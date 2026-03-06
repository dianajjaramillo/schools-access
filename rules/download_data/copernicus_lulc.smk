#
# Copernicus LULC and clip to country boundaries.
#

rule download_lulc:
    output:
        zip="incoming_data/copernicus_lulc/archive.zip",
    run:
        import os 
        path = os.path.join("incoming_data","copernicus_lulc")
        if not os.path.isdir(path):
            os.mkdir(path)

        from schools import download_from_CDS
        download_from_CDS(
            "satellite-land-cover",
            "all",
            "zip",
            "v2.1.1",
            "2020",
            "incoming_data/copernicus_lulc/archive.zip")

rule convert_lulc:
    input:
        zip="incoming_data/copernicus_lulc/archive.zip",
    output:
        tif = "incoming_data/copernicus_lulc/copernicus_lulc.tif",
    shell:
        """ 
        cd incoming_data/copernicus_lulc
        
        unzip archive.zip

        gdalwarp \
            -of Gtiff \
            -co COMPRESS=LZW \
            -ot Byte \
            -te -180.0000000 -90.0000000 180.0000000 90.0000000 \
            -tr 0.002777777777778 0.002777777777778 \
            -t_srs EPSG:4326 \
            NETCDF:C3S-LC-L4-LCCS-Map-300m-P1Y-2020-v2.1.1.nc:lccs_class \
            copernicus_lulc.tif

        """

rule lulc_clip:
    input:
        tif="incoming_data/copernicus_lulc/copernicus_lulc.tif",
        bounds="data/{ISO3}/boundaries__{ISO3}.gpkg"
    output:
        tif="data/{ISO3}/landcover__{ISO3}.tif",
    shell:
        """
        gdalwarp \
            -co COMPRESS=LZW \
            -cutline {input.bounds} \
            -cl boundaries__{wildcards.ISO3} \
            -crop_to_cutline \
            -dstnodata 0 \
            {input.tif} \
            {output.tif}
        """