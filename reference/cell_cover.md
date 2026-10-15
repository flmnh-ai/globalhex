# Cover polygons with cells

DGGRID selects cells whose nuclei fall inside the supplied polygon
region. Large polygons at fine resolutions can be expensive.

## Usage

``` r
cell_cover(
  polygon,
  resolution,
  grid = hex_grid(),
  include_holes = TRUE,
  max_cells = 100000L,
  progress = NULL,
  densify = 0.01
)
```

## Arguments

- polygon:

  An sf/sfc POLYGON or MULTIPOLYGON object.

- resolution:

  Target grid resolution.

- grid:

  A modern grid from
  [`hex_grid()`](https://flmnh-ai.github.io/globalhex/reference/hex_grid.md).

- include_holes:

  Whether interior holes exclude cell nuclei.

- max_cells:

  Safety cap applied to the returned result.

- progress:

  Show progress while DGGRID covers the polygon. `NULL` shows a delayed
  progress bar in interactive sessions, while `TRUE` or `FALSE` always
  enables or disables it.

- densify:

  Maximum angular spacing in degrees when DGGRID densifies polygon
  edges. The conservative default is intended for arbitrary input
  polygons; rectangular raster footprints can safely use a coarser
  value.

## Value

A `globalhex_cell` vector.
