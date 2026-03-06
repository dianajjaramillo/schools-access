#
# Population (ghs) is overlayed with accessibility analysis outputs 
#

with open("config/countries_list.txt") as f:
    ISO3_CODES = [line.strip() for line in f if line.strip()]

rule am_analyse_all:
    input:
        expand("model_90m/outputs/{VERSION}/{ISO3}/analysis/ttpop_nat__{ISO3}.csv", 
            VERSION="jrcwalking", 
            ISO3=ISO3_CODES)

rule am_analyse_all_urb:
    input:
        expand("model_90m/outputs/{VERSION}/{ISO3}/analysis/ttpopurb_nat__{ISO3}.csv", 
            VERSION="jrcwalking", 
            ISO3=ISO3_CODES)

rule am_analyse_all_gadm:
    input:
        expand("model_90m/outputs/{VERSION}/{ISO3}/analysis/ttpop_gadm__{ISO3}.csv", 
            VERSION="jrcwalking", 
            ISO3=ISO3_CODES)

rule am_gadm_stats_all:
    input:
        expand("model_90m/outputs/{VERSION}/{ISO3}/analysis/stats_gadm__{ISO3}.gpkg", 
            VERSION="jrcwalking", 
            ISO3=ISO3_CODES)

rule am_pop:
    input:
        tt="{MODEL}/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
        pp="data/{ISO3}/pop_ghs__{ISO3}.tif",
        # gadm_zones="data/{ISO3}/gadm__{ISO3}.gpkg",
    output:
        csv_nat="{MODEL}/outputs/{VERSION}/{ISO3}/analysis/ttpop_nat__{ISO3}.csv",
        # csv_sub_gadm="{MODEL}/outputs/{VERSION}/{ISO3}/analysis/ttpop_gadm__{ISO3}.csv",
    run:
        import rasterio
        import rioxarray
        import pandas
        import geopandas

        print ("Processing population...")
        # The population raster is converted to points. The points hold the total population count in each grid cell
        pop = rioxarray.open_rasterio(input.pp)
        pop_crs = pop.rio.crs
        pop = pop.squeeze().drop_vars("spatial_ref").drop_vars("band")
        pop.name = "pop"
        pop_df = pop.to_dataframe().reset_index()

        pop_df = pop_df[pop_df["pop"] > 0.0].reset_index()

        pop_gdf = geopandas.GeoDataFrame(pop_df, 
                                 crs=pop_crs, 
                                 geometry = geopandas.points_from_xy(pop_df.x, pop_df.y))

        print ("Processing traveltime...")
        # The points are then intersected with the travel time raster to extract the travel time for each population point. 
        tt_raster = rasterio.open(input.tt)
        coord_list = [(x, y) for x, y in zip(pop_gdf["geometry"].x, pop_gdf["geometry"].y)]
        pop_gdf["traveltime"] = [x[0] for x in tt_raster.sample(coord_list, indexes=1, masked=True)]

        # Summarize at national level
        print("Creating summary tables at national level...")
        # Now proceed to create summary tables
        df_nat=pop_gdf.drop(["index","y","x","geometry"], axis=1)
        df_nat["traveltime"] = df_nat["traveltime"].astype(float)
        df_nat= df_nat.groupby("traveltime").sum("pop").reset_index()

        print("Ready to export national summary...")
        df_nat.to_csv(output.csv_nat)


        # # Summarize at subnational level 
        # print("Creating summary tables at subnational level...")

        # print ("Adding admin zone info using GADM zones...")
        # # Before proceeding, add in the admin code for each population point 
        
        # level_layer = "ADM_ADM_2"
        # level_id = "GID_2"

        # try:
        #     admin_gadm = geopandas.read_file(input.gadm_zones, include_fields = [level_id,"geometry"],layer = level_layer)

        # except:
        #     print("Warning: GADM level 2 does not exist, using GADM 1 instead")
        #     level_layer = "ADM_ADM_1"
        #     level_id = "GID_1"

        #     admin_gadm = geopandas.read_file(input.gadm_zones, include_fields = [level_id,"geometry"],layer = level_layer)


        # df_sub_gadm = pop_gdf.sjoin(admin_gadm, how="left")

        # print("Creating summary tables for GADM...")
        # # Now proceed to create summary tables
        # df_sub_gadm=df_sub_gadm.drop(["index","index_right","y","x","geometry"], axis=1)
        # df_sub_gadm["traveltime"] = df_sub_gadm["traveltime"].astype(float)
        # df_sub_gadm= df_sub_gadm.groupby(["traveltime", level_id]).sum("pop").reset_index()

        # print("Ready to export GADM...")
        # df_sub_gadm.to_csv(output.csv_sub_gadm)


