# P2 — Enforcement Gap Monitoring System
## Session Reference v5
**Last updated:** 2026-07-12
**Status:** Staging: deflator IPCA + `municipios_ref` (via API IBGE) implementados e validados em produção. Marts: filtro 3 casos estável (sem UF, por design — ver §4.11). Analytics: p75 dinâmico, classificação por materialidade consistente, `priority_score` (streak=1) resolvido, `uf`/`nome_municipio` propagados até os rankings. Script R: v4, seções IBAMA + PRODES + IPCA presentes. Pipeline completo (01→04) rodado pelo autor no DBeaver contra dados reais em 2026-07-12 — todos os checks relevantes confirmados, não apenas revisados em código.

---

### Changelog v5 (2026-07-12 — municipios_ref via API IBGE, UF fechada e validada)

- **`municipios_ref` implementada.** Fonte final: **API de localidades do IBGE** (`servicodados.ibge.gov.br/api/v1/localidades/municipios`, JSON), não o DTB/xls originalmente planejado — o site do DTB ficou inacessível ao autor. Estrutura do JSON **inspecionada com Python antes de escrever o SQL** (não presumida): 5.571 municípios, ids de 7 dígitos sem duplicata, 27 UFs, cobertura de UF de 100% via caminho `"regiao-imediata"."regiao-intermediaria".UF.sigla` (o caminho alternativo via `microrregiao` falha em 1 registro — Boa Esperança do Norte/MT).
- **UF/`nome_municipio` propagados**: join com `municipios_ref` movido para `egs_base` (03_analytics.sql), não para `ibama_clean` — decisão consciente, já que `municipios_ref` é a fonte de verdade também para `gap_absoluto` (sem registro em IBAMA). Chega até `egs_final`, `ranking_gap_absoluto` e `ranking_completo`.
- **Validado em produção**, não só em código: autor rodou `01_staging.sql` → `04_export.sql` no DBeaver contra os dados reais do projeto e confirmou os checks: `n_municipios_ref`=5.571, `geocodes_duplicados`=0, `geocode_ref_invalido`=0, `uf_ausente`=0, `sem_referencia`=0 (PRODES × municipios_ref), `sem_uf`=0 (egs_final).
- **NOVO — `data_root` configurável.** Paths relativos falharam ao rodar no DBeaver (resolvidos contra o cwd do processo, não a raiz do projeto); a correção imediata foi hardcode de path absoluto pessoal, depois substituída por `SET VARIABLE data_root` + `getvariable()` no topo de `01_staging.sql` — ponto único de configuração, portável entre DBeaver/CLI/R, motivado por preparação para publicação em GitHub/Zenodo. Ver Fix 14 em `p2_technical_fixes.txt`.
- **§4.11 (UF) deixa de ser "regressão registrada" e passa a "resolvido".** Bloco 6 do `p2_next_steps.md` (Power BI) não tem mais bloqueio técnico conhecido.
- **Sem alteração:** Barra do Bugres e quebras estruturais do PRODES seguem abertos — não fizeram parte deste ciclo.

> v4 (2026-07-10): deflator IPCA aplicado, p75 dinâmico, bug de `priority_score` resolvido, classificação por materialidade consistente — mas UF era uma regressão registrada (removida de `ibama_clean` sem substituto) e `municipios_ref` seguia comentada. Ver changelog v4 no documento anterior para o detalhamento completo.

---

## 1. Project Overview

Sem alteração desde v4. Ver documento anterior.

**Output types — atualização de status:**
- Ranked list of municipalities with persistent enforcement gap
- KPI classification by gap type (completo / gap_absoluto / sem_pressao)
- Dashboard with temporal and geographic filters (Power BI — **desbloqueado**, ver §4.11)

---

## 2. Infrastructure & Stack

| Layer | Tool |
|---|---|
| Storage / query engine | DuckDB (`project2.duckdb`) |
| Data exploration | R + tidyverse |
| Visualization | Power BI (pending connection; sem bloqueio técnico conhecido) |
| Data files | Configurável via `SET VARIABLE data_root` no topo de `01_staging.sql` (era hardcoded `C:/Users/diogo/projects/project2/`; ver Fix 14) |

