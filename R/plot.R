#' Choose a display resolution for global-hex data
#'
#' The selector combines a hard cell cap with a screen-pixel budget, then walks
#' the actual cell hierarchy inside the requested geographic extent. Only cell
#' centers are used during selection; polygon boundaries are not generated.
#'
#' @param x A [hex_data()] object.
#' @param extent Geographic extent as `c(xmin, xmax, ymin, ymax)` in longitude
#'   and latitude. `xmin > xmax` denotes an antimeridian-crossing extent.
#'   `NULL` infers an extent from a bounded set of hierarchical cells.
#' @param device_size Display width and height in pixels. `NULL` inspects the
#'   current graphics device and falls back to 800 by 600 pixels.
#' @param max_cells Hard maximum number of display cells.
#' @param cell_pixels Approximate minimum cell diameter in screen pixels.
#' @param lod Whether to select a coarser level automatically.
#' @param resolution Optional explicit display resolution.
#' @return A single display resolution.
#' @export
plot_resolution <- function(
    x,
    extent = NULL,
    device_size = NULL,
    max_cells = 100000L,
    cell_pixels = 3,
    lod = TRUE,
    resolution = NULL) {
  .plot_plan(
    x,
    extent = extent,
    device_size = device_size,
    max_cells = max_cells,
    cell_pixels = cell_pixels,
    lod = lod,
    resolution = resolution
  )$resolution
}

#' Plot global-hex values with hierarchical level of detail
#'
#' Source polygons are never constructed. The method selects a legitimate Z7
#' or Z3 ancestor level and aggregates source values before making any display
#' geometry. `render = "auto"` draws smaller results as vector polygons and
#' rasterizes larger results for a compact, device-friendly display.
#'
#' @param x A [hex_data()] object.
#' @param y Unused; present for the base [plot()] generic.
#' @param value Attribute column to plot. `NULL` uses the first attribute.
#' @param resolution Explicit display resolution. `NULL` selects one
#'   automatically.
#' @param max_cells Hard maximum number of display cells.
#' @param fun Aggregation function. `NULL` uses type-aware defaults; use
#'   `sum` explicitly for counts.
#' @param na.rm Whether aggregation removes missing values.
#' @param lod Whether to use automatic hierarchical level of detail.
#' @param extent Geographic display extent as `c(xmin, xmax, ymin, ymax)`.
#' @param xlim,ylim Optional conventional longitude and latitude limits. They
#'   override the corresponding part of `extent` and participate in LOD
#'   selection before projection.
#' @param device_size Optional display width and height in pixels.
#' @param cell_pixels Approximate minimum cell diameter in screen pixels.
#' @param crs Display CRS understood by [sf::st_crs()]. Aggregation always
#'   happens before projection.
#' @param border Polygon border passed to [plot()].
#'   Raster rendering cannot draw individual cell borders.
#' @param pal Optional color palette function or vector.
#' @param render Rendering backend. `"auto"` rasterizes sufficiently large
#'   displays when `terra` is available, `"polygon"` always draws vector
#'   polygons, and `"raster"` always rasterizes the displayed polygons.
#' @param raster_threshold Number of displayed cells at which automatic
#'   rendering switches to a raster. An explicit non-missing `border` keeps
#'   automatic rendering in polygon mode.
#' @param ... Additional arguments passed to the selected `sf` or `terra` plot
#'   method.
#' @return The aggregated `globalhex_data` used for display, invisibly, with
#'   `plot_resolution`, `plot_extent`, and `plot_render` attributes. Polygon
#'   rendering also attaches the displayed `geometry`; raster rendering
#'   attaches `plot_raster_size` instead.
#' @examples
#' if (requireNamespace("sf", quietly = TRUE)) {
#'   cells <- point_to_cell(rbind(c(0, 0), c(10, 10)), 5)
#'   plot(hex_data(cells, value = c(1, 2)), max_cells = 1000)
#' }
#' @export
plot.globalhex_data <- function(
    x,
    y = NULL,
    value = NULL,
    resolution = NULL,
    max_cells = 100000L,
    fun = NULL,
    na.rm = TRUE,
    lod = TRUE,
    extent = NULL,
    xlim = NULL,
    ylim = NULL,
    device_size = NULL,
    cell_pixels = 3,
    crs = 4326,
    border = NA,
    pal = NULL,
    render = c("auto", "polygon", "raster"),
    raster_threshold = 20000L,
    ...) {
  .check_hex_data(x)
  rlang::check_installed("sf", reason = "to render globalhex polygon displays")
  render <- rlang::arg_match(render)
  raster_threshold <- .scalar_int(raster_threshold, "raster_threshold")
  if (raster_threshold < 1L) {
    .abort(
      "{.arg raster_threshold} must be positive.",
      "globalhex_error_argument"
    )
  }
  column <- .value_columns(x, value)[[1L]]
  keep <- !is.na(x[[column]])
  if (!any(keep)) {
    .abort(
      "{.arg value} contains no non-missing data to plot.",
      "globalhex_error_argument"
    )
  }
  if (isTRUE(na.rm)) {
    x <- .new_hex_data(x[keep, , drop = FALSE])
  }
  extent <- .resolve_plot_extent(x$cell, extent, xlim, ylim)
  prepared <- .prepare_plot_values(
    x,
    value = column,
    resolution = resolution,
    max_cells = max_cells,
    fun = fun,
    na.rm = na.rm,
    lod = lod,
    extent = extent,
    device_size = device_size,
    cell_pixels = cell_pixels
  )
  method <- .plot_render_method(
    render,
    cells = nrow(prepared$data),
    raster_threshold = raster_threshold,
    border = border
  )
  prepared <- .add_plot_geometry(prepared, crs = crs)
  if (identical(method, "raster")) {
    size <- .plot_raster(
      prepared,
      value = column,
      device_size = device_size,
      pal = pal,
      border = border,
      dots = rlang::list2(...)
    )
  } else {
    args <- c(
      list(x = prepared$sf[column], border = border),
      if (!is.null(pal)) list(pal = pal),
      .display_limits(prepared$extent, crs),
      list(...)
    )
    do.call(graphics::plot, args)
  }

  out <- prepared$data
  attr(out, "plot_resolution") <- prepared$resolution
  attr(out, "plot_extent") <- prepared$extent
  attr(out, "plot_render") <- method
  if (identical(method, "polygon")) {
    attr(out, "geometry") <- sf::st_geometry(prepared$sf)
  } else {
    attr(out, "plot_raster_size") <- size
  }
  invisible(out)
}

