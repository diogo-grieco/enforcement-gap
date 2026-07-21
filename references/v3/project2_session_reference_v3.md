# P2 — Enforcement Gap Monitoring System
## Session Reference v3
**Last updated:** 2026-05-07  
**Status:** Pipeline v3 completo (Fix 8 + Fix 9 aplicados). Script R exploração: **seção IBAMA concluída e locked** (filtros, datas, multas, lags como comentários). Pendente: bloco PRODES no script R; revisão analytics layer (streak + priority_score); staging fixes (municipios_ref + ipca_deflator); Power BI; narrativas finais; Barra do Bugres.

**⚠ Priority flag:** verificar se `streak = 1 → priority_score = 0` está no código atual. `LOG(1) = 0` zera o score independente do volume de desmatamento — municípios com streak = 1 e área expressiva desaparecem silenciosamente do ranking completo.

---

### Changelog v3.3 (2026-05-07 — loading e exploração geral PRODES)
- **Loading PRODES documentado:** decisões de encoding, mutate, stopifnots
- **`geocode_ibge` já limpo no CSV** — cast via `as.numeric()` desnecessário e removido
- **`area km²` requer str_replace** — `decimal_mark` do locale não se aplica a colunas character
- **Painel balanceado confirmado:** 805 × 18 = 14.490
- **Distribuição area_km2 adicionada:** min=0, p25=0, mediana=0.56, p75=4.89, p90=21.1, max=797
- **Próximas etapas:** loading PRODES marcado como concluído

### Changelog v3.2 (2026-05-07 — cobertura PRODES × IBAMA)
- **IBAMA geocodes corrigido:** 2.655 → **2.806** (2.655 era do filtro antigo de 1 caso, pré-Fix 9)
- **Cobertura adicionada:** interseção 678, só-PRODES 127, só-IBAMA 2.128
- **Nota interpretativa:** 127 municípios só-PRODES = sem enforcement, não sem desmatamento

### Changelog v3.1 (2026-05-07 — atualização PRODES)
- **PRODES municípios:** 800 → **805** geocodes únicos (800 nomes únicos — 5 homônimos entre estados)
- **Painel balanceado confirmado:** 805 × 18 = 14.490 (todas as combinações município-ano presentes)
- **`mun` não é identificador único:** documentado como aviso em 3.1 e 3.3
- **Geocode conversion:** `as.character(as.integer(as.numeric(...)))` removido do script R — raw já contém strings limpas de 7 dígitos

### Changelog v3 (2026-05-07)
- **Status:** Script R seção IBAMA concluída e locked (filtros + datas + multas + lags como comentários)
- **Lag — n_lag corrigido:** 17.243 → **17.642**
- **Lag — média corrigida:** 235 dias → **271 dias**
- **Lag — direção explicitada:** `DAT_HORA_AUTO_INFRACAO - DT_FATO` (lavratura minus fato)
- **Lag — 355 descartados:** registros com lag < 0 descartados antes das análises (adicionado)
- **Lag — tabela corrigida:** todos os valores alinhados com script locked v3-2026-05-03
- **Val_multa total confirmado:** R$26.814.492.927 via `stopifnot` + `isTRUE(all.equal())`
- **Padrão técnico adicionado:** `isTRUE(all.equal(..., CONSTANTE))` para stopifnot com somas de ponto flutuante
- **Próximas etapas:** step 1 (script R IBAMA) marcado como CONCLUÍDO; próximo = PRODES

> v2 (2026-05-04): lag section tinha números preliminares (n=17.243, média=235d, tabela com base pré-correção). Todos corrigidos nesta versão para refletir o script locked.

---

## 1. Project Overview

**Decision question:** Where should enforcement agencies or monitoring teams increase inspection effort because current enforcement intensity is low relative to environmental risk?

**Primary users:** Environmental enforcement teams (IBAMA/state), NGO monitoring units, policy/donor organizations tracking territorial response capacity.

**Unit of analysis:** Municipality × year panel (Amazônia Legal, 2008–2025).

**Output types:**
- Ranked list of municipalities with persistent enforcement gap
- KPI classification by gap type (completo / gap_absoluto / sem_pressao)
- Dashboard with temporal and geographic filters (Power BI — pending)

---

## 2. Infrastructure & Stack

| Layer | Tool |
|---|---|
| Storage / query engine | DuckDB (`project2.duckdb`) |
| Data exploration | R + tidyverse |
| Visualization | Power BI (pending connection) |
| Data files | `C:/Users/diogo/projects/project2/` |

**Schema structure:**
```
project2.staging   → raw ingestion tables
project2.marts     → cleaned, typed, filtered tables
project2.analytics → final metrics and outputs
```

---

## 3. Data Sources

### 3.1 PRODES (TerraBrasilis)

**File:** `data_prodes/terrabrasilis_legal_amazon_25_04_2026_1777126839450.csv`  
**Delimiter:** `;` | **Decimal separator:** `,` | **Encoding:** UTF-8 (confidence 1.0, confirmado 2026-05-07)  
**Scope:** Amazônia Legal, annual deforestation by municipality, 2008–2025

