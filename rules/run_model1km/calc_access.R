# Accessibility mapping with `gdistance` (R)
#
# Provenance:
# - Original script credits: Dan Weiss, Telethon Kids Institute / Malaria Atlas Project.
# - Integrated here as part of the Snakemake-based school accessibility workflow.
#
# Purpose:
# - Read a friction surface raster and a CSV of school point coordinates.
# - Build a transition matrix and compute accumulated travel cost to nearest points.
# - Write the resulting accessibility raster.
#
# Runtime context:
# - Inputs and outputs are supplied by Snakemake (`snakemake@input` / `snakemake@output`).
# - Requires the `gdistance` package:
#   https://cran.r-project.org/web/packages/gdistance/index.html
#
# References:
# - Weiss et al. (2020), Nature Medicine.
# - Nelson et al. (2019), Scientific Data.
# - Weiss et al. (2018), Nature.
# 

## Required Packages
require(gdistance)

# User-defined extent variables for optional clipping from a global layer.
# This can also be accomplished by importing a polygon boundary.
# Geographic Coordinates (WGS84)
# left   <- -2.0
# right  <- 0.0
# bottom <- 50.0
# top    <- 52.0
transition.matrix.exists.flag <- 0 # If the geo-corrected graph already exists, this can reduce runtime.

# Input Files
# Note: the alternate, 'walking_only' friction surface is named friction_surface_2019_v51_walking_only.tif
friction.surface.filename <- snakemake@input[["friction"]]
point.filename <- snakemake@input[["schools"]] # Two columns: [X_COORD, Y_COORD] with a header.

# Output Files
T.filename <- snakemake@output[["T"]]
T.GC.filename <- snakemake@output[["GC"]]
output.filename <- snakemake@output[["access"]]

# Read in the points table
points <- read.csv(file = point.filename)

# Fetch the number of points
temp <- dim(points)
n.points <- temp[1]

#  Define the spatial template
# friction <- raster(friction.surface.filename)
# fs1 <- crop(friction, extent(left, right, bottom, top))
# Use the following line instead of the preceding 2 if clipping is not needed.
# Global runs typically exceed practical computational capacity.
fs1 <- raster(friction.surface.filename) 

# Make the graph and the geocorrected version of the graph (or read in the latter).
if (transition.matrix.exists.flag == 1) {
  # Read in the transition matrix object if it has been pre-computed
  T.GC <- readRDS(T.GC.filename)
} else {
  # Make and geocorrect the transition matrix (i.e., the graph)
  T <- transition(fs1, function(x) 1/mean(x), 8) # RAM intensive, can be very slow for large areas
  saveRDS(T, T.filename)
  T.GC <- geoCorrection(T)                    
  saveRDS(T.GC, T.GC.filename)
}

# Convert the points into a matrix
xy.data.frame <- data.frame()
xy.data.frame[1:n.points,1] <- points[,1]
xy.data.frame[1:n.points,2] <- points[,2]
xy.matrix <- as.matrix(xy.data.frame)

# Run the accumulated cost algorithm to make the final output map. This can be quite slow (potentially hours).
temp.raster <- accCost(T.GC, xy.matrix)

# Write the resulting raster
writeRaster(temp.raster, output.filename)
