#' Define a global hexagonal grid
#'
#' `hex_grid()` describes spatial identity only: the DGGS family, hierarchy,
#' and orientation. Resolution belongs to cells and is supplied to
#' [point_to_cell()] or [cell_cover()]. Backend discovery is deliberately
#' separate from the grid definition.
#'
#' @param system Either `"igeo7"` (the equal-area Z7 default) or `"isea3h"`
#'   (equal-area Z3).
#' @param pole_lon,pole_lat,azimuth Orientation in degrees. IGEO7 has a
#'   canonical orientation; custom values are supported for ISEA3H.
#' @return A `globalhex_grid` object.
#' @examples
#' hex_grid()
#' hex_grid("isea3h")
#' @export
hex_grid <- function(
    system = c("igeo7", "isea3h"),
    pole_lon = 11.25,
    pole_lat = 58.28252559,
    azimuth = 0) {
  system <- tolower(system)
  system <- rlang::arg_match(system, c("igeo7", "isea3h"))
  orientation <- c(
    pole_lon = as.numeric(pole_lon),
    pole_lat = as.numeric(pole_lat),
    azimuth = as.numeric(azimuth)
  )
  if (anyNA(orientation) || any(!is.finite(orientation)) ||
      orientation[["pole_lon"]] < -180 || orientation[["pole_lon"]] > 180 ||
      orientation[["pole_lat"]] < -90 || orientation[["pole_lat"]] > 90 ||
      orientation[["azimuth"]] < 0 || orientation[["azimuth"]] > 360) {
    .abort(
      "Grid orientation contains an invalid longitude, latitude, or azimuth.",
      "globalhex_error_grid"
    )
  }
  canonical <- c(pole_lon = 11.25, pole_lat = 58.28252559, azimuth = 0)
  if (identical(system, "igeo7") && !isTRUE(all.equal(orientation, canonical))) {
    .abort(
      "IGEO7 uses its canonical orientation; custom orientation is available for ISEA3H.",
      "globalhex_error_grid"
    )
  }

  structure(
    list(
      system = system,
      index_system = if (identical(system, "igeo7")) "z7" else "z3",
      address_type = "hierarchical",
      pole_lon = orientation[["pole_lon"]],
      pole_lat = orientation[["pole_lat"]],
      azimuth = orientation[["azimuth"]]
    ),
    class = "globalhex_grid"
  )
}

#' Define the explicit legacy dggridR fallback
#'
#' This opt-in constructor quarantines the older sequence-number behavior.
#' Legacy cells support point, center, boundary, and sf conversion, but not the
#' modern hierarchy or neighbor operations.
#'
#' @param resolution ISEA3H resolution.
#' @param pole_lon,pole_lat,azimuth Orientation in degrees.
#' @return A `globalhex_legacy_grid` object.
#' @export
legacy_grid <- function(
    resolution,
    pole_lon = 11.25,
    pole_lat = 58.28252559,
    azimuth = 0) {
  rlang::check_installed(
    "dggridR",
    reason = "to construct an explicit legacy grid",
    call = rlang::caller_env()
  )
  resolution <- .validate_resolution(resolution, "isea3h")
  grid <- hex_grid(
    "isea3h",
    pole_lon = pole_lon,
    pole_lat = pole_lat,
    azimuth = azimuth
  )
  grid$index_system <- "seqnum"
  grid$address_type <- "seqnum"
  grid$resolution <- resolution
  class(grid) <- c("globalhex_legacy_grid", "globalhex_grid")
  grid
}

#' @noRd
.check_grid <- function(x, arg = "grid", call = rlang::caller_env()) {
  if (!inherits(x, "globalhex_grid")) {
    .abort(
      "{.arg {arg}} must be created by {.fn hex_grid} or {.fn legacy_grid}.",
      "globalhex_error_argument",
      arg = arg,
      call = call
    )
  }
  invisible(x)
}

#' @noRd
.is_legacy_grid <- function(x) inherits(x, "globalhex_legacy_grid")

#' @noRd
.grid_signature <- function(x) {
  .check_grid(x)
  fields <- c("system", "index_system", "address_type", "pole_lon", "pole_lat", "azimuth")
  if (.is_legacy_grid(x)) fields <- c(fields, "resolution")
  unname(unlist(x[fields], use.names = FALSE))
}

