from dataclasses import dataclass
import shlex
import subprocess
from pathlib import Path
from typing import Optional
import argparse
import os

import pandas
import geopandas
import shapely
import pyproj
import cdsapi
import numpy as np
from statistics import fmean

from osgeo import gdal
from shapely.ops import transform


def download_from_CDS(dataset_name: str, variable: str, file_format: str, version: str, year: str, output_path: str) -> None:
    """
    Download one dataset resource from the Copernicus CDS API.

    Uses `cdsapi.Client` with credentials read from environment variables.

    Inputs:
        dataset_name: CDS dataset identifier.
        variable: Variable name requested from the dataset.
        file_format: Output format requested by CDS (for example, `zip`).
        version: Dataset version selector.
        year: Year selector for the request.
        output_path: Destination path for the downloaded file.

    Outputs:
        None.

    Side effects:
        Writes a downloaded file to `output_path`.
    """

    client = cdsapi.Client(
        url=os.environ.get("COPERNICUS_CDS_URL"),
        key=os.environ.get("COPERNICUS_CDS_API_KEY")
    )

    # Some CDS files require manual acceptance of licence terms, for example:
    # https://cds.climate.copernicus.eu/cdsapp/#!/terms/satellite-land-cover
    # https://cds.climate.copernicus.eu/cdsapp/#!/terms/vito-proba-v
    #
    # The example below documents an attempted programmatic acceptance approach.
    # It is retained for reference but is not currently used.
    #
    #   API_URL = os.environ.get("COPERNICUS_CDS_URL")
    #   payloads = [
    #       [{"terms_id":"vito-proba-v","revision":1}],
    #       [{"terms_id":"satellite-land-cover","revision":1}],
    #   ]
    #   for payload in payloads:
    #       client._api(
    #           url=f"{API_URL.rstrip('/')}.ui/user/me/terms-and-conditions",
    #           request=payload,
    #           method="post"
    #       )
    #
    # See https://github.com/ecmwf/cdsapi/blob/master/cdsapi/api.py

    client.retrieve(
        dataset_name,
        {
            'variable': variable,
            'format': file_format,
            'version': version,
            'year': year,
        },
        output_path
    )

def weighted_percentile(a, q, weights=None, interpolation='step'):
    """
    Compute weighted percentile value(s) for a one-dimensional array.

    Supports multiple interpolation styles used by this workflow.

    Inputs:
        a: Input values.
        q: Percentile or percentiles in the 0-100 range.
        weights: Optional non-negative weights matching `a`.
        interpolation: One of `step`, `lower`, `higher`, or `midpoint`.

    Outputs:
        A scalar percentile value for scalar `q`, otherwise a NumPy array.

    Side effects:
        None.
    """
    import numpy as np
    # sanitation check on a, q, weights
    a = np.asarray(a).flatten()
    q = np.true_divide(q, 100.0)  # handles the asarray for us too
    if q.max() > 100 or q.min() < 0:
        raise ValueError("Percentiles must be in the range [0, 100]")
    if weights is None:
        weights = np.repeat(1, a.shape)
    weights = np.asarray(weights).flatten()
    if weights.min() < 0:
        raise ValueError("Weights must be non-negative")
    if weights.max() <= 0:
        print(a)
        print(q)
        print(weights)
        raise ValueError("Total weight must be positive")
    weights = np.true_divide(weights, weights.sum())
    if weights.shape != a.shape:
        raise ValueError("Weights and input are not in the same shape")
    # sort a and weights, remove zero weights, then convert weights into cumsum
    a, weights = zip(*sorted([(a_, w_) for a_, w_ in zip(a, weights) if w_ > 0]))
    weights = np.cumsum(weights)
    # depends on the interpolation parameter, modify the vectors
    if interpolation == 'step':
        x = np.ravel(np.column_stack((a,a)))
        w = np.insert(np.ravel(np.column_stack((weights,weights)))[:-1], 0, 0)
    elif interpolation == 'lower':
        x = np.insert(a, len(a), a[-1])
        w = np.insert(weights, 0, 0)
    elif interpolation == 'higher':
        x = np.insert(a, 0, a[0])
        w = np.insert(weights, 0, 0)
    elif interpolation == 'midpoint':
        x = np.insert(np.insert(a, len(a), a[-1]), 0, a[0])
        w = [(p+q)/2 for p,q in zip(weights, weights[1:])]
        w = np.insert(np.insert(w, len(w), 1.0), 0, 0.0)
    else:
        raise NotImplementedError("Unknown interpolation method")
    # Perform a linear search over cumulative weights for each percentile.
    output = []
    for percentile in ([q] if isinstance(q, (int, float)) else q):
        if percentile <= 0:
            output.append(x[0])
        elif percentile >= 1.0:
            output.append(x[-1])
        else:
            for i, w2 in enumerate(w):
                if w2 == percentile:
                    output.append(x[i])
                    break
                elif w2 > percentile:
                    w1 = w[i-1]
                    x1, x2 = x[i-1], x[i]
                    output.append((x2-x1)*(percentile-w1)/(w2-w1) + x1)
                    break
    return output[0] if isinstance(q, (int, float)) else np.array(output)

def weighted_avg(group):
    """Compute weighted mean travel time for one grouped table.

    Inputs:
        group: DataFrame with `traveltime` and `pop` columns.

    Outputs:
        Weighted mean as a float.
    """
    return fmean(group["traveltime"], weights=group["pop"])

def weighted_percentiles(group, percentiles):
    """Compute selected weighted percentile travel times for one group.

    Inputs:
        group: DataFrame with `traveltime` and `pop` columns.
        percentiles: Iterable of percentile integers.

    Outputs:
        Dictionary keyed as `wgt_pXX`.
    """
    return {f'wgt_p{p}': weighted_percentile(group["traveltime"], p, group["pop"]) for p in percentiles}

percentiles = [20, 80]

def group_stats(group):
    """Create weighted summary statistics for grouped travel-time data.

    Inputs:
        group: DataFrame with `traveltime` and `pop` columns.

    Outputs:
        Pandas Series with weighted mean and selected weighted percentiles.
    """
    result = {}
    result["wgt_avg"] = weighted_avg(group)
    result.update(weighted_percentiles(group, percentiles))
    return pandas.Series(result)
