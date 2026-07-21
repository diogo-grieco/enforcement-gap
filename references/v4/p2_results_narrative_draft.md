# Enforcement Gap Monitoring System — Results Narrative
## Draft v3
**Status:** Resultados definitivos incorporados (pipeline v5, confirmado em produção 2026-07-12). Pendente: Power BI visuals, verificação adicional de casos além de Barra do Bugres, revisão editorial das fontes externas.

---

## What the data shows

Across the Brazilian Legal Amazon, 18 years (2008–2025), the pipeline produces 14,490 municipality-year observations. Under the current, production-confirmed classification (materiality threshold ≥1 km², IPCA-deflated fine values, base year 2025):

| tipo_egs | n | % |
|---|---|---|
| completo | 3,285 | 22.7% |
| gap_absoluto | 3,063 | 21.1% |
| sem_pressão | 8,142 | 56.2% |

p75 EGS = 0.7027106414917799.

**These numbers are not comparable to earlier drafts of this narrative.** An earlier version cited 41.2% gap_absoluto (5,966 cases); a later intermediate pipeline version cited over 50% completo. Both were superseded by two methodology fixes: consistent application of the 1 km² materiality threshold to the gap_absoluto/sem_pressão boundary (previously the threshold was documented but not applied there), and deflation of fine values to a common 2025 base. The materiality fix alone moved roughly 700 municipality-years — clearings under 1 km² with no enforcement record — out of gap_absoluto and into sem_pressão, since sub-1-km² clearing is at or below what any realistic inspection would target. **This is a measurement correction, not evidence that enforcement changed.** Any comparison to the earlier percentages should say so explicitly.

21.1% of observations are gap_absoluto: material deforestation (≥1 km²) detected by PRODES with no IBAMA infraction on record in that municipality-year. In roughly one in five cases where satellite imagery confirmed material forest loss, the federal enforcement system left no administrative trace.

The persistence analysis (minimum 3 consecutive years above the streak threshold, aligned with the electoral cycle) is what turns this from a single-year anomaly into a structural claim. The rankings below are ordered by `priority_score = log(max_streak) × log(1 + total_desmatado_km²)`.

---

## Where enforcement never arrived — gap_absoluto top 10

| # | Município | UF | Streak | km² acumulados | Período | priority_score |
|---|---|---|---|---|---|---|
| 1 | Governador Luiz Rocha | MA | 18 | 106.8 | 2008–2025 | 2.552 |
| 2 | Barra do Bugres | MT | 16 | 101.1 | 2008–2023 | 2.419 |
| 3 | Fortuna | MA | 13 | 107.1 | 2008–2025 | 2.266 |
| 4 | Tefé | AM | 12 | 117.5 | 2010–2025 | 2.238 |
| 5 | São Domingos do Maranhão | MA | 10 | 168.5 | 2008–2023 | 2.229 |
| 6 | Santa Rosa do Purus | AC | 18 | 52.9 | 2008–2025 | 2.174 |
| 7 | Floresta do Araguaia | PA | 12 | 85.3 | 2008–2023 | 2.089 |
| 8 | Arame | MA | 7 | 223.3 | 2008–2022 | 1.987 |
| 9 | Santo Afonso | MT | 14 | 50.6 | 2008–2021 | 1.963 |
| 10 | Viseu | PA | 9 | 112.4 | 2008–2025 | 1.961 |

For each of these ten, this round of research specifically searched for the two alternative explanations that would disqualify an "impunity" reading: (a) legally authorized clearing under AUTEX/DOF permits, and (b) state-level environmental enforcement not captured in the federal IBAMA dataset. Findings, by case:

**Governador Luiz Rocha (MA)** — 18 consecutive years, 106.8 km², no federal enforcement record. No specific evidence of authorized clearing or a documented state enforcement program covering this municipality was found. General context: Maranhão's state environmental secretariat (SEMA-MA) has publicly acknowledged rising deforestation pressure and created a strategic anti-deforestation committee (CEDIF) only in 2024–2025, well after most of this streak accumulated — consistent with, not contradicting, a long-standing enforcement gap.

**Barra do Bugres (MT)** — 16 consecutive years, 101.1 km². **This case carries a confirmed caveat.** State data (Sema-MT satellite monitoring, January–March 2022) indicates approximately 99% of a 1,573-hectare clearing episode in the municipality during that window was legally authorized. This is a real, sourced finding, not a hypothesis — it should be stated plainly in the final narrative, and Barra do Bugres should be **excluded from or heavily qualified in any "worst enforcement failures" framing**. Its continued presence in the gap_absoluto ranking is methodologically correct (PRODES detects clearing, IBAMA has no infraction record for it), but the substantive interpretation is "authorized clearing outside the federal permitting/monitoring interface," not "unpunished illegal deforestation."

