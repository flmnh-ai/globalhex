# AGENTS.md

Guidance for AI coding agents (and humans) working on globalhex.

## What this is

An experimental R package that wraps the DGGRID command-line program
(\>= 9.0) in a small, H3-shaped API. Default grid: IGEO7 with Z7
indexes; ISEA3H/Z3 is also supported, plus an opt-in legacy path through
dggridR. Cell IDs are DGGRID indexes, never H3 indexes.

## Layout

- `R/grid.R` –
  [`hex_grid()`](https://flmnh-ai.github.io/globalhex/reference/hex_grid.md),
  [`legacy_grid()`](https://flmnh-ai.github.io/globalhex/reference/legacy_grid.md),
  DGGRID discovery (`.find_dggrid()`),
  [`globalhex_info()`](https://flmnh-ai.github.io/globalhex/reference/globalhex_info.md)
- `R/cli.R` – builds DGGRID metafiles and runs the executable as a
  subprocess
- `R/cell-class.R` – the `globalhex_cell` vctrs class
- `R/convert.R`, `R/hierarchy.R`, `R/traversal.R` –
  point/center/boundary conversion, parent/children,
  neighbors/disk/ring/distance
- `R/data.R`, `R/plot.R` – lazy
  [`hex_data()`](https://flmnh-ai.github.io/globalhex/reference/hex_data.md)
  tables, aggregation, level-of-detail plotting
- `R/raster.R`, `R/sf.R` – terra/exactextractr and sf integration
- `R/compatibility.R` – legacy dggridR fallback
- `R/conditions.R` – `.abort()` and argument validators
- `tests/testthat/` – tests; `helper-engine.R` skips when DGGRID is
  missing
- `bench/` – development-only benchmarks (excluded from builds)
- `vignettes/` – getting started, plotting, rasters and polygons
- `inst/examples/` – runnable example scripts
- `src/dggrid/` – vendored, unmodified DGGRID 9.03b source (commit
  e9bb18a); do not edit
- `src/Makevars`, `src/install.libs.R` – compile DGGRID without GDAL and
  install it to `bin/`
- `work/` – local demo outputs; not part of the package

## Commands

``` sh
Rscript -e 'devtools::test()'       # run tests
Rscript -e 'devtools::document()'   # regenerate man/ and NAMESPACE
Rscript -e 'devtools::check()'      # full R CMD check
```

`devtools::load_all()`/`test()` compile `src/dggrid/dggrid` and use it
directly. The first build compiles ~140 C++ files and takes a minute or
two.

## Conventions

- Public operations use the `cell_` prefix; constructors use `hex_`.
  Keep the API small and H3-like in naming.
- Variable-size results are always tibbles that keep their source column
  (`origin`, `parent`); never switch return type based on input length.
- Coordinates are longitude first, then latitude.
- Raise errors with `.abort()` and a classed `globalhex_error_*`
  subclass, using cli formatting. Validate arguments with the helpers in
  `R/conditions.R`.
- Deduplicate inputs and batch by resolution before calling DGGRID;
  avoid one subprocess per cell. Restore original order on output.
- Long operations accept `progress = NULL/TRUE/FALSE` and use the
  internal `.progress_*` helpers.
- The bundled DGGRID has no GDAL: use only TEXT/GEOJSON/AIGEN/SHAPEFILE
  inputs and outputs in metafiles, never `GDAL` types.
- `sf`, `terra`, `exactextractr`, `dggridR` are Suggests only: guard
  with
  [`rlang::check_installed()`](https://rlang.r-lib.org/reference/is_installed.html).
- Internal helpers start with `.` and are documented with `@noRd`.
- `man/` and `NAMESPACE` are roxygen-generated; edit the roxygen
  comments, not the generated files.
- Add a `NEWS.md` bullet for user-visible changes.

## Implementation notes

- Vector inputs are deduplicated before calling DGGRID and restored to
  input order afterwards. Hierarchy and traversal batch by resolution
  and depth.
- Point, center, boundary, and sequence-number requests run in bounded
  chunks. Centers use DGGRID’s TEXT output; boundaries use GEOJSON.
- Parent lookup is a local string operation on Z7/Z3 IDs (no DGGRID
  call).
- Plotting picks a display level from cell centers, aggregates locally,
  and asks DGGRID for boundaries only for the final display cells.
  `render = "auto"` rasterizes at `raster_threshold` (20,000) cells when
  terra is available.
- [`raster_to_cell()`](https://flmnh-ai.github.io/globalhex/reference/raster_to_cell.md)
  pads DGGRID’s nucleus-based cover by one neighbor ring, then drops
  cells not intersecting the raster footprint. Full-longitude rasters
  use whole-grid generation instead of a clipping polygon.

## Open work

- Replace subprocess-per-operation calls with a persistent process or a
  native dgaplib bridge.
- Add fixtures for polygon covers spanning the antimeridian and holes at
  polar latitudes.
- Consider a bounded neighbor/center cache if benchmarks show repeated
  lookups dominate real workloads.
- Consider precomputed aggregation pyramids if interactive workloads
  outgrow the current LOD path.
- Set up a pkgdown site.

## Docs

`README.md` is generated from `README.Rmd`: edit the .Rmd and run
`devtools::build_readme()`. Longer explanations belong in `vignettes/`,
not the README. Vignettes must run quickly and guard optional packages
with `eval = requireNamespace(...)`.

## Licensing

The package is AGPL-3.0-or-later because it bundles DGGRID. Third-party
copyrights are listed in `inst/COPYRIGHTS` and `Authors@R`; update both
when upgrading or adding bundled code. To upgrade DGGRID, replace the
`lib/` and `apps/dggrid/` trees in `src/dggrid/` from a pinned upstream
commit, drop its CMake/Makefile files, and record the commit in
`inst/COPYRIGHTS` and README.
