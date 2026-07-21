# Enforcement Gap Monitoring System — Results Narrative
## Draft v3
**Status:** Rewritten for the redesigned methodology (pipeline v5, 2026-07-20; unified EGS formula, single ranking, all 54 pipeline checks passing in DuckDB — 51 after the audit patch, plus 3 guards added by the third audit of 2026-07-20). Supersedes v2 (2026-05-02) entirely — the streak-based rankings, priority_score, and municipality-level gap classification described there no longer exist in the pipeline. Pendente: Power BI visuals, final citations.

---

## What the data shows

Across the 805 municipalities of PRODES's municipal panel for the Legal Amazon (the official delimitation counts 772 municipalities; PRODES includes partially contained ones) over 18 years (2008–2025), the system identifies a persistent and geographically concentrated pattern: deforestation continues, year after year, in places where the federal enforcement response is either absent or bears no meaningful relationship to the pressure being measured.

Of 14,490 municipality-year observations, 56.2% (8,142) register no material deforestation pressure (below 1 km² in the year — a threshold sensitivity-tested against PRODES's own 6.25 ha minimum mapping unit and against no threshold at all; the top 50 of the ranking is identical under all three; Spearman 0.985 (1 km² vs 6.25 ha) across all 805 municipalities). Among the 6,348 observations with material pressure, the split is nearly even: 3,063 (21.1% of all observations) are absolute gaps — deforestation detected by PRODES with no federal fine on record in that municipality-year — and 3,285 (22.7%) are measured gaps, where fines exist but fall short of the registered pressure. 552 of the 805 municipalities experienced at least one year of material pressure.

These figures are not comparable to earlier drafts of this document. The previous version reported "41.2% gap_absoluto" — a number produced by a design that classified entire municipalities into separate absolute/complete rankings, counted any deforestation regardless of size, and ranked by consecutive-year streaks weighted through an ad hoc priority score. That design was discarded, not adjusted. The current index is a single formula applied uniformly to every municipality-year:

> **EGS = log(1 + deforested area) / max(1, √(log(1 + fines count) × log(1 + fine values, IPCA-deflated to 2025)))**, with EGS = 0 when area < 1 km².

The denominator floor makes the absolute gap a limiting case of the same formula rather than a separate branch: when the response is zero, the denominator floors to 1 and the score is the pure log-pressure. The ranking orders municipalities by the 18-year mean of this score, with no-pressure years entering as zeros. That zero-filled mean is itself a composite — algebraically, it equals mean severity in pressure years × the fraction of years with pressure (identity verified in the data to machine precision) — so persistence and intensity are both priced in, transparently, without a separate weighting scheme.

---

## The top of the ranking

The top 20 is dominated by Pará (16 municipalities), with two each from Maranhão and Amazonas — and every one of the 20 registers material pressure in all 18 years of the series. The leading cases are not episodes; they are two decades of uninterrupted imbalance.

**Cachoeira do Piriá (PA)** leads with a mean EGS of 1.179: 410 km² deforested across 18 years — a median of roughly 20 km² per year, every year — against 13 federal infraction notices and R$4.3 million in deflated fines in total. Thirteen of its eighteen years are absolute gaps. This is the profile the index was designed to surface: not the largest deforestation in the Amazon, but the most persistently unanswered. One tension worth naming: its 3-year mean (1.228) sits above its 18-year mean, while its slope is mildly negative (−0.010) — the recent situation is worse than the historical average, and the negative slope reflects early-series highs, not current improvement. By the recent-mean criterion applied to Aveiro below, the #1 case is also deteriorating relative to its own history.

**Porto de Moz (PA)** ranks second (1.175) — 501 km², 28 notices, R$21.6 million over 18 years, at the mouth of the Xingu adjacent to the Verde para Sempre extractive reserve. Porto de Moz is one of three municipalities that survived the complete redesign of the methodology (see below), which makes it the single most robust finding in the system. Notably, its recent trajectory is improving: the 2023–25 mean (0.930) sits well below its 18-year mean, a pattern consistent with intensified state enforcement in Pará in 2024–25 — though no source specific to Porto de Moz was found in this round of verification.

**Monte Alegre, Aveiro, and Alenquer (PA)** — ranks 3–5 — share a geography: the Baixo Amazonas/Calha Norte region, where several federal forest concession areas (Glebas Paru/Flota do Paru) overlap these municipalities. Aveiro is the most alarming current case in the top 20: its 3-year mean (1.508) far exceeds its 18-year mean (1.109) and its slope (+0.042) is the steepest deterioration in the top 20. (Outside the top 20, a handful of lower-ranked municipalities show even sharper recent surges — e.g. Nova Santa Helena/MT, 3-year mean 1.561 on an 18-year mean of 0.697 — the recency columns exist precisely to surface these regardless of historical rank.) Whatever is happening in Aveiro is happening now.

**Arame (MA)** and **São Domingos do Maranhão (MA)** — ranks 6 and 15 — carry the Maranhão pattern documented since the earliest version of this analysis: modest absolute volumes (353 and 193 km²) met with almost nothing (26 and 4 notices; R$3.7M and R$2.3M over 18 years). Both, however, show clearly negative slopes (−0.033, −0.034) and 3-year means near 0.72 — the eastern-Amazon gap is old and deep, but the recent direction is improvement.

**Cumaru do Norte (PA)** — rank 12 — is a different kind of case, and it must not be narrated as absence. Its raw IBAMA record shows 112 infraction notices across 12 of 18 years, totaling R$761.9 million deflated — including single notices in the tens of millions (R$54M in 2017, R$39M in 2008 and 2017, nominal). Federal enforcement showed up in Cumaru do Norte, repeatedly, at scale — and annual deforestation continued at 15–182 km² regardless. What the index registers here is not an enforcement gap in the sense of absence but in the sense of ineffectiveness: fines levied without apparent deterrent or collection effect. The system cannot distinguish these two mechanisms from administrative data alone; the distinction matters for what a response should look like.

---

## What survived the redesign — and what fell

Between v2 and v3 of this analysis, the methodology changed completely: streaks were replaced by zero-filled means, the two partitioned rankings by one, the priority score by an algebraic identity. Three municipalities from the old top lists survived into the new top 20: **Porto de Moz, Jacareacanga, and São Domingos do Maranhão**. Findings that persist across a full replacement of the method are the strongest the system produces.

The falls are as informative as the survivals:

**Governador Luiz Rocha (MA)** — the previous #1 absolute-gap case, with 18 consecutive years of unanswered deforestation — drops to rank 54. The streak is real and remains visible in the table (18 pressure years, zero notices ever). What changed is that magnitude now matters: its median annual clearing is 4.65 km², total 107 km² over two decades. The old design counted years; the new design weighs them.

**Itaituba (PA)** and **Apuí (AM)** — leaders of the old "enforcement present but disproportionate" ranking — drop to ranks 129 and 141. Both have enormous deforestation (2,780 and 3,192 km²) but also two of the larger federal responses in the dataset (561 and 845 notices; R$843M and R$1,027M deflated — for scale, the dataset maximum by fine value is Altamira, R$3.75bn on 1,454 notices; by notice count, Porto Velho, 2,938). The old ranking, weighting streaks and volume, effectively rewarded them for the size of their deforestation; the ratio-based index recognizes that the federal response there, whatever its sufficiency, is not disproportionally small on the scale the metric measures.

**Nova Nazaré (MT)** is the documented editorial decision of the new design. It has the highest raw severity in the dataset (mean EGS of 1.384 in its pressure years) — but only 2 of 18 years register pressure (11 km² in 2008, 63 km² in 2017). The zero-filled mean demotes it out of the top 10 entirely. A monitoring system for *persistent* gaps deliberately discounts isolated episodes; Nova Nazaré is the worked example of that choice and its cost, in the same register as the Barra do Bugres caveat below.

---

## Validation in time: the Apuí trajectory

The most consequential validation argument from v2 — that the system flags gaps before institutional responses arrive — survives the redesign, but it lives in the annual table (`egs_final`) and the recency columns, not in the 18-year ranking.

Apuí's annual series tells the story cleanly. In 2020–2022, deforestation exploded to a mean of 440 km²/year (peaking at 732 km² in 2022) while the federal response stayed flat (~47 notices/year in 2020–22, above the ~35/year of 2008–19 but nowhere near the tripling of deforestation): the annual EGS rose to its worst sustained stretch, averaging 0.743 over the three years (2021: 0.770). The single-year series maximum is actually 2009 (1.459) — an isolated one-notice year of exactly the near-floor type Fix S10 targets — which is why the sustained 2020–22 plateau, not the 2009 spike, is the meaningful peak. In 2023–2025 the response surged — 95 notices/year, R$115M/year in deflated fines, culminating in 118 notices and R$188M in 2025 alone, alongside the operations documented externally ([IBAMA's R$173M in fines and ~27,000 ha embargoed in 2025](https://www.gov.br/ibama/pt-br/assuntos/noticias/2025/ibama-aplica-r-173-milhoes-em-multas-por-desmatamento-no-sul-do-amazonas); [the arrest of the former vice-mayor in March 2025, Operação Máscara Rural](https://climainfo.org.br/2025/03/13/pf-e-ibama-prendem-ex-vice-prefeito-de-apui-por-desmatamento-ilegal/); IPAAM's Operação Tamoiotatá) — and deforestation fell to 173 km²/year. The annual EGS dropped to a 0.564 average.

The system's own summary columns capture exactly this: Apuí's 3-year mean (0.564) sits far below its 18-year mean (0.668), and its slope (−0.012) is negative. Its fall to rank 141 in the 18-year ranking is not the index missing a known hotspot — it is the index correctly recording that the response arrived. A monitoring instrument that never demoted anyone would not be measuring anything.

---

## External corroboration — and the caveat it sharpens

Eight of the top 20 — Cumaru do Norte, Itupiranga, Jacareacanga, Medicilândia, Mojuí dos Campos, Prainha, Santa Maria das Barreiras, and Santana do Araguaia — appear on the federal government's own priority list for deforestation action ([Portaria GM/MMA nº 1.202/2024](https://www.lex.com.br/portaria-mma-no-1-202-de-11-de-novembro-de-2024/): 81 municipalities accounting for ~71% of 2024 Legal Amazon deforestation, [28 of them in Pará](https://www.oliberal.com/para/para-tem-28-municipios-na-lista-dos-81-prioritarios-para-acoes-de-urgencia-contra-desmatamentos-1.887003)). A 40% overlap between a ratio-based gap index and a list built on entirely different criteria (raw deforestation volume and rates) is meaningful convergence — the two methods agree on a substantial core while each surfaces cases the other misses. The 2026 update to the list (Portarias GM/MMA nº 1.716/1.717) could not be obtained for this draft; the true overlap may be higher.

The same research sharpens the system's most important caveat. This index measures the **federal** enforcement gap — IBAMA infraction records are its only response data — and the states hosting 18 of the top 20 municipalities operate substantial enforcement apparatuses of their own that the pipeline cannot see. Pará's SEMAS has run an open transparency portal since March 2021, and Operação Curupira's official two-year balance (Feb 2025) records [1,792 integrated inspections, 471 infraction notices, and 521,000 ha embargoed](https://agenciapara.com.br/noticia/64422/em-dois-anos-operacao-curupira-registra-mais-de-17-mil-fiscalizacoes-integradas), with the state's deforestation falling from 3,299 km² to 2,362 km² across the operation's two PRODES years — the [28% drop in the state's 2024 deforestation](https://agenciapara.com.br/noticia/61124/para-tem-reducao-de-28-no-desmatamento-em-2024-aponta-inpe). (Figures corrected 2026-07-21, Fix S20 — an earlier draft cited an intermediate snapshot with no locatable source.) Amazonas's IPAAM applied [R$144.7 million in fines and interdicted 16,176 ha in Operação Tamoiotatá 2025](https://www.agenciaamazonas.am.gov.br/noticias/operacao-tamoiotata-2025-ipaam-aplica-r-1447-milhoes-em-multas-por-crimes-ambientais-no-sul-do-amazonas/), with Maués — rank 9 here — explicitly among its targets.

The consequence is interpretive, not computational. A high score in this system is compatible with at least three distinct situations: genuine enforcement absence; federal absence with active state substitution; and federal presence without effect (the Cumaru do Norte pattern). Distinguishing them requires the state-level data this MVP deliberately excludes — which is why the metric is named precisely, and why state data integration is the first item on the product horizon.

---

## An institutional explanation

The geographic concentration of the gap does not explain itself. The pattern is consistent with a documented supply-side constraint: between 2019 and 2020, IBAMA's surveillance budget was cut by approximately [43%](https://agendadeemergencia.laut.org.br/2021/02/orcamento-para-fiscalizacao-ambiental-no-ibama-e-icmbio-reduziu-em-mais-de-100-milhoes-entre-2019-e-2020/); by 2021 [only 41% of it was being executed (against 86–92% in the three prior years), with the inspector corps at its historical minimum — just over 500 inspectors, a 55% reduction over ten years](https://www.oc.eco.br/ibama-so-gastou-41-do-que-teve-para-fiscalizacao/). The index measures the output — response low relative to pressure — without identifying the mechanism. But it generates a testable profile: municipalities whose annual EGS peaks in 2019–2022 and declines after 2023 (Apuí is the type case; Porto de Moz and Mojuí dos Campos show the same signature in their 3-year means) are consistent with constant demand-side pressure meeting a temporary supply-side shock. That profile could support an event-study design if formal identification is required.

---

## What this system does not resolve

The municipalities identified here are not confirmed illegal deforesters. PRODES measures satellite-detected forest loss and does not distinguish authorized clearing — the Barra do Bugres problem documented in earlier versions applies with full force to the current top 20 — no AUTEX/DOF authorization check was performed for any of the 20 current cases — and no case should be published without that caveat attached. IBAMA records are the only response measure: state enforcement (demonstrably active in Pará and Amazonas), embargoes, seizures, criminal prosecution, and whether levied fines are ever collected are all invisible to the index. The EGS is ordinal in practice: the ranking is robust, but distances between scores have no direct substantive interpretation. And the 2025 PRODES figure may not be consolidated — the 3-year window includes it, flagged, by decision.

What the system resolves is the prioritization problem: given constrained inspection capacity, where has the federal response been most disproportionate to observed pressure — and where has that disproportion persisted long enough, across administrations and enforcement regimes, to be structural rather than episodic?

---

## Beyond the Amazon: what a complete system would do

This analysis covers the Brazilian Legal Amazon. The same gap exists in the Cerrado, Caatinga, and Mata Atlântica. Two technical problems block extension, both with identified solutions: replacing the municipal geocode join with a spatial join on IBAMA GPS coordinates, and normalizing deforestation within biomes before index calculation. Integration of state-level enforcement data — now demonstrated to be available for at least Pará (SEMAS open portal) and Amazonas (IPAAM operation reports) — is the third, and after the findings above, the most consequential. The Legal Amazon is the proof of concept. A national, multi-level system is the logical extension.

---

*Note: all quantitative EGMS claims are from project2.duckdb, pipeline v5 (2026-07-20), all 54 checks passing; the full 805-municipality table is in `egs_ranking`. External sources: MMA portarias, SEMAS-PA and IPAAM/Agência Amazonas releases, O Liberal, IBAMA press releases, and the investigative reporting cited in v2 (InfoAmazonia, Repórter Brasil, ClimaInfo). External citations verified 2026-07-21 (fourth audit, Fix S20): every quantitative external claim now carries a locatable source; the one open item is the annex list of Portaria GM/MMA 1.717/2026 (not yet obtained).*
