#' Require modern hierarchical cells
#' @noRd
.require_modern <- function(cell, arg = "cell", call = rlang::caller_env()) {
  grid <- .cell_grid(cell, arg = arg, call = call)
  if (.is_legacy_grid(grid)) {
    .abort(
      "{.arg {arg}} uses the explicit legacy grid, which has no modern hierarchy.",
      "globalhex_error_unsupported",
      arg = arg,
      call = call
    )
  }
  .check_cells_complete(cell, arg = arg, call = call)
  grid
}

#' Read one native relationship at one resolution
#' @noRd
.relation_once <- function(cell, relation = c("parent", "children", "neighbors")) {
  relation <- rlang::arg_match(relation)
  grid <- .require_modern(cell)
  if (!length(cell)) return(list())
  resolution <- unique(cell_resolution(cell))
  if (length(resolution) != 1L) {
    .abort("Internal relationship batches must have one resolution.", "globalhex_error_internal")
  }
  unique_cell <- .unique_cells(cell)$cell
  dir <- .job_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE), add = TRUE)
  .write_cells(dir, unique_cell)

  spec <- switch(
    relation,
    parent = c(
      "indexing_parent_output_type TEXT",
      "indexing_parent_output_file_name relation"
    ),
    children = c(
      "indexing_children_output_type TEXT",
      "indexing_children_output_file_name relation"
    ),
    neighbors = c(
      "neighbor_output_type TEXT",
      "neighbor_output_file_name relation"
    )
  )
  .run_job(dir, .generate_meta(grid, resolution, spec))
  suffix <- switch(relation, parent = ".ndxPrt", children = ".ndxChd", neighbors = ".nbr")
  .read_relation(file.path(dir, paste0("relation", suffix)), grid)
}

#' Return immediate cell neighbors
#'
#' The return type is stable for one or many origins. Normal hexagons have six
#' rows per origin; pentagons have five.
#'
#' @param cell A `globalhex_cell` vector.
#' @return A tibble with `origin` and neighboring `cell` columns.
#' @examples
#' x <- point_to_cell(c(-73.9857, 40.7484), 5)
#' cell_neighbors(x)
#' @export
cell_neighbors <- function(cell) {
  grid <- .require_modern(cell)
  empty <- .new_cells(character(), grid)
  if (!length(cell)) return(tibble::tibble(origin = empty, cell = empty))

  origins <- empty
  neighbors <- empty
  groups <- split(seq_along(cell), cell_resolution(cell))
  for (i in groups) {
    rel <- .relation_once(cell[i], "neighbors")
    for (j in i) {
      values <- rel[[.cell_strings(cell[j])]]
      origins <- vctrs::vec_c(origins, vctrs::vec_rep(cell[j], length(values)))
      neighbors <- vctrs::vec_c(neighbors, values)
    }
  }
  tibble::tibble(origin = origins, cell = neighbors)
}

#' Return ancestors by truncating hierarchical digit strings
#' @noRd
.parent_once <- function(cell) {
  grid <- .cell_grid(cell)
  resolution <- cell_resolution(cell) - 1L
  .cell_ancestor(cell, resolution, grid = grid)
}

#' Map cells to ancestors without invoking DGGRID
#' @noRd
.cell_ancestor <- function(cell, resolution, grid = .cell_grid(cell)) {
  current <- cell_resolution(cell)
  if (length(resolution) == 1L) {
    resolution <- rep.int(as.integer(resolution), length(cell))
  }
  if (length(resolution) != length(cell) || anyNA(resolution) ||
      any(resolution < 0L | resolution > current)) {
    .abort(
      "Ancestor resolution must be non-negative and no finer than each input cell.",
      "globalhex_error_resolution"
    )
  }
  ids <- .cell_strings(cell)
  ancestors <- substring(ids, 1L, resolution + 2L)
  .new_cells(ancestors, grid)
}

#' Return immediate children for a uniform-resolution batch
#' @noRd
.children_once <- function(cell) {
  grid <- .cell_grid(cell)
  rel <- .relation_once(cell, "children")
  values <- unlist(lapply(rel[.cell_strings(cell)], .cell_strings), use.names = FALSE)
  as_globalhex_cell(values, grid)
}

