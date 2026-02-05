#' Build Carbon Project Database
#'
#' @description
#' Creates a local DuckDB database containing forest carbon project boundaries
#' and metadata. The database can be built either from a pre-processed GitHub
#' release (fast) or from source parquet files (slower, but with fresh data and
#' full geometry processing).
#'
#' @param dest Directory path where the database will be created. If NULL
#'   (default), uses the system cache directory via `rappdirs::user_cache_dir("wheredd")`.
#' @param db_name Name of the database file (without extension). Default is "wheredd_db".
#' @param continents Character vector of continent names to include. Valid values
#'   are "africa", "asia", "europe", "north_america", "oceania", and "south_america".
#'   Default is all continents. Multiple values are allowed.
#' @param force Logical. If TRUE, removes and rebuilds existing database. If FALSE
#'   (default), returns existing database path without rebuilding.
#' @param build_from Character string specifying the data source. Either "release"
#'   (default, downloads pre-processed data from GitHub releases - faster) or
#'   "source" (processes raw parquet files with full geometry cleaning - slower).
#' @param tag Character string specifying the GitHub release tag to use when
#'   `build_from = "release"`. Default is "latest". Ignored when `build_from = "source"`.
#'
#' @return The file path to the created database, returned invisibly.
#'
#' @details
#' The function creates a DuckDB database with the following structure:
#' - One row per project per area type (project, accounting, reference)
#' - Geometries stored as WKB blobs for efficient storage
#' - Data ordered by continent, country, and project ID
#'
#' When `build_from = "release"`:
#' - Downloads pre-processed parquet file from GitHub releases
#' - Faster and simpler
#' - Uses data as published in the specified release tag
#'
#' When `build_from = "source"`:
#' - Fetches raw parquet files from source.coop
#' - Applies geometry validation and cleaning
#' - Converts from wide to long format
#' - Slower but ensures fresh data processing
#'
#' @examples
#' \dontrun{
#' # Build from latest release (fast)
#' db_path <- carbon_proj_db()
#'
#' # Build from source for Africa and Asia only
#' db_path <- carbon_proj_db(
#'   continents = c("africa", "asia"),
#'   build_from = "source"
#' )
#'
#' # Use a specific release version
#' db_path <- carbon_proj_db(
#'   tag = "v0.0.1",
#'   build_from = "release"
#' )
#'
#' # Force rebuild of existing database
#' db_path <- carbon_proj_db(force = TRUE)
#' }
#'
#' @export
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

  cli::cli_alert_success("Created REDD+ database at {.path {db_path}}")

  build_whereredd_info(con, db_path)
  whereredd_info()

  return(invisible(db_path))
}


#' Build Database from GitHub Release
#'
#' @description
#' Internal function that creates the database table by downloading a pre-processed
#' parquet file from a GitHub release. This is the fast path for database creation.
#'
#' @param con A DBI connection object to the DuckDB database.
#' @param continents Character vector of continent names to filter and include in
#'   the database.
#' @param tag Character string specifying which GitHub release tag to use.
#'
#' @return NULL (called for side effects - creates table in database)
#'
#' @details
#' This function:
#' 1. Retrieves the download URL for the specified release tag
#' 2. Creates a table by reading the parquet file directly from the URL
#' 3. Filters rows to include only the specified continents
#' 4. Orders results by continent, country, and ID
#'
#' @noRd
#' @keywords internal
carbon_proj_db_release <- function(con, continents, tag) {
  url <- carbon_proj_release_url(tag = tag)
  q <- glue::glue_sql(
    "CREATE TABLE carbon_projects AS
       SELECT *
         FROM read_parquet({url})
        WHERE continent IN ({continents*})
     ORDER BY continent, country, id;",
    .con = con
  )
  DBI::dbExecute(con, q)
}


#' Build Database from Source Parquet Files
#'
#' @description
#' Internal function that creates the database table by fetching and processing
#' raw parquet files from source.coop. This involves full geometry validation,
#' cleaning, and transformation from wide to long format.
#'
#' @param con A DBI connection object to the DuckDB database.
#' @param continents Character vector of continent names to fetch and process.
#'
#' @return NULL (called for side effects - creates table in database)
#'
#' @details
#' This function performs the following operations:
#'
#' **Geometry Processing:**
#' 1. Forces geometries to 2D (removes Z coordinates)
#' 2. Validates 2D geometries using ST_MakeValid (fixes topology issues that may
#'    appear after dimension reduction)
#' 3. Detects geometry type and extracts appropriate features:
#'    - Points from point geometries
#'    - Polygons from polygon/collection geometries
#' 4. Filters out empty results
#' 5. Converts to WKB (Well-Known Binary) format for efficient storage
#'
#' **Data Transformation:**
#' 1. Reads parquet files for specified continents in parallel
#' 2. Extracts continent name from filename
#' 3. Pivots from wide format (3 geometry columns) to long format (1 geometry
#'    column with area_role indicator)
#' 4. Filters out empty geometries
#' 5. Orders by continent, country, and ID
#'
#' **Area Roles:**
#' - "project": The project boundary area
#' - "accounting": The accounting region (if defined)
#' - "reference": The reference region (if defined)
#'
#' @section Extensions:
#' This function installs and loads the following DuckDB extensions:
#' - `httpfs`: For reading parquet files from HTTPS URLs
#' - `spatial`: For geometry processing functions
#'
#' @noRd
#' @keywords internal
carbon_proj_db_src <- function(
  con,
  continents
) {
  urls <- carbon_proj_source_urls(continents = continents)

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
    "CASE
       WHEN ST_GeometryType ({geom_cols}::GEOMETRY)::VARCHAR LIKE '%POINT%'
         THEN ST_CollectionExtract (
                ST_MakeValid (
                  ST_Force2D ({geom_cols}::GEOMETRY)
                ),
                1
              )
       ELSE ST_CollectionExtract (
              ST_MakeValid (
                ST_Force2D ({geom_cols}::GEOMETRY)
              ),
              3
            )
     END AS {geom_cols}_clean"
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
            TRY_STRPTIME(project_start_date, '%m/%d/%Y')::DATE AS project_start_date,
            TRY_STRPTIME(project_end_date, '%m/%d/%Y')::DATE AS project_end_date,
            TRY_STRPTIME(entry_date, '%m/%d/%Y')::DATE AS entry_date,
            processing_approach,
            pd_declined,
            filename,
            ST_AsWKB ({geom_cols}_clean)::BLOB AS geometry
       FROM cleaned
      WHERE {geom_cols}_clean IS NOT NULL
        AND NOT ST_IsEmpty ({geom_cols}_clean)"
  ) |>
    glue::glue_sql_collapse(sep = "\n\n     UNION ALL\n\n     ")

  q <- glue::glue_sql(
    "   CREATE TABLE carbon_projects AS
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
    "COPY carbon_projects TO {dest_path} (FORMAT 'parquet', COMPRESSION 'zstd');",
    .con = con
  )

  DBI::dbExecute(
    con,
    q
  )

  return(invisible(dest_path))
}