#' Prepare reduced data and final display geometry
#' @noRd
.prepare_plot_data <- function(
    x,
    value,
    resolution,
    max_cells,
    fun,
    na.rm,
    lod,
    extent,
    device_size,
    cell_pixels,
    crs) {
  prepared <- .prepare_plot_values(
    x,
    value = value,
    resolution = resolution,
    max_cells = max_cells,
    fun = fun,
    na.rm = na.rm,
    lod = lod,
    extent = extent,
    device_size = device_size,
    cell_pixels = cell_pixels
  )
  .add_plot_geometry(prepared, crs = crs)
}

#' Prepare viewport-selected, aggregated values without polygon geometry
#' @noRd
.prepare_plot_values <- function(
    x,
    value,
    resolution,
    max_cells,
    fun,
    na.rm,
    lod,
    extent,
    device_size,
    cell_pixels) {
  if (length(na.rm) != 1L || is.na(na.rm) || !is.logical(na.rm)) {
    .abort("{.arg na.rm} must be {.code TRUE} or {.code FALSE}.", "globalhex_error_argument")
  }
  plan <- .plot_plan(
    x,
    extent = extent,
    device_size = device_size,
    max_cells = max_cells,
    cell_pixels = cell_pixels,
    lod = lod,
    resolution = resolution
  )
  grid <- .cell_grid(x$cell)
  ancestor <- .cell_ancestor(x$cell, plan$resolution, grid = grid)
  keep <- .cell_strings(ancestor) %in% .cell_strings(plan$cells)
  if (!any(keep)) {
    .abort("No source cells are visible inside {.arg extent}.", "globalhex_error_argument")
  }
  if (!is.null(fun)) fun <- match.fun(fun)
  aggregated <- .aggregate_with_ancestor(
    x,
    ancestor,
    columns = value,
    fun = fun,
    na.rm = na.rm,
    keep = keep
  )
  order <- match(.cell_strings(plan$cells), .cell_strings(aggregated$cell), nomatch = 0L)
  order <- order[order > 0L]
  aggregated <- .new_hex_data(aggregated[order, , drop = FALSE])
  list(
    data = aggregated,
    resolution = plan$resolution,
    extent = plan$extent
  )
}

