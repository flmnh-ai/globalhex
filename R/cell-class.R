#' Construct a globalhex cell vector
#'
#' Use this after character-only storage such as CSV or a database. Cell
#' vectors may contain multiple resolutions, but all cells must share one grid
#' system and orientation.
#'
#' @param x A character vector of DGGRID cell IDs.
#' @param grid A grid from [hex_grid()] or [legacy_grid()].
#' @return A `globalhex_cell` vector.
#' @examples
#' grid <- hex_grid()
#' as_globalhex_cell(c("0203124", "02031240"), grid)
#' @export
as_globalhex_cell <- function(x = character(), grid = hex_grid()) {
  .check_grid(grid)
  x <- vctrs::vec_cast(x, character())
  present <- !is.na(x)
  if (any(present & !nzchar(x))) {
    .abort("Cell IDs cannot be empty strings.", "globalhex_error_invalid_cell")
  }

  if (!.is_legacy_grid(grid)) {
    if (any(present & !grepl("^[0-9]+$", x))) {
      .abort(
        "Hierarchical cell IDs must contain digits only.",
        "globalhex_error_invalid_cell"
      )
    }
    resolution <- nchar(x[present]) - 2L
    if (any(resolution < 0L | resolution > .max_resolution(grid))) {
      .abort(
        "Cell IDs contain a resolution outside the range supported by {toupper(grid$index_system)}.",
        "globalhex_error_invalid_cell"
      )
    }
  } else if (any(present & !grepl("^[0-9]+$", x))) {
    .abort("Legacy sequence numbers must contain digits only.", "globalhex_error_invalid_cell")
  }

  .new_cells(x, grid)
}

#' Low-level cell constructor
#' @noRd
.new_cells <- function(x = character(), grid = hex_grid()) {
  vctrs::new_vctr(
    as.character(x),
    grid = grid,
    class = "globalhex_cell"
  )
}

#' Access the storage values of a cell vector
#' @noRd
.cell_strings <- function(x) {
  vctrs::vec_data(x)
}

#' Deduplicate cells while retaining a restoration index
#' @noRd
.unique_cells <- function(cell) {
  ids <- .cell_strings(cell)
  keep <- !duplicated(ids)
  list(
    cell = cell[keep],
    location = match(ids, ids[keep])
  )
}

#' Access the semantic grid attached to cells
#' @noRd
.cell_grid <- function(x, arg = "cell", call = rlang::caller_env()) {
  if (!inherits(x, "globalhex_cell")) {
    .abort(
      "{.arg {arg}} must be a <globalhex_cell> vector.",
      "globalhex_error_argument",
      arg = arg,
      call = call
    )
  }
  grid <- attr(x, "grid", exact = TRUE)
  .check_grid(grid, call = call)
  grid
}

#' Return the grid attached to cells
#'
#' @param cell A `globalhex_cell` vector.
#' @return The [hex_grid()] or [legacy_grid()] shared by every element.
#' @export
cell_grid <- function(cell) {
  .cell_grid(cell)
}

