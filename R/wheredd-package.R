#' wheredd: Access Forest Carbon Project Boundary Data
#'
#' @description
#' Provides streamlined access to forest carbon offset project boundary data
#' from the Akshata et al. (2024) forest carbon boundaries dataset, converted
#' to parquet by Alex Logan and hosted on Source Cooperative. Creates a local
#' DuckDB database with validated, cleaned project geometries from REDD+
#' (Reducing Emissions from Deforestation and Forest Degradation) and other
#' carbon offset projects worldwide.
#'
#' **This package focuses on data access.** Analytical functionality is left
#' to R's spatial and data analysis ecosystem (sf, dplyr, terra, etc.).
#'
#' @details
#' ## Main Features
#'
#' - **Database Creation**: Build a local DuckDB database using `carbon_proj_db()`
#' - **Flexible Data Sources**: Choose between pre-processed GitHub releases
#'   (fast) or raw source data (fresh, with full geometry processing)
#' - **Geometry Processing**: Automatic validation, cleaning, and WKB conversion
#'   of project boundary geometries (points and polygons supported)
#' - **Direct URLs**: Use `carbon_proj_release_url()` and
#'   `carbon_proj_source_urls()` to get download links without building the database
#' - **Spatial Queries**: Query by continent, country, registry, or project attributes
#'
#' ## Getting Started
#'
#' Build the database:
#' ```
#' library(wheredd)
#'
#' # Quick start with pre-processed data
#' db_path <- carbon_proj_db()
#'
#' # Or build from source with full processing
#' db_path <- carbon_proj_db(build_from = "source")
#'
#' # View database information
#' whereredd_info()
#' ```
#'
#' Connect and query with standard DBI/dplyr workflows:
#' ```
#' library(DBI)
#' library(dplyr)
#'
#' con <- dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)
#'
#' # Query with SQL
#' projects <- dbGetQuery(con, "
#'   SELECT * FROM carbon_projects
#'   WHERE continent = 'africa' AND area_role = 'project'
#'   LIMIT 10
#' ")
#'
#' # Or use dplyr
#' projects <- tbl(con, "carbon_projects") |>
#'   filter(continent == "africa", area_role == "project") |>
#'   collect()
#'
#' dbDisconnect(con, shutdown = TRUE)
#' ```
#'
#' Work with spatial data:
#' ```
#' library(sf)
#'
#' # Convert WKB to sf
#' projects_sf <- st_as_sf(projects, crs = 4326)
#' plot(st_geometry(projects_sf))
#' ```
#'
#' ## Data Structure
#'
#' The database contains one table (`carbon_projects`) with:
#' - One row per project per area type (project/accounting/reference)
#' - Geometry stored as WKB BLOB for efficient storage
#' - Metadata: project name, registry, dates, country, etc.
#' - Ordered by: continent → country → id
#'
#' ## Data Source and Attribution
#'
#' **Original Publication:**
#' Akshata Karnik, Jack B. Kilbride, Tristan R.H. Goodbody, Rachael Ross,
#' Elias Ayrey (2024). Forest carbon boundaries dataset.
#' Zenodo. \url{https://zenodo.org/records/11459391}
#'
#' **Data Conversion:**
#' Converted to parquet format by Alex Logan (June 5, 2024)
#'
#' **Data Host:**
#' Source Cooperative CECIL project
#' \url{https://source.coop/cecil/forest-carbon-boundaries}
#'
#' **License:** CC-BY 4.0
#'
#' @keywords internal
"_PACKAGE"
