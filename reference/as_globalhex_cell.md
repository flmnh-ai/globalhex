# Construct a globalhex cell vector

Use this after character-only storage such as CSV or a database. Cell
vectors may contain multiple resolutions, but all cells must share one
grid system and orientation.

## Usage

``` r
as_globalhex_cell(x = character(), grid = hex_grid())
```

## Arguments

- x:

  A character vector of DGGRID cell IDs.

- grid:

  A grid from
  [`hex_grid()`](https://flmnh-ai.github.io/globalhex/reference/hex_grid.md)
  or
  [`legacy_grid()`](https://flmnh-ai.github.io/globalhex/reference/legacy_grid.md).

## Value

A `globalhex_cell` vector.

## Examples

``` r
grid <- hex_grid()
as_globalhex_cell(c("0203124", "02031240"), grid)
#> <globalhex_cell[2]>
#> [1] 0203124  02031240
```
