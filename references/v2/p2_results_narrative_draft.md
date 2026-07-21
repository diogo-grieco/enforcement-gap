# Enforcement Gap Monitoring System — Results Narrative
## Draft v2
**Status:** Resultados definitivos incorporados (pipeline corrigido, 2026-05-02). Pendente: Power BI visuals, verificação Barra do Bugres.

---

## What the data shows

Across 800 municipalities in the Brazilian Legal Amazon over 18 years (2008–2025), the system identifies a persistent and geographically concentrated pattern: deforestation continues, year after year, in places where federal enforcement either never arrives or arrives at a scale that bears no meaningful relationship to the pressure being measured.

41.2% of all municipality-year observations — 5,966 out of 14,490 — are classified as gap_absoluto: deforestation detected by PRODES with no IBAMA infraction on record in that municipality that year. In more than four in ten cases where satellite imagery confirmed forest loss, the federal enforcement system left no administrative trace.

This finding is substantially different from earlier versions of the analysis, which reported 57.7% gap_absoluto based on a date column with 69% null values. The corrected pipeline recovers enforcement records that were previously invisible — particularly for municipalities with lower volumes of infraction records. The 41.2% figure is more conservative, more accurate, and more defensible.

The persistence analysis makes this finding structural rather than anecdotal. Across both gap types, the municipalities at the top of the ranked list are not one-off failures. They are places where the same pattern repeated across electoral cycles, across administrations, and in some cases across nearly the entire span of the dataset.

---

## Where enforcement never arrived

The gap_absoluto persistence list is led by **Governador Luiz Rocha (MA)**: 18 consecutive years of detected deforestation with no federal enforcement record, 106 km² accumulated, priority score 2.552. The municipality exemplifies a pattern concentrated in the Maranhão portion of the Legal Amazon — a region where federal enforcement presence is structurally weaker and where smaller municipalities have never generated the operational attention that larger arc-of-deforestation cases attract. Eighteen years of uninterrupted gap across two decades and multiple federal administrations is not an oversight. It is a structural absence.

**Santa Rosa do Purus (AC)** matches the 18-year streak with 52.9 km² accumulated — a municipality in the western Amazon, adjacent to the Peruvian border and the Purus River basin, in a region with significant indigenous territorial overlap and historically limited federal enforcement reach.

**Floresta do Araguaia (PA)** and **Barra do Bugres (MT)** each sustained 16-year gaps. Barra do Bugres requires a caveat before inclusion in the final narrative: investigative reporting and state data indicate that a significant proportion of deforestation in this municipality may be legally authorized via AUTEX/DOF permits. If confirmed, the gap_absoluto classification is methodologically correct — PRODES records forest loss, IBAMA has no infraction record — but the interpretation shifts from impunity to authorized clearing. This case will be verified before the portfolio publication.

**Tefé (AM)** appears at rank 5 with a 12-year gap and 117.5 km². The Tefé region, situated on the Solimões River and adjacent to the Mamirauá Sustainable Development Reserve, shifted from a net carbon sink to a net carbon source around 2019. The absence of enforcement records over 12 years of cumulative deforestation, in a municipality adjacent to one of Brazil's most important protected areas, represents a significant institutional gap.

**São Domingos do Maranhão** and **Graça Aranha** — both in Maranhão — each appear in the top 20 with streaks of 10–12 years. The geographic concentration of Maranhão municipalities in the gap_absoluto list points to a state-level pattern: the Maranhão portion of the Legal Amazon sits at the frontier between the Amazon and Cerrado biomes, receives less monitoring attention than the more prominently discussed Pará and Mato Grosso fronts, and has been subject to significant land pressure from agricultural expansion with limited federal enforcement response.

**Porto de Moz (PA)** stands out despite a shorter streak (6 years): 276.2 km² accumulated between 2009 and 2019, producing the highest absolute deforestation volume of any municipality in the gap_absoluto top 20. Located at the mouth of the Xingu River, Porto de Moz is adjacent to the Extractivist Reserve Verde para Sempre — one of the largest sustainable use protected areas in the Amazon. The concentration of deforestation immediately outside protected area boundaries with no enforcement response is a pattern the system surfaces precisely.

---

## Where enforcement is present but disproportionate

Among municipalities with documented enforcement activity, 43 sustained EGS above the 75th percentile (p75 = 0.727) for three or more consecutive years — indicating that enforcement is occurring, fines are being levied, and infractions are being recorded, yet the volume and intensity fall systematically short of the deforestation pressure registered in the same years.

**Moju (PA)** leads this list with seven consecutive years above the threshold (2008–2023), 672 km² deforested during those years, and a priority score of 2.390. IBAMA operations in 2026 identified 21 suspected phantom and front-company timber operations in the Pará region, applying over R$110 million in fines. Moju's position at the top of the completo ranking reflects a pattern consistent with what the operations subsequently confirmed: enforcement is present but captured within a system where illegal timber extraction operates through layers of documentation designed to simulate compliance.

**Itaituba (PA)** ranks second with the largest deforestation volume in the completo list — 1,739 km² accumulated over a 5-year streak (2008–2022). Itaituba has been described as Brazil's capital of illegal gold laundering: between January and August 2023, Itaituba and neighboring Jacareacanga generated 9,017 garimpo alerts, representing 41% of national totals. IBAMA destroyed 100 machines and dismantled 29 illegal mining camps in the same period. The infraction records captured in the pipeline reflect enforcement against deforestation associated with garimpo operations — the enforcement gap score captures precisely the imbalance between what PRODES detects and what federal fines represent.

