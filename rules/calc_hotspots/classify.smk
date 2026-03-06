#
# Classifies clusters for socioeconomic hotspot exporation
#

import rasterio
from rasterio.mask import mask
import geopandas as gpd
import numpy as np


def make_thresholds(raster_paths):
    thresholds = {}

    # Travel time — fixed threshold
    thresholds["tt"] = 30

    # Education (male) — fixed threshold
    thresholds["edm"] = 6

    # Education (female) — fixed threshold
    thresholds["edf"] = 6

    # Wealth — median of valid values
    with rasterio.open(raster_paths["rwi"]) as src:
        data = src.read(1, masked=True)
        values = data.compressed()  # Get valid (non-masked) values
        thresholds["rwi"] = np.percentile(values, 50)

    return thresholds

def classify_hexagons(hexgrid, raster_paths, thresholds):
    classified_hexes = []

    for _, hexagon in hexgrid.iterrows():
        raster_stats = {}

        for key, path in raster_paths.items():
            with rasterio.open(path) as src:
                out_image, out_transform = mask(src, [hexagon.geometry], crop=True)
                values = out_image[0].flatten()
                values = values[~np.isnan(values)]

                 # Mask out nodata
                if src.nodata is not None:
                    values = values[values != src.nodata]

                # If float raster, mask NaNs too
                if np.issubdtype(values.dtype, np.floating):
                    values = values[~np.isnan(values)]

                if len(values) > 0:
                    if key == "pp":
                        raster_stats["pp_sum"] = np.sum(values)
                    else:
                        raster_stats[f"{key}_mean"] = np.mean(values)
                        raster_stats[f"{key}_def"] = np.mean(values > thresholds[key])
                else:
                    if key == "pp":
                        raster_stats["pp_sum"] = np.nan
                    else:
                        raster_stats[f"{key}_mean"] = np.nan
                        raster_stats[f"{key}_def"] = np.nan

        classified_hexes.append({"geometry": hexagon.geometry, **raster_stats})

    classified_hexes = gpd.GeoDataFrame(classified_hexes, crs="EPSG:4326")

    # Drop hexes with missing key data
    classified_hexes = classified_hexes.dropna(subset=["tt_def", "edf_def", "rwi_def"])

    # Classify clusters
    classified_hexes["cluster"] = classified_hexes.apply(classify_cluster, axis=1)

    return classified_hexes

def classify_cluster(x):
    # Critical areas: Low attainment, Low wealth, Low accessibility
    if x["tt_def"] > 0.5 and x["edf_def"] < 0.5 and x["rwi_def"] < 0.5:
        cluster = "Critical areas"
    
    # Local educational gaps: Low attainment, Low wealth, High accessibility
    elif x["tt_def"] < 0.5 and x["edf_def"] < 0.5 and x["rwi_def"] < 0.5:
        cluster = "Local educational gaps"
    
    # Underserved yet educated: High attainment, Low wealth, Low accessibility
    elif x["tt_def"] > 0.5 and x["edf_def"] > 0.5 and x["rwi_def"] < 0.5:
        cluster = "Underserved yet educated"
    
    # Well-served areas: High attainment, High wealth, High accessibility
    elif x["tt_def"] < 0.5 and x["edf_def"] > 0.5 and x["rwi_def"] > 0.5:
        cluster = "Well-served areas"
    
    # Other combinations
    else:
        cluster = "Other"
    
    return cluster


rule classify_hexagons:
    input:
        hexgrid="model_90m/applications/{VERSION}/{ISO3}/hexgrid__{ISO3}.geojson",
        tt="model_90m/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif",
        edf="data/{ISO3}/edatt_female__{ISO3}.tif",
        edm="data/{ISO3}/edatt_male__{ISO3}.tif",
        rwi="data/{ISO3}/rwi__{ISO3}.tif",
        pp="data/{ISO3}/pop_ghs__{ISO3}.tif",
    output:
        gpkg="model_90m/applications/{VERSION}/{ISO3}/classified_hexgrid__{ISO3}.gpkg"
    run:
        import rasterio

        # Check CRS of all rasters
        def ensure_epsg4326(path):
            with rasterio.open(path) as src:
                if src.crs.to_epsg() != 4326:
                    raise ValueError(f"Raster {path} is not EPSG:4326!")
        
        ensure_epsg4326(input.tt)
        ensure_epsg4326(input.edf)
        ensure_epsg4326(input.edm)
        ensure_epsg4326(input.rwi)
        ensure_epsg4326(input.pp)

        hexgrid = gpd.read_file(input.hexgrid)

        thresholds = make_thresholds({
            "tt": input.tt,
            "edf": input.edf,
            "rwi": input.rwi
        })

        print(thresholds)

        classified_hexgrid = classify_hexagons(
            hexgrid,
            {
                "tt": input.tt,
                "edf": input.edf,
                "edm": input.edm,
                "rwi": input.rwi,
                "pp": input.pp
            },
            thresholds
        )
        classified_hexgrid.to_file(output.gpkg, driver="GPKG")

