# Resave raw PRISM raster data as fst for further processing.

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

# Convert daily to tabular -----
daily_zip_files <- data.table(path = list.files(file.path(RAW, "daily"), 
                                                pattern = "_bil\\.zip$", 
                                                recursive = T, full.names = T))
daily_zip_files[, c("obs_type", "primacy", "period") := tstrsplit(basename(path), "_")[c(2,3,5)]]

daily_zip_files[, primacy := factor(primacy, levels = c("stable", "provisional", "early"))]
setorder(daily_zip_files, period, obs_type, primacy)
daily_zip_files <- unique(daily_zip_files, by = c("period", "obs_type"))
daily_zip_files[, date := as.IDate(period, format = "%Y%m%d")]

for (this_year in unique(year(daily_zip_files$date))) {
  print(this_year)
  zip_files <- daily_zip_files[year(date) == this_year, path]
  
  dt <- convert_prism_to_tabular(zip_files = zip_files)
  
  dt[, `:=`(period = as.IDate(period, "%Y%m%d"),
            poly_id = counties %>% slice(poly_id) %>% pull(GEOID))]
  setnames(dt, c("period", "poly_id"), c("date", "fips"))
  
  write_fst(dt, 
            file.path(PROCESSED, "daily_gridded_fst", sprintf("%s.fst", this_year)), 
            compress = 100)
}