**Jacareacanga (PA)** ranks fifth with a 7-year streak overlapping the Terra Indígena Munduruku — one of the most contested territories in the Amazon. A multi-agency task force launched in November 2024 to remove illegal miners from the territory caused an estimated R$112 million in damage to the garimpo infrastructure. The enforcement gap the system identifies in Jacareacanga is inseparable from the political difficulty of operating in territories where illegal extraction is entrenched and where federal operations face organized resistance.

**Apuí (AM)** is the most analytically significant case in this ranking for one reason: timing. The system identifies Apuí as a persistent high-gap municipality across 2020–2022, with EGS consistently above the 75th percentile and 1,321 km² of deforestation during those three years. The institutional response arrived later: in 2025, IBAMA applied R$173 million in fines and embargoed approximately 27,000 hectares in the municipality. In March 2025, the Federal Police and IBAMA arrested the former vice-mayor of Apuí on charges of orchestrating illegal deforestation. In April 2026, the state environmental agency IPAAM applied an additional R$5.4 million in fines as part of Operação Tamoiotatá 6. Apuí had been described in federal enforcement documents as one of the epicenters of Amazon deforestation. The EGMS identified it as a high-gap case three years before the institutional response confirmed the diagnosis.

**Novo Repartimento (PA)** appears in the completo ranking at position 8 — a significant shift from its previous position as the top gap_absoluto case. With the corrected date column, Novo Repartimento's enforcement records are now visible in the pipeline: it has IBAMA infractions on record and is correctly classified as completo. The gap remains substantial: 1,586 km² of deforestation, a 4-year streak above the p75, priority score 1.927. Operação Metaverso (March 2026) applied over R$5 million in fines and embargoed 1,627 hectares across the Tucuruí-Novo Repartimento-Pacajá region. The reclassification from gap_absoluto to completo does not reduce the case's significance — it makes it more precise. Enforcement is present; it is proportionately inadequate.

**Peixoto de Azevedo (MT)** remains one of the most robust findings across both versions of the pipeline. At rank 4 with a 6-year streak (2020–2025), 467 km² deforested, and a priority score of 2.078, the result is not sensitive to the date correction — it was already in the top of the completo ranking before and remains there after. The municipality holds the third largest mining area in Brazil (128 km²), and environmental oversight is administered under the same municipal secretariat as mining and tourism. The institutional arrangement structurally limits dedicated environmental enforcement capacity, and the EGS reflects this year after year.

---

## An institutional explanation

The geographic concentration of the enforcement gap is real, but it does not explain itself. The pattern in the data is consistent with a structural constraint on the supply side of enforcement: between 2019 and 2020, IBAMA's budget for environmental surveillance was cut by approximately 43%. By 2021, only 41% of the surveillance budget was being executed — compared to 86–92% in the three prior years. IBAMA operated at its historically lowest staffing level, with approximately 500 inspectors, representing a 55% reduction over ten years.

This context does not appear directly in the EGS. The index measures the output — where enforcement is low relative to pressure — without identifying the mechanism. But it creates a testable hypothesis: municipalities that enter the persistent gap_absoluto list during 2019–2022, and return to enforcement activity after 2023, are consistent with a demand-side explanation (deforestation pressure was always there) coupled with a supply-side shock (enforcement capacity was curtailed). Several municipalities in the dataset match this profile and could support an event study design if formal identification is required.

---

## Validation: the system found what enforcement agencies later confirmed

The most direct validation comes from Apuí: system identifies high EGS in 2020–2022; federal and state operations arrive in 2025–2026. The gap was in the data. The enforcement followed.

The completo leaders — Moju, Itaituba, Jacareacanga, Novo Repartimento — were each the target of significant federal operations between 2023 and 2026. Peixoto de Azevedo has appeared on federal priority lists for deforestation prevention across multiple administrations. The convergence between the ranked output and the subsequent operational attention is not coincidental. It means the index is identifying the same pressure points that expert judgment, investigative journalism, and institutional enforcement planning independently reached — using only satellite deforestation data and administrative infraction records.

The more consequential version of this argument is temporal. The EGMS running in 2021 would have flagged Apuí as a persistent high-gap case. The enforcement response came in 2025. The gap was not hidden. It was unmonitored.

This is the practical case for the system: not that it discovers what agencies do not know, but that it makes the known legible, rankable, and actionable at a scale and speed that institutional knowledge alone cannot match.

---

## Beyond the Amazon: what a complete system would do

This analysis covers the Brazilian Legal Amazon. The same enforcement gap exists in the Cerrado, the Caatinga, and the Mata Atlântica. Two technical problems currently block extension to those biomes, both with identified solutions: replacing the municipal geocode join with a spatial join on IBAMA GPS coordinates, and normalizing deforestation values within biomes before index calculation. Both are tractable with the existing toolstack. The Legal Amazon is the proof of concept. A national system is the logical extension.

---

## What this system does not resolve

The municipalities identified here are not confirmed illegal deforesters. PRODES measures satellite-detected forest loss; some portion may be authorized. IBAMA records federal enforcement actions; state-level agencies are not captured. High EGS does not establish guilt — it establishes a signal worth investigating.

What the system resolves is the prioritization problem: given constrained inspection capacity, where is the institutional response most disproportionate to observed pressure, and where has that disproportionality persisted long enough to be structural?

---

*Note: this document draws on IBAMA press releases, investigative journalism (InfoAmazonia, Repórter Brasil, ((o))eco, ClimaInfo), and INPE/PRODES data. All quantitative claims from the EGMS are based on project2.duckdb as of 2026-05-02 (pipeline v2, DAT_HORA_AUTO_INFRACAO). External sources are preliminary — final citations pending editorial review.*
