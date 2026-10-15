#' Abort with a globalhex error
#'
#' @param message A cli-formatted error message.
#' @param class A specific globalhex condition subclass.
#' @param ... Data stored on the condition.
#' @param call The user-facing call to report.
#' @noRd
.abort <- function(
    message,
    class = "globalhex_error",
    ...,
    call = rlang::caller_env()) {
  cli::cli_abort(
    message,
    class = unique(c(class, "globalhex_error")),
    ...,
    call = call,
    .envir = rlang::caller_env()
  )
}

#' Validate a scalar integer
#' @noRd
.scalar_int <- function(x, arg, call = rlang::caller_env()) {
  if (length(x) != 1L || is.na(x) || !is.finite(x) || x != as.integer(x)) {
    .abort(
      "{.arg {arg}} must be one finite integer.",
      "globalhex_error_argument",
      arg = arg,
      call = call
    )
  }
  as.integer(x)
}

#' Validate an optional scalar flag
#' @noRd
.optional_flag <- function(x, arg, call = rlang::caller_env()) {
  if (is.null(x)) return(NULL)
  if (length(x) != 1L || is.na(x) || !is.logical(x)) {
    .abort(
      "{.arg {arg}} must be {.code TRUE}, {.code FALSE}, or {.code NULL}.",
      "globalhex_error_argument",
      arg = arg,
      call = call
    )
  }
  x
}

#' Reject missing cells before sending data to DGGRID
#' @noRd
.check_cells_complete <- function(cell, arg = "cell", call = rlang::caller_env()) {
  if (anyNA(cell)) {
    .abort(
      "{.arg {arg}} cannot contain missing cells for this operation.",
      "globalhex_error_missing_cell",
      arg = arg,
      call = call
    )
  }
  invisible(cell)
}
