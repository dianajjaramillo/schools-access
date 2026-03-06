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
    Download a resource from the Copernicus CDS API, given appropriate credentials.

    Requires COPERNICUS_CDS_URL and COPERNICUS_CDS_API_KEY to be in the environment.
    For more details see: https://cds.climate.copernicus.eu/api-how-to

    Args:
        dataset_name: Name of dataset to download
        variable: Name of variable to request
        file_format: Desired file format e.g. zip
        version: Version of dataset
        year: Year of dataset applicability
        output_path: Where to save the downloaded file
    """

    client = cdsapi.Client(
        url=os.environ.get("COPERNICUS_CDS_URL"),
        key=os.environ.get("COPERNICUS_CDS_API_KEY")
    )

    # N.B. Files are covered by licences which need to be manually accepted, e.g.
    # https://cds.climate.copernicus.eu/cdsapp/#!/terms/satellite-land-cover
    # https://cds.climate.copernicus.eu/cdsapp/#!/terms/vito-proba-v
    #
    # Ideally we could programmatically accept the necessary licence conditions
    # the below code is an attempt at that, but fails with an HTTP 403, not
    # logged in when trying to simulate a user acceptance 
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
    Compute the qth percentile of the data a, optionally weight can be provided.
    Returns the qth percentile(s) of the array elements.

    Methodology
    -----------
    If weights are not provided, we set all `a` of equal weight of 1. Then we
    normalize the weight by equal factor so that their sum is 1. Then, in sorted
    ascending order of `a`, we plot the values as a curve from 0 to 1 and lookup
    the values corresponding to `q` from the curve.

    Shape of the curve is determined by the parameter `interpolation`. If it is
    'step', the curve is cadlag steps; if 'lower', we set the leftmost edge of
    each step as the corresponding value in `a` and interpolate the adjacent
    values except the last one, which we carry the horizontal step forward to
    1.0; if 'higher', it is similar to the case of 'lower' but we set the value
    at the rightmost edge of each step instead and the horizontal step is
    preserved at the minimum value; if 'midpoint', we set the value at the
    middle of each step and the half steps at the minimum and maximum is
    preserved as horizontal.

    Parameters
    ----------
    a : array_like of float
        Input array or object that can be converted to an array.
    q : array_like of float
        Percentile or sequence of percentiles to compute, which must be between
        0 and 100 inclusive.
    weights : array_like of float, optional
        if provided, must be the same dimension as `a` and all elements are
        non-negative. This is the weights to be used
    interpolation : {'step', 'lower', 'higher', 'midpoint'}

    Returns
    -------
    percentile : scalar or ndarray
        If `q` is a single percentile and `axis=None`, then the result
        is a scalar. If multiple percentiles are given, first axis of
        the result corresponds to the percentiles. The other axes are
        the axes that remain after the reduction of `a`. If the input
        contains integers or floats smaller than ``float64``, the output
        data-type is ``float64``. Otherwise, the output data-type is the
        same as that of the input. If `out` is specified, that array is
        returned instead.
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
    # linear search of weights by each element of q
    # TODO we can do binary search instead
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

# Define the weighted average and weighted percentiles functions
def weighted_avg(group):
    return fmean(group["traveltime"], weights=group["pop"])

def weighted_percentiles(group, percentiles):
    return {f'wgt_p{p}': weighted_percentile(group["traveltime"], p, group["pop"]) for p in percentiles}

# List of percentiles you want to calculate
percentiles = [20, 80]  # Modify this list as needed

# Apply the functions to each group
def group_stats(group):
    result = {}
    result["wgt_avg"] = weighted_avg(group)
    result.update(weighted_percentiles(group, percentiles))
    return pandas.Series(result)