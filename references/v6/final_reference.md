# Enforcement Gap Monitoring System (EGMS) — Technical Appendix

**Author:** Diogo Grieco
**Document status:** consolidated reference for anyone reading the doctoral application. Supersedes `project2_session_reference_v5.md`, `p2_technical_fixes.txt`, and `p2_next_steps.md`; the originals remain in the repository as the full working log.
**Last updated:** 2026-07-20 (**methodology redesign, pipeline v5** — unified EGS formula, single ranking, layer-purity restructuring; see `sql_technical_fixes.md` for the full empirical record. This version supersedes the 2026-07-16 appendix entirely: the streak-based rankings and `priority_score` described there no longer exist in the pipeline.)

---

## 1. Purpose and scope

EGMS is a DuckDB + SQL + R pipeline that cross-references satellite-detected deforestation (PRODES/INPE) with federal environmental enforcement records (IBAMA) for all municipalities in PRODES's Legal Amazon panel (the official delimitation counts 772 municipalities; the panel's 805 include partially contained ones), at municipality-year granularity (2008–2025, 805 municipalities, 14,490 rows). It produces a single derived indicator, the **Enforcement Gap Score (EGS)** — one formula, applied uniformly to every observation — a per-year descriptive classification (`gap_type`), and one municipality-level ranking table (`egs_ranking`) combining the 18-year mean, a 3-year recent mean, a trend slope, and context columns.

The project is not a claim about which municipalities are, in fact, poorly policed. It is an instrument: a reproducible way of turning two large public administrative datasets into a ranked, falsifiable hypothesis about where the **federal** enforcement response is disproportionate to pressure — deliberately built to be checked, with its own falsification routes documented (Sections 6 and 10).

## 2. Architecture and stack

| Layer | Tool |
|---|---|
| Storage / query engine | DuckDB (`project2.duckdb`, schemas `staging` → `marts` → `analytics`) |
| Pipeline | 4 SQL files, run in order: `01_staging.sql` → `02_marts.sql` → `03_analytics.sql` → `04_export.sql` |
| Exploration / validation | R (tidyverse), `exploring_script.R` — an auditable, `stopifnot()`-gated document; the redesign-validation additions (formerly drafted as `exploring_script_additions_proposal.R`) are merged into the script as of v4.4-2026-07-20 |
| Visualization | Power BI, consumes 3 parquet exports from `04_export.sql` (not yet built — see Section 11) |
| Reproducibility | Single configuration point: `SET VARIABLE data_root` at the top of `01_staging.sql`. Export paths in `04_export.sql` are absolute literals (see 7.4) |

**Layer purity (v5).** Each file now does only what it declares: staging is raw ingestion exclusively (`SELECT *`, `all_varchar = true`, no filtering — five `*_raw` tables); marts filters, types, and standardizes (`ibama_clean`, `prodes_clean`, `municipality_ref`, `municipality_area`, `ipca_annual`); analytics computes derived indices (`ipca_deflator` ratio, `egs_final`, `egs_ranking`, `annual_summary`). The IPCA deflator ratio had lived in staging since v1, contradicting that file's own stated purpose; v5 split the operation across the three layers by kind of computation. Each file ends in a single consolidated check query (UNION ALL with a status column): 7 + 26 + 20 + 1 = **54 checks, all passing in production** (DuckDB via DBeaver, 2026-07-20; the `ipca_months_not_12` marts check was added 2026-07-20, Fix S14; the 2026-07-20 audit added three `prodes_clean` checks and `n_floor_active_nominal`; the third audit of 2026-07-20 added three silent-failure guards — `total_area_prodes_clean`, `deflator_2008`, and a post-export staleness check in `04_export.sql`, all three verified against the production database. Failures sort to the top of the grid).

The pipeline and R script were fully translated to English on 2026-07-15 (`tipo_egs` → `gap_type` etc.); this appendix uses only current identifiers.

## 3. Data sources

