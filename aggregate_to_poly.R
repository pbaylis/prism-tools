# Aggregate PRISM raster data to shapefiles, possibly including population weights.
# TODO:
# - Change to handle monthly or daily data.
# - Functionalize (? - Consider quadratics, should those be squared first?).
# - Get this working for daily data again.
# - Get this working using the output from the tabular data again.
# - Have it return something useful, not just poly_id?

library(tidyverse)
library(raster)
library(data.table)
library(sf)
library(fst)
library(tictoc)
library(fst)
library(velox)
library(stringr)

DEBUG <- FALSE
TMP <- "/datatmp"
RAW <- "/data1/prism/raw"
PROCESSED <- "/data1/prism/processed"
ANCILLARY <- "/data1/prism/ancillary"

source("~/github/prism-tools/dummy_cols_pb.R")

# Functions ----

#' Compute raster weights for a given polygon.
#'
#' @param rast Raster for which we are getting weights.
#' @param poly Polygon to get weights over.
#' @param normalizeWeights Flag for whether to return normalized weights by polygon. 
#' @param pop_weights Flag for whether to return population-weighted weights.
#'
#' @return data.table with the following columns: poly_id, cell, w. Also pop and w_pop if pop_weights = T.
get_weights <- function(rast, poly, normalizeWeights = T, pop_weights = T) {
  # rast = sample_rast; poly = counties_wisc; normalizeWeights = T; pop_weights = T
  
  # Use disaggregate-veloxExtract method rather than raster::extract for performance.
  # See: https://stackoverflow.com/questions/51689116/weighted-means-with-velox
  rast$cell <- 1:ncell(rast)
  brk_100 <- disaggregate(rast, fact = 10) 
  brk_100_vx <- velox(brk_100) 
  vx_raw_dt <- setDT(brk_100_vx$extract(poly, fun = NULL, df = TRUE))
  setnames(vx_raw_dt, c("poly_id", "x", "cell"))
  
  weights <- vx_raw_dt[, .(w = .N / 100), by = .(poly_id, cell)]
  if (normalizeWeights) {
    weights[, w := w / sum(w), by = poly_id]
  }
  setorder(weights, poly_id, cell)
  
  if (pop_weights) {
    uspop_rast <- raster(file.path(ANCILLARY, "uspop300.tif"))
    
    # Use resample (with, as default, bilinear interpolation) to align with PRISM grid
    uspop_rs <- resample(uspop_rast, sample_rast)
    popweights <- data.table(cell = 1:length(uspop_rs), pop = getValues(uspop_rs))
    
    weights <- merge(weights, popweights, by = c("cell"))
    weights[, w_pop := w * pop] # Not normalized, shouldn't matter
  }
  weights
}

# Given a set of zip files, a shapefile, and a flag for whether population weighting should be used
# Aggregate polygons

#' Aggregate PRISM rasters to polygons
#'
#' @param zip_files PRISM zip files to open.
#' @param in_fst path to FST file of gridded PRISM data to open. Either zip_files or in_fst is required.
#' @param weights data.table with the following columns: poly_id, id, and given weight_var
#' @param weight_var character vector of the variable to take as weight in weights
#' @param cut_list list of named character vectors, where each vector is a sequence for cut and names are the variable names to cut.
#'
#' @return NULL
aggregate_prism <- function(zip_files = NULL, in_fst = NULL, weights, weight_var, cut_list) {
  # DEBUG
  # zip_files = zip_files; in_fst = NULL
  # weights = weights; weight_var = "w_pop"
  # cut_list = list(tmax = c(-Inf, seq(5, 40, 5), Inf),
  #                 tmin = c(-Inf, seq(0, 35, 5), Inf))
  # END DEBUG
  
  if (is.null(zip_files) & is.null(in_fst)) {
    stop("At least one of zip_files or in_fst must be provided.")
  }
  
  if (!is.null(zip_files)) {
    print(sprintf("Loading zip files"))
    unzipped <- unlist(lapply(zip_files, unzip, exdir = TMP))
    bil_files <- grep("[0-9]{6,8}_bil\\.bil$", unzipped, value = T)
    
    stack <- stack(bil_files)
    dt_wide <- as.data.table(values(stack))
    invisible(file.remove(unzipped))
    
    dt_wide[, cell := 1:nrow(dt_wide)]
    dt_long <- melt(dt_wide, id.vars = "cell")
    
    # Save metadata from filenames to the data.table
    prism_meta <- data.table(variable = grep("PRISM", names(dt_wide), value = T))
    prism_meta[, c("obs_type", "period") := tstrsplit(variable, "_")[c(2,5)]]
    
    dt_long <- merge(dt_long, prism_meta, by = c("variable"))
    
    # Cast wide so columns are observation types
    dt <- dcast(dt_long, cell + period ~ obs_type, value.var = "value")
  } else {
    print(sprintf("Loading %s", in_fst))
    dt <- read_fst(in_fst, as.data.table = T, to = NULL)
    if ("date" %in% names(dt)) { 
      setnames(dt, "date", "period")
    }
  }

  # Apply binned cuts to data
  cut_names <- paste0(names(cut_list), "_cut")
  dt[, c(cut_names) := mapply(cut, x = .SD, breaks = cut_list, ordered_result = T, SIMPLIFY = F), 
     .SDcols = names(cut_list)]
  dummy_cols_pb(dt, select_columns = cut_names, sort_columns = T) # Modifies in place
  
  # Set variables to aggregate over
  agg_vars <- names(dt)[!(names(dt) %in% c("poly_id", "cell", "period", "w"))]
  agg_vars <- agg_vars[!grepl("_NA", agg_vars)] # Omit any NA cuts if they exist.
  agg_vars <- agg_vars[!grepl("_cut$", agg_vars)] # Omit any factor variables
  
  # Bring in the weights from the polygon extract operation
  dt <- merge(dt, weights[, .(poly_id, cell, w = get(weight_var))], by = "cell")
  
  # Aggregate to polygon by taking weighted means
  dt_poly <- dt[, lapply(.SD, weighted.mean, w, na.rm = T), 
                by = .(poly_id, period), .SDcols = agg_vars]
  setorder(dt_poly, poly_id, period)
  
  dt_poly
}
