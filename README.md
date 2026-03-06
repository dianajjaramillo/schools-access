# Modelling School Accessibility Across Africa
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.15261112.svg)](https://doi.org/10.5281/zenodo.15261112)
![Workflow](https://img.shields.io/badge/workflow-Snakemake-brightgreen)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

This repository accompanies the following publication and dataset release.

**Paper**  
Jaramillo-Araujo, D., & Hall, J. W. (2026). *Mapping School Accessibility in Africa: High-Resolution Spatial Analysis Uncovers Inequalities in Education Access.* Sustainable Development. https://doi.org/10.1002/sd.70920 *(in production)*

**Data**  
The processed travel-time rasters generated in this study are archived on Zenodo:  
https://doi.org/10.5281/zenodo.15261112

## Repository Description

This repository contains the workflow used to generate the travel-time accessibility analysis presented in the accompanying publication.

The workflow is implemented with [Snakemake](https://snakemake.readthedocs.io/) and uses Python and R scripts. The main 90 m workflow is centered on AccessMod input preparation, manual AccessMod execution, output processing, and population-overlay analysis.

## Reproducibility

This repository documents and reproduces the published workflow structure and processing steps.

Important notes:
- AccessMod model runs are external and manual. This repository prepares inputs and processes outputs.
- Several upstream datasets are downloaded from third-party sources and remain subject to their own availability, versioning, and license terms.

## Setup

Clone the repository:

```bash
git clone git@github.com:dianajjaramillo/schools-access.git
cd schools-access
```

Create and activate the environment (using [micromamba](https://mamba.readthedocs.io/)):

```bash
micromamba create -f environment.yaml
micromamba activate schools
```

## Required Credentials

Some download rules require API credentials for third-party data providers.  
These credentials should be added to the `.env` file in the repository root.

Users must generate their own API keys by following the instructions provided by the respective data providers.

The following environment variables are required:

- `GIGA_API_KEY` – API key for accessing the Giga school-location API.
- `COPERNICUS_CDS_URL` – Copernicus Climate Data Store API URL.
- `COPERNICUS_CDS_API_KEY` – Copernicus Climate Data Store API key.

If these credentials are not provided, the corresponding download steps in the workflow will fail.

## Workflow Overview

Country coverage is defined in `config/countries_list.txt`.

### 1) Prepare AccessMod input packages

Run all countries:

```bash
snakemake --dry-run am_prepare_all
```

Run a single country:

```bash
snakemake --dry-run model_90m/inputs/{ISO3}/rundate.txt
```

This stage prepares model inputs and writes upload-ready files under `accessmod/inputs/{ISO3}/`.

### 2) Run AccessMod manually

Upload `accessmod/inputs/{ISO3}/` into AccessMod and export result zip files to:

```text
model_90m/outputs/{VERSION}/{ISO3}/
```

### 3) Process AccessMod outputs

Run all countries:

```bash
snakemake --dry-run am_process_all
```

Run a single country:

```bash
snakemake --dry-run model_90m/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif
```

### 4) Analyse travel-time outputs

Run all countries:

```bash
snakemake --dry-run am_analyse_all
```

Run a single country:

```bash
snakemake --dry-run model_90m/outputs/{VERSION}/{ISO3}/analysis/ttpop_nat__{ISO3}.csv
```

### 5) Figures, tables, and supplementary outputs

Additional outputs are defined in:
- `rules/make_figures/`
- `rules/calc_hotspots/`
- `rules/comp_models/`
- `validation/`

## Repository Structure

- `Snakefile`: top-level workflow entrypoint (includes all rule modules).
- `rules/`: Snakemake modules for data download, modelling, analysis, and outputs.
- `config/`: country list, OSM extraction specs, and travel-speed scenario CSV files.
- `src/schools/`: helper Python functions used by rules.
- `validation/`: validation notebooks and comparison artifacts.

## What Is Included / Not Included

Included:
- Workflow definitions, scripts, and configuration used for the published analysis.
- Validation notebooks and selected derived comparison outputs.

Not included (or externally managed):
- Full raw third-party datasets requiring separate download.
- AccessMod runtime environment and execution itself.
- Any guarantees that upstream providers retain identical file versions indefinitely.

## License
Code in this repository is licensed under the MIT License.
The accompanying dataset archived on Zenodo is released under CC-BY 4.0.

Note that third-party datasets used in this workflow may be subject to their own licenses and terms of use.