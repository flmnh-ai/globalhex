# Convert points to cells

Coordinates consistently use longitude before latitude. Named data-frame
columns and sf POINT objects are preferred for clarity.

## Usage

``` r
point_to_cell(points, resolution = NULL, grid = hex_grid())
```

## Arguments

- points:

  Point coordinates as `c(lon, lat)`, a two-column matrix/data frame, or
  an sf POINT object.

- resolution:

  Target resolution. Required for modern grids; fixed by a
  [`legacy_grid()`](https://flmnh-ai.github.io/globalhex/reference/legacy_grid.md).

- grid:

  A grid definition from
  [`hex_grid()`](https://flmnh-ai.github.io/globalhex/reference/hex_grid.md)
  or
  [`legacy_grid()`](https://flmnh-ai.github.io/globalhex/reference/legacy_grid.md).

## Value

A `globalhex_cell` vector with one cell per input point.

## Examples

``` r
grid <- hex_grid()
point_to_cell(c(-73.9857, 40.7484), resolution = 5, grid = grid)
#> <globalhex_cell[1]>
#> [1] 0203124
```
