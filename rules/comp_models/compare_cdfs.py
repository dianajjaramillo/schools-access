import pandas as pd
import numpy as np


def load_distribution(df):
    """
    Load traveltime-pop distribution and return sorted travel times and cumulative distribution.
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
    Interpolate CDF values to a common grid of travel times.
    """
    return np.interp(grid, times, cdf, left=0, right=1)


def compare_model_cdfs(model_df_1, model_df_2, tmax=180):
    """
    Compare CDFs of two models (e.g., 90m vs 1km) using A+, A-, Aabs metrics.
    
    Parameters:
        model_df_1, model_df_2: DataFrames with 'traveltime' and 'pop' columns
        tmax: maximum travel time (in minutes) to define common grid

    Returns:
        Dictionary of A+, A-, Aabs metrics (raw and normalized)
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