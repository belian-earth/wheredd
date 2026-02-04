library(devtools)
load_all()


dbdir <- redd_db(force = TRUE)

con <- DBI::dbConnect(duckdb::duckdb(), dbdir = dbdir, read_only = TRUE)
# DBI::dbDisconnect(con, shutdown = TRUE)
redd_projects <- DBI::dbReadTable(con, "redd_projects")

tibble::as_tibble(redd_projects)$accounting_region
is.null(redd_projects$accounting_region[[1]])
tibble::as_tibble(redd_projects[!is.null(redd_projects$accounting_region), ])[
  1:10,
  "accounting_region"
]
colnames(redd_projects)
spdf <- sf::st_as_sf(
  redd_projects,
  sf_column_name = "project_area_wkb",
  crs = 4326
)

sf::write_sf(spdf["id"], "redd_projects.parquet", driver = "Parquet")


spdf_poly <- spdf[
  sf::st_geometry_type(spdf) %in% c("POLYGON", "MULTIPOLYGON"),
]

sf::sf_use_s2(FALSE)

areas <- sf::st_area(spdf_poly)

area_ha <- as.numeric(units::set_units(areas, "ha"))

library(ggplot2)
library(units)
ggplot() +
  aes(x = area_ha[area_ha < 1e6]) +
  # geom_density(fill = "#1f78b4", alpha = 0.7) +
  geom_histogram(fill = "#1f78b4", alpha = 0.7) +
  # scale_x_log10(labels = scales::label_comma()) +
  labs(
    title = "Distribution of Forest Carbon Project Areas",
    x = "Area (hectares)"
  ) +
  scale_x_continuous(labels = scales::label_comma()) +
  theme_light() +
  stat_bin(
    aes(label = ifelse(after_stat(count) > 0, after_stat(count), "")),
    geom = "text",
    vjust = -0.5
  )

ggsave(
  "figures/redd_project_area_distribution-hist-sub1mil.png",
  width = 8,
  height = 5
)


spdf['id'][1, ]$project_area_wkb

mapgl::maplibre_view(spdf['id'][1:100, ])


head(redd_projects$project_area)

purrr::walk(
  colnames(redd_projects),
  ~ {
    cat(.x, "\n")
    print(head(redd_projects[[.x]]))
    cat("\n\n")
  }
)


nrecords <- DBI::dbGetQuery(
  con,
  "SELECT COUNT(*) AS n FROM redd_projects"
)$n

DBI::dbGetQuery(con, "DESCRIBE redd_projects")

ncols <- DBI::dbGetQuery(
  con,
  "PRAGMA table_info(redd_projects);"
) %>%
  nrow()

DBI::dbDisconnect(con, shutdown = TRUE)
