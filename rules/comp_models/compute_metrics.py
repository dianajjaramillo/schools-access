import rasterio
import numpy as np
import json
import sys

def compute_exposure_metrics(diff_raster_path, pop_raster_path, output_path):
    with rasterio.open(diff_raster_path) as diff_src, rasterio.open(pop_raster_path) as pop_src:
        diff = diff_src.read(1, masked=True)
        pop = pop_src.read(1, masked=True)

        # Apply valid mask
        mask = (~diff.mask) & (~pop.mask) & (pop.data > 0)
        diff_data = diff.data[mask]
        pop_data = pop.data[mask]

        # Compute stats
        pop_total = np.sum(pop_data)
        pop_15plus = np.sum(pop_data[diff_data > 15])
        pop_15minus = np.sum(pop_data[diff_data < -15])

        results = {
            "pop_total": float(pop_total),
            "pop_15plus": float(pop_15plus),
            "pop_15minus": float(pop_15minus),
            "pct_15plus": float(pop_15plus / pop_total * 100),
            "pct_15minus": float(pop_15minus / pop_total * 100),
        }

        with open(output_path, "w") as f:
            json.dump(results, f, indent=2)

def compute_exposure_metrics_v1(diff_raster_path, pop_raster_path, output_path):
    with rasterio.open(diff_raster_path) as diff_src, rasterio.open(pop_raster_path) as pop_src:
        diff = diff_src.read(1, masked=True)
        pop = pop_src.read(1, masked=True)

        # Apply valid mask
        mask = (~diff.mask) & (~pop.mask) & (pop.data > 0)
        diff_data = diff.data[mask]
        pop_data = pop.data[mask]

        # Compute stats
        abs_diff = np.abs(diff_data)
        pop_total = np.sum(pop_data)
        pop_diff_gt15 = np.sum(pop_data[abs_diff > 15])
        #mean_abs_diff = np.sum(abs_diff * pop_data) / pop_total
        pop_gain = np.sum(pop_data[diff_data < 0])
        pop_loss = np.sum(pop_data[diff_data > 0])

        # Fix: handle potential NaNs in weighted mean calculation
        valid = np.isfinite(abs_diff) & np.isfinite(pop_data)
        if valid.sum() > 0:
            mean_abs_diff = np.sum(abs_diff[valid] * pop_data[valid]) / np.sum(pop_data[valid])
        else:
            mean_abs_diff = np.nan

        results = {
            "pop_total": float(pop_total),
            "pop_diff_gt15": float(pop_diff_gt15),
            "mean_abs_diff": float(mean_abs_diff),
            "pop_gain": float(pop_gain),
            "pop_loss": float(pop_loss),
            "pct_diff_gt15": float(pop_diff_gt15 / pop_total * 100),
            "pct_gain": float(pop_gain / pop_total * 100),
            "pct_loss": float(pop_loss / pop_total * 100),
        }

        with open(output_path, "w") as f:
            json.dump(results, f, indent=2)

if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise ValueError("Usage: python compute_exposure_metrics.py <diff_raster> <pop_raster> <output_json>")
    compute_exposure_metrics(sys.argv[1], sys.argv[2], sys.argv[3])
