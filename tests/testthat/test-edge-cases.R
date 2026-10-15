test_that("all twelve pentagons retain five neighbors and six children", {
  grid <- modern_grid()
  pentagons <- as_globalhex_cell(sprintf("%02d", 0:11), grid)

  neighbors <- cell_neighbors(pentagons)
  children <- cell_children(pentagons, max_cells = 6L, progress = FALSE)
  expect_true(all(table(as.character(neighbors$origin)) == 5L))
  expect_true(all(table(as.character(children$parent)) == 6L))
  expect_true(all(cell_is_valid(pentagons)))
})

test_that("antimeridian and polar cells round trip with closed valid boundaries", {
  grid <- modern_grid()
  points <- rbind(
    c(179.999, 0),
    c(-179.999, 0),
    c(0, 89.999),
    c(0, -89.999)
  )
  cells <- point_to_cell(points, 7, grid)
  centers <- cell_center(cells)
  boundaries <- cell_boundary(cells)$boundary

  expect_equal(point_to_cell(centers[c("lon", "lat")], 7, grid), cells)
  expect_true(all(vapply(boundaries, function(x) all(is.finite(x)), logical(1))))
  expect_true(all(vapply(boundaries, function(x) isTRUE(all.equal(x[1L, ], x[nrow(x), ])), logical(1))))
  expect_true(all(vapply(boundaries, function(x) all(x[, 1L] >= -180 & x[, 1L] <= 180), logical(1))))
  expect_true(all(vapply(boundaries, function(x) all(x[, 2L] >= -90 & x[, 2L] <= 90), logical(1))))

  skip_if_not_installed("sf")
  expect_true(all(sf::st_is_valid(sf::st_as_sf(cells))))
})

test_that("larger disks contain exact nonduplicated graph layers", {
  grid <- modern_grid()
  origin <- point_to_cell(c(-73.9857, 40.7484), 7, grid)
  disk <- cell_disk(origin, 4, progress = FALSE)
  ring <- disk[disk$distance == 4L, ]

  expect_equal(nrow(disk), 61L)
  expect_equal(nrow(ring), 24L)
  expect_false(anyDuplicated(as.character(disk$cell)) > 0L)
  expect_identical(cell_distance(origin, ring$cell[1L], max_k = 4L), 4L)
  expect_identical(cell_distance(origin, ring$cell[1L], max_k = 3L), NA_integer_)
})
