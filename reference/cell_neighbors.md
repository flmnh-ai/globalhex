# Return immediate cell neighbors

The return type is stable for one or many origins. Normal hexagons have
six rows per origin; pentagons have five.

## Usage

``` r
cell_neighbors(cell)
```

## Arguments

- cell:

  A `globalhex_cell` vector.

## Value

A tibble with `origin` and neighboring `cell` columns.

## Examples

``` r
x <- point_to_cell(c(-73.9857, 40.7484), 5)
cell_neighbors(x)
#> # A tibble: 6 × 2
#>   origin    cell     
#>   <gh_cell> <gh_cell>
#> 1 0203124   0203162  
#> 2 0203124   0203011  
#> 3 0203124   0203126  
#> 4 0203124   0203120  
#> 5 0203124   0203125  
#> 6 0203124   0203163  
```