#' Add geometry only after display cells have been selected
#' @noRd
.add_plot_geometry <- function(prepared, crs) {
  boundaries <- cell_boundary(prepared$data$cell)$boundary
  geometry <- .display_geometry(boundaries, extent = prepared$extent, crs = crs)
  prepared$sf <- sf::st_sf(tibble::as_tibble(prepared$data), geometry = geometry)
  prepared
}

#' Select the final renderer after LOD aggregation
#' @noRd
.plot_render_method <- function(render, cells, raster_threshold, border) {
  if (!identical(render, "auto")) {
    if (identical(render, "raster")) {
      rlang::check_installed("terra", reason = "to rasterize globalhex displays")
    }
    return(render)
  }
  if (.plot_border_requested(border) || cells < raster_threshold ||
      !rlang::is_installed("terra")) {
    return("polygon")
  }
  "raster"
}

#' @noRd
.plot_border_requested <- function(border) {
  !(is.null(border) || !length(border) || all(is.na(border)))
}

#' Rasterize and draw the already-reduced display layer
#' @noRd
.plot_raster <- function(prepared, value, device_size, pal, border, dots) {
  rlang::check_installed("terra", reason = "to rasterize globalhex displays")
  if (.plot_border_requested(border)) {
    cli::cli_warn(
      c(
        "Cell borders are not available with {.code render = \"raster\"}.",
        "i" = "Use {.code render = \"polygon\"} to draw individual borders."
      ),
      class = c("globalhex_warning_render", "globalhex_warning"),
      .envir = rlang::caller_env()
    )
  }

  size <- as.integer(round(.plot_device_size(device_size)))
  bounds <- .plot_raster_bounds(prepared$sf, prepared$extent)
  target <- terra::rast(
    ncols = size[[1L]],
    nrows = size[[2L]],
    xmin = bounds[["xmin"]],
    xmax = bounds[["xmax"]],
    ymin = bounds[["ymin"]],
    ymax = bounds[["ymax"]],
    crs = sf::st_crs(prepared$sf)$wkt
  )

  field <- ".globalhex_render_value"
  layer <- prepared$sf
  values <- layer[[value]]
  discrete <- is.factor(values) || is.character(values) || is.logical(values)
  labels <- NULL
  if (discrete) {
    labels <- .plot_discrete_labels(values)
    layer[[field]] <- match(as.character(values), labels)
  } else {
    layer[[field]] <- as.numeric(values)
  }
  vector <- terra::vect(layer[field])
  raster <- terra::rasterize(
    vector,
    target,
    field = field,
    background = NA_real_,
    touches = FALSE
  )
  names(raster) <- value
  if (discrete) {
    levels(raster) <- data.frame(
      ID = seq_along(labels),
      label = labels,
      stringsAsFactors = FALSE
    )
  }

  if (is.null(dots$axes)) dots$axes <- FALSE
  if (is.null(dots$box)) dots$box <- FALSE
  if (is.null(dots$maxcell)) dots$maxcell <- prod(size)
  if (is.null(dots$plg)) dots$plg <- list(x = "bottom", horiz = TRUE)
  if (!is.null(pal)) {
    dots$col <- .plot_raster_palette(
      pal,
      if (discrete) length(labels) else 100L
    )
  }
  args <- c(list(x = raster), dots)
  do.call(terra::plot, args)
  stats::setNames(size, c("width", "height"))
}

#' @noRd
.plot_discrete_labels <- function(x) {
  if (is.factor(x)) {
    present <- levels(x)[levels(x) %in% as.character(x[!is.na(x)])]
    return(present)
  }
  if (is.logical(x)) {
    return(c("FALSE", "TRUE")[c(FALSE, TRUE) %in% x[!is.na(x)]])
  }
  unique(as.character(x[!is.na(x)]))
}

#' @noRd
.plot_raster_palette <- function(pal, n) {
  if (is.function(pal)) pal(max(1L, n)) else pal
}

