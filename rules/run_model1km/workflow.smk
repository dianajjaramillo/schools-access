#
# Runs accessibility analysis using 1km friction surfaces
#

with open("config/countries_list.txt") as f:
    ISO3_CODES = [line.strip() for line in f if line.strip()]

rule analyse_all_jrc:
    input:
        expand("model_1km/outputs/{SOURCE}/{ISO3}/analysis/ttpop_nat__{ISO3}.csv", 
            SOURCE="jrc", 
            ISO3=ISO3_CODES)

rule friction_download: 
    output:
        walking="incoming_data/friction/2020_walking_only_friction_surface.geotiff",
        motor="incoming_data/friction/2020_motorized_friction_surface.geotiff",
    shell:
        """
        mkdir -p incoming_data/friction
        cd incoming_data/friction
        wget https://malariaatlas.org/geoserver/ows?service=CSW&version=2.0.1&request=DirectDownload&ResourceId=Explorer:2020_motorized_friction_surface
        wget https://malariaatlas.org/geoserver/ows?service=CSW&version=2.0.1&request=DirectDownload&ResourceId=Explorer:2020_walking_only_friction_surface
        
        unzip 2020_motorized_friction_surface.zip
        unzip 2020_walking_only_friction_surface.zip

        """

rule friction_clip:
    input:
        walking="incoming_data/friction/2020_walking_only_friction_surface.geotiff",
        motor="incoming_data/friction/2020_motorized_friction_surface.geotiff",
        bounds="data/{ISO3}/boundaries__{ISO3}.gpkg",
    output:
        walking="data/{ISO3}/friction_walking__{ISO3}.tif",
        motor="data/{ISO3}/friction_motorized__{ISO3}.tif",
    shell:
        """
        gdalwarp \
            -co COMPRESS=DEFLATE \
            -cutline {input.bounds} \
            -crop_to_cutline \
            -s_srs EPSG:4326 \
            {input.walking} \
            {output.walking}

        gdalwarp \
            -co COMPRESS=DEFLATE \
            -cutline {input.bounds} \
            -crop_to_cutline \
            -s_srs EPSG:4326 \
            {input.motor} \
            {output.motor}

        """

rule csv_schools:
    input:
        pc="data/{ISO3}/schools_{SOURCE}__{ISO3}.gpkg",
    output:
        csv="data/{ISO3}/schools_{SOURCE}__{ISO3}.csv",
    wildcard_constraints:
        SOURCE="jrc|giga|osm|merged",
    run:
        import geopandas 
        import geopandas

        pc=geopandas.read_file(input.pc)

        csv = pc.get_coordinates()
        csv.rename(columns={"x":"X_COORD","y":"Y_COORD"}, inplace=True)

        csv.to_csv(output.csv, index=False)
        

rule walking_access:
    input:
        friction="data/{ISO3}/friction_walking__{ISO3}.tif",
        schools="data/{ISO3}/schools_{SOURCE}__{ISO3}.csv",
    output:
        T="model_1km/outputs/{SOURCE}/{ISO3}/outputs/walking_{SOURCE}_T.rds",
        GC="model_1km/outputs/{SOURCE}/{ISO3}/outputs/walking_{SOURCE}_T.GC.rds",
        access="model_1km/outputs/{SOURCE}/{ISO3}/outputs/walking_access_{SOURCE}__{ISO3}.tif",
    wildcard_constraints: 
        SOURCE="jrc|giga|osm|merged",
    script:
        "calc_access.R"



rule analysis_pop:
    input:
        tt="model_1km/outputs/{SOURCE}/{ISO3}/outputs/walking_access_{SOURCE}__{ISO3}.tif",
        pp="data/{ISO3}/pop_ghs__{ISO3}.tif",
    output:
        csv_nat="model_1km/outputs/{SOURCE}/{ISO3}/analysis/ttpop_nat__{ISO3}.csv",
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
