# Return cells within grid distance k

Return cells within grid distance k

## Usage

``` r
cell_disk(cell, k = 1L, progress = NULL)
```

## Arguments

- cell:

  One or more origin cells.

- k:

  Non-negative graph radius.

- progress:

  Show progress for multi-step traversal. `NULL` shows a delayed
  progress bar in interactive sessions, while `TRUE` or `FALSE` always
  enables or disables it.

## Value

A tibble with `origin`, `cell`, and exact `distance` columns.