#' Check cell identifiers
#'
#' The default check is local and fast. It checks the two-digit base cell,
#' resolution, hierarchy digits, and deleted pentagon subsequences. Strict
#' validation additionally asks DGGRID (or dggridR for legacy cells) to resolve
#' each syntactically valid identifier.
#'
#' @param x A `globalhex_cell` or character vector.
#' @param grid Grid definition for character input. `NULL` uses [hex_grid()].
#'   The attached grid is always used for `globalhex_cell` input.
#' @param strict Whether to confirm syntactically valid identifiers with the
#'   relevant backend.
#' @return A logical vector with one value per identifier.
#' @examples
#' cell_is_valid(c("0203124", "99"))
#' cell_is_valid(point_to_cell(c(0, 0), 5))
#' @export
cell_is_valid <- function(x, grid = NULL, strict = FALSE) {
  if (length(strict) != 1L || is.na(strict) || !is.logical(strict)) {
    .abort("{.arg strict} must be {.code TRUE} or {.code FALSE}.", "globalhex_error_argument")
  }

  if (inherits(x, "globalhex_cell")) {
    attached <- .cell_grid(x, arg = "x")
    if (!is.null(grid)) {
      .check_grid(grid)
      if (!.same_grid(attached, grid)) {
        .abort(
          "{.arg grid} must match the grid attached to {.arg x}.",
          "globalhex_error_incompatible_grid"
        )
      }
    }
    grid <- attached
    ids <- .cell_strings(x)
  } else {
    if (!is.character(x)) {
      .abort("{.arg x} must be a character or <globalhex_cell> vector.", "globalhex_error_argument")
    }
    grid <- grid %||% hex_grid()
    .check_grid(grid)
    ids <- x
  }

  valid <- .cell_syntax_valid(ids, grid)
  if (!strict || !any(valid)) return(valid)

  if (.is_legacy_grid(grid)) {
    rlang::check_installed("dggridR", reason = "to strictly validate legacy cells")
  } else {
    .find_dggrid()
  }
  for (i in which(valid)) {
    probe <- .new_cells(ids[[i]], grid)
    valid[[i]] <- tryCatch(
      {
        center <- cell_center(probe)
        nrow(center) == 1L && all(is.finite(c(center$lon, center$lat)))
      },
      error = function(e) FALSE
    )
  }
  valid
}

#' Perform fast local identifier validation
#' @noRd
.cell_syntax_valid <- function(ids, grid) {
  valid <- !is.na(ids) & nzchar(ids) & grepl("^[0-9]+$", ids)
  if (.is_legacy_grid(grid)) return(valid)

  resolution <- nchar(ids) - 2L
  base <- suppressWarnings(as.integer(substr(ids, 1L, 2L)))
  valid <- valid & resolution >= 0L & resolution <= .max_resolution(grid) &
    !is.na(base) & base >= 0L & base <= 11L &
    grepl("^[0-6]*$", substring(ids, 3L))

  for (i in which(valid & resolution > 0L)) {
    digits <- substring(ids[[i]], 3L)
    first_nonzero <- regexpr("[1-6]", digits)[[1L]]
    if (first_nonzero > 0L) {
      skip <- if (base[[i]] <= 5L) "2" else "5"
      if (substr(digits, first_nonzero, first_nonzero) == skip) valid[[i]] <- FALSE
    }
  }
  valid
}

#' @export
format.globalhex_cell <- function(x, ...) {
  .cell_strings(x)
}

#' @export
as.character.globalhex_cell <- function(x, ...) {
  .cell_strings(x)
}

#' @export
vec_ptype_abbr.globalhex_cell <- function(x, ...) "gh_cell"

#' @export
vec_ptype_full.globalhex_cell <- function(x, ...) "globalhex_cell"

#' @export
vec_ptype2.globalhex_cell.globalhex_cell <- function(x, y, ...) {
  x_grid <- .cell_grid(x)
  y_grid <- .cell_grid(y)
  if (!.same_grid(x_grid, y_grid)) {
    vctrs::stop_incompatible_type(
      x,
      y,
      x_arg = "x",
      y_arg = "y",
      details = "Cells use different global grid definitions."
    )
  }
  .new_cells(character(), x_grid)
}

#' @export
vec_cast.globalhex_cell.globalhex_cell <- function(x, to, ...) {
  if (!.same_grid(.cell_grid(x), .cell_grid(to))) {
    vctrs::stop_incompatible_cast(
      x,
      to,
      x_arg = "x",
      to_arg = "to",
      details = "Cells use different global grid definitions."
    )
  }
  .new_cells(.cell_strings(x), .cell_grid(to))
}

#' Return cell resolution
#'
#' @param cell A `globalhex_cell` vector.
#' @return An integer vector, one value per cell.
#' @examples
#' cell_resolution(as_globalhex_cell(c("0203124", "02031240")))
#' @export
cell_resolution <- function(cell) {
  grid <- .cell_grid(cell)
  if (.is_legacy_grid(grid)) {
    return(rep.int(as.integer(grid$resolution), vctrs::vec_size(cell)))
  }
  out <- as.integer(nchar(.cell_strings(cell)) - 2L)
  out[is.na(cell)] <- NA_integer_
  out
}
