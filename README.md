# globalhex

globalhex is an experimental R package providing a tidy, H3-shaped API over
modern DGGRID. It defaults to the equal-area IGEO7 grid with Z7 indexes and
also supports ISEA3H/Z3.

**Status:** early prototype. The API may change without notice, and the package
has only been tested on macOS arm64.

globalhex is not affiliated with DGGRID, dggridR, or Uber H3. Its IDs are
DGGRID indexes, not H3 indexes.


## Why functions use `cell_`, not `hex_`

The grid constructor is `hex_grid()` because the package models global
hexagonal grids. Operations use the `cell_` prefix because indexed grids also
contain 12 unavoidable pentagons. “Cell” is both technically correct and
consistent with H3 vocabulary.

The resulting grammar is deliberately small:

- `hex_grid()` defines spatial identity;
- `point_to_cell()` encodes coordinates;
- `cell_center()` and `cell_boundary()` return geometry;
- `cell_neighbors()`, `cell_disk()`, and `cell_ring()` describe adjacency;
- `cell_parent()` and `cell_children()` traverse the hierarchy;
- `cell_distance()` measures graph distance;
- `cell_cover()` fills a polygon region;
- `hex_data()` keeps cell values geometry-free until they are needed;
- `cell_aggregate()` and `plot_resolution()` provide hierarchical plotting;
- `cell_sample()` and `cell_extract()` transfer raster values to cells;
- `raster_to_cell()` covers and summarizes a raster in one operation;
- `cell_resolution()` and `cell_grid()` inspect cell metadata;
- `cell_is_valid()` checks stored or imported identifiers.

## Installation

```r
install.packages(
  "globalhex",
  repos = c("https://flmnh-ai.r-universe.dev", "https://cloud.r-project.org")
)
```

That's it. r-universe provides ready-built packages for Windows, macOS, and
Linux, so no compiler or extra software is needed. globalhex includes its own
copy of DGGRID 9, which older DGGRID builds (including the one inside dggridR)
cannot replace because they lack IGEO7/Z7.

To install the development version from GitHub instead, you need a C++
compiler (Rtools on Windows, Xcode Command Line Tools on macOS):

```r
remotes::install_github("flmnh-ai/globalhex")
```

Check the installation with `globalhex::globalhex_info()`.

## Quick start

```r
library(globalhex)

grid <- hex_grid("igeo7")
cell <- point_to_cell(c(-73.9857, 40.7484), resolution = 9, grid = grid)

cell_resolution(cell)
cell_center(cell)
cell_boundary(cell)

neighbors <- cell_neighbors(cell)
disk <- cell_disk(cell, k = 2)
ring <- cell_ring(cell, k = 2)
cell_distance(cell, neighbors$cell[1])

parent <- cell_parent(cell)
children <- cell_children(parent)

cell_grid(cell)
cell_is_valid(cell)
```

Coordinates always use longitude before latitude. Data frames with `lon` and
`lat` columns and sf POINT objects avoid positional ambiguity.

## Type-stable relationship tables

Variable-size operations always return tibbles retaining their source:

```r
cell_neighbors(cell)
#> # A tibble with origin and cell columns

cell_children(parent)
#> # A tibble with parent and cell columns

cell_disk(cell, 2)
#> # A tibble with origin, cell, and exact distance columns
```

This behavior is identical for one or many inputs; no function switches from a
vector to a list based on input length.

## Cell vectors

`globalhex_cell` is a vctrs vector. It works as a tibble column, preserves grid
metadata under slicing and concatenation, refuses to combine incompatible
grids, and may contain mixed resolutions:

```r
mixed <- vctrs::vec_c(cell_parent(cell), cell)
cell_resolution(mixed)
```

Grid metadata contains spatial identity only. Resolution is derived from each
cell ID, while the DGGRID executable is discovered independently. After CSV or
database storage, restore metadata explicitly:

```r
restored <- as_globalhex_cell(read.csv("cells.csv")$cell, grid)
```

