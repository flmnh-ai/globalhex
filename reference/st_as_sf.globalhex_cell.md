# Convert cells to sf polygons

Cell boundaries are spherical polygons: DGGRID reports their vertices,
and the edges between them are great-circle arcs. That is exactly what
[`sf::st_area()`](https://r-spatial.github.io/sf/reference/geos_measures.html)
and other spherical (s2) operations expect, but a flat
longitude/latitude map draws straight lines between vertices, so cells
that cross the antimeridian (180 degrees longitude) would stretch across
the whole map and cells containing a pole would draw as twisted shapes.

## Usage

``` r
# S3 method for class 'globalhex_cell'
st_as_sf(x, wrap = TRUE, ...)
```

## Arguments

- x:

  A `globalhex_cell` vector.

- wrap:

  Whether to split antimeridian cells, close polar cells, and densify
  long edges for flat longitude/latitude use.

- ...:

  Passed to methods; currently unused.

## Value

An sf object in EPSG:4326 with one row and geometry per cell.

## Details

With `wrap = TRUE` (the default) the polygons are prepared for flat
longitude/latitude use:

- edges longer than one degree are densified along their great circles;

- cells crossing the antimeridian are split into a `MULTIPOLYGON` whose
  parts touch longitude -180 and 180;

- cells containing a pole are closed along the map edge at latitude 90
  or -90, so they draw as a polar cap.

Longitudes stay in \[-180, 180\] and spherical areas are unchanged. When
any cell is split, every geometry is returned as a `MULTIPOLYGON` so the
column has a single type. For a Pacific-centred map, use
[`sf::st_shift_longitude()`](https://r-spatial.github.io/sf/reference/st_shift_longitude.html)
on the result to move longitudes to \[0, 360\].

Use `wrap = FALSE` for the raw spherical polygons with one ring of
DGGRID vertices per cell, for example before projecting to a polar CRS.

## Examples

``` r
if (requireNamespace("sf", quietly = TRUE)) {
  seam <- point_to_cell(c(180, 10), 6)
  sf::st_geometry(sf::st_as_sf(seam))
  sf::st_geometry(sf::st_as_sf(seam, wrap = FALSE))
}
#> Geometry set for 1 feature 
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: -179.9898 ymin: 9.812935 xmax: 179.9192 ymax: 10.06704
#> Geodetic CRS:  WGS 84
#> POLYGON ((-179.9898 10, 179.916 10.06704, 179.8...
```