**Loading (R):**
```r
prodes_raw <- read_delim(
  file.path(PATH_PRODES, FILE_PRODES),
  delim          = ";",
  locale         = locale(encoding = "UTF-8", decimal_mark = ","),
  col_types      = cols(.default = "c"),
  show_col_types = FALSE
)
```
`decimal_mark` no locale não se aplica a colunas forçadas como character — `area km²` requer `str_replace(",", ".")` antes de `as.numeric()`. `geocode_ibge` já é string limpa de 7 dígitos no CSV (sem ".0") — cast via `as.numeric()` desnecessário.

**Mutate decisions:**
```r
prodes_clean <- prodes_raw %>%
  mutate(
    ano      = as.integer(year),
    area_km2 = as.numeric(str_replace(`area km²`, ",", "."))
  ) %>%
  select(geocode_ibge, mun, ano, area_km2)
# uf: NA em todos os registros — descartado
```

| Field | Raw type | Clean type | Notes |
|---|---|---|---|
| year | VARCHAR | INTEGER | renomeado para `ano` |
| area km² | VARCHAR | DOUBLE | decimal vírgula → ponto; renomeado `area_km2` |
| mun | VARCHAR | VARCHAR | mantido |
| geocode_ibge | VARCHAR | VARCHAR | já limpo (7 dígitos, sem ".0") |
| uf | VARCHAR | — | descartado (100% NA) |

**Coverage stats:**
- 14,490 rows | **805 geocodes únicos** | 800 nomes únicos | 18 anos | **painel perfeitamente balanceado** (805 × 18 = 14.490; todo município com exatamente 18 observações)
- 5 municípios homônimos entre estados — `mun` não é identificador único; usar exclusivamente `geocode_ibge` em joins e group_by

**Distribuição area_km2 (todas as observações, n=14.490):**

| stat | valor |
|---|---|
| min | 0 |
| p10 | 0 |
| p25 | 0 |
| mediana | 0.56 |
| p75 | 4.89 |
| p90 | 21.1 |
| max | 797 |

~33% das observações com area_km2 = 0 (sem desmatamento detectado naquele ano). 67% (≈9.740) com area > 0. Distribuição fortemente assimétrica à direita — justifica threshold de detecção 1 km² e transformação LOG no EGS.

- **Limite de detecção PRODES: 1 km²** — threshold usado em análises agregadas

### 3.2 IBAMA

**Files:** `data_ibama/auto_infracao_ano_*.csv` (wildcard, múltiplos arquivos anuais)  
**Delimiter:** `;` | **Encoding:** UTF-8 (confirmado via `guess_encoding()`, confidence 1.0, 2026-05-03) | **All columns read as VARCHAR**  
**Total rows (raw):** 309,116 | **Colunas:** 84

**Colunas usadas:**

| Coluna | Notas |
|---|---|
| COD_MUNICIPIO | Código IBGE como VARCHAR (7 dígitos) — aliased como `geocode_ibge` nos marts |
| DT_FATO_INFRACIONAL | Data do fato infracional — **71% NULL no dataset filtrado. NÃO USADA.** |
| DAT_HORA_AUTO_INFRACAO | Data de lavratura do auto — **zero NULLs. DATA USADA NO PIPELINE.** |
| VAL_AUTO_INFRACAO | Valor da multa (decimal com vírgula) — 356 NAs (0.6%), dispersos por todos os anos |
| TIPO_INFRACAO | Tipo de infração — filtro: `Flora` |
| INFRACAO_AREA | Área da infração — filtro: `Desmatamento` apenas |
| SIT_CANCELADO | Flag de cancelamento — filtro: `N` |
| DES_STATUS_FORMULARIO | Status — filtro: `Lavrado` |
| NUM_LATITUDE_AUTO | Latitude do auto (disponível — útil para future spatial join) |
| NUM_LONGITUDE_AUTO | Longitude do auto (disponível — útil para future spatial join) |

**Após filtros (3 casos + Lavrado + não cancelado):**
- 60,707 registros | 2008–2025
- Case 1 (Flora + Desmatamento, ambos presentes): 58,051
- Case 2 (Flora + NA área + código explícito): 2,129 — concentrado 2008–2012, INFRACAO_AREA não era obrigatório no sistema inicial
- Case 3 (NA tipo + Desmatamento): 527 — mesmo padrão histórico

**Val_multa total (confirmado 2026-05-07):**
R$26.814.492.927 — verificado via `stopifnot(isTRUE(all.equal(sum(..., na.rm=TRUE), TOTAL_IBAMA_MULTAS)))`.  
Padrão `isTRUE(all.equal(...))` necessário porque `==` falha por ruído de ponto flutuante em somas longas — o valor impresso é idêntico mas a representação interna diverge na 15ª casa decimal.

> ⚠ **Nota metodológica:** `DAT_HORA_AUTO_INFRACAO` é a data de lavratura — quando o ato administrativo foi formalmente constituído — não a data do fato infracional. Ver seção 3.4 para análise de impacto.

