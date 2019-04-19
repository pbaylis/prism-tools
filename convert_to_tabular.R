# Convert PRISM raster files to tabular data, saved as FST. 
# TODO:
# - Get this working for the monthly data as well. Currently only works for daily.
# - Save field indicating date or ym as "period" to avoid issues in aggregate_to_poly

library(raster)
library(data.table)
library(tools)
library(parallel)
library(fst)

rm(list=ls())
DB <- "/data1/Dropbox/"
GEO <- paste0(DB, "01_Work/01_Current/99_Common/geo/")
RAW <- "/data1/prism/raw/daily"

EXPECTED.CELLS <- 481631
REMOVE.OBSOLETE <- FALSE # Remove obsolete zip files (dangerous!)
TMP <- "/datatmp" # TMP
OUT <- "/data1/prism/processed/gc"

dt_from_rast_zip <- function(zip.file) {
  # Take in filename, return data table with date and measure
  # zip.file <- "/data1/prism/data/daily/ppt/2015/PRISM_ppt_stable_4kmD2_20150101_bil.zip" # DEBUG
  print(zip.file)
  unzip(zip.file, exdir = TMP)
  
  base.name <- file_path_sans_ext(basename(zip.file))

  rast <- raster(file.path(TMP, paste0(base.name, ".bil"))) 
  dt <- data.table(value=getValues(rast))
  desc <- strsplit(rast@data@names, "_")[[1]]

  dt[, `:=`(gc=1:nrow(dt),
            date=as.IDate(desc[5], "%Y%m%d"), 
            meas=desc[2])]
  dt <- dt[!is.na(value)] # Not interpolating, so we can drop these
  # Check number of rows.
  if (nrow(dt) != EXPECTED.CELLS) {
    stop(sprintf("%s did not have the expected number of non-missing cells. %i found, %i expected.", 
                 zip.file, nrow(dt), EXPECTED.CELLS))
  }
  # Erase unzipped files
  erase.files <- list.files(path=TMP, 
                            pattern=base.name, full.names=T)
  file.remove(erase.files)
  return(dt)
} 

# Run by year
for (year in 1981:2017) {
  # year <- 2015 # DEBUG
  print(year)
  meas <- "*"
  pattern <- glob2rx(paste0("PRISM_", meas,"_*_*_",year,"*_bil.zip"))
  
  all.files <- data.table(filename=list.files(path=RAW, 
                                              pattern=pattern, recursive=T, full.names=T))
  
  # Keep only the best data for each date
  all.files[, `:=`(meas=tstrsplit(all.files$filename, split="_")[[2]],
                   date=as.IDate(tstrsplit(all.files$filename, split="_")[[5]], "%Y%m%d"),
                   priority=tstrsplit(all.files$filename, split="_")[[3]])]
  
  all.files[,priority.num:=ifelse(priority=="stable", 1, 
                                  ifelse(priority=="provisional", 2, 3))]
  setorder(all.files, meas, date, priority.num)
  best.files <- all.files[!duplicated(all.files, by=c("meas", "date"))]
  
  # Wipe out old files if necessary
  obsolete.files <- all.files[duplicated(all.files, by=c("meas", "date"))]
  if (nrow(obsolete.files) > 0 & REMOVE.OBSOLETE == TRUE) {
    print(paste("Removing", nrow(obsolete.files), "files"))
    file.remove(obsolete.files$filename)
  }
  
  # Don't parallelize, it breaks
  year.dt <- rbindlist(lapply(best.files$filename, dt_from_rast_zip))
  
  # Cast to wide
  year.dt <- dcast(year.dt, gc + date ~ meas)
  out.file <- paste0("prism_gc_", year, ".fst")
  print(paste("Saving", out.file))
  write_fst(year.dt, file.path(OUT, out.file), compress = 100)
}

prism_list <- list.files(OUT, "\\.Rds", full.names = T)

foo <- function(prism_in) {
  print(prism_in)
  prism_out <- sub("\\.Rds", "\\.fst", prism_in)
  data <- readRDS(prism_in)
  write_fst(data, prism_out, compress = 100)
  NULL
}

lapply(prism_list, foo)
