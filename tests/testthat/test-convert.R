test_that("IGEO7 point, center, and boundary conversions round trip", {
  grid <- modern_grid("igeo7")
  cell <- point_to_cell(c(-73.9857, 40.7484), 5, grid)
  expect_identical(as.character(cell), "0203124")

  center <- cell_center(cell)
  expect_s3_class(center, "tbl_df")
  expect_named(center, c("cell", "lon", "lat"))
  expect_equal(point_to_cell(center[c("lon", "lat")], 5, grid), cell)

  boundary <- cell_boundary(cell)
  expect_s3_class(boundary, "tbl_df")
  ring <- boundary$boundary[[1L]]
  expect_identical(colnames(ring), c("lon", "lat"))
  expect_true(nrow(ring) %in% c(6L, 7L))
  expect_equal(ring[1L, ], ring[nrow(ring), ])
})

test_that("duplicate conversion requests preserve size and order", {
  grid <- modern_grid("igeo7")
  points <- rbind(
    c(-73.9857, 40.7484),
    c(0, 0),
    c(-73.9857, 40.7484)
  )
  cells <- point_to_cell(points, 5, grid)

  expect_length(cells, 3L)
  expect_equal(cells[1L], cells[3L])
  expect_identical(as_seqnum(cells)[c(1L, 3L)], rep(as_seqnum(cells[1L]), 2L))
  expect_equal(cell_center(cells)$cell, cells)
  expect_equal(cell_boundary(cells)$cell, cells)
})

test_that("center extraction uses text output and backend jobs are chunkable", {
  grid <- modern_grid()
  points <- rbind(c(-73.9857, 40.7484), c(0, 0), c(120, 35))

  testthat::local_mocked_bindings(
    .backend_chunk_size = function() 2L,
    .package = "globalhex"
  )
  expect_identical(.chunk_indices(5L), list(`1` = 1:2, `2` = 3:4, `3` = 5L))

  cells <- point_to_cell(points, 7, grid)
  centers <- testthat::with_mocked_bindings(
    cell_center(cells),
    .read_geojson = function(...) stop("GeoJSON should not be read for centers."),
    .package = "globalhex"
  )
  expect_equal(point_to_cell(centers[c("lon", "lat")], 7, grid), cells)
  expect_length(as_seqnum(cells), 3L)
  expect_length(cell_boundary(cells)$boundary, 3L)
})

test_that("ISEA3H/Z3 uses the same public surface", {
  grid <- modern_grid("isea3h")
  cell <- point_to_cell(c(-73.9857, 40.7484), 5, grid)
  expect_s3_class(cell, "globalhex_cell")
  expect_identical(cell_resolution(cell), 5L)
  expect_equal(point_to_cell(cell_center(cell)[c("lon", "lat")], 5, grid), cell)
  expect_true(nzchar(as_seqnum(cell)))
})

test_that("sf conversion is a standard st_as_sf method", {
  skip_if_not_installed("sf")
  grid <- modern_grid()
  cells <- point_to_cell(rbind(c(-73.9857, 40.7484), c(0, 0)), 5, grid)
  x <- sf::st_as_sf(cells)
  expect_s3_class(x, "sf")
  expect_equal(nrow(x), 2L)
  expect_true(all(sf::st_is_valid(x)))
})

test_that("coordinate and missing-cell failures have stable classes", {
  grid <- modern_grid()
  expect_error(point_to_cell(c(200, 0), 5, grid), class = "globalhex_error_coordinate")
  x <- as_globalhex_cell(c("0203124", NA), grid)
  expect_error(cell_center(x), class = "globalhex_error_missing_cell")
})
