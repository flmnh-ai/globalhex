raster_packages <- function() {
  skip_if_not_installed("terra")
  skip_if_not_installed("sf")
  skip_if_not_installed("exactextractr")
}

test_that("cell sampling is row-stable and geometry-free", {
  raster_packages()
  raster <- terra::rast(
    nrows = 18,
    ncols = 36,
    xmin = -180,
    xmax = 180,
    ymin = -90,
    ymax = 90,
    crs = "EPSG:4326"
  )
  terra::values(raster) <- 5
  names(raster) <- "temperature"
  cells <- point_to_cell(rbind(c(0, 0), c(10, 10), c(0, 0)), 4, modern_grid())

  sampled <- cell_sample(cells, raster)

  expect_s3_class(sampled, "globalhex_data")
  expect_identical(sampled$cell, cells)
  expect_equal(sampled$temperature, rep(5, 3))
  expect_false(inherits(sampled, "sf"))

  empty <- expect_no_warning(cell_sample(cells[0], raster))
  expect_identical(names(empty), c("cell", "temperature"))
  expect_equal(nrow(empty), 0L)
})

test_that("exact extraction has safe defaults and tidy explicit names", {
  raster_packages()
  continuous <- terra::rast(
    nrows = 18,
    ncols = 36,
    xmin = -180,
    xmax = 180,
    ymin = -90,
    ymax = 90,
    crs = "EPSG:4326"
  )
  terra::values(continuous) <- 5
  names(continuous) <- "temperature"
  categorical <- continuous
  terra::values(categorical) <- 1
  levels(categorical) <- data.frame(
    ID = 1:2,
    class = c("land", "water")
  )
  names(categorical) <- "cover"
  raster <- c(continuous, categorical)
  cells <- point_to_cell(rbind(c(0, 0), c(10, 10)), 4, modern_grid())

  extracted <- cell_extract(cells, raster, progress = FALSE)
  expect_equal(extracted$temperature, rep(5, 2))
  expect_identical(extracted$cover, factor(rep("land", 2), levels = c("land", "water")))

  summaries <- cell_extract(
    cells,
    continuous,
    fun = c("mean", "min"),
    progress = FALSE
  )
  expect_named(summaries, c("cell", "temperature_mean", "temperature_min"))
  expect_equal(summaries$temperature_mean, rep(5, 2))
})

test_that("raster conversion covers edge cells and 0-to-360 rasters", {
  raster_packages()
  regional <- terra::rast(
    nrows = 10,
    ncols = 10,
    xmin = -2,
    xmax = 2,
    ymin = -2,
    ymax = 2,
    crs = "EPSG:4326"
  )
  terra::values(regional) <- 3
  names(regional) <- "constant"

  converted <- raster_to_cell(
    regional,
    resolution = 3,
    grid = modern_grid(),
    max_cells = 1000,
    progress = FALSE
  )
  expect_s3_class(converted, "globalhex_data")
  expect_gt(nrow(converted), 0)
  expect_true(all(cell_resolution(converted$cell) == 3L))
  expect_equal(converted$constant, rep(3, nrow(converted)), tolerance = 1e-6)

  terra::values(regional)[1:20] <- NA
  sparse <- raster_to_cell(
    regional,
    resolution = 3,
    grid = modern_grid(),
    max_cells = 1000,
    progress = FALSE
  )
  retained <- raster_to_cell(
    regional,
    resolution = 3,
    grid = modern_grid(),
    max_cells = 1000,
    progress = FALSE,
    drop_na = FALSE
  )
  expect_lte(nrow(sparse), nrow(retained))
  expect_false(anyNA(sparse$constant))

  global <- terra::rast(
    nrows = 18,
    ncols = 36,
    xmin = -180,
    xmax = 180,
    ymin = -90,
    ymax = 90,
    crs = "EPSG:4326"
  )
  terra::values(global) <- 4
  names(global) <- "global"
  global_cells <- raster_to_cell(
    global,
    resolution = 1,
    grid = modern_grid(),
    max_cells = 1000,
    progress = FALSE
  )
  expect_equal(nrow(global_cells), 72L)
  expect_equal(global_cells$global, rep(4, 72), tolerance = 1e-6)

  seam <- terra::rast(
    nrows = 4,
    ncols = 20,
    xmin = 170,
    xmax = 190,
    ymin = -2,
    ymax = 2,
    crs = "EPSG:4326"
  )
  terra::values(seam) <- rep(rep(c(1, 2), each = 10), 4)
  names(seam) <- "seam"
  seam_cells <- point_to_cell(rbind(c(179, 0), c(-179, 0)), 6, modern_grid())

  expect_equal(cell_sample(seam_cells, seam)$seam, c(1, 2))
  expect_equal(
    cell_extract(seam_cells, seam, weights = NULL, progress = FALSE)$seam,
    c(1, 2),
    tolerance = 0.05
  )
})

test_that("raster arguments fail clearly", {
  raster_packages()
  cells <- point_to_cell(c(0, 0), 3, modern_grid())
  raster <- terra::rast(nrows = 2, ncols = 2)
  terra::values(raster) <- 1:4

  expect_error(cell_sample(cells, matrix(1)), class = "globalhex_error_argument")
  terra::crs(raster) <- ""
  expect_error(cell_sample(cells, raster), class = "globalhex_error_crs")
  terra::crs(raster) <- "EPSG:4326"
  expect_error(
    cell_extract(cells, raster, weights = "population", progress = FALSE),
    class = "globalhex_error_argument"
  )
  expect_error(
    cell_extract(cells, raster, fun = character(), progress = FALSE),
    class = "globalhex_error_argument"
  )
})

test_that("raster_to_cell handles small rasters between chunk breaks", {
  skip_if_not_installed("terra")
  skip_if_not_installed("exactextractr")
  skip_if_not_installed("sf")
  grid <- modern_grid()
  elevation <- terra::rast(system.file("ex/elev.tif", package = "terra"))
  converted <- raster_to_cell(elevation, resolution = 7, grid = grid, progress = FALSE)
  expect_gt(length(converted$cell), 0L)
  expect_true(all(is.finite(converted$elevation)))
})

test_that(".bounded_breaks returns only the endpoints for narrow intervals", {
  expect_equal(.bounded_breaks(5.7, 6.5), c(5.7, 6.5))
  expect_equal(.bounded_breaks(-10, 70), c(-10, 0, 60, 70))
})
