# Load Wolfram Schlenker's Daily Weather Data and resave as FST
# SOURCE DATA: http://www.columbia.edu/~ws2162/links.html
## "Daily Weather Data for Contiguous United States (1950-2019) - version March 2020."
# Setup ----

library(readstata13) 
library(fst)
library(data.table)
library(stringr)
library(pbmcapply)
library(raster)
library(exactextractr)
library(sf)
library(tidyverse)

ANCILLARY <- "/data1/prism/ancillary"
TMP <- "/tmp"
OUT_CELL <- "/data1/schlenker-daily-weather/processed/daily-cell"
OUT_FIPS <- "/data1/schlenker-daily-weather/processed/daily-fips3059"

# Resave daily data, aggregating by county ----

resave_as_fst <- function(this_year) {
  # Load and resave daily weather data (provided as a .dta) as fst for quicker loading
  print(this_year)
  cell_daily <- unzip_wolfram_daily(this_year)
  write_fst(cell_daily, file.path(OUT_CELL, sprintf("cell-daily-%i.fst", this_year)), compress = 100)
}

unzip_wolfram_daily <- function(this_year, source_dir = "/data1/schlenker-daily-weather/dailyData/rawDataByYear_v2020") {
  # Unzip and load one year from the Schlenker daily dataset
  
  # DEBUG
  # this_year <- 1957; source_dir = "/data1/schlenker-daily-weather/dailyData/rawDataByYear_v2020"
  # END DEBUG
  
  # Get the location (hopefully) single file for this year
  tar_file <- list.files(path = source_dir, pattern = as.character(this_year), full.names = T)
  
  # Untar doesn't return the files it extracts, so extract once, then request a list of files it extracted
  untar(tar_file, exdir = TMP)
  extracted_files <- file.path(TMP, untar(tar_file, exdir = TMP, list = T))
  
  # Keep only the .dta files and set names to be the filename's FIPS (county) code
  dta_files <- grep("\\.dta", extracted_files, value = T)
  names(dta_files) <- str_match(dta_files, "([0-9]{3,5}).dta")[, 2]
  
  # In parallel, load and bind together all files
  cell_daily <- rbindlist(pbmclapply(dta_files, load_fips_dta, mc.cores = 12), use.names = T, idcol = "schlenker_fips")
  cell_daily[, schlenker_fips := sprintf("%05d", as.numeric(schlenker_fips))] # Restore proper padding ("1001" becomes "01001")
  
  # Delete all temporary files
  unlink(extracted_files[[1]], recursive = T)
  
  # Return cell data
  cell_daily
}

load_fips_dta <- function(dta_file) {
  # Convenience function to load a .dta file, change type to data.table, and return
  df <- read.dta13(dta_file)
  setDT(df)
  df
}

# Load and resave all of the .dta files Wolfram provides as FST ----
# This is mainly for convenience, since it will be much faster to load this in R.

# lapply(1950:2019, resave_as_fst)
lapply(1957:2019, resave_as_fst)
