#' Convert cells to sf polygons
#'
#' Cell boundaries are spherical polygons: DGGRID reports their vertices, and
#' the edges between them are great-circle arcs. That is exactly what
#' [sf::st_area()] and other spherical (s2) operations expect, but a flat
#' longitude/latitude map draws straight lines between vertices, so cells that
#' cross the antimeridian (180 degrees longitude) would stretch across the whole map and cells
#' containing a pole would draw as twisted shapes.
#'
#' With `wrap = TRUE` (the default) the polygons are prepared for flat
#' longitude/latitude use:
#'
#' * edges longer than one degree are densified along their great circles;
#' * cells crossing the antimeridian are split into a `MULTIPOLYGON` whose
#'   parts touch longitude -180 and 180;
#' * cells containing a pole are closed along the map edge at latitude 90 or -90,
#'   so they draw as a polar cap.
#'
#' Longitudes stay in \[-180, 180\] and spherical areas are unchanged. When
#' any cell is split, every geometry is returned as a `MULTIPOLYGON` so the
#' column has a single type. For a Pacific-centred map, use
#' [sf::st_shift_longitude()] on the result to move longitudes to \[0, 360\].
#'
#' Use `wrap = FALSE` for the raw spherical polygons with one ring of
#' DGGRID vertices per cell, for example before projecting to a polar CRS.
#'
#' @param x A `globalhex_cell` vector.
#' @param wrap Whether to split antimeridian cells, close polar cells, and
#'   densify long edges for flat longitude/latitude use.
#' @param ... Passed to methods; currently unused.
#' @return An sf object in EPSG:4326 with one row and geometry per cell.
#' @examples
#' if (requireNamespace("sf", quietly = TRUE)) {
#'   seam <- point_to_cell(c(180, 10), 6)
#'   sf::st_geometry(sf::st_as_sf(seam))
#'   sf::st_geometry(sf::st_as_sf(seam, wrap = FALSE))
#' }
#' @exportS3Method sf::st_as_sf
st_as_sf.globalhex_cell <- function(x, wrap = TRUE, ...) {
  rlang::check_installed(
    "sf",
    reason = "to convert globalhex cells to sf polygons",
    call = rlang::caller_env()
  )
  wrap <- .flag(wrap, "wrap")
  boundaries <- cell_boundary(x)$boundary
  geometry <- if (wrap) {
    .flat_cell_geometry(boundaries)
  } else {
    sf::st_sfc(
      lapply(boundaries, function(ring) sf::st_polygon(list(unname(ring)))),
      crs = 4326
    )
  }
  sf::st_sf(tibble::tibble(cell = x), geometry = geometry)
}

#' Cell polygons for flat longitude/latitude maps
#'
#' Densifies long edges along great circles, closes pole-containing cells
#' along latitude 90 or -90, and splits cells that leave the longitude window
#' `[center - 180, center + 180]` into MULTIPOLYGONs. Only cells that need
#' it are processed; the rest become plain POLYGONs.
#' @noRd
.flat_cell_geometry <- function(boundaries, center = 0, max_segment = 1) {
  lower <- center - 180
  rings <- lapply(boundaries, function(ring) {
    ring <- unname(ring)
    ring[, 1L] <- (ring[, 1L] - lower) %% 360 + lower
    ring
  })
  work <- .rings_need_work(rings, max_segment)
  geometry <- vector("list", length(rings))
  geometry[!work] <- lapply(rings[!work], function(ring) sf::st_polygon(list(ring)))
  split <- FALSE
  for (i in which(work)) {
    parts <- .flat_ring_parts(.densify_ring(rings[[i]], max_segment), lower)
    if (length(parts) == 1L) {
      geometry[[i]] <- sf::st_polygon(parts[[1L]])
    } else {
      geometry[[i]] <- sf::st_multipolygon(parts)
      split <- TRUE
    }
  }
  if (split) {
    # One geometry type per column; avoids st_cast(), which is slow per row.
    single <- vapply(geometry, inherits, logical(1), what = "POLYGON")
    geometry[single] <- lapply(geometry[single], function(g) {
      structure(list(unclass(g)), class = c("XY", "MULTIPOLYGON", "sfg"))
    })
  }
  sf::st_sfc(geometry, crs = 4326)
}

