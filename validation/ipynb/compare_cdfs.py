import pandas as pd
import numpy as np

def load_validation(df, time_col="traveltime", weight_col=None):
    """
    Convert household-level survey data into a sorted distribution and CDF.
    If weight_col is None, all households are weighted equally.
    """
    if weight_col is None:
        # assign weight = 1 for each row
        df = df.copy()
        df["__weight__"] = 1
        weight_col = "__weight__"
    
    # group by travel time (minutes) and sum weights
    grouped = df.groupby(time_col, as_index=False)[weight_col].sum()
    grouped = grouped.sort_values(time_col).reset_index(drop=True)

    times = grouped[time_col].to_numpy()
    weights = grouped[weight_col].to_numpy()

    cdf = np.cumsum(weights) / np.sum(weights)

    return times, cdf


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


def compare_cdfs(model_df, 
                 validation_df, 
                 tmax=120,
                 time_col="traveltime", 
                 weight_col=None):
    """
    Compute A+, A-, Aabs between model and validation CDFs.
    """
    # load data
    t_m, F_m = load_distribution(model_df)
    t_v, F_v = load_validation(validation_df, time_col, weight_col)

    # define common grid of travel times
    grid = np.arange(0, tmax + 1)

    # interpolate CDFs
    Fm = interpolate_cdf(t_m, F_m, grid)
    Fv = interpolate_cdf(t_v, F_v, grid)

    # differences
    diff = Fm - Fv

    # integrals using trapezoidal rule
    Aplus = np.trapz(np.clip(diff, 0, None), grid)
    Aminus = np.trapz(np.clip(-diff, 0, None), grid)
    Aabs = np.trapz(np.abs(diff), grid)

    # normalise by 120 min range
    Aplus_norm = Aplus / tmax
    Aminus_norm = Aminus / tmax
    Aabs_norm = Aabs / tmax

    return {
        "A+": Aplus, 
        "A-": Aminus, 
        "Aabs": Aabs,
        "A+_norm": Aplus_norm, 
        "A-_norm": Aminus_norm, 
        "Aabs_norm": Aabs_norm
    }
