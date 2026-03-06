#
# Clip DEM and LULC data from mistral/incoming_data folder
#

rule dem_clip:
    input:
        tif="../../../mistral/incoming_data/yamazaki-2017-merit-dem/merit_dem.tif",
        bounds="data/{ISO3}/boundaries__{ISO3}.gpkg"
    output:
        tif="data/{ISO3}/elevation__{ISO3}.tif",
    shell:
        """
        gdalwarp \
            -co COMPRESS=LZW \
            -cutline {input.bounds} \
            -cl boundaries__{wildcards.ISO3} \
            -crop_to_cutline \
            -dstnodata -9999 \
            {input.tif} \
            {output.tif}
        """

rule lulc_clip:
    input:
        tif="../../../mistral/incoming_data/copernicus-2019-landcover/C3S-LC-L4-LCCS-Map-300m-P1Y-2020-v2.1.1.tif",
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
