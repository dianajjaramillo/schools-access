import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import json
import sys
import numpy as np

from compare_cdfs import compare_model_cdfs 

def main(iso3, path_90m, path_1km, out_fig, out_metrics,country_info_path="figures/country_data/country_info.xlsx"):
    # Load data
    df_90m = pd.read_csv(path_90m, index_col=0)
    df_1km = pd.read_csv(path_1km, index_col=0)

    # Compute metrics
    metrics = compare_model_cdfs(df_90m, df_1km, tmax=180)
    Aplus = metrics["A+"]
    Aminus = metrics["A-"]

    # Save metrics
    with open(out_metrics, "w") as f:
        json.dump(metrics, f, indent=2)

    if iso3 == "AFR":
        country_name = "Africa"
        
    else:
        # Load country name from Excel
        country_info = pd.read_excel(country_info_path)
        iso_to_name = dict(zip(country_info["ISO3"], country_info["Country"]))
        country_name = iso_to_name.get(iso3, iso3)

    # Set color palette
    color_90m = sns.color_palette()[0]  # blue
    color_1km = sns.color_palette()[2]  # green

    # Interpolate CDFs on common grid
    grid = np.arange(0, 181)
    cdf_90m = np.interp(grid, df_90m["traveltime"], np.cumsum(df_90m["pop"]) / np.sum(df_90m["pop"]), left=0, right=1)
    cdf_1km = np.interp(grid, df_1km["traveltime"], np.cumsum(df_1km["pop"]) / np.sum(df_1km["pop"]), left=0, right=1)

    # Plot comparison
    fig, ax = plt.subplots()

    # Shading A+ (90m > 1km): light blue
    ax.fill_between(grid, cdf_1km*100, cdf_90m*100, 
                    where=(cdf_90m > cdf_1km), 
                    color=color_90m, alpha=0.2, label=f"A⁺ = {Aplus:.3f}")

    # Shading A- (1km > 90m): light red
    ax.fill_between(grid, cdf_1km*100, cdf_90m*100, 
                    where=(cdf_1km > cdf_90m), 
                    color=color_1km, alpha=0.2, label=f"A⁻ = {Aminus:.3f}")

    # Plot ECDF lines
    sns.ecdfplot(data=df_90m, x="traveltime", weights="pop", stat="percent", label="Modelled population, 90m", color=color_90m)
    sns.ecdfplot(data=df_1km, x="traveltime", weights="pop", stat="percent", label="Modelled population, 1km", color=color_1km)

    # Axis formatting
    ax.set_xlim([0, 180])
    ax.set_ylim([0, 100])
    ax.set_xlabel("Travel time (minutes)")
    ax.set_ylabel("Cumulative percent (%)")
    ax.set_title(f"{country_name}", fontsize=14, fontweight='bold')
    ax.legend(loc='lower right')
    fig.tight_layout()
    fig.savefig(out_fig, dpi=300)

if __name__ == "__main__":
    iso3, path_90m, path_1km, out_fig, out_metrics = sys.argv[1:]
    main(iso3, path_90m, path_1km, out_fig, out_metrics)
