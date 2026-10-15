#' Sample raster values at cell centers
#'
#' `cell_sample()` is the fast, geometry-free raster path. Cell centers are
#' transformed into the raster coordinate reference system and sampled with
#' [terra::extract()]. Use [cell_extract()] when partial raster-pixel coverage
#' must be represented exactly.
#'
#' @param cell A `globalhex_cell` vector.
#' @param raster A [terra::SpatRaster].
#' @param method Either `"simple"` for nearest-cell lookup or `"bilinear"`.
#' @return A [hex_data()] object with one row per input cell and one column per
#'   raster layer.
#' @export
cell_sample <- function(cell, raster, method = c("simple", "bilinear")) {
  .cell_grid(cell)
  .check_cells_complete(cell)
  .check_spat_raster(raster)
  method <- rlang::arg_match(method)
  if (!length(cell)) {
    values <- terra::extract(raster, matrix(numeric(), ncol = 2L), method = method)
    return(.raster_hex_data(cell, values))
  }
  raster_crs <- .raster_crs(raster)
  unique <- .unique_cells(cell)
  centers <- cell_center(unique$cell)
  points <- sf::st_as_sf(centers, coords = c("lon", "lat"), crs = 4326)
  points <- sf::st_transform(points, raster_crs)
  xy <- sf::st_coordinates(points)[, 1:2, drop = FALSE]
  xy <- .align_raster_longitude_points(xy, raster)
  values <- terra::extract(raster, xy, method = method)
  values <- tibble::as_tibble(values)[unique$location, , drop = FALSE]
  .raster_hex_data(cell, values)
}

#' Extract raster summaries into cells
#'
#' Cell polygons are generated only for the supplied cells. Extraction uses
#' exact raster-pixel coverage through [exactextractr::exact_extract()]. With
#' `fun = NULL`, continuous layers use an area-weighted mean and categorical
#' layers use a coverage-weighted mode. This makes longitude/latitude rasters
#' safe by default, because their pixels do not have equal physical area.
#'
#' @param cell A `globalhex_cell` vector.
#' @param raster A [terra::SpatRaster].
#' @param fun A named `exactextractr` summary, a vector of summary names, or a
#'   custom summary function. `NULL` chooses a type-aware default.
#' @param weights Weights for continuous defaults and explicit weighted
#'   summaries. Use `"area"` (the default), `NULL` for coverage fractions
#'   alone, or a compatible [terra::SpatRaster].
#' @param ... Additional arguments passed to [exactextractr::exact_extract()].
#' @param progress Whether `exactextractr` displays progress. `NULL` follows
#'   [interactive()].
#' @return A [hex_data()] object with one row per input cell.
#' @export
cell_extract <- function(
    cell,
    raster,
    fun = NULL,
    weights = "area",
    ...,
    progress = NULL) {
  .cell_grid(cell)
  .check_cells_complete(cell)
  .check_spat_raster(raster)
  .check_raster_fun(fun)
  progress <- .optional_flag(progress, "progress")
  if (is.null(progress)) progress <- interactive()
  weights <- .check_raster_weights(weights, raster)
  dots <- rlang::list2(...)
  .check_extract_dots(dots)

  unique <- .unique_cells(cell)
  polygons <- .cell_raster_polygons(unique$cell)
  values <- .extract_raster_values(
    raster,
    polygons,
    fun = fun,
    weights = weights,
    progress = progress,
    dots = dots
  )
  values <- values[unique$location, , drop = FALSE]
  .raster_hex_data(cell, values)
}

