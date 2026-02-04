redd_src_urls <- function(
  continents = c(
    "africa",
    "asia",
    "europe",
    "north_america",
    "oceania",
    "south_america"
  )
) {
  continents <- rlang::arg_match(continents, multiple = TRUE)
  glue::glue(
    "https://data.source.coop/cecil/forest-carbon-boundaries/{continents}.parquet"
  )
}


redd_db <- function(
  dest = NULL,
  db_name = "wheredd_db",
  continents = c(
    "africa",
    "asia",
    "europe",
    "north_america",
    "oceania",
    "south_america"
  ),
  force = FALSE
) {
  if (is.null(dest)) {
    dest <- rappdirs::user_cache_dir("wheredd")
  }
  fs::dir_create(dest)

  db_path <- fs::path(dest, db_name, ext = "duckdb")
  if (fs::file_exists(db_path)) {
    if (force) {
      cli::cli_alert_info("Removing existing database at {.path {db_path}}")
      fs::file_delete(db_path)
    } else {
      whereredd_info()
      return(db_path)
    }
  }

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = FALSE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  urls <- redd_src_urls(continents = continents)
  # Define geometry columns

  geom_cols <- c(
    "project_area",
    "accounting_region",
    "reference_region"
  )

  exclude_clause <- glue::glue_sql_collapse(
    c("geometry", geom_cols),
    sep = ", "
  )

  clean_clause <- glue::glue(
    "ST_MakeValid (
       CASE
         WHEN ST_GeometryType ({geom_cols}::GEOMETRY)::VARCHAR LIKE '%POINT%'
           THEN ST_Force2D (ST_CollectionExtract ({geom_cols}::GEOMETRY, 1))
         WHEN ST_GeometryType ({geom_cols}::GEOMETRY)::VARCHAR LIKE '%POLYGON%'
           THEN ST_Force2D (ST_CollectionExtract ({geom_cols}::GEOMETRY, 3))
         ELSE ST_Force2D ({geom_cols}::GEOMETRY)
       END
     ) AS {geom_cols}_clean"
  ) |>
    glue::glue_sql_collapse(sep = ",\n                   ")

  DBI::dbExecute(
    con,
    "  INSTALL httpfs;

           LOAD httpfs;

        INSTALL spatial;

           LOAD spatial"
  )

  clean_geom_cols <- paste0(geom_cols, "_clean")
  exclude_clean_clause <- glue::glue_sql_collapse(clean_geom_cols, sep = ", ")

  wkb_clause <- glue::glue(
    "ST_AsWKB ({geom_cols}_clean)::BLOB AS {geom_cols}_wkb"
  ) |>
    glue::glue_sql_collapse(sep = ",\n                ")

  q <- glue::glue_sql(
    "   CREATE TABLE redd_projects AS
           WITH cleaned AS (
                   SELECT * EXCLUDE ({`exclude_clause`}),
                          {`clean_clause`}
                     FROM read_parquet([{urls*}])
                )
         SELECT * EXCLUDE ({`exclude_clean_clause`}),
                {`wkb_clause`}
           FROM cleaned
          WHERE NOT ST_IsEmpty (project_area_clean);",
    .con = con
  )

  sq <- DBI::dbSendQuery(con, q)
  DBI::dbClearResult(sq)

  cli::cli_alert_success("Created REDD+ database at {.path {db_path}}")

  build_whereredd_info(con, db_path)
  whereredd_info()

  return(invisible(db_path))
}


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
