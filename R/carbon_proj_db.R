carbon_proj_db <- function(
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
  force = FALSE,
  build_from = c("release", "source"),
  tag = "latest"
) {
  if (!requireNamespace("duckdb", quietly = TRUE)) {
    cli::cli_abort(
      c(
        "The 'duckdb' package is required to build the carbon project database.",
        "i" = "Please refer to https://github.com/duckdb/duckdb-r for installation instructions."
      )
    )
  }

  build_from <- rlang::arg_match(build_from)
  continents <- rlang::arg_match(continents, multiple = TRUE)

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

  # Connect to DuckDB and create database
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = FALSE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  if (build_from == "release") {
    carbon_proj_db_release(con, continents, tag)
  } else {
    carbon_proj_db_src(con, continents)
  }

  cli::cli_alert_success(
    "Created REDD+ database at {.path
   {db_path}}"
  )

  build_whereredd_info(con, db_path)
  whereredd_info()

  return(invisible(db_path))
}


carbon_proj_db_release <- function(con, continents, tag) {
  url <- carbon_proj_release_url(tag = tag)
  q <- glue::glue_sql(
    "CREATE TABLE redd_projects AS
       SELECT *
         FROM read_parquet({url})
        WHERE continent IN ({continents*})
     ORDER BY continent, country, id;",
    .con = con
  )
  DBI::dbExecute(con, q)
}


carbon_proj_db_src <- function(
  con,
  continents
) {
  urls <- carbon_proj_src_urls(continents = continents)

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

  # Build UNION ALL for pivot to long format with explicit column ordering
  # Map area role labels
  area_role_labels <- c(
    "project_area" = "project",
    "accounting_region" = "accounting",
    "reference_region" = "reference"
  )

  pivot_union <- glue::glue(
    "SELECT id,
            project_name,
            '{area_role_labels[geom_cols]}' AS area_role,
            registry_name,
            methodology,
            project_type,
            continent,
            country,
            project_developer,
            project_start_date,
            project_end_date,
            entry_date,
            processing_approach,
            pd_declined,
            filename,
            ST_AsWKB ({geom_cols}_clean)::BLOB AS geometry_wkb
       FROM cleaned
      WHERE NOT ST_IsEmpty ({geom_cols}_clean)"
  ) |>
    glue::glue_sql_collapse(sep = "\n\n     UNION ALL\n\n     ")

  q <- glue::glue_sql(
    "   CREATE TABLE redd_projects AS
        SELECT * FROM (
           WITH source AS (
                   SELECT *,
                          regexp_extract(filename, '([^/]+)\\.parquet$', 1) AS continent
                     FROM read_parquet([{urls*}], filename = true)
                ),
                cleaned AS (
                   SELECT * EXCLUDE ({`exclude_clause`}),
                          {`clean_clause`}
                     FROM source
                )
     {`pivot_union`}
        )
     ORDER BY continent, country, id;",
    .con = con
  )

  sq <- DBI::dbSendQuery(con, q)
  DBI::dbClearResult(sq)
}

#' Export Carbon Project Database to Parquet File
#' @description
#' Exports the carbon project database to a Parquet file. The function connects to the database, retrieves the data, and writes it to a specified Parquet file.
#' @param dest_path The destination path for the output Parquet file. If not provided, it defaults to "forest_carbon_boundaries.parquet" in the current working directory.
#' @param db_path The path to the carbon project database. If not provided, it will attempt to find the database path using the `wheredd_db_path()` function.
#' @return The path to the exported Parquet file, invisibly.
#' @export
carbon_proj_db_to_file <- function(
  dest_path = "forest_carbon_boundaries.parquet",
  db_path = NULL
) {
  if (is.null(db_path)) {
    db_path <- wheredd_db_path()
  }
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  out_ext <- fs::path_ext(dest_path)
  if (!nzchar(out_ext)) {
    out_ext <- "parquet"
    dest_path <- fs::path(dest_path, ext = out_ext)
  } else if (tolower(out_ext) != "parquet") {
    cli::cli_abort(
      c(
        "Unsupported output file format: {.path {dest_path}}",
        "i" = "Only Parquet format is supported. Please provide a .parquet file extension."
      )
    )
  }

  q <- glue::glue_sql(
    "COPY redd_projects TO {dest_path} (FORMAT 'parquet', COMPRESSION 'zstd');",
    .con = con
  )

  DBI::dbExecute(
    con,
    q
  )

  return(invisible(dest_path))
}