**Schema structure:** sem alteração desde v3.

---

## 3. Data Sources

### 3.1 PRODES, 3.2 IBAMA, 3.3 IPCA/Sidra

Sem alteração desde v4 — ver documento anterior.

### 3.4 IBGE — municípios (NOVA nesta versão)

**Fonte:** API de localidades do IBGE, `servicodados.ibge.gov.br/api/v1/localidades/municipios`. Baixada manualmente via navegador em 2026-07-12 (fetch automatizado não retornou conteúdo; causa não diagnosticada — pode ser bloqueio de API ou incompatibilidade de content-type).
**Arquivo:** `data_ibge/municipios.json`.
**Formato:** JSON, array de objetos aninhados (município → microrregião → mesorregião → UF; e município → região imediata → região intermediária → UF, redundante e sempre consistente onde ambos existem).

**Estrutura verificada (Python, 2026-07-12) antes de qualquer SQL:**
- 5.571 municípios | ids de 7 dígitos, todos únicos | 27 UFs
- Caminho `microrregiao.mesorregiao.UF.sigla`: falha em 1 registro (Boa Esperança do Norte/MT — sem `microrregiao` cadastrada)
- Caminho `"regiao-imediata"."regiao-intermediaria".UF.sigla`: 0 falhas — usado no SQL final
- Os dois caminhos nunca divergem nos 5.570 registros em que ambos existem

**Carregamento:** `read_json_auto`, sem necessidade de conversão para CSV — DuckDB lê a estrutura aninhada nativamente, incluindo chaves com hífen (`"regiao-imediata"`) via identificador entre aspas.

**Tentativa anterior descartada:** DTB/IBGE oficial (`RELATORIO_DTB_BRASIL_2025_MUNICIPIOS`, formato `.xls`/`.ods`) — site ficou inacessível ao autor; nomes de coluna presumidos nunca foram verificados contra o arquivo real, então essa via foi abandonada antes de aplicar (ver Fix 12 em `p2_technical_fixes.txt` para o histórico completo da tentativa).

---

## 4. Methodological Decisions (Locked, salvo indicação em contrário)

### 4.1–4.10

Sem alteração desde v4 — ver documento anterior para o texto completo.

### 4.11 UF / `municipios_ref` (RESOLVIDA — era regressão registrada em v4)

`municipios_ref` implementada via API de localidades do IBGE (ver §3.4). Join movido para `egs_base` em `03_analytics.sql` — não para `ibama_clean` em `02_marts.sql` — porque a tabela precisa cobrir `gap_absoluto` (município-ano sem nenhum registro em `ibama_clean`), e o join por `ibama_clean` nunca cobriria esses casos. `mun` (PRODES, 5 homônimos entre estados) permanece nas tabelas por compatibilidade histórica; `nome_municipio` (de `municipios_ref`) é a fonte recomendada para exibição e para qualquer join/agrupamento por nome.

Validado em produção: pipeline completo executado pelo autor no DBeaver, checks de cobertura (`uf_ausente`, `sem_uf`) confirmados em 0.

---

## 5. Pipeline SQL — versão atual (2026-07-12)

### 5.1 Staging — configuração e municipios_ref (NOVO em relação à v4)
```sql
-- topo de 01_staging.sql — ponto único de configuração (Fix 14)
SET VARIABLE data_root = 'C:/Users/diogo/projects/project2';  -- editar por máquina

CREATE OR REPLACE TABLE project2.staging.municipios_ref AS
SELECT
    CAST(id AS VARCHAR)                                AS geocode_ibge,
    nome                                                AS nome_municipio,
    "regiao-imediata"."regiao-intermediaria".UF.sigla   AS uf
FROM read_json_auto(getvariable('data_root') || '/data_ibge/municipios.json');
```
Os demais `read_csv` de `prodes_raw`, `ibama_raw` e `ipca_deflator` passam a usar `getvariable('data_root') || '/...'` no lugar do path relativo original.

