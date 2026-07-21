# Enforcement Gap Monitoring System
## Narrative Draft v2 — Portfolio Layer
**Status:** Resultados definitivos incorporados. Pendente: Power BI screenshots, verificação Barra do Bugres.

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
- **Sem pressão:** No deforestation detected. No gap to measure.

---

## Key Design Decisions

**Why PRODES, not DETER.** DETER provides near-real-time deforestation alerts for field operations. PRODES is the audited annual series — the official reference for policy evaluation and historical comparison. A monitoring system oriented toward institutional accountability requires consistency over reactivity.

**Why the geometric mean in the denominator.** Enforcement has two dimensions that are not interchangeable: the number of acts (presence) and their financial weight (intensity). Summing them loses information. Multiplying their logs and taking the square root gives a combined measure that degrades gracefully when either dimension is weak. A municipality with 50 infractions totaling R$10,000 is not equivalent to one with 5 infractions totaling R$1,000,000 — and EGS treats them differently.

**Why log(1 + x) throughout.** Deforestation and fine values follow highly right-skewed distributions. Log-transforming compresses extreme values while preserving rank information and avoiding division by zero.

**Why the same-year join.** An earlier version of the index assumed a one-year enforcement lag. Empirical analysis across all 58,051 IBAMA records confirmed that the same-year join captures 4.4% of records that a t+1 join would miss, while the t+1 join would only recover 0.8% of additional records. The monthly distribution of infraction registrations peaks in September-October — aligned with the Amazon dry season and deforestation pressure — with no concentration in January-March that would indicate systematic response to the prior year. Same-year join confirmed and locked.

**Why 3 consecutive years as the persistence threshold.** Three years spans one Brazilian electoral cycle (4 years) with a one-year buffer. A municipality with a persistent gap across three consecutive years is exhibiting a structural pattern, not a one-off institutional failure or an election-year anomaly.

**Why the date of registration, not the date of the infraction.** The IBAMA field `DT_FATO_INFRACIONAL` (infraction date) is null in 69% of filtered records. The pipeline uses `DAT_HORA_AUTO_INFRACAO` — the date the infraction was formally registered — which has zero nulls across the full dataset. The tradeoff is explicit: registration date may differ from infraction date by days to months, introducing potential year misalignment in a minority of cases. Sensitivity analysis shows that approximately 17% of gap_absoluto municipality-years would shift category with a t+1 join — municipalities with multi-year streaks are robust to this uncertainty.

---

## What the Data Shows

The dataset covers 800 municipalities in the Brazilian Legal Amazon, 18 years (2008–2025), yielding 14,490 municipality-year observations.

**41.2% of observations are gap_absoluto** — 5,966 cases where PRODES recorded deforestation with no IBAMA infraction on record in that municipality and year. This is the most direct signal in the data: in more than four in ten cases where satellite imagery confirmed forest loss, the federal enforcement system left no administrative trace.

**The gap_absoluto persistence list reveals a different profile than expected.** The leading municipalities are not the high-profile arc-of-deforestation cases — they are smaller, systematically invisible municipalities that never appear in federal enforcement operations. Governador Luiz Rocha (MA) leads with 18 consecutive years of gap and 106 km² accumulated. Santa Rosa do Purus (AC) matches the 18-year streak with 53 km². Floresta do Araguaia (PA) and Barra do Bugres (MT) each sustained 16 years. These municipalities have never generated a major IBAMA enforcement headline — which is precisely the point.

**Among municipalities with documented enforcement (completo),** 43 sustained EGS above the 75th percentile for three or more consecutive years. The top case by priority score is **Moju (PA)** — 7 years above the threshold, 672 km² deforested, enforcement consistently present but proportionately inadequate. **Itaituba (PA)** ranks second with 1,739 km² and a 5-year streak — the largest deforestation volume in the completo ranking, driven by garimpo ilegal in the Tapajós basin.

**Apuí (AM) is the most significant validation case.** The system identified Apuí as a persistent high-gap municipality across 2020–2022. In 2025, IBAMA applied R$173 million in fines and embargoed 27,000 hectares in the municipality. In March 2025, the Federal Police and IBAMA arrested the former vice-mayor for illegal deforestation. In April 2026, the state agency IPAAM applied an additional R$5.4 million in fines under Operação Tamoiotatá 6. The enforcement gap was in the data three years before the institutional response materialized.

---

## Decision Output

The system is designed to answer one operational question: **where should enforcement capacity be directed next quarter?**

> Decision: Prioritize environmental inspections  
> Constraint: N inspections/month — capacity parameter set by the user in Power BI  
> Rule: Highest priority_score (log(streak) × log(1 + deforestation)) with persistence ≥ 3 consecutive years  
> Action: Deploy inspection team to top-N municipalities from the ranked list; escalate persistent gap_absoluto cases for targeted audit planning

The number of inspections is not hardcoded — it is a user-controlled parameter in the dashboard, allowing the system to adapt to whatever operational capacity the agency or team actually has.

---

## Interpretive Limits

This system does not measure illegality. PRODES records satellite-detected forest loss — some of this deforestation may be legally authorized via AUTEX/DOF permits. IBAMA records detected federal enforcement acts — municipalities with no federal records may be served by state-level agencies not captured in the dataset. EGS measures the ratio of observed pressure to observed response; it does not establish causality or confirm that a municipality is operating outside the law.

That caveat is not a weakness — it is the appropriate scope. The system identifies where a rational monitoring agency should look next, given the information available.

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
- Empirical validation of methodological decisions (lag analysis, join sensitivity)
- Explicit statement of indicator validity and interpretive limits
- Power BI dashboard for operational decision support (in progress)