**Qualidade do dado — completude de DT_FATO_INFRACIONAL:**
Análise sobre os 58.051 registros filtrados revelou correlação entre completude do registro e intensidade financeira. Municípios com mediana de multa abaixo de R$10k têm taxa de preenchimento de DT_FATO_INFRACIONAL de 2–7%. Municípios com multas medianas acima de R$300k têm 50–70% de preenchimento. Isso indica que operações de maior complexidade têm documentação mais completa — não que municípios famosos sejam melhor documentados. O pipeline antigo (usando DT_FATO_INFRACIONAL) tinha **viés por volume**: municípios com muitos autos retinham registros suficientes mesmo a 28–40% de completude; municípios com poucos autos ficavam com 0–4 registros válidos, insuficientes para qualquer streak.

### 3.3 Geographic Coverage

**Join key:** `prodes.geocode_ibge` = `ibama.geocode_ibge` (ambos VARCHAR 7 dígitos)

> ⚠ `mun` (nome) não é identificador único no PRODES — 5 pares de municípios homônimos entre estados. Usar exclusivamente `geocode_ibge` em joins e group_by.

- PRODES: 805 geocodes únicos (800 nomes únicos) | 18 anos | painel balanceado
- IBAMA (após filtros, 2008–2025): **2.806 geocodes únicos** (v2 dizia 2.655 — calculado com filtro antigo de 1 caso, pré-Fix 9)
- Interseção PRODES ∩ IBAMA: **678 municípios** (Amazônia Legal com enforcement registrado)
- Só em PRODES (não em IBAMA): **127 municípios** — zero enforcement federal registrado em 18 anos; sempre gap_absoluto no pipeline
- Só em IBAMA (não em PRODES): **2.128 municípios** — fora da Amazônia Legal; confirmado pelo LEFT JOIN estrutural

### 3.4 Lag analysis — join temporal ✅ RESOLVIDO

**Contexto:** o pipeline usa `p.ano = i.ano` para join entre PRODES e IBAMA. A justificativa exigia evidência de que o ano de lavratura (`DAT_HORA_AUTO_INFRACAO`) tende a coincidir com o ano de detecção do PRODES.

**Análise 1 — lag interno IBAMA (comprometida, registrada para histórico):**  
Calculada sobre 29% dos registros com `DT_FATO_INFRACIONAL` não-nulo (n=17.642). Direção: `DAT_HORA_AUTO_INFRACAO - DT_FATO` (lavratura minus fato; lag positivo = lavratura após fato). 355 registros com lag < 0 descartados (lavratura anterior ao fato — anomalia administrativa). Base resultante: n=17.642. Mediana 6 dias, média 271 dias — distribuição bimodal. Análise comprometida por seleção não-aleatória da base amostral e por medir pergunta errada (lag interno IBAMA, não alinhamento com PRODES).

> **Comparação v2 → v3:** v2 reportava n=17.243, média=235 dias (valores preliminares pré-script lock). Corrigido para n=17.642, média=271 dias.

**Distribuição por faixa de lag (base comprometida, informativa):**

| Faixa | n | Mediana multa |
|---|---|---|
| ≤7 dias | 8.954 | R$95k |
| 8–30 dias | 1.326 | R$154k |
| 31–365 dias | 3.321 | R$284k (pico) |
| 1–2 anos | 1.217 | R$215k |
| >2 anos | 2.469 | R$155k |

> **Comparação v2 → v3:** tabela v2 tinha n=9.047/1.344/3.412/1.248/2.183 e medianas R$152k/R$290k/R$209k/R$160k. Corrigido para valores do script locked.

Padrão: operações de maior valor têm lag interno mais longo. Análise confundida pela seleção — não causal.

**Distribuição mensal de lavraturas (n=60.707):**  
jan=2.6% | fev=5.3% | mar=7.2% | abr=8.4% | mai=9.8% | jun=9.6% | jul=9.2% | ago=9.6% | set=11.1% | out=10.3% | nov=9.8% | dez=7.1%.  
Pico set–out alinha com estação seca. Ausência de concentração jan–mar descarta resposta sistemática ao ano anterior. Evidência de suporte para join t+0 — não decisiva isoladamente.

**Análise 2 — alinhamento IBAMA × PRODES (decisiva, n=58.051):**
Para cada auto do IBAMA em ano t, verificou-se presença de desmatamento PRODES em t vs. t-1:

| Cenário | % dos registros |
|---|---|
| Desmatamento em t E t-1 (join indiferente) | 64.4% |
| Desmatamento só em t (join t correto, t+1 errado) | **4.4%** |
| Desmatamento só em t-1 (join t+1 correto, t errado) | **0.8%** |
| Sem desmatamento em nenhum (fora da Amazônia Legal) | 30.5% |

**Análise 3 — sensibilidade gap_absoluto:**
Com join t+1, 1.033 de 5.948 municípios-ano gap_absoluto (17.4%) mudariam de categoria. Não altera a decisão — confirma que streaks longas (≥3 anos) são robustas à incerteza de 1 ano.

**Conclusão:** `p.ano = i.ano` é empiricamente superior. **Locked.**

---

## 4. Methodological Decisions (Locked)

### 4.1 Fonte PRODES, não DETER
PRODES (anual, consolidado) — dado oficial auditado, referência de política pública. DETER é para operações de campo em tempo quase-real; não adequado para análise de painel histórico.

