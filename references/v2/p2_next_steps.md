# EGMS — Next Steps
**Status:** Pipeline v2 completo. Resultados definitivos incorporados. Documento gerado 2026-05-03.

---

## Priority flag

Before proceeding with any analytics commit: verify `streak = 1 → priority_score = 0` behavior. `LOG(1) = 0` zeroes the score regardless of deforestation volume. If this is in the current code, municipalities with large deforestation but exactly one year above threshold are silently excluded from rankings. This is the highest-risk unverified issue in the pipeline.

---

## Block 1 — R exploration script (→ closed commit)

**Objective:** understand, validate, and close the script as an auditable document before committing to GitHub. The script was written incrementally across sessions; this pass treats it as a first formal review.

### Best practices to apply throughout
- Structure in named sections with header comments (`# === SECTION ===`) — no code block without context
- Every non-obvious analytical decision gets a comment explaining *why*, not *what*
- No magic constants inline: `0.01` (val_multa threshold), `3` (minimum streak), `0.727` (p75) defined as named variables at the top of the script
- Remove dead code: commented-out chunks with no documentation function

### Review items
- **IBAMA filters:** confirm each condition (`Flora`, `Desmatamento`, `SIT_CANCELADO='N'`, `DES_STATUS_FORMULARIO='Lavrado'`) is justified and that the combination does not silently exclude valid records
- **Date handling:** `DAT_HORA_AUTO_INFRACAO`, `TRY_CAST`, year extraction — review what happens with malformed records; confirm `TRY_CAST` is not masking errors that should be visible
- **Lag analysis (4 sub-analyses):** review the double-join structure; confirm `pct_match_t`, `pct_match_t1`, `pct_ambos`, and `pct_nenhum` are calculated over the same base and sum to 100%
- **Sensitivity analysis (17.4%):** confirm the t+1 reclassification logic uses the same base as the SQL pipeline and that the denominator is consistent
- **Volume bias analysis:** confirm the correlation between `DT_FATO_INFRACIONAL` completeness and fine value is calculated correctly and that the document interpretation reflects what the code actually does
- **PRODES temporal coverage:** are there municipalities with fewer than 18 years of data? Gaps affect streak calculation silently — this has not been verified
- **PRODES annual distribution:** check `area_km2` by year for structural breaks — INPE methodology changes (minimum detection area, cloud cover) can introduce series breaks that are currently undocumented

### Checks to add
```r
# After loading ibama_raw: guard against partial read
stopifnot(nrow(ibama_raw) > 200000)

# After filters: print funnel breakdown
# How many records removed by each filter condition
# Makes the filtering pipeline auditable

# After year extraction: assert no NULLs in critical column
stopifnot(sum(is.na(ibama_clean$ano)) == 0)

# After PRODES × IBAMA join: confirm join did not expand rows
stopifnot(nrow(egs_base) == nrow(prodes))

# At end of script: print reference summary table
# n by tipo_egs and % gap_absoluto
# Output saved for comparison across runs
```

---

## Block 2 — Staging layer (01_staging.sql)

**Objective:** add municipality reference table; add geocode integrity checks.

### Best practices to apply
- Each `CREATE OR REPLACE TABLE` preceded by a comment with data source, granularity, and expected row count
- Column names standardized from staging: `geocode_ibge` (not `COD_MUNICIPIO`), `ano`, `val_multa` — no late renaming in analytics
- Checks block at end of each table: `-- == CHECKS ==`

### Items
- **Add `municipios_ref`:** table with `geocode_ibge`, `nome_municipio`, `uf` — source of truth for name and UF across all categories, including gap_absoluto municipalities that have no ibama_clean record. Source: IBGE municipality table (~5,570 rows)
- **Add `ipca_deflator`:** table with `ano`, `deflator` (base 2025) for 2008–2025 — required by Fix 2 (val_multas nominal bias) and Fix 3 (p75 pooled threshold). Values from IBGE/Sidra IPCA accumulated series; approximate values exist in the technical fixes document but must be replaced with exact Sidra figures before any publication. Adding to staging now makes it available as soon as Fix 2 is implemented in the analytics layer, with zero pipeline disruption
- **Geocode digit check:** verify that `COD_MUNICIPIO` in IBAMA raw always uses 7 digits — records with 6 digits (missing leading zero) would break the join with PRODES silently

