# Return cells at exactly grid distance k

Return cells at exactly grid distance k

## Usage

``` r
cell_ring(cell, k = 1L, progress = NULL)
```

## Arguments

- cell:

  One or more origin cells.

- k:

  Non-negative graph distance.

- progress:

  Show progress for multi-step traversal. See
  [`cell_disk()`](https://flmnh-ai.github.io/globalhex/reference/cell_disk.md).

## Value

A tibble with `origin`, `cell`, and `distance` columns.
