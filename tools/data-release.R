library(piggyback)

tag <- "v0.2.0"

piggyback::pb_release_create(
  repo = "belian-earth/wheredd",
  tag = tag,
  prerelease = FALSE
)
piggyback::pb_list()

piggyback::pb_upload(
  file = fs::path("forest_carbon_boundaries.parquet"),
  repo = "belian-earth/wheredd",
  tag = tag
)