### Checks to add
```sql
-- == CHECKS staging ==

-- All PRODES geocodes must match municipios_ref
SELECT COUNT(*) AS sem_referencia
FROM project2.staging.prodes_raw p
LEFT JOIN project2.staging.municipios_ref r USING (geocode_ibge)
WHERE r.geocode_ibge IS NULL;
-- Expected: 0

-- ipca_deflator must cover all years in the panel (2008–2025)
SELECT COUNT(*) AS anos_faltando
FROM (SELECT UNNEST(RANGE(2008, 2026)) AS ano) anos
LEFT JOIN project2.staging.ipca_deflator d USING (ano)
WHERE d.ano IS NULL;
-- Expected: 0

-- No deflator value should be NULL or <= 0
SELECT COUNT(*) AS deflator_invalido
FROM project2.staging.ipca_deflator
WHERE deflator IS NULL OR deflator <= 0;
-- Expected: 0

-- Geocodes with length != 7 in IBAMA raw
SELECT COUNT(*) AS geocode_invalido
FROM project2.staging.ibama_raw
WHERE LENGTH(CAST(COD_MUNICIPIO AS VARCHAR)) != 7;
-- Expected: 0 or documented
```

---

## Block 3 — Marts layer (02_marts.sql)

**Objective:** confirm ibama_clean fix is solid; add integrity checks.

### Best practices to apply
- `ibama_clean` exposes only columns consumed downstream — no `SELECT *`
- Explicit comment on the choice of `DAT_HORA_AUTO_INFRACAO` vs `DT_FATO_INFRACIONAL` with fix number and justification (69% NULL in DT_FATO_INFRACIONAL)

### Items
- **Fix 9 — expand ibama_clean filter to 3 cases (Fix 9, ABERTO):** replace single `Flora + Desmatamento` condition with 3-case OR covering 2008–2012 records where INFRACAO_AREA/TIPO_INFRACAO were not mandatory. See `p2_technical_fixes.txt` for exact SQL. After applying: re-run egs_final and compare tipo_egs distribution against reference (gap_absoluto 41.2%, total 14.490).
- UF sourcing: downstream analytics will join with `municipios_ref` rather than pulling UF from ibama_clean — this ensures coverage for gap_absoluto records

### Checks to add
```sql
-- == CHECKS marts ==

-- No NULLs in ano after CAST
SELECT COUNT(*) AS null_ano
FROM project2.marts.ibama_clean
WHERE ano IS NULL;
-- Expected: 0

-- Year range within expected bounds
SELECT MIN(ano), MAX(ano)
FROM project2.marts.ibama_clean;
-- Expected: 2008–2025

-- No negative val_multa
SELECT COUNT(*) AS multa_negativa
FROM project2.marts.ibama_clean
WHERE val_multa < 0;
-- Expected: 0
```

---

## Block 4 — Analytics layer (03_analytics.sql → review + checks + commit)

**Objective:** review persistence and ranking logic in detail; add integrity checks; fix UF; commit.

### Best practices to apply
- Separate `egs_base`, `egs_final`, and persistence/ranking queries into clearly demarcated sections
- Each CTE with a one-line comment explaining what it produces and why it exists
- Parameters (`p75 = 0.727`, `streak_min = 3`) documented as explicit constants with justification, not inline values

### Items

**Streak mechanism review**
- Reread the `ROW_NUMBER() + (ano - rn)` trick in full — understand why it works and where it fails
- Edge cases to verify: municipality with exactly 1 year of data; gap of 1 year interrupting a streak; municipalities entering the panel after 2008; municipalities with consistent data but only in non-consecutive years

**Priority score review**
- Formula: `LOG(max_streak) × LOG(1 + total_desmatado_km2)`
- Critical: when `streak = 1`, `LOG(1) = 0` → `priority_score = 0` regardless of deforestation volume. A municipality with streak = 1 and 500 km² deforested disappears from the ranking. Verify whether this is intentional. If not, `LOG(streak + 1)` is the straightforward fix
- Document the formula's properties explicitly: what it rewards, what it penalizes, what it makes invisible

**Threshold p75 = 0.727**
- Is it hardcoded or computed dynamically?
- If hardcoded: add comment with calculation date and the distribution it was derived from. When data is updated the threshold will drift while the cutoff stays fixed
- Consider computing dynamically within the query so it updates automatically