#' Convert a raster footprint to global-hex data
#'
#' `raster_to_cell()` covers the raster extent with DGGS cells, includes the
#' neighboring edge cells needed for exact overlap, removes non-intersecting
#' candidates, and extracts raster summaries. It returns no polygon geometry.
#'
#' @param raster A [terra::SpatRaster].
#' @param resolution Target DGGS resolution.
#' @param grid A modern grid from [hex_grid()].
#' @param fun,weights,... Extraction arguments passed to [cell_extract()].
#' @param max_cells Hard maximum number of returned cells.
#' @param progress Show progress where supported. `NULL` uses interactive
#'   defaults.
#' @param drop_na Whether to remove cells for which every extracted raster
#'   summary is missing.
#' @return A [hex_data()] object covering the raster extent.
#' @export
raster_to_cell <- function(
    raster,
    resolution,
    grid = hex_grid(),
    fun = NULL,
    weights = "area",
    ...,
    max_cells = 100000L,
    progress = NULL,
    drop_na = TRUE) {
  .check_grid(grid)
  if (.is_legacy_grid(grid)) {
    .abort(
      "{.fn raster_to_cell} requires hierarchical Z7 or Z3 cells.",
      "globalhex_error_unsupported"
    )
  }
  .check_spat_raster(raster)
  .check_raster_fun(fun)
  resolution <- .validate_resolution(resolution, grid$system)
  max_cells <- .scalar_int(max_cells, "max_cells")
  if (max_cells < 1L) {
    .abort("{.arg max_cells} must be positive.", "globalhex_error_argument")
  }
  progress <- .optional_flag(progress, "progress")
  drop_na <- .optional_flag(drop_na, "drop_na")
  if (is.null(drop_na)) drop_na <- TRUE
  weights <- .check_raster_weights(weights, raster)
  dots <- rlang::list2(...)
  .check_extract_dots(dots)

  footprint <- .raster_footprint(raster)
  if (.raster_spans_all_longitudes(raster)) {
    total <- .grid_cell_count(resolution, grid)
    if (total > max_cells) {
      .abort(
        "A global resolution-{resolution} grid contains {format(total, big.mark = ',')} cells, exceeding {.arg max_cells} ({max_cells}).",
        "globalhex_error_size",
        resolution = resolution,
        total = total,
        max_cells = max_cells
      )
    }
    candidates <- .all_grid_cells(resolution, grid)
  } else {
    covered <- cell_cover(
      footprint,
      resolution = resolution,
      grid = grid,
      max_cells = max_cells,
      densify = .raster_cover_densify(resolution, grid),
      progress = progress
    )
    anchors <- suppressWarnings(sf::st_point_on_surface(footprint))
    anchor_xy <- sf::st_coordinates(anchors)[, 1:2, drop = FALSE]
    anchor_cells <- point_to_cell(anchor_xy, resolution = resolution, grid = grid)
    seeds <- unique(vctrs::vec_c(covered, anchor_cells))
    adjacent <- if (length(seeds)) cell_neighbors(seeds)$cell else seeds
    candidates <- unique(vctrs::vec_c(seeds, adjacent))
  }

  polygons <- .cell_raster_polygons(candidates)
  visible <- lengths(sf::st_intersects(polygons, footprint)) > 0L
  candidates <- candidates[visible]
  polygons <- polygons[visible, , drop = FALSE]
  if (length(candidates) > max_cells) {
    .abort(
      "Raster coverage returned {length(candidates)} cells, exceeding {.arg max_cells} ({max_cells}).",
      "globalhex_error_size",
      size = length(candidates),
      max_cells = max_cells
    )
  }

  exact_progress <- progress
  if (is.null(exact_progress)) exact_progress <- interactive()
  values <- .extract_raster_values(
    raster,
    polygons,
    fun = fun,
    weights = weights,
    progress = exact_progress,
    dots = dots
  )
  out <- .raster_hex_data(candidates, values)
  if (drop_na) {
    columns <- setdiff(names(out), "cell")
    keep <- Reduce(`|`, lapply(out[columns], function(x) !is.na(x)))
    out <- .new_hex_data(out[keep, , drop = FALSE])
  }
  out
}

#' Validate the modern raster input and optional packages
#' @noRd
.check_spat_raster <- function(x, call = rlang::caller_env()) {
  rlang::check_installed("terra", reason = "to read modern raster data", call = call)
  rlang::check_installed("sf", reason = "to transform raster and cell geometry", call = call)
  if (!inherits(x, "SpatRaster")) {
    .abort("{.arg raster} must be a <SpatRaster>.", "globalhex_error_argument", call = call)
  }
  if (terra::nlyr(x) < 1L) {
    .abort("{.arg raster} must contain at least one layer.", "globalhex_error_argument", call = call)
  }
  invisible(x)
}

