plot_fixture <- local({
  value <- NULL
  function() {
    if (!is.null(value)) return(value)
    grid <- modern_grid()
    world <- as.matrix(expand.grid(
      lon = seq(-177, 177, length.out = 48L),
      lat = seq(-78, 78, length.out = 24L)
    ))
    florida <- cbind(
      lon = seq(-84.5, -80.0, length.out = 80L),
      lat = seq(24.5, 30.8, length.out = 80L)
    )
    cells <- point_to_cell(rbind(world, florida), 8, grid)
    value <<- hex_data(cells, value = seq_along(cells))
    value
  }
})

test_that("numeric, categorical, logical, and explicit aggregations are stable", {
  grid <- modern_grid()
  parent <- point_to_cell(c(0, 0), 4, grid)
  children <- cell_children(parent, progress = FALSE)$cell
  n <- length(children)
  category <- factor(c(rep("land", n - 2L), "water", "water"))
  x <- hex_data(
    children,
    value = seq_len(n),
    category = category,
    flag = c(rep(TRUE, n - 2L), FALSE, NA)
  )

  default <- cell_aggregate(x, 4)
  expect_equal(nrow(default), 1L)
  expect_equal(default$value, mean(seq_len(n)))
  expect_identical(default$category, factor("land", levels = levels(category)))
  expect_true(default$flag)

  total <- cell_aggregate(x, 4, fun = sum, value = "value")
  expect_equal(total$value, sum(seq_len(n)))

  missing <- hex_data(children, value = rep(NA_real_, n))
  expect_true(is.na(cell_aggregate(missing, 4)$value))
})

test_that("a local viewport selects finer detail than a global viewport", {
  x <- plot_fixture()
  global <- plot_resolution(
    x,
    extent = c(-180, 180, -90, 90),
    device_size = c(800, 600),
    max_cells = 200L
  )
  local <- plot_resolution(
    x,
    extent = c(-85, -79, 24, 32),
    device_size = c(800, 600),
    max_cells = 200L
  )
  expect_lt(global, local)
})

test_that("coarse-enough source cells retain native resolution", {
  grid <- modern_grid()
  parent <- point_to_cell(c(0, 0), 4, grid)
  children <- cell_children(parent, progress = FALSE)$cell
  x <- hex_data(children, value = seq_along(children))

  expect_identical(
    plot_resolution(x, device_size = c(1200, 800), max_cells = 1000L),
    5L
  )
})

test_that("LOD selection never constructs polygons", {
  x <- plot_fixture()
  testthat::local_mocked_bindings(
    cell_boundary = function(...) stop("fine polygons were generated"),
    .package = "globalhex"
  )
  expect_type(
    plot_resolution(x, extent = c(-180, 180, -90, 90), max_cells = 200L),
    "integer"
  )
})

test_that("plotting ignores missing values before choosing LOD", {
  skip_if_not_installed("sf")
  x <- plot_fixture()
  x$value[-1L] <- NA_real_
  file <- tempfile(fileext = ".png")
  grDevices::png(file, width = 600, height = 400)
  displayed <- plot(x, max_cells = 2L)
  grDevices::dev.off()

  expect_equal(nrow(displayed), 1L)
  expect_identical(attr(displayed, "plot_resolution"), 8L)
})

test_that("plot rendering switches cleanly between polygon and raster backends", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  grid <- modern_grid()
  cells <- point_to_cell(rbind(c(-10, 5), c(0, 0), c(10, 10)), 5, grid)
  x <- hex_data(cells, value = c(1, 2, 3))
  file <- tempfile(fileext = ".png")
  grDevices::png(file, width = 300, height = 200)

  polygon <- plot(
    x,
    resolution = 5,
    extent = c(-20, 20, -10, 20),
    render = "polygon"
  )
  expect_identical(attr(polygon, "plot_render"), "polygon")
  expect_s3_class(attr(polygon, "geometry"), "sfc")

  raster <- plot(
    x,
    resolution = 5,
    extent = c(-20, 20, -10, 20),
    render = "raster",
    device_size = c(300, 200),
    pal = function(n) grDevices::hcl.colors(n, "YlOrRd")
  )
  expect_identical(attr(raster, "plot_render"), "raster")
  expect_identical(
    attr(raster, "plot_raster_size"),
    c(width = 300L, height = 200L)
  )
  expect_null(attr(raster, "geometry"))

  automatic <- plot(
    x,
    resolution = 5,
    extent = c(-20, 20, -10, 20),
    render = "auto",
    raster_threshold = 2L,
    device_size = c(300, 200)
  )
  expect_identical(attr(automatic, "plot_render"), "raster")

  bordered <- plot(
    x,
    resolution = 5,
    extent = c(-20, 20, -10, 20),
    render = "auto",
    raster_threshold = 1L,
    border = "grey50"
  )
  grDevices::dev.off()
  expect_identical(attr(bordered, "plot_render"), "polygon")
  expect_gt(file.info(file)$size, 0)
})

test_that("raster rendering supports categories and explains ignored borders", {
  skip_if_not_installed("sf")
  skip_if_not_installed("terra")
  cells <- point_to_cell(rbind(c(-10, 5), c(0, 0), c(10, 10)), 5, modern_grid())
  x <- hex_data(cells, land = factor(c("crop", "forest", "crop")))
  file <- tempfile(fileext = ".png")
  grDevices::png(file, width = 300, height = 200)
  expect_warning(
    displayed <- plot(
      x,
      value = "land",
      resolution = 5,
      extent = c(-20, 20, -10, 20),
      render = "raster",
      device_size = c(300, 200),
      border = "white"
    ),
    class = "globalhex_warning_render"
  )
  grDevices::dev.off()
  expect_identical(attr(displayed, "plot_render"), "raster")
  expect_gt(file.info(file)$size, 0)
})

test_that("rendering arguments fail early and clearly", {
  x <- plot_fixture()
  expect_error(plot(x, render = "tiles"), class = "rlang_error")
  expect_error(
    plot(x, raster_threshold = 0L),
    class = "globalhex_error_argument"
  )
})

test_that("regional projected and dateline plots render reduced geometry", {
  skip_if_not_installed("sf")
  grid <- modern_grid()
  regional_cells <- point_to_cell(
    rbind(c(-84, 28), c(-82, 29), c(-80.5, 26)),
    7,
    grid
  )
  regional <- hex_data(regional_cells, value = c(1, 2, 3))
  file <- tempfile(fileext = ".png")
  grDevices::png(file, width = 600, height = 400)
  displayed <- plot(
    regional,
    resolution = 7,
    xlim = c(-86, -79),
    ylim = c(24, 32),
    crs = 3857
  )
  grDevices::dev.off()
  expect_gt(file.info(file)$size, 0)
  expect_identical(attr(displayed, "plot_resolution"), 7L)
  expect_identical(sf::st_crs(attr(displayed, "geometry"))$epsg, 3857L)

  seam_cells <- point_to_cell(rbind(c(179.99, 0), c(-179.99, 0)), 7, grid)
  seam <- hex_data(seam_cells, value = c(1, 3))
  seam_file <- tempfile(fileext = ".png")
  grDevices::png(seam_file, width = 600, height = 400)
  seam_display <- plot(
    seam,
    resolution = 7,
    extent = c(170, -170, -10, 10),
    crs = 4326
  )
  grDevices::dev.off()
  expect_gt(file.info(seam_file)$size, 0)
  expect_true(all(sf::st_is_valid(attr(seam_display, "geometry"))))
})