### 4.2 Escopo: Amazônia Legal
Join PRODES × IBAMA por geocode IBGE municipal funciona com alta cobertura e consistência histórica na Amazônia Legal. Em outros biomas, IBAMA indexa por coordenadas, não por geocode — join tabular inviável sem tratamento espacial adicional.

### 4.3 Filtros IBAMA

`SIT_CANCELADO = 'N'` + `DES_STATUS_FORMULARIO = 'Lavrado'` + 3-case OR:

| Case | Condição | Registros |
|---|---|---|
| 1 | `TIPO_INFRACAO = 'Flora' AND INFRACAO_AREA = 'Desmatamento'` | 58,051 |
| 2 | `TIPO_INFRACAO = 'Flora' AND INFRACAO_AREA IS NULL AND COD_INFRACAO IN (6 códigos)` | 2,129 |
| 3 | `TIPO_INFRACAO IS NULL AND INFRACAO_AREA = 'Desmatamento'` | 527 |
| **Total** | | **60,707** |

**CODIGOS_DESMATAMENTO** (6 códigos de 356 no dataset, identificados por leitura das descrições):
`409907`, `409901`, `452001`, `430001`, `431003`, `468001`

`409999` excluído: código genérico "Não Classificada-Móvel" (77.872 registros). Registros com INFRACAO_AREA = Desmatamento já capturados pelos Cases 1/3; os 14.710 restantes têm ambos TIPO e AREA como NA — sem sinal recuperável.

**"Desmatamento e Queimada" investigado e excluído (2026-05-03):**
2.051 registros válidos inspecionados. Flora subset (1.606): 1.579 são 409999 (mesmo código genérico da exclusão principal); 26 são 422006 (Sisflora — comércio de madeira, não desmatamento). Exclusão consistente com a lógica do filtro principal.

**INFRACAO_AREA NAs** (110.313 no total): concentrados em 2008–2012 — campo não obrigatório nas versões iniciais do sistema IBAMA. Não é falha de qualidade de dado.

**Caveat — Barra do Bugres (MT):** identificada como município com maior taxa de desmatamento *legal* do MT (99% de 1.573 ha autorizado via AUTEX/DOF). Se confirmado, o gap_absoluto desse município reflete ausência de ilegalidade registrada, não de enforcement. **PENDING: verificar proporção de desmatamento legal vs. ilegal antes de incluir na narrativa.**

### 4.4 Threshold `area_km2 >= 1`
Limite de detecção do PRODES. Valores abaixo de 1 km² são ruído de sensor.

### 4.5 EGS — nome e lógica
EGS alto = gap maior = prioridade maior. Numerador: pressão de desmatamento. Denominador: resposta de enforcement.

### 4.6 Fórmula EGS
```
EGS = LOG(1 + area_km2) / SQRT(LOG(1 + n_autos) * LOG(1 + val_multas))
```
- `LOG(1 + x)`: evita LOG(0), comprime extremos preservando ordenação
- Denominador = média geométrica de presença (n_autos) e intensidade (val_multas)
- Penaliza assimetria: municípios com muitos autos de multa ínfima não aparecem como bem-enforcement

### 4.7 Três tipos de EGS

| tipo_egs | Condição | EGS calculado |
|---|---|---|
| `completo` | n_autos > 0 AND val_multas >= 0.01 | LOG(1+area) / SQRT(LOG(1+n_autos) * LOG(1+val_multas)) |
| `gap_absoluto` | area_km2 > 0, sem enforcement qualificado | LOG(1+area_km2) |
| `sem_pressao` | area_km2 = 0 | 0 |

### 4.8 Persistência: ≥ 3 anos consecutivos
Ciclo eleitoral brasileiro (4 anos). Três anos consecutivos indica padrão estrutural, não conjuntural.

### 4.9 priority_score
`ROUND(LOG(max_streak) * LOG(1 + total_desmatado_km2), 3)` — produto de logs cria score bidimensional. Nenhuma dimensão domina completamente a outra.

> **⚠ Pendente revisão:** quando `max_streak = 1`, `LOG(1) = 0` → `priority_score = 0` independente do volume de desmatamento. Municípios com streak = 1 e área expressiva somem do ranking. Discutir se `LOG(streak + 1)` é mais adequado — pendente para a sessão de revisão do analytics layer.

### 4.10 Join temporal: mesmo ano ✅ LOCKED
`p.ano = i.ano` — confirmado empiricamente. Ver seção 3.4.

---

## 5. Pipeline SQL Completo

### 5.1 Schema Setup
```sql
CREATE SCHEMA IF NOT EXISTS project2.staging;
CREATE SCHEMA IF NOT EXISTS project2.marts;
CREATE SCHEMA IF NOT EXISTS project2.analytics;
```

### 5.2 Staging — PRODES
```sql
CREATE OR REPLACE TABLE project2.staging.prodes_raw AS
SELECT * FROM read_csv(
    'C:/Users/diogo/projects/project2/data_prodes/terrabrasilis_legal_amazon_25_04_2026_1777126839450.csv',
    delim = ';', header = true, decimal_separator = ','
);
```

