# Enforcement Gap Monitoring System (EGMS) — Technical Appendix

**Author:** Diogo Grieco
**Document status:** consolidated from `project2_session_reference_v5.md`, `p2_technical_fixes.txt` and `p2_next_steps.md` (19 dated working sessions, 2026-05-03 to 2026-07-15). This appendix supersedes those three documents as the reference for anyone reading the doctoral application; the originals remain in the repository as the full working log.
**Last updated:** 2026-07-15

---

## 1. Purpose and scope

EGMS is a DuckDB + SQL + R pipeline that cross-references satellite-detected deforestation (PRODES/INPE) with federal environmental enforcement records (IBAMA) for all municipalities of the Brazilian Legal Amazon, at municipality-year granularity (2008–2025, 805 municipalities, 14,490 rows). It produces a single derived indicator, the **Enforcement Gap Score (EGS)**, and a three-way classification (`gap_type`) that separates municipalities where deforestation is measurably unmatched by federal punitive response from those where it is not, or where deforestation pressure itself is not material.

The project is not a claim about which municipalities are, in fact, poorly policed. It is an instrument: a reproducible way of turning two large public administrative datasets into a ranked, falsifiable hypothesis about where enforcement is disproportionate to pressure — deliberately built to be checked, and built with its own falsification routes documented (Sections 6 and 7 below).

## 2. Architecture and stack

| Layer | Tool |
|---|---|
| Storage / query engine | DuckDB (`project2.duckdb`, schemas `staging` → `marts` → `analytics`) |
| Pipeline | 4 SQL files, run in order: `01_staging.sql` → `02_marts.sql` → `03_analytics.sql` → `04_export.sql` |
| Exploration / validation | R (tidyverse), `exploring_script.R` — an auditable, `stopifnot()`-gated document, not a scratch script |
| Visualization | Power BI, consumes 4 parquet exports from `04_export.sql` (not yet built — see Section 9) |
| Reproducibility | Single configuration point: `SET VARIABLE data_root` at the top of `01_staging.sql`; every read in the pipeline resolves against it. Export paths in `04_export.sql` are absolute literals instead (see Section 7, path portability) |

The pipeline and the R script were originally written in Portuguese identifiers and fully translated to English on 2026-07-15, including a rename of the classification field itself (`tipo_egs` → `gap_type`, values `completo/gap_absoluto/sem_pressao` → `measured_gap/absolute_gap/no_pressure`). This appendix uses only the current, English identifiers; the working documents preserve the Portuguese history for anyone auditing the changelog.

## 3. Data sources

| Source | Content | Notes |
|---|---|---|
| PRODES/INPE (TerraBrasilis) | Annual deforested area per municipality, Legal Amazon | 5 raw columns |
| IBAMA (dadosabertos.ibama.gov.br) | Federal environmental infraction records ("auto de infração"), one file per year | 84 raw columns; only federal jurisdiction — see Section 8 |
| IBGE — Localidades API | Municipality → state (UF) reference, JSON | Replaced an originally-planned DTB/.xls download that proved inaccessible; 5,571 municipalities, 100% UF coverage confirmed |
| IBGE/Sidra table 1737 | Monthly IPCA index, used to deflate fine values to constant 2025 reais | Wide format, parsed via `UNPIVOT` |

## 4. Methodology (locked decisions)

**Enforcement Gap Score:**

```
EGS = LOG(1 + area_km2) / SQRT(LOG(1 + n_infractions) * LOG(1 + fine_values))
```

computed only where both deforested area and enforcement response are present and material; `fine_values` is IPCA-deflated to constant 2025 reais before this computation, so the score is comparable across the 18-year panel.

**Classification (`gap_type`), current formula (`03_analytics.sql`):**

```sql
CASE
    WHEN area_km2 < 1       THEN 'no_pressure'    -- below materiality threshold
    WHEN fine_values < 0.01 THEN 'absolute_gap'    -- pressure present, ~zero federal response
    ELSE                          'measured_gap'   -- both present, EGS quantifies the ratio
END AS gap_type
```

Distribution confirmed against real production data (2026-07-12, re-confirmed after the 2026-07-15 SQL audit): `measured_gap` 3,285 (22.7%), `absolute_gap` 3,063 (21.1%), `no_pressure` 8,142 (56.2%), total 14,490. `p75` of EGS within `measured_gap` = **0.7027106414917799** (`PERCENTILE_CONT(0.75)`, recomputed on every run, not hardcoded).

**Persistence rankings.** Two ranked outputs identify municipalities with *sustained* (not one-off) gaps, using a gaps-and-islands streak detection (`ROW_NUMBER() OVER (PARTITION BY geocode_ibge ORDER BY year)`, streak = constant `year − row_number()`), filtered to streaks ≥ 3 consecutive years (chosen to exceed a single Brazilian municipal election cycle) and ranked by `priority_score = LOG(max_streak) * LOG(1 + total_deforested_km2)`:

- `ranking_absolute_gap`: 238 qualifying municipality-cases (sustained deforestation, ~zero federal fines).
- `ranking_measured_gap`: 47 qualifying municipality-cases (sustained deforestation, EGS ≥ p75 — enforcement present but disproportionate).

