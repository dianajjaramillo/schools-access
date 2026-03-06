#
# Download DEM and clip to country boundaries.
#
rule dem_download:
    output:
        tif="incoming_data/merit_dem/merit_dem.tif"
    shell:
        """
        mkdir -p incoming_data/merit_dem
        cd incoming_data/merit_dem
        wget https://hydro.iis.u-tokyo.ac.jp/~yamadai/MERIT_DEM/MERIT_DEM.tif
        """

rule dem_clip:
    input:
        tif="incoming_data/merit_dem/merit_dem.tif",
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