#' Resolve and validate a raster CRS
#' @noRd
.raster_crs <- function(raster, call = rlang::caller_env()) {
  definition <- terra::crs(raster, proj = TRUE)
  crs <- if (length(definition) == 1L && !is.na(definition) && nzchar(definition)) {
    tryCatch(sf::st_crs(definition), error = function(e) NULL)
  } else {
    NULL
  }
  if (is.null(crs) || is.na(crs)) {
    .abort(
      "{.arg raster} must have a coordinate reference system.",
      "globalhex_error_crs",
      call = call
    )
  }
  crs
}

#' Validate exact-extraction weights
#' @noRd
.check_raster_weights <- function(weights, raster, call = rlang::caller_env()) {
  if (is.null(weights)) return(NULL)
  if (is.character(weights) && length(weights) == 1L && !is.na(weights) &&
      identical(weights, "area")) {
    return(weights)
  }
  if (inherits(weights, "SpatRaster")) {
    layers <- terra::nlyr(weights)
    if (!layers %in% c(1L, terra::nlyr(raster))) {
      .abort(
        "A weighting raster must have one layer or the same number of layers as {.arg raster}.",
        "globalhex_error_argument",
        call = call
      )
    }
    return(weights)
  }
  .abort(
    "{.arg weights} must be {.val area}, `NULL`, or a <SpatRaster>.",
    "globalhex_error_argument",
    call = call
  )
}

#' Validate an exact-extraction summary
#' @noRd
.check_raster_fun <- function(fun, call = rlang::caller_env()) {
  if (is.null(fun) || is.function(fun) ||
      (is.character(fun) && length(fun) > 0L && !anyNA(fun) && all(nzchar(fun)))) {
    return(invisible(fun))
  }
  .abort(
    "{.arg fun} must be `NULL`, a function, or one or more summary names.",
    "globalhex_error_argument",
    call = call
  )
}

#' Reject arguments controlled by the wrapper
#' @noRd
.check_extract_dots <- function(dots, call = rlang::caller_env()) {
  reserved <- intersect(
    names(dots),
    c("x", "y", "fun", "weights", "progress", "force_df")
  )
  if (length(reserved)) {
    .abort(
      "Arguments controlled by {.pkg globalhex} cannot be supplied in `...`: {paste(reserved, collapse = ', ')}.",
      "globalhex_error_argument",
      call = call
    )
  }
  invisible(dots)
}

#' Construct wrapped cell polygons for raster work
#'
#' Seam cells are split and polar cells closed so they are valid planar
#' polygons in longitude/latitude.
#' @noRd
.cell_raster_polygons <- function(cell) {
  sf::st_as_sf(cell, wrap = TRUE)
}

#' Run exact extraction with type-aware defaults
#' @noRd
.extract_raster_values <- function(raster, polygons, fun, weights, progress, dots) {
  rlang::check_installed(
    "exactextractr",
    reason = "to calculate exact raster coverage",
    call = rlang::caller_env()
  )
  raster_crs <- .raster_crs(raster)
  polygons <- sf::st_transform(polygons, raster_crs)
  if (.raster_uses_positive_longitude(raster)) {
    polygons <- suppressWarnings(sf::st_shift_longitude(polygons))
  }
  layer_names <- .raster_layer_names(raster)

  if (!is.null(fun)) {
    call_weights <- if (is.function(fun) || any(grepl("^weighted_", fun))) weights else NULL
    call_dots <- dots
    if (is.character(fun) && is.null(call_dots$colname_fun)) {
      call_dots$colname_fun <- .raster_summary_name
    }
    out <- .exact_extract_call(
      raster,
      polygons,
      fun = fun,
      weights = call_weights,
      progress = progress,
      dots = call_dots
    )
    out <- tibble::as_tibble(out)
    if (is.character(fun) && length(fun) == 1L && ncol(out) == terra::nlyr(raster)) {
      names(out) <- layer_names
      if (fun %in% c("mode", "majority")) {
        out <- .restore_raster_categories(out, raster, seq_len(terra::nlyr(raster)))
      }
    }
    return(out)
  }

  categorical <- terra::is.factor(raster)
  columns <- vector("list", terra::nlyr(raster))
  continuous_index <- which(!categorical)
  if (length(continuous_index)) {
    continuous <- raster[[continuous_index]]
    continuous_weights <- .subset_raster_weights(
      weights,
      continuous_index,
      terra::nlyr(raster)
    )
    summary <- if (is.null(continuous_weights)) "mean" else "weighted_mean"
    part <- .exact_extract_call(
      continuous,
      polygons,
      fun = summary,
      weights = continuous_weights,
      progress = progress,
      dots = dots
    )
    part <- as.data.frame(part)
    for (i in seq_along(continuous_index)) {
      columns[[continuous_index[[i]]]] <- part[[i]]
    }
  }

  categorical_index <- which(categorical)
  if (length(categorical_index)) {
    part <- .exact_extract_call(
      raster[[categorical_index]],
      polygons,
      fun = "mode",
      weights = NULL,
      progress = progress,
      dots = dots
    )
    part <- as.data.frame(part)
    names(part) <- layer_names[categorical_index]
    part <- .restore_raster_categories(part, raster, categorical_index)
    for (i in seq_along(categorical_index)) {
      columns[[categorical_index[[i]]]] <- part[[i]]
    }
  }

  tibble::as_tibble(stats::setNames(columns, layer_names))
}

