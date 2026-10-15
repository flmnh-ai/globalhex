#' Convert to a low-level dggridR grid
#'
#' @param grid An ISEA3H [hex_grid()] or a [legacy_grid()].
#' @param resolution Resolution for a modern grid; ignored for a legacy grid.
#' @return A dggridR grid list.
#' @export
as_dggridR_dggs <- function(grid, resolution = NULL) {
  .check_grid(grid)
  if (!identical(grid$system, "isea3h")) {
    .abort(
      "{.pkg dggridR} 3.x cannot represent IGEO7/Z7; use an ISEA3H grid.",
      "globalhex_error_grid"
    )
  }
  rlang::check_installed(
    "dggridR",
    reason = "to convert ISEA3H grids to dggridR grid objects",
    call = rlang::caller_env()
  )
  if (.is_legacy_grid(grid)) {
    resolution <- grid$resolution
  } else if (is.null(resolution)) {
    .abort("{.arg resolution} is required for a modern grid.", "globalhex_error_resolution")
  }
  resolution <- .validate_resolution(resolution, "isea3h")
  dggridR::dgconstruct(
    projection = "ISEA",
    aperture = 3,
    topology = "HEXAGON",
    res = resolution,
    show_info = FALSE,
    pole_lon_deg = grid$pole_lon,
    pole_lat_deg = grid$pole_lat,
    azimuth_deg = grid$azimuth
  )
}

#' Convert hierarchical cells to sequence numbers
#'
#' Values are returned as character strings to avoid losing integer precision.
#'
#' @param cell A `globalhex_cell` vector.
#' @return A character vector with one sequence number per cell.
#' @export
as_seqnum <- function(cell) {
  grid <- .cell_grid(cell)
  ids <- .cell_strings(cell)
  if (.is_legacy_grid(grid)) return(ids)
  if (!length(cell)) return(character())
  .check_cells_complete(cell)

  result <- rep.int(NA_character_, length(cell))
  resolution <- cell_resolution(cell)
  groups <- split(seq_along(cell), resolution)
  for (i in groups) {
    unique <- .unique_cells(cell[i])
    values <- unlist(lapply(.chunk_indices(length(unique$cell)), function(j) {
      .as_seqnum_one(unique$cell[j], resolution[[i[[1L]]]], grid)
    }), use.names = FALSE)
    result[i] <- values[unique$location]
  }
  result
}

#' Transform one bounded hierarchical-index batch to sequence numbers
#' @noRd
.as_seqnum_one <- function(cell, resolution, grid) {
  dir <- .job_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE), add = TRUE)
  .write_cells(dir, cell)
  meta <- c(
    "dggrid_operation TRANSFORM_POINTS",
    .meta_grid(grid, resolution),
    "input_file_name cells.txt",
    "input_address_type HIERNDX",
    paste("input_hier_ndx_system", toupper(grid$index_system)),
    "input_hier_ndx_form DIGIT_STRING",
    'input_delimiter " "',
    "output_file_name seqnum.txt",
    "output_address_type SEQNUM",
    'output_delimiter " "'
  )
  .run_job(dir, meta)
  trimws(readLines(file.path(dir, "seqnum.txt"), warn = FALSE))
}
