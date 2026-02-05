#' wheredd: Locate and Query Forest Carbon Project Boundaries
#'
#' @description
#' The wheredd package provides tools to locate and query REDD+ (Reducing
#' Emissions from Deforestation and Forest Degradation) and other forest carbon
#' offset project locations worldwide. The package downloads and processes
#' boundary data from the Source Cooperative.
#'
#' @details
#' ## Main Features
#'
#' The wheredd package provides:
#'
#' - **Database Creation**: Build a local DuckDB database of forest carbon
#'   project boundaries using `carbon_proj_db()`
#' - **Flexible Data Sources**: Choose between pre-processed GitHub releases
#'   (fast) or raw source data (fresh, with full geometry processing)
#' - **Geometry Processing**: Automatic validation, cleaning, and conversion
#'   of project boundary geometries
#' - **Just get the URLs**: Use `carbon_proj_release_url()` and
#'   `carbon_proj_source_urls()` to get direct download links for the data files
#'   without building the database.
#'
#' ## Getting Started
#'
#' Build the database:
#' ```
#' # Quick start with pre-processed data
#' db_path <- carbon_proj_db()
#'
#' # Or build from source with full processing
#' db_path <- carbon_proj_db(build_from = "source")
#' ```
#'
#' Connect and query:
#' ```
#' library(DBI)
#' con <- dbConnect(duckdb::duckdb(), dbdir = db_path)
#' projects <- dbGetQuery(con, "SELECT * FROM carbon_projects LIMIT 10")
#' dbDisconnect(con)
#' ```
#'
#' ## Data Source
#'
#' Data is sourced from the Source Cooperative:
#' \url{https://source.coop/cecil/forest-carbon-boundaries}
#'
#' Source Dataset Information
#' - Converted by: Alex Logan
#' - Original Authors: Akshata Karnik, Jack B. Kilbride, Tristan R.H. Goodbody, Rachael Ross, Elias Ayrey (Corresponding Author)
#' - Date: June 5, 2024
#'
#' License: CC-BY 4.0 See \url{https://zenodo.org/records/11459391}
#'
#'
#'
#' @keywords internal
"_PACKAGE"
