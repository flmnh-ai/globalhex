# Define a global hexagonal grid

`hex_grid()` describes spatial identity only: the DGGS family,
hierarchy, and orientation. Resolution belongs to cells and is supplied
to
[`point_to_cell()`](https://flmnh-ai.github.io/globalhex/reference/point_to_cell.md)
or
[`cell_cover()`](https://flmnh-ai.github.io/globalhex/reference/cell_cover.md).
Backend discovery is deliberately separate from the grid definition.

## Usage

``` r
hex_grid(
  system = c("igeo7", "isea3h"),
  pole_lon = 11.25,
  pole_lat = 58.28252559,
  azimuth = 0
)
```

## Arguments

- system:

  Either `"igeo7"` (the equal-area Z7 default) or `"isea3h"` (equal-area
  Z3).

- pole_lon, pole_lat, azimuth:

  Orientation in degrees. IGEO7 has a canonical orientation; custom
  values are supported for ISEA3H.

## Value

A `globalhex_grid` object.

## Examples

``` r
hex_grid()
#> <globalhex_grid>
#> system: IGEO7
#> index: Z7
#> orientation: 11.25, 58.28252559, 0
hex_grid("isea3h")
#> <globalhex_grid>
#> system: ISEA3H
#> index: Z3
#> orientation: 11.25, 58.28252559, 0
```