#' Use explicit geographic limits where possible and final geometry otherwise
#' @noRd
.plot_raster_bounds <- function(x, extent) {
  target <- sf::st_crs(x)
  limits <- .display_limits(extent, target)
  bounds <- if (length(limits)) {
    c(
      xmin = limits$xlim[[1L]],
      xmax = limits$xlim[[2L]],
      ymin = limits$ylim[[1L]],
      ymax = limits$ylim[[2L]]
    )
  } else {
    box <- sf::st_bbox(x)
    unname_box <- unname(box[c("xmin", "xmax", "ymin", "ymax")])
    stats::setNames(unname_box, c("xmin", "xmax", "ymin", "ymax"))
  }
  if (anyNA(bounds) || any(!is.finite(bounds)) ||
      bounds[["xmin"]] >= bounds[["xmax"]] ||
      bounds[["ymin"]] >= bounds[["ymax"]]) {
    .abort(
      "The display extent cannot be rasterized in the requested CRS.",
      "globalhex_error_crs"
    )
  }
  bounds
}

#' Build a viewport-aware LOD plan without constructing polygons
#' @noRd
.plot_plan <- function(
    x,
    extent,
    device_size,
    max_cells,
    cell_pixels,
    lod,
    resolution) {
  .check_hex_data(x)
  grid <- .cell_grid(x$cell)
  if (.is_legacy_grid(grid)) {
    .abort("LOD plotting requires hierarchical Z7 or Z3 cells.", "globalhex_error_unsupported")
  }
  if (!length(x$cell)) {
    .abort("Cannot plot an empty {.cls globalhex_data} object.", "globalhex_error_argument")
  }
  .check_cells_complete(x$cell)
  max_cells <- .scalar_int(max_cells, "max_cells")
  if (max_cells < 1L) .abort("{.arg max_cells} must be positive.", "globalhex_error_argument")
  if (length(cell_pixels) != 1L || is.na(cell_pixels) || !is.finite(cell_pixels) || cell_pixels <= 0) {
    .abort("{.arg cell_pixels} must be one positive number.", "globalhex_error_argument")
  }
  lod <- .optional_flag(lod, "lod")
  if (is.null(lod)) lod <- TRUE
  source_resolution <- min(cell_resolution(x$cell))
  size <- .plot_device_size(device_size)
  budget <- max(1L, min(max_cells, floor(prod(size) / cell_pixels^2)))
  if (is.null(extent)) extent <- .infer_data_extent(x$cell, source_resolution)
  extent <- .validate_extent(extent)

  if (!is.null(resolution)) {
    resolution <- .scalar_int(resolution, "resolution")
    if (resolution < 0L || resolution > source_resolution) {
      .abort(
        "{.arg resolution} must be between 0 and the coarsest source resolution ({source_resolution}).",
        "globalhex_error_resolution",
        source_resolution = source_resolution
      )
    }
    return(.plan_at_resolution(x$cell, resolution, extent))
  }
  if (!lod) {
    if (length(unique(cell_resolution(x$cell))) != 1L) {
      .abort(
        "{.code lod = FALSE} currently requires a uniform source resolution.",
        "globalhex_error_resolution"
      )
    }
    return(.plan_at_resolution(x$cell, source_resolution, extent))
  }

  source_ids <- .cell_strings(x$cell)
  eligible <- seq_along(source_ids)
  chosen <- NULL
  for (candidate_resolution in 0:source_resolution) {
    ids <- substring(source_ids[eligible], 1L, candidate_resolution + 2L)
    candidate_ids <- unique(ids)
    if (length(candidate_ids) > budget) {
      if (!is.null(chosen)) break
      .abort(
        "The display budget ({budget}) is smaller than the {length(candidate_ids)} visible resolution-0 cells.",
        "globalhex_error_size",
        budget = budget
      )
    }
    candidate <- as_globalhex_cell(candidate_ids, grid)
    centers <- cell_center(candidate)
    padding <- .cell_padding(candidate_resolution, grid)
    visible <- .centers_visible(centers$lon, centers$lat, extent, padding)
    candidate <- candidate[visible]
    if (!length(candidate)) break
    if (length(candidate) > budget && !is.null(chosen)) break

    chosen <- list(
      resolution = as.integer(candidate_resolution),
      cells = candidate,
      extent = extent,
      budget = budget
    )
    prefix <- substring(source_ids, 1L, candidate_resolution + 2L)
    eligible <- which(prefix %in% .cell_strings(candidate))
    if (!length(eligible) || candidate_resolution == source_resolution) break
  }
  chosen %||% .plan_at_resolution(x$cell, 0L, extent)
}

