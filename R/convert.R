#' Normalize point input to longitude/latitude columns
#' @noRd
.as_lonlat <- function(points, call = rlang::caller_env()) {
  if (inherits(points, "sf") || inherits(points, "sfc")) {
    rlang::check_installed("sf", reason = "to accept sf point input", call = call)
    geom <- if (inherits(points, "sf")) sf::st_geometry(points) else points
    types <- unique(as.character(sf::st_geometry_type(geom)))
    if (!all(types == "POINT")) {
      .abort("{.arg points} must contain POINT geometries only.", "globalhex_error_argument", call = call)
    }
    crs <- sf::st_crs(geom)
    if (!is.na(crs) && !identical(crs$epsg, 4326L)) {
      geom <- sf::st_transform(geom, 4326)
    }
    xy <- sf::st_coordinates(geom)
    return(tibble::tibble(lon = xy[, 1L], lat = xy[, 2L]))
  }

  if (is.numeric(points) && is.null(dim(points))) {
    if (length(points) != 2L) {
      .abort(
        "A numeric {.arg points} value must be {.code c(longitude, latitude)}.",
        "globalhex_error_argument",
        call = call
      )
    }
    if (is.na(points[[1L]]) || is.na(points[[2L]]) ||
        points[[1L]] < -180 || points[[1L]] > 180 ||
        points[[2L]] < -90 || points[[2L]] > 90) {
      .abort(
        "Longitude must be in [-180, 180] and latitude in [-90, 90], with no missing values.",
        "globalhex_error_coordinate",
        call = call
      )
    }
    return(tibble::tibble(lon = points[[1L]], lat = points[[2L]]))
  }

  if (!is.data.frame(points) && !is.matrix(points)) {
    .abort(
      "{.arg points} must be an sf object, a two-column data frame/matrix, or {.code c(lon, lat)}.",
      "globalhex_error_argument",
      call = call
    )
  }
  if (ncol(points) < 2L) {
    .abort("{.arg points} must have at least two columns.", "globalhex_error_argument", call = call)
  }

  nm <- tolower(colnames(points) %||% rep.int("", ncol(points)))
  lon_pos <- match(TRUE, nm %in% c("lon", "lng", "longitude", "x"), nomatch = 0L)
  lat_pos <- match(TRUE, nm %in% c("lat", "latitude", "y"), nomatch = 0L)
  if (!lon_pos || !lat_pos) {
    lon_pos <- 1L
    lat_pos <- 2L
  }
  column <- function(pos) {
    if (is.data.frame(points)) points[[pos]] else points[, pos]
  }
  out <- tibble::tibble(
    lon = as.numeric(column(lon_pos)),
    lat = as.numeric(column(lat_pos))
  )
  if (anyNA(out$lon) || anyNA(out$lat) ||
      any(out$lon < -180 | out$lon > 180) || any(out$lat < -90 | out$lat > 90)) {
    .abort(
      "Longitude must be in [-180, 180] and latitude in [-90, 90], with no missing values.",
      "globalhex_error_coordinate",
      call = call
    )
  }
  out
}

#' Format coordinates for DGGRID text input
#' @noRd
.format_number <- function(x) {
  format(x, digits = 17, scientific = FALSE, trim = TRUE)
}

#' Transform one bounded point batch
#' @noRd
.point_to_cell_one <- function(xy, resolution, grid) {
  dir <- .job_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE), add = TRUE)
  rows <- paste(.format_number(xy$lon), .format_number(xy$lat))
  .write_job_file(file.path(dir, "points.txt"), rows)
  meta <- c(
    "dggrid_operation TRANSFORM_POINTS",
    .meta_grid(grid, resolution),
    "input_file_name points.txt",
    "input_address_type GEO",
    'input_delimiter " "',
    .meta_hier_output(grid, "cells.txt"),
    "precision 15"
  )
  .run_job(dir, meta)
  ids <- trimws(readLines(file.path(dir, "cells.txt"), warn = FALSE))
  ids[nzchar(ids)]
}

#' Convert points to cells
#'
#' Coordinates consistently use longitude before latitude. Named data-frame
#' columns and sf POINT objects are preferred for clarity.
#'
#' @param points Point coordinates as `c(lon, lat)`, a two-column matrix/data
#'   frame, or an sf POINT object.
#' @param resolution Target resolution. Required for modern grids; fixed by a
#'   [legacy_grid()].
#' @param grid A grid definition from [hex_grid()] or [legacy_grid()].
#' @return A `globalhex_cell` vector with one cell per input point.
#' @examples
#' grid <- hex_grid()
#' point_to_cell(c(-73.9857, 40.7484), resolution = 5, grid = grid)
#' @export
point_to_cell <- function(points, resolution = NULL, grid = hex_grid()) {
  .check_grid(grid)
  xy <- .as_lonlat(points)
  keys <- paste(.format_number(xy$lon), .format_number(xy$lat), sep = "\r")
  keep <- !duplicated(keys)
  location <- match(keys, keys[keep])
  xy_unique <- xy[keep, , drop = FALSE]
  if (.is_legacy_grid(grid)) {
    if (!is.null(resolution) && !identical(as.integer(resolution), grid$resolution)) {
      .abort(
        "{.arg resolution} must match the resolution fixed by {.fn legacy_grid}.",
        "globalhex_error_resolution"
      )
    }
    if (!nrow(xy)) return(.new_cells(character(), grid))
    low <- as_dggridR_dggs(grid)
    ans <- dggridR::dgGEO_to_SEQNUM(low, xy_unique$lon, xy_unique$lat)$seqnum
    return(.new_cells(as.character(ans)[location], grid))
  }

  if (is.null(resolution)) {
    .abort("{.arg resolution} is required.", "globalhex_error_resolution")
  }
  resolution <- .validate_resolution(resolution, grid$system)
  if (!nrow(xy)) return(.new_cells(character(), grid))

  ids <- unlist(
    lapply(
      .chunk_indices(nrow(xy_unique)),
      function(i) .point_to_cell_one(xy_unique[i, , drop = FALSE], resolution, grid)
    ),
    use.names = FALSE
  )
  as_globalhex_cell(ids[location], grid)
}

