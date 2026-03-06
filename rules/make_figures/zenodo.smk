#
# Makes a folder with every countries traveltime map, for zenodo 
#
rule zenodo_folder:
    input:
        src="model_90m/outputs/jrcwalking/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
    output:
        dst="zenodo/v1/schools_traveltime_walking__{ISO3}.tif",
    shell:
        """
        mkdir -p zenodo/
        cp {input.src} {output.dst}
        """

with open("config/countries_list.txt") as f:
    ISO3_CODES = [line.strip() for line in f if line.strip()]

rule zenodo_all:
    input:
        expand("zenodo/v1/schools_traveltime_walking__{ISO3}.tif",
            ISO3=ISO3_CODES)

