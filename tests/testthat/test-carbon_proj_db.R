test_that("carbon_proj_db creates database from source (europe only)", {
  skip_if_offline()
  skip_on_cran()

  # Create temp directory for test database
  temp_dir <- withr::local_tempdir()

  # Build database from source using only europe (smallest file)
  db_path <- carbon_proj_db(
    dest = temp_dir,
    db_name = "test_source_db",
    continents = "europe",
    build_from = "source",
    force = TRUE
  )

  # Check database was created
  expect_true(fs::file_exists(db_path))
  expect_match(db_path, "test_source_db.duckdb")

  # Connect and verify contents
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # Check table exists
  tables <- DBI::dbListTables(con)
  expect_contains(tables, "carbon_projects")

  # Check table has data
  n_rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM carbon_projects")$n
  expect_gt(n_rows, 0)

  # Check continent column
  continents <- DBI::dbGetQuery(con, "SELECT DISTINCT continent FROM carbon_projects")$continent
  expect_contains(continents, "europe")
  expect_length(continents, 1) # Should only have europe

  # Check area_role column exists and has expected values
  area_roles <- DBI::dbGetQuery(con, "SELECT DISTINCT area_role FROM carbon_projects")$area_role
  expect_true(all(area_roles %in% c("project", "accounting", "reference")))

  # Check geometry_wkb column exists and is BLOB
  cols <- DBI::dbGetQuery(con, "DESCRIBE carbon_projects")
  expect_contains(cols$column_name, "geometry_wkb")

  # Check required columns exist
  expected_cols <- c(
    "id", "project_name", "area_role", "registry_name",
    "continent", "country", "geometry_wkb"
  )
  expect_true(all(expected_cols %in% cols$column_name))
})

test_that("carbon_proj_db creates database from release", {
  skip_if_offline()
  skip_on_cran()

  # Create temp directory for test database
  temp_dir <- withr::local_tempdir()

  # Build database from release
  db_path <- carbon_proj_db(
    dest = temp_dir,
    db_name = "test_release_db",
    continents = c("europe", "oceania"),
    build_from = "release",
    force = TRUE
  )

  # Check database was created
  expect_true(fs::file_exists(db_path))

  # Connect and verify contents
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  # Check table exists
  tables <- DBI::dbListTables(con)
  expect_contains(tables, "carbon_projects")

  # Check filtering by continent worked
  continents <- DBI::dbGetQuery(con, "SELECT DISTINCT continent FROM carbon_projects")$continent
  expect_setequal(continents, c("europe", "oceania"))

  # Check data exists
  n_rows <- DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM carbon_projects")$n
  expect_gt(n_rows, 0)
})

test_that("carbon_proj_db respects force parameter", {
  skip_if_offline()
  skip_on_cran()

  temp_dir <- withr::local_tempdir()

  # Create database first time
  db_path1 <- carbon_proj_db(
    dest = temp_dir,
    db_name = "test_force_db",
    continents = "europe",
    build_from = "source"
  )

  # Get creation time
  creation_time1 <- fs::file_info(db_path1)$modification_time

  # Try creating again without force - should return existing path
  Sys.sleep(1) # Ensure time difference
  db_path2 <- carbon_proj_db(
    dest = temp_dir,
    db_name = "test_force_db",
    continents = "europe",
    build_from = "source",
    force = FALSE
  )

  expect_equal(db_path1, db_path2)
  creation_time2 <- fs::file_info(db_path2)$modification_time
  expect_equal(creation_time1, creation_time2) # File not modified

  # Create with force = TRUE - should recreate
  Sys.sleep(1)
  db_path3 <- carbon_proj_db(
    dest = temp_dir,
    db_name = "test_force_db",
    continents = "europe",
    build_from = "source",
    force = TRUE
  )

  creation_time3 <- fs::file_info(db_path3)$modification_time
  expect_true(creation_time3 > creation_time2) # File was recreated
})

test_that("carbon_proj_db_to_file exports database", {
  skip_if_offline()
  skip_on_cran()

  temp_dir <- withr::local_tempdir()

  # Create a small test database
  db_path <- carbon_proj_db(
    dest = temp_dir,
    db_name = "test_export_db",
    continents = "europe",
    build_from = "source"
  )

  # Export to parquet
  export_path <- fs::path(temp_dir, "exported.parquet")
  result <- carbon_proj_db_to_file(
    dest_path = export_path,
    db_path = db_path
  )

  # Check file was created
  expect_true(fs::file_exists(export_path))
  expect_match(result, "exported.parquet")

  # Verify we can read the exported parquet
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  data <- DBI::dbGetQuery(
    con,
    glue::glue_sql("SELECT COUNT(*) as n FROM read_parquet({export_path})", .con = con)
  )
  expect_gt(data$n, 0)
})

test_that("carbon_proj_db_to_file validates file extension", {
  temp_dir <- withr::local_tempdir()

  # Create a dummy database first
  temp_db <- fs::path(temp_dir, "test.duckdb")
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = temp_db)
  DBI::dbExecute(con, "CREATE TABLE carbon_projects AS SELECT 1 as id")
  DBI::dbDisconnect(con, shutdown = TRUE)

  expect_error(
    carbon_proj_db_to_file(
      dest_path = fs::path(temp_dir, "test.csv"),
      db_path = temp_db
    ),
    "Unsupported output file format"
  )
})

test_that("carbon_proj_db validates continents parameter", {
  temp_dir <- withr::local_tempdir()

  expect_error(
    carbon_proj_db(
      dest = temp_dir,
      continents = "invalid_continent"
    )
  )
})
