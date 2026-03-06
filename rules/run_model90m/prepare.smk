#
# Generates datapackage necessary to run AccessMod
#

with open("config/countries_list.txt") as f:
    ISO3_CODES = [line.strip() for line in f if line.strip()]

rule am_prepare_all:
    input:
        expand("model_90m/inputs/{ISO3}/rundate.txt", ISO3=ISO3_CODES)

rule am_package:
    input:
        "model_90m/inputs/{ISO3}/boundaries__{ISO3}.shp",    
        "model_90m/inputs/{ISO3}/elevation__{ISO3}.tif",
        "model_90m/inputs/{ISO3}/landcover__{ISO3}.tif",
        "model_90m/inputs/{ISO3}/population__{ISO3}.tif",
        "model_90m/inputs/{ISO3}/roads__{ISO3}.shp",
        "model_90m/inputs/{ISO3}/schools_merged_wbuff50__{ISO3}.shp",
        "model_90m/inputs/{ISO3}/scenario_multimodal.csv",
        "model_90m/inputs/{ISO3}/scenario_walkingonly.csv",
    output:
        "model_90m/inputs/{ISO3}/rundate.txt",
    shell:
        """
        mkdir -p accessmod/inputs/{wildcards.ISO3}
        cd accessmod/inputs/{wildcards.ISO3}
        touch rundate.txt
        date >> rundate.txt
        """

rule am_boundaries:
    input:
        gpkg="data/{ISO3}/boundaries__{ISO3}.gpkg",
    output:
        shp="model_90m/inputs/{ISO3}/boundaries__{ISO3}.shp",
    run:
        boundaries=geopandas.read_file(input.gpkg).to_crs(3857)
        boundaries.to_file(output.shp)

rule am_zones:
    input:
        gpkg="data/{ISO3}/gadm__{ISO3}.gpkg",
    output:
        shp="model_90m/inputs/{ISO3}/gadm3__{ISO3}.shp",
    run:
        boundaries=geopandas.read_file(input.gpkg, layer="ADM_ADM_3").to_crs(3857)
        boundaries.to_file(output.shp)


rule am_dem:
    input:
        tif="data/{ISO3}/elevation__{ISO3}.tif",
    output:
        tif="model_90m/inputs/{ISO3}/elevation__{ISO3}.tif",
    shell:
        """
        gdalwarp \
            -co COMPRESS=LZW \
            -t_srs EPSG:3857 \
            {input.tif} \
            {output.tif}
        """

rule am_lulc:
    input:
        tif="data/{ISO3}/landcover__{ISO3}.tif",
    output:
        tif="model_90m/inputs/{ISO3}/landcover__{ISO3}.tif",
    shell:
        """
        gdalwarp \
            -co COMPRESS=LZW \
            -tr 0.000833333333333 0.000833333333333 \
            -r nearest \
            {input.tif} \
            "data/{wildcards.ISO3}/landcover_3857.tif"

        gdalwarp\
            -co COMPRESS=LZW \
            -s_srs EPSG:4326 \
            -t_srs EPSG:3857 \
            "data/{wildcards.ISO3}/landcover_3857.tif" \
            {output.tif}

        rm data/{wildcards.ISO3}/landcover_3857.tif
        """

rule am_pop_schoolage:
    input:
        tif="data/{ISO3}/pop_schoolage/pop_schoolage__{ISO3}.tif",
    output:
        tif="model_90m/inputs/{ISO3}/pop_schoolage__{ISO3}.tif",
    shell:
        """
        gdalwarp -t_srs EPSG:3857 {input.tif} {output.tif}
        """

rule am_pop_ghs:
    input:
        tif="data/{ISO3}/pop_ghs__{ISO3}.tif",
    output:
        tif="model_90m/inputs/{ISO3}/population__{ISO3}.tif",
    shell:
        """
        gdalwarp \
            -co COMPRESS=LZW \
            -t_srs EPSG:3857 \
            {input.tif} \
            {output.tif}
        """

def categorize_class(road_class):
    if road_class == 'motorway':
        return 1001
    elif road_class == 'motorway_link':
        return 1002
    elif road_class == 'trunk':
        return 2001
    elif road_class == 'trunk_link':
        return 2002
    elif road_class == 'primary':
        return 3001
    elif road_class == 'primary_link':
        return 3002
    elif road_class == 'secondary':
        return 4001
    elif road_class == 'secondary_link':
        return 4002
    elif road_class == 'tertiary':
        return 5001
    elif road_class == 'tertiary_link':
        return 5002
    elif road_class == 'unclassified':
        return 6001
    elif road_class == 'residential':
        return 6002
    elif road_class == 'service':
        return 6003
    elif road_class == 'track':
        return 6004
    elif road_class == 'footway':
        return 6005
    elif road_class == 'path':
        return 6006

rule am_roads:
    input:
        gpkg="data/{ISO3}/openstreetmap/openstreetmap_roads-all__{ISO3}.gpkg",
    output:
        shp="model_90m/inputs/{ISO3}/roads__{ISO3}.shp",
    run:
        # Add a road class integer
        roads_gdf=geopandas.read_file(input.gpkg, layer='lines').to_crs(3857)
        roads_gdf["road_class"] = roads_gdf['highway'].apply(categorize_class)

        # Reduce filesize
        roads_gdf = roads_gdf[["road_class","highway","geometry","maxspeed"]]

        roads_gdf.to_file(output.shp)

rule am_scenario:
    input:
        shp="model_90m/inputs/{ISO3}/roads__{ISO3}.shp",
        temp_m="config/travel_speeds/scenario_multimodal.csv", 
        temp_w="config/travel_speeds/scenario_walkingonly.csv",
    output:
        scenario_m="model_90m/inputs/{ISO3}/scenario_multimodal.csv",
        scenario_w="model_90m/inputs/{ISO3}/scenario_walkingonly.csv",
    run:
        # Calcualte mean road driving speeds by class
        roads_gdf = geopandas.read_file(input.shp)
        roads=pandas.DataFrame(roads_gdf)
        roads_filtered = roads[(roads["maxspeed"].notnull()) & (roads["maxspeed"].str.isnumeric())]
        roads_filtered["maxspeed"]=roads_filtered["maxspeed"].apply(pandas.to_numeric)
        speeds = roads_filtered.groupby(["road_class","highway"]).mean("maxspeed").reset_index()
        # speeds = speeds.drop(columns="z_order")
        speeds = speeds.rename(columns={"road_class":"class","highway":"label","maxspeed":"speed"})
        speeds["mode"]="MOTORIZED"

        # Add national motorized speeds to travel scenario
        scenario_m = pandas.read_csv(input.temp_m)
        scenario_m = scenario_m.set_index('class')
        scenario_m.update(speeds.set_index('class'))
        scenario_m = scenario_m.reset_index()

        # Change footway to walking
        scenario_m.loc[scenario_m['label']=='footway','speed'] = 4
        scenario_m.loc[scenario_m['label']=='footway','mode'] = "WALKING"

        # Export multimodal travel scenario
        scenario_m.to_csv(output.scenario_m, index=False)

        # Export generic copy of walking only travel scenario
        scenario_w = pandas.read_csv(input.temp_w)
        scenario_w.to_csv(output.scenario_w, index=False)

rule am_schools:
    input:
        gpkg="data/{ISO3}/schools_{SOURCE}__{ISO3}.gpkg",
    output:
        shp="model_90m/inputs/{ISO3}/schools_{SOURCE}__{ISO3}.shp",
    run:
        pcschools=geopandas.read_file(input.gpkg).to_crs(3857)
        pcschools.to_file(output.shp)