| Source | Content | Notes |
|---|---|---|
| PRODES/INPE (TerraBrasilis) | Annual deforested area per municipality, Legal Amazon | 5 raw columns |
| IBAMA (dadosabertos.ibama.gov.br) | Federal environmental infraction records, one file per year | 84 raw columns; federal jurisdiction only — see Section 6 |
| IBGE — Localidades API | Municipality → state (UF) reference, JSON | 5,571 municipalities, 100% UF coverage confirmed |
| IBGE/Sidra table 1737 | Monthly IPCA index, deflates fines to constant 2025 reais | Wide format, parsed via `UNPIVOT` (marts) |
| IBGE — Malha Municipal Digital, Áreas Territoriais 2025 | Municipality territorial area (km²) | New in v4/v5 (resolves Fix S12); `.xls` converted once to CSV; 100% coverage of the 805 PRODES geocodes, no duplicates |

## 4. Methodology (locked decisions, v5 — each with its empirical basis)

**Enforcement Gap Score — one formula for every municipality-year:**

```
EGS = 0                                                          if area_km2 < 1
EGS = LOG(1 + area_km2) /
      GREATEST(1, SQRT(LOG(1 + n_infractions) * LOG(1 + fine_values)))   otherwise
```

`fine_values` is IPCA-deflated to constant 2025 reais. `LOG` is base 10 (DuckDB); the scale is monotonic, so rankings are base-invariant. The EGS is treated as **ordinal** in practice: the ordering is validated, distances between scores are not interpreted.

- **Denominator floor** (`GREATEST(1, ...)`): the former `absolute_gap` branch is now the limiting case of the single formula — zero response floors the denominator at 1, leaving pure log-pressure. This removes the v3 two-scale problem (Fix S1: absolute and measured EGS were incommensurable) and the R$0.01-boundary instability (Fix S10). *Empirical basis:* reproduces the old three-branch CASE exactly in 100% of former absolute_gap rows and 99.1% of former measured_gap rows; the 0.9% divergent (28/3,285) are precisely the boundary-instability cases the floor was built to fix, made more conservative rather than explosive. Monitored by check `n_floor_active = 28`.
- **Materiality threshold (1 km²)**: unchanged from v3, but now a robustness result rather than an assumption. *Empirical basis:* top 10/20/50 of `egs_ranking` are identical under 1 km², 6.25 ha (PRODES's actual minimum mapping unit, confirmed against INPE's technical documentation), and no threshold; Spearman 0.985 (1 km² vs 6.25 ha rankings — the pair actually computed in R; the no-threshold comparison was verified by top-10/20/50 overlap only) across all 805 municipalities. The threshold only moves the descriptive `no_pressure` share.
- **`egs = 0` (not NULL) for no_pressure**: no-pressure years contribute exactly zero to averages, making the ranking's 18-year mean a single auditable formula.
- **`gap_type` kept as annotation only** (same three thresholds): `no_pressure` / `absolute_gap` (fines < R$0.01) / `measured_gap`. It no longer drives the formula or partitions rankings — municipalities at the top of the ranking typically mix absolute and measured years. Documented asymmetry: absolute_gap years score higher on average than measured_gap years (0.723 vs 0.582), consistent with the project's reading that zero response is the more severe gap.

**Classification distribution** (confirmed in production, 2026-07-20, identical to the 2026-07-12 figures — the redesign did not alter the classification): `measured_gap` 3,285 (22.7%), `absolute_gap` 3,063 (21.1%), `no_pressure` 8,142 (56.2%), total 14,490. 552 of 805 municipalities have at least one pressure year.

**Ranking (`egs_ranking`, one table, 805 rows)** — replaces the two streak-based rankings, `priority_score`, and the 3-consecutive-year rule (Fixes S2/S3/S7, superseded). Columns and rationale:

