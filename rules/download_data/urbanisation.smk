#
# Download GHS degree of urbanisation data (epoch: 2020, resolution: 1km, coordinate system: Mollweide)
#

rule urban_deg_download:
    output:
        zip="incoming_data/urban_deg/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.tif"
    shell:
        """
        mkdir -p incoming_data/urban_deg
        cd incoming_data/urban_deg
        wget "https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_SMOD_GLOBE_R2023A/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000/V2-0/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.zip"
        unzip GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.zip
        """

rule urban_deg_clip:
    input:
        tif="incoming_data/urban_deg/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.tif",
        bounds="data/{ISO3}/boundaries__{ISO3}.gpkg",
    output:
        tif="data/{ISO3}/urban_deg__{ISO3}.tif",
    shell:
        """
        gdalwarp \
            -co COMPRESS=LZW \
            -cutline {input.bounds} \
            -crop_to_cutline \
            -t_srs EPSG:4326 \
            -tr 0.000833334065097 0.000833334065097 \
            -r near \
            -dstnodata -200 \
            {input.tif} \
            {output.tif}
        """