### 5.3 Staging — IBAMA
```sql
CREATE OR REPLACE TABLE project2.staging.ibama_raw AS
SELECT * FROM read_csv(
    'C:/Users/diogo/projects/project2/data_ibama/auto_infracao_ano_*.csv',
    delim = ';', header = true, all_varchar = true
);
```

### 5.4 Mart — IBAMA Clean
```sql
CREATE OR REPLACE TABLE project2.marts.ibama_clean AS
SELECT
    COD_MUNICIPIO AS geocode_ibge,
    UF AS uf,
    -- DAT_HORA_AUTO_INFRACAO: data de lavratura formal — zero NULLs
    -- Substitui DT_FATO_INFRACIONAL (71% NULL). Ver Fix 8.
    EXTRACT(YEAR FROM CAST(DAT_HORA_AUTO_INFRACAO AS DATE)) AS ano,
    CAST(REPLACE(VAL_AUTO_INFRACAO, ',', '.') AS DOUBLE) AS val_multa
FROM project2.staging.ibama_raw
WHERE
    TIPO_INFRACAO             = 'Flora'
    AND INFRACAO_AREA         = 'Desmatamento'
    AND SIT_CANCELADO         = 'N'
    AND DES_STATUS_FORMULARIO = 'Lavrado';
```

> **Pendente (staging):** adicionar `municipios_ref` (geocode → nome → UF, fonte IBGE, ~5.570 linhas) como fonte de verdade para UF em todas as categorias, inclusive gap_absoluto onde ibama_clean não tem registro. Adicionar `ipca_deflator` (ano → deflator base 2025, fonte IBGE/Sidra) para Fix 2 (deflação de val_multas). Ambas as tabelas entram no 01_staging.sql.

### 5.5 Mart — PRODES Clean
```sql
CREATE OR REPLACE TABLE project2.marts.prodes_clean AS
SELECT
    CAST(geocode_ibge AS BIGINT)::VARCHAR AS geocode_ibge,
    mun,
    CAST(year AS INTEGER) AS ano,
    "area km²" AS area_km2
FROM project2.staging.prodes_raw;
```

### 5.6 Analytics — EGS Base
```sql
CREATE OR REPLACE TABLE project2.analytics.egs_base AS
SELECT
    p.geocode_ibge,
    p.mun,
    p.ano,
    p.area_km2,
    COUNT(i.geocode_ibge)         AS n_autos,
    COALESCE(SUM(i.val_multa), 0) AS val_multas
FROM project2.marts.prodes_clean p
LEFT JOIN project2.marts.ibama_clean i
    ON  p.geocode_ibge = i.geocode_ibge
    AND p.ano          = i.ano
GROUP BY p.geocode_ibge, p.mun, p.ano, p.area_km2;
```

### 5.7 Analytics — EGS Final
```sql
CREATE OR REPLACE TABLE project2.analytics.egs_final AS
SELECT
    geocode_ibge, mun, ano, area_km2, n_autos, val_multas,
    CASE
        WHEN n_autos > 0 AND val_multas >= 0.01
            THEN LOG(1 + area_km2) / SQRT(LOG(1 + n_autos) * LOG(1 + val_multas))
        WHEN area_km2 > 0 THEN LOG(1 + area_km2)
        ELSE 0
    END AS egs,
    CASE
        WHEN n_autos > 0 AND val_multas >= 0.01 THEN 'completo'
        WHEN area_km2 > 0                        THEN 'gap_absoluto'
        ELSE                                          'sem_pressao'
    END AS tipo_egs
FROM project2.analytics.egs_base;
```

### 5.8 Analytics — Rankings
Ver seção 6.4 e 6.5 para queries completas.

---

## 6. Query Results (Definitivos — 2026-05-02)

### 6.1 Distribuição por tipo_egs

| tipo_egs | n | % |
|---|---|---|
| completo | 7,893 | 54.5% |
| gap_absoluto | 3,784 | 26.1% |
| sem_pressao | 2,813 | 19.4% |
| **Total** | **14,490** | |

> Pipeline v3 (Fix 8 + Fix 9 aplicados, 2026-05-04). Referência histórica:
> v2 (Fix 8, filtro caso único): gap_absoluto 41.2% (5,966), completo 32.2% (4,667), sem_pressao 26.6% (3,857)
> v1 (DT_FATO_INFRACIONAL, 71% NULLs): gap_absoluto 57.7% (8,366) — inflado artificialmente

### 6.2 p75 EGS (completo, area_km2 >= 1)

**p75 = 0.5891** — threshold para qualificação no ranking de persistência completo (pipeline v3).
Histórico: v1 ~0.85–0.90 | v2 = 0.7267 | v3 = 0.5891
Redução explicada pelo crescimento do pool completo: 1.616 → 4.667 (v2) → 7.893 (v3) observações.
EGS stats (v3, completo): min=0.0, max=1.95, mean=0.294, median=0.255, p95=0.777

### 6.3 Persistência gap_absoluto (≥ 3 anos consecutivos, area_km2 >= 1)

**Top 20 por priority_score:**

