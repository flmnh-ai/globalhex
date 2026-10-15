# Aggregate values to hierarchical ancestors

Parent assignment uses the Z7 or Z3 digit-string hierarchy directly; it
does not perform polygon operations or invoke DGGRID. With `fun = NULL`,
numeric values use the mean, logical values use a majority rule, and
categorical values use the mode. Summation is always explicit
(`fun = sum`).

## Usage

``` r
cell_aggregate(x, resolution, fun = NULL, na.rm = TRUE, value = NULL)
```

## Arguments

- x:

  A
  [`hex_data()`](https://flmnh-ai.github.io/globalhex/reference/hex_data.md)
  object.

- resolution:

  Target ancestor resolution.

- fun:

  A summary function or function name. `NULL` selects a conservative
  type-aware default.

- na.rm:

  Whether to remove missing values before aggregation.

- value:

  Attribute columns to aggregate. `NULL` aggregates all columns.

## Value

A `globalhex_data` object with one row per represented ancestor.

## Examples

``` r
cells <- point_to_cell(rbind(c(0, 0), c(0.01, 0.01)), 5)
cell_aggregate(hex_data(cells, value = c(1, 3)), 4)
#> # A tibble: 1 × 2
#>   cell      value
#>   <gh_cell> <dbl>
#> 1 036565        2
```