#' Generate cell centers for one bounded, uniform-resolution batch
#' @noRd
.cell_centers_one <- function(cell, resolution) {
  grid <- .cell_grid(cell)
  dir <- .job_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE), add = TRUE)
  .write_cells(dir, cell)
  output <- c("point_output_type TEXT", "point_output_file_name centers")
  .run_job(dir, .generate_meta(grid, resolution, output))
  utils::read.csv(
    file.path(dir, "centers.txt"),
    header = FALSE,
    col.names = c("id", "lon", "lat"),
    colClasses = c("character", "numeric", "numeric"),
    quote = "",
    comment.char = ""
  )
}

#' Generate polygon features for one bounded, uniform-resolution batch
#' @noRd
.cell_features_one <- function(cell, resolution) {
  grid <- .cell_grid(cell)
  dir <- .job_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE), add = TRUE)
  .write_cells(dir, cell)
  output <- c("cell_output_type GEOJSON", "cell_output_file_name features")
  .run_job(dir, .generate_meta(grid, resolution, output))
  .read_geojson(file.path(dir, "features.geojson"))
}

#' Run bounded jobs for possibly mixed-resolution cells
#' @noRd
.cell_jobs <- function(cell, generator) {
  grid <- .cell_grid(cell)
  .check_cells_complete(cell)
  if (.is_legacy_grid(grid)) {
    .abort("Internal modern feature generation received legacy cells.", "globalhex_error_backend")
  }
  if (!length(cell)) return(list())
  resolution <- cell_resolution(cell)
  groups <- split(seq_along(cell), resolution)
  jobs <- list()
  for (i in groups) {
    for (j in .chunk_indices(length(i))) {
      jobs[[length(jobs) + 1L]] <- generator(cell[i[j]], resolution[[i[[1L]]]])
    }
  }
  jobs
}

#' Return cell centers
#'
#' @param cell A `globalhex_cell` vector.
#' @return A tibble with `cell`, `lon`, and `lat` columns.
#' @examples
#' x <- point_to_cell(c(-73.9857, 40.7484), 5)
#' cell_center(x)
#' @export
cell_center <- function(cell) {
  grid <- .cell_grid(cell)
  ids <- .cell_strings(cell)
  if (!length(cell)) {
    return(tibble::tibble(cell = cell, lon = double(), lat = double()))
  }
  .check_cells_complete(cell)
  unique <- .unique_cells(cell)

  if (.is_legacy_grid(grid)) {
    ans <- dggridR::dgSEQNUM_to_GEO(
      as_dggridR_dggs(grid),
      as.numeric(.cell_strings(unique$cell))
    )
    return(tibble::tibble(
      cell = cell,
      lon = ans$lon_deg[unique$location],
      lat = ans$lat_deg[unique$location]
    ))
  }

  chunks <- .cell_jobs(unique$cell, .cell_centers_one)
  centers <- do.call(rbind, chunks)
  pos <- match(ids, centers$id)
  tibble::tibble(cell = cell, lon = centers$lon[pos], lat = centers$lat[pos])
}

#' Return cell boundary rings
#'
#' @param cell A `globalhex_cell` vector.
#' @return A tibble with `cell` and `boundary`; `boundary` is a list-column of
#'   closed longitude/latitude matrices.
#' @export
cell_boundary <- function(cell) {
  grid <- .cell_grid(cell)
  ids <- .cell_strings(cell)
  if (!length(cell)) return(tibble::tibble(cell = cell, boundary = list()))
  .check_cells_complete(cell)
  unique <- .unique_cells(cell)

  if (.is_legacy_grid(grid)) {
    raw <- dggridR::dgcellstogrid(
      as_dggridR_dggs(grid),
      as.numeric(.cell_strings(unique$cell)),
      return_sf = FALSE
    )
    split_raw <- split(raw, as.character(raw$seqnum))
    rings <- lapply(.cell_strings(unique$cell), function(id) {
      part <- split_raw[[id]]
      matrix(c(part$x, part$y), ncol = 2L, dimnames = list(NULL, c("lon", "lat")))
    })
    return(tibble::tibble(cell = cell, boundary = rings[unique$location]))
  }

  features <- do.call(c, .cell_jobs(unique$cell, .cell_features_one))
  feature_ids <- vapply(features, function(x) as.character(x$properties$name), character(1))
  rings <- lapply(features, function(x) {
    coords <- x$geometry$coordinates[[1L]]
    matrix(
      as.numeric(unlist(coords, use.names = FALSE)),
      ncol = 2L,
      byrow = TRUE,
      dimnames = list(NULL, c("lon", "lat"))
    )
  })
  rings <- rings[match(ids, feature_ids)]
  tibble::tibble(cell = cell, boundary = rings)
}
