# Enforcement Gap Monitoring System

**Where should environmental enforcement agencies deploy limited inspection capacity?**

---

### The problem

Brazil monitors deforestation by satellite continuously. It has no integrated system to compare where forest loss is happening against where enforcement is actually responding. The result is invisible impunity — not because the data doesn't exist, but because it has never been systematically crossed.

---

### What this system does

Crosses PRODES annual deforestation data with IBAMA administrative infraction records for 800 municipalities in the Brazilian Legal Amazon, 2008–2025. Produces a single ranked output: which municipalities have sustained the largest gap between deforestation pressure and enforcement response, for the longest time.

**Core metric — Enforcement Gap Score (EGS):**

```
EGS = log(1 + deforestation km²) / √(log(1 + n_fines) × log(1 + fine_value))
```

High EGS = large deforestation, weak enforcement. The geometric mean in the denominator disaggregates enforcement presence from enforcement intensity — a municipality filing many low-value fines scores worse than one with proportionate sanctions.

---

### Decision output

| | |
|---|---|
| **Decision** | Prioritize environmental inspections |
| **Constraint** | N inspections/month — set by user in dashboard |
| **Rule** | Highest priority score with persistence ≥ 3 consecutive years |
| **Action** | Deploy to top-N ranked municipalities; escalate zero-enforcement cases for audit |

---

### What the data shows

**41.2% of all observations are gap_absoluto** — deforestation detected, zero enforcement on record that year. In more than four in ten cases where satellite imagery confirmed forest loss, the federal enforcement system left no administrative trace.

The gap_absoluto persistence ranking surfaces cases of systematic invisibility — not the famous arc-of-deforestation municipalities, but smaller places that have never generated a federal enforcement headline. **Governador Luiz Rocha (MA)**: 18 consecutive years of gap, 106 km² accumulated. **Santa Rosa do Purus (AC)**: 18 years, 53 km². **Floresta do Araguaia (PA)**: 16 years, 89 km².

Among municipalities with documented enforcement, **Apuí (AM)** is the strongest validation case: the system identified Apuí as a persistent high-gap municipality in 2020–2022. In 2025, IBAMA applied R$173 million in fines and embargoed 27,000 hectares. The former vice-mayor was arrested. The enforcement gap was in the data three years before the institutional response.

**Every top-ranked municipality in the completo list was the target of a major enforcement operation between 2023 and 2026.** The index found what enforcement agencies independently confirmed — using only satellite data and administrative records.

---

### Stack & scope

**Stack:** DuckDB · SQL · R · Power BI  
**Data:** PRODES/INPE (satellite deforestation) + IBAMA (administrative infractions)  
**Scope:** Brazilian Legal Amazon — 800 municipalities, 18-year panel

**This is an MVP.** Every IBAMA infraction record contains GPS coordinates. Replacing the municipal geocode join with a spatial join on those coordinates extends the same capability to all Brazilian biomes. The analytical problem is solved. What remains is scale.
