#
# Download OpenStreetMap Planet, create country file and sector extracts
#

# OSM snapshot date used by this workflow run.
# Previous snapshot retained for provenance:
# OSM_DATE = "20240401"
OSM_DATE = "20250825"
OSM_YEAR = OSM_DATE[:4]   # "2025"
OSM_YMD  = OSM_DATE[2:]   # "250825"

rule download_osm:
    output:
        pbf = protected(f"incoming_data/osm/planet-{OSM_YMD}.osm.pbf"),
    params:
        year = OSM_YEAR,
        ymd  = OSM_YMD
    shell:
        """
        mkdir -p incoming_data/osm
        cd incoming_data/osm
        aws s3 cp --no-sign-request s3://osm-planet-eu-central-1/planet/pbf/{params.year}/planet-{params.ymd}.osm.pbf .
        aws s3 cp --no-sign-request s3://osm-planet-eu-central-1/planet/pbf/{params.year}/planet-{params.ymd}.osm.pbf.md5 .
        md5sum --check planet-{params.ymd}.osm.pbf.md5
        """

rule extract_osm_data:
    input:
        pbf=f"incoming_data/osm/planet-{OSM_YMD}.osm.pbf",
        json="data/{ISO3}/boundary__{ISO3}.geojson",
    output:
        pbf=f"data/{{ISO3}}/osm_{OSM_DATE}/openstreetmap__{{ISO3}}.osm.pbf",
    shell:
        """
        osmium extract \
            --polygon {input.json} \
            --set-bounds \
            --strategy=complete_ways \
            --output={output.pbf} \
            {input.pbf}
        """

rule filter_osm_data:
    input:
        pbf=f"data/{{ISO3}}/osm_{OSM_DATE}/openstreetmap__{{ISO3}}.osm.pbf",
    output:
        pbf=f"data/{{ISO3}}/osm_{OSM_DATE}/openstreetmap_{{SECTOR}}__{{ISO3}}.osm.pbf",
    shell:
        """
        osmium tags-filter \
            --expressions=config/osm_specs/{wildcards.SECTOR}.txt \
            --output={output.pbf} \
            {input.pbf}
        """

rule convert_osm_data:
    input:
        pbf=f"data/{{ISO3}}/osm_{OSM_DATE}/openstreetmap_{{SECTOR}}__{{ISO3}}.osm.pbf",
    output:
        gpkg=f"data/{{ISO3}}/osm_{OSM_DATE}/openstreetmap_{{SECTOR}}__{{ISO3}}.gpkg",
    shell:
        """
        OSM_CONFIG_FILE=config/osm_specs/{wildcards.SECTOR}.conf.ini ogr2ogr -f GPKG -overwrite {output.gpkg} {input.pbf}
        """
    
rule clean_osm_schools:
    input:
        gpkg=f"data/{{ISO3}}/osm_{OSM_DATE}/openstreetmap_schools__{{ISO3}}.gpkg",
    output:
        gpkg="data/{ISO3}/schools_osm__{ISO3}.gpkg",
    wildcard_constraints:
        SECTOR="schools",
    run:
        import geopandas, pandas

        # read in all input layers
        points = geopandas.read_file(input.gpkg, layer='points')
        lines = geopandas.read_file(input.gpkg, layer='lines')
        polygons = geopandas.read_file(input.gpkg, layer='multipolygons')

        # find centroid of lines
        lines = lines.to_crs(3857)
        lines["geometry"] = lines.centroid
        lines = lines.to_crs(4326)

        # split up multipolygons 
        polygons = polygons.explode(index_parts=False)

        # find centroid of polygons        
        polygons = polygons.to_crs(3857)
        polygons["geometry"] = polygons.centroid
        polygons = polygons.to_crs(4326)

        # join together again 
        merged = pandas.concat([points, lines, polygons])
        merged = merged[merged["amenity"] == "school"]

        merged.to_file(output.gpkg, layer="points")