#' @noRd
.same_grid <- function(x, y) identical(.grid_signature(x), .grid_signature(y))

#' @noRd
.max_resolution <- function(grid) {
  if (identical(grid$index_system, "z7")) 20L else 30L
}

#' @noRd
.validate_resolution <- function(resolution, system, call = rlang::caller_env()) {
  resolution <- .scalar_int(resolution, "resolution", call = call)
  max_resolution <- if (identical(tolower(system), "igeo7")) 20L else 30L
  if (resolution < 0L || resolution > max_resolution) {
    .abort(
      "Resolution for {.val {toupper(system)}} must be between 0 and {max_resolution}.",
      "globalhex_error_resolution",
      resolution = resolution,
      system = system,
      call = call
    )
  }
  resolution
}

#' @export
print.globalhex_grid <- function(x, ...) {
  cli::cli_text("<globalhex_grid>")
  cli::cli_text("  system:      {toupper(x$system)}")
  cli::cli_text("  index:       {toupper(x$index_system)}")
  cli::cli_text("  orientation: {x$pole_lon}, {x$pole_lat}, {x$azimuth}")
  if (.is_legacy_grid(x)) {
    cli::cli_text("  legacy res:  {x$resolution}")
  }
  invisible(x)
}

#' Locate the modern DGGRID executable
#' @noRd
.find_dggrid <- function(path = NULL, error = TRUE, call = rlang::caller_env()) {
  candidates <- c(
    path,
    getOption("globalhex.dggrid", ""),
    Sys.getenv("DGGRID_BIN", unset = ""),
    Sys.getenv("DGGRID", unset = ""),
    unname(Sys.which("dggrid")),
    system.file("bin", paste0("dggrid", .Platform$exeext), package = "globalhex"),
    # Under devtools::load_all() the executable is compiled but not installed,
    # and system.file() points at the source tree's inst/ directory.
    file.path(
      dirname(system.file(package = "globalhex")),
      "src", "dggrid", paste0("dggrid", .Platform$exeext)
    )
  )
  candidates <- unique(candidates[nzchar(candidates)])
  found <- candidates[file.exists(candidates)]
  if (length(found)) return(normalizePath(found[[1L]], mustWork = TRUE))
  if (isTRUE(error)) {
    .abort(
      c(
        "Modern DGGRID was not found.",
        "i" = "Reinstall globalhex to rebuild the bundled DGGRID, or set {.envvar DGGRID_BIN} or the {.code globalhex.dggrid} option."
      ),
      "globalhex_error_backend",
      call = call
    )
  }
  ""
}

#' Report the local globalhex environment
#'
#' globalhex runs a DGGRID executable compiled when the package is installed.
#' To use a different DGGRID build (version 9.0 or later), set
#' `options(globalhex.dggrid = "/path/to/dggrid")` or the `DGGRID_BIN` (or
#' `DGGRID`) environment variable. These take precedence over a `dggrid` on
#' the `PATH`, which in turn takes precedence over the bundled copy.
#'
#' @return A named list describing R, optional packages, and the DGGRID
#'   executable in use.
#' @export
globalhex_info <- function() {
  path <- .find_dggrid(error = FALSE)
  version <- NULL
  if (nzchar(path)) {
    probe <- tryCatch(
      system2(path, "-v", stdout = TRUE, stderr = TRUE),
      error = function(e) conditionMessage(e)
    )
    version <- trimws(paste(probe, collapse = " "))
  }
  list(
    R = R.version.string,
    dggridR = if (rlang::is_installed("dggridR")) {
      as.character(utils::packageVersion("dggridR"))
    } else NULL,
    sf = if (rlang::is_installed("sf")) {
      as.character(utils::packageVersion("sf"))
    } else NULL,
    terra = if (rlang::is_installed("terra")) {
      as.character(utils::packageVersion("terra"))
    } else NULL,
    exactextractr = if (rlang::is_installed("exactextractr")) {
      as.character(utils::packageVersion("exactextractr"))
    } else NULL,
    dggrid_path = if (nzchar(path)) path else NULL,
    dggrid_version = version
  )
}
