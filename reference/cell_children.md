# Return cell descendants

Return cell descendants

## Usage

``` r
cell_children(cell, resolution = NULL, max_cells = 100000L, progress = NULL)
```

## Arguments

- cell:

  A `globalhex_cell` vector.

- resolution:

  Target finer resolution. `NULL` selects immediate children for each
  input cell.

- max_cells:

  Safety cap per input cell.

- progress:

  Show progress for multi-level expansion. `NULL` shows a delayed
  progress bar in interactive sessions, while `TRUE` or `FALSE` always
  enables or disables it.

## Value

A tibble with the original `parent` and each descendant `cell`.
