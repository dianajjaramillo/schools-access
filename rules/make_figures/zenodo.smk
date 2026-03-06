#
# Create a Zenodo-ready folder with country travel-time rasters.
#
rule zenodo_folder:
    input:
        src="model_90m/outputs/jrcwalking/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
    output:
        dst="zenodo/traveltime/schools_traveltime_walking__{ISO3}.tif",
    shell:
        """
        mkdir -p zenodo/traveltime/
        gdal_translate -of GTiff -co COMPRESS=DEFLATE -mo DESCRIPTION=traveltime_mins {input.src} {output.dst}
        """

with open("config/countries_list.txt") as f:
    ISO3_CODES = [line.strip() for line in f if line.strip()]

rule zenodo_all:
    input:
        expand("zenodo/traveltime/schools_traveltime_walking__{ISO3}.tif",
            ISO3=ISO3_CODES)


rule zenodo_upload_traveltime:
    input:
        rasters=rules.zenodo_all.input
    output:
        stamp="zenodo/upload_rundate.txt"
    shell:
        r"""
        set -euo pipefail

        TOKEN="${{ZENODO_TOKEN:-}}"
        if [ -z "$TOKEN" ] && [ -f .env ]; then
            TOKEN="$(grep -E '^ZENODO_TOKEN=' .env | head -n 1 | cut -d '=' -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
        fi

        if [ -z "$TOKEN" ]; then
            echo "ZENODO_TOKEN missing. Add it to env or .env" >&2
            exit 1
        fi

        BUCKET_URL="$(curl --fail --silent --show-error \
            "https://zenodo.org/api/deposit/depositions/15261112?access_token=${{TOKEN}}" \
            | python3 -c 'import json,sys; print(json.load(sys.stdin)["links"]["bucket"])')"

        if [ -z "$BUCKET_URL" ]; then
            echo "Could not resolve Zenodo bucket URL for deposition 15261112" >&2
            exit 1
        fi

        for f in {input.rasters}; do
            curl --fail --silent --show-error \
                --upload-file "$f" \
                "${{BUCKET_URL}}/$(basename "$f")?access_token=${{TOKEN}}"
        done

        date -u +"%Y-%m-%dT%H:%M:%SZ" > {output.stamp}
        """
