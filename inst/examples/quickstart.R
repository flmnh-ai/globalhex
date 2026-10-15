library(globalhex)

grid <- hex_grid("igeo7")
cell <- point_to_cell(c(-73.9857, 40.7484), 5, grid)

print(cell)
print(cell_center(cell))
print(cell_neighbors(cell))
print(cell_parent(cell))
nearby <- cell_disk(cell, 2)
print(nearby)

if (requireNamespace("sf", quietly = TRUE)) {
  plot(sf::st_as_sf(nearby$cell)["cell"])

  values <- hex_data(nearby$cell, value = seq_len(nrow(nearby)))
  plot(values)
}
