# Package index

## Locate

Move between coordinates and cells.

- [`point_to_cell()`](https://flmnh-ai.github.io/globalhex/reference/point_to_cell.md)
  : Convert points to cells
- [`cell_center()`](https://flmnh-ai.github.io/globalhex/reference/cell_center.md)
  : Return cell centers
- [`cell_boundary()`](https://flmnh-ai.github.io/globalhex/reference/cell_boundary.md)
  : Return cell boundary rings

## Neighborhoods

Find nearby cells and measure grid distance.

- [`cell_neighbors()`](https://flmnh-ai.github.io/globalhex/reference/cell_neighbors.md)
  : Return immediate cell neighbors
- [`cell_disk()`](https://flmnh-ai.github.io/globalhex/reference/cell_disk.md)
  : Return cells within grid distance k
- [`cell_ring()`](https://flmnh-ai.github.io/globalhex/reference/cell_ring.md)
  : Return cells at exactly grid distance k
- [`cell_distance()`](https://flmnh-ai.github.io/globalhex/reference/cell_distance.md)
  : Return shortest neighbor-graph distance

## Hierarchy

Move up and down resolutions.

- [`cell_parent()`](https://flmnh-ai.github.io/globalhex/reference/cell_parent.md)
  : Return cell ancestors
- [`cell_children()`](https://flmnh-ai.github.io/globalhex/reference/cell_children.md)
  : Return cell descendants
- [`cell_aggregate()`](https://flmnh-ai.github.io/globalhex/reference/cell_aggregate.md)
  : Aggregate values to hierarchical ancestors

## Mapping

Build lazy cell tables and draw them.

- [`hex_data()`](https://flmnh-ai.github.io/globalhex/reference/hex_data.md)
  : Construct lazily geometric global-hex data
- [`plot(`*`<globalhex_data>`*`)`](https://flmnh-ai.github.io/globalhex/reference/plot.globalhex_data.md)
  : Plot global-hex values with hierarchical level of detail
- [`plot_resolution()`](https://flmnh-ai.github.io/globalhex/reference/plot_resolution.md)
  : Choose a display resolution for global-hex data
- [`st_as_sf(`*`<globalhex_cell>`*`)`](https://flmnh-ai.github.io/globalhex/reference/st_as_sf.globalhex_cell.md)
  : Convert cells to sf polygons

## Rasters and polygons

Move raster and vector data onto cells.

- [`raster_to_cell()`](https://flmnh-ai.github.io/globalhex/reference/raster_to_cell.md)
  : Convert a raster footprint to global-hex data
- [`cell_extract()`](https://flmnh-ai.github.io/globalhex/reference/cell_extract.md)
  : Extract raster summaries into cells
- [`cell_sample()`](https://flmnh-ai.github.io/globalhex/reference/cell_sample.md)
  : Sample raster values at cell centers
- [`cell_cover()`](https://flmnh-ai.github.io/globalhex/reference/cell_cover.md)
  : Cover polygons with cells

## Grids and cells

Create grids and inspect cell vectors.

- [`hex_grid()`](https://flmnh-ai.github.io/globalhex/reference/hex_grid.md)
  : Define a global hexagonal grid
- [`as_globalhex_cell()`](https://flmnh-ai.github.io/globalhex/reference/as_globalhex_cell.md)
  : Construct a globalhex cell vector
- [`cell_resolution()`](https://flmnh-ai.github.io/globalhex/reference/cell_resolution.md)
  : Return cell resolution
- [`cell_grid()`](https://flmnh-ai.github.io/globalhex/reference/cell_grid.md)
  : Return the grid attached to cells
- [`cell_is_valid()`](https://flmnh-ai.github.io/globalhex/reference/cell_is_valid.md)
  : Check cell identifiers
- [`globalhex_info()`](https://flmnh-ai.github.io/globalhex/reference/globalhex_info.md)
  : Report the local globalhex environment
- [`globalhex`](https://flmnh-ai.github.io/globalhex/reference/globalhex-package.md)
  [`globalhex-package`](https://flmnh-ai.github.io/globalhex/reference/globalhex-package.md)
  : globalhex: Equal-area hierarchical global cells

## Legacy

Interoperate with dggridR and sequence numbers.

- [`legacy_grid()`](https://flmnh-ai.github.io/globalhex/reference/legacy_grid.md)
  : Define the explicit legacy dggridR fallback
- [`as_dggridR_dggs()`](https://flmnh-ai.github.io/globalhex/reference/as_dggridR_dggs.md)
  : Convert to a low-level dggridR grid
- [`as_seqnum()`](https://flmnh-ai.github.io/globalhex/reference/as_seqnum.md)
  : Convert hierarchical cells to sequence numbers
