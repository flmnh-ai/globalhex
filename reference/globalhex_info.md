# Report the local globalhex environment

globalhex runs a DGGRID executable compiled when the package is
installed. To use a different DGGRID build (version 9.0 or later), set
`options(globalhex.dggrid = "/path/to/dggrid")` or the `DGGRID_BIN` (or
`DGGRID`) environment variable. These take precedence over a `dggrid` on
the `PATH`, which in turn takes precedence over the bundled copy.

## Usage

``` r
globalhex_info()
```

## Value

A named list describing R, optional packages, and the DGGRID executable
in use.
