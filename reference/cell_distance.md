# Return shortest neighbor-graph distance

The current implementation uses bounded breadth-first search.

## Usage

``` r
cell_distance(origin, destination, max_k = 100L, progress = NULL)
```

## Arguments

- origin, destination:

  Cell vectors. Size-one inputs are recycled.

- max_k:

  Maximum search radius before returning `NA_integer_`.

- progress:

  Show progress for the bounded search. `NULL` shows a delayed progress
  bar in interactive sessions, while `TRUE` or `FALSE` always enables or
  disables it.

## Value

An integer vector.
