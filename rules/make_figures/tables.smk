#
# Rules for generating tables
#

with open("config/countries_list.txt") as f:
    ISO3_CODES = [line.strip() for line in f if line.strip()]

rule schools_numbers_all:
    input:
        expand("data/{ISO3}/schools_facilities.txt",
            ISO3=ISO3_CODES)

rule schools_numbers:
    input:
        jrc = "data/{ISO3}/schools_jrc__{ISO3}.gpkg",
        giga = "data/{ISO3}/schools_giga__{ISO3}.gpkg",
        osm = "data/{ISO3}/schools_osm__{ISO3}.gpkg",
        # nbuf="data/{ISO3}/schools_merged_nobuff__{ISO3}.gpkg",
        # ybuf="data/{ISO3}/schools_merged_wbuff50__{ISO3}.gpkg",
        # nbuf_JG="data/{ISO3}/schools_merged_nobuff_JG__{ISO3}.gpkg",
        # ybuf_JG="data/{ISO3}/schools_merged_wbuff50_JG__{ISO3}.gpkg",
        df = "figures/tables/countries_schools.csv",
    output:
        txt = "data/{ISO3}/schools_facilities.txt",
    run:
        import pandas
        import geopandas

        jrc = geopandas.read_file(input.jrc)
        giga = geopandas.read_file(input.giga)
        osm = geopandas.read_file(input.osm)
        # nbuf = geopandas.read_file(input.nbuf)
        # ybuf = geopandas.read_file(input.ybuf)
        # nbuf_JG = geopandas.read_file(input.nbuf_JG)
        # ybuf_JG = geopandas.read_file(input.ybuf_JG)

        jrc_len = len(jrc)
        giga_len = len(giga)
        osm_len = len(osm)
        # nbuf_len = len(nbuf)
        # ybuf_len = len(ybuf)
        # nbuf_JG_len = len(nbuf_JG)
        # ybuf_JG_len = len(ybuf_JG)

        # update main file
        df = pandas.read_csv(input.df, index_col = 0)
        df.loc[df['ISO3']==list({wildcards.ISO3})[0],'Schools (JRC)'] = jrc_len
        df.loc[df['ISO3']==list({wildcards.ISO3})[0],'Schools (Giga)'] = giga_len
        df.loc[df['ISO3']==list({wildcards.ISO3})[0],'Schools (OSM)'] = osm_len
        # df.loc[df['ISO3']==list({wildcards.ISO3})[0],'Schools (Merged_nobuff)'] = nbuf_len
        # df.loc[df['ISO3']==list({wildcards.ISO3})[0],'Schools (Merged_wbuff50)'] = ybuf_len
        # df.loc[df['ISO3']==list({wildcards.ISO3})[0],'Schools (Merged_nobuff_JG)'] = nbuf_JG_len
        # df.loc[df['ISO3']==list({wildcards.ISO3})[0],'Schools (Merged_wbuff50_JG)'] = ybuf_JG_len
        df.to_csv(input.df)


        # export dummy txt file
        txt = open(output.txt, "x")
        txt.write("# of schools in JRC: "+str(jrc_len)+"\n")
        txt.write("# of schools in Giga: "+str(giga_len)+"\n")
        txt.write("# of schools in OSM: "+str(osm_len)+"\n")
        # txt.write("# of schools in Merged nobuff: "+str(nbuf_len))
        # txt.write("# of schools in Merged wbuff50: "+str(ybuf_len))
        # txt.write("# of schools in Merged nobuff: "+str(nbuf_JG_len))
        # txt.write("# of schools in Merged wbuff50: "+str(ybuf_JG_len))

        txt.close

rule stats_all:
    input:
        txt="config/countries_list.txt",
    output:
        csv_stats="figures/tables/{MODEL}/{VERSION}/stats_byiso.csv",
        csv_all="figures/tables/{MODEL}/{VERSION}/df_complete.csv",
    run:
        from statistics import fmean

        countries = open(input.txt, "r").read().split("\n")

        if wildcards.MODEL == "model_1km":
            countries.remove("EGY")

        df_complete = []
        df_stats = pandas.DataFrame(columns={0: 'ISO3', 1: 'wgt_avg', 2: 'wgt_p20', 3: 'wgt_p80', 4: 'ratio'})

        for iso in countries:
            path_iso = f"{wildcards.MODEL}/outputs/{wildcards.VERSION}/{iso}/analysis/ttpop_nat__{iso}.csv"
            df_iso = pandas.read_csv(path_iso, index_col=0)
            df_iso["ISO3"]=iso
            df_complete.append(df_iso)

            # calculate statistics
            wgt_avg = fmean(df_iso["traveltime"], weights=df_iso["pop"])
            wgt_p80 = schools.weighted_percentile(df_iso["traveltime"],80,df_iso["pop"])
            wgt_p20 = schools.weighted_percentile(df_iso["traveltime"],20,df_iso["pop"])
            ratio = wgt_p80/wgt_p20

            df_stats.loc[len(df_stats.index)] = [iso,wgt_avg,wgt_p20,wgt_p80,ratio]

        df_complete = pandas.concat(df_complete)
        df_stats = df_stats.rename(columns={0: 'ISO3', 1: 'wgt_avg', 2: 'wgt_p20', 3: 'wgt_p80', 4: 'ratio'})
        
        df_complete.to_csv(output.csv_all)
        df_stats.to_csv(output.csv_stats)