#' Return cell ancestors
#'
#' @param cell A `globalhex_cell` vector.
#' @param resolution Target coarser resolution. `NULL` selects each cell's
#'   immediate parent, including for mixed-resolution vectors.
#' @return A `globalhex_cell` vector with one parent per input cell.
#' @export
cell_parent <- function(cell, resolution = NULL) {
  grid <- .require_modern(cell)
  if (!length(cell)) return(.new_cells(character(), grid))
  current <- cell_resolution(cell)
  target <- if (is.null(resolution)) {
    current - 1L
  } else {
    rep.int(.scalar_int(resolution, "resolution"), length(cell))
  }
  if (any(target < 0L | target > current)) {
    .abort(
      "Parent resolution must be non-negative and no finer than every input cell.",
      "globalhex_error_resolution"
    )
  }

  .cell_ancestor(cell, target, grid = grid)
}

#' Expand cells to descendants with one backend call per active resolution
#' @noRd
.descendants_batch <- function(cell, target, max_cells, progress = NULL) {
  grid <- .cell_grid(cell)
  out <- lapply(seq_along(cell), function(i) cell[i])
  current <- cell_resolution(cell)
  progress_id <- .progress_start(
    "Expanding children",
    total = sum(target - current),
    progress = progress,
    call = rlang::caller_env()
  )
  on.exit(.progress_done(progress_id), add = TRUE)

  while (any(current < target)) {
    active <- which(current < target)
    for (i in active) {
      if (length(out[[i]]) * 6 > max_cells) {
        .abort(
          "Child expansion would exceed {.arg max_cells} ({max_cells}).",
          "globalhex_error_size",
          max_cells = max_cells
        )
      }
    }

    groups <- split(active, current[active])
    for (indices in groups) {
      frontier <- do.call(vctrs::vec_c, out[indices])
      rel <- .relation_once(frontier, "children")
      for (i in indices) {
        ids <- .cell_strings(out[[i]])
        values <- unlist(lapply(rel[ids], .cell_strings), use.names = FALSE)
        if (length(values) > max_cells) {
          .abort(
            "Child expansion would exceed {.arg max_cells} ({max_cells}).",
            "globalhex_error_size",
            max_cells = max_cells
          )
        }
        out[[i]] <- as_globalhex_cell(values, grid)
        current[[i]] <- current[[i]] + 1L
      }
      .progress_update(progress_id, length(indices))
    }
  }
  out
}

#' Return cell descendants
#'
#' @param cell A `globalhex_cell` vector.
#' @param resolution Target finer resolution. `NULL` selects immediate children
#'   for each input cell.
#' @param max_cells Safety cap per input cell.
#' @param progress Show progress for multi-level expansion. `NULL` shows a
#'   delayed progress bar in interactive sessions, while `TRUE` or `FALSE`
#'   always enables or disables it.
#' @return A tibble with the original `parent` and each descendant `cell`.
#' @export
cell_children <- function(
    cell,
    resolution = NULL,
    max_cells = 100000L,
    progress = NULL) {
  grid <- .require_modern(cell)
  progress <- .optional_flag(progress, "progress")
  max_cells <- .scalar_int(max_cells, "max_cells")
  empty <- .new_cells(character(), grid)
  if (!length(cell)) return(tibble::tibble(parent = empty, cell = empty))
  current <- cell_resolution(cell)
  target <- if (is.null(resolution)) {
    current + 1L
  } else {
    rep.int(.scalar_int(resolution, "resolution"), length(cell))
  }
  if (any(target < current | target > .max_resolution(grid))) {
    .abort(
      "Child resolution must be no coarser than every input and within the grid limit.",
      "globalhex_error_resolution"
    )
  }

  expanded <- .descendants_batch(cell, target, max_cells, progress = progress)
  parents <- empty
  descendants <- empty
  for (i in seq_along(expanded)) {
    parents <- vctrs::vec_c(parents, vctrs::vec_rep(cell[i], length(expanded[[i]])))
    descendants <- vctrs::vec_c(descendants, expanded[[i]])
  }
  tibble::tibble(parent = parents, cell = descendants)
}
