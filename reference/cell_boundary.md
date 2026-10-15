# Return cell boundary rings

Return cell boundary rings

## Usage

``` r
cell_boundary(cell)
```

## Arguments

- cell:

  A `globalhex_cell` vector.

## Value

A tibble with `cell` and `boundary`; `boundary` is a list-column of
closed longitude/latitude matrices.
