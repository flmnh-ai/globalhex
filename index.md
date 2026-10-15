# globalhex

globalhex divides the whole Earth into **equal-area hexagons** and gives
you tidy tools to work with them. Every cell at a given resolution
covers the same area, anywhere on the globe, so counts and averages are
directly comparable, unlike latitude/longitude grids, whose cells shrink
toward the poles. Cells nest into coarser parents, so you can summarize
the same data at many scales.

If you have used [H3](https://h3geo.org), the function names will feel
familiar. Under the hood, globalhex uses
[DGGRID](https://github.com/sahrk/DGGRID)’s IGEO7 grid, which is
equal-area where H3 is not.

## Installation

``` r

install.packages(
  "globalhex",
  repos = c("https://flmnh-ai.r-universe.dev", "https://cloud.r-project.org")
)
```

## Example

Find the cell containing a point, then explore around it:

``` r

library(globalhex)

gainesville <- point_to_cell(c(-82.32, 29.65), resolution = 7)
gainesville
#> <globalhex_cell[1]>
#> [1] 020050152

cell_center(gainesville)
#> # A tibble: 1 x 3
#>   cell        lon   lat
#>   <gh_cell> <dbl> <dbl>
#> 1 020050152 -82.4  29.6

cell_neighbors(gainesville)
#> # A tibble: 6 x 2
#>   origin    cell     
#>   <gh_cell> <gh_cell>
#> 1 020050152 020050156
#> 2 020050152 020050105
#> 3 020050152 020050101
#> 4 020050152 020050114
#> 5 020050152 020050153
#> 6 020050152 020050150

cell_parent(gainesville)
#> <globalhex_cell[1]>
#> [1] 02005015
```

Results are tibbles, so they work with dplyr and the rest of the
tidyverse.

Binning points is one call. Here are about 20,000 Atlantic storm
observations from
[`dplyr::storms`](https://dplyr.tidyverse.org/reference/storms.html),
counted in cells:

``` r

storms <- dplyr::storms
cells <- point_to_cell(storms[c("long", "lat")], resolution = 6)
counts <- hex_data(cells, observations = 1L)

plot(counts, fun = sum, resolution = 4, border = NA, reset = FALSE)

# Add coastlines for context
world <- sf::st_as_sf(maps::map("world", plot = FALSE, fill = TRUE))
plot(sf::st_geometry(world), add = TRUE, border = "grey40", lwd = 0.4)
```

![Map of Atlantic storm observation counts in equal-area hexagons,
highest in the Gulf of Mexico and
Caribbean.](reference/figures/README-storms-1.png)

[`hex_data()`](https://flmnh-ai.github.io/globalhex/reference/hex_data.md)
keeps your data as cell IDs. Hexagon polygons are only built for what is
drawn, after values are summed up to the display resolution, so plotting
millions of cells stays fast.

## What you can do

- **Locate:**
  [`point_to_cell()`](https://flmnh-ai.github.io/globalhex/reference/point_to_cell.md),
  [`cell_center()`](https://flmnh-ai.github.io/globalhex/reference/cell_center.md),
  [`cell_boundary()`](https://flmnh-ai.github.io/globalhex/reference/cell_boundary.md)
- **Explore neighborhoods:**
  [`cell_neighbors()`](https://flmnh-ai.github.io/globalhex/reference/cell_neighbors.md),
  [`cell_disk()`](https://flmnh-ai.github.io/globalhex/reference/cell_disk.md),
  [`cell_ring()`](https://flmnh-ai.github.io/globalhex/reference/cell_ring.md),
  [`cell_distance()`](https://flmnh-ai.github.io/globalhex/reference/cell_distance.md)
- **Change scale:**
  [`cell_parent()`](https://flmnh-ai.github.io/globalhex/reference/cell_parent.md),
  [`cell_children()`](https://flmnh-ai.github.io/globalhex/reference/cell_children.md),
  [`cell_aggregate()`](https://flmnh-ai.github.io/globalhex/reference/cell_aggregate.md)
- **Map:**
  [`hex_data()`](https://flmnh-ai.github.io/globalhex/reference/hex_data.md)
  with [`plot()`](https://rdrr.io/r/graphics/plot.default.html),
  [`sf::st_as_sf()`](https://r-spatial.github.io/sf/reference/st_as_sf.html)
  for polygons
- **Bring in other data:**
  [`cell_cover()`](https://flmnh-ai.github.io/globalhex/reference/cell_cover.md)
  for polygons;
  [`raster_to_cell()`](https://flmnh-ai.github.io/globalhex/reference/raster_to_cell.md),
  [`cell_extract()`](https://flmnh-ai.github.io/globalhex/reference/cell_extract.md),
  and
  [`cell_sample()`](https://flmnh-ai.github.io/globalhex/reference/cell_sample.md)
  for rasters

## Learn more

Full documentation lives at <https://flmnh-ai.github.io/globalhex/>.

- [`vignette("globalhex")`](https://flmnh-ai.github.io/globalhex/articles/globalhex.md):
  grids, cells, resolutions, and saving cells
- [`vignette("plotting")`](https://flmnh-ai.github.io/globalhex/articles/plotting.md):
  mapping large datasets
- [`vignette("rasters-and-polygons")`](https://flmnh-ai.github.io/globalhex/articles/rasters-and-polygons.md):
  moving raster and vector data onto cells

## Related work

- [DGGRID](https://github.com/sahrk/DGGRID), by Kevin Sahr, generates
  the grids. globalhex bundles a copy, so there is nothing else to
  install.
- [dggridR](https://cran.r-project.org/package=dggridR) wraps an older
  DGGRID without the IGEO7 grid.
- [h3jsr](https://cran.r-project.org/package=h3jsr) provides Uber’s H3
  grid in R.

globalhex is not affiliated with DGGRID, dggridR, or H3. It is licensed
under AGPL-3.0-or-later because it bundles DGGRID.
