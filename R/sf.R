#' Convert cells to sf polygons
#'
#' @param x A `globalhex_cell` vector.
#' @param ... Passed to methods; currently unused.
#' @return An sf object in EPSG:4326 with one polygon per cell.
#' @exportS3Method sf::st_as_sf
st_as_sf.globalhex_cell <- function(x, ...) {
  rlang::check_installed(
    "sf",
    reason = "to convert globalhex cells to sf polygons",
    call = rlang::caller_env()
  )
  boundaries <- cell_boundary(x)$boundary
  polygons <- lapply(boundaries, function(ring) sf::st_polygon(list(unname(ring))))
  geometry <- sf::st_sfc(polygons, crs = 4326)
  sf::st_sf(tibble::tibble(cell = x), geometry = geometry)
}

#' Cover polygons with cells
#'
#' DGGRID selects cells whose nuclei fall inside the supplied polygon region.
#' Large polygons at fine resolutions can be expensive.
#'
#' @param polygon An sf/sfc POLYGON or MULTIPOLYGON object.
#' @param resolution Target grid resolution.
#' @param grid A modern grid from [hex_grid()].
#' @param include_holes Whether interior holes exclude cell nuclei.
#' @param max_cells Safety cap applied to the returned result.
#' @param densify Maximum angular spacing in degrees when DGGRID densifies
#'   polygon edges. The conservative default is intended for arbitrary input
#'   polygons; rectangular raster footprints can safely use a coarser value.
#' @param progress Show progress while DGGRID covers the polygon. `NULL` shows
#'   a delayed progress bar in interactive sessions, while `TRUE` or `FALSE`
#'   always enables or disables it.
#' @return A `globalhex_cell` vector.
#' @export
cell_cover <- function(
    polygon,
    resolution,
    grid = hex_grid(),
    include_holes = TRUE,
    max_cells = 100000L,
    progress = NULL,
    densify = 0.01) {
  .check_grid(grid)
  progress <- .optional_flag(progress, "progress")
  if (.is_legacy_grid(grid)) {
    .abort("{.fn cell_cover} requires modern DGGRID.", "globalhex_error_unsupported")
  }
  resolution <- .validate_resolution(resolution, grid$system)
  rlang::check_installed(
    "sf",
    reason = "to cover polygon geometries with cells",
    call = rlang::caller_env()
  )
  if (!inherits(polygon, "sf") && !inherits(polygon, "sfc")) {
    .abort("{.arg polygon} must be an sf or sfc object.", "globalhex_error_argument")
  }
  max_cells <- .scalar_int(max_cells, "max_cells")
  if (max_cells < 1L) {
    .abort("{.arg max_cells} must be positive.", "globalhex_error_argument")
  }
  if (!is.numeric(densify) || length(densify) != 1L || is.na(densify) ||
      !is.finite(densify) || densify <= 0) {
    .abort("{.arg densify} must be one positive number.", "globalhex_error_argument")
  }
  geom <- if (inherits(polygon, "sf")) sf::st_geometry(polygon) else polygon
  types <- unique(as.character(sf::st_geometry_type(geom)))
  if (!all(types %in% c("POLYGON", "MULTIPOLYGON"))) {
    .abort(
      "{.arg polygon} must contain POLYGON or MULTIPOLYGON geometries.",
      "globalhex_error_argument"
    )
  }
  crs <- sf::st_crs(geom)
  if (is.na(crs)) {
    sf::st_crs(geom) <- 4326
  } else if (!identical(crs$epsg, 4326L)) {
    geom <- sf::st_transform(geom, 4326)
  }

  dir <- .job_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE), add = TRUE)
  # The bundled DGGRID is built without GDAL, so clip to exterior rings via
  # AIGEN and remove nuclei that fall inside holes afterwards.
  .write_aigen(geom, file.path(dir, "region.gen"))
  meta <- c(
    "dggrid_operation GENERATE_GRID",
    .meta_grid(grid, resolution),
    "clip_subset_type AIGEN",
    "clip_region_files region.gen",
    paste("geodetic_densify", format(densify, digits = 15, scientific = FALSE)),
    "output_cell_label_type OUTPUT_ADDRESS_TYPE",
    .meta_hier_output(grid),
    "point_output_type GEOJSON",
    "point_output_file_name centers",
    "precision 15"
  )
  progress_id <- .progress_start(
    "Covering polygon",
    total = 1L,
    progress = progress,
    call = rlang::caller_env()
  )
  on.exit(.progress_done(progress_id), add = TRUE)
  .run_job(dir, meta, timeout = 300000)
  .progress_update(progress_id)
  features <- .read_geojson(file.path(dir, "centers.geojson"))
  ids <- vapply(features, function(x) as.character(x$properties$name), character(1))
  if (isTRUE(include_holes) && length(ids)) {
    holes <- .polygon_holes(geom)
    if (length(holes)) {
      centers <- do.call(rbind, lapply(features, function(x) {
        as.numeric(unlist(x$geometry$coordinates))[1:2]
      }))
      points <- sf::st_as_sf(
        data.frame(lon = centers[, 1], lat = centers[, 2]),
        coords = c("lon", "lat"),
        crs = 4326
      )
      in_hole <- lengths(sf::st_intersects(points, holes)) > 0L
      if (any(in_hole)) {
        # Keep nuclei on islands that sit inside another polygon's hole.
        in_hole[in_hole] <- lengths(sf::st_intersects(points[in_hole, ], geom)) == 0L
      }
      ids <- ids[!in_hole]
    }
  }
  if (length(ids) > max_cells) {
    .abort(
      "Polygon cover returned {length(ids)} cells, exceeding {.arg max_cells} ({max_cells}).",
      "globalhex_error_size",
      size = length(ids),
      max_cells = max_cells
    )
  }
  as_globalhex_cell(ids, grid)
}

#' Write polygon exterior rings as a DGGRID AIGEN clipping file
#' @noRd
.write_aigen <- function(geom, path) {
  rings <- .polygon_rings(geom)
  lines <- unlist(lapply(seq_along(rings), function(i) {
    ring <- rings[[i]][["exterior"]]
    c(
      as.character(i),
      sprintf("%.15f %.15f", ring[, 1], ring[, 2]),
      "END"
    )
  }), use.names = FALSE)
  writeLines(c(lines, "END"), path)
  invisible(path)
}

#' Interior rings (holes) as an sfc of polygons, or an empty list
#' @noRd
.polygon_holes <- function(geom) {
  holes <- unlist(
    lapply(.polygon_rings(geom), function(x) x[["holes"]]),
    recursive = FALSE
  )
  if (!length(holes)) return(list())
  sf::st_sfc(lapply(holes, function(h) sf::st_polygon(list(h))), crs = 4326)
}

#' Split POLYGON/MULTIPOLYGON geometries into exterior and hole rings
#' @noRd
.polygon_rings <- function(geom) {
  polygons <- unlist(lapply(geom, function(g) {
    if (inherits(g, "MULTIPOLYGON")) unclass(g) else list(unclass(g))
  }), recursive = FALSE)
  lapply(polygons, function(p) {
    list(exterior = p[[1L]][, 1:2, drop = FALSE], holes = lapply(p[-1L], function(h) h[, 1:2, drop = FALSE]))
  })
}
