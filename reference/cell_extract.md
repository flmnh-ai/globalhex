# Extract raster summaries into cells

Cell polygons are generated only for the supplied cells. Extraction uses
exact raster-pixel coverage through
[`exactextractr::exact_extract()`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html).
With `fun = NULL`, continuous layers use an area-weighted mean and
categorical layers use a coverage-weighted mode. This makes
longitude/latitude rasters safe by default, because their pixels do not
have equal physical area.

## Usage

``` r
cell_extract(cell, raster, fun = NULL, weights = "area", ..., progress = NULL)
```

## Arguments

- cell:

  A `globalhex_cell` vector.

- raster:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html).

- fun:

  A named `exactextractr` summary, a vector of summary names, or a
  custom summary function. `NULL` chooses a type-aware default.

- weights:

  Weights for continuous defaults and explicit weighted summaries. Use
  `"area"` (the default), `NULL` for coverage fractions alone, or a
  compatible
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html).

- ...:

  Additional arguments passed to
  [`exactextractr::exact_extract()`](https://isciences.gitlab.io/exactextractr/reference/exact_extract.html).

- progress:

  Whether `exactextractr` displays progress. `NULL` follows
  [`interactive()`](https://rdrr.io/r/base/interactive.html).

## Value

A
[`hex_data()`](https://flmnh-ai.github.io/globalhex/reference/hex_data.md)
object with one row per input cell.
