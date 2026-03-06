import json
import shutil
from pathlib import Path
from glob import glob

import geopandas
import schools
import pandas
import requests
import shapely

include: "rules/download_data/boundaries.smk"
include: "rules/download_data/openstreetmap.smk"
include: "rules/download_data/merit_dem.smk"
include: "rules/download_data/copernicus_lulc.smk"
include: "rules/download_data/pop_ghs.smk"
include: "rules/download_data/pop_wp.smk"
include: "rules/download_data/socio_econ.smk"
include: "rules/download_data/urbanisation.smk"
include: "rules/download_data/rwi.smk"
include: "rules/download_data/schools_jrc.smk"
include: "rules/download_data/schools_giga.smk"
include: "rules/download_data/schools_merged.smk"

include: "rules/run_model90m/prepare.smk"
include: "rules/run_model90m/process.smk"
include: "rules/run_model90m/analyse.smk"

include: "rules/run_model1km/workflow.smk"
include: "rules/run_model1km/monergirona.smk"

include: "rules/calc_hotspots/hexgrid.smk"
include: "rules/calc_hotspots/classify.smk"

include: "rules/make_figures/maps.smk"
include: "rules/make_figures/tables.smk"
include: "rules/make_figures/plots.smk"
include: "rules/make_figures/zenodo.smk"

include: "rules/comp_models/supmat.smk"
