# Enforcement Gap Monitoring System
## Narrative Draft v3 — Portfolio Layer
**Status:** Resultados definitivos incorporados (pipeline v5, confirmado em produção 2026-07-12). Pendente: Power BI screenshots, quebras estruturais do PRODES, verificação de mais casos além de Barra do Bugres.

---

## The Problem

Brazil's environmental enforcement apparatus faces a structural misalignment: deforestation is monitored continuously via satellite (PRODES/INPE), but inspection and sanctioning capacity is geographically concentrated, resource-constrained, and reactive. The result is not simply impunity — it is invisible impunity. Without a systematic way to compare where forest loss is occurring against where enforcement is actually happening, agencies and oversight bodies have no operational basis for prioritizing limited inspection capacity.

This project builds that comparison.

---

## What This System Does

The Enforcement Gap Monitoring System (EGMS) crosses PRODES annual deforestation data with IBAMA administrative records of environmental infractions to produce a single, interpretable index — the **Enforcement Gap Score (EGS)** — that measures the imbalance between deforestation pressure and institutional response, at the municipality-year level, across the Brazilian Legal Amazon from 2008 to 2025.

**EGS formula:**

```
EGS = log(1 + deforestation_km²) / √(log(1 + n_fines) × log(1 + fine_value_R$))
```

The numerator captures deforestation pressure. The denominator captures enforcement through a geometric mean of two components: presence (number of infractions filed) and intensity (total fine value). The geometric mean penalizes imbalance — a municipality that files many low-value fines scores substantially worse than one with fewer, proportionate sanctions. Higher EGS means a larger gap between pressure and response.

The index produces three analytically distinct categories, which are not compared against each other:

- **Completo:** Deforestation observed AND enforcement documented. EGS measures relative intensity of the gap.
- **Gap absoluto:** Deforestation observed, zero enforcement on record. EGS = log(1 + area) — a measure of unaddressed pressure.
- **Sem pressão:** No deforestation detected, or deforestation below the materiality threshold (see below). No gap to measure.

---

## Key Design Decisions

**Why PRODES, not DETER.** DETER provides near-real-time deforestation alerts for field operations. PRODES is the audited annual series — the official reference for policy evaluation and historical comparison. A monitoring system oriented toward institutional accountability requires consistency over reactivity.

**Why the geometric mean in the denominator.** Enforcement has two dimensions that are not interchangeable: the number of acts (presence) and their financial weight (intensity). Summing them loses information. Multiplying their logs and taking the square root gives a combined measure that degrades gracefully when either dimension is weak. A municipality with 50 infractions totaling R$10,000 is not equivalent to one with 5 infractions totaling R$1,000,000 — and EGS treats them differently.

**Why log(1 + x) throughout.** Deforestation and fine values follow highly right-skewed distributions. Log-transforming compresses extreme values while preserving rank information and avoiding division by zero.

**Why a materiality threshold of 1 km².** PRODES records any detected clearing above its detection resolution, which includes trace amounts (well under 1 km²) that are not meaningful enforcement targets. The pipeline classifies a municipality-year as `sem_pressao` (no material pressure) unless accumulated deforestation reaches 1 km², not merely `> 0`. Below that threshold, absence of an IBAMA infraction is not an enforcement gap — it is the absence of anything worth enforcing. This single decision has a large distributional effect (see below) and is documented in the pipeline as Fix 11.

**Why the same-year join.** Empirical analysis across the IBAMA infraction dataset confirmed that the same-year join captures more records than a t+1 (following-year) join would, with the monthly distribution of infraction registrations peaking in September–October — aligned with the Amazon dry season and deforestation pressure, not with a systematic lag pattern that would indicate response to the prior year. Same-year join confirmed and locked.

**Why 3 consecutive years as the persistence threshold.** Three years spans one Brazilian electoral cycle (4 years) with a one-year buffer. A municipality with a persistent gap across three consecutive years is exhibiting a structural pattern, not a one-off institutional failure or an election-year anomaly.

