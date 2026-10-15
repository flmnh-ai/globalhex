# Return cell ancestors

Return cell ancestors

## Usage

``` r
cell_parent(cell, resolution = NULL)
```

## Arguments

- cell:

  A `globalhex_cell` vector.

- resolution:

  Target coarser resolution. `NULL` selects each cell's immediate
  parent, including for mixed-resolution vectors.

## Value

A `globalhex_cell` vector with one parent per input cell.
