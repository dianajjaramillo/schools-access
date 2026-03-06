#
# Download GHS population data (epoch: 2020, resolution: 3 arcsec, coordinate system: WGS84)
#

rule pop_ghs_download:
    output:
        zip="incoming_data/pop-ghs/GHS_POP_E2020_GLOBE_R2023A_4326_3ss_V1_0.tif"
    shell:
        """
        mkdir -p incoming_data/pop-ghs
        cd incoming_data/pop=ghs
        wget https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/GHS_POP_E2020_GLOBE_R2023A_4326_3ss/V1-0/GHS_POP_E2020_GLOBE_R2023A_4326_3ss_V1_0.zip"
        unzip GHS_POP_E2020_GLOBE_R2023A_4326_3ss_V1_0.zip
        """

rule pop_ghs_clip:
    input:
        tif="incoming_data/pop-ghs/GHS_POP_E2020_GLOBE_R2023A_4326_3ss_V1_0.tif",
        bounds="data/{ISO3}/boundaries__{ISO3}.gpkg"
    output:
        tif="data/{ISO3}/pop_ghs__{ISO3}.tif",
    shell:
        """
        gdalwarp \
            -co COMPRESS=LZW \
            -cutline {input.bounds} \
            -cl boundaries__{wildcards.ISO3} \
            -crop_to_cutline \
            {input.tif} \
            {output.tif}
        """

rule pop_ghs_hex:
    input:
        tif="data/{ISO3}/pop_ghs__{ISO3}.tif",
    output:
        gpkg="data/{ISO3}/pop_ghs_hex__{ISO3}.gpkg",
    run:

        import h3pandas
        import rioxarray as rxr
        import os.path

        """
        This script takes an population grid raster file
        and converts it to a hexagonal grid cell gpkg

        """
        rds = rxr.open_rasterio(input.tif)
        rds = rds.squeeze().drop("spatial_ref").drop("band")
        rds.name = "pop"
        df = rds.to_dataframe().reset_index()
        df.replace(-99999, 0, inplace = True)

        # For testing purposes make a small version of the file 
        testing = False
        if testing == True:
            df = df.head(10)

        # Convert to H3 hexagons
        # Note: higher number, smaller hexagons and higher resolution
        print("Converting to hexagons...")
        pop = df.h3.geo_to_h3_aggregate(6, 'sum', lat_col = 'y', lng_col = 'x')

        # Export hexagons to gpkg
        print("Exporting to gpkg...")
        pop.to_file(output.gpkg,
                    layer = "population",
                    driver = "GPKG")