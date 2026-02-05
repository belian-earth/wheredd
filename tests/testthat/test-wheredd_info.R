test_that("whereredd_info displays database information", {
  skip_if_offline()
  skip_on_cran()

  temp_dir <- withr::local_tempdir()

  # Create a test database
  db_path <- carbon_proj_db(
    dest = temp_dir,
    db_name = "test_info_db",
    continents = "europe",
    build_from = "source"
  )

  # Get info
  info <- whereredd_info()

  # Check structure
  expect_type(info, "list")
  expect_named(
    info,
    c("db_path", "db_date", "db_size", "table_name", "nrecords", "ncols")
  )

  # Check values
  expect_equal(info$db_path, db_path)
  expect_s3_class(info$db_date, "POSIXct")
  expect_s3_class(info$db_size, "fs_bytes")
  expect_equal(info$table_name, "carbon_projects")
  expect_gt(info$nrecords, 0)
  expect_gt(info$ncols, 0)
})

test_that("whereredd_info returns NULL when no database exists", {
  # Temporarily move any existing info file
  info_path <- fs::path(rappdirs::user_cache_dir("wheredd"), "wheredd_info.rds")
  backup_path <- fs::path(rappdirs::user_cache_dir("wheredd"), "wheredd_info_backup.rds")

  if (fs::file_exists(info_path)) {
    fs::file_move(info_path, backup_path)
    on.exit(fs::file_move(backup_path, info_path), add = TRUE)
  }

  # Should return NULL and show message
  result <- suppressMessages(whereredd_info())
  expect_null(result)
})

test_that("wheredd_db_path returns correct path", {
  skip_if_offline()
  skip_on_cran()

  temp_dir <- withr::local_tempdir()

  # Create a test database
  db_path_created <- carbon_proj_db(
    dest = temp_dir,
    db_name = "test_path_db",
    continents = "europe",
    build_from = "source"
  )

  # Get path via helper function
  db_path_retrieved <- wheredd_db_path()

  expect_equal(db_path_retrieved, db_path_created)
  expect_true(fs::file_exists(db_path_retrieved))
})

test_that("find_wheredd_info errors when database doesn't exist", {
  # Temporarily move any existing info file
  info_path <- fs::path(rappdirs::user_cache_dir("wheredd"), "wheredd_info.rds")
  backup_path <- fs::path(rappdirs::user_cache_dir("wheredd"), "wheredd_info_backup.rds")

  if (fs::file_exists(info_path)) {
    fs::file_move(info_path, backup_path)
    on.exit(fs::file_move(backup_path, info_path), add = TRUE)
  }

  expect_error(
    find_wheredd_info(),
    "No wheredd database found"
  )
})

test_that("build_whereredd_info creates info file with all fields", {
  skip_if_offline()
  skip_on_cran()

  temp_dir <- withr::local_tempdir()

  # Create database
  db_path <- carbon_proj_db(
    dest = temp_dir,
    db_name = "test_build_info",
    continents = "europe",
    build_from = "source"
  )

  # Info should have been created automatically
  info <- find_wheredd_info()

  # Verify all expected fields
  expect_true("db_path" %in% names(info))
  expect_true("db_date" %in% names(info))
  expect_true("db_size" %in% names(info))
  expect_true("table_name" %in% names(info))
  expect_true("nrecords" %in% names(info))
  expect_true("ncols" %in% names(info))

  # Verify table_name is correct
  expect_equal(info$table_name, "carbon_projects")
})
