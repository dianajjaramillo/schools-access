import pandas as pd
import numpy as np


def load_distribution(df):
    """
    Build a cumulative distribution from modelled travel-time data.

    Inputs:
        df: DataFrame containing `traveltime` and `pop` columns.

    Outputs:
        Tuple `(times, cdf)` sorted by travel time.
    """
    # sort by travel time
    df = df.sort_values("traveltime").reset_index(drop=True)
    
    # population weights
    pop = df["pop"].to_numpy()
    times = df["traveltime"].to_numpy()

    # cumulative distribution (CDF)
    cdf = np.cumsum(pop) / np.sum(pop)

    return times, cdf

def interpolate_cdf(times, cdf, grid):
    """
    Interpolate CDF values on a shared travel-time grid.

    Inputs:
        times: Source travel-time values.
        cdf: Source cumulative probabilities.
        grid: Target grid for interpolation.

    Outputs:
        Interpolated CDF values on `grid`.
    """
    return np.interp(grid, times, cdf, left=0, right=1)


def compare_model_cdfs(model_df_1, model_df_2, tmax=180):
    """
    Compare CDFs from two model outputs using area-based metrics.

    Inputs:
        model_df_1: First model DataFrame with `traveltime` and `pop`.
        model_df_2: Second model DataFrame with `traveltime` and `pop`.
        tmax: Maximum travel-time bound (minutes) for integration.

    Outputs:
        Dictionary with raw and normalized `A+`, `A-`, and `Aabs` values.

    Side effects:
        None.
    """
    # load both model distributions
    t1, F1 = load_distribution(model_df_1)
    t2, F2 = load_distribution(model_df_2)

    # define common time grid
    grid = np.arange(0, tmax + 1)

    # interpolate to common grid
    F1_interp = interpolate_cdf(t1, F1, grid)
    F2_interp = interpolate_cdf(t2, F2, grid)

    # compute difference between CDFs
    diff = F1_interp - F2_interp

    # compute area metrics
    Aplus  = np.trapz(np.clip(diff, 0, None), grid)
    Aminus = np.trapz(np.clip(-diff, 0, None), grid)
    Aabs   = np.trapz(np.abs(diff), grid)

    # normalize by tmax
    return {
        "A+": Aplus,
        "A-": Aminus,
        "Aabs": Aabs,
        "A+_norm": Aplus / tmax,
        "A-_norm": Aminus / tmax,
        "Aabs_norm": Aabs / tmax
    }
