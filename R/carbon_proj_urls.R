#' Get URL for Carbon Project Release Data
#'
#' @description
#' Retrieves the download URL for pre-processed carbon project boundary data
#' from a GitHub release. The data is stored as a parquet file in the
#' belian-earth/wheredd repository releases.
#'
#' @param tag A character string specifying the release tag to retrieve data from.
#'   Default is "latest" to get the most recent release. If a specific tag is
#'   provided (e.g., "v0.0.1"), it must match an existing tag in the repository.
#'
#' @return A character string containing the download URL for the parquet file
#'   from the specified release.
#'
#' @details
#' This function uses the piggyback package to construct a direct download URL
#' for the "forest_carbon_boundaries.parquet" file from the specified GitHub
#' release. If a specific tag is provided, the function validates it against
#' available tags in the repository.
#'
#' @examples
#' \dontrun{
#' # Get URL for latest release
#' url <- carbon_proj_release_url()
#'
#' # Get URL for specific version
#' url <- carbon_proj_release_url("v0.0.1")
#' }
#'
#' @export
carbon_proj_release_url <- function(tag = "latest") {
  if (tag != "latest") {
    rlist <- piggyback::pb_list(repo = "belian-earth/wheredd")
    tag <- rlang::arg_match(tag, c(unique(rlist[["tag"]]), "latest"))
  }

  piggyback::pb_download_url(
    file = fs::path("forest_carbon_boundaries.parquet"),
    repo = "belian-earth/wheredd",
    tag = tag
  )
}


#' Get URLs for Carbon Project Source Data
#'
#' @description
#' Generates URLs for raw carbon project boundary data files hosted on
#' source.coop. Each continent has a separate parquet file containing the
#' project polygons and supplementary metadata.
#'
#' @param continents A character vector of continent names to retrieve URLs for.
#'   Valid values are "africa", "asia", "europe", "north_america", "oceania",
#'   and "south_america". Default is all continents. Multiple values are allowed.
#'
#' @return A character vector of HTTPS URLs pointing to parquet files on
#'   source.coop, one URL per specified continent.
#'
#' @details
#' These URLs point to the raw source data maintained by the CECIL project at:
#' https://source.coop/cecil/forest-carbon-boundaries/
#'
#' Each parquet file contains carbon offset project boundaries with associated
#' metadata. The data requires processing (geometry validation, cleaning, etc.)
#' before use - see `carbon_proj_db(build_from = "source")` for automated
#' processing.
#'
#' @examples
#' \dontrun{
#' # Get URLs for all continents
#' urls <- carbon_proj_src_urls()
#'
#' # Get URLs for specific continents
#' urls <- carbon_proj_src_urls(c("africa", "asia"))
#'
#' # Get URL for single continent
#' url <- carbon_proj_src_urls("europe")
#' }
#'
#' @export
carbon_proj_src_urls <- function(
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
