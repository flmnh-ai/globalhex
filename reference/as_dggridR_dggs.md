# Convert to a low-level dggridR grid

Convert to a low-level dggridR grid

## Usage

``` r
as_dggridR_dggs(grid, resolution = NULL)
```

## Arguments

- grid:

  An ISEA3H
  [`hex_grid()`](https://flmnh-ai.github.io/globalhex/reference/hex_grid.md)
  or a
  [`legacy_grid()`](https://flmnh-ai.github.io/globalhex/reference/legacy_grid.md).

- resolution:

  Resolution for a modern grid; ignored for a legacy grid.

## Value

A dggridR grid list.