**Threshold of 3 years**
- Document as a design decision (one Brazilian electoral cycle) with a comment in the SQL, not as an arbitrary number

**UF fix**
- In rankings, replace UF sourced from ibama_clean with join to `municipios_ref` — resolves gap_absoluto coverage and the Pau D'Arco (PA vs TO) homonym

**Barra do Bugres (MT) verification**
- External research: what proportion of deforestation in this municipality is legally authorized via AUTEX/DOF permits?
- If confirmed as predominantly legal: gap_absoluto classification is methodologically correct (PRODES records forest loss, IBAMA has no infraction), but the narrative interpretation shifts from impunity to authorized clearing — update p2_results_narrative_draft accordingly

### Checks to add
```sql
-- == CHECKS analytics ==

-- Total rows in egs_final must be 14,490
SELECT COUNT(*) AS total FROM project2.analytics.egs_final;
-- Expected: 14490

-- Three categories must sum to total; gap_absoluto within tolerance band
SELECT tipo_egs, COUNT(*) AS n,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM project2.analytics.egs_final
GROUP BY tipo_egs;
-- Expected: completo + gap_absoluto + sem_pressao = 14490
-- gap_absoluto between 39.0% and 43.5% — outside this band, investigate before continuing

-- EGS must be >= 0 in all rows
SELECT COUNT(*) AS egs_negativo
FROM project2.analytics.egs_final
WHERE egs < 0;
-- Expected: 0

-- No duplicate geocode within the same year
SELECT geocode_ibge, ano, COUNT(*) AS n
FROM project2.analytics.egs_final
GROUP BY geocode_ibge, ano
HAVING n > 1;
-- Expected: 0 rows

-- Regression check: gap_absoluto% within historical band
SELECT
    ROUND(SUM(CASE WHEN tipo_egs = 'gap_absoluto' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS pct_gap_absoluto
FROM project2.analytics.egs_final;
-- Expected: 39.0–43.5 — if outside, do not proceed without investigation
```

---

## Block 5 — Documentation

**Objective:** close written deliverables before Power BI.

- **README:** final pipeline version only — no history of fixes, no mention of intermediate versions. Include: repository structure, data sources, execution sequence (01 → 02 → 03 → checks), known limitations (registration date vs infraction date, federal enforcement only, PRODES detection floor of 1 km²)
- **Methodological appendix:** document lag analysis results (same-year join empirically superior), sensitivity analysis (17.4% of gap_absoluto would change with t+1 join), and volume bias finding (correlation between DT_FATO_INFRACIONAL completeness and fine value magnitude). These decisions are currently in the narrative drafts but should be in a dedicated technical section accessible without reading the full results document
- **p2_results_narrative_draft:** update Barra do Bugres section after external verification
- **Citations:** convert preliminary references (IBAMA press releases, InfoAmazonia, Repórter Brasil, ((o))eco, ClimaInfo) to formal citations

---

## Block 6 — Power BI

**Objective:** build operational dashboard connected to pipeline output.

- Export parquets from DuckDB or configure direct connection
- **KPI cards:** % gap_absoluto, number of municipalities with streak ≥ 3, highest-priority municipality in current run
- **Time series:** % gap_absoluto by year; mean EGS (completo) by year
- **Choropleth map:** priority_score by municipality — UF and name now sourced from `municipios_ref`, correct for all categories
- **Ranking table:** user-controlled N parameter for number of inspections — top-N municipalities from ranked output
- **Municipality drill-down:** on clicking a municipality in the map, display EGS history year by year — turns a static ranking into a longitudinal monitoring tool

---

## Execution order

```
Block 1  →  Block 2  →  Block 3  →  Block 4  →  Block 5  →  Block 6
R review    staging     marts       analytics    docs         Power BI
            (UF fix)    (checks)    (streak,     (README,
                                    priority,    appendix,
                                    checks,      narratives)
                                    commit)
```

Blocks 2–4 are sequential (staging feeds marts feeds analytics). Block 1 (R script) is independent and can be done in parallel with Block 2 if needed, but the PRODES coverage and annual distribution checks in R may surface issues that affect staging decisions — completing Block 1 first is lower risk.

---

*Generated 2026-05-03. Based on pipeline v2 (DAT_HORA_AUTO_INFRACAO). All quantitative references from project2.duckdb as of 2026-05-02.*