## Fast hierarchical plotting

Keep large DGGS datasets as cell IDs plus attributes. `hex_data()` does not
construct polygons:

```r
x <- hex_data(cells, temperature = values)

plot(x)                                      # automatic viewport-aware detail
plot(x, resolution = 9)                     # fixed display resolution
plot(x, max_cells = 50e3)                   # explicit display-cell budget
plot(x, extent = c(-85, -79, 24, 32))       # xmin, xmax, ymin, ymax
plot(x, xlim = c(-85, -79), ylim = c(24, 32))
plot(x, crs = 3857)                         # project after aggregation
plot(x, lod = FALSE)                        # native-resolution escape hatch
plot(x, render = "polygon")                 # exact vector paths
plot(x, render = "raster")                  # compact bitmap layer
```

The plotting path chooses visible ancestors using compact cell centers,
aggregates values locally, and asks DGGRID for boundaries only for the final
display cells. Numeric values use the mean by default, logical values use a
majority rule, and categorical values use the mode. Counts and other additive
quantities should request `fun = sum` explicitly.

`render = "auto"` is the default. With `terra` available it rasterizes displays
of 20,000 cells or more; smaller displays remain vector polygons. Set
`raster_threshold` to tune the crossover. Requesting a visible `border` keeps
automatic mode vector-based, because raster layers do not retain individual
cell outlines. Raster mode uses the current device pixel dimensions (or
`device_size`) and discards its temporary polygon geometry after rendering,
which keeps PDF/SVG output compact and avoids sending thousands of separate
paths to the graphics device.

`extent`, `xlim`, and `ylim` are longitude/latitude limits evaluated before
projection. Use an extent whose `xmin` is greater than its `xmax`, such as
`c(170, -170, -10, 10)`, for a viewport crossing the antimeridian.

## Raster to DGGS

The raster helpers accept modern `terra::SpatRaster` objects and return lazy
`globalhex_data`, not millions of retained polygons:

```r
elevation <- terra::rast("elevation.tif")

# Cover the raster and calculate exact summaries for intersecting cells.
elevation_hex <- raster_to_cell(elevation, resolution = 9)

# Extract into cells you already have.
exact <- cell_extract(cells, elevation)

# Sample at cell centers without constructing cell polygons.
quick <- cell_sample(cells, elevation)

plot(elevation_hex, value = "elevation")
```

The exact default is an area-weighted mean for continuous layers and a
coverage-weighted mode for categorical `terra` layers. This matters for
longitude/latitude rasters, whose pixels have different physical areas. Use
`weights = NULL` for coverage-fraction weighting alone, or select explicit
`exactextractr` summaries such as `fun = c("mean", "min", "max")`. Explicit
weighted summaries can use `weights = "area"` or a compatible weighting
raster.

`raster_to_cell()` pads nucleus-based DGGRID coverage by one neighbor ring and
then removes cells that do not intersect the raster extent. Projected rasters
and the common 0-to-360 longitude convention are handled before extraction.
Full-longitude rasters use bounded whole-grid generation instead of passing an
invalid globe-spanning clipping polygon to DGGRID.
Cells with no extracted data are dropped by default (`drop_na = FALSE` retains
the complete raster footprint). Plotting likewise excludes missing values
before automatic LOD selection when `na.rm = TRUE`.
`terra`, `exactextractr`, and `sf` remain optional dependencies. Plotting needs
`sf`; automatic plotting simply stays in polygon mode when `terra` is absent.

The `inst/examples/fertilizer-demo.R` script exercises the entire path with the
NASA SEDAC global phosphorus-fertilizer application raster, which is not
included here. Download it from SEDAC (free Earthdata login required) and set
`GLOBALHEX_FERTILIZER_RASTER` to the GeoTIFF path, or place it at
`~/Downloads/PFertilizer_global_geotif/pfertilizer_global.tif`. It writes the reusable
cell data and PNG into `work/`, which is excluded from package builds. It uses
native resolution 4 by default; set `GLOBALHEX_DEMO_RESOLUTION=5` for a grid
whose cell count is close to the source raster's 0.5-degree pixel count.