**Fortuna (MA)** — 13 years, 107.1 km². No specific evidence of authorized clearing or state-level enforcement coverage found in this round of research.

**Tefé (AM)** — 12 years, 117.5 km², 2010–2025. Tefé sits on the Solimões River adjacent to the Mamirauá Sustainable Development Reserve; the region has been reported (Amazon carbon-flux literature) to have shifted from a net carbon sink to a net carbon source around 2019. No specific AUTEX/DOF or state-enforcement evidence was found that would disqualify this case.

**São Domingos do Maranhão (MA)** — 10 years, 168.5 km². No specific alternative-explanation evidence found. Groups with Governador Luiz Rocha and Fortuna as a Maranhão cluster (3 of the top 10), consistent with a regional pattern of weaker federal enforcement presence at the Amazon–Cerrado frontier.

**Santa Rosa do Purus (AC)** — 18 years (tied for longest streak), 52.9 km², on the Peruvian border in the Purus basin, an area of significant indigenous territorial overlap. No specific alternative-explanation evidence found.

**Floresta do Araguaia (PA)** — 12 years, 85.3 km². Search results returned general information on Pará's AUTEX/DOF forestry-authorization framework but no record tying an authorized-clearing program specifically to this municipality. No disqualifying evidence found.

**Arame (MA)** — 7 years, 223.3 km² (largest accumulated area in this top 10 despite the shortest streak). Web research found that Arame is one of the municipalities where the indigenous rights organization Coapima documents ongoing illegal timber extraction, and that SEMA-MA describes generally expanding — not specifically Arame-targeted — inspection capacity. This reinforces rather than undermines the enforcement-gap reading: illegal extraction is documented, and state response is described in general terms rather than as a specific enforcement program covering this municipality.

**Santo Afonso (MT)** — 14 years, 50.6 km². No municipality-specific results were found; broader Mato Grosso search results returned IBAMA operations in other municipalities (e.g., Colniza) but nothing tying authorized clearing or dedicated state enforcement to Santo Afonso specifically.

**Viseu (PA)** — 9 years, 112.4 km². No municipality-specific results found. Pará's SEMAS state monitoring system (LDI — Lista de Desmatamento Ilegal) exists and is active, but no record was found of it covering Viseu specifically during this period.

**Summary of the screening exercise:** of ten cases checked, one (Barra do Bugres) has a confirmed, sourced disqualifying caveat and should be reframed or excluded from headline "worst case" claims. The other nine returned no evidence — positive or negative — specific enough to confirm or disqualify them individually. That is the honest state of verification: these nine remain the system's best current candidates for a genuine enforcement gap, not confirmed findings. Any published narrative should say exactly this, rather than implying all ten were individually verified.

---

## Where enforcement is present but disproportionate — completo top 10

Among municipalities with documented enforcement activity, 43 sustained EGS above the 75th percentile (p75 = 0.7027) for three or more consecutive years.

| # | Município | UF | Streak | km² acumulados | Período | priority_score |
|---|---|---|---|---|---|---|
| 1 | Moju | PA | 7 | 735.2 | 2008–2024 | 2.423 |
| 2 | Itaituba | PA | 5 | 1,240.9 | 2018–2022 | 2.163 |
| 3 | Itupiranga | PA | 6 | 528.9 | 2008–2013 | 2.120 |
| 4 | Peixoto de Azevedo | MT | 6 | 467.3 | 2020–2025 | 2.078 |
| 5 | Jacareacanga | PA | 7 | 246.5 | 2012–2018 | 2.023 |
| 6 | Aripuanã | MT | 5 | 707.5 | 2018–2022 | 1.992 |
| 7 | Novo Repartimento | PA | 4 | 1,586.6 | 2008–2022 | 1.927 |
| 8 | Prainha | PA | 5 | 451.6 | 2013–2024 | 1.856 |
| 9 | Tailândia | PA | 6 | 241.4 | 2020–2025 | 1.856 |
| 10 | União do Sul | MT | 5 | 394.0 | 2020–2024 | 1.815 |

