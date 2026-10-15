# Convert a raster footprint to global-hex data

`raster_to_cell()` covers the raster extent with DGGS cells, includes
the neighboring edge cells needed for exact overlap, removes
non-intersecting candidates, and extracts raster summaries. It returns
no polygon geometry.

## Usage

``` r
raster_to_cell(
  raster,
  resolution,
  grid = hex_grid(),
  fun = NULL,
  weights = "area",
  ...,
  max_cells = 100000L,
  progress = NULL,
  drop_na = TRUE
)
```

## Arguments

- raster:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html).

- resolution:

  Target DGGS resolution.

- grid:

  A modern grid from
  [`hex_grid()`](https://flmnh-ai.github.io/globalhex/reference/hex_grid.md).

- fun, weights, ...:

  Extraction arguments passed to
  [`cell_extract()`](https://flmnh-ai.github.io/globalhex/reference/cell_extract.md).

- max_cells:

  Hard maximum number of returned cells.

- progress:

  Show progress where supported. `NULL` uses interactive defaults.

- drop_na:

  Whether to remove cells for which every extracted raster summary is
  missing.

## Value

A
[`hex_data()`](https://flmnh-ai.github.io/globalhex/reference/hex_data.md)
object covering the raster extent.