- `avg_egs_18y` (main ordering): mean of yearly EGS, zero-filled. *Algebraic identity, verified in R to ~1e-16; the SQL check (`identity_mismatches`) enforces it to 0.01, the tolerance imposed by the rounded column:* `avg_egs_18y = mean(EGS | pressure years) × fraction(pressure years)` — the severity × persistence composite computed as one direct average rather than a hidden weighting. *Empirical basis for adopting it over alternatives:* severity and frequency correlate strongly across the 552 qualified municipalities (Pearson 0.621 / Spearman 0.696); 9/10 overlap between the top 10 by pure severity and by 0-fill; the single divergence — Nova Nazaré (MT), highest raw severity in the dataset (1.384) on only 2/18 pressure years, demoted out of the top 10 — is the documented editorial decision: a *persistent-gap* monitor deliberately discounts isolated episodes.
- `avg_egs_3y` (2023–2025) and `slope_egs`: current-situation columns, kept **together** by decision. The slope is computed manually (`COVAR_POP(egs, year) / VAR_POP(year)`, identical to R's `cov/var` since the normalization cancels; DuckDB's native `REGR_SLOPE` deliberately avoided pending verification). *Documented fragility:* with few non-zero years the slope is driven by the position of one or two points (validated: single 2024 event → +0.005 vs. 2008/2017 events → −0.017); it is read alongside `n_years_pressure` as a reliability indicator, never alone. The 3-year window includes the possibly-unconsolidated 2025 PRODES figure — flagged "last year subject to revision," by decision, without an additional sensitivity window.
- `n_years_pressure`, `n_absolute_gap`, `n_measured_gap`, `n_no_pressure`: the per-type year counts (sum to 18, checked).
- `pct_desmatado` (resolves Fix S12): 18-year total deforestation as % of the municipality's own territory (IBGE areas). Context column, not a ranking criterion — captures a distinct axis (validated: Cujubim/RO has the dataset maximum, 29.79% of territory, with avg_egs_18y of only 0.578). Distribution: median 0.97%, p75 3.19%.
- `total_desmatado_km2`, `n_infractions`, `total_fines`: raw context totals — not recomputable inputs to the EGS (a mean of ratios ≠ a ratio of sums), flagged as such.

