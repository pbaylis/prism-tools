# Aggregate monthly files by county

source("aggregate_to_poly.R")

monthly_zip_files <- data.table(path = list.files(file.path(RAW, "monthly"), 
                                                  pattern = "_all_bil\\.zip$", 
                                                  recursive = T, full.names = T))
monthly_zip_files[, c("obs_type", "primacy", "period") := tstrsplit(basename(path), "_")[c(2,3,5)]]

monthly_zip_files[, primacy := factor(primacy, levels = c("stable", "provisional", "early"))]
setorder(monthly_zip_files, period, obs_type, primacy)
monthly_zip_files <- unique(monthly_zip_files, by = c("period", "obs_type"))

# Unzip a sample of the files (assumes all rasters are identical)
sample_unzipped <- unzip(monthly_zip_files$path[[1]], exdir = TMP)
bil_files <- grep("_bil\\.bil$", sample_unzipped, value = T)[1]
sample_rast <- raster(bil_files)

counties_wisc <- st_read("~/github/climate_migration_v2/data/Wisconsin Migration Data/netMigrationCounties")
counties_wisc <- counties_wisc %>% 
  group_by(statename, countyname, fips3059) %>% summarize() %>% # Aggregate counties by groups
  st_cast("MULTIPOLYGON") # Cast to MULTIPOLYGON (GEOMETRY type causes issues)
weights <- get_weights(sample_rast, counties_wisc)
invisible(file.remove(sample_unzipped)) # Have to wait to remove raster .bil file until we have weights.

for (this_year in 1950:2010) {
  # this_year <- 1950
  print(this_year)
  zip_files <- monthly_zip_files[period == this_year, path]
  
  poly_agg <- aggregate_prism(zip_files = zip_files,
                              weights = weights,
                              weight_var = "w_pop",
                              cut_list = list(tmax = c(-Inf, seq(5, 40, 5), Inf),
                                              tmin = c(-Inf, seq(0, 35, 5), Inf)))
  
  write_fst(poly_agg, file.path(PROCESSED, "monthly_county_popweighted", sprintf("%s.fst", this_year)))
}