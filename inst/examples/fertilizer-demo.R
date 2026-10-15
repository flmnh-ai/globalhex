# End-to-end demo: global raster -> IGEO7 cells -> map.
#
# Uses the NASA SEDAC "Global Fertilizer and Manure, Version 1: Phosphorus
# Fertilizer Application" GeoTIFF (free Earthdata login required). Set
# GLOBALHEX_FERTILIZER_RASTER to its path, or place it at
# ~/Downloads/PFertilizer_global_geotif/pfertilizer_global.tif.
#
# Writes cell data (.rds) and a PNG to GLOBALHEX_DEMO_DIR (default "work/").
# GLOBALHEX_DEMO_RESOLUTION defaults to 4; resolution 5 roughly matches the
# source raster's 0.5-degree pixel count.

if (file.exists("DESCRIPTION")) {
  devtools::load_all(".", quiet = TRUE)
} else {
  library(globalhex)
}

raster_path <- Sys.getenv(
  "GLOBALHEX_FERTILIZER_RASTER",
  unset = path.expand(
    "~/Downloads/PFertilizer_global_geotif/pfertilizer_global.tif"
  )
)
output_dir <- Sys.getenv("GLOBALHEX_DEMO_DIR", unset = "work")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
resolution <- as.integer(Sys.getenv("GLOBALHEX_DEMO_RESOLUTION", unset = "4"))
if (is.na(resolution) || resolution < 0L) {
  stop("GLOBALHEX_DEMO_RESOLUTION must be a non-negative integer.")
}
max_cells <- as.integer(Sys.getenv(
  "GLOBALHEX_DEMO_MAX_CELLS",
  unset = "200000"
))
output_path <- file.path(
  output_dir,
  sprintf("phosphorus-igeo7-res%d.png", resolution)
)
data_path <- file.path(
  output_dir,
  sprintf("phosphorus-igeo7-res%d.rds", resolution)
)

phosphorus <- terra::rast(raster_path)
names(phosphorus) <- "phosphorus"

conversion_time <- system.time({
  phosphorus_hex <- raster_to_cell(
    phosphorus,
    resolution = resolution,
    max_cells = max_cells,
    progress = FALSE
  )
})

phosphorus_hex$log_phosphorus <- log1p(phosphorus_hex$phosphorus)
saveRDS(phosphorus_hex, data_path)

grDevices::png(output_path, width = 1800, height = 950, res = 150)
graphics::par(mar = c(2.5, 2.5, 5, 1))
displayed <- plot(
  phosphorus_hex,
  value = "log_phosphorus",
  resolution = resolution,
  pal = function(n) grDevices::hcl.colors(n, "YlOrRd", rev = TRUE),
  main = paste(
    "Global phosphorus fertilizer application on IGEO7",
    sprintf(
      "log1p area-weighted mean; native resolution %d without display downsampling",
      resolution
    ),
    sep = "\n"
  )
)
grDevices::dev.off()

summary <- list(
  source = raster_path,
  source_dimensions = c(
    rows = terra::nrow(phosphorus),
    columns = terra::ncol(phosphorus),
    layers = terra::nlyr(phosphorus)
  ),
  source_resolution = terra::res(phosphorus),
  dggs = "IGEO7/Z7",
  extraction_resolution = resolution,
  cells = nrow(phosphorus_hex),
  non_missing_cells = sum(!is.na(phosphorus_hex$phosphorus)),
  value_range = range(phosphorus_hex$phosphorus, na.rm = TRUE),
  conversion_seconds = unname(conversion_time[["elapsed"]]),
  display_resolution = attr(displayed, "plot_resolution"),
  display_cells = nrow(displayed),
  display_renderer = attr(displayed, "plot_render"),
  plot = normalizePath(output_path),
  data = normalizePath(data_path)
)

print(summary)