**Why the date of registration, not the date of the infraction.** The IBAMA field `DT_FATO_INFRACIONAL` (infraction date) is null in a majority of records. The pipeline uses `DAT_HORA_AUTO_INFRACAO` — the date the infraction was formally registered — which has no nulls. The tradeoff is explicit: registration date may differ from infraction date by days to months, introducing potential year misalignment in a minority of cases.

---

## What the Data Shows

The dataset covers municipalities in the Brazilian Legal Amazon, 18 years (2008–2025), yielding 14,490 municipality-year observations with material deforestation pressure defined and materiality-filtered classification, confirmed in production on 2026-07-12:

| tipo_egs | n | % |
|---|---|---|
| completo | 3,285 | 22.7% |
| gap_absoluto | 3,063 | 21.1% |
| sem_pressão | 8,142 | 56.2% |

p75 EGS (reference threshold for persistence ranking) = 0.7027106414917799.

**A methodological note on these numbers.** Earlier drafts of this project cited a substantially higher gap_absoluto share (41.2%, under an early pipeline version) and, later, a completo share above 50% (pipeline v3, before the materiality threshold was applied consistently). The current 22.7% / 21.1% / 56.2% split reflects the materiality fix (Fix 11): roughly 700 municipality-years that had *some* detected clearing under 1 km² — with no enforcement record — moved from `gap_absoluto` into `sem_pressão`, because sub-1-km² clearing is below what any inspection would realistically target. This is a methodology correction, not a claim that enforcement improved. It should be presented in the portfolio as evidence of iterative rigor, not as a substantive finding about enforcement trends.

**21.1% of observations are gap_absoluto** — 3,063 cases where PRODES recorded material deforestation (≥1 km²) with no IBAMA infraction on record in that municipality and year.

**The gap_absoluto persistence top 10 (by priority_score = log(max_streak) × log(1 + total_desmatado_km²)):**

| # | Município | UF | Streak (anos) | km² acumulados | Período |
|---|---|---|---|---|---|
| 1 | Governador Luiz Rocha | MA | 18 | 106.8 | 2008–2025 |
| 2 | Barra do Bugres | MT | 16 | 101.1 | 2008–2023 |
| 3 | Fortuna | MA | 13 | 107.1 | 2008–2025 |
| 4 | Tefé | AM | 12 | 117.5 | 2010–2025 |
| 5 | São Domingos do Maranhão | MA | 10 | 168.5 | 2008–2023 |
| 6 | Santa Rosa do Purus | AC | 18 | 52.9 | 2008–2025 |
| 7 | Floresta do Araguaia | PA | 12 | 85.3 | 2008–2023 |
| 8 | Arame | MA | 7 | 223.3 | 2008–2022 |
| 9 | Santo Afonso | MT | 14 | 50.6 | 2008–2021 |
| 10 | Viseu | PA | 9 | 112.4 | 2008–2025 |

Three of the top ten are in Maranhão — a pattern consistent with weaker federal enforcement presence at the Amazon–Cerrado frontier, and distinct from the higher-profile Pará/Mato Grosso arc-of-deforestation cases.