| mun | UF | max_streak | total_km2 | primeiro_ano | ultimo_ano | priority_score |
|---|---|---|---|---|---|---|
| Governador Luiz Rocha | MA | 18 | 106.8 | 2008 | 2025 | **2.552** |
| Barra do Bugres* | MT | 16 | 101.1 | 2008 | 2023 | 2.419 |
| Floresta do Araguaia | PA | 16 | 89.3 | 2008 | 2023 | 2.355 |
| Fortuna | MA | 13 | 107.1 | 2008 | 2025 | 2.266 |
| Tefé | AM | 12 | 117.5 | 2010 | 2025 | 2.238 |
| São Domingos do Maranhão | MA | 10 | 168.5 | 2008 | 2023 | 2.229 |
| Santa Rosa do Purus | AC | 18 | 52.9 | 2008 | 2025 | 2.174 |
| Arame | MA | 7 | 223.3 | 2008 | 2022 | 1.987 |
| Santo Afonso | MT | 14 | 50.6 | 2008 | 2021 | 1.963 |
| Viseu | PA | 9 | 112.4 | 2008 | 2025 | 1.961 |
| Piçarra | PA | 14 | 47.7 | 2010 | 2023 | 1.934 |
| Jutaí | AM | 12 | 59.1 | 2013 | 2024 | 1.920 |
| Porto de Moz | PA | 6 | 276.2 | 2009 | 2019 | 1.901 |
| Terra Santa | PA | 12 | 54.0 | 2009 | 2024 | 1.878 |
| Coari | AM | 10 | 66.0 | 2016 | 2025 | 1.826 |
| Santa Maria das Barreiras | PA | 7 | 137.5 | 2017 | 2023 | 1.810 |
| Graça Aranha | MA | 12 | 42.0 | 2008 | 2019 | 1.763 |
| São José do Xingu | MT | 7 | 106.5 | 2019 | 2025 | 1.717 |
| Theobroma | RO | 9 | 61.2 | 2009 | 2024 | 1.712 |
| Nova Olinda do Norte | AM | 9 | 60.4 | 2008 | 2022 | 1.706 |

*Barra do Bugres: verificar proporção de desmatamento legal antes de incluir na narrativa.

