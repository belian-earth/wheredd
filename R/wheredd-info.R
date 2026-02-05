#' Build wheredd info file
#' This function builds the wheredd info file containing metadata about the database.
#' It is called after the database is built to save information about the database
#' such as the number of records and columns.
#' @param con A DBI connection to the wheredd database.
#' @param db_path The file path to the wheredd database.
#' @noRd
#' @keywords Internal
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


nowheredd_db_message <- function(dbpath) {
  cli::cli_abort(
    c(
      "No wheredd database found at {.path {dbpath}}",
      "i" = "Please build the database first using `carbon_proj_db()`"
    )
  )
}


find_wheredd_info <- function() {
  info_path <- fs::path(rappdirs::user_cache_dir("wheredd"), "wheredd_info.rds")
  if (!fs::file_exists(info_path)) {
    nowheredd_db_message(info_path)
  }
  readRDS(info_path)
}

wheredd_db_path <- function() {
  info <- find_wheredd_info()
  info$db_path
}


#' Display wheredd database information
#' This function reads the wheredd info file and displays information about the
#' database such as the number of records and columns.
#' @return A list containing the wheredd database information.
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