### 5.2 Analytics — egs_base com UF (atualizado em relação à v4)
```sql
CREATE OR REPLACE TABLE project2.analytics.egs_base AS
SELECT
    p.geocode_ibge, p.mun, r.uf, r.nome_municipio, p.ano, p.area_km2,
    COUNT(i.geocode_ibge)                        AS n_autos,
    COALESCE(SUM(i.val_multa), 0)                AS val_multas_nominal,
    COALESCE(SUM(i.val_multa), 0) * d.deflator   AS val_multas
FROM project2.marts.prodes_clean p
LEFT JOIN project2.marts.ibama_clean i ON p.geocode_ibge = i.geocode_ibge AND p.ano = i.ano
LEFT JOIN project2.staging.ipca_deflator d ON p.ano = d.ano
LEFT JOIN project2.staging.municipios_ref r ON p.geocode_ibge = r.geocode_ibge
GROUP BY p.geocode_ibge, p.mun, r.uf, r.nome_municipio, p.ano, p.area_km2, d.deflator;
```
`uf` e `nome_municipio` propagam sem transformação por `egs_final`, `ranking_gap_absoluto` e `ranking_completo` (entram no `SELECT` e no `GROUP BY` de cada CTE de streak).

Demais seções (`egs_final`, rankings, `resumo_anual`) sem alteração de lógica desde v4 — ver documento anterior ou `03_analytics.sql` para o texto completo.

---

## 6. Query Results

### 6.1 Checks confirmados em produção (2026-07-12)

| Check | Arquivo | Esperado | Confirmado pelo autor |
|---|---|---|---|
| `n_municipios_ref` | 01_staging.sql | 5.571 | ✅ 5.571 |
| `geocodes_duplicados` | 01_staging.sql | 0 | ✅ 0 |
| `geocode_ref_invalido` | 01_staging.sql | 0 | ✅ 0 |
| `uf_ausente` | 01_staging.sql | 0 | ✅ 0 |
| `sem_referencia` (PRODES × municipios_ref) | 01_staging.sql | 0 | ✅ 0 |
| `sem_uf` (egs_final) | 03_analytics.sql | 0 | ✅ 0 |

### 6.2 Distribuição por tipo_egs e p75 — confirmado em produção (2026-07-12)

| tipo_egs | n | % |
|---|---|---|
| completo | 3.285 | 22.7% |
| gap_absoluto | 3.063 | 21.1% |
| sem_pressao | 8.142 | 56.2% |
| **Total** | **14.490** | |

**p75 EGS (completo) = 0.7027106414917799** (dinâmico, `PERCENTILE_CONT`, pipeline v5 — materialidade `>=1` + deflator aplicados)

Confirmado pelo autor via execução real de `03_analytics.sql` no DBeaver, não recalculado por mim nesta sessão. `gap_absoluto` = 3.063 bate exatamente com o checkpoint cruzado R/SQL já registrado desde a v4 — consistência confirmada entre `exploring_script.R` (N_GAP_ABSOLUTO) e o pipeline SQL real.

**Comparação com pipeline v3 (histórico, critério `area_km2 > 0`, sem deflator):** completo 7.893 (54.5%) | gap_absoluto 3.784 (26.1%) | sem_pressao 2.813 (19.4%). A queda de `completo` (54.5%→22.7%) e o salto de `sem_pressao` (19.4%→56.2%) refletem sobretudo a mudança de threshold de materialidade (Fix 11): sob `area_km2 >= 1`, muito mais município-anos caem em `sem_pressao` (antes classificados por `area_km2 > 0`, um limiar bem mais permissivo). Não é uma mudança na metodologia de enforcement — é a mesma reclassificação documentada no Fix 11, agora com o efeito quantificado por completo.

**Ação para a próxima sessão:** regerar as tabelas de ranking (`ranking_gap_absoluto`, `ranking_completo`) sob o pipeline v5 antes de reincorporá-las à §6.3 — a composição dos top-N provavelmente mudou dado o novo p75 (0.703, vs. 0.589 hardcoded em v3/v4) e a redistribuição de `tipo_egs`.

### 6.3 Rankings — regenerados sob o pipeline v5, confirmados pelo autor (2026-07-12)

`ranking_gap_absoluto`: 200 municípios qualificados (streak ≥ 3, materialidade ≥ 1 km²). `ranking_completo`: 47 municípios qualificados (streak ≥ 3, egs ≥ p75 = 0.7027). Ambos conferidos por script (ordenação por `priority_score` validada, sem gaps de coluna) antes de entrar neste documento — não copiados manualmente linha a linha.

