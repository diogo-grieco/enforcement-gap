# =============================================================================
# ENFORCEMENT GAP MONITORING SYSTEM
# Build the municipal mesh (GeoJSON)
#
# Author: Diogo Grieco
#
# Purpose: fetch the IBGE municipal mesh via geobr, filter to the 772-
#          municipality panel, reproject, and export as GeoJSON for the
#          viz/ maps. Run once;
#          re-run only if the panel's municipality set changes.
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

MESH_RAW_PATH <- "data/data_ibge/malha_772_amazonia_legal.geojson"

# -----------------------------------------------------------------------------
#### 2-6. Fetch, filter, reproject, trim, export — SKIPPED if the unsimplified
####       772-polygon file already exists on disk (e.g. left over from
####       filtering the panel from 805 to 772: same geometry, same 772
####       geocodes, no need to re-hit geobr/IBGE for it). Delete
####       MESH_RAW_PATH and re-run this script if you ever need a genuine
####       refetch (e.g. the panel's municipality set changes again).
# -----------------------------------------------------------------------------

if (file.exists(MESH_RAW_PATH)) {

  message("Found existing ", MESH_RAW_PATH, " — reusing it, skipping geobr fetch.")
  mesh_export <- st_read(MESH_RAW_PATH, quiet = TRUE) %>%
    mutate(code_muni = as.character(code_muni))

  stopifnot(
    "mesh_export (reused): polygon count != 772" = nrow(mesh_export) == 772,
    "mesh_export (reused): geocode mismatch against ranking" =
      length(setdiff(panel_geocodes, mesh_export$code_muni)) == 0
  )

} else {

  library(geobr)

  # ---------------------------------------------------------------------------
  #### 2. Check available years and download the whole-of-Brazil municipal mesh
  # ---------------------------------------------------------------------------
  # geobr::read_municipality() is an official wrapper over IBGE's Malha
  # Municipal Digital. The code_muni column comes out in the same 7-digit
  # format as your geocode_ibge — you can join directly, no need to match
  # by name.
  #
  # simplified = TRUE (default) already applies st_simplify preserving
  # topology — good enough for a map visualization. For any real spatial
  # analysis (not the case here) you'd want simplified = FALSE.

  # Run this line first to check whether 2022 is available in your installed
  # geobr; if not, use the most recent available year:
  # geobr::list_geobr() |> dplyr::filter(grepl("unicipal", geography))

  brazil_mesh <- read_municipality(code_muni = "all", year = 2022, simplified = TRUE)

  # Check the column names — they can vary slightly between package versions
  # (e.g. name_muni vs. nm_mun):
  names(brazil_mesh)

  # ---------------------------------------------------------------------------
  #### 3. Filter to the panel's 772 municipalities — join by geocode, with checkpoint
  # ---------------------------------------------------------------------------
  panel_mesh <- brazil_mesh %>%
    filter(code_muni %in% panel_geocodes)

  missing_from_mesh <- setdiff(panel_geocodes, panel_mesh$code_muni)

  stopifnot(
    "panel_mesh: ranking geocodes with no matching polygon" =
      length(missing_from_mesh) == 0,
    "panel_mesh: polygon count != 772" =
      nrow(panel_mesh) == 772
  )

  # ---------------------------------------------------------------------------
  #### 4. Reproject to WGS84 (EPSG:4326)
  # ---------------------------------------------------------------------------
  # geobr delivers in SIRGAS 2000 (EPSG:4674) — IBGE's official datum.
  # GeoJSON (RFC 7946) and Azure Maps expect WGS84. The numeric difference
  # between the two datums is small in Brazil, but the correct fix is
  # st_transform(), not just writing it out as if it were already WGS84.

  panel_mesh_wgs84 <- st_transform(panel_mesh, crs = 4326)

  # ---------------------------------------------------------------------------
  #### 5. Trim columns before exporting
  # ---------------------------------------------------------------------------
  # The join with the ranking/panel only needs the key (code_muni). Any extra
  # attribute is dead weight in the file — the tooltips/labels use the columns
  # from the parquet (egs_ranking), not the GeoJSON's properties.

  mesh_export <- panel_mesh_wgs84 %>%
    mutate(code_muni = as.character(as.integer(code_muni))) %>%  # geocode_ibge in
      # the parquet is text (it's an identifier, not a number to compute with);
      # keeping code_muni as text here too guarantees the join key matches on
      # both sides, regardless of what eventually reads this GeoJSON.
    select(code_muni, name_muni)   # adjust name_muni if the real column name differs

  # ---------------------------------------------------------------------------
  #### 6. Export GeoJSON
  # ---------------------------------------------------------------------------
  st_write(
    mesh_export,
    MESH_RAW_PATH,
    driver = "GeoJSON",
    delete_dsn = TRUE
  )

  cat("File size (MB):", file.info(MESH_RAW_PATH)$size / 1e6, "\n")
}

# -----------------------------------------------------------------------------
#### 7. Simplify further — this is the file viz/00_setup.R actually reads
# -----------------------------------------------------------------------------
# Azure Maps' own documentation recommends mapshaper with the Visvalingam
# algorithm for large reference layers. In R that's rmapshaper, a wrapper
# around the same mapshaper. FILE_MESH in 00_setup.R points at the
# _simplificada output below, not at the file from step 6 — this step is
# not optional for the viz/ suite to run; it always executes as part of a
# full source() of this script (install rmapshaper once if missing).

if (!requireNamespace("rmapshaper", quietly = TRUE)) {
  install.packages("rmapshaper")
}
light_mesh <- rmapshaper::ms_simplify(mesh_export, keep = 0.10, keep_shapes = TRUE)
st_write(light_mesh, "data/data_ibge/malha_772_amazonia_legal_simplificada.geojson",
         driver = "GeoJSON", delete_dsn = TRUE)

stopifnot(
  "light_mesh: polygon count != 772" = nrow(light_mesh) == 772
)

cat("Simplified file size (MB):",
    file.info("data/data_ibge/malha_772_amazonia_legal_simplificada.geojson")$size / 1e6, "\n")