#' Flag rings that cross the window edge, touch a pole, or have long edges
#'
#' Edge length is measured both in arc and in longitude.
#' @noRd
.rings_need_work <- function(rings, max_segment) {
  if (!length(rings)) return(logical())
  sizes <- vapply(rings, nrow, integer(1))
  id <- rep.int(seq_along(rings), sizes)
  coords <- do.call(rbind, rings)
  xyz <- .lonlat_to_xyz(coords)
  n <- nrow(coords)
  same <- id[-n] == id[-1L]
  dot <- rowSums(xyz[-n, , drop = FALSE] * xyz[-1L, , drop = FALSE])
  arc <- acos(pmin(1, pmax(-1, dot))) * 180 / pi
  dlon <- abs(.wrap_longitude(diff(coords[, 1L])))
  long_edge <- same & (arc > max_segment | dlon > max_segment)
  span <- vapply(split(coords[, 1L], id), function(x) diff(range(x)), numeric(1))
  pole <- abs(coords[, 2L]) > 90 - 1e-6
  span > 180 |
    tabulate(id[pole], nbins = length(rings)) > 0L |
    tabulate(id[-n][long_edge], nbins = length(rings)) > 0L
}

#' @noRd
.lonlat_to_xyz <- function(ring) {
  lon <- ring[, 1L] * pi / 180
  lat <- ring[, 2L] * pi / 180
  cbind(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat))
}

#' @noRd
.xyz_to_lonlat <- function(p) {
  c(atan2(p[[2L]], p[[1L]]), atan2(p[[3L]], sqrt(p[[1L]]^2 + p[[2L]]^2))) * 180 / pi
}

#' Insert great-circle points until no step exceeds `max_segment` degrees
#'
#' Steps are limited both in arc and in longitude, so edges passing close to
#' a pole (where longitude changes quickly) follow their true path on a flat
#' map. Bisection stops at a negligible arc length, which bounds the work for
#' an edge passing exactly through a pole.
#' @noRd
.densify_ring <- function(ring, max_segment) {
  xyz <- .lonlat_to_xyz(ring)
  bisect <- function(a, b, la, lb, depth) {
    arc <- acos(min(1, max(-1, sum(a * b)))) * 180 / pi
    dlon <- abs(.wrap_longitude(lb[[1L]] - la[[1L]]))
    if (depth > 40L || arc < 1e-8 || (arc <= max_segment && dlon <= max_segment)) {
      return(NULL)
    }
    m <- a + b
    m <- m / sqrt(sum(m^2))
    lm <- .xyz_to_lonlat(m)
    rbind(bisect(a, m, la, lm, depth + 1L), lm, bisect(m, b, lm, lb, depth + 1L))
  }
  n <- nrow(ring)
  pieces <- vector("list", n)
  for (j in seq_len(n - 1L)) {
    pieces[[j]] <- rbind(
      ring[j, , drop = FALSE],
      bisect(xyz[j, ], xyz[j + 1L, ], ring[j, ], ring[j + 1L, ], 0L)
    )
  }
  pieces[[n]] <- ring[n, , drop = FALSE]
  out <- do.call(rbind, pieces)
  dimnames(out) <- NULL
  out
}

