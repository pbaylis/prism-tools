# Aggregate daily files by county

source("aggregate_to_poly.R")

daily_zip_files <- data.table(path = list.files(file.path(RAW, "daily"), 
                                                  pattern = "_bil\\.zip$", 
                                                  recursive = T, full.names = T))
daily_zip_files[, c("obs_type", "primacy", "period") := tstrsplit(basename(path), "_")[c(2,3,5)]]

daily_zip_files[, primacy := factor(primacy, levels = c("stable", "provisional", "early"))]
setorder(daily_zip_files, period, obs_type, primacy)
daily_zip_files <- unique(daily_zip_files, by = c("period", "obs_type"))
daily_zip_files[, date := as.IDate(period, format = "%Y%m%d")]

# Unzip a sample of the files (assumes all rasters are identical)
sample_unzipped <- unzip(daily_zip_files$path[[1]], exdir = TMP)
bil_files <- grep("_bil\\.bil$", sample_unzipped, value = T)[1]
sample_rast <- raster(bil_files)

counties <- st_read("~/Dropbox/01_Research/99_Common/geo/cb_2015_us_county_20m")
weights <- get_weights(sample_rast, counties)


for (this_year in unique(year(daily_zip_files$date))) {
  this_year <- 1981
  print(this_year)
  zip_files <- daily_zip_files[year(date) == this_year, path]
  
  poly_agg <- aggregate_prism(zip_files = zip_files,
                              weights = weights,
                              weight_var = "w_pop",
                              cut_list = list(tmax = c(-Inf, seq(5, 40, 5), Inf),
                                              tmin = c(-Inf, seq(0, 35, 5), Inf)))
  
  poly_agg[, `:=`(period = as.date(period, "%Y%m%d"),
                  poly_id = counties %>% slice(poly_id) %>% pull(GEOID))]
  setnames(poly_agg, c("period", "poly_id"), c("date", "fips"))
  
  write_fst(poly_agg, 
            file.path(PROCESSED, "daily_county_popweighted", sprintf("%s.fst", this_year)), 
            compress = 100)
}