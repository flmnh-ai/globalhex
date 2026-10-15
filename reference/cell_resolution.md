# Return cell resolution

Return cell resolution

## Usage

``` r
cell_resolution(cell)
```

## Arguments

- cell:

  A `globalhex_cell` vector.

## Value

An integer vector, one value per cell.

## Examples

``` r
cell_resolution(as_globalhex_cell(c("0203124", "02031240")))
#> [1] 5 6
```
