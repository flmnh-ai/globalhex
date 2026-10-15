#' Construct lazily geometric global-hex data
#'
#' `hex_data()` keeps indexed cells and ordinary attribute columns together.
#' It deliberately stores no polygon geometry; geometry is generated only for
#' the cells ultimately selected for display.
#'
#' @param cell A `globalhex_cell` vector.
#' @param ... One or more vectors of cell attributes. Size-one values are
#'   recycled by [tibble::tibble()].
#' @return A `globalhex_data` tibble.
#' @examples
#' cells <- point_to_cell(rbind(c(0, 0), c(10, 10)), 5)
#' x <- hex_data(cells, value = c(1, 2))
#' x
#' @export
hex_data <- function(cell, ...) {
  .cell_grid(cell)
  out <- tibble::tibble(cell = cell, ...)
  if (ncol(out) < 2L) {
    .abort(
      "Supply at least one attribute column in {.arg ...}.",
      "globalhex_error_argument"
    )
  }
  .new_hex_data(out)
}

#' @noRd
.new_hex_data <- function(x) {
  class(x) <- unique(c("globalhex_data", class(x)))
  x
}

#' @noRd
.check_hex_data <- function(x, call = rlang::caller_env()) {
  if (!inherits(x, "globalhex_data") || !"cell" %in% names(x) ||
      !inherits(x$cell, "globalhex_cell")) {
    .abort(
      "{.arg x} must be created by {.fn hex_data}.",
      "globalhex_error_argument",
      call = call
    )
  }
  invisible(x)
}

#' @noRd
.value_columns <- function(x, value = NULL, call = rlang::caller_env()) {
  choices <- setdiff(names(x), "cell")
  if (is.null(value)) return(choices)
  if (!is.character(value) || !length(value) || anyNA(value) ||
      any(!value %in% choices)) {
    .abort(
      "{.arg value} must name one or more attribute columns.",
      "globalhex_error_argument",
      call = call
    )
  }
  unique(value)
}

#' Aggregate values to hierarchical ancestors
#'
#' Parent assignment uses the Z7 or Z3 digit-string hierarchy directly; it
#' does not perform polygon operations or invoke DGGRID. With `fun = NULL`,
#' numeric values use the mean, logical values use a majority rule, and
#' categorical values use the mode. Summation is always explicit
#' (`fun = sum`).
#'
#' @param x A [hex_data()] object.
#' @param resolution Target ancestor resolution.
#' @param fun A summary function or function name. `NULL` selects a conservative
#'   type-aware default.
#' @param na.rm Whether to remove missing values before aggregation.
#' @param value Attribute columns to aggregate. `NULL` aggregates all columns.
#' @return A `globalhex_data` object with one row per represented ancestor.
#' @examples
#' cells <- point_to_cell(rbind(c(0, 0), c(0.01, 0.01)), 5)
#' cell_aggregate(hex_data(cells, value = c(1, 3)), 4)
#' @export
cell_aggregate <- function(x, resolution, fun = NULL, na.rm = TRUE, value = NULL) {
  .check_hex_data(x)
  grid <- .cell_grid(x$cell)
  if (.is_legacy_grid(grid)) {
    .abort(
      "{.fn cell_aggregate} requires hierarchical Z7 or Z3 cells.",
      "globalhex_error_unsupported"
    )
  }
  resolution <- .scalar_int(resolution, "resolution")
  if (resolution < 0L || any(resolution > cell_resolution(x$cell))) {
    .abort(
      "{.arg resolution} must be no finer than every source cell.",
      "globalhex_error_resolution"
    )
  }
  if (length(na.rm) != 1L || is.na(na.rm) || !is.logical(na.rm)) {
    .abort("{.arg na.rm} must be {.code TRUE} or {.code FALSE}.", "globalhex_error_argument")
  }
  columns <- .value_columns(x, value)
  if (!is.null(fun)) fun <- match.fun(fun)

  ancestor <- .cell_ancestor(x$cell, resolution, grid = grid)
  .aggregate_with_ancestor(x, ancestor, columns, fun, na.rm)
}

#' Aggregate using an already-computed ancestor vector
#' @noRd
.aggregate_with_ancestor <- function(x, ancestor, columns, fun, na.rm, keep = NULL) {
  grid <- .cell_grid(x$cell)
  ids <- .cell_strings(ancestor)
  restrict <- !is.null(keep) && !all(keep)
  if (restrict) ids <- ids[keep]
  keys <- unique(ids)
  group <- match(ids, keys)
  result <- lapply(columns, function(column) {
    values <- x[[column]]
    if (restrict) values <- values[keep]
    .aggregate_column(
      values,
      group = group,
      n_groups = length(keys),
      fun = fun,
      na.rm = na.rm
    )
  })
  names(result) <- columns
  data <- tibble::as_tibble(c(list(
    cell = as_globalhex_cell(keys, grid)
  ), result))
  .new_hex_data(data)
}

#' @noRd
.aggregate_column <- function(x, group, n_groups, fun, na.rm) {
  if (is.numeric(x) && (is.null(fun) || identical(fun, base::mean))) {
    return(.grouped_numeric(x, group, n_groups, "mean", na.rm))
  }
  if ((is.numeric(x) || is.logical(x)) && identical(fun, base::sum)) {
    return(.grouped_numeric(x, group, n_groups, "sum", na.rm))
  }
  if (is.logical(x) && is.null(fun)) {
    average <- .grouped_numeric(as.numeric(x), group, n_groups, "mean", na.rm)
    return(ifelse(is.na(average), NA, average >= 0.5))
  }

  summarize <- fun
  if (is.null(summarize)) {
    summarize <- if (is.numeric(x)) {
      base::mean
    } else if (is.logical(x) || is.factor(x) || is.character(x)) {
      .mode_value
    } else {
      .abort(
        "No default aggregation is defined for class {.cls {class(x)[[1L]]}}; supply {.arg fun}.",
        "globalhex_error_argument"
      )
    }
  }

  locations <- split(seq_along(group), group)
  pieces <- lapply(locations, function(i) {
    values <- x[i]
    if (na.rm) values <- values[!is.na(values)]
    if (!length(values)) return(vctrs::vec_init(x, 1L))
    answer <- summarize(values)
    if (vctrs::vec_size(answer) != 1L) {
      .abort(
        "{.arg fun} must return exactly one value per display cell.",
        "globalhex_error_argument"
      )
    }
    answer
  })
  out <- vctrs::list_unchop(pieces)
  names(out) <- NULL
  out
}

#' Fast grouped mean and sum for the common plotting cases
#' @noRd
.grouped_numeric <- function(x, group, n_groups, operation, na.rm) {
  present <- !is.na(x)
  if (na.rm) {
    total <- numeric(n_groups)
    if (any(present)) {
      sums <- rowsum(x[present], group[present], reorder = FALSE)
      total[as.integer(rownames(sums))] <- sums[, 1L]
    }
    if (identical(operation, "sum")) return(total)
    count <- tabulate(group[present], nbins = n_groups)
    total[count == 0L] <- NA_real_
    return(total / count)
  }

  sums <- rowsum(x, group, reorder = FALSE, na.rm = FALSE)
  total <- numeric(n_groups)
  total[as.integer(rownames(sums))] <- sums[, 1L]
  if (identical(operation, "sum")) return(total)
  total / tabulate(group, nbins = n_groups)
}

#' Return the first most-frequent non-missing value
#' @noRd
.mode_value <- function(x) {
  key <- as.character(x)
  candidates <- unique(key)
  winner <- candidates[[which.max(tabulate(match(key, candidates)))]]
  x[[match(winner, key)]]
}