#' @noRd
.plan_at_resolution <- function(cell, resolution, extent) {
  grid <- .cell_grid(cell)
  candidate <- unique(.cell_ancestor(cell, resolution, grid = grid))
  centers <- cell_center(candidate)
  visible <- .centers_visible(
    centers$lon,
    centers$lat,
    extent,
    .cell_padding(resolution, grid)
  )
  if (!any(visible)) {
    .abort("No source cells are visible inside {.arg extent}.", "globalhex_error_argument")
  }
  list(
    resolution = as.integer(resolution),
    cells = candidate[visible],
    extent = extent,
    budget = length(candidate)
  )
}

#' @noRd
.plot_device_size <- function(device_size) {
  if (is.null(device_size)) {
    device_size <- if (grDevices::dev.cur() == 1L) {
      c(800, 600)
    } else {
      tryCatch(grDevices::dev.size("px"), error = function(e) c(NA, NA))
    }
    if (length(device_size) != 2L || anyNA(device_size) || any(!is.finite(device_size)) ||
        any(device_size <= 1)) {
      device_size <- c(800, 600)
    }
  }
  if (!is.numeric(device_size) || length(device_size) != 2L || anyNA(device_size) ||
      any(!is.finite(device_size)) || any(device_size <= 0)) {
    .abort(
      "{.arg device_size} must contain positive pixel width and height.",
      "globalhex_error_argument"
    )
  }
  as.numeric(device_size)
}

#' Merge standard plot limits into the geographic LOD extent
#' @noRd
.resolve_plot_extent <- function(cell, extent, xlim, ylim) {
  if (is.null(xlim) && is.null(ylim)) return(extent)
  if (!is.null(xlim) && (!is.numeric(xlim) || length(xlim) != 2L || anyNA(xlim))) {
    .abort("{.arg xlim} must contain two longitudes.", "globalhex_error_argument")
  }
  if (!is.null(ylim) && (!is.numeric(ylim) || length(ylim) != 2L || anyNA(ylim))) {
    .abort("{.arg ylim} must contain two latitudes.", "globalhex_error_argument")
  }
  if (is.null(extent)) {
    extent <- .infer_data_extent(cell, min(cell_resolution(cell)))
  }
  if (!is.null(xlim)) extent[1:2] <- xlim
  if (!is.null(ylim)) extent[3:4] <- ylim
  .validate_extent(extent)
}

#' Infer a tight-enough extent without constructing source polygons
#' @noRd
.infer_data_extent <- function(cell, source_resolution, max_probe = 2000L) {
  grid <- .cell_grid(cell)
  ids <- .cell_strings(cell)
  selected <- as_globalhex_cell(unique(substring(ids, 1L, 2L)), grid)
  selected_resolution <- 0L
  for (resolution in seq_len(source_resolution)) {
    candidate <- unique(substring(ids, 1L, resolution + 2L))
    if (length(candidate) > max_probe) break
    selected <- as_globalhex_cell(candidate, grid)
    selected_resolution <- resolution
  }
  centers <- cell_center(selected)
  padding <- .cell_padding(selected_resolution, grid)
  lon <- .minimal_longitude_extent(centers$lon)
  lat <- range(centers$lat)
  span <- if (lon[[1L]] <= lon[[2L]]) {
    lon[[2L]] - lon[[1L]]
  } else {
    lon[[2L]] + 360 - lon[[1L]]
  }
  if (span + 2 * padding >= 359.999) lon <- c(-180, 180)
  c(
    xmin = if (identical(lon, c(-180, 180))) -180 else .wrap_longitude(lon[[1L]] - padding),
    xmax = if (identical(lon, c(-180, 180))) 180 else .wrap_longitude(lon[[2L]] + padding),
    ymin = max(-90, lat[[1L]] - padding),
    ymax = min(90, lat[[2L]] + padding)
  )
}

#' @noRd
.validate_extent <- function(extent) {
  if (!is.numeric(extent) || length(extent) != 4L || anyNA(extent) ||
      any(!is.finite(extent))) {
    .abort(
      "{.arg extent} must be {.code c(xmin, xmax, ymin, ymax)}.",
      "globalhex_error_argument"
    )
  }
  extent <- as.numeric(extent)
  if (any(extent[1:2] < -180 | extent[1:2] > 180) ||
      extent[[3L]] < -90 || extent[[4L]] > 90 || extent[[3L]] > extent[[4L]]) {
    .abort("{.arg extent} contains invalid longitude or latitude limits.", "globalhex_error_argument")
  }
  stats::setNames(extent, c("xmin", "xmax", "ymin", "ymax"))
}

