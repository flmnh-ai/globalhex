if (requireNamespace("globalhex", quietly = TRUE)) {
  library(globalhex)
} else if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  stop("Install globalhex or run from its source tree with pkgload installed.")
}

if (!requireNamespace("bench", quietly = TRUE)) {
  stop("Install the suggested bench package before running this script.")
}

set.seed(20260811)
grid <- hex_grid()
points <- cbind(
  lon = stats::runif(2000, -179, 179),
  lat = stats::runif(2000, -85, 85)
)
cells <- unique(point_to_cell(points, resolution = 8, grid = grid))

print(globalhex_info())

conversion <- bench::press(
  n = c(1L, 100L, 1000L),
  {
    point_batch <- points[seq_len(n), , drop = FALSE]
    cell_batch <- cells[seq_len(n)]
    bench::mark(
      point_to_cell = point_to_cell(point_batch, 8, grid),
      cell_center = cell_center(cell_batch),
      iterations = 5L,
      check = FALSE
    )
  }
)
print(conversion)

origins <- cells[seq_len(10L)]
neighbors <- cell_neighbors(origins)
destinations <- neighbors$cell[!duplicated(as.character(neighbors$origin))]
hierarchy <- bench::mark(
  children = cell_children(cell_parent(origins), progress = FALSE),
  disk_k2 = cell_disk(origins, 2, progress = FALSE),
  distance_k1 = cell_distance(
    origins,
    destinations,
    progress = FALSE
  ),
  iterations = 5L,
  check = FALSE
)
print(hierarchy)