**One case requires an explicit caveat.** Barra do Bugres (#2) was checked against the two alternative explanations this project treats as disqualifying for an "impunity" reading: legally authorized clearing (AUTEX/DOF permits) and state-level enforcement not captured in the federal IBAMA dataset. State data (Sema-MT satellite monitoring, Jan–Mar 2022) indicates that approximately 99% of a 1,573-hectare clearing episode in the municipality was legally authorized. This does not necessarily invalidate the full 16-year streak, but it means Barra do Bugres should **not** be presented as a straightforward enforcement failure without that caveat, and its inclusion in any top-line "worst cases" framing should be qualified or replaced. For the other nine municipalities in this list, targeted web research found no equivalent evidence of authorized clearing or documented state-level enforcement — which supports, but does not prove, treating them as genuine federal enforcement gaps. Absence of evidence is not confirmation; these remain the system's best current candidates for field verification, not adjudicated findings.

**Among municipalities with documented enforcement (completo), 43 sustained EGS above the 75th percentile for three or more consecutive years.** The top case by priority score is **Moju (PA)** — 7 years above the threshold (2008–2024), 735.2 km² deforested, enforcement consistently present but proportionately inadequate; recent IBAMA operations in the region (2025–2026) identified phantom/front timber companies and applied over R$107 million in fines, consistent with the pattern EGS surfaces. **Itaituba (PA)** ranks second with 1,240.9 km² over a 2018–2022 streak — driven by garimpo ilegal in the Tapajós basin, where IBAMA suspended over 300 mining permits in the adjacent protected area. Unlike the gap_absoluto list, the completo top 10 is dominated by Pará and Mato Grosso municipalities tied to illegal logging and mining operations that are independently documented in federal enforcement records — a pattern that reinforces rather than undermines the "enforcement present, disproportionate" reading.

---

## Decision Output

The system is designed to answer one operational question: **where should enforcement capacity be directed next quarter?**

> Decision: Prioritize environmental inspections
> Constraint: N inspections/month — capacity parameter set by the user in Power BI
> Rule: Highest priority_score (log(streak) × log(1 + deforestation)) with persistence ≥ 3 consecutive years
> Action: Deploy inspection team to top-N municipalities from the ranked list; escalate persistent gap_absoluto cases for targeted audit planning, excluding or flagging cases with a known authorized-clearing caveat (e.g., Barra do Bugres)

The number of inspections is not hardcoded — it is a user-controlled parameter in the dashboard, allowing the system to adapt to whatever operational capacity the agency or team actually has.

---

## Interpretive Limits

This system does not measure illegality. PRODES records satellite-detected forest loss — some of this deforestation may be legally authorized via AUTEX/DOF permits, as confirmed for Barra do Bugres. IBAMA records detected federal enforcement acts — municipalities with no federal records may be served by state-level agencies not captured in the dataset. EGS measures the ratio of observed pressure to observed response; it does not establish causality or confirm that a municipality is operating outside the law.

That caveat is not a weakness — it is the appropriate scope, and the Barra do Bugres case is a working example of the screening process this project applies before presenting any municipality as an enforcement failure: rank by the index, then check the top candidates against known alternative explanations before drawing conclusions.

No causal identification is claimed. Two-way fixed effects (territory × year) could partial out time-invariant confounders in a future extension, but time-varying factors — commodity price cycles, state-level enforcement coordination, road infrastructure changes — would remain.

---

## This System as MVP

The current implementation covers the Brazilian Legal Amazon — not because other biomes matter less, but because the Legal Amazon is where the data architecture allows a clean, defensible join. PRODES and IBAMA both index observations by IBGE municipal geocode in this region, with consistent historical coverage since 2008.

Extending to the Cerrado, Caatinga, or Mata Atlântica requires solving two concrete technical problems. First, outside the Legal Amazon PRODES data is organized by biome geometry (shapefiles), not by municipal geocode — but every IBAMA infraction record contains GPS coordinates (`NUM_LATITUDE_AUTO`, `NUM_LONGITUDE_AUTO`). A spatial join between those coordinates and biome boundary polygons replaces the geocode-based join. Second, PRODES uses different methodologies across biomes — distinct minimum detection areas, vegetation class definitions, and coverage periods — making direct km² comparisons across biomes unsound. Intra-biome normalization (percentile ranks or z-scores) resolves this before the EGS formula is applied.

Both problems have tractable solutions with the same toolstack already in use. The Legal Amazon is the proof of concept. A national system is the logical extension.

---

## Skills Demonstrated

- End-to-end monitoring system design from public administrative data
- KPI construction combining satellite imagery data and administrative records
- SQL pipeline: multi-source ingestion, cleaning, temporal join across heterogeneous identifiers, composite index calculation, streak/persistence logic
- Applied log transformation and geometric mean for skewed environmental data
- Empirical validation of methodological decisions (materiality threshold, join timing sensitivity)
- Explicit statement of indicator validity, interpretive limits, and case-by-case screening against alternative explanations
- Power BI dashboard for operational decision support (in progress)
