# AGENTS.md

Guidance for AI coding agents (and humans) working on globalhex.

## What this is

An experimental R package that wraps the DGGRID command-line program (>= 9.0)
in a small, H3-shaped API. Default grid: IGEO7 with Z7 indexes; ISEA3H/Z3 is
also supported, plus an opt-in legacy path through dggridR. Cell IDs are DGGRID
indexes, never H3 indexes.

## Layout

- `R/grid.R` – `hex_grid()`, `legacy_grid()`, DGGRID discovery (`.find_dggrid()`), `globalhex_info()`
- `R/cli.R` – builds DGGRID metafiles and runs the executable as a subprocess
- `R/cell-class.R` – the `globalhex_cell` vctrs class
- `R/convert.R`, `R/hierarchy.R`, `R/traversal.R` – point/center/boundary conversion, parent/children, neighbors/disk/ring/distance
- `R/data.R`, `R/plot.R` – lazy `hex_data()` tables, aggregation, level-of-detail plotting
- `R/raster.R`, `R/sf.R` – terra/exactextractr and sf integration
- `R/compatibility.R` – legacy dggridR fallback
- `R/conditions.R` – `.abort()` and argument validators
- `tests/testthat/` – tests; `helper-engine.R` skips when DGGRID is missing
- `bench/` – development-only benchmarks (excluded from builds)
- `src/dggrid/` – vendored, unmodified DGGRID 9.03b source (commit e9bb18a); do not edit
- `src/Makevars`, `src/install.libs.R` – compile DGGRID without GDAL and install it to `bin/`
- `work/` – local demo outputs; not part of the package

## Commands

```sh
Rscript -e 'devtools::test()'       # run tests
Rscript -e 'devtools::document()'   # regenerate man/ and NAMESPACE
Rscript -e 'devtools::check()'      # full R CMD check
```

`devtools::load_all()`/`test()` compile `src/dggrid/dggrid` and use it directly.
The first build compiles ~140 C++ files and takes a minute or two.

## Conventions

- Public operations use the `cell_` prefix; constructors use `hex_`. Keep the
  API small and H3-like in naming.
- Variable-size results are always tibbles that keep their source column
  (`origin`, `parent`); never switch return type based on input length.
- Coordinates are longitude first, then latitude.
- Raise errors with `.abort()` and a classed `globalhex_error_*` subclass, using
  cli formatting. Validate arguments with the helpers in `R/conditions.R`.
- Deduplicate inputs and batch by resolution before calling DGGRID; avoid one
  subprocess per cell. Restore original order on output.
- Long operations accept `progress = NULL/TRUE/FALSE` and use the internal
  `.progress_*` helpers.
- The bundled DGGRID has no GDAL: use only TEXT/GEOJSON/AIGEN/SHAPEFILE
  inputs and outputs in metafiles, never `GDAL` types.
- `sf`, `terra`, `exactextractr`, `dggridR` are Suggests only: guard with
  `rlang::check_installed()`.
- Internal helpers start with `.` and are documented with `@noRd`.
- `man/` and `NAMESPACE` are roxygen-generated; edit the roxygen comments, not
  the generated files.
- Add a `NEWS.md` bullet for user-visible changes.

## Licensing

The package is AGPL-3.0-or-later because it bundles DGGRID. Third-party
copyrights are listed in `inst/COPYRIGHTS` and `Authors@R`; update both when
upgrading or adding bundled code. To upgrade DGGRID, replace the `lib/` and
`apps/dggrid/` trees in `src/dggrid/` from a pinned upstream commit, drop its
CMake/Makefile files, and record the commit in `inst/COPYRIGHTS` and README.
