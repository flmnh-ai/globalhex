#' Compute breadth-first layers for several origins
#' @noRd
.grid_layers_batch <- function(cell, k, progress = NULL) {
  grid <- .require_modern(cell)
  k <- .scalar_int(k, "k")
  if (k < 0L) .abort("{.arg k} must be non-negative.", "globalhex_error_argument")
  empty <- .new_cells(character(), grid)
  layers <- lapply(seq_along(cell), function(i) {
    out <- rep(list(empty), k + 1L)
    out[[1L]] <- cell[i]
    out
  })
  seen <- lapply(seq_along(cell), function(i) .cell_strings(cell[i]))
  frontier <- lapply(seq_along(cell), function(i) cell[i])
  if (!k) return(layers)
  progress_id <- .progress_start(
    "Traversing grid",
    total = k,
    progress = progress,
    call = rlang::caller_env()
  )
  on.exit(.progress_done(progress_id), add = TRUE)

  for (step in seq_len(k)) {
    active <- which(lengths(frontier) > 0L)
    if (!length(active)) break
    resolutions <- vapply(frontier[active], function(x) cell_resolution(x)[[1L]], integer(1))
    groups <- split(active, resolutions)

    for (indices in groups) {
      batch <- do.call(vctrs::vec_c, frontier[indices])
      rel <- .relation_once(batch, "neighbors")
      for (i in indices) {
        ids <- .cell_strings(frontier[[i]])
        candidates <- unique(unlist(lapply(rel[ids], .cell_strings), use.names = FALSE))
        fresh <- setdiff(candidates, seen[[i]])
        frontier[[i]] <- as_globalhex_cell(fresh, grid)
        layers[[i]][[step + 1L]] <- frontier[[i]]
        seen[[i]] <- c(seen[[i]], fresh)
      }
    }
    .progress_update(progress_id)
  }
  layers
}

#' Return cells within grid distance k
#'
#' @param cell One or more origin cells.
#' @param k Non-negative graph radius.
#' @param progress Show progress for multi-step traversal. `NULL` shows a
#'   delayed progress bar in interactive sessions, while `TRUE` or `FALSE`
#'   always enables or disables it.
#' @return A tibble with `origin`, `cell`, and exact `distance` columns.
#' @export
cell_disk <- function(cell, k = 1L, progress = NULL) {
  grid <- .require_modern(cell)
  progress <- .optional_flag(progress, "progress")
  k <- .scalar_int(k, "k")
  if (k < 0L) .abort("{.arg k} must be non-negative.", "globalhex_error_argument")
  empty <- .new_cells(character(), grid)
  if (!length(cell)) {
    return(tibble::tibble(origin = empty, cell = empty, distance = integer()))
  }

  origins <- empty
  members <- empty
  distance <- integer()
  layers <- .grid_layers_batch(cell, k, progress = progress)
  for (i in seq_along(cell)) {
    for (d in seq_along(layers[[i]]) - 1L) {
      values <- layers[[i]][[d + 1L]]
      origins <- vctrs::vec_c(origins, vctrs::vec_rep(cell[i], length(values)))
      members <- vctrs::vec_c(members, values)
      distance <- c(distance, rep.int(d, length(values)))
    }
  }
  tibble::tibble(origin = origins, cell = members, distance = distance)
}

#' Return cells at exactly grid distance k
#'
#' @param cell One or more origin cells.
#' @param k Non-negative graph distance.
#' @param progress Show progress for multi-step traversal. See [cell_disk()].
#' @return A tibble with `origin`, `cell`, and `distance` columns.
#' @export
cell_ring <- function(cell, k = 1L, progress = NULL) {
  progress <- .optional_flag(progress, "progress")
  out <- cell_disk(cell, k, progress = progress)
  out[out$distance == k, , drop = FALSE]
}

#' Return shortest neighbor-graph distance
#'
#' The current implementation uses bounded breadth-first search.
#'
#' @param origin,destination Cell vectors. Size-one inputs are recycled.
#' @param max_k Maximum search radius before returning `NA_integer_`.
#' @param progress Show progress for the bounded search. `NULL` shows a delayed
#'   progress bar in interactive sessions, while `TRUE` or `FALSE` always
#'   enables or disables it.
#' @return An integer vector.
#' @export
cell_distance <- function(origin, destination, max_k = 100L, progress = NULL) {
  origin_grid <- .require_modern(origin, "origin")
  destination_grid <- .require_modern(destination, "destination")
  progress <- .optional_flag(progress, "progress")
  if (!.same_grid(origin_grid, destination_grid)) {
    .abort(
      "{.arg origin} and {.arg destination} must use the same grid definition.",
      "globalhex_error_incompatible_grid"
    )
  }
  max_k <- .scalar_int(max_k, "max_k")
  if (max_k < 0L) .abort("{.arg max_k} must be non-negative.", "globalhex_error_argument")
  recycled <- vctrs::vec_recycle_common(origin = origin, destination = destination)
  origin <- recycled$origin
  destination <- recycled$destination
  if (any(cell_resolution(origin) != cell_resolution(destination))) {
    .abort(
      "Paired cells must have the same resolution.",
      "globalhex_error_resolution"
    )
  }

  origin_ids <- .cell_strings(origin)
  destination_ids <- .cell_strings(destination)
  distance <- rep.int(NA_integer_, length(origin))
  distance[origin_ids == destination_ids] <- 0L
  pending <- which(is.na(distance))
  if (!length(pending) || !max_k) return(distance)

  searches <- unname(split(pending, origin_ids[pending]))
  frontier <- lapply(searches, function(i) origin[i[[1L]]])
  seen <- lapply(frontier, .cell_strings)
  progress_id <- .progress_start(
    "Measuring distance",
    total = max_k,
    progress = progress,
    call = rlang::caller_env()
  )
  on.exit(.progress_done(progress_id), add = TRUE)

  for (step in seq_len(max_k)) {
    active <- which(lengths(frontier) > 0L & vapply(
      searches,
      function(i) anyNA(distance[i]),
      logical(1)
    ))
    if (!length(active)) break
    resolutions <- vapply(frontier[active], function(x) cell_resolution(x)[[1L]], integer(1))
    groups <- split(active, resolutions)

    for (indices in groups) {
      batch <- do.call(vctrs::vec_c, frontier[indices])
      rel <- .relation_once(batch, "neighbors")
      for (i in indices) {
        ids <- .cell_strings(frontier[[i]])
        candidates <- unique(unlist(lapply(rel[ids], .cell_strings), use.names = FALSE))
        fresh <- setdiff(candidates, seen[[i]])
        request <- searches[[i]]
        found <- request[is.na(distance[request]) & destination_ids[request] %in% fresh]
        distance[found] <- as.integer(step)
        frontier[[i]] <- as_globalhex_cell(fresh, origin_grid)
        seen[[i]] <- c(seen[[i]], fresh)
      }
    }
    .progress_update(progress_id)
  }
  distance
}
