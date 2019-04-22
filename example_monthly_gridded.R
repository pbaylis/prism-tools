# Resave raw PRISM raster data as fst for further processing.
# TODO:
# - There's something with 2016 (and maybe onward) data, but I'm not sure what it is.
#   - All NAs for the raster? Also misalignment of projections?
#   - I'm not using right now, so not a high priority for me to figure out.

library(tidyverse)
library(raster)
library(data.table)
library(fst)
library(velox)
library(stringr)
library(zoo)

DEBUG <- FALSE
TMP <- "/datatmp"
RAW <- "/data1/prism/raw"
PROCESSED <- "/data1/prism/processed"

source("~/github/prism-tools/convert_prism_to_tabular.R")

# Convert monthly to tabular -----
monthly_zip_files <- data.table(path = list.files(file.path(RAW, "monthly"), 
                                                  pattern = "_all_bil\\.zip$", 
                                                  recursive = T, full.names = T))
monthly_zip_files[, c("obs_type", "primacy", "period") := tstrsplit(basename(path), "_")[c(2,3,5)]]

monthly_zip_files[, primacy := factor(primacy, levels = c("stable", "provisional", "early"))]
setorder(monthly_zip_files, period, obs_type, primacy)
monthly_zip_files <- unique(monthly_zip_files, by = c("period", "obs_type"))

for (this_year in unique(monthly_zip_files$period)) {
  this_year <- 2016
  print(this_year)
  zip_files <- monthly_zip_files[period == this_year, path]
  
  dt <- convert_prism_to_tabular(zip_files = zip_files)
  
  dt[, `:=`(period = as.yearmon(period, "%Y%m"))]

  write_fst(dt, 
            file.path(PROCESSED, "monthly_gridded_fst", sprintf("%s.fst", this_year)), 
            compress = 100)
}



