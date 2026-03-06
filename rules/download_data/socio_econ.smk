#
# Download educational attainment from Graetz et al., 2018 (https://doi.org/10.1038/nature25761)
#
rule edatt_download:
    output:
        zip_f="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_YEARS_FEMALE_15_49_MEAN.zip",
        zip_m="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_YEARS_MALE_15_49_MEAN.zip",
        zip_d="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_DISPARITY_DIFF_15_49_MEAN.zip",
    shell:
        """
        mkdir -p incoming_data/edatt
        cd incoming_data/edatt
        wget https://ghdx.healthdata.org/sites/default/files/record-attached-files/IHME_AFRICA_EDU_2000_2015_YEARS_FEMALE_15_49_MEAN.zip
        wget https://ghdx.healthdata.org/sites/default/files/record-attached-files/IHME_AFRICA_EDU_2000_2015_YEARS_MALE_15_49_MEAN.zip
        wget https://ghdx.healthdata.org/sites/default/files/record-attached-files/IHME_AFRICA_EDU_2000_2015_DISPARITY_DIFF_15_49_MEAN.zip
        """
rule edatt_process:
    input: 
        zip_f="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_YEARS_FEMALE_15_49_MEAN.zip",
        zip_m="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_YEARS_MALE_15_49_MEAN.zip",
        zip_d="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_DISPARITY_DIFF_15_49_MEAN.zip",
    output:
        tif_f="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_YEARS_FEMALE_15_49_MEAN_2014_Y2018M02D28.TIF",
        tif_m="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_YEARS_MALE_15_49_MEAN_2014_Y2018M02D28.TIF",
        tif_d="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_DISPARITY_DIFF_15_49_MEAN_2014_Y2018M02D28.TIF",
    shell:
        """
        cd incoming_data/edatt
        unzip IHME_AFRICA_EDU_2000_2015_YEARS_FEMALE_15_49_MEAN.zip IHME_AFRICA_EDU_2000_2015_YEARS_FEMALE_15_49_MEAN_2014_Y2018M02D28.TIF
        unzip IHME_AFRICA_EDU_2000_2015_YEARS_MALE_15_49_MEAN.zip IHME_AFRICA_EDU_2000_2015_YEARS_MALE_15_49_MEAN_2014_Y2018M02D28.TIF
        unzip IHME_AFRICA_EDU_2000_2015_DISPARITY_DIFF_15_49_MEAN.zip IHME_AFRICA_EDU_2000_2015_DISPARITY_DIFF_15_49_MEAN_2014_Y2018M02D28.TIF
        """

rule edatt_clip:
    input:
        tif_f="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_YEARS_FEMALE_15_49_MEAN_2014_Y2018M02D28.TIF",
        tif_m="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_YEARS_MALE_15_49_MEAN_2014_Y2018M02D28.TIF",
        tif_d="incoming_data/edatt/IHME_AFRICA_EDU_2000_2015_DISPARITY_DIFF_15_49_MEAN_2014_Y2018M02D28.TIF",
        bounds="data/{ISO3}/boundaries__{ISO3}.gpkg"
    output:
        tif_f="data/{ISO3}/edatt_female__{ISO3}.tif",
        tif_m="data/{ISO3}/edatt_male__{ISO3}.tif",
        tif_d="data/{ISO3}/edatt_diff__{ISO3}.tif",
    shell:
        """
        gdalwarp \
            -co COMPRESS=LZW \
            -cutline {input.bounds} \
            -cl boundaries__{wildcards.ISO3} \
            -crop_to_cutline \
            -s_srs EPSG:4326 \
            {input.tif_f} \
            {output.tif_f}

        gdalwarp \
            -co COMPRESS=LZW \
            -cutline {input.bounds} \
            -cl boundaries__{wildcards.ISO3} \
            -crop_to_cutline \
            -s_srs EPSG:4326 \
            {input.tif_m} \
            {output.tif_m}

        gdalwarp \
            -co COMPRESS=LZW \
            -cutline {input.bounds} \
            -cl boundaries__{wildcards.ISO3} \
            -crop_to_cutline \
            -s_srs EPSG:4326 \
            {input.tif_d} \
            {output.tif_d}
        """
