# Modelling School Accessibility

This workflow downloads, prepares, processes, and analyses the data required to model school accessibility for all countries in Africa.

## Setup

Clone the repository:

```bash
git clone git@github.com:dianajjaramillo/schools.git
cd schools
```

Create the environment (using [micromamba](https://mamba.readthedocs.io/)):

```bash
micromamba create -f environment.yaml
micromamba activate schools
```

---

## Generate travel time maps with AccessMod

### 1) Prepare data packages

The data packages are produced using a [`Snakemake`](https://snakemake.readthedocs.io/) workflow.

To generate data packages for **all countries in Africa**, run:

```bash
snakemake --dry-run am_prepare_all
```

You can modify the list of countries in `config/schools.txt`.

To generate a package for a **single country**, run:

```bash
snakemake --dry-run accessmod/inputs/{ISO3}/rundate.txt
```

This will generate the following folder structure:

```text
schools/
├── accessmod
│   └── inputs
│       └── {ISO3}/
```

Where `{ISO3}` is the three-letter country code (e.g., ETH, KEN, UGA).

Upload these input files into [AccessMod](https://www.accessmod.org/), then export results as a `.zip` file into:

```text
schools/
├── accessmod
│   └── outputs
│       └── {VERSION}/
│           └── {ISO3}/
```

Here `{VERSION}` is your chosen run version (e.g., `v1`).

---

### 2) Process AccessMod outputs

After saving your outputs in the correct folder, convert them into `.tif` format with:

```bash
snakemake --dry-run accessmod/outputs/{VERSION}/{ISO3}/outputs/traveltime_4326__{ISO3}.tif
```

To run this for **all countries** in your config file:

```bash
snakemake --dry-run am_process_all
```

---

### 3) Analyse travel time

Overlay population data with the travel time maps to generate accessibility metrics with:

```bash
snakemake --dry-run accessmod/outputs/{VERSION}/{ISO3}/analysis/ttpop_nat__{ISO3}.csv
```

To run this for **all countries** in your config file:

```bash
snakemake --dry-run am_analyse_all
```

---

### 4) Generate outputs

Scripts to create summary maps, plots, and tables are available in `rules/make_figures/`.

---

## Hotspot analysis

...

## Validation

...