## sf integration

```r
library(sf)

polygons <- st_as_sf(cell_disk(cell, 1)$cell)
region <- st_read("my-region.geojson", quiet = TRUE)
covered_cells <- cell_cover(region, resolution = 9, grid = grid)
```

DGGRID's clipping selects cells by cell nucleus. Large regions at fine
resolution can generate many cells; use `max_cells` as a guard.

Long hierarchy, traversal, distance, and covering operations show delayed
progress in interactive sessions. Set `progress = FALSE` for guaranteed quiet
operation or `progress = TRUE` to request progress explicitly.

## ISEA3H/Z3 and explicit legacy support

```r
z3 <- hex_grid("isea3h")
z3_cell <- point_to_cell(c(-73.9857, 40.7484), 12, z3)
```

The older dggridR path never activates silently. It is opt-in and limited to
ISEA3H point, center, boundary, and sf operations:

```r
legacy <- legacy_grid(resolution = 12)
legacy_cell <- point_to_cell(c(-73.9857, 40.7484), grid = legacy)
```

## DGGRID backend

globalhex compiles the DGGRID 9.03b source in `src/dggrid/` into a command-line
program when the package is installed, and runs it as a subprocess. It is built
without GDAL, so it needs no system libraries. To use a different DGGRID
executable, set the `globalhex.dggrid` option or the `DGGRID_BIN` (or `DGGRID`)
environment variable. Those take precedence over a `dggrid` on `PATH`, which
in turn takes precedence over the bundled copy.

```r
options(globalhex.dggrid = "/path/to/dggrid")
globalhex_info()
```

Vector inputs are deduplicated before backend work and restored to their
original order afterward. Hierarchy and graph operations also batch cells by
resolution and traversal depth, so supplying a vector does not launch one
DGGRID process per cell. Point, center, boundary, and sequence-number requests
are split into bounded internal chunks for predictable memory use. Cell
centers use DGGRID's compact text output rather than GeoJSON.

## Tested configuration

Tested on macOS arm64 with R 4.4.2, dggridR 3.1.1, sf 1.1-0, and the bundled
DGGRID 9.03b (commit `e9bb18a`, which reports itself as DGGRID 9.0b).

## Development benchmarks

The development-only benchmark harness covers vector conversion, centers,
hierarchy, disks, distances, hierarchical plotting, and a naive fine-polygon
comparison:

```sh
Rscript bench/bench-core.R
Rscript bench/bench-plot-lod.R
```

`bench` is suggested only for running that script; it is not a runtime
dependency and the benchmark directory is excluded from package builds. The
recorded 100 thousand, 1 million, and 10 million row results are in
`bench/results-2026-09-06.md`; the largest case is opt-in when rerunning.

## Remaining work

- Replace subprocess-per-operation work with a persistent process or native
  dgaplib bridge.
- Extend geographic fixtures to polygon covers spanning the antimeridian and
  holes at polar latitudes.
- Consider a bounded neighbor/center cache only if benchmarks show repeated
  lookups dominate real workloads.
- Consider a bitmap renderer and precomputed aggregation pyramids if interactive
  workloads outgrow the current polygon LOD path.
- Add a full vignette once the API settles.

## License

globalhex is licensed under AGPL-3.0-or-later because it bundles DGGRID
(Kevin Sahr, AGPL-3.0-or-later), which in turn includes MIT-licensed shapelib
and proj4lib code. See `inst/COPYRIGHTS`.

## Upstream references

- [DGGRID source and manual](https://github.com/sahrk/DGGRID)
- [DGGRID changelog](https://github.com/sahrk/DGGRID/blob/master/CHANGELOG.md)
- [dggridR on CRAN](https://cran.r-project.org/package=dggridR)
