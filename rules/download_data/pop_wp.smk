#
# Download WorldPop school-age population (Africa).
#
rule pop_schoolage_download:
    output:
        zip="data/{ISO3}/pop_schoolage/{ISO3}_SAP_1km_2020.zip",
    shell:
        """
        mkdir -p data/{wildcards.ISO3}/pop_schoolage
        cd data/{wildcards.ISO3}/pop_schoolage
        wget https://data.worldpop.org/GIS/AgeSex_structures/school_age_population/v1/2020/{wildcards.ISO3}/{wildcards.ISO3}_SAP_1km_2020.zip
        
        """

rule pop_schoolage_process:
    input:
        zip="data/{ISO3}/pop_schoolage/{ISO3}_SAP_1km_2020.zip",
    output:
        tif="data/{ISO3}/pop_schoolage/pop_schoolage__{ISO3}.tif",
    shell:
        """
        cd data/{wildcards.ISO3}/pop_schoolage
        unzip {wildcards.ISO3}_SAP_1km_2020.zip

        gdal_calc.py -P {wildcards.ISO3}_F_M_PRIMARY_2020_1km.tif -S {wildcards.ISO3}_F_M_SECONDARY_2020_1km.tif --outfile=pop_schoolage__{wildcards.ISO3}.tif --calc="P+S"

        """

rule pop_schoolage_hex:
    input:
        tif="data/{ISO3}/pop_schoolage/pop_schoolage__{ISO3}.tif",
    output:
        gpkg="data/{ISO3}/pop_schoolage/hexpop_schoolage__{ISO3}.gpkg",
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