#' Unwrap a closed ring and cut it into planar polygon parts in a window
#'
#' Longitudes are made continuous along the ring. Vertices at a pole have no
#' longitude of their own, so each becomes two vertices on the map edge at the
#' longitudes of its neighbours. A ring whose longitudes wind once around the
#' globe contains a pole and is closed along latitude 90 or -90. The resulting
#' planar polygon is cut at multiples of 360 degrees and the pieces shifted
#' back into the window starting at `lower`.
#' @noRd
.flat_ring_parts <- function(ring, lower) {
  ring <- ring[-nrow(ring), , drop = FALSE]
  at_pole <- abs(ring[, 2L]) > 90 - 1e-6
  if (all(at_pole)) return(list())
  # Start at a vertex with a defined longitude.
  first <- which(!at_pole)[[1L]]
  order <- c(seq.int(first, nrow(ring)), seq_len(first - 1L))
  ring <- ring[order, , drop = FALSE]
  at_pole <- at_pole[order]

  keep <- which(!at_pole)
  lon <- ring[keep, 1L]
  lat <- ring[keep, 2L]
  # Longitude step to the next defined vertex, closing back to the first.
  step <- diff(c(lon, lon[[1L]]))
  step <- .wrap_longitude(step)
  pole_after <- vapply(seq_along(keep), function(j) {
    next_index <- if (j < length(keep)) keep[[j + 1L]] else nrow(ring) + 1L
    next_index - keep[[j]] > 1L
  }, logical(1))
  total <- sum(step)
  through_pole <- which(pole_after & abs(step) > 179)
  if (length(through_pole) && abs(total) > 180) {
    # An edge through the pole has no preferred direction around it. The
    # cell lies on one side of that edge and does not wind around the pole.
    j <- through_pole[[1L]]
    step[[j]] <- step[[j]] - 360 * sign(step[[j]])
    total <- sum(step)
  }
  unwrapped <- lon[[1L]] + c(0, cumsum(step))
  winds <- abs(total) > 180
  # Without a pole the ring returns exactly to its start.
  if (!winds) unwrapped[[length(unwrapped)]] <- unwrapped[[1L]]
  pole_lat <- if (mean(lat) >= 0) 90 else -90

  coords <- list()
  for (j in seq_along(keep)) {
    coords[[length(coords) + 1L]] <- c(unwrapped[[j]], lat[[j]])
    if (pole_after[[j]]) {
      coords[[length(coords) + 1L]] <- c(unwrapped[[j]], pole_lat)
      coords[[length(coords) + 1L]] <- c(unwrapped[[j + 1L]], pole_lat)
    }
  }
  end <- unwrapped[[length(unwrapped)]]
  coords[[length(coords) + 1L]] <- c(end, lat[[1L]])
  if (winds) {
    # The ring winds around a pole: close it along the map edge.
    coords[[length(coords) + 1L]] <- c(end, pole_lat)
    coords[[length(coords) + 1L]] <- c(unwrapped[[1L]], pole_lat)
    coords[[length(coords) + 1L]] <- c(unwrapped[[1L]], lat[[1L]])
  }
  shape <- do.call(rbind, coords)
  shape <- shape[c(TRUE, rowSums(abs(diff(shape))) > 0), , drop = FALSE]
  span <- range(shape[, 1L])
  if (!winds && span[[1L]] >= lower && span[[2L]] <= lower + 360) {
    return(list(list(shape)))
  }
  polygon <- sf::st_make_valid(sf::st_polygon(list(shape)))

  windows <- seq(floor((span[[1L]] - lower) / 360), ceiling((span[[2L]] - lower) / 360) - 1)
  parts <- list()
  for (k in windows) {
    offset <- lower + 360 * k
    box <- sf::st_polygon(list(rbind(
      c(offset, -90), c(offset + 360, -90), c(offset + 360, 90),
      c(offset, 90), c(offset, -90)
    )))
    piece <- sf::st_intersection(polygon, box)
    if (sf::st_is_empty(piece)) next
    piece <- sf::st_sfc(piece)
    if (inherits(piece, "sfc_GEOMETRYCOLLECTION")) {
      piece <- sf::st_collection_extract(piece, "POLYGON")
    }
    for (g in piece) {
      polys <- if (inherits(g, "MULTIPOLYGON")) unclass(g) else list(unclass(g))
      for (p in polys) {
        p <- lapply(p, function(r) {
          r[, 1L] <- r[, 1L] - 360 * k
          r
        })
        parts[[length(parts) + 1L]] <- p
      }
    }
  }
  if (length(parts) < 2L) return(parts)
  # Rejoin pieces that only touched along a cut or at the map edge.
  merged <- sf::st_union(sf::st_sfc(sf::st_multipolygon(parts)))[[1L]]
  if (inherits(merged, "POLYGON")) list(unclass(merged)) else unclass(merged)
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
