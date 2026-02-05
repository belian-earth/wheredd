
<!-- README.md is generated from README.Rmd. Please edit that file -->

# wheredd

<!-- badges: start -->

[![R-CMD-check](https://github.com/belian-earth/wheredd/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/belian-earth/wheredd/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/belian-earth/wheredd/graph/badge.svg)](https://app.codecov.io/gh/belian-earth/wheredd)
[![License:Apache](https://img.shields.io/github/license/Permian-Global-Research/vrtility)](https://www.apache.org/licenses/LICENSE-2.0)
[![CRANstatus](https://www.r-pkg.org/badges/version/vrtility)](https://cran.r-project.org/package=vrtility)

<!-- badges: end -->

**wheredd** provides streamlined access to forest carbon offset project
boundary data. The package builds a local DuckDB database from the
[CECIL forest carbon boundaries
dataset](https://source.coop/cecil/forest-carbon-boundaries), making it
easy to query and analyze REDD+ and carbon offset project locations.

**This package focuses on data access.** Once you have the data, use
standard R spatial and data analysis tools (sf, dplyr, terra, etc.) for
your analysis workflows.

## Installation

Install the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("belian-earth/wheredd")
```

## Quick Start

Build the database (downloads pre-processed data from GitHub releases):

``` r
library(wheredd)

# just get the urls and download yourself...
carbon_proj_release_url()
#> [1] "https://github.com/belian-earth/wheredd/releases/download/v0.0.1/forest_carbon_boundaries.parquet"
# or for access to the original source data urls...
carbon_proj_source_urls()
#> https://data.source.coop/cecil/forest-carbon-boundaries/africa.parquet
#> https://data.source.coop/cecil/forest-carbon-boundaries/asia.parquet
#> https://data.source.coop/cecil/forest-carbon-boundaries/europe.parquet
#> https://data.source.coop/cecil/forest-carbon-boundaries/north_america.parquet
#> https://data.source.coop/cecil/forest-carbon-boundaries/oceania.parquet
#> https://data.source.coop/cecil/forest-carbon-boundaries/south_america.parquet


# Create local database
db_path <- carbon_proj_db()
#> 
#> ── wheredd Database Information ────────────────────────────────────────────────
#> Database path:
#> '/tmp/RtmpT11lTD/working_dir/RtmpFBlEmk/file241b12168d572/test_build_info.duckdb'
#> Table name: carbon_projects
#> Database created on: 2026-02-05 14:32:34.804495
#> Database size: 12K
#> Number of records: 4
#> Number of columns: 16
```

## Usage

### Connect and query

Use standard DBI/duckdb/duckplyr/dplyr workflows:

``` r
library(DBI)
library(dplyr)
library(duckplyr)
# Connect to database
con <- dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)

# Query with SQL
projects <- dbGetQuery(con, "
  SELECT * FROM carbon_projects
  WHERE continent = 'africa' AND area_role = 'project'
  LIMIT 10
")

# Or use d(uck)plyr
projects <- tbl(con, "carbon_projects") |>
  filter(continent == "africa", area_role == "project") |>
  collect()

projects
#> # A tibble: 72 × 16
#>    id    project_name area_role registry_name methodology project_type continent
#>    <chr> <chr>        <chr>     <chr>         <chr>       <chr>        <chr>    
#>  1 VCS2… Pendjari an… project   Verra         VM0009      AD           africa   
#>  2 VCS2… Forest Cons… project   Verra         VM0010      IFM          africa   
#>  3 VCS2… Chinko Cons… project   Verra         VM0009      AD           africa   
#>  4 GS56… EcoMakala V… project   Gold Standard Gold Stand… ARR          africa   
#>  5 VCS1… Isangi REDD… project   Verra         VM0006      AD           africa   
#>  6 VCS9… The Mai Ndo… project   Verra         VM0009      AD           africa   
#>  7 GS10… Humbo Ethio… project   Gold Standard AR-AM0003   ARR          africa   
#>  8 GS30… Soddo Commu… project   Gold Standard Gold Stand… ARR          africa   
#>  9 VCS1… Bale Mounta… project   Verra         VM0015      AD           africa   
#> 10 GS11… JOil Jatrop… project   Gold Standard Gold Stand… ARR          africa   
#> # ℹ 62 more rows
#> # ℹ 9 more variables: country <chr>, project_developer <chr>,
#> #   project_start_date <chr>, project_end_date <chr>, entry_date <chr>,
#> #   processing_approach <chr>, pd_declined <chr>, filename <chr>,
#> #   geometry_wkb <list>

dbDisconnect(con, shutdown = TRUE)
```

### Work with spatial data

Convert WKB geometries to sf objects:

``` r
library(sf)
#> Linking to GEOS 3.12.2, GDAL 3.12.1, PROJ 9.4.1; sf_use_s2() is TRUE

# Read WKB geometry column as sf
projects_sf <- projects |>
  st_as_sf(crs = 4326)

# Now use standard sf operations
plot(projects_sf['id'], axes=TRUE)
```

<img src="man/figures/README-spatial-1.png" width="100%" />

### Build from source

For fresh data with full geometry processing:

``` r
# Build from source parquet files (slower, but fresh)
db_path <- carbon_proj_db(
  build_from = "source",
  continents = c("africa", "asia")
)
```

## Data Structure

The database contains one table (`carbon_projects`) with:

- **One row per project per area type** (project, accounting, reference)
- **area_role**: Type of boundary (project/accounting/reference)
- **geometry_wkb**: Geometry as WKB BLOB (use `sf::st_as_sf(wkb = ...)`)
- **Metadata**: Project name, registry, dates, country, etc.
- **Ordered by**: continent → country → id

## Data Source

Data is from the CECIL project’s forest carbon boundaries dataset:
<https://source.coop/cecil/forest-carbon-boundaries>

The package does not include analytical functions—it provides clean,
queryable access to the data. Use R’s rich ecosystem of spatial and
analytical packages for your analysis needs.

## Data Dictionary

The `carbon_projects` table contains the following columns:

| Column | Type | Description |
|----|----|----|
| `id` | VARCHAR | Unique project identifier combining registry abbreviation and project number (e.g., “VCS1234”) |
| `project_name` | VARCHAR | Name of the carbon project as documented by the registry |
| `area_role` | VARCHAR | Type of boundary geometry: “project” (implementation area), “accounting” (area for credit calculation), or “reference” (area for baseline trends) |
| `registry_name` | VARCHAR | Carbon registry hosting the project (American Carbon Registry, BioCarbon Registry, Climate Action Reserve, EcoRegistry, Gold Standard, Verra) |
| `methodology` | VARCHAR | Methodology used for project implementation (e.g., VM0015, ACR Methodology) |
| `project_type` | VARCHAR | Type of forestry carbon offset program: ARR (Afforestation/Reforestation), AD (Avoided Deforestation), IFM (Improved Forest Management) |
| `continent` | VARCHAR | Continent where the project is located (africa, asia, europe, north_america, oceania, south_america) |
| `country` | VARCHAR | Country where the project is located |
| `project_developer` | VARCHAR | Entity or individual organizing the carbon offset project |
| `project_start_date` | DATE | Start date of the crediting period |
| `project_end_date` | DATE | End date of the crediting period |
| `entry_date` | DATE | Date when project information was added to the source database |
| `processing_approach` | VARCHAR | Method used to obtain boundary data: “Official” (from project developer), “Georeferenced” (from documents), “Linear” (traced from maps), or “Method” (derived from methodology) |
| `pd_declined` | VARCHAR | Whether the project developer declined to provide geometry (Yes/No/N/A) |
| `filename` | VARCHAR | Source parquet file URL from which this record was read |
| `geometry_wkb` | BLOB | Well-Known Binary representation of the project boundary (convert to sf using `st_as_sf(wkb = "geometry_wkb", crs = 4326)`) |

> [!NOTE]
> - Each project may appear 1-3 times depending on available boundary types (project/accounting/reference areas)
> - Empty geometries are filtered out during database creation
> - All geometries are validated, forced to 2D (Z coordinates removed), and stored as WKB BLOBs
> - Both point and polygon geometries are supported (collections are extracted to individual types)
> - Data is ordered by continent → country → id.

## Original Data Info and Attributions:

**source**: <https://source.coop/cecil/forest-carbon-boundaries>

**Converted by:** Alex Logan

**Original Authors:** Akshata Karnik, Jack B. Kilbride, Tristan R.H.
Goodbody, Rachael Ross, Elias Ayrey (Corresponding Author)

**Date:** June 5, 2024

**License:** CC-BY 4.0 See <https://zenodo.org/records/11459391>
