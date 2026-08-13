# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Build the municipal mesh (GeoJSON)
#
# Author: Diogo Grieco
#
# Purpose: fetch the IBGE municipal mesh via geobr, filter to the 772-
#          municipality panel, reproject to WGS84, and export the simplified
#          GeoJSON that viz/00_setup.R reads. Outside the source() chain: run
#          standalone, and only if the panel's municipality set changes.
# =============================================================================

library(sf)
library(dplyr)
library(arrow)

ranking <- arrow::read_parquet("output/parquets/egs_ranking.parquet")
panel_geocodes <- ranking$geocode_ibge

stopifnot(
  "expected 772 unique geocodes in the ranking" =
    length(unique(panel_geocodes)) == 772
)

MESH_RAW_PATH   <- "data/data_ibge/malha_772_amazonia_legal.geojson"
MESH_LIGHT_PATH <-
  "data/data_ibge/malha_772_amazonia_legal_simplificada.geojson"

# -----------------------------------------------------------------------------
#### Fetch, filter, reproject, export
# -----------------------------------------------------------------------------
# Skipped if the unsimplified 772-polygon file is already on disk. Delete
# MESH_RAW_PATH to force a genuine refetch from geobr/IBGE.

if (file.exists(MESH_RAW_PATH)) {

  message("Found existing ", MESH_RAW_PATH,
          ", reusing it, skipping geobr fetch.")
  mesh_export <- st_read(MESH_RAW_PATH, quiet = TRUE) %>%
    mutate(code_muni = as.character(code_muni))

  stopifnot(
    "mesh_export (reused): polygon count != 772" = nrow(mesh_export) == 772,
    "mesh_export (reused): geocode mismatch against ranking" =
      length(setdiff(panel_geocodes, mesh_export$code_muni)) == 0
  )

} else {

  library(geobr)

  brazil_mesh <- read_municipality(code_muni = "all", year = 2022,
                                   simplified = TRUE)

  panel_mesh <- brazil_mesh %>%
    filter(code_muni %in% panel_geocodes)

  missing_from_mesh <- setdiff(panel_geocodes, panel_mesh$code_muni)

  stopifnot(
    "panel_mesh: ranking geocodes with no matching polygon" =
      length(missing_from_mesh) == 0,
    "panel_mesh: polygon count != 772" =
      nrow(panel_mesh) == 772
  )

  # geobr delivers SIRGAS 2000 (EPSG:4674); GeoJSON expects WGS84
  panel_mesh_wgs84 <- st_transform(panel_mesh, crs = 4326)

  mesh_export <- panel_mesh_wgs84 %>%
    mutate(code_muni = as.character(as.integer(code_muni))) %>%
    select(code_muni, name_muni)

  st_write(
    mesh_export,
    MESH_RAW_PATH,
    driver = "GeoJSON",
    delete_dsn = TRUE
  )

  cat("File size (MB):", file.info(MESH_RAW_PATH)$size / 1e6, "\n")
}

# -----------------------------------------------------------------------------
#### Simplify: this is the file viz/00_setup.R reads
# -----------------------------------------------------------------------------
# rmapshaper wraps mapshaper's Visvalingam simplification. Runs after either
# branch above: FILE_MESH in 00_setup.R points here, not at MESH_RAW_PATH.

light_mesh <- rmapshaper::ms_simplify(mesh_export, keep = 0.10,
                                      keep_shapes = TRUE)
st_write(light_mesh, MESH_LIGHT_PATH, driver = "GeoJSON", delete_dsn = TRUE)

stopifnot(
  "light_mesh: polygon count != 772" = nrow(light_mesh) == 772
)

cat("Simplified file size (MB):", file.info(MESH_LIGHT_PATH)$size / 1e6, "\n")
