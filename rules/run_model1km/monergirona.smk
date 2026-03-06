#
# 
#

with open("config/countries_list.txt") as f:
    ISO3_CODES = [line.strip() for line in f if line.strip() and line.strip() != "EGY"]

rule analyse_all_1km:
    input:
        expand("model_1km/outputs/{SOURCE}/{ISO3}/analysis/ttpop_nat__{ISO3}.csv", 
            SOURCE="monergirona", 
            ISO3=[c for c in ISO3_CODES if c != "EGY"])

rule analyse_all_urb_1km:
    input:
        expand("model_1km/outputs/{SOURCE}/{ISO3}/analysis/ttpopurb_nat__{ISO3}.csv", 
            SOURCE="monergirona", 
            ISO3=[c for c in ISO3_CODES if c != "EGY"])

rule download_monergirona:
	output:
		tif="incoming_data/monergirona/ttimeschool_africa.tif",
	shell:
		"""
		mkdir -p incoming_data/monergirona
		wget -O {output} "https://africa-knowledge-platform.ec.europa.eu/geoserver/akp/ows?service=WCS&version=2.0.1&request=GetCoverage&coverageId=akp__ttimeschool&subset=Long(-17.60006,51.49991)&subset=Lat(-35.00001,37.59996)&format=image/tiff"
        """

rule clip_monergirona:
    input:
        tif="incoming_data/monergirona/ttimeschool_africa.tif",
        bounds="data/{ISO3}/boundaries__{ISO3}.gpkg",
    output:
        tif="model_1km/outputs/monergirona/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
    shell:
        """
        gdalwarp \
            -cutline {input.bounds} \
            -crop_to_cutline \
            -s_srs EPSG:4326 \
            {input.tif} \
            temp__{wildcards.ISO3}.tif

        gdal_calc.py \
            -A temp__{wildcards.ISO3}.tif \
            --outfile={output.tif} \
            --calc="A*60" \
            --overwrite 
            
        # Clean up temp file
        rm temp__{wildcards.ISO3}.tif
        """	