rule stats_all_urb:
    input:
        txt="config/countries_list.txt",
    output:
        csv_stats="figures/tables/{MODEL}/{VERSION}/stats_urb_byiso.csv",
        csv_all="figures/tables/{MODEL}/{VERSION}/df_urb_complete.csv",
    run:
        from statistics import fmean

        countries = open(input.txt, "r").read().split("\n")

        if wildcards.MODEL == "model_1km":
            countries.remove("EGY")

        df_complete = []
        df_stats = pandas.DataFrame(columns={0: 'ISO3', 1: 'wgt_avg', 2: 'wgt_p20', 3: 'wgt_p80', 4: 'ratio'})

        for iso in countries:
            path_iso = f"{wildcards.MODEL}/outputs/{wildcards.VERSION}/{iso}/analysis/ttpopurb_nat__{iso}.csv"
            df_iso = pandas.read_csv(path_iso, index_col=0)
            df_iso["ISO3"]=iso
            df_complete.append(df_iso)

            # calculate statistics
            wgt_avg = fmean(df_iso["traveltime"], weights=df_iso["pop"])
            wgt_p80 = schools.weighted_percentile(df_iso["traveltime"],80,df_iso["pop"])
            wgt_p20 = schools.weighted_percentile(df_iso["traveltime"],20,df_iso["pop"])
            ratio = wgt_p80/wgt_p20

            df_stats.loc[len(df_stats.index)] = [iso,wgt_avg,wgt_p20,wgt_p80,ratio]

        df_complete = pandas.concat(df_complete)
        df_stats = df_stats.rename(columns={0: 'ISO3', 1: 'wgt_avg', 2: 'wgt_p20', 3: 'wgt_p80', 4: 'ratio'})
        
        df_complete.to_csv(output.csv_all)
        df_stats.to_csv(output.csv_stats)

rule summary_all:
    input:
        txt="config/countries_list.txt",
    output:
        csv="figures/tables/{MODEL}/{VERSION}/threshpop_byiso.csv",
    run:
        countries = open(input.txt, "r").read().split("\n")

        if wildcards.MODEL == "model_1km":
            countries.remove("EGY")

        df_summary = []

        for iso in countries:
            path_iso = f"{wildcards.MODEL}/outputs/{wildcards.VERSION}/{iso}/analysis/ttpop_nat__{iso}.csv"
            df_iso = pandas.read_csv(path_iso, index_col=0)
            df_iso["ISO3"]=iso
    
            sum_iso = []
            tot_pop_iso = df_iso["pop"].sum()
            
            for i in (15,30,60,90,120,180,240,360):
                val = df_iso.loc[(df_iso["traveltime"] <= i), "pop"].sum()
                sum_iso.append([i, val, val/tot_pop_iso])
            
            sum_iso = pandas.DataFrame(sum_iso)
            sum_iso = sum_iso.rename(columns={0: 'traveltime', 1: 'cumpop', 2: 'cumpop_%'})

            sum_iso["pop_%"] = sum_iso["cumpop_%"].diff().fillna(sum_iso["cumpop_%"])*100

            sum_iso.loc[len(sum_iso.index)] = ['higher', tot_pop_iso, 1, (1-(val/tot_pop_iso))*100]

            sum_export = sum_iso.drop(columns=["cumpop","cumpop_%"]).set_index("traveltime")
            sum_export = sum_export.T
            sum_export.insert(0, 'ISO3', iso)
            sum_export.reset_index(drop = True, inplace=True)
            df_summary.append(sum_export)

        df_summary = pandas.concat(df_summary).reset_index(drop = True)

        df_summary.to_csv(output.csv)

rule summary_cumulative:
    input:
        txt="config/countries_list.txt",
    output:
        csv="figures/tables/{MODEL}/{VERSION}/threshcumpop_byiso.csv",
    run:
        countries = open(input.txt, "r").read().split("\n")

        if wildcards.MODEL == "model_1km":
            countries.remove("EGY")

        df_summary_cum = []

        for iso in countries:
            path_iso = f"{wildcards.MODEL}/outputs/{wildcards.VERSION}/{iso}/analysis/ttpop_nat__{iso}.csv"
            df_iso = pandas.read_csv(path_iso, index_col=0)
            df_iso["ISO3"]=iso
    
            cumsum_iso = []
            tot_pop_iso = df_iso["pop"].sum()
            
            for i in (15,30,60,90,120,180,240,360):
                val = df_iso.loc[df_iso["traveltime"] <= i, "pop"].sum()
                cumsum_iso.append([i, val, val/tot_pop_iso])
            
            cumsum_iso.append(['higher', tot_pop_iso, 1])    
            
            cumsum_iso = pandas.DataFrame(cumsum_iso)
            cumsum_iso = cumsum_iso.rename(columns={0: 'traveltime', 1: 'cumpop', 2: 'cumpop_%'})
            
            cumsum_export = cumsum_iso.drop(columns="cumpop").set_index("traveltime")
            cumsum_export = cumsum_export.T
            cumsum_export.insert(0, 'ISO3', iso)
            
            
            df_summary_cum.append(cumsum_export)

        df_summary_cum = pandas.concat(df_summary_cum)

        df_summary_cum.to_csv(output.csv)

