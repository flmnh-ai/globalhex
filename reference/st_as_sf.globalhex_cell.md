# Convert cells to sf polygons

Convert cells to sf polygons

## Usage

``` r
# S3 method for class 'globalhex_cell'
st_as_sf(x, ...)
```

## Arguments

- x:

  A `globalhex_cell` vector.

- ...:

  Passed to methods; currently unused.

## Value

An sf object in EPSG:4326 with one polygon per cell.
