# Define the explicit legacy dggridR fallback

This opt-in constructor quarantines the older sequence-number behavior.
Legacy cells support point, center, boundary, and sf conversion, but not
the modern hierarchy or neighbor operations.

## Usage

``` r
legacy_grid(resolution, pole_lon = 11.25, pole_lat = 58.28252559, azimuth = 0)
```

## Arguments

- resolution:

  ISEA3H resolution.

- pole_lon, pole_lat, azimuth:

  Orientation in degrees.

## Value

A `globalhex_legacy_grid` object.
