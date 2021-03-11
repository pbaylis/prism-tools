# Load Wolfram Schlenker's Daily Weather Data and aggregate to some set of polygons (e.g., counties), potentially including weights (e.g., population weights)
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

# Construct mapping from PRISM cells to counties from Net Migration data ----
# Note that the Schlenker daily data is on the same raster as the PRISM daily data

# Load a single PRISM raster
PRISM_rast_files <- unzip(file.path(ANCILLARY, "samples/PRISM_tmax_stable_4kmD1_20100109_bil.zip"), exdir = TMP)
PRISM_rast <- raster(grep("\\.bil$", PRISM_rast_files, value = T))

netWisc_counties <- st_read("~/github/climate-migration/data/Wisconsin Migration Data/netMigrationCounties")

# Get geography weights 
geoweights <- rbindlist(exactextractr::exact_extract(PRISM_rast, netWisc_counties, progress = T, include_cell = T), idcol = "poly_id")
geoweights[, fips3059 := netWisc_counties$fips3059[poly_id]]
geoweights <- geoweights[, .(gridNumber = cell, fips3059, w_geo = coverage_fraction)]
geoweights[, w_geo := w_geo / sum(w_geo), by = fips3059] # Normalize within county

# Get population weights
uspop_rast <- raster(file.path(ANCILLARY, "uspop300.tif"))

# Resample (with bilinear interpolation) to align with PRISM grid
uspop_rs <- resample(uspop_rast, PRISM_rast)
popweights <- data.table(gridNumber = 1:length(uspop_rs), w_pop = getValues(uspop_rs))

weights <- merge(geoweights, popweights, by = "gridNumber")
weights[, w_pop := w_pop / sum(w_pop), by = fips3059] # Normalize within county
weights[, w := w_geo * w_pop]

weights[, w := w / sum(w), by = fips3059] # Normalize within county

# Load cell data, merge in weights, process, and save ----

aggregate_fips3059 <- function(this_year, weights) {
    # Load daily cell data and compute (potentially weighted) averages
    # weights: data.frame with gridNumber, fips3059, and w. (TODO: Make more flexible.)
    
    # DEBUG
    # this_year <- 2019
    # weights <- weights # Required variables are gridNumber, fips3059, and w
    # END DEBUG
    print(this_year)
    
    dt <- read_fst(file.path(OUT_CELL, sprintf("cell-daily-%i.fst", this_year)), as.data.table = T)
    
    # Perform a keyed merge
    setkey(dt, gridNumber)
    dt <- dt[weights, allow.cartesian = T] # Note that some cells map to multiple counties, so we need a m:m join.
    dt <- dt[!is.na(dateNum)] # Not sure why a few NAs are included after this join, but drop these
    
    # For now, just take averages over the raw variables
    agg_vars <- c("tMin", "tMax", "prec")
    agg <- dt[, lapply(.SD, weighted.mean, w = w, na.rm = T), 
              by = .(fips3059, dateNum), 
              .SDcols = agg_vars]
    
    agg
}

weather_fips3059 <- rbindlist(lapply(c(1950:1955), aggregate_fips3059, weights = weights))
# TODO: Run this when all data are ready
# weather_fips3059 <- rbindlist(lapply(c(1950:2019), aggregate_fips3059, weights = weights))

weather_fips3059 <- write_fst(weather_fips3059, file.path(OUT_FIPS, "weather-fips3059-1950-2019.fst"))

##### OLD #####

# 
# # For now, just compute CDD as degree-days above 30 and HDD as degree-days below 5. We can always try other arrangements later.
# CDD_cutoff <- 30
# HDD_cutoff <- 5
# 
# # This is similar to Nath (2021)
# cell_daily[tMax > CDD_cutoff, CDD := tMax - CDD_cutoff]
# cell_daily[is.na(CDD), CDD := 0]
# cell_daily[tMax < HDD_cutoff, HDD := HDD_cutoff - tMax]
# cell_daily[is.na(HDD), HDD := 0]
# 
# # TODO: Load in PRISM raster (which is the same as this one, I think), compute counties according to the boundaries we use for net migration
# 
# fips_daily <- cell_daily[, .(CDD = mean(CDD, na.rm = T),
#                              HDD = mean(HDD, na.rm = T)),
#                          by = .(fips, dateNum)]


##### CHECKING --- NOT IN USE RIGHT NOW #####
# 
# 
# # DEBUG: Verify that it "looks" like the right mapping between cells and rasters
# 
# # Check 1: Plot raw data to make sure it looks reasonable
# schlenker_rast <- copy(PRISM_rast)
# oneday <- cell_daily[dateNum == as.Date("2019-01-01")]
# schlenker_rast <- copy(PRISM_rast)
# schlenker_rast[] <- NA
# schlenker_rast[oneday$gridNumber] <- oneday$tMax
# plot(schlenker_rast) # YES, this looks reasonable / correct.
# 
# # Check 2: Map to FIPS and make sure they (mostly) match
# library(sf)
# library(tidyverse)
# netWisc_counties <- st_read("~/github/climate-migration/data/Wisconsin Migration Data/netMigrationCounties")
# 
# # Extract polygon weights
# weights <- rbindlist(exactextractr::exact_extract(PRISM_rast, netWisc_counties, progress = T, include_cell = T), idcol = "poly_id")
# weights[, fips3059 := netWisc_counties$fips3059[poly_id]]
# 
# oneday_check <- merge(oneday, weights, by.x = "gridNumber", by.y = "cell")
# counts_check <- oneday_check[, .N, by = .(schlenker_fips, fips3059)]
# 
# # Looks good. Most cells end up in the same FIPS in either case. Not all. But this is expected, since Wolfram is using a different county shapefile.