> **Mudança crítica em relação à análise anterior:** Novo Repartimento (ex-#1, streak 11, score 3.46) migrou para o ranking completo — na análise anterior, seus autos de infração eram invisíveis por NULLs em DT_FATO_INFRACIONAL. Com a data correta, ele tem enforcement registrado e aparece como completo #8. Santa Carmem e São José do Xingu permanecem no gap_absoluto mas com streaks menores que o reportado anteriormente (as datas corretas revelaram alguns anos com enforcement).

> **Perfil novo:** os líderes atuais são municípios menores e sistematicamente menos visíveis — Maranhão, municípios do interior do AM e PA — com desflorestamento acumulado moderado mas streaks muito longas. Nenhum deles aparece em operações IBAMA federais de grande escala.

### 6.4 Persistência completo — top quartile EGS (≥ 3 anos consecutivos acima do p75 = 0.727)

**43 municípios qualificados. Ranking completo por priority_score:**

| mun | UF | max_streak | egs_medio | total_km2 | primeiro_ano | ultimo_ano | priority_score |
|---|---|---|---|---|---|---|---|
| Moju | PA | 7 | 1.149 | 672.1 | 2008 | 2023 | **2.390** |
| Itaituba | PA | 5 | 0.824 | 1739.7 | 2008 | 2022 | 2.265 |
| Itupiranga | PA | 6 | 1.100 | 528.9 | 2008 | 2013 | 2.120 |
| Peixoto de Azevedo | MT | 6 | 1.102 | 467.3 | 2020 | 2025 | 2.078 |
| Jacareacanga | PA | 7 | 0.894 | 246.5 | 2012 | 2018 | 2.023 |
| Tailândia | PA | 6 | 0.922 | 378.1 | 2008 | 2025 | 2.007 |
| Aripuanã | AM | 5 | 0.810 | 707.5 | 2018 | 2022 | 1.992 |
| Novo Repartimento | PA | 4 | 0.934 | 1586.6 | 2008 | 2022 | 1.927 |
| Prainha | PA | 5 | 0.896 | 451.6 | 2013 | 2024 | 1.856 |
| União do Sul | MT | 5 | 0.959 | 394.0 | 2020 | 2024 | 1.815 |
| Rurópolis | PA | 4 | 0.953 | 426.8 | 2018 | 2021 | 1.584 |
| Candeias do Jamari | RO | 4 | 1.080 | 408.3 | 2016 | 2019 | 1.573 |
| Nova Maringá | MT | 4 | 1.120 | 390.0 | 2021 | 2024 | 1.561 |
| Grajaú | MA | 4 | 0.970 | 359.9 | 2008 | 2022 | 1.540 |
| Querência | MT | 5 | 1.061 | 158.0 | 2019 | 2023 | 1.539 |
| Apuí | AM | 3 | 0.748 | 1321.2 | 2020 | 2022 | 1.489 |
| Apiacás | MT | 4 | 0.841 | 285.4 | 2020 | 2023 | 1.479 |
| Portel | PA | 4 | 0.758 | 256.8 | 2008 | 2011 | 1.452 |
| Marabá | PA | 4 | 1.078 | 210.1 | 2020 | 2023 | 1.399 |
| Pacajá | PA | 3 | 0.782 | 633.4 | 2008 | 2010 | 1.337 |
| Barra do Corda | MA | 4 | 1.209 | 160.1 | 2009 | 2012 | 1.329 |
| Novo Aripuanã | AM | 3 | 0.851 | 599.8 | 2020 | 2022 | 1.326 |
| Cotriguaçu | MT | 4 | 1.031 | 150.3 | 2020 | 2023 | 1.312 |
| Placas | PA | 3 | 0.963 | 490.8 | 2014 | 2020 | 1.284 |
| Cláudia | MT | 4 | 1.137 | 123.9 | 2020 | 2023 | 1.262 |
| Nova Bandeirantes | MT | 3 | 0.795 | 370.8 | 2021 | 2023 | 1.226 |
| Nova Mamoré | RO | 3 | 1.168 | 357.4 | 2020 | 2022 | 1.219 |
| Aveiro | PA | 4 | 1.144 | 97.5 | 2009 | 2012 | 1.200 |
| Juara | MT | 3 | 1.044 | 285.2 | 2021 | 2023 | 1.172 |
| Tarauacá | AC | 3 | 1.283 | 268.5 | 2020 | 2022 | 1.160 |
| Buritis | RO | 3 | 0.968 | 263.6 | 2013 | 2022 | 1.156 |
| Vilhena | RO | 4 | 0.971 | 78.9 | 2019 | 2022 | 1.145 |
| Paragominas | PA | 3 | 0.917 | 223.2 | 2009 | 2011 | 1.122 |
| Maués | AM | 3 | 0.885 | 130.3 | 2023 | 2025 | 1.011 |
| Centro Novo do Maranhão | MA | 3 | 0.970 | 128.2 | 2009 | 2011 | 1.007 |
| Juína | MT | 3 | 1.107 | 108.7 | 2021 | 2023 | 0.973 |
| Comodoro | MT | 3 | 0.905 | 94.7 | 2018 | 2020 | 0.945 |
| São Francisco do Guaporé | RO | 3 | 0.929 | 70.1 | 2008 | 2010 | 0.884 |
| Oriximiná | PA | 3 | 1.048 | 67.8 | 2009 | 2011 | 0.877 |
| Tabaporã | MT | 3 | 0.873 | 57.2 | 2013 | 2015 | 0.842 |
| Bom Jardim | MA | 3 | 0.895 | 44.3 | 2011 | 2013 | 0.790 |
| Chupinguaia | RO | 3 | 1.117 | 43.0 | 2019 | 2021 | 0.784 |
| Óbidos | PA | 3 | 0.779 | 41.1 | 2011 | 2013 | 0.775 |

> **Destaque — Itaituba (PA):** 1.739 km² desflorestados com enforcement persistentemente insuficiente. Epicentro do garimpo ilegal no Tapajós — "capital brasileira de lavagem de ouro ilegal." Operações destruíram 100 máquinas (2023), IBAMA suspendeu 331 permissões garimpeiras na APA Tapajós (2024).

> **Destaque — Apuí (AM):** 1.321 km², streak 2020–2022. IBAMA aplicou R$173 mi em multas (2025), embargou 27.000 ha. PF e IBAMA prenderam ex-vice-prefeito por desmatamento ilegal (mar/2025). Operação Tamoiotatá 6 (IPAAM, 2026) aplicou R$5,4 mi adicionais. Sistema identificou Apuí como alto EGS em 2020–2022; as operações chegaram em 2025–2026 — **principal caso de validação temporal do dataset corrigido.**

> **Destaque — Novo Repartimento (PA):** migrou do gap_absoluto (ex-#1) para completo #8. Tem enforcement registrado, mas ainda com gap expressivo (1.586 km², score 1.927). A Operação Metaverso (mar/2026) aplicou R$5 mi em multas na região — consistente com enforcement presente mas insuficiente.

> **Destaque — Peixoto de Azevedo (MT):** resultado mais robusto e consistente entre as duas versões do pipeline — mantém score 2.078, streak 6, 2020–2025. Resultado não sensível à correção da data.

---

## 7. Fixes — Status Final

> Numeração neste documento é independente da numeração em `p2_technical_fixes.txt` (que usa numeração diferente por ter sido gerado em sessão anterior).

| Fix | Descrição | Status |
|---|---|---|
| Fix 1 | Threshold val_multas: `n_autos > 0 AND val_multas >= 0.01` | ✅ Aplicado |
| Fix 2 | Date column: `DT_FATO_INFRACIONAL` → `DAT_HORA_AUTO_INFRACAO` | ✅ Aplicado |
| Fix 3 | Queimadas removidas do filtro INFRACAO_AREA | ✅ Aplicado |
| Fix 4 | Join temporal `p.ano = i.ano` confirmado empiricamente | ✅ Locked |
| Fix 5 | 5.689 sem match: todos fora da Amazônia Legal | ✅ Fechado |
| Fix 6 | NAs de val_multa: negligíveis nos rankings (0.1–5.5%) | ✅ Fechado |
| Pendente | Barra do Bugres: verificar % desmatamento legal vs. ilegal | ⚠ Aberto |
| Fix 9 | Filtro IBAMA: 1 caso → 3 casos (+2.656 registros 2008–2012). SQL aplicado em 02_marts.sql | ✅ Aplicado |
| Pendente | UF fix: adicionar `municipios_ref` no staging para cobrir gap_absoluto | ⚠ Aberto |
| Pendente | Deflator: adicionar `ipca_deflator` no staging (pré-requisito Fix 2 val_multas) | ⚠ Aberto |
| Pendente | priority_score: verificar `streak = 1 → score = 0` e discutir `LOG(streak + 1)` | ⚠ Aberto |
| Pendente | p75 hardcoded vs. dinâmico — documentar ou parametrizar | ⚠ Aberto |

---

## 8. Limitações Interpretativas

1. **PRODES mede perda florestal observada, não ilegalidade confirmada.** Parte do desmatamento pode ser legalmente autorizada (AUTEX/DOF). Caso específico: Barra do Bugres (MT) com 99% de desmatamento potencialmente autorizado — pode gerar gap_absoluto sem ilegalidade subjacente.

2. **IBAMA mede enforcement federal detectado, não o total de enforcement.** Municípios sem autos federais podem ter atuação de órgãos estaduais (IPAAM, SEMA, etc.) não capturada no dataset.

3. **EGS mede intensidade de resposta relativa, não efetividade.** Alto EGS não implica impunidade — pode refletir atuação estadual, autuações em anos adjacentes, ou limitação operacional documentada.

4. **Data usada é de lavratura, não do fato infracional.** `DAT_HORA_AUTO_INFRACAO` registra quando o auto foi constituído. Análise de sensibilidade indica que ~17.4% dos municípios-ano gap_absoluto teriam enforcement com join t+1. Municípios com streaks longas (≥3 anos) são robustos a essa incerteza.

5. **Viés de volume no pipeline antigo.** O pipeline original (usando `DT_FATO_INFRACIONAL`, 71% NULL) capturava preferencialmente enforcement em municípios com alto volume de autos — os casos famosos mantinham registros suficientes mesmo a 28–40% de completude. O pipeline atual é mais completo e menos enviesado.

6. **p75 como threshold de persistência é arbitrário.** Robustez: testar com p80 e p90. O p75 atual (0.727) é mais baixo que o estimado anteriormente (~0.85) devido ao crescimento do pool completo.

7. **Join por geocode IBGE assume cobertura completa.** 16 municípios do PRODES não aparecem no IBAMA — tratados como zero enforcement (correto pela estrutura LEFT JOIN). Os 5.689 municípios-ano IBAMA sem match foram confirmados como externos à Amazônia Legal.

---

## 9. MVP Vision — Próximos Passos Analíticos

### 9.1 Expansão para outros biomas
**Problema 1:** fora da Amazônia Legal, PRODES organiza por geometria de bioma, não por geocode. Solução: spatial join usando `NUM_LATITUDE_AUTO` e `NUM_LONGITUDE_AUTO` do IBAMA.

**Problema 2:** heterogeneidade metodológica entre PRODES por bioma. Solução: normalização intra-bioma (percentil ou z-score) antes do cálculo do EGS.

### 9.2 Extensões inferenciais
Two-way FE panel: `EGS_{t-1} → desmatamento_t`. Se policy shock identificável (cortes IBAMA 2019–2022): DiD ou event study.

---

## 10. Portfolio Integration

**Posicionamento:** P2 é o único projeto monitoring-focused do portfolio (P1 = targeting, P3 = pattern detection). KPI design e pipeline end-to-end.

**Decision snapshot:**
- Decisão: Priorizar inspeções ambientais
- Restrição: N inspeções/mês — configurável no Power BI
- Regra: Maior priority_score (LOG(streak) × LOG(1 + volume)) com persistência ≥ 3 anos consecutivos
- Ação: Inspecionar top-N municípios; escalonar gap_absoluto persistente para auditoria

**Documento de próximas etapas detalhado:** `p2_next_steps.md` (gerado 2026-05-03) — 6 blocos sequenciais com itens, best practices e checks por layer.

**Próximas etapas em ordem:**
1. ~~Revisão script R de exploração — seção IBAMA~~ ✅ **CONCLUÍDO (2026-05-07)**
2. ~~Script R: loading PRODES (encoding, mutate, stopifnots, cobertura PRODES × IBAMA)~~ ✅ **CONCLUÍDO (2026-05-07)**
3. Script R: exploração PRODES — distribuição anual de area_km2 (quebras estruturais), análises decisivas PRODES × IBAMA (alinhamento temporal, sensibilidade t+1)
3. Staging fixes: `municipios_ref` + `ipca_deflator` → commit 01_staging.sql
4. Marts: review + checks → commit 02_marts.sql
5. Analytics: revisão streak + priority_score (incluindo streak=1 bug) + p75 + checks → commit 03_analytics.sql
6. Documentação: README (pipeline final apenas), apêndice metodológico, narrativas finais, Barra do Bugres
7. Power BI: conexão + dashboard
8. Website + LinkedIn (após P1–P3 completos)

**Documento de fixes técnicos:** `p2_technical_fixes.txt` — 8 fixes documentados com problema, solução, código e trade-offs (v3, 2026-05-03).
