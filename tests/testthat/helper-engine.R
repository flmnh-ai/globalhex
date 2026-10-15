modern_grid <- function(system = "igeo7") {
  info <- globalhex_info()
  testthat::skip_if(is.null(info$dggrid_path), "modern DGGRID is unavailable")
  hex_grid(system)
}
