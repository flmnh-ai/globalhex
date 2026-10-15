test_that("grid definitions contain spatial identity, not execution state", {
  z7 <- modern_grid("igeo7")
  expect_s3_class(z7, "globalhex_grid")
  expect_identical(z7$index_system, "z7")
  expect_false("resolution" %in% names(z7))
  expect_false("dggrid" %in% names(z7))

  z3 <- modern_grid("isea3h")
  expect_identical(z3$index_system, "z3")
  expect_error(
    hex_grid("igeo7", azimuth = 1),
    class = "globalhex_error_grid"
  )
})

test_that("cell vectors support mixed resolutions and tidy containers", {
  grid <- modern_grid()
  cell <- as_globalhex_cell(c("0203124", "02031240", NA), grid)
  expect_s3_class(cell, "globalhex_cell")
  expect_identical(as.character(cell), c("0203124", "02031240", NA_character_))
  expect_identical(cell_resolution(cell), c(5L, 6L, NA_integer_))

  tbl <- tibble::tibble(cell = cell)
  expect_s3_class(tbl$cell, "globalhex_cell")
  expect_equal(vctrs::vec_c(cell[1], cell[2]), cell[1:2])

  other <- as_globalhex_cell("0111202", hex_grid("isea3h"))
  expect_error(vctrs::vec_c(cell[1], other), class = "vctrs_error_incompatible_type")
  expect_error(as_globalhex_cell("abc", grid), class = "globalhex_error_invalid_cell")
})

test_that("zero-length cell vectors are valid prototypes", {
  x <- as_globalhex_cell()
  expect_length(x, 0L)
  expect_identical(cell_resolution(x), integer())
})

test_that("grid access and identifier validation are explicit", {
  grid <- modern_grid()
  cell <- point_to_cell(c(0, 0), 5, grid)

  expect_identical(cell_grid(cell), grid)
  expect_true(cell_is_valid(cell))
  expect_true(cell_is_valid(cell, strict = TRUE))
  expect_identical(
    cell_is_valid(c("00", "12", "002", "065", "0207", "abc", ""), grid),
    c(TRUE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE)
  )
  expect_error(cell_is_valid(cell, grid = hex_grid("isea3h")),
    class = "globalhex_error_incompatible_grid"
  )
})