#' Approximate angular radius used only to avoid viewport-edge gaps
#' @noRd
.cell_padding <- function(resolution, grid) {
  aperture <- if (identical(grid$index_system, "z7")) 7 else 3
  n_cells <- 2 + 10 * aperture^resolution
  min(180, 1.5 * sqrt(41253 / n_cells))
}

#' @noRd
.centers_visible <- function(lon, lat, extent, padding = 0) {
  lat_ok <- lat >= max(-90, extent[["ymin"]] - padding) &
    lat <= min(90, extent[["ymax"]] + padding)
  lon_padding <- min(180, padding / max(cos(mean(extent[3:4]) * pi / 180), 0.1))
  xmin <- .wrap_longitude(extent[["xmin"]] - lon_padding)
  xmax <- .wrap_longitude(extent[["xmax"]] + lon_padding)
  lon_ok <- if (lon_padding >= 180 || abs(diff(extent[1:2])) >= 359.999) {
    rep(TRUE, length(lon))
  } else if (xmin <= xmax) {
    lon >= xmin & lon <= xmax
  } else {
    lon >= xmin | lon <= xmax
  }
  lat_ok & lon_ok
}

#' @noRd
.wrap_longitude <- function(x) ((x + 180) %% 360) - 180

#' Find the shortest circular longitude interval containing points
#' @noRd
.minimal_longitude_extent <- function(lon) {
  if (!length(lon)) return(c(-180, 180))
  shifted <- sort(unique((lon + 360) %% 360))
  if (length(shifted) == 1L) {
    value <- .wrap_longitude(shifted)
    return(c(value, value))
  }
  gaps <- diff(c(shifted, shifted[[1L]] + 360))
  gap <- which.max(gaps)
  start <- shifted[(gap %% length(shifted)) + 1L]
  end <- shifted[[gap]]
  c(.wrap_longitude(start), .wrap_longitude(end))
}

#' Construct final polygons, then project for display
#' @noRd
.display_geometry <- function(boundaries, extent, crs) {
  wrap <- extent[["xmin"]] > extent[["xmax"]]
  polygons <- lapply(boundaries, function(ring) {
    ring <- unname(ring)
    if (wrap) ring[ring[, 1L] < 0, 1L] <- ring[ring[, 1L] < 0, 1L] + 360
    sf::st_polygon(list(ring))
  })
  geometry <- sf::st_sfc(polygons, crs = 4326)
  if (!wrap) {
    geometry <- suppressWarnings(sf::st_wrap_dateline(
      geometry,
      options = c("WRAPDATELINE=YES", "DATELINEOFFSET=180"),
      quiet = TRUE
    ))
  }
  target <- sf::st_crs(crs)
  if (!is.na(target) && !identical(target$epsg, 4326L)) {
    geometry <- sf::st_transform(geometry, target)
  }
  geometry
}

#' Convert a geographic viewport to final plot limits
#' @noRd
.display_limits <- function(extent, crs) {
  target <- sf::st_crs(crs)
  wrap <- extent[["xmin"]] > extent[["xmax"]]
  if (is.na(target) || identical(target$epsg, 4326L)) {
    return(list(
      xlim = if (wrap) c(extent[["xmin"]], extent[["xmax"]] + 360) else extent[1:2],
      ylim = extent[3:4]
    ))
  }
  if (wrap || abs(diff(extent[1:2])) >= 359.999) return(list())

  lon <- seq(extent[["xmin"]], extent[["xmax"]], length.out = 25L)
  lat <- seq(extent[["ymin"]], extent[["ymax"]], length.out = 25L)
  ring <- rbind(
    cbind(lon, extent[["ymin"]]),
    cbind(extent[["xmax"]], lat[-1L]),
    cbind(rev(lon[-length(lon)]), extent[["ymax"]]),
    cbind(extent[["xmin"]], rev(lat[-c(1L, length(lat))])),
    c(extent[["xmin"]], extent[["ymin"]])
  )
  box <- sf::st_sfc(sf::st_polygon(list(ring)), crs = 4326)
  bounds <- sf::st_bbox(sf::st_transform(box, target))
  list(xlim = unname(bounds[c("xmin", "xmax")]), ylim = unname(bounds[c("ymin", "ymax")]))
}
