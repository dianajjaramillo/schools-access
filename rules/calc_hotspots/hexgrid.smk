#
# Creates a hexagonal grid for the country 
#

import h3
import geopandas as gpd
import rasterio
from shapely.geometry import Polygon

def generate_hexgrid(bounds, resolution):
    hexagons = []
    h3_indices = h3.polyfill_geojson({"type": "Polygon", "coordinates": [
        [[bounds.left, bounds.bottom], [bounds.left, bounds.top],
         [bounds.right, bounds.top], [bounds.right, bounds.bottom],
         [bounds.left, bounds.bottom]]
    ]}, resolution)
    
    for h in h3_indices:
        hex_boundary = h3.h3_to_geo_boundary(h, geo_json=True)
        hexagons.append(Polygon(hex_boundary))
    
    return gpd.GeoDataFrame(geometry=hexagons, crs="EPSG:4326")

rule generate_hexgrid:
    input:
        reference="model_90m/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
    output:
        geojson="model_90m/applications/{VERSION}/{ISO3}/hexgrid__{ISO3}.geojson"
    run:
        with rasterio.open(input.reference) as src:
            bounds = src.bounds
        hexgrid = generate_hexgrid(bounds, resolution=6)
        hexgrid.to_file(output.geojson, driver="GeoJSON")

