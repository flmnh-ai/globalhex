test_that("neighbors and children always return relation tibbles", {
  grid <- modern_grid()
  cell <- point_to_cell(c(-73.9857, 40.7484), 5, grid)

  neighbors <- cell_neighbors(cell)
  expect_s3_class(neighbors, "tbl_df")
  expect_named(neighbors, c("origin", "cell"))
  expect_equal(nrow(neighbors), 6L)
  expect_true(all(neighbors$origin == cell))
  expect_false(as.character(cell) %in% as.character(neighbors$cell))

  parent <- cell_parent(cell)
  expect_identical(cell_resolution(parent), 4L)
  children <- cell_children(parent)
  expect_s3_class(children, "tbl_df")
  expect_named(children, c("parent", "cell"))
  expect_equal(nrow(children), 7L)
  expect_true(as.character(cell) %in% as.character(children$cell))
  expect_equal(cell_parent(children$cell), children$parent)
})

test_that("hierarchy operations vectorize across mixed resolutions", {
  grid <- modern_grid()
  cell5 <- point_to_cell(c(-73.9857, 40.7484), 5, grid)
  cell4 <- cell_parent(cell5)
  mixed <- vctrs::vec_c(cell4, cell5)

  expect_identical(cell_resolution(mixed), c(4L, 5L))
  expect_identical(cell_resolution(cell_parent(mixed)), c(3L, 4L))
  expect_equal(nrow(cell_neighbors(mixed)), 12L)
  expect_equal(nrow(cell_children(mixed)), 14L)
})

test_that("disk, ring, and distance have stable relational outputs", {
  grid <- modern_grid()
  cells <- point_to_cell(rbind(c(-73.9857, 40.7484), c(0, 0)), 5, grid)
  disk <- cell_disk(cells, 1)
  ring <- cell_ring(cells, 1)

  expect_s3_class(disk, "tbl_df")
  expect_named(disk, c("origin", "cell", "distance"))
  expect_equal(nrow(disk), 14L)
  expect_equal(nrow(ring), 12L)
  expect_true(all(ring$distance == 1L))
  expect_identical(cell_distance(cells, cells), c(0L, 0L))
  expect_identical(cell_distance(cells[1], cell_neighbors(cells[1])$cell[1]), 1L)
})

test_that("batched hierarchy and traversal preserve duplicate origins", {
  grid <- modern_grid()
  cell <- point_to_cell(c(-73.9857, 40.7484), 5, grid)
  duplicated <- vctrs::vec_c(cell, cell)

  children <- cell_children(cell_parent(duplicated))
  expect_equal(nrow(children), 14L)
  expect_equal(
    as.character(children$cell[seq_len(7L)]),
    as.character(children$cell[8:14])
  )

  disk <- cell_disk(duplicated, 2)
  first <- disk[seq_len(nrow(disk) / 2L), ]
  second <- disk[seq.int(nrow(disk) / 2L + 1L, nrow(disk)), ]
  expect_equal(as.character(first$cell), as.character(second$cell))
  expect_identical(first$distance, second$distance)
})

test_that("distance batches repeated origins and stops at the requested bound", {
  grid <- modern_grid()
  origin <- point_to_cell(c(-73.9857, 40.7484), 5, grid)
  disk <- cell_disk(origin, 2)
  destinations <- vctrs::vec_c(
    origin,
    disk$cell[disk$distance == 1L][1L],
    disk$cell[disk$distance == 2L][1L]
  )

  expect_identical(cell_distance(origin, destinations), 0:2)
  expect_identical(cell_distance(origin, destinations, max_k = 1), c(0L, 1L, NA_integer_))
})

test_that("progress arguments are optional scalar flags", {
  grid <- modern_grid()
  cell <- point_to_cell(c(0, 0), 5, grid)

  expect_equal(cell_disk(cell, 0, progress = FALSE)$cell, cell)
  expect_error(cell_disk(cell, 0, progress = "yes"),
    class = "globalhex_error_argument"
  )
  expect_error(cell_children(cell, progress = NA),
    class = "globalhex_error_argument"
  )
})

test_that("cell cover returns cells at the requested resolution", {
  skip_if_not_installed("sf")
  grid <- modern_grid()
  ring <- matrix(
    c(-74.4, 40.5, -73.5, 40.5, -73.5, 41.2, -74.4, 41.2, -74.4, 40.5),
    ncol = 2,
    byrow = TRUE
  )
  polygon <- sf::st_sfc(sf::st_polygon(list(ring)), crs = 4326)
  cells <- cell_cover(polygon, 5, grid)
  expect_gt(length(cells), 0L)
  expect_true(all(cell_resolution(cells) == 5L))
})

test_that("cell cover excludes holes but keeps islands inside them", {
  skip_if_not_installed("sf")
  grid <- modern_grid()
  square <- function(xmin, ymin, size) {
    matrix(
      c(xmin, ymin, xmin + size, ymin, xmin + size, ymin + size,
        xmin, ymin + size, xmin, ymin),
      ncol = 2,
      byrow = TRUE
    )
  }
  donut <- sf::st_polygon(list(square(0, 0, 10), square(3, 3, 4)))
  island <- sf::st_polygon(list(square(4.25, 4.25, 1.5)))
  region <- sf::st_sfc(sf::st_multipolygon(list(donut, island)), crs = 4326)

  in_box <- function(xy, xmin, ymin, size) {
    xy$lon > xmin & xy$lon < xmin + size & xy$lat > ymin & xy$lat < ymin + size
  }
  with_holes <- cell_center(cell_cover(region, 5, grid))
  without_holes <- cell_center(cell_cover(region, 5, grid, include_holes = FALSE))
  hole_only <- in_box(with_holes, 3, 3, 4) & !in_box(with_holes, 4.25, 4.25, 1.5)

  expect_false(any(hole_only))
  expect_true(any(in_box(with_holes, 4.25, 4.25, 1.5)))
  expect_true(any(in_box(without_holes, 3, 3, 4) & !in_box(without_holes, 4.25, 4.25, 1.5)))
})
