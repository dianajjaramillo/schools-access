#
# Process AccessMod outputs into travel-time rasters.
#

with open("config/countries_list.txt") as f:
    ISO3_CODES = [line.strip() for line in f if line.strip()]

rule am_process_all:
    input:
        expand("model_90m/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif", 
            VERSION="jrcwalking", 
            ISO3=ISO3_CODES)

rule am_unzip:
    input:
        zip=glob_wildcards("model_90m/outputs/{VERSION}/{ISO3}/*.zip"),
    output:
        img="model_90m/outputs/{VERSION}/{ISO3}/outputs/raster_travel_time_accessibility_{VERSION}/raster_travel_time_accessibility_{VERSION}.img",
    shell:
        """
        mkdir -p model_90m/outputs/{wildcards.VERSION}/{wildcards.ISO3}/analysis
        mkdir -p model_90m/outputs/{wildcards.VERSION}/{wildcards.ISO3}/outputs
        cd model_90m/outputs/{wildcards.VERSION}/{wildcards.ISO3}
        unzip '*.zip' -d outputs
        """

rule am_convert: 
    input:
        img="model_90m/outputs/{VERSION}/{ISO3}/outputs/raster_travel_time_accessibility_{VERSION}/raster_travel_time_accessibility_{VERSION}.img",
    output:
        tif="model_90m/outputs/{VERSION}/{ISO3}/outputs/traveltime_3857__{ISO3}.tif",
    shell:
        """
        gdal_translate \
            -a_srs EPSG:3857 \
            {input.img} \
            {output.tif}
        """

rule am_reproject: 
    input:
        tif="model_90m/outputs/{VERSION}/{ISO3}/outputs/traveltime_3857__{ISO3}.tif",
    output:
        tif="model_90m/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
    shell:
        """
        gdalwarp \
            -s_srs EPSG:3857 \
            -t_srs EPSG:4326 \
            {input.tif} \
            {output.tif}
        """

rule am_byadmin:
    input:
        tif="model_90m/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
        gadm="data/{ISO3}/boundaries__{ISO3}.gpkg",
    output:
        gpkg="model_90m/outputs/{VERSION}/{ISO3}/outputs/traveltime_byadmin.gpkg",
    run:
        import geopandas
        import pandas
        from rasterstats import zonal_stats
        
        admin = geopandas.read_file(input.gadm, include_fields = ["GID_3","NAME_3","geometry"],layer = "ADM_ADM_3").explode(index_parts=False)
        stats_tt = ['min', 'percentile_10', 'percentile_25', 'median', 'percentile_75', 'percentile_90', 'max', 'mean', 'count']

        tt = zonal_stats(admin,
                    input.tif,
                    stats=stats_tt)

        tt_df = pandas.DataFrame(tt)
        tt_gdf = admin.join(tt_df)
        tt_gdf.to_file(output.gpkg)


rule am_make_tiff_list:
    input:
        expand("model_90m/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
               VERSION="jrcwalking",
               ISO3=ISO3_CODES)
    output:
        "model_90m/outputs/jrcwalking/AFR/tiff_list.txt"
    shell:
        "printf '%s\n' {input} > {output}"


rule am_merge:
    input:
        txt="model_90m/outputs/{VERSION}/AFR/tiff_list.txt",
    output:
        tif="model_90m/outputs/{VERSION}/AFR/traveltime_4326__AFR.tif",
    shell:
        """
        gdal_merge.py \
            -co "COMPRESS=LZW" \
            -co "BIGTIFF=YES" \
            -of "GTiff" \
            -o {output.tif} \
            --optfile {input.txt}
        """
