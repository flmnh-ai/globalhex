# Sample raster values at cell centers

`cell_sample()` is the fast, geometry-free raster path. Cell centers are
transformed into the raster coordinate reference system and sampled with
[`terra::extract()`](https://rspatial.github.io/terra/reference/extract.html).
Use
[`cell_extract()`](https://flmnh-ai.github.io/globalhex/reference/cell_extract.md)
when partial raster-pixel coverage must be represented exactly.

## Usage

``` r
cell_sample(cell, raster, method = c("simple", "bilinear"))
```

## Arguments

- cell:

  A `globalhex_cell` vector.

- raster:

  A
  [terra::SpatRaster](https://rspatial.github.io/terra/reference/SpatRaster-class.html).

- method:

  Either `"simple"` for nearest-cell lookup or `"bilinear"`.

## Value

A
[`hex_data()`](https://flmnh-ai.github.io/globalhex/reference/hex_data.md)
object with one row per input cell and one column per raster layer.
