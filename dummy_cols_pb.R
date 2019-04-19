# Slight modification to fastDummies::dummy_cols

dummy_cols_pb <- function(.data,
                       select_columns = NULL,
                       remove_first_dummy = FALSE,
                       remove_most_frequent_dummy = FALSE,
                       sort_columns = FALSE) {
  
  stopifnot(is.null(select_columns) || is.character(select_columns),
            select_columns != "",
            is.logical(remove_first_dummy), length(remove_first_dummy) == 1)
  
  if (remove_first_dummy == TRUE & remove_most_frequent_dummy == TRUE) {
    stop("Select either 'remove_first_dummy' or 'remove_most_frequent_dummy'
         to proceed.")
  }
  
  data_type <- check_type(.data)
  
  if (!data.table::is.data.table(.data)) {
    .data <- data.table::as.data.table(.data)
  }
  
  # Grabs column names that are character or factor class -------------------
  if (!is.null(select_columns)) {
    char_cols <- select_columns
    cols_not_in_data <- char_cols[!char_cols %in% names(.data)]
    char_cols <- char_cols[!char_cols %in% cols_not_in_data]
    if (length(char_cols) == 0) {
      stop("select_columns is/are not in data. Please check data and spelling.")
    }
  } else if (ncol(.data) == 1) {
    char_cols <- names(.data)
  } else {
    char_cols <- sapply(.data, class)
    char_cols <- char_cols[char_cols %in% c("factor", "character")]
    char_cols <- names(char_cols)
  }
  
  if (length(char_cols) == 0 && is.null(select_columns)) {
    stop(paste0("No character or factor columns found. ",
                "Please use select_columns to choose columns."))
  }
  
  if (!is.null(select_columns) && length(cols_not_in_data) > 0) {
    warning(paste0("NOTE: The following select_columns input(s) ",
                   "is not a column in data.\n"),
            paste0(names(cols_not_in_data), "\t"))
  }
  
  
  for (col_name in char_cols) {
    unique_vals <- as.character(unique(.data[[col_name]]))
    
    if (remove_most_frequent_dummy) {
      vals <- as.character(.data[[col_name]])
      vals <- data.frame(sort(table(vals), decreasing = TRUE),
                         stringsAsFactors = FALSE)
      if (vals$Freq[1] > vals$Freq[2]) {
        vals <- as.character(vals$vals[2:nrow(vals)])
        unique_vals <- unique_vals[which(unique_vals %in% vals)]
        unique_vals <- vals[order(match(vals, unique_vals))]
      } else {
        remove_first_dummy <- TRUE
      }
      
    }
    
    if (remove_first_dummy) {
      unique_vals <- unique_vals[-1]
    }
    if (sort_columns) {  # Modification to sort according to given levels
      idx <- match(levels(.data[[col_name]]), unique_vals)
      idx <- idx[!is.na(idx)]
      unique_vals <- unique_vals[idx]
    }
    data.table::alloc.col(.data, ncol(.data) + length(unique_vals))
    data.table::set(.data, j = paste0(col_name, "_", unique_vals), value = 0L)
    for (unique_value in unique_vals) {
      data.table::set(.data, i =
                        which(data.table::chmatch(
                          as.character(.data[[col_name]]),
                          unique_value) == 1L),
                      j = paste0(col_name, "_", unique_value), value = 1L)
      
    }
  }
  
  .data <- fix_data_type(.data, data_type)
  return(.data)
  
}

check_type <- function(.data) {
  if (data.table::is.data.table(.data)) {
    data_type <- "is_data_table"
  } else if (tibble::is_tibble(.data)) {
    data_type <- "is_tibble"
  } else {
    data_type <- "is_data_frame"
  }
  
  return(data_type)
}

fix_data_type <- function(.data, data_type) {
  if (data_type == "is_data_frame") {
    .data <- as.data.frame(.data)
  } else if (data_type == "is_tibble") {
    .data <- tibble::as_tibble(.data)
  }
  
  return(.data)
}
