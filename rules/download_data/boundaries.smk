#
# Create admin boundaries, many different formats available 
#

def boundary_bbox(wildcards):
    geom = boundary_geom(wildcards.ISO3)
    minx, miny, maxx, maxy = geom.bounds
    # LEFT,BOTTOM,RIGHT,TOP
    return f"{minx},{miny},{maxx},{maxy}"


rule geojson_boundary:
    output:
        json="data/{ISO3}/boundary__{ISO3}.geojson",
    run:
        geom = boundary_geom(wildcards.ISO3)
        json = '{"type":"Feature","geometry": %s}' % shapely.to_geojson(geom)
        with open(output.json, "w") as fh:
            fh.write(json)

rule boundaries:
    input:
        gpkg="bundled_data/ne_10m_admin_0_map_units_custom.gpkg",
    output:
        gpkg="data/{ISO3}/boundaries__{ISO3}.gpkg",
    run:
        boundaries=geopandas.read_file(input.gpkg)
        selected=boundaries[boundaries["CODE_A3"]==wildcards.ISO3]
        selected.to_file(output.gpkg)

rule zones_gadm:
    output:
        gpkg="data/{ISO3}/gadm__{ISO3}.gpkg",
    shell:
        """
        cd data/{wildcards.ISO3}
        wget https://geodata.ucdavis.edu/gadm/gadm4.1/gpkg/gadm41_{wildcards.ISO3}.gpkg --output-document=gadm__{wildcards.ISO3}.gpkg
        """

rule zones_shdi:
    input:
        shp="incoming_data/shdi/GDL Shapefiles V6.3/GDL Shapefiles V6.3 large.shp",
    output:
        gpkg="data/{ISO3}/zones_shdi__{ISO3}.gpkg"
    run:
        boundaries=geopandas.read_file(input.shp)
        selected=boundaries[boundaries["iso_code"]==wildcards.ISO3]
        selected.to_file(output.gpkg)
