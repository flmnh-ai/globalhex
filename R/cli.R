#' Build the grid section of a DGGRID metafile
#' @noRd
.meta_grid <- function(grid, resolution) {
  .check_grid(grid)
  if (.is_legacy_grid(grid)) {
    .abort("Legacy grids cannot use the modern DGGRID backend.", "globalhex_error_backend")
  }
  resolution <- .validate_resolution(resolution, grid$system)
  lines <- c(
    paste("dggs_type", toupper(grid$system)),
    paste("dggs_res_spec", resolution),
    paste("hier_indexing_system_type", toupper(grid$index_system))
  )
  if (identical(grid$system, "isea3h")) {
    lines <- c(
      lines,
      "dggs_orient_specify_type SPECIFIED",
      paste("dggs_vert0_lon", format(grid$pole_lon, digits = 16, scientific = FALSE)),
      paste("dggs_vert0_lat", format(grid$pole_lat, digits = 16, scientific = FALSE)),
      paste("dggs_vert0_azimuth", format(grid$azimuth, digits = 16, scientific = FALSE))
    )
  }
  lines
}

#' Build hierarchical output controls
#' @noRd
.meta_hier_output <- function(grid, file = NULL) {
  out <- c(
    "output_address_type HIERNDX",
    paste("output_hier_ndx_system", toupper(grid$index_system)),
    "output_hier_ndx_form DIGIT_STRING",
    'output_delimiter " "'
  )
  if (!is.null(file)) out <- c(paste("output_file_name", file), out)
  out
}

#' Create an isolated DGGRID job directory
#' @noRd
.job_dir <- function() {
  path <- tempfile("globalhex-")
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

#' Maximum number of records sent through one backend job
#' @noRd
.backend_chunk_size <- function() 50000L

#' Split record positions into bounded backend chunks
#' @noRd
.chunk_indices <- function(n, size = .backend_chunk_size()) {
  n <- as.integer(n)
  size <- as.integer(size)
  if (!n) return(list())
  split(seq_len(n), ceiling(seq_len(n) / size))
}

#' Start an opt-in or interactive progress bar
#' @noRd
.progress_start <- function(name, total = NA, progress = NULL, call = rlang::caller_env()) {
  progress <- .optional_flag(progress, "progress", call = call)
  enabled <- if (is.null(progress)) rlang::is_interactive() else progress
  if (!enabled) return(NULL)
  cli::cli_progress_bar(
    name = name,
    total = total,
    current = FALSE,
    .auto_close = FALSE
  )
}

#' Update or finish an optional progress bar
#' @noRd
.progress_update <- function(id, inc = 1L) {
  if (!is.null(id)) cli::cli_progress_update(id = id, inc = inc)
  invisible(id)
}

#' @noRd
.progress_done <- function(id) {
  if (!is.null(id)) cli::cli_progress_done(id = id)
  invisible(id)
}

#' Write a job input file
#' @noRd
.write_job_file <- function(path, lines) {
  writeLines(enc2utf8(lines), path, useBytes = TRUE)
}

#' Execute DGGRID and translate backend failures
#' @noRd
.run_job <- function(dir, meta, timeout = 60000, call = rlang::caller_env()) {
  .write_job_file(file.path(dir, "job.meta"), meta)
  old_wd <- setwd(dir)
  on.exit(setwd(old_wd), add = TRUE)
  result <- tryCatch(
    system2(
      .find_dggrid(call = call),
      "job.meta",
      stdout = TRUE,
      stderr = TRUE,
      timeout = max(1L, as.integer(ceiling(timeout / 1000)))
    ),
    error = function(e) structure(conditionMessage(e), status = 1L)
  )
  status <- attr(result, "status", exact = TRUE) %||% 0L
  if (!identical(as.integer(status), 0L)) {
    details <- trimws(paste(result, collapse = "\n"))
    display <- if (nchar(details, type = "chars") > 4000L) {
      paste0(substr(details, 1L, 4000L), "\n... backend output truncated")
    } else {
      details
    }
    .abort(
      c("DGGRID failed.", "x" = "{display}"),
      "globalhex_error_backend",
      status = status,
      details = details,
      display = display,
      call = call
    )
  }
  invisible(result)
}

#' Write cells to a DGGRID address file
#' @noRd
.write_cells <- function(dir, cells, name = "cells.txt") {
  .check_cells_complete(cells)
  .write_job_file(file.path(dir, name), .cell_strings(cells))
}

#' Build a GENERATE_GRID metafile
#' @noRd
.generate_meta <- function(grid, resolution, outputs) {
  c(
    "dggrid_operation GENERATE_GRID",
    .meta_grid(grid, resolution),
    "clip_subset_type ADDRESS_FILES",
    "input_address_type HIERNDX",
    paste("input_hier_ndx_system", toupper(grid$index_system)),
    "input_hier_ndx_form DIGIT_STRING",
    "clip_region_files cells.txt",
    "output_cell_label_type OUTPUT_ADDRESS_TYPE",
    .meta_hier_output(grid),
    "densification 0",
    "precision 15",
    outputs
  )
}

#' Parse a DGGRID relationship file
#' @noRd
.read_relation <- function(path, grid) {
  lines <- readLines(path, warn = FALSE)
  fields <- strsplit(trimws(lines), "[[:space:]]+")
  names(fields) <- vapply(fields, `[[`, character(1), 1L)
  lapply(fields, function(x) as_globalhex_cell(x[-1L], grid))
}

#' Parse built-in GeoJSON output
#' @noRd
.read_geojson <- function(path) {
  object <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  object$features %||% list()
}

`%||%` <- function(x, y) if (is.null(x)) y else x
