# Choose a display resolution for global-hex data

The selector combines a hard cell cap with a screen-pixel budget, then
walks the actual cell hierarchy inside the requested geographic extent.
Only cell centers are used during selection; polygon boundaries are not
generated.

## Usage

``` r
plot_resolution(
  x,
  extent = NULL,
  device_size = NULL,
  max_cells = 100000L,
  cell_pixels = 3,
  lod = TRUE,
  resolution = NULL
)
```

## Arguments

- x:

  A
  [`hex_data()`](https://flmnh-ai.github.io/globalhex/reference/hex_data.md)
  object.

- extent:

  Geographic extent as `c(xmin, xmax, ymin, ymax)` in longitude and
  latitude. `xmin > xmax` denotes an antimeridian-crossing extent.
  `NULL` infers an extent from a bounded set of hierarchical cells.

- device_size:

  Display width and height in pixels. `NULL` inspects the current
  graphics device and falls back to 800 by 600 pixels.

- max_cells:

  Hard maximum number of display cells.

- cell_pixels:

  Approximate minimum cell diameter in screen pixels.

- lod:

  Whether to select a coarser level automatically.

- resolution:

  Optional explicit display resolution.

## Value

A single display resolution.
