#' Build wheredd Info File
#'
#' @description
#' Creates and saves metadata about the wheredd database to an RDS file. This
#' function is called internally after the database is built to store information
#' such as path, creation date, size, and row/column counts.
#'
#' @param con A DBI connection object to the wheredd database.
#' @param db_path Character string containing the file path to the wheredd database.
#'
#' @return NULL (called for side effects - saves info file to cache)
#'
#' @details
#' The info file is saved to the user's cache directory as "wheredd_info.rds"
#' and contains:
#' - `db_path`: Full path to the database file
#' - `db_date`: Timestamp of database creation
#' - `db_size`: Size of the database file
#' - `nrecords`: Total number of records in redd_projects table
#' - `ncols`: Total number of columns in redd_projects table
#'
#' @noRd
#' @keywords internal
build_whereredd_info <- function(con, db_path) {
  nrecords <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM redd_projects"
  )$n

  ncols <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) FROM (DESCRIBE redd_projects)"
  )$count

  whereredd_info <- list(
    db_path = db_path,
    db_date = Sys.time(),
    db_size = fs::file_size(db_path),
    nrecords = nrecords,
    ncols = ncols
  )

  saveRDS(
    whereredd_info,
    fs::path(rappdirs::user_cache_dir("wheredd"), "wheredd_info.rds")
  )
}


#' Display Error Message for Missing Database
#'
#' @description
#' Internal helper function that throws an informative error when the wheredd
#' database cannot be found at the expected location.
#'
#' @param dbpath Character string containing the path where the database was
#'   expected to be found.
#'
#' @return This function does not return - it always throws an error.
#'
#' @noRd
#' @keywords internal
nowheredd_db_message <- function(dbpath) {
  cli::cli_abort(
    c(
      "No wheredd database found at {.path {dbpath}}",
      "i" = "Please build the database first using `carbon_proj_db()`"
    )
  )
}


#' Find and Load wheredd Info File
#'
#' @description
#' Internal function that locates and reads the wheredd info file from the
#' cache directory. Throws an error if the file does not exist.
#'
#' @return A list containing wheredd database metadata (path, date, size,
#'   record count, column count).
#'
#' @details
#' This function looks for the info file at:
#' `{rappdirs::user_cache_dir("wheredd")}/wheredd_info.rds`
#'
#' If the file is not found, it calls `nowheredd_db_message()` which throws
#' an informative error suggesting to build the database first.
#'
#' @noRd
#' @keywords internal
find_wheredd_info <- function() {
  info_path <- fs::path(rappdirs::user_cache_dir("wheredd"), "wheredd_info.rds")
  if (!fs::file_exists(info_path)) {
    nowheredd_db_message(info_path)
  }
  readRDS(info_path)
}

#' Get wheredd Database Path
#'
#' @description
#' Internal function that retrieves the file path to the wheredd database
#' from the cached info file.
#'
#' @return Character string containing the full path to the wheredd database.
#'
#' @details
#' This function reads the info file and extracts the `db_path` element.
#' If the database or info file doesn't exist, it will throw an error via
#' `find_wheredd_info()`.
#'
#' @noRd
#' @keywords internal
wheredd_db_path <- function() {
  info <- find_wheredd_info()
  info$db_path
}


#' Display wheredd Database Information
#'
#' @description
#' Reads and displays metadata about the wheredd database including its location,
#' creation date, size, and content summary.
#'
#' @return A list containing the wheredd database information, returned invisibly.
#'   The list contains:
#'   - `db_path`: Full path to the database file
#'   - `db_date`: Timestamp of database creation
#'   - `db_size`: Size of the database file (fs_bytes object)
#'   - `nrecords`: Total number of records in the database
#'   - `ncols`: Total number of columns in the database
#'
#' @details
#' The function looks for the info file in the user's cache directory. If no
#' database has been built yet, it displays a warning and returns NULL invisibly.
#'
#' Information is displayed to the console using cli formatting for readability.
#'
#' @examples
#' \dontrun{
#' # Display database information
#' whereredd_info()
#'
#' # Capture the info for programmatic use
#' info <- whereredd_info()
#' print(info$nrecords)
#' }
#'
#' @export
whereredd_info <- function() {
  info_path <- fs::path(rappdirs::user_cache_dir("wheredd"), "wheredd_info.rds")
  if (!fs::file_exists(info_path)) {
    cli::cli_alert_warning("No wheredd info file found at {.path {info_path}}")
    return(invisible(NULL))
  }
  whereredd_info <- readRDS(info_path)
  cli::cli_h1("wheredd Database Information")
  cli::cli_text("Database path: {.path {whereredd_info$db_path}}")
  cli::cli_text("Database created on: {.field {whereredd_info$db_date}}")
  cli::cli_text(
    "Database size: {.field {format(whereredd_info$db_size, units = 'auto')}}"
  )
  cli::cli_text("Number of records: {.field {whereredd_info$nrecords}}")
  cli::cli_text("Number of columns: {.field {whereredd_info$ncols}}")
  invisible(whereredd_info)
}