rule am_pop_urb:
    input:
        tt="{MODEL}/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
        pp="data/{ISO3}/pop_ghs__{ISO3}.tif",
        urb="data/{ISO3}/urban_deg__{ISO3}.tif"
    output:
        csv_nat="{MODEL}/outputs/{VERSION}/{ISO3}/analysis/ttpopurb_nat__{ISO3}.csv",
    run:
        import rasterio
        import rioxarray
        import pandas
        import geopandas

        print ("Processing population...")
        # The population raster is converted to points. The points hold the total population count in each grid cell
        pop = rioxarray.open_rasterio(input.pp)
        pop_crs = pop.rio.crs
        pop = pop.squeeze().drop_vars("spatial_ref").drop_vars("band")
        pop.name = "pop"
        pop_df = pop.to_dataframe().reset_index()

        pop_df = pop_df[pop_df["pop"] > 0.0].reset_index()

        pop_gdf = geopandas.GeoDataFrame(pop_df, 
                                 crs=pop_crs, 
                                 geometry = geopandas.points_from_xy(pop_df.x, pop_df.y))

        print ("Processing traveltime...")
        # The points are then intersected with the travel time raster to extract the travel time for each population point. 
        tt_raster = rasterio.open(input.tt)
        coord_list = [(x, y) for x, y in zip(pop_gdf["geometry"].x, pop_gdf["geometry"].y)]
        pop_gdf["traveltime"] = [x[0] for x in tt_raster.sample(coord_list, indexes=1, masked=True)]

        print ("Processing urbanisation...")
        # The points are then intersected with the degree of urbanisation raster to extract the category for each population point. 
        urb_raster = rasterio.open(input.urb)
        pop_gdf["urban_deg"] = [x[0] for x in urb_raster.sample(coord_list, indexes=1, masked=True)]

        # Summarize at national level
        print("Creating summary tables at national level...")
        # Now proceed to create summary tables
        df_nat=pop_gdf.drop(["index","y","x","geometry"], axis=1)
        df_nat["traveltime"] = df_nat["traveltime"].astype(float)
        df_nat["urban_deg"] = df_nat["urban_deg"].astype(float)
        df_nat= df_nat.groupby(["traveltime","urban_deg"]).sum("pop").reset_index()

        print("Ready to export national summary...")
        df_nat.to_csv(output.csv_nat)

rule am_pop_gadm:
    input:
        tt="{MODEL}/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
        pp="data/{ISO3}/pop_ghs__{ISO3}.tif",
        gadm_zones="data/{ISO3}/gadm__{ISO3}.gpkg",
    output:
        csv_sub_gadm="{MODEL}/outputs/{VERSION}/{ISO3}/analysis/ttpop_gadm__{ISO3}.csv",
    run:
        import rasterio
        import rioxarray
        import pandas
        import geopandas

        print ("Processing population...")
        # The population raster is converted to points. The points hold the total population count in each grid cell
        pop = rioxarray.open_rasterio(input.pp)
        pop_crs = pop.rio.crs
        pop = pop.squeeze().drop_vars("spatial_ref").drop_vars("band")
        pop.name = "pop"
        pop_df = pop.to_dataframe().reset_index()

        pop_df = pop_df[pop_df["pop"] > 0.0].reset_index()

        pop_gdf = geopandas.GeoDataFrame(pop_df, 
                                 crs=pop_crs, 
                                 geometry = geopandas.points_from_xy(pop_df.x, pop_df.y))

        print ("Processing traveltime...")
        # The points are then intersected with the travel time raster to extract the travel time for each population point. 
        tt_raster = rasterio.open(input.tt)
        coord_list = [(x, y) for x, y in zip(pop_gdf["geometry"].x, pop_gdf["geometry"].y)]
        pop_gdf["traveltime"] = [x[0] for x in tt_raster.sample(coord_list, indexes=1, masked=True)]

        # Summarize at subnational level 
        print("Creating summary tables at subnational level...")

        print ("Adding admin zone info using GADM zones...")
        # Before proceeding, add in the admin code for each population point 
        
        level_layer = "ADM_ADM_2"
        level_id = "GID_2"

        try:
            admin_gadm = geopandas.read_file(input.gadm_zones, include_fields = [level_id,"geometry"],layer = level_layer)

        except:
            print("Warning: GADM level 2 does not exist, using GADM 1 instead")
            level_layer = "ADM_ADM_1"
            level_id = "GID_1"

            admin_gadm = geopandas.read_file(input.gadm_zones, include_fields = [level_id,"geometry"],layer = level_layer)


        df_sub_gadm = pop_gdf.sjoin(admin_gadm, how="left")

        print("Creating summary tables for GADM...")
        # Now proceed to create summary tables
        df_sub_gadm=df_sub_gadm.drop(["index","index_right","y","x","geometry"], axis=1)
        df_sub_gadm["traveltime"] = df_sub_gadm["traveltime"].astype(float)
        df_sub_gadm= df_sub_gadm.groupby(["traveltime", level_id]).sum("pop").reset_index()

        print("Ready to export GADM...")
        df_sub_gadm.to_csv(output.csv_sub_gadm)


rule metric_gadm:
    input:
        csv="{MODEL}/outputs/{VERSION}/{ISO3}/analysis/ttpop_gadm__{ISO3}.csv",
        gadm_zones="data/{ISO3}/gadm__{ISO3}.gpkg",

    output:
        gpkg="{MODEL}/outputs/{VERSION}/{ISO3}/analysis/stats_gadm__{ISO3}.gpkg",
    run:
        import schools
        df = pandas.read_csv(input.csv, index_col=0)

        try:
            group = "GID_2"
            layer="ADM_ADM_2"
            grouped_stats = df.groupby(group).apply(schools.group_stats, include_groups=False).reset_index()

        except:
            group = "GID_1"
            layer="ADM_ADM_1"
            grouped_stats = df.groupby(group).apply(schools.group_stats, include_groups=False).reset_index()
        
        grouped_stats["ratio"] = grouped_stats["wgt_p80"]/grouped_stats["wgt_p20"]
        
        admin = geopandas.read_file(input.gadm_zones, layer=layer)
        stats_df = grouped_stats.merge(admin[[group,"geometry"]],
                            how = "left",
                            on = group)
        stats_gdf = geopandas.GeoDataFrame(stats_df, geometry="geometry")
        stats_gdf.to_file(output.gpkg)