**Top 20 — ranking_gap_absoluto (de 200):**

| mun | UF | max_streak | total_km2 | primeiro_ano | ultimo_ano | priority_score |
|---|---|---|---|---|---|---|
| Governador Luiz Rocha | MA | 18 | 106.8 | 2008 | 2025 | 2.552 |
| Barra do Bugres | MT | 16 | 101.1 | 2008 | 2023 | 2.419 |
| Fortuna | MA | 13 | 107.1 | 2008 | 2025 | 2.266 |
| Tefé | AM | 12 | 117.5 | 2010 | 2025 | 2.238 |
| São Domingos do Maranhão | MA | 10 | 168.5 | 2008 | 2023 | 2.229 |
| Santa Rosa do Purus | AC | 18 | 52.9 | 2008 | 2025 | 2.174 |
| Floresta do Araguaia | PA | 12 | 85.3 | 2008 | 2023 | 2.089 |
| Arame | MA | 7 | 223.3 | 2008 | 2022 | 1.987 |
| Santo Afonso | MT | 14 | 50.6 | 2008 | 2021 | 1.963 |
| Viseu | PA | 9 | 112.4 | 2008 | 2025 | 1.961 |
| Piçarra | PA | 14 | 47.7 | 2010 | 2023 | 1.934 |
| Jutaí | AM | 12 | 59.1 | 2013 | 2024 | 1.920 |
| Coari | AM | 10 | 66.0 | 2016 | 2025 | 1.826 |
| Santa Maria das Barreiras | PA | 7 | 137.5 | 2017 | 2023 | 1.810 |
| Terra Santa | PA | 12 | 44.3 | 2013 | 2024 | 1.788 |
| Graça Aranha | MA | 12 | 42.0 | 2008 | 2019 | 1.763 |
| São José do Xingu | MT | 7 | 106.5 | 2019 | 2025 | 1.717 |
| Theobroma | RO | 9 | 61.2 | 2009 | 2024 | 1.712 |
| Nova Olinda do Norte | AM | 9 | 60.4 | 2008 | 2022 | 1.706 |
| Nova Esperança do Piriá | PA | 6 | 154.0 | 2008 | 2022 | 1.704 |

> **Barra do Bugres (MT) segue em #2.** Fix 4 (`p2_technical_fixes.txt`) ainda não foi verificado — % de desmatamento legal via AUTEX/DOF continua sem checagem externa. Não incluir este município em narrativa de "impunidade" sem antes fechar esse fix.

> **Comparação com v3 (histórico):** o top 5 mudou pouco em composição (Governador Luiz Rocha, Barra do Bugres, Fortuna, Tefé, São Domingos do Maranhão permanecem entre os primeiros), mas os `priority_score` absolutos não são diretamente comparáveis entre v3 e v5 — v3 não tinha threshold de materialidade `>=1` aplicado a todo o painel, então a base de streaks elegíveis mudou.

**ranking_completo — todos os 47 municípios qualificados (streak ≥ 3, egs ≥ p75):**

