# globalhex benchmarks

The benchmark harness is intentionally excluded from package builds. Install
the package locally, install the suggested `bench` package, and run:

```sh
Rscript bench/bench-core.R
Rscript bench/bench-plot-lod.R
```

The script measures point conversion, text center extraction, immediate
children, batched radius-two disks, and repeated graph-distance searches at
several vector sizes. Results are machine- and DGGRID-build-specific, so they
are printed rather than committed as performance promises.

The plotting benchmark runs 100,000 and 1,000,000 source rows by default. Its
10,000,000-row pass is intentionally opt-in because of memory use:

```sh
GLOBALHEX_BENCH_LARGE=true Rscript bench/bench-plot-lod.R
```

See `results-2026-09-06.md` for one recorded development run, including a
100,000-cell naive-polygon comparison and the measurements used to choose the
automatic polygon-to-raster crossover.
