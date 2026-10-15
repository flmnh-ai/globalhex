# Changelog

## globalhex 0.0.0.9000

- Bundled DGGRID 9.03b source, compiled without GDAL at install time, so
  no separate DGGRID installation is needed. The package is now
  AGPL-3.0-or-later.
- [`cell_cover()`](https://flmnh-ai.github.io/globalhex/reference/cell_cover.md)
  clips with DGGRID’s AIGEN format and applies polygon holes in R,
  keeping cells on islands inside holes.
- Fixed automatic plot resolution failing (“No source cells are
  visible”) for wide regional datasets, such as North Atlantic storm
  tracks.
- Fixed
  [`raster_to_cell()`](https://flmnh-ai.github.io/globalhex/reference/raster_to_cell.md)
  failing for rasters narrower than 60 degrees that do not cross a
  multiple of 60 degrees longitude.
- [`point_to_cell()`](https://flmnh-ai.github.io/globalhex/reference/point_to_cell.md)
  recognizes a `long` column for longitude.
- New README with rendered examples, and three vignettes: getting
  started, plotting, and rasters and polygons.
- Added an IGEO7/Z7-first API over DGGRID 9.x.
- Added ISEA3H/Z3 selection and a partial dggridR compatibility
  fallback.
- Added conversion, boundary, neighbor, traversal, hierarchy, sf, and
  polygon fill helpers with H3-like snake-case names.
- Reworked cells as vctrs vectors supporting mixed resolutions.
- Separated grid identity from DGGRID backend configuration.
- Standardized cell operations on a `cell_` grammar and type-stable
  relation tibbles.
- Made the legacy dggridR fallback explicit and added classed cli
  errors.
- Deduplicated point, sequence-number, relation, and geometry requests
  before invoking their backends while preserving the original result
  order.
- Batched hierarchy and graph traversal work by resolution and search
  depth, including shared searches for repeated distance origins.
- Standardized optional-package checks with rlang’s package-checking
  API.
- Switched center extraction from GeoJSON to compact DGGRID text output
  and added bounded internal chunks for large point, center, boundary,
  and sequence-number requests.
- Added delayed cli progress for hierarchy, graph traversal, distance,
  and polygon-cover operations without adding a runtime dependency.
- Added
  [`cell_grid()`](https://flmnh-ai.github.io/globalhex/reference/cell_grid.md)
  and fast or backend-confirmed
  [`cell_is_valid()`](https://flmnh-ai.github.io/globalhex/reference/cell_is_valid.md)
  helpers.
- Added regression coverage for all 12 pentagons, seam-crossing
  antimeridian cells, polar cells, larger graph radii, and forced
  multi-chunk execution.
- Added a development-only `bench` harness excluded from package builds.
- Added lazy
  [`hex_data()`](https://flmnh-ai.github.io/globalhex/reference/hex_data.md)
  tables and a base
  [`plot()`](https://rspatial.github.io/terra/reference/plot.html)
  method that constructs geometry only after hierarchical aggregation.
- Added
  [`cell_aggregate()`](https://flmnh-ai.github.io/globalhex/reference/cell_aggregate.md)
  and viewport/device-aware
  [`plot_resolution()`](https://flmnh-ai.github.io/globalhex/reference/plot_resolution.md)
  with numeric, logical, and categorical aggregation semantics.
- Made parent lookup a local Z7/Z3 index operation, removing a DGGRID
  process from parent aggregation and level-of-detail selection.
- Added center-only viewport selection, antimeridian handling,
  projection after aggregation, fixed-resolution plotting, and a
  `lod = FALSE` escape hatch.
- Added 100 thousand, 1 million, and 10 million row plotting benchmarks
  and a naive fine-polygon comparison.
- Added
  [`cell_sample()`](https://flmnh-ai.github.io/globalhex/reference/cell_sample.md)
  for fast center-point extraction from `SpatRaster` layers without cell
  polygons.
- Added
  [`cell_extract()`](https://flmnh-ai.github.io/globalhex/reference/cell_extract.md)
  for exact raster-pixel coverage with area-weighted continuous defaults
  and categorical mode extraction.
- Added
  [`raster_to_cell()`](https://flmnh-ai.github.io/globalhex/reference/raster_to_cell.md)
  with edge-cell padding, projected-raster support, and 0-to-360
  longitude handling; all raster helpers return lazy `globalhex_data`
  objects.
- Made full-longitude raster conversion enumerate the bounded whole DGGS
  instead of sending globe-spanning polygons through DGGRID’s clipper.
- Added controllable
  [`cell_cover()`](https://flmnh-ai.github.io/globalhex/reference/cell_cover.md)
  edge densification and made long DGGRID failures safe and concise
  while retaining their full diagnostic text.
- Made raster conversion drop all-missing cells by default and made
  plotting ignore missing values before LOD selection, avoiding needless
  downsampling for sparse global rasters.
- Added `render = "auto"`, `"polygon"`, or `"raster"` plotting.
  Automatic mode rasterizes large display layers through optional
  `terra`, keeps explicit borders vector-based, and records the renderer
  on the returned data.