| mun | UF | max_streak | egs_medio | total_km2 | primeiro_ano | ultimo_ano | priority_score |
|---|---|---|---|---|---|---|---|
| Moju | PA | 7 | 1.046 | 735.2 | 2008 | 2024 | 2.423 |
| Itaituba | PA | 5 | 0.793 | 1240.9 | 2018 | 2022 | 2.163 |
| Itupiranga | PA | 6 | 1.012 | 528.9 | 2008 | 2013 | 2.120 |
| Peixoto de Azevedo | MT | 6 | 1.097 | 467.3 | 2020 | 2025 | 2.078 |
| Jacareacanga | PA | 7 | 0.876 | 246.5 | 2012 | 2018 | 2.023 |
| Aripuanã | MT | 5 | 0.804 | 707.5 | 2018 | 2022 | 1.992 |
| Novo Repartimento | PA | 4 | 0.917 | 1586.6 | 2008 | 2022 | 1.927 |
| Prainha | PA | 5 | 0.884 | 451.6 | 2013 | 2024 | 1.856 |
| Tailândia | PA | 6 | 1.067 | 241.4 | 2020 | 2025 | 1.856 |
| União do Sul | MT | 5 | 0.953 | 394.0 | 2020 | 2024 | 1.815 |
| Altamira | PA | 3 | 0.727 | 2189.0 | 2020 | 2022 | 1.594 |
| Rurópolis | PA | 4 | 0.942 | 426.8 | 2018 | 2021 | 1.584 |
| Nova Bandeirantes | MT | 4 | 0.773 | 421.5 | 2020 | 2023 | 1.581 |
| Candeias do Jamari | RO | 4 | 1.064 | 408.3 | 2016 | 2019 | 1.573 |
| Nova Maringá | MT | 4 | 1.114 | 390.0 | 2021 | 2024 | 1.561 |
| Grajaú | MA | 4 | 0.917 | 359.9 | 2008 | 2022 | 1.540 |
| Querência | MT | 5 | 1.052 | 158.0 | 2019 | 2023 | 1.539 |
| Rio Branco | AC | 4 | 0.858 | 351.6 | 2019 | 2022 | 1.534 |
| Mojuí dos Campos | PA | 4 | 0.958 | 316.9 | 2021 | 2024 | 1.507 |
| Apuí | AM | 3 | 0.743 | 1321.2 | 2020 | 2022 | 1.489 |
| Apiacás | MT | 4 | 0.836 | 285.4 | 2020 | 2023 | 1.479 |
| Portel | PA | 4 | 0.733 | 256.8 | 2008 | 2011 | 1.452 |
| Colniza | MT | 3 | 0.735 | 904.7 | 2020 | 2022 | 1.411 |
| Marabá | PA | 4 | 1.069 | 210.1 | 2020 | 2023 | 1.399 |
| Pacajá | PA | 3 | 0.746 | 633.4 | 2008 | 2010 | 1.337 |
| Barra do Corda | MA | 4 | 1.109 | 160.1 | 2009 | 2012 | 1.329 |
| Novo Aripuanã | AM | 3 | 0.846 | 599.8 | 2020 | 2022 | 1.326 |
| Cotriguaçu | MT | 4 | 1.024 | 150.3 | 2020 | 2023 | 1.312 |
| Placas | PA | 3 | 0.948 | 490.8 | 2014 | 2020 | 1.284 |
| Anapu | PA | 3 | 0.804 | 463.0 | 2019 | 2021 | 1.272 |
| Cláudia | MT | 4 | 1.126 | 123.9 | 2020 | 2023 | 1.262 |
| Nova Mamoré | RO | 3 | 1.158 | 357.4 | 2020 | 2022 | 1.219 |
| Aveiro | PA | 4 | 0.906 | 97.5 | 2009 | 2012 | 1.200 |
| Sena Madureira | AC | 3 | 1.089 | 290.1 | 2020 | 2022 | 1.176 |
| Juara | MT | 3 | 1.039 | 285.2 | 2021 | 2023 | 1.172 |
| Tarauacá | AC | 3 | 1.271 | 268.5 | 2020 | 2022 | 1.160 |
| Alenquer | PA | 4 | 0.844 | 82.8 | 2009 | 2012 | 1.158 |
| Buritis | RO | 3 | 0.955 | 263.6 | 2013 | 2022 | 1.156 |
| Vilhena | RO | 4 | 0.960 | 78.9 | 2019 | 2022 | 1.145 |
| Paragominas | PA | 3 | 0.873 | 223.2 | 2009 | 2011 | 1.122 |
| Maués | AM | 3 | 0.884 | 130.3 | 2023 | 2025 | 1.011 |
| Porto de Moz | PA | 3 | 1.030 | 124.7 | 2020 | 2022 | 1.002 |
| Juína | MT | 3 | 1.101 | 108.7 | 2021 | 2023 | 0.973 |
| Comodoro | MT | 3 | 0.894 | 94.7 | 2018 | 2020 | 0.945 |
| Bujari | AC | 3 | 0.830 | 79.0 | 2021 | 2023 | 0.908 |
| Tabaporã | MT | 3 | 0.854 | 57.2 | 2013 | 2015 | 0.842 |
| Chupinguaia | RO | 3 | 1.098 | 43.0 | 2019 | 2021 | 0.784 |