**Design decisions locked and documented in-code** (full rationale in `03_analytics.sql` header and `sql_explained.md`): materiality threshold of 1 km² (an order of magnitude above PRODES' 6.25 ha minimum mapping unit, to exclude residual noise); same-year join between PRODES and IBAMA (confirmed via lag analysis in `exploring_script.R`: 59.2% of matches occur same-year, 4.7% lag one year, 35.1% never match — same-year join retains the larger share and is the simpler, defensible choice); `egs = NULL` (not 0) for `no_pressure` cases, to avoid biasing aggregate averages; a 3-year minimum streak length for both rankings.

## 5. Validation performed

Two independent validation passes, both against real data, not just code review:

1. **Structural validation of the PRODES panel** (2026-07-12): confirmed a balanced panel (805 municipalities × 18 years, no coverage gaps) and cross-checked the annual `area_km2` trajectory against INPE's officially published PRODES rates at four anchor years (2008, 2012, 2024, 2025) — agreement within a few percentage points throughout. The one large single-year shift in the panel (median area per municipality dropping from 2.31 km² in 2008 to 0.87 km² in 2009) coincides with a real, documented policy change (Resolução CMN nº 3,545/2008, which blocked rural credit to properties embargoed for illegal deforestation) rather than an INPE methodology or sensor change — INPE has held its minimum mapping unit constant at 6.25 ha since 1988 specifically to preserve series comparability. No structural break found; the trajectory is treated as real signal.

2. **End-to-end pipeline execution** (2026-07-15, after the SQL audit in Section 7): the author ran all four SQL files from a clean state in DBeaver against real source files (not a code walkthrough), using a generated single-file concatenation (`00_run_all.sql`) for convenience — the four canonical files remain the source of truth. All checks matched documented expectations except one (Section 7.3).

## 6. Known limitations (systemic, not code defects)

These are explicitly *not* bugs to be fixed inside the current pipeline scope — they are boundaries of what federal administrative data can support, documented so no reader mistakes the ranking for a claim broader than the data allows.

1. **PRODES ≠ illegal deforestation.** PRODES detects canopy loss from satellite imagery; it does not distinguish legally authorized clearing (via AUTEX/DOF permits) from unauthorized clearing. One specific case in the current `absolute_gap` top 10, Barra do Bugres (MT), was checked against external data: state environmental agency (Sema-MT) satellite monitoring shows that approximately 99% of a 1,573-hectare deforestation episode in the municipality (Jan–Mar 2022) was legally authorized. The `absolute_gap` classification remains technically correct (PRODES detects it, IBAMA issues no federal fine for it), but the substantive reading changes from "enforcement impunity" to "authorized clearing outside the federal monitoring interface." The other 9 municipalities in that top 10 returned no equivalent finding either way (see Section 10, external research).
2. **State-level enforcement is not captured.** The dataset used here is federal (IBAMA) only. State environmental agencies (SEMAS-PA, SEMA-MT, IDESAM-AM, etc.) issue their own infractions, unavailable as a consistent national time series. The bias this introduces is conservative: a municipality's true enforcement gap can only be smaller than what EGMS reports, never larger, wherever active state-level enforcement exists and is not captured.
3. **Legal Amazon only.** Extending the index to other biomes (Cerrado, Caatinga, Mata Atlântica) requires replacing the current tabular geocode join with a spatial join (IBAMA infraction coordinates against biome polygons), not yet implemented.
4. **`exploring_script.R` lacks the portability treatment applied to the SQL pipeline.** It still uses working-directory-relative paths, unlike the SQL files (Section 7.4), which resolve through a single configurable variable. This is a known, low-severity, unresolved item.

## 7. Development history — condensed

Nineteen numbered fixes were logged across the project's working sessions (`p2_technical_fixes.txt`); the great majority are closed and are summarized here by theme rather than individually, to avoid repeating the full log. Four are worth naming because they materially shaped the current numbers or remain open by design.

**7.1 — Inflation adjustment and dynamic threshold (Fixes 2, 3).** Fine values span an 18-year panel in nominal reais; without deflation, older years would show artificially inflated EGS. Fine values are now deflated to constant 2025 reais via a real IPCA series (IBGE/Sidra), and the `p75` threshold used to define `measured_gap`'s upper tier is computed dynamically (`PERCENTILE_CONT`) on every run rather than hardcoded — eliminating a class of silent drift between documentation and pipeline output.

**7.2 — Materiality threshold and null semantics (Fixes 1, 11, 13).** An early version of the classification was vulnerable to floating-point contamination (a product of two logarithms could evaluate to a near-zero nonzero value instead of exactly zero) and used an inconsistent area threshold between its own documentation and its code (`> 0` vs. `>= 1` km²). Both were resolved: the materiality threshold is now `>= 1 km²` consistently, and `no_pressure` cases carry `egs = NULL` rather than `0`, so they cannot silently bias aggregate averages of EGS.

**7.3 — A documentation error, not a pipeline bug (Fix 19).** After the full pipeline was re-run from a clean state on 2026-07-15 (following the SQL audit in 7.5), `ranking_absolute_gap` returned 238 qualifying cases against a previously documented figure of 200. Investigation (duplicate-row check, top-20 and bottom-20 row inspection, cross-check of the unchanged `absolute_gap` population count of 3,063 against the R-side checkpoint) found no defect: the streak-detection logic had not been touched by any edit in this session, and the input population was identical to before. The conclusion is that "200" was a stale figure inherited from an earlier pipeline version (predating the materiality-threshold and classification fixes in 7.2) that was never recalculated once the logic stabilized. The reference document was corrected; no code changed.

**7.4 — Portability (Fixes 14, 18).** The pipeline originally used personal, hardcoded absolute paths (a workaround applied after working-directory-relative paths failed inside DBeaver). Read paths were consolidated behind a single DuckDB session variable (`SET VARIABLE data_root`), resolved via `getvariable()` at every read site — one line to edit per machine, portable across DBeaver, the DuckDB CLI, and R. The four `COPY ... TO` export paths in `04_export.sql` were, at first, missed by this fix and failed identically when the full pipeline was actually executed; they were corrected to absolute literal paths rather than routed through `getvariable()`, because it was not confirmed that DuckDB's `COPY ... TO` clause accepts an expression rather than a string literal — a deliberately conservative choice, documented as a known trade-off rather than resolved with an unverified syntax.

**7.5 — Line-by-line SQL audit (Fix 17).** All four SQL files were audited for robustness after the English translation: a rigid `CAST` on a date column was replaced with `TRY_CAST` (a malformed value now becomes `NULL`, caught by an existing check, instead of aborting the script — matching R's `ymd()` semantics); a duplicated pair of `CASE` expressions computing `egs` and `gap_type` from the same thresholds independently (a latent risk of silent divergence if one were edited without the other) was refactored into a single classification CTE that both are derived from; column-count checks mirroring the R script's checks were added for the two raw staging tables; a redundant type cast was removed. The full pipeline was re-run afterward and produced identical rankings, confirming the refactor was behavior-preserving.

**7.6 — Not yet resolved, by design (Fixes 4, 5, 6).** Authorized-clearing detection (7.1 above) and state-level enforcement integration remain open as systemic limitations, not code defects — see Section 6. Biome extension (Fix 6) is scoped as future work, not attempted.

## 8. Current results (production-confirmed, 2026-07-15)

**Top 10, `ranking_absolute_gap`** (sustained deforestation, ~zero federal fines; of 238 qualifying cases): Governador Luiz Rocha (MA), Barra do Bugres (MT), Fortuna (MA), Tefé (AM), São Domingos do Maranhão (MA), Santa Rosa do Purus (AC), Floresta do Araguaia (PA), Arame (MA), Santo Afonso (MT), Viseu (PA).

**Top 10, `ranking_measured_gap`** (sustained deforestation, enforcement present but disproportionate; of 47 qualifying cases): Moju (PA), Itaituba (PA), Itupiranga (PA), Peixoto de Azevedo (MT), Jacareacanga (PA), Aripuanã (MT), Novo Repartimento (PA), Prainha (PA), Tailândia (PA), União do Sul (MT).

Full rankings (all 238 and 47 rows, with `priority_score`, streak length, first/last year) are in `project2_session_reference_v5.md` §6.3 and reproducible via `05_rankings_audit.sql`.

## 9. Reproducibility

Full instructions are in `README.md` at the project root: data sources and download links for each of the four raw folders, the single `data_root` variable to edit, execution order, and expected check values at each stage. Raw data folders and the DuckDB database file are deliberately not versioned (`.gitignore` provided); they are large and independently regenerable from primary sources.

## 10. External validation research (new in this session)

A broad, independently-cited web search was carried out on all 20 municipalities appearing in the two top-10 rankings above, plus a cross-reference against Brazil's official federal list of "priority municipalities for deforestation prevention, monitoring and control" (Decreto nº 6,321/2007, MMA). Full citations and per-municipality notes are in `p2_municipal_research.md`; the headline pattern: 6 of the 10 `measured_gap` municipalities are, or have long been, formally designated federal priority areas (consistent with "enforcement present but disproportionate"), while none of the 10 `absolute_gap` municipalities appear on that list (consistent with "outside the coordinated federal attention system entirely") — treated here as one piece of construct-validity evidence, not as proof, since the priority-list cross-reference could only be confirmed against its 2021 cut and the list has since been expanded (to 81 municipalities by 2024, per public reporting not independently verified in full here).

## 11. Remaining work

1. Power BI dashboard — not started; no known technical blocker (UF/municipality name now materialize in all four parquet exports).
2. `exploring_script.R` path portability (Section 6, item 4) — low priority, unresolved.
3. Editorial review of external sources cited in the narrative documents — in progress as of this appendix (Section 10).
4. Systemic limitations in Section 6 (authorized-clearing detection at scale, state-level enforcement integration, biome extension) are explicitly out of MVP scope, not tracked as pending bugs.