#' Call exactextractr while retaining dynamic dots
#' @noRd
.exact_extract_call <- function(raster, polygons, fun, weights, progress, dots) {
  arguments <- c(
    list(
      x = raster,
      y = polygons,
      fun = fun,
      weights = weights,
      progress = progress,
      force_df = TRUE
    ),
    dots
  )
  do.call(exactextractr::exact_extract, arguments)
}

#' Produce tidy names for multiple explicit summaries
#' @noRd
.raster_summary_name <- function(
    values,
    weights,
    fun_name,
    fun_value,
    nvalues,
    nweights) {
  suffix <- fun_name
  if (length(fun_value) && !is.na(fun_value)) {
    suffix <- paste(fun_name, format(fun_value, trim = TRUE), sep = "_")
  }
  paste(values, suffix, sep = "_")
}

#' Select corresponding layers from an optional weighting raster
#' @noRd
.subset_raster_weights <- function(weights, index, total_layers) {
  if (!inherits(weights, "SpatRaster") || terra::nlyr(weights) == 1L) return(weights)
  if (terra::nlyr(weights) == total_layers) return(weights[[index]])
  weights
}

#' Restore active terra category labels after exact extraction
#' @noRd
.restore_raster_categories <- function(x, raster, index) {
  categories <- terra::cats(raster)
  for (i in seq_along(index)) {
    layer <- index[[i]]
    table <- categories[[layer]]
    if (is.null(table) || ncol(table) < 2L) next
    label_column <- terra::activeCat(raster, layer = layer) + 1L
    labels <- table[[label_column]]
    x[[i]] <- factor(
      labels[match(x[[i]], table[[1L]])],
      levels = unique(labels)
    )
  }
  x
}

#' Normalize raster layer names
#' @noRd
.raster_layer_names <- function(raster) {
  names <- names(raster)
  blank <- is.na(names) | !nzchar(names)
  names[blank] <- paste0("layer_", which(blank))
  vctrs::vec_as_names(names, repair = "unique", quiet = TRUE)
}

#' Detect the common 0-to-360 longitude convention
#' @noRd
.raster_uses_positive_longitude <- function(raster) {
  terra::is.lonlat(raster) && terra::xmin(raster) >= 0 && terra::xmax(raster) > 180
}

#' Align WGS84 point longitudes with a 0-to-360 raster
#' @noRd
.align_raster_longitude_points <- function(xy, raster) {
  if (.raster_uses_positive_longitude(raster) && nrow(xy)) {
    xy[xy[, 1L] < 0, 1L] <- xy[xy[, 1L] < 0, 1L] + 360
  }
  xy
}

#' Combine cell IDs and extracted raster values
#' @noRd
.raster_hex_data <- function(cell, values) {
  values <- tibble::as_tibble(values)
  repaired <- vctrs::vec_as_names(
    c("cell", names(values)),
    repair = "unique",
    quiet = TRUE
  )
  names(values) <- repaired[-1L]
  .new_hex_data(tibble::as_tibble(c(list(cell = cell), as.list(values))))
}

