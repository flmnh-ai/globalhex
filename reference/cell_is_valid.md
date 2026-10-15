# Check cell identifiers

The default check is local and fast. It checks the two-digit base cell,
resolution, hierarchy digits, and deleted pentagon subsequences. Strict
validation additionally asks DGGRID (or dggridR for legacy cells) to
resolve each syntactically valid identifier.

## Usage

``` r
cell_is_valid(x, grid = NULL, strict = FALSE)
```

## Arguments

- x:

  A `globalhex_cell` or character vector.

- grid:

  Grid definition for character input. `NULL` uses
  [`hex_grid()`](https://flmnh-ai.github.io/globalhex/reference/hex_grid.md).
  The attached grid is always used for `globalhex_cell` input.

- strict:

  Whether to confirm syntactically valid identifiers with the relevant
  backend.

## Value

A logical vector with one value per identifier.

## Examples

``` r
cell_is_valid(c("0203124", "99"))
#> [1]  TRUE FALSE
cell_is_valid(point_to_cell(c(0, 0), 5))
#> [1] TRUE
```
