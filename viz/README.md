# EGMS visualization suite (R)

Static and animated visuals for the Enforcement Gap Monitoring System, built
on the pipeline exports. Each script starts with `source("viz/00_setup.R")`,
which declares paths, integrity checkpoints, the shared palette/theme, and
loads the feeds with `stopifnot()` guards, in the style of the style of
`exploration/exploring_script.R`.

Run everything from the **project root** (open `project2.Rproj`).

There are three `00_*` files, and they are not interchangeable: each covers
a different kind of "runs before the numbered items":

| File | Sourced by | When |
|---|---|---|
| `00_setup.R` | every `01`-`07` script | always, cheap parquet/mesh loads, palette, theme |
| `00_load_ibama_clean.R` | only `04` and `07` | only by the two scripts that need the raw IBAMA notices; not sourced by `00_setup.R` so the other five scripts don't pay for the 18-CSV read |
| `00_build_mesh.R` | nobody | run standalone, once, only if the panel's municipality set changes |

## Directory assumptions

| What | Location |
|---|---|
| Pipeline exports (parquet) | `output/parquets/` |
| Municipal mesh (GeoJSON) | `data/data_ibge/` |
| Raw IBAMA CSVs (PII-free, see `data/data_ibama_public/README.md`) | `data/data_ibama_public/` |
| Plot outputs (PNG/GIF) | `output/visualizations/` |
| Viz intermediate caches | `output/parquets/viz_*.parquet` |

All of these are declared as `PATH_*` / `FILE_*` constants at the top of
`00_setup.R`. Change them in one place if the layout moves again.

## One-time package install

```r
install.packages(c(
  "tidyverse","sf","arrow","scales",          # 00_setup
  "geobr","rmapshaper",                        # 00_build_mesh (fetch + simplify)
  "ggrepel","ineq","readr",                    # panels + raw IBAMA
  "fixest","ggridges",                          # panel effects
  "gganimate","gifski",                         # animation
  "igraph","ggraph"                             # offender network
))
```

## Run order

Every one of `01` through `07` is independently executable: run any single
one on its own, in any order, and it produces its own figures correctly.
`00_build_mesh.R` is the only real prerequisite, and only once (fetches the
mesh via geobr; re-run only if the panel's municipality set changes).

`04_raw_ibama.R` and `07_offender_network.R` both call `load_ibama_clean()`
(`00_load_ibama_clean.R`), which reads the raw IBAMA cache if it exists or
builds it if it doesn't. Running `04` before `07` just saves `07` from
redoing the 18-CSV read; it isn't required. Map 17 (cancellation rate) lives
in `04_raw_ibama.R`, next to the data it's built from, not in `01_maps.R`.

| Script | Items | Produces |
|---|---|---|
| `00_build_mesh.R` | (nenhum) | municipal mesh GeoJSON in `data/data_ibge/` (one-time) |
| `01_maps.R` | 1a-1d | choropleths (pct / absolute / EGS), bivariate map |
| `02_ranking_panels.R` | 2, 3, 5, 6, 7 | KPI shares, top-20 bars + composition, log-log scatter, quadrant, anchor small multiples |
| `03_annual_and_audit.R` | 4 | annual series (gap counts by type + total deforested area) |
| `04_raw_ibama.R` | 11-14, 17 | Lorenz curve, cancellation series + by state, fact->notice lag, instrument mix, cancellation map; **caches** raw IBAMA + cancellation rate |
| `05_panel_effects.R` | 15, 16, 19 | coefficient plot (fixest), event study around a deforestation surge (autos & fines, placebo pre-period), EGS ridgeline |
| `06_animated_map.R` | 20 | year-by-year animated GIF (test on 3 frames first) |
| `07_offender_network.R` | 18 | multi-municipality offender network |

## Conventions carried over from the analysis

- **Join by `geocode_ibge` (7-digit), never by name**: 5 homonym pairs in the panel.
- **EGS and pct_desmatado are ordinal**: colour by rank-quintile (`q5()`), never a continuous raw value.
- **Integrity checkpoints** (`N_MUNI`, `N_PANEL`, `N_YEARS`, `N_IBAMA_*`) are declared once in `00_setup.R` and asserted with `stopifnot()` in each script, same as the exploration script.
- The panel models in `05` reproduce the Python pilot in `fixest` (municipality + year FE, municipality-clustered SEs): the estimator planned for the thesis.
- The pipeline's own verification (56 checks across `pipeline/01-04*.sql`) is independent of this suite: no chart here is required for those checks to run.
- **Charts carry no title/subtitle** (axis labels and legends stay). Each figure's title lives as a numbered heading in the deliverable's own text (e.g. "7.5 Pressão x resposta") instead of being baked into the PNG. That avoids duplicating the same text in two places and any font/rendering mismatch between the chart and the document.