**Novidade em relação à v3:** todos os 47 municípios agora têm UF confiável (via `municipios_ref`), sem risco de homônimo — inclui, por exemplo, Alenquer (PA), que não tem par homônimo, mas outros casos como Pau D'Arco (PA, presente só no `ranking_gap_absoluto` desta lista) historicamente geravam ambiguidade contra o Pau D'Arco de TO antes do Fix 12.

---

## 7. Fixes — Status Final

> Numeração deste documento é independente da numeração em `p2_technical_fixes.txt`.

| Fix | Descrição | Status v4 | Status v5 |
|---|---|---|---|
| Fix 1–4, 9 (numeração antiga) | Filtros, coluna de data, join temporal | ✅ Aplicado/Locked | ✅ Inalterado |
| — | `ipca_deflator` no staging | ✅ Aplicado | ✅ Inalterado |
| — | p75 hardcoded vs. dinâmico | ✅ Resolvido | ✅ Inalterado |
| — | `priority_score`: `streak=1 → score=0` | ✅ Resolvido | ✅ Inalterado |
| — | classificação `tipo_egs`: materialidade ambígua | ✅ Resolvido | ✅ Inalterado |
| — | `sem_pressao`: `egs` 0 → NULL | ✅ Aplicado | ✅ Inalterado |
| **Fix 12** | `municipios_ref` + UF | ❌ Regrediu | ✅ **Resolvido e validado em produção** |
| **Fix 14** | Paths hardcoded → `data_root` configurável | *(não existia)* | ✅ **Novo, aplicado** |
| — | Barra do Bugres: legal vs. ilegal | ⚠ Aberto | ⚠ **Ainda aberto** |
| — | PRODES: quebras estruturais | ⚠ Aberto | ⚠ **Ainda aberto** |

---

## 8. Limitações Interpretativas

Sem alteração de conteúdo desde v3 (itens 1–7). **Item 8 da v4 removido** — "UF/nome de município não confiável" não se aplica mais: `municipios_ref` cobre 100% dos casos, incluindo `gap_absoluto`, e `nome_municipio` é a fonte recomendada em vez de `mun` (PRODES, com homônimos).

---

## 9. MVP Vision — Próximos Passos Analíticos

Sem alteração de conteúdo desde v3/v4 (expansão de biomas, extensões inferenciais).

---

## 10. Portfolio Integration

**Posicionamento:** sem alteração.

**Documento de próximas etapas detalhado:** `p2_next_steps.md`, atualizado em 2026-07-12.

**Próximas etapas em ordem (revisado):**
1. ~~Script R: seção IBAMA~~ ✅ CONCLUÍDO
2. ~~Script R: loading PRODES~~ ✅ CONCLUÍDO
3. ~~Staging: `ipca_deflator`~~ ✅ CONCLUÍDO
4. ~~Staging: `municipios_ref`~~ ✅ CONCLUÍDO (2026-07-12, via API IBGE)
5. ~~Analytics: streak + priority_score + p75~~ ✅ CONCLUÍDO
6. ~~Marts/Analytics: UF~~ ✅ CONCLUÍDO e validado em produção (2026-07-12)
7. **PRODES: quebras estruturais** ⚠ — único item aberto do Bloco 1 (script R), isolado
8. **Barra do Bugres** ⚠ — pesquisa externa, isolado
9. **Documentação:** README, apêndice metodológico, narrativas finais — sem bloqueio técnico agora, mas depende de regenerar os números da §6.2 (tipo_egs, p75) antes de citar
10. **Power BI** — sem bloqueio técnico conhecido; pronto para iniciar
11. Website + LinkedIn (após P1–P3 completos)

**Caminho crítico anterior (resolvido em 2026-07-12):** `municipios_ref` → UF → choropleth Power BI. Itens restantes (7 e 8) são isolados e não bloqueiam mais nada entre si.

**Documento de fixes técnicos:** `p2_technical_fixes.txt` v5 (2026-07-12) — 14 fixes (9 originais + 5 identificados/aplicados nas auditorias de código de 07-10 e 07-12).
