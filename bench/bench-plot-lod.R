if (requireNamespace("globalhex", quietly = TRUE)) {
  library(globalhex)
} else if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  stop("Install globalhex or run from its source tree with pkgload installed.")
}

set.seed(20260906)
pool_size <- 100000L
points <- cbind(
  lon = stats::runif(pool_size, -180, 180),
  lat = asin(stats::runif(pool_size, -1, 1)) * 180 / pi
)
pool <- point_to_cell(points, resolution = 12)
grid <- cell_grid(pool)
sizes <- c(100000L, 1000000L)
if (identical(Sys.getenv("GLOBALHEX_BENCH_LARGE"), "true")) {
  sizes <- c(sizes, 10000000L)
}

time_one <- function(expression) unname(system.time(force(expression))[["elapsed"]])

for (n in sizes) {
  cells <- as_globalhex_cell(rep(as.character(pool), length.out = n), grid)
  x <- hex_data(cells, value = sin(seq_len(n) * 0.0001))
  gc()
  ancestor_seconds <- time_one(cell_parent(x$cell, resolution = 4))
  aggregate_seconds <- time_one(cell_aggregate(x, resolution = 4))
  resolution_seconds <- time_one(plot_resolution(
    x,
    extent = c(-180, 180, -90, 90),
    device_size = c(1200, 800),
    max_cells = 1000L
  ))
  prepared <- NULL
  prepare_seconds <- if (requireNamespace("sf", quietly = TRUE)) {
    time_one(prepared <- globalhex:::.prepare_plot_data(
      x,
      value = "value",
      resolution = NULL,
      max_cells = 1000L,
      fun = NULL,
      na.rm = TRUE,
      lod = TRUE,
      extent = c(-180, 180, -90, 90),
      device_size = c(1200, 800),
      cell_pixels = 3,
      crs = 4326
    ))
  } else {
    NA_real_
  }
  cat(sprintf(
    "n=%d ancestor=%.3fs aggregate=%.3fs lod-selection=%.3fs full-prepare=%.3fs polygons=%s\n",
    n,
    ancestor_seconds,
    aggregate_seconds,
    resolution_seconds,
    prepare_seconds,
    if (is.null(prepared)) "NA" else nrow(prepared$sf)
  ))
  rm(x, cells, prepared)
  gc()
}

cat("\nThe naive polygon comparison is intentionally limited to 100,000 cells.\n")
if (requireNamespace("sf", quietly = TRUE)) {
  source <- hex_data(pool, value = sin(points[, 2L] * pi / 180))
  naive_geometry <- time_one(sf::st_as_sf(source$cell))
  lod_prepare <- time_one(globalhex:::.prepare_plot_data(
    source,
    value = "value",
    resolution = NULL,
    max_cells = 1000L,
    fun = NULL,
    na.rm = TRUE,
    lod = TRUE,
    extent = c(-180, 180, -90, 90),
    device_size = c(1200, 800),
    cell_pixels = 3,
    crs = 4326
  ))
  cat(sprintf(
    "100k naive-geometry=%.3fs hierarchical-LOD-prepare=%.3fs\n",
    naive_geometry,
    lod_prepare
  ))
}
