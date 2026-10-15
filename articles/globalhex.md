# Getting started with globalhex

globalhex works with a *discrete global grid*: a set of cells that
covers the whole Earth with no gaps or overlaps. This vignette
introduces grids, cells, and the functions that move between them.

``` r

library(globalhex)
```

## Grids

A grid is defined by
[`hex_grid()`](https://flmnh-ai.github.io/globalhex/reference/hex_grid.md).
The default, IGEO7, is an equal-area grid of hexagons in which each cell
has seven children at the next finer resolution.

``` r

grid <- hex_grid()
grid
#> <globalhex_grid>
#> system: IGEO7
#> index: Z7
#> orientation: 11.25, 58.28252559, 0
```

Every function that creates cells takes a `grid` argument that defaults
to
[`hex_grid()`](https://flmnh-ai.github.io/globalhex/reference/hex_grid.md),
so you rarely need to pass it explicitly. The alternative ISEA3H grid,
in which each cell has three children, is available as
`hex_grid("isea3h")`.

### Resolutions

Resolution 0 is the coarsest level. Each step finer divides every cell
into seven, so cells shrink quickly:

``` r

resolution <- 0:12
n_cells <- 10 * 7^resolution + 2
data.frame(
  resolution,
  n_cells = format(n_cells, big.mark = ",", scientific = FALSE),
  area_km2 = signif(510.1e6 / n_cells, 3)
)
#>    resolution         n_cells area_km2
#> 1           0              12 4.25e+07
#> 2           1              72 7.08e+06
#> 3           2             492 1.04e+06
#> 4           3           3,432 1.49e+05
#> 5           4          24,012 2.12e+04
#> 6           5         168,072 3.04e+03
#> 7           6       1,176,492 4.34e+02
#> 8           7       8,235,432 6.19e+01
#> 9           8      57,648,012 8.85e+00
#> 10          9     403,536,072 1.26e+00
#> 11         10   2,824,752,492 1.81e-01
#> 12         11  19,773,267,432 2.58e-02
#> 13         12 138,412,872,012 3.69e-03
```

Because the grid is equal-area, these areas hold everywhere on Earth,
from the equator to the poles.

The grid is built on an icosahedron, so 12 cells at every resolution are
pentagons rather than hexagons. That is why cell operations use the
`cell_` prefix rather than `hex_`: not every cell is a hexagon.
Pentagons have five neighbors instead of six, and globalhex handles them
like any other cell.

## Cells

[`point_to_cell()`](https://flmnh-ai.github.io/globalhex/reference/point_to_cell.md)
finds the cell containing a point. Coordinates are always longitude
first, then latitude:

``` r

gainesville <- point_to_cell(c(-82.32, 29.65), resolution = 7)
gainesville
#> <globalhex_cell[1]>
#> [1] 020050152
cell_resolution(gainesville)
#> [1] 7
```

It also accepts a matrix or data frame. Columns named `lon`/`lat` (or
`long`, `lng`, `longitude`, `x`, `latitude`, `y`) are matched by name;
otherwise the first two columns are used. With sf installed, sf `POINT`
objects work too.

``` r

cities <- data.frame(
  name = c("Gainesville", "Nairobi", "Reykjavik"),
  lat = c(29.65, -1.29, 64.15),
  lon = c(-82.32, 36.82, -21.94)
)
cities$cell <- point_to_cell(cities, resolution = 5)
cities
#>          name   lat    lon    cell
#> 1 Gainesville 29.65 -82.32 0200501
#> 2     Nairobi -1.29  36.82 0401421
#> 3   Reykjavik 64.15 -21.94 0041112
```

Cells are a vector type, so they sit happily in data frame columns, and
they remember which grid they belong to. Cells from different grids
cannot be combined by accident.

### Geometry

[`cell_center()`](https://flmnh-ai.github.io/globalhex/reference/cell_center.md)
returns the center of each cell, and
[`cell_boundary()`](https://flmnh-ai.github.io/globalhex/reference/cell_boundary.md)
its vertices:

``` r

cell_center(cities$cell)
#> # A tibble: 3 × 3
#>   cell        lon   lat
#>   <gh_cell> <dbl> <dbl>
#> 1 0200501   -82.2 29.7 
#> 2 0401421    36.9 -1.56
#> 3 0041112   -21.9 64.4
```

``` r

polygons <- sf::st_as_sf(cities$cell)
polygons
#> Simple feature collection with 3 features and 1 field
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -82.52929 ymin: -1.886798 xmax: 37.14544 ymax: 64.71727
#> Geodetic CRS:  WGS 84
#> # A tibble: 3 × 2
#>   cell                                                                  geometry
#>   <gh_cell>                                                        <POLYGON [°]>
#> 1 0200501   ((-81.90485 29.68215, -82.11736 29.96618, -82.43091 29.93892, -82.5…
#> 2 0401421   ((37.06223 -1.299545, 36.79428 -1.23296, 36.61043 -1.492471, 36.694…
#> 3 0041112   ((-21.58766 64.12927, -21.26621 64.41509, -21.59749 64.71051, -22.2…
```

## Neighborhoods

[`cell_neighbors()`](https://flmnh-ai.github.io/globalhex/reference/cell_neighbors.md)
returns the cells sharing an edge.
[`cell_disk()`](https://flmnh-ai.github.io/globalhex/reference/cell_disk.md)
returns all cells within `k` steps, and
[`cell_ring()`](https://flmnh-ai.github.io/globalhex/reference/cell_ring.md)
only those exactly `k` steps away:

``` r

cell_neighbors(gainesville)
#> # A tibble: 6 × 2
#>   origin    cell     
#>   <gh_cell> <gh_cell>
#> 1 020050152 020050156
#> 2 020050152 020050105
#> 3 020050152 020050101
#> 4 020050152 020050114
#> 5 020050152 020050153
#> 6 020050152 020050150
cell_disk(gainesville, k = 2)
#> # A tibble: 19 × 3
#>    origin    cell      distance
#>    <gh_cell> <gh_cell>    <int>
#>  1 020050152 020050152        0
#>  2 020050152 020050156        1
#>  3 020050152 020050105        1
#>  4 020050152 020050101        1
#>  5 020050152 020050114        1
#>  6 020050152 020050153        1
#>  7 020050152 020050150        1
#>  8 020050152 020050141        2
#>  9 020050152 020050143        2
#> 10 020050152 020050154        2
#> 11 020050152 020050104        2
#> 12 020050152 020050100        2
#> 13 020050152 020050103        2
#> 14 020050152 020050116        2
#> 15 020050152 020050110        2
#> 16 020050152 020050115        2
#> 17 020050152 020051466        2
#> 18 020050152 020050151        2
#> 19 020050152 020050155        2
```

Functions that can return several cells per input always return a tibble
with one row per result and a column recording which input it came from.
That holds for one input or many, so you never have to handle a list.

[`cell_distance()`](https://flmnh-ai.github.io/globalhex/reference/cell_distance.md)
counts the steps between two cells:

``` r

other <- point_to_cell(c(-82.0, 29.9), resolution = 7)
cell_distance(gainesville, other)
#> [1] 6
```

## Changing scale

Each cell has one parent at the next coarser resolution, and seven
children at the next finer one:

``` r

parent <- cell_parent(gainesville)
parent
#> <globalhex_cell[1]>
#> [1] 02005015
cell_children(parent)
#> # A tibble: 7 × 2
#>   parent    cell     
#>   <gh_cell> <gh_cell>
#> 1 02005015  020050150
#> 2 02005015  020050151
#> 3 02005015  020050152
#> 4 02005015  020050153
#> 5 02005015  020050154
#> 6 02005015  020050155
#> 7 02005015  020050156
cell_parent(gainesville, resolution = 3)
#> <globalhex_cell[1]>
#> [1] 02005
```

A cell’s ID begins with its parent’s ID, so a cell vector can mix
resolutions:

``` r

mixed <- c(parent, gainesville)
cell_resolution(mixed)
#> [1] 6 7
```

To summarize values from fine cells into coarse ones, use
[`cell_aggregate()`](https://flmnh-ai.github.io/globalhex/reference/cell_aggregate.md),
described in
[`vignette("plotting")`](https://flmnh-ai.github.io/globalhex/articles/plotting.md).

## Saving and restoring cells

A cell ID is a short string of digits. Store it as text, never as a
number, or leading zeros will be lost. After reading it back, attach the
grid again with
[`as_globalhex_cell()`](https://flmnh-ai.github.io/globalhex/reference/as_globalhex_cell.md):

``` r

path <- tempfile(fileext = ".csv")
write.csv(data.frame(cell = as.character(cities$cell)), path, row.names = FALSE)

restored <- read.csv(path, colClasses = "character")
restored$cell <- as_globalhex_cell(restored$cell, grid)
restored
#>      cell
#> 1 0200501
#> 2 0401421
#> 3 0041112
```

[`cell_is_valid()`](https://flmnh-ai.github.io/globalhex/reference/cell_is_valid.md)
checks that IDs read from elsewhere are well formed:

``` r

cell_is_valid(c("0200501", "0200509", "99"), grid)
#> [1]  TRUE FALSE FALSE
```

## Under the hood

globalhex calls a bundled copy of
[DGGRID](https://github.com/sahrk/DGGRID).
[`globalhex_info()`](https://flmnh-ai.github.io/globalhex/reference/globalhex_info.md)
reports which copy is in use and the versions of related packages. To
use your own DGGRID build instead, set the `globalhex.dggrid` option or
the `DGGRID_BIN` environment variable.

For grids created with the older
[dggridR](https://cran.r-project.org/package=dggridR) package,
[`legacy_grid()`](https://flmnh-ai.github.io/globalhex/reference/legacy_grid.md)
provides a limited compatibility path. It is only used when you ask for
it.
