#' Retrieve cleaned carbon project boundary data from GitHub
#' @description
#' retrieve the source urls for the carbon project polygon outline and supplementary data
#' @param tag A character string specifying the release tag to retrieve data from.
#' Default is "latest". If a specific tag is provided, it must match one of the existing tags in the repository.
#' @return A character string containing the URL for the specified release tag.
#' @example
#' carbon_proj_release_url("v0.0.1")
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


#' Retrieve Carbon Project Source Data URLs
#' @description
#' retrieve the source urls for the carbon project polygon outline and supplementary data
#' @param continents A character vector of continent names to retrieve data for.
#' Valid values are "africa", "asia", "europe", "north_america", "oceania", and
#' "south_america". Default is all continents - multiple values are allowed.
#' @return A character vector of source URLs for the specified continents.
#' @example
#' carbon_proj_src_urls(c("africa", "asia"))
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
