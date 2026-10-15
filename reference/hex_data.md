# Construct lazily geometric global-hex data

`hex_data()` keeps indexed cells and ordinary attribute columns
together. It deliberately stores no polygon geometry; geometry is
generated only for the cells ultimately selected for display.

## Usage

``` r
hex_data(cell, ...)
```

## Arguments

- cell:

  A `globalhex_cell` vector.

- ...:

  One or more vectors of cell attributes. Size-one values are recycled
  by
  [`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html).

## Value

A `globalhex_data` tibble.

## Examples

``` r
cells <- point_to_cell(rbind(c(0, 0), c(10, 10)), 5)
x <- hex_data(cells, value = c(1, 2))
x
#> # A tibble: 2 × 2
#>   cell      value
#>   <gh_cell> <dbl>
#> 1 0365650       1
#> 2 0366031       2
```