Unlike the gap_absoluto list, this ranking is dominated by cases with strong, independently documented federal enforcement activity — which is exactly what the "completo" classification requires (enforcement present, but disproportionate to pressure). None of the alternative-explanation checks apply here in the same way, since by definition IBAMA has already recorded federal action in these municipalities; the relevant question is whether that action is proportionate, not whether it exists.

**Moju (PA)** — 7-year streak (2008–2024), 735.2 km². IBAMA operations in 2025–2026 ("Operação Metaverso") identified 21 suspected phantom/front-company timber operations in the surrounding Pará region and applied over R$107.5 million in fines tied to fraudulent forest-credit schemes centered on Moju and neighboring Tailândia. This is consistent with the EGS reading: enforcement exists, is well documented, and is still outpaced by the volume of illegal activity uncovered.

**Itaituba (PA)** — 5-year streak (2018–2022), 1,240.9 km² — the largest accumulated area in the completo top 10. Between January and August 2023, Itaituba and neighboring Jacareacanga together generated 9,017 illegal-mining (garimpo) alerts, 41% of the national total; IBAMA suspended over 300 mining permits in the adjacent Tapajós APA in a 2024–2025 operation. Note: an earlier narrative draft cited 1,739 km² for Itaituba and a 2008–2022 period — those figures are superseded by the current pipeline and should not be reused.

**Itupiranga (PA)** — 6-year streak (2008–2013), 528.9 km². Federal Highway Police (PRF) seized 550 m³ of illegally transported timber near Itupiranga in 2022, including protected Bertholletia excelsa (Brazil nut). IBAMA has run embargo-enforcement operations against irregular use of previously-embargoed areas in the broader southeastern Pará region.

**Peixoto de Azevedo (MT)** — 6-year streak (2020–2025), 467.3 km². Holds the third-largest mining-designated area of any Brazilian municipality (128 km², per MapBiomas). A multi-agency operation ("Rastro de Érebo," October 2025) dismantled illegal mining cooperatives on the Peixoto and Peixotinho rivers. Local reporting has also raised conflict-of-interest concerns about the municipal environment secretariat's ties to mining interests — relevant institutional context, not independently verified by this project.

**Jacareacanga (PA)** — 7-year streak (2012–2018), 246.5 km², overlapping the Terra Indígena Munduruku. A multi-agency federal task force (Operação Desintrusão TI Munduruku) has run since late 2024, reporting over R$74 million in damage imposed on illegal mining infrastructure by December 2024 alone.

**Aripuanã (MT)** — 5-year streak (2018–2022), 707.5 km². IBAMA operations dismantled illegal mining within the Aripuanã indigenous park in 2025; mining-alert data shows the area remained active into 2025 despite enforcement, with mercury contamination affecting the Cinta Larga territory.

**Novo Repartimento (PA)** — 4-year streak (2008–2022), 1,586.6 km² — the second-largest accumulated area in the completo top 10. IBAMA's "Operação Metaverso I" (March 2026) inspected this municipality directly; a separate 2024 operation embargoed over 600 hectares of native forest near Vila Maracajá within Novo Repartimento, including illegal extraction of protected Brazil nut trees.

**Prainha (PA)** — 5-year streak (2013–2024), 451.6 km². IBAMA data shows deforestation alerts across nearly 9,000 hectares in the broader Santarém–Belterra–Mojuí dos Campos–Prainha cluster; following an MPF recommendation, IBAMA added inspection operations covering this area to its 2025 National Environmental Protection Plan.

**Tailândia (PA)** — 6-year streak (2020–2025), 241.4 km². One of the municipalities historically most associated with illegal timber extraction in Pará; a 2026 civil case against a Tailândia-based lumber company (Mademata Madeiras da Mata) raised court-ordered damages from R$376,000 to R$4.3 million plus R$218,000 in collective moral damages. IBAMA's "Operação Maravalha" (February 2026) targeted the regional timber supply chain and seized 15,000 m³ of sawn wood with over R$110 million in fines.

**União do Sul (MT)** — 5-year streak (2020–2024), 394.0 km². No municipality-specific enforcement record was found; search results returned only general Mato Grosso-wide IBAMA/Federal Police operations (e.g., near General Carneiro, in a Reserva da União area) without confirming direct action in União do Sul itself. This case should be flagged as unverified pending more targeted research before publication.

---

## Cases from earlier drafts that no longer belong in the headline narrative