**Other locked decisions** (unchanged from v3, empirical bases in `exploring_script.R`): same-year PRODES–IBAMA join — 59.2% of infraction records (n = 60,707; the lag validation's unit is the notice, not the municipality-year) match same-year; 4.7% (`only_t`) match same-year with no better lag alternative; only 1.0% (`only_t1`) would match exclusively with a one-year lag; 35.1% never match (**corrected 2026-07-20, Fix S13**: this section previously mislabeled the 4.7% figure as "one-year lag" — it is the same-year-only share; the true one-year-lag-exclusive share is 1.0%, roughly 5× smaller than the earlier text implied). `DAT_HORA_AUTO_INFRACAO` as the date column (0% NA vs 71% NA for `DT_FATO_INFRACIONAL`); the three-case deforestation filter on IBAMA records.

**Known, undocumented-until-now caveat on the join itself (Fix S8, 2026-07-20):** the "same-year" join above compares two different calendars. PRODES's official annual rate covers August 1 (year *t*−1) to July 31 (year *t*); IBAMA's `year` here is calendar year (Jan–Dec) from `DAT_HORA_AUTO_INFRACAO`. The two windows overlap for only about 7 of 12 months. The lag-validation figures just cited were computed on this calendar-year basis, not against PRODES's true Aug–Jul window — part of what the analysis calls "lag" may be this mismatch rather than genuine reporting delay. Not corrected in v5 (the same-year join is kept, as before); now stated explicitly rather than left for a reader to infer.

## 5. Validation performed

Four independent passes, all against real data:

1. **Structural validation of the PRODES panel** (2026-07-12): balanced panel confirmed (805 × 18, no gaps); annual trajectory cross-checked against INPE's published PRODES rates at four anchor years (2008, 2012, 2024, 2025). Three of four agree within ~3% (2008 +2.9%, 2012 −3.2%, 2024 −0.4%). **Corrected 2026-07-20, Fix S9:** the fourth anchor, 2025, does not — it diverges −8.3% to −9.3%, well outside the "<5%"/"a few percentage points" claim made in earlier versions of this document and in `exploring_script.R`'s own comment (corrected there as of v4.4-2026-07-20). The likely explanation is not a data defect: PRODES publishes a preliminary estimate for the in-progress year before consolidating it, and the file used here may predate consolidation for 2025 — the same issue behind the "last year subject to revision" note attached to `avg_egs_3y` in Section 4. Treated as a documented caveat on the most recent year, not as evidence against the panel's structural validity, which the other three anchors support. The one large single-year shift (2008→2009) coincides with a documented policy change (Resolução CMN nº 3.545/2008), not a sensor/methodology change.
2. **Cross-validation of the redesign** (2026-07-20; claim revised by the 2026-07-20 audit): every formula decision (floor, materiality, 0-fill, slope) was implemented and tested in the author's R (the redesign-validation additions, since merged into `exploring_script.R` v4.4) and in the production DuckDB pipeline, all checkpoints agreeing (e.g., deflator(2008) = 2.5826 identical in both). A third, independent Python reproduction against the raw files was run during development and matched R to 4 decimal places, but neither the script nor its output CSV was preserved in the repository — that leg is documented, not reproducible from the repo. In its place, an independent external replication (audit session, 2026-07-20) rebuilt `ibama_clean` from the raw CSVs (60,707 rows; R$26,814,492,927 exact), the IPCA deflator (2008 = 2.5826), and the full classification (8,142/3,063/3,285), confirming all checkpoints.
3. **End-to-end production run of the v5 pipeline** (2026-07-20; re-confirmed the same day with the S14 addition): all consolidated checks pass in DBeaver from a clean state (47 at that run; 51 after the 2026-07-20 audit additions, re-confirmed; 54 after the third audit's guards, verified read-only against the production database), including the algebraic-identity check and the `pct_desmatado` distribution — verified in SQL, not only documented in prose. The one initial failure was a string-formatting artifact in one check (see 7.7), not a data defect.
4. **External verification research** (2026-07-20): Section 10.

**Note on the R-side classification checkpoint (Fix S11, downgraded to a footnote 2026-07-20):** `exploring_script.R`'s `absolute_gap` checkpoint (3,063, matching `n_absolute_gap` in `egs_final`) uses a different operationalization than the SQL — an individual-record test (any single infraction ≥ R$0.01 nominal) versus the SQL's aggregated, deflated municipality-year sum. The two agree here because real fine values sit far from the R$0.01 boundary; it is empirical agreement on the resulting population, not a proof that the two rules are equivalent in general. `gap_type` no longer drives the EGS formula in v5 (Section 4), which lowers the practical stakes of this gap, but the cross-check should still be read as "same answer on this data," not "same rule."

## 6. Known limitations (systemic, not code defects)

1. **The metric is a *federal* enforcement gap, not an enforcement gap simpliciter.** IBAMA records are the only response data. This caveat is now concrete rather than generic: Pará (16 of the current top 20) operates an active state apparatus (SEMAS-PA — open transparency portal since March 2021; Operação Curupira: 196 notices, R$87.9M in fines, 30,592 ha embargoed cumulatively; the state's deforestation fell 28.4% in 2024), and Amazonas (2 of the top 20) likewise (IPAAM's Operação Tamoiotatá 2025: R$144.7M in fines, 16,176 ha interdicted, explicitly covering Maués, rank 9). A high EGS is therefore compatible with three distinct situations — genuine absence, federal absence with state substitution, and federal presence without effect — indistinguishable from this data alone. The bias is conservative in one direction only: wherever uncaptured state enforcement exists, the true *total* gap is smaller than measured, never larger.
2. **PRODES ≠ illegal deforestation.** No distinction between authorized (AUTEX/DOF) and unauthorized clearing. The verified example remains Barra do Bugres (MT — ~99% of a 1,573 ha episode legally authorized per Sema-MT); the caveat applies with full force to the current top 20.
3. **Enforcement is measured by fines levied**, not by embargoes, seizures, criminal action, or fines actually collected. The Cumaru do Norte case (Section 10) shows why this matters: heavy repeated federal fining with persistent deforestation is scored as a gap, correctly, but the mechanism is ineffectiveness, not absence.
4. **Legal Amazon only.** Extension to other biomes requires a spatial join (IBAMA GPS coordinates × biome polygons) — scoped as product horizon (`p2_horizonte_produto.md`), not MVP.
5. **EGS is ordinal.** Rankings are validated; score distances are not interpreted.
6. **`exploring_script.R` lacks the SQL pipeline's path portability** (working-directory-relative paths). Known, low severity.

## 7. Development history — condensed

**7.1 — Inflation adjustment (Fixes 2, 3).** Fines deflated to constant 2025 reais via the real IPCA monthly series; the 2025 base is the year's average of monthly indices (notices are drafted year-round, peaking Sep–Oct).

**7.2 — Materiality threshold and null semantics (Fixes 1, 11, 13).** Early inconsistencies (`> 0` vs `>= 1 km²`; floating-point contamination) resolved in v3; v5 subsequently replaced `egs = NULL` with `egs = 0` for no_pressure as part of the 0-fill design (Section 4).

**7.3 — Documentation drift (Fix 19).** The "238 vs 200" ranking-count discrepancy of 2026-07-15 was a stale documented figure, not a pipeline defect. Moot as of v5 (those rankings no longer exist) but kept as a process lesson: numbers in prose drift; numbers in checks don't.

**7.4 — Portability (Fixes 14, 18).** All reads consolidated behind `SET VARIABLE data_root`; `COPY ... TO` export paths deliberately left as absolute literals (unverified whether `TO` accepts an expression — documented trade-off).

**7.5 — Line-by-line SQL audit (Fix 17, 2026-07-15).** `TRY_CAST` on date parsing; duplicated CASE logic refactored; column-count checks added. Behavior-preserving (identical outputs on re-run).

**7.6 — NULL blind spot in a staging check (Fix S17, 2026-07-20).** `WHERE LENGTH(col) != 7` silently missed 6 NULL geocodes (`LENGTH(NULL) != 7` evaluates to NULL, not TRUE, under three-valued logic); corrected to `IS NULL OR ...`, expected value 29. Composition verified in the raw files: 23 rows are Manoel Viana/RS with a malformed 6-digit code (the correct IBGE code is 4311759; corruption mechanism unknown — **not** a leading-zero drop, no IBGE code starts with 0; corrected here by the third audit, 2026-07-20 — this paragraph had kept the impossible mechanism after S18 fixed it everywhere else); 6 are garbage rows. Neither affects `egs_final` — documented, not corrected.

**7.7 — Methodology redesign and layer restructuring (v4/v5, 2026-07-20).** The full redesign described in Section 4: streaks, `priority_score`, and the two partitioned rankings discarded and replaced by the unified formula + single 0-fill ranking; staging/marts/analytics restructured for layer purity; checks consolidated (46 total at the time). Every decision validated empirically before adoption (Section 5, item 2); complete record in `sql_technical_fixes.md` ("Registro empírico — validação da redesign dos rankings"). One cosmetic check failure in production (`ROUND` on DOUBLE leaves ".0" when cast to VARCHAR) fixed via BIGINT cast and re-confirmed.

**7.8 — Fixes-review pass (2026-07-20).** A second read of `sql_technical_fixes.md`'s open items (S8, S9, S11, S13, S14, S15, S16.1) against the current v5 documents found two places where the rewritten docs had carried an error the fixes log had already flagged (the lag-percentage mislabeling, Fix S13) or left a known gap undocumented (the PRODES/IBAMA calendar mismatch, Fix S8). Corrected: the lag-figure labels here and in `02_marts.sql`'s header comment; the "<5%" anchor-agreement claim in Section 5 (2025's anchor genuinely exceeds it); the calendar-mismatch caveat, now stated in `02_marts.sql`, `03_analytics.sql`, and Section 4 above; a deterministic tiebreak added to `egs_ranking`'s `ORDER BY` (Fix S16.1); a new check (`ipca_months_not_12`, Fix S14) added to `02_marts.sql`, bringing the total to 47 (51 after the 2026-07-20 audit patch; 54 after the third audit's guards); download-snapshot dates added to `README.md` (Fix S15); the R/SQL classification cross-check reframed as an empirical footnote rather than a structural guarantee (Fix S11). `assert_*` macros (Fix S4) were considered and explicitly declined — the consolidated check-block pattern already adopted was judged sufficient, and adding an aborting-error layer was not worth the added surface. Fixes S5 and S6 were found already resolved by earlier work (the empirical validation registry, and the ordinal-EGS framing, respectively) and are marked closed.

## 8. Current results (production-confirmed, 2026-07-20)

**Top 10, `egs_ranking` by `avg_egs_18y`** (of 805; all ten have 18/18 pressure years): Cachoeira do Piriá (PA) 1.179, Porto de Moz (PA) 1.175, Monte Alegre (PA) 1.109, Aveiro (PA) 1.109, Alenquer (PA) 1.107, Arame (MA) 1.078, Acará (PA) 1.075, Mojuí dos Campos (PA) 1.068, Maués (AM) 1.036, Santa Maria das Barreiras (PA) 1.021.

The top 20 adds Itupiranga, Cumaru do Norte, Jacareacanga, Medicilândia, São Domingos do Maranhão (MA), Prainha, Santana do Araguaia, Autazes (AM), Oriximiná, Ipixuna do Pará — 16/20 in Pará, 2 Maranhão, 2 Amazonas; every one with 18/18 pressure years.

**Cross-version robustness:** three municipalities from the discarded v2/v3 rankings survive in the new top 20 (Porto de Moz, Jacareacanga, São Domingos do Maranhão) — findings that persist across a complete replacement of the method. The falls are design-intended: Governador Luiz Rocha (old absolute #1, 18-year streak but median 4.6 km²/year) → rank 54 (magnitude now matters); Itaituba and Apuí (old measured leaders, with two of the dataset's larger federal responses) → ranks 129/141 (the ratio recognizes their response); Nova Nazaré → demoted by the 0-fill mean (isolated episodes discounted).

**Current-situation columns working as designed:** Aveiro (avg_3y 1.508 vs avg_18y 1.109, slope +0.042 — the sharpest current deterioration in the top 20) vs. Arame (0.722 vs 1.078, slope −0.033 — old, deep, improving). Full table: `egs_ranking` (805 rows). (The prototype cross-check CSV, `egms_tabela_final_prototipo.csv`, was not preserved in the repository — see §5.2.)

## 9. Reproducibility

Full instructions in `README.md`: data sources and download links for the five raw inputs (including the new IBGE territorial-areas file and its xls→csv conversion note), the single `data_root` edit, execution order, the consolidated check blocks (54 checks with expected values in-file), and — since Fix S15 — the download snapshot date for each source, because the check values are specific to that snapshot and IBAMA/PRODES data is revised over time. Raw data and the DuckDB file are not versioned; regenerable from primary sources.

## 10. External validation research (2026-07-20, on the v5 top 20)

Systematic web verification on the new ranking, replacing the v3-era research (which targeted the discarded rankings' top cases; `p2_municipal_research.md` retains it for the record):

- **MMA priority-list cross-reference:** 8 of the top 20 (Cumaru do Norte, Itupiranga, Jacareacanga, Medicilândia, Mojuí dos Campos, Prainha, Santa Maria das Barreiras, Santana do Araguaia) appear on Portaria GM/MMA nº 1.202/2024 (81 priority municipalities, ~71% of 2024 Legal Amazon deforestation, 28 in Pará). Independent methodologies converging on a 40% core is treated as construct-validity evidence, not proof. The 2026 update (Portarias 1.716/1.717) could not be obtained; true overlap may be higher.
- **State-capacity findings** (SEMAS-PA, IPAAM): Section 6, item 1 — the concrete grounding of the federal-only caveat.
- **Cumaru do Norte** (rank 12): raw IBAMA records show 112 notices across 12/18 years, R$761.9M deflated, including single notices of R$54M/R$39M (nominal; 2017 and 2008/2017) — federal presence without effect, a distinct mechanism from absence, flagged wherever the case is cited.
- **Apuí temporal validation:** annual EGS reached its worst sustained stretch in 2020–22 (mean 0.743; deforestation 440 km²/yr against a flat response — the single-year series max, 1.459 in 2009, is an isolated one-notice year) and fell to 0.564 in 2023–25 as the response surged (95 notices/yr, R$115M/yr deflated; 118 notices and R$188M in 2025 alone) — matching the externally documented 2025–26 federal/state operations. The system's recency columns capture the correction (avg_3y 0.564 < avg_18y 0.668, slope −0.012); Apuí's fall to rank 141 is the instrument recording that the response arrived, not a miss.
- **Absence of evidence noted as such:** no usable press coverage found for several top municipalities (e.g., Cachoeira do Piriá returned only generic regional operations); no ICMBio conservation-unit overlap check completed; SEMA-MA (relevant to Arame and São Domingos do Maranhão) returned only programmatic descriptions, no operational data — an asymmetry in verification, recorded, not filled in.

## 11. Remaining work

1. Power BI dashboard — not started; no known technical blocker (3 parquet feeds ready).
2. ~~Merge `exploring_script_additions_proposal.R` into `exploring_script.R`~~ — done (v4.4-2026-07-20): the additions are merged into the script; the standalone proposal file remains only as repository history.
3. `exploring_script.R` path portability — low priority, unresolved.
4. Editorial review of external citations in the narrative documents. Named items (audit, 2026-07-20; updated by the third audit, 2026-07-20): (a) SEMAS-PA/Operação Curupira — the linked note (10/10/2024, on the 37% alert reduction) does not match, by title, the figures cited (196 notices, R$87.9M, 30,592 ha); confirm the page contains them or find the primary source (page is JS-rendered; automated fetch returns empty). (a2, third audit) The Agência Pará (28% deforestation drop) and Agência Amazonas (IPAAM Tamoiotatá: R$144.7M, 16,176 ha) links are likewise JS-rendered and machine-unverifiable — same verification status as (a), previously unflagged; URL slugs corroborate the headline figures only. (b) IBAMA budget figures (~43% cut, 41% execution, ~500 inspectors) — no link since v2. (c) IBAMA 2025 in Apuí (R$173M, ~27,000 ha embargoed) — inherited from v2, no link. (d) Arrest of Apuí's former vice-mayor (Mar/2025) — no link. (e) Portarias GM/MMA 1.716/1.717 (2026) — nº 1.716 confirmed to exist (June 19, 2026; sets the list criteria, revokes Portaria 833/2023; the 2026 program covers 89 municipalities); the list itself (1.717) still not obtained — retry before publishing. (f, third audit) The lex.com.br link for Portaria 1.202/2024 is title/date-correct but its annexes (the 81-municipality list) are subscriber-only — the 8/20 overlap is not verifiable from that link; the O Liberal article names the Pará priority municipalities and does contain all 8 overlap cases (all PA). Prefer the DOU (in.gov.br) as primary source, and keep the fixture suggestion: commit the 81-municipality list of Portaria 1.202/2024 in `references/`, so the 8/20 overlap becomes verifiable offline.
5. Systemic limitations (Section 6) are product-horizon items (`p2_horizonte_produto.md`), not pending bugs.
