library(piggyback)

tag <- "v0.0.1"

piggyback::pb_release_create(
  repo = "belian-earth/wheredd",
  tag = tag,
  prerelease = TRUE
)

piggyback::pb_upload(
  file = fs::path("forest_carbon_boundaries.parquet"),
  repo = "belian-earth/wheredd",
  tag = tag
)