#' Return a dateline-safe WGS84 polygon for the raster extent
#' @noRd
.raster_footprint <- function(raster) {
  raster_crs <- .raster_crs(raster)
  xmin <- terra::xmin(raster)
  xmax <- terra::xmax(raster)
  ymin <- terra::ymin(raster)
  ymax <- terra::ymax(raster)

  if (terra::is.lonlat(raster)) {
    width <- xmax - xmin
    if (width >= 359.999999) {
      intervals <- list(c(-180, 180))
    } else {
      start <- ((xmin + 180) %% 360) - 180
      finish <- start + width
      intervals <- if (finish <= 180) {
        list(c(start, finish))
      } else {
        list(c(start, 180), c(-180, finish - 360))
      }
    }
    latitude <- c(max(-90, ymin), min(90, ymax))
    pieces <- unlist(lapply(intervals, function(interval) {
      lon_breaks <- .bounded_breaks(interval[[1L]], interval[[2L]])
      lat_breaks <- .bounded_breaks(latitude[[1L]], latitude[[2L]])
      unlist(lapply(seq_len(length(lon_breaks) - 1L), function(i) {
        lapply(seq_len(length(lat_breaks) - 1L), function(j) {
          sf::st_as_sfc(sf::st_bbox(c(
            xmin = lon_breaks[[i]],
            ymin = lat_breaks[[j]],
            xmax = lon_breaks[[i + 1L]],
            ymax = lat_breaks[[j + 1L]]
          ), crs = raster_crs))
        })
      }), recursive = FALSE)
    }), recursive = FALSE)
    footprint <- do.call(c, pieces)
  } else {
    footprint <- sf::st_as_sfc(sf::st_bbox(c(
      xmin = xmin,
      ymin = ymin,
      xmax = xmax,
      ymax = ymax
    ), crs = raster_crs))
    segment <- max(xmax - xmin, ymax - ymin) / 32
    if (is.finite(segment) && segment > 0) {
      footprint <- sf::st_segmentize(footprint, dfMaxLength = segment)
    }
  }

  footprint <- sf::st_transform(footprint, 4326)
  suppressWarnings(sf::st_wrap_dateline(
    footprint,
    options = c("WRAPDATELINE=YES", "DATELINEOFFSET=180"),
    quiet = TRUE
  ))
}

#' Split a geographic interval into bounded clipping pieces
#' @noRd
.bounded_breaks <- function(lower, upper, size = 60) {
  first <- ceiling(lower / size) * size
  last <- floor(upper / size) * size
  # Intervals narrower than one chunk contain no internal break.
  internal <- if (first <= last) seq(first, last, by = size) else numeric()
  sort(unique(c(lower, internal[internal > lower & internal < upper], upper)))
}

#' Match raster-footprint densification to approximate DGGS cell size
#' @noRd
.raster_cover_densify <- function(resolution, grid) {
  max(0.01, min(1, .cell_padding(resolution, grid) / 4))
}

#' Detect rasters for which whole-grid generation is simpler than clipping
#' @noRd
.raster_spans_all_longitudes <- function(raster) {
  terra::is.lonlat(raster) && terra::xmax(raster) - terra::xmin(raster) >= 359.999999
}

#' Number of cells in a pure-aperture hexagonal DGGS
#' @noRd
.grid_cell_count <- function(resolution, grid) {
  aperture <- if (identical(grid$index_system, "z7")) 7 else 3
  2 + 10 * aperture^resolution
}

#' Enumerate one complete DGGS resolution
#' @noRd
.all_grid_cells <- function(resolution, grid) {
  dir <- .job_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE), add = TRUE)
  meta <- c(
    "dggrid_operation GENERATE_GRID",
    .meta_grid(grid, resolution),
    "output_cell_label_type OUTPUT_ADDRESS_TYPE",
    .meta_hier_output(grid),
    "point_output_type TEXT",
    "point_output_file_name centers",
    "precision 15"
  )
  .run_job(dir, meta, timeout = 300000)
  centers <- utils::read.csv(
    file.path(dir, "centers.txt"),
    header = FALSE,
    col.names = c("id", "lon", "lat"),
    colClasses = c("character", "numeric", "numeric"),
    quote = "",
    comment.char = ""
  )
  as_globalhex_cell(centers$id, grid)
}
