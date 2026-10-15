part_widths <- function(geometry) {
  polygons <- sf::st_cast(sf::st_geometry(geometry), "POLYGON")
  vapply(polygons, function(p) diff(range(p[[1L]][, 1L])), numeric(1))
}

test_that("antimeridian cells split into narrow valid multipolygons", {
  skip_if_not_installed("sf")
  grid <- modern_grid()
  cell <- point_to_cell(c(180, 10), 6, grid)

  raw <- sf::st_as_sf(cell, wrap = FALSE)
  expect_s3_class(sf::st_geometry(raw), "sfc_POLYGON")
  expect_gt(diff(range(sf::st_geometry(raw)[[1L]][[1L]][, 1L])), 350)

  wrapped <- sf::st_as_sf(cell)
  geometry <- sf::st_geometry(wrapped)
  expect_s3_class(geometry, "sfc_MULTIPOLYGON")
  expect_identical(wrapped$cell, cell)
  expect_length(geometry[[1L]], 2L)
  expect_true(all(sf::st_is_valid(wrapped)))
  coords <- sf::st_coordinates(geometry)
  expect_true(all(coords[, "X"] >= -180 & coords[, "X"] <= 180))
  expect_true(all(part_widths(geometry) < 10))
  expect_setequal(range(coords[, "X"]), c(-180, 180))

  area <- as.numeric(sf::st_area(wrapped))
  expect_equal(area, as.numeric(sf::st_area(raw)), tolerance = 1e-6)
  expect_equal(area / 1e6, 433.6, tolerance = 1e-3)
})

test_that("cells around the poles close along the map edge", {
  skip_if_not_installed("sf")
  grid <- modern_grid()
  north <- cell_disk(point_to_cell(c(0, 90), 3, grid), 2, progress = FALSE)$cell
  south <- cell_disk(point_to_cell(c(0, -90), 2, grid), 1, progress = FALSE)$cell
  cells <- c(north, south)

  wrapped <- sf::st_as_sf(cells)
  expect_true(all(sf::st_is_valid(wrapped)))
  coords <- sf::st_coordinates(wrapped)
  expect_true(all(coords[, "X"] >= -180 & coords[, "X"] <= 180))
  expect_true(all(coords[, "Y"] >= -90 & coords[, "Y"] <= 90))
  expect_equal(
    as.numeric(sf::st_area(wrapped)),
    as.numeric(sf::st_area(sf::st_as_sf(cells, wrap = FALSE))),
    tolerance = 1e-6
  )

  # Drawn as flat polygons, the cells leave no gap at either polar cap.
  flat <- sf::st_set_crs(sf::st_geometry(wrapped), NA)
  for (lat in c(89.9, -89.9)) {
    probes <- sf::st_sfc(lapply(seq(-179.5, 179.5, by = 1), function(lon) {
      sf::st_point(c(lon, lat))
    }))
    expect_true(all(lengths(sf::st_intersects(probes, flat)) >= 1L))
  }
})

test_that("coarse cells keep spherical areas and stay inside the map", {
  skip_if_not_installed("sf")
  grid <- modern_grid()
  cells <- as_globalhex_cell(sprintf("%02d", 0:11), grid)
  wrapped <- sf::st_as_sf(cells)
  expect_true(all(sf::st_is_valid(wrapped)))
  expect_equal(
    as.numeric(sf::st_area(wrapped)),
    as.numeric(sf::st_area(sf::st_as_sf(cells, wrap = FALSE))),
    tolerance = 1e-6
  )
  box <- sf::st_bbox(wrapped)
  expect_equal(unname(box[c("xmin", "xmax")]), c(-180, 180))
  expect_true(all(part_widths(wrapped) < 360))
})

test_that("a Pacific window keeps seam cells whole", {
  skip_if_not_installed("sf")
  grid <- modern_grid()
  boundary <- cell_boundary(point_to_cell(c(180, 10), 6, grid))$boundary
  geometry <- .flat_cell_geometry(boundary, center = 180)
  expect_s3_class(geometry, "sfc_POLYGON")
  x <- sf::st_coordinates(geometry)[, "X"]
  expect_true(all(x > 179 & x < 181))
})

test_that("st_as_sf validates wrap", {
  skip_if_not_installed("sf")
  cell <- point_to_cell(c(0, 0), 3, modern_grid())
  expect_error(sf::st_as_sf(cell, wrap = NA), class = "globalhex_error_argument")
})

test_that("unprojected plots draw polar cells as caps", {
  skip_if_not_installed("sf")
  grid <- modern_grid()
  cells <- cell_disk(point_to_cell(c(0, 90), 3, grid), 1, progress = FALSE)$cell
  x <- hex_data(cells, v = seq_along(cells))
  file <- tempfile(fileext = ".png")
  grDevices::png(file, width = 600, height = 400)
  displayed <- plot(x, border = "black", render = "polygon")
  grDevices::dev.off()
  unlink(file)

  geometry <- attr(displayed, "geometry")
  expect_true(all(sf::st_is_valid(geometry)))
  coords <- sf::st_coordinates(geometry)
  expect_true(all(coords[, "X"] >= -180 & coords[, "X"] <= 180))
  expect_equal(max(coords[, "Y"]), 90)
  expect_true(all(part_widths(geometry) <= 360))
})