Earlier versions of this document built the "validation" argument heavily around **Apuí (AM)** — citing R$173 million in fines, a 2025 vice-mayor arrest, and an April 2026 IPAAM fine under "Operação Tamoiotatá 6." Under the current v5 pipeline, Apuí ranks **20th** in the completo list (priority_score 1.489, 2020–2022, 1,321.2 km²) — no longer a top-10 case. Those specific figures were not re-verified in this round of research (the scope was the current top 10 of each ranking) and should **not** be repeated in the final narrative without independent re-verification. If the Apuí case is kept as a secondary illustration of the system's predictive logic, it should be labeled explicitly as unverified-in-this-pass and re-checked before publication — consistent with treating it as a claim, not a fact.

The same applies to **Porto de Moz** and **Graça Aranha**, both featured in earlier drafts and both now outside the top 10 of their respective rankings (Porto de Moz is #42 in completo; Graça Aranha is #16 in gap_absoluto). Their specific figures (fine amounts, protected-area proximity claims) were not re-checked this round and should be dropped from the headline narrative or clearly marked as pending verification if retained.

---

## An institutional explanation

Earlier drafts asserted a specific narrative about IBAMA budget cuts (a ~43% cut in surveillance budget between 2019–2020, 41% budget execution by 2021 versus 86–92% in prior years, staffing falling to ~500 inspectors). **These figures were not re-verified in this research round** and are retained here only as a flag: before publication, they need independent sourcing or should be removed. The general direction — that federal enforcement capacity was constrained during part of the period this dataset covers — is broadly consistent with public reporting on IBAMA in 2019–2022, but the specific numbers should not be presented as confirmed without a citation check.

---

## Validation: what the screening exercise actually supports

The most defensible validation claim from this round of research is narrower than earlier drafts suggested. It is not "the system found what agencies later confirmed" — that claim rests on the Apuí case, which is no longer in the current top 10 and was not re-verified here. The defensible claim is:

1. The completo top 10 (Moju, Itaituba, Itupiranga, Peixoto de Azevedo, Jacareacanga, Aripuanã, Novo Repartimento, Prainha, Tailândia) is corroborated by independently documented, recent (2024–2026) federal enforcement operations for nine of ten cases — real operations, real fines, real seizures, in the same municipalities the index flags as having enforcement present but disproportionate. União do Sul is the one exception with no corroborating record found.
2. The gap_absoluto screening process — checking top candidates against authorized-clearing and state-enforcement alternative explanations before publishing an "impunity" claim — correctly identified one confirmed exception (Barra do Bugres) out of ten. That is the system working as intended: it does not claim illegality, it flags candidates for verification, and verification changed the interpretation of one case in ten.

This is a more modest, more defensible claim than "the system predicts enforcement three years in advance" (the old Apuí framing), and it should replace that framing in the final narrative.

---

## Beyond the Amazon: what a complete system would do

This analysis covers the Brazilian Legal Amazon. The same enforcement gap plausibly exists in the Cerrado, the Caatinga, and the Mata Atlântica. Two technical problems currently block extension to those biomes, both with identified solutions: replacing the municipal geocode join with a spatial join on IBAMA GPS coordinates, and normalizing deforestation values within biomes before index calculation. Both are tractable with the existing toolstack. The Legal Amazon is the proof of concept. A national system is the logical extension.

---

## What this system does not resolve

The municipalities identified here are not confirmed illegal deforesters. PRODES measures satellite-detected forest loss; some portion may be authorized — confirmed for Barra do Bugres, not ruled out for the rest of the gap_absoluto top 10. IBAMA records federal enforcement actions; state-level agencies are not systematically captured, though targeted research found no specific state-enforcement program covering any of the other nine gap_absoluto cases. High EGS does not establish guilt — it establishes a signal worth investigating, and this document should be read as a record of that investigation, including where it came up empty.

What the system resolves is the prioritization problem: given constrained inspection capacity, where is the institutional response most disproportionate to observed pressure, and where has that disproportionality persisted long enough to be structural?

---

*Note: this document draws on IBAMA press releases (gov.br/ibama), Sema-MT and SEMAS-PA state environmental agency sources, and general news coverage identified via web search on 2026-07-12, cross-checked against project2.duckdb pipeline v5 (confirmed in production 2026-07-12: completo=3,285/22.7%, gap_absoluto=3,063/21.1%, sem_pressão=8,142/56.2%, p75=0.7027106414917799). The institutional-budget-cuts section and all facts specific to Apuí, Porto de Moz, and Graça Aranha are carried over from an earlier draft (2026-05-02) and were NOT re-verified in this round — they require independent citation checks before publication. External sources throughout are preliminary; final citations pending editorial review.*
