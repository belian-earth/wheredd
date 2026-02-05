test_that("carbon_proj_source_urls returns correct URLs", {
  # Test single continent
  url <- carbon_proj_source_urls("africa")
  expect_length(url, 1)
  expect_match(url, "https://data.source.coop/cecil/forest-carbon-boundaries/africa.parquet")

  # Test multiple continents
  urls <- carbon_proj_source_urls(c("africa", "asia"))
  expect_length(urls, 2)
  expect_match(urls[1], "africa.parquet")
  expect_match(urls[2], "asia.parquet")

  # Test all continents
  urls_all <- carbon_proj_source_urls()
  expect_length(urls_all, 6)
  expect_true(all(grepl("source.coop", urls_all)))
})

test_that("carbon_proj_source_urls validates continent names", {
  expect_error(
    carbon_proj_source_urls("invalid_continent")
  )
})

test_that("carbon_proj_release_url returns a URL", {
  skip_if_offline()
  skip_on_cran()

  # Skip if no releases exist yet
  skip_if(
    length(piggyback::pb_list(repo = "belian-earth/wheredd")$tag) == 0,
    "No GitHub releases available yet"
  )

  url <- carbon_proj_release_url()
  expect_type(url, "character")
  expect_length(url, 1)
  expect_match(url, "forest_carbon_boundaries.parquet")
  expect_match(url, "github")
})

test_that("carbon_proj_release_url validates tags", {
  skip_if_offline()
  skip_on_cran()

  # Skip if no releases exist yet
  skip_if(
    length(piggyback::pb_list(repo = "belian-earth/wheredd")$tag) == 0,
    "No GitHub releases available yet"
  )

  expect_error(
    carbon_proj_release_url("nonexistent_tag_12345")
  )
})
