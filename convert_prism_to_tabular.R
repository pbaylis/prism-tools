#' Aggregate PRISM rasters to polygons
#'
#' @param zip_files PRISM zip files to convert
#' 
#' @import data.table
#' @import raster
#' @return data.table PRISM data
convert_prism_to_tabular <- function(zip_files = NULL) {
  print(sprintf("Loading zip files"))
  unzipped <- unlist(lapply(zip_files, unzip, exdir = TMP))
  bil_files <- grep("[0-9]{6,8}_bil\\.bil$", unzipped, value = T)
  
  print("Stacking")
  stack <- stack(bil_files)
  dt_wide <- as.data.table(values(stack))
  rm("stack")
  invisible(file.remove(unzipped))
  
  dt_wide[, cell := 1:nrow(dt_wide)]
  print("Melting")
  dt_long <- melt(dt_wide, id.vars = "cell")

  # Save metadata from filenames to the data.table
  prism_meta <- data.table(variable = grep("PRISM", names(dt_wide), value = T))
  prism_meta[, c("obs_type", "period") := tstrsplit(variable, "_")[c(2,5)]]
  
  print("Merging to metadata")
  rm("dt_wide")
  dt_long <- merge(dt_long, prism_meta, by = c("variable"))
  
  # Cast wide so columns are observation types
  print("Casting")
  dt <- dcast(dt_long, cell + period ~ obs_type, value.var = "value")
  rm("dt_long")
  dt
}
