# Return cell centers

Return cell centers

## Usage

``` r
cell_center(cell)
```

## Arguments

- cell:

  A `globalhex_cell` vector.

## Value

A tibble with `cell`, `lon`, and `lat` columns.

## Examples

``` r
x <- point_to_cell(c(-73.9857, 40.7484), 5)
cell_center(x)
#> # A tibble: 1 × 3
#>   cell        lon   lat
#>   <gh_cell> <dbl> <dbl>
#> 1 0203124   -74.0  40.9
```
