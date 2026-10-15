test_that("legacy dggridR behavior is explicit and quarantined", {
  skip_if_not_installed("dggridR")
  grid <- legacy_grid(resolution = 5)
  cell <- point_to_cell(c(-73.9857, 40.7484), grid = grid)
  expect_identical(as.character(cell), "208")
  expect_equal(point_to_cell(cell_center(cell)[c("lon", "lat")], grid = grid), cell)
  expect_true(nrow(cell_boundary(cell)$boundary[[1L]]) >= 6L)
  expect_error(cell_neighbors(cell), class = "globalhex_error_unsupported")
})
