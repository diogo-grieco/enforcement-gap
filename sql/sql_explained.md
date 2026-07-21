# Pipeline SQL — Guia Comentado (Material de Estudo)

**Base:** `01_staging.sql`, `02_marts.sql`, `03_analytics.sql`, `04_export.sql` (**v5, 2026-07-20** — redesign dos rankings + reestruturação de camadas; substitui integralmente a versão deste guia baseada em v3/v3.1).
**Propósito:** igual ao `exploring_script_explained.md` — não roda, é leitura acompanhada. Código idêntico ao arquivo original, explicação técnica logo depois: mecânica do DuckDB/SQL, por que a decisão foi essa, e onde se conecta a um Fix documentado em `sql_technical_fixes.md` ou a um achado do `exploring_script.R`.

**O que mudou da v3 para a v5 (mapa rápido):**
- *Camadas puras:* staging agora é só `SELECT *` + `all_varchar` (5 tabelas `*_raw`); toda tipagem/filtragem migrou para marts (`municipality_ref`, `municipality_area`, `ipca_annual`); a razão do deflator (índice derivado) migrou para analytics.
- *Fórmula EGS unificada:* um único `CASE` com piso no denominador substitui os três ramos por `gap_type`; `egs` nunca mais é `NULL`.
- *Ranking único:* `egs_ranking` (805 municípios, média 0-fill de 18 anos) substitui `ranking_absolute_gap` + `ranking_measured_gap`; streaks e `priority_score` foram **removidos**, não adaptados.
- *Checks consolidados:* cada arquivo termina em uma única query `UNION ALL` com coluna `status` — 7 + 26 + 20 + 1 = 54 checks, todos passando em produção (2026-07-20; o check `ipca_months_not_12` entrou em 2026-07-20; a auditoria de 2026-07-20 adicionou 3 checks de `prodes_clean` e o `n_floor_active_nominal`; a terceira auditoria de 2026-07-20 adicionou `total_area_prodes_clean`, `deflator_2008` e o primeiro check do `04_export.sql`, contra parquet stale).

---

## 0. Padrão geral do pipeline

**Dependência sequencial via schema.** `project2.staging` → `project2.marts` → `project2.analytics` — cada arquivo só lê tabelas que o arquivo anterior já criou. `CREATE OR REPLACE TABLE` em toda parte torna cada etapa idempotente: rodar duas vezes não acumula nada.

**Princípio de pureza de camada (novo na v5).** Cada arquivo declara no cabeçalho o que lhe pertence — e o próprio código é auditável contra essa declaração: em staging, *qualquer* `CAST`, `WHERE` ou coluna computada é, por definição, um erro de camada ("if you find a CAST, a WHERE, or a computed column below, it doesn't belong in this file"). Marts filtra, tipa e padroniza. Analytics deriva índices. O caso que motivou a regra: a razão do deflator IPCA vivia em staging desde a v1, contradizendo o propósito declarado do próprio arquivo ("no analytical transformation") — um índice derivado disfarçado de ingestão. A v5 divide a operação em três pedaços, um por camada: leitura bruta (`ipca_raw`, staging) → UNPIVOT/filtro/média anual (`ipca_annual`, marts) → razão de rebase (`ipca_deflator`, analytics).

**Checks consolidados: um grid, falhas primeiro.** O padrão v5, idêntico nos três arquivos:

```sql
WITH checks AS (
    SELECT 'nome_do_check' AS check_name, CAST(COUNT(*) AS VARCHAR) AS actual, '14490' AS expected FROM ...
    UNION ALL SELECT ...
)
SELECT check_name, actual, expected,
       CASE WHEN actual = expected THEN 'OK' ELSE 'failed' END AS status
FROM checks
ORDER BY status DESC, check_name;
```

Três mecânicas valem nota. (1) Tudo é `CAST(... AS VARCHAR)` porque `UNION ALL` exige tipos compatíveis entre os braços — contagens, anos, medianas e somas convivem na mesma coluna como texto. (2) `ORDER BY status DESC, check_name` agrupa os resultados por status antes da ordem alfabética — na colação binária padrão (`'f'` = 102 > `'O'` = 79), qualquer `failed` vem primeiro, no topo do grid, nunca perdido no meio das linhas de `OK`. (Corrigido na auditoria de 2026-07-20: a versão anterior usava `ASC`, que punha os `OK` primeiro — exatamente o oposto do que o título desta seção prometia.) (3) O comparador é igualdade de *string*: foi isso que produziu a única falha cosmética da validação em produção — `CAST(ROUND(SUM(fine_value)) AS VARCHAR)` sobre um `DOUBLE` rende `"26814492927.0"` (o `ROUND` de um `DOUBLE` continua `DOUBLE`, e a conversão para texto preserva o ponto decimal), que difere da string esperada `"26814492927"`. Correção: `CAST(CAST(ROUND(...) AS BIGINT) AS VARCHAR)` — forçar inteiro antes do texto. Lição geral: check por igualdade de string exige controlar a *formatação*, não só o valor.

Os checks continuam sendo "leia e compare" — nada aborta a execução se `actual != expected` (diferente do `stopifnot()` do R). O formato consolidado mitiga o risco prático (um grid único com coluna de status, em vez de 15 abas de resultado no DBeaver que ninguém confere), mas a natureza é a mesma: é um humano que precisa olhar.

**Catálogo `project2` vem do nome do arquivo.** Toda referência é qualificada (`project2.staging.prodes_raw`), sem `ATTACH` explícito: ao abrir `project2.duckdb`, o DuckDB nomeia o catálogo pelo nome do arquivo sem extensão. Se o banco tivesse outro nome, todo `project2.` quebraria.

---

## 1. 01_staging.sql

### 1.1 Configuração

```sql
SET VARIABLE data_root = 'C:/Users/diogo/projects/project2';
```

`SET VARIABLE` cria uma variável de **sessão** (vive na conexão, não é salva no `.duckdb`); `getvariable('data_root')` a recupera nos `read_csv`/`read_json_auto`. Ponto único de configuração, motivado pelo Fix 14: paths relativos resolvem contra o diretório de trabalho do *processo* (que no DBeaver não é a raiz do projeto) e falhavam com "No files found".

```sql
CREATE SCHEMA IF NOT EXISTS project2.staging;
CREATE SCHEMA IF NOT EXISTS project2.marts;
CREATE SCHEMA IF NOT EXISTS project2.analytics;
```

Três namespaces, um por camada. `IF NOT EXISTS` = idempotência, igual ao `CREATE OR REPLACE TABLE`.

### 1.2 prodes_raw / ibama_raw

```sql
CREATE OR REPLACE TABLE project2.staging.prodes_raw AS
SELECT * FROM read_csv(
    getvariable('data_root') || '/data_prodes/terrabrasilis_legal_amazon_*.csv',
    delim = ';',
    header = true,
    all_varchar = true    -- deterministic typing happens in marts (mirrors R)
);
```

`all_varchar = true` força tudo a texto — a mesma decisão defensiva do `col_types = cols(.default = "c")` do R: impede o inferidor de tipos de estragar geocodes de 7 dígitos (zero à esquerda sumiria como inteiro) ou valores com vírgula decimal. A tipagem real, explícita, acontece em marts.

`ibama_raw` idem, com glob (`auto_infracao_ano_*.csv`): um CSV por ano, e o `read_csv` do DuckDB concatena automaticamente tudo que casa com o padrão — o que no R exigiu `map()` + `list_rbind()` manual.

### 1.3 ipca_raw (v5: só a leitura bruta)

```sql
CREATE OR REPLACE TABLE project2.staging.ipca_raw AS
SELECT * FROM read_csv(
    getvariable('data_root') || '/data_ipca/sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv',
    delim = ';', skip = 3, header = true,
    all_varchar = true, null_padding = true, ignore_errors = true,
    parallel = false
);
```

Na v3, este bloco fazia leitura + UNPIVOT + filtro + média + razão do deflator, tudo numa cadeia de CTEs dentro de staging. Na v5 sobrou só a leitura. A distinção que o cabeçalho documenta é fina mas importante: as opções do leitor (`skip = 3` por causa do título multilinha do Sidra, `null_padding`/`ignore_errors` pelo rodapé com legenda, `parallel = false` porque o scanner paralelo não lida com quebra de linha *dentro* de aspas quando combinado com `null_padding`) são **mecânica de parsing do arquivo**, não decisões analíticas — mesma categoria do `all_varchar`. Já o UNPIVOT (reformatação), o filtro de rodapé (filtragem) e a média anual (padronização) são trabalho de marts; a razão de rebase é índice derivado, trabalho de analytics.

### 1.4 municipality_ref_raw / municipality_area_raw (v5: sem extração, sem cast)

```sql
CREATE OR REPLACE TABLE project2.staging.municipality_ref_raw AS
SELECT * FROM read_json_auto(getvariable('data_root') || '/data_ibge/municipios.json');
```

`read_json_auto` infere os STRUCTs aninhados do JSON da API do IBGE inteiros, sem escolher um caminho — a *escolha* de qual caminho de UF usar é decisão de padronização, e por isso vive em marts (§2.3).

```sql
CREATE OR REPLACE TABLE project2.staging.municipality_area_raw AS
SELECT * FROM read_csv(
    getvariable('data_root') || '/data_ibge/municipality_area_2025.csv',
    delim = ',',
    header = true,
    all_varchar = true
);
```

Fonte nova da v4/v5 (resolve o Fix S12): IBGE, Malha Municipal Digital — Áreas Territoriais, arquivo `AR_BR_RG_UF_RGINT_RGI_MUN_2025.xls` convertido uma vez para CSV. Duas armadilhas documentadas no comentário do arquivo: (1) **`delim = ','`, não `';'`** — o conversor usado (online) produziu vírgula, contra a convenção brasileira de todos os outros CSVs do projeto; se o CSV for regenerado com Excel/LibreOffice, conferir o delimitador antes de confiar na contagem. (2) As 2 linhas de lixo no fim do arquivo (uma em branco, uma nota "OBS") **ficam** na tabela raw — descartá-las é filtragem, trabalho de marts. Esperado: 5.575 linhas (5.573 municípios + 2 lixo).

### 1.5 STAGING CHECKS — a lição de NULL do Fix S17

O bloco consolidado tem 7 checks (contagens de linhas e colunas via `information_schema.columns`, que expõe metadados do banco — uma linha por coluna de cada tabela). Um deles carrega a lição de SQL mais importante do arquivo:

```sql
UNION ALL SELECT 'invalid_geocode_ibama', CAST(COUNT(*) AS VARCHAR), '29'
FROM project2.staging.ibama_raw
WHERE COD_MUNICIPIO IS NULL OR LENGTH(COD_MUNICIPIO) != 7
```

A versão original era só `WHERE LENGTH(COD_MUNICIPIO) != 7` e retornava 23. O problema: `LENGTH(NULL)` avalia para `NULL`, e `NULL != 7` avalia para `NULL` — que **não é** `TRUE` na lógica de três valores do SQL, então a linha não passa no `WHERE`. Seis linhas com geocode `NULL` eram silenciosamente invisíveis ao check. Correção: `IS NULL OR ...`, esperado corrigido para 29. A composição dos 29 (investigada nos CSVs brutos, Fix S17): 23 linhas com `COD_MUNICIPIO = '431173'` — Manoel Viana/RS, código de 6 dígitos malformado (correto: 4311759; não é zero à esquerda perdido — nenhum código IBGE começa com 0) — e 6 linhas-lixo com geocode `NULL`. Nenhum dos dois grupos afeta `egs_final` (RS está fora da Amazônia Legal; as linhas `NULL` não passam no filtro `Lavrado` de `ibama_clean`) — documentado, não corrigido. Regra geral a levar para qualquer projeto: **todo check negativo (`!=`, `NOT IN`, `<>`) sobre coluna anulável precisa de `IS NULL OR` explícito**, ou tem um ponto cego.

---

## 2. 02_marts.sql

### 2.1 ibama_clean

```sql
CREATE OR REPLACE TABLE project2.marts.ibama_clean AS
SELECT
    COD_MUNICIPIO AS geocode_ibge,
    EXTRACT(YEAR FROM TRY_CAST(DAT_HORA_AUTO_INFRACAO AS DATE)) AS year,
    CAST(REPLACE(VAL_AUTO_INFRACAO, ',', '.') AS DOUBLE)        AS fine_value
FROM project2.staging.ibama_raw
WHERE
    SIT_CANCELADO         = 'N'
    AND DES_STATUS_FORMULARIO = 'Lavrado'
    AND ( ... 3 casos, mesma lógica do exploring_script.R, "locked" ... );
```

Inalterado desde a v3. `TRY_CAST` (não `CAST`): valor malformado vira `NULL` — catável pelo check `null_year` — em vez de abortar o script inteiro antes do check rodar; alinha o comportamento de falha com o `ymd()` do R (que retorna `NA` silenciosamente). `EXTRACT(YEAR FROM NULL)` propaga `NULL`, como toda operação SQL com nulo. O filtro de 3 casos é tradução cláusula a cláusula do `filter()` do R, deliberadamente sincronizado. Esperado: 60.707 linhas.

### 2.2 prodes_clean

```sql
CREATE OR REPLACE TABLE project2.marts.prodes_clean AS
SELECT
    geocode_ibge,
    mun,
    CAST(year AS INTEGER) AS year,
    CAST(REPLACE("area km²", ',', '.') AS DOUBLE) AS area_km2
FROM project2.staging.prodes_raw;
```

`"area km²"` entre aspas duplas: nome de coluna com espaço e caractere Unicode precisa de citação (equivalente às crases do R). Esperado: 14.490 linhas, 805 geocodes.

### 2.3 municipality_ref (v5: veio de staging)

```sql
CREATE OR REPLACE TABLE project2.marts.municipality_ref AS
SELECT
    CAST(id AS VARCHAR)                                AS geocode_ibge,
    nome                                                AS municipality_name,
    "regiao-imediata"."regiao-intermediaria".UF.sigla   AS uf
FROM project2.staging.municipality_ref_raw;
```

As aspas em `"regiao-imediata"` são obrigatórias: hífen não é válido em identificador SQL sem citação (seria lido como subtração). A escolha do caminho é a decisão de padronização que justifica a tabela viver em marts: o caminho alternativo (`microrregiao.mesorregiao.UF.sigla`) falha para 1 registro (Boa Esperança do Norte/MT, sem microrregião cadastrada); o caminho usado tem cobertura 100%, e os dois nunca divergem nos 5.570 registros onde ambos existem. Esperado: 5.571 linhas.

### 2.4 municipality_area (v5: veio de staging)

```sql
CREATE OR REPLACE TABLE project2.marts.municipality_area AS
SELECT
    CD_MUN                                          AS geocode_ibge,
    CAST(REPLACE(AR_MUN_2025, ',', '.') AS DOUBLE)  AS area_municipio_km2
FROM project2.staging.municipality_area_raw
WHERE LENGTH(CD_MUN) = 7;   -- drops the trailing blank/OBS footer rows
```

O `WHERE LENGTH(CD_MUN) = 7` descarta as 2 linhas-lixo do rodapé — filtragem, por isso aqui e não em staging. Repare que este check positivo (`= 7`) não sofre do problema de NULL do §1.5: `LENGTH(NULL) = 7` avalia `NULL`, que não passa no `WHERE` — o que aqui é exatamente o comportamento desejado (linha sem geocode é lixo). Esperado: 5.573 linhas; cobertura de 100% dos 805 geocodes do PRODES (verificada, sem duplicatas).

### 2.5 ipca_annual (v5: veio de staging, sem a razão)

```sql
CREATE OR REPLACE TABLE project2.marts.ipca_annual AS
WITH long AS (
    UNPIVOT project2.staging.ipca_raw ON COLUMNS('\d{4}$') INTO NAME month VALUE index
)
SELECT
    CAST(regexp_extract(month, '(\d{4})$', 1) AS INTEGER) AS year,
    AVG(CAST(REPLACE(index, ',', '.') AS DOUBLE))         AS avg_index
FROM long
WHERE regexp_matches(index, '^\d+(,\d+)?$')
GROUP BY year
ORDER BY year;
```

`UNPIVOT ... ON COLUMNS('\d{4}$')` transforma colunas em linhas — o Sidra exporta um mês por coluna (formato largo); a regex seleciona só colunas cujo nome termina em 4 dígitos, empilhando nome em `month` e valor em `index`. Equivalente SQL do `pivot_longer()`. Por padrão o UNPIVOT do DuckDB **descarta valores `NULL`** — é assim que a maior parte do rodapé some sem filtro explícito. O que sobra de lixo (texto de legenda vazado para as colunas de mês via `null_padding`) é barrado por `regexp_matches(index, '^\d+(,\d+)?$')` — só passa o que tem *formato* de índice, sem precisar identificar as linhas de rodapé uma a uma. A média anual (`AVG`) é a decisão documentada de base: autos são lavrados ao longo do ano inteiro (pico set–out), então a base 2025 é a média dos índices mensais do ano, não um mês de referência. A **razão** do deflator não está aqui — é índice derivado, `03_analytics.sql` (§3.2). Esperado: 18 linhas.

### 2.6 MARTS CHECKS

26 checks consolidados (21 originais + 3 da auditoria de 2026-07-20 — `negative_area`/`min_year`/`max_year` de `prodes_clean`, simetria com os checks de `ibama_clean` — + `total_area_prodes_clean`, da terceira auditoria de 2026-07-20: o único check de *magnitude* do lado PRODES, simétrico ao `total_fines_ibama_clean` — sem ele, um CSV trocado com a forma certa passaria por tudo com áreas erradas — + `ipca_months_not_12`, adicionado 2026-07-20, Fix S14 — replica a asserção `all(count(ipca_raw, year)$n == 12)` do R, ausente do SQL até então: sem ela, um mês malformado descartado silenciosamente por `ignore_errors`/pelo filtro regex reduziria a média anual para 11 meses sem disparar nenhum check existente). Além dos herdados (contagens, nulos, min/max de ano, multa negativa), os padrões que valem conhecer:

```sql
UNION ALL SELECT 'total_fines_ibama_clean', CAST(CAST(ROUND(SUM(fine_value)) AS BIGINT) AS VARCHAR), '26814492927' FROM project2.marts.ibama_clean
```
O caso do `.0` residual explicado no §0 — o único check que falhou na validação de produção, por formatação, não por dado.

```sql
UNION ALL SELECT 'duplicate_geocodes_ref', CAST(COUNT(*) AS VARCHAR), '0'
FROM (SELECT geocode_ibge FROM project2.marts.municipality_ref GROUP BY geocode_ibge HAVING COUNT(*) > 1) d
```
`GROUP BY x HAVING COUNT(*) > 1` é o idiomatismo padrão de duplicatas (`HAVING` filtra *depois* do agrupamento, ao contrário do `WHERE`); a subquery converte "quais duplicam" em "quantas duplicam".

```sql
UNION ALL SELECT 'missing_area_prodes_to_area', CAST(COUNT(*) AS VARCHAR), '0'
FROM project2.staging.prodes_raw p
LEFT JOIN project2.marts.municipality_area a ON p.geocode_ibge = a.geocode_ibge
WHERE a.geocode_ibge IS NULL
```
`LEFT JOIN + IS NULL` é o anti-join clássico: acha linhas de `p` sem par em `a`. DuckDB tem `ANTI JOIN` nativo, mas este padrão é mais portável e é o usado consistentemente no pipeline. Aplicado duas vezes (referência de UF e área): garante que **todo** geocode do PRODES resolve nas duas tabelas do IBGE antes de qualquer join em analytics.

---

## 3. 03_analytics.sql

### 3.1 Nota de escala (LOG)

`LOG()` no DuckDB é base **10**; `log()` no R é natural. Transformação monotônica — ordem preservada, rankings idênticos — mas os valores absolutos de EGS não são comparáveis com um cálculo manual em R sem ajuste de base. (Na prática o EGS é tratado como ordinal de toda forma; ver §3.4.)

### 3.2 ipca_deflator (v5: veio de staging — é um índice derivado)

```sql
CREATE OR REPLACE TABLE project2.analytics.ipca_deflator AS
SELECT
    year,
    (SELECT avg_index FROM project2.marts.ipca_annual WHERE year = 2025) / avg_index AS deflator
FROM project2.marts.ipca_annual
ORDER BY year;
```

A subquery escalar `(SELECT avg_index ... WHERE year = 2025)` não é correlacionada — é uma constante, a mesma para toda linha. `deflator(2025) = 1.0` por construção (checado); `deflator(2008) = 2.5826`, confirmado identicamente em Python e R. Mora em analytics porque é a mesma *categoria* de computação que o EGS — uma razão derivada — mesmo sendo trivial: a fronteira de camada é sobre o tipo de operação, não sobre a complexidade.

### 3.3 egs_base

```sql
CREATE OR REPLACE TABLE project2.analytics.egs_base AS
SELECT
    p.geocode_ibge, p.mun, r.uf, r.municipality_name, p.year, p.area_km2,
    COUNT(i.geocode_ibge)                        AS n_infractions,
    COALESCE(SUM(i.fine_value), 0)                AS fine_values_nominal,
    COALESCE(SUM(i.fine_value), 0) * d.deflator   AS fine_values
FROM project2.marts.prodes_clean p
LEFT JOIN project2.marts.ibama_clean i
    ON  p.geocode_ibge = i.geocode_ibge AND p.year = i.year
LEFT JOIN project2.analytics.ipca_deflator d ON p.year = d.year
LEFT JOIN project2.marts.municipality_ref r ON p.geocode_ibge = r.geocode_ibge
GROUP BY p.geocode_ibge, p.mun, r.uf, r.municipality_name, p.year, p.area_km2, d.deflator;
```

Três mecânicas centrais, inalteradas desde a v3 (só os schemas dos joins mudaram na v5):

- `COUNT(i.geocode_ibge)`, não `COUNT(*)`: quando o `LEFT JOIN` não encontra par, `i.geocode_ibge` vem `NULL`, e `COUNT(coluna)` **não conta** nulos — é o que faz `n_infractions = 0` em município-anos sem auto, em vez do `1` errado que `COUNT(*)` daria (contaria a própria linha do join).
- O `LEFT JOIN` com `ibama_clean` é a peça central do pipeline inteiro: mantém as 14.490 linhas do painel PRODES mesmo sem auto correspondente — é o que permite o gap absoluto *existir* como observação, em vez de sumir da tabela.
- `d.deflator` no `GROUP BY` mesmo sendo funcionalmente determinado por `p.year`: SQL exige toda coluna não-agregada do `SELECT` no `GROUP BY`. Redundante logicamente, obrigatório sintaticamente.

Multiplicar o deflator *depois* do `SUM` é equivalente a deflacionar auto a auto (o deflator é constante dentro do ano) — documentado no comentário para não parecer atalho.

**Ressalva não corrigida, só documentada (Fix S8, 2026-07-20):** o `ON p.year = i.year` acima cruza dois calendários diferentes como se fossem o mesmo. O "ano" oficial do PRODES vai de 1º de agosto (ano *t*−1) a 31 de julho (ano *t*); o `year` do IBAMA aqui é ano civil (jan–dez), extraído de `DAT_HORA_AUTO_INFRACAO`. As duas janelas só se sobrepõem em ~7 dos 12 meses. A validação de lag do `exploring_script.R` (59,2% mesmo ano / 4,7% só mesmo ano / 1,0% só um ano de defasagem / 35,1% nunca bate — proporções sobre os 60.707 autos, não sobre município-anos) foi feita sobre essa base de ano civil, não contra a janela ago–jul real do PRODES — parte do que a análise chama de "lag" pode ser esse descompasso de calendário, não atraso real de lavratura. Não corrigido na v5 (o join por mesmo ano continua como está); passou a ser dito explicitamente em vez de deixado implícito.

### 3.4 egs_final — a fórmula unificada (v5, o coração da redesign)

```sql
CREATE OR REPLACE TABLE project2.analytics.egs_final AS
SELECT
    geocode_ibge, mun, uf, municipality_name, year, area_km2, n_infractions,
    fine_values_nominal,   -- persistida desde o patch da auditoria (A2): torna o check n_floor_active_nominal reprodutível a partir do parquet
    fine_values,
    CASE
        WHEN area_km2 < 1 THEN 0
        ELSE LOG(1 + area_km2)
             / GREATEST(1, SQRT(LOG(1 + n_infractions) * LOG(1 + fine_values)))
    END AS egs,
    CASE
        WHEN area_km2 < 1       THEN 'no_pressure'
        WHEN fine_values < 0.01 THEN 'absolute_gap'
        ELSE                         'measured_gap'
    END AS gap_type
FROM project2.analytics.egs_base;
```

O que morreu: a v3 tinha três fórmulas por ramo de `gap_type` (`NULL` para no_pressure, `LOG(1+area)` puro para absolute_gap, a razão completa para measured_gap) — o que tornava os dois EGS incomensuráveis entre categorias (Fix S1) e proibia qualquer `AVG(egs)` sem filtro. O que substitui:

- **`GREATEST(1, ...)` — o piso no denominador.** `GREATEST` retorna o maior dos argumentos; com resposta zero, `SQRT(LOG(1)·LOG(1)) = 0`, o piso segura o denominador em 1, e `egs = LOG(1+area)` — ou seja, o antigo ramo `absolute_gap` **é o caso-limite da fórmula única**, não uma fórmula à parte. Validação (2026-07-20): reproduz o CASE antigo exatamente em 100% dos ex-absolute_gap e 99,1% dos ex-measured_gap; os 0,9% divergentes (28 de 3.285) são exatamente os casos de instabilidade na fronteira de R$0,01 que o piso existe para corrigir (Fix S10) — denominadores minúsculos que explodiam o score; o piso os torna mais conservadores, não mais extremos. O check `n_floor_active = 28` monitora essa população.
- **`no_pressure` vira 0, não `NULL`.** Consequência deliberada: anos sem pressão material contribuem exatamente 0 para qualquer média — é o que torna a média 0-fill do `egs_ranking` uma fórmula única e auditável em vez de uma média de dois estágios escondida.
- **`gap_type` continua — como anotação.** Mesmos três limiares da v3, mas não alimenta mais a fórmula nem particiona rankings. Vale notar a assimetria documentada no cabeçalho: anos absolute_gap pontuam sistematicamente *mais alto* que measured_gap (médias 0,723 vs. 0,582, deflacionado) porque o piso nunca os desconta — coerente com a leitura declarada do projeto de que resposta zero é lacuna mais grave que resposta desproporcional.
- **Os dois `CASE` são independentes de novo** — e agora isso é correto, não o risco que o Fix 17 corrigiu na v3: lá, `egs` era *derivado* de `gap_type` e a duplicação de condições podia divergir silenciosamente; aqui, `egs` não depende de `gap_type` por design (o `CASE` do egs testa só a materialidade; o do gap_type é rótulo descritivo). A dependência foi eliminada, não a duplicação sincronizada.

O limiar de materialidade (`area_km2 < 1`) deixou de ser suposição e virou resultado de robustez: testado contra 6,25 ha (a unidade mínima de mapeamento real do PRODES, confirmada em nota técnica do INPE) e contra nenhum limiar — top 10/20/50 do ranking **idênticos** nos três cenários, Spearman 0,985 nos 805 municípios. O limiar só move a fatia descritiva de `no_pressure` (56,2%), não a ordenação.

### 3.5 egs_ranking — o ranking único (v5)

```sql
CREATE OR REPLACE TABLE project2.analytics.egs_ranking AS
SELECT
    e.geocode_ibge, e.mun, e.uf, e.municipality_name,
    ROUND(AVG(e.egs), 3)                                          AS avg_egs_18y,
    ROUND(AVG(e.egs) FILTER (WHERE e.year >= 2023), 3)            AS avg_egs_3y,
    ROUND(COVAR_POP(e.egs, e.year) / VAR_POP(e.year), 5)          AS slope_egs,
    SUM(CASE WHEN e.gap_type != 'no_pressure' THEN 1 ELSE 0 END)  AS n_years_pressure,
    SUM(CASE WHEN e.gap_type = 'absolute_gap' THEN 1 ELSE 0 END)  AS n_absolute_gap,
    SUM(CASE WHEN e.gap_type = 'measured_gap' THEN 1 ELSE 0 END)  AS n_measured_gap,
    SUM(CASE WHEN e.gap_type = 'no_pressure'  THEN 1 ELSE 0 END)  AS n_no_pressure,
    ROUND(SUM(e.area_km2), 1)                                     AS total_desmatado_km2,
    a.area_municipio_km2,
    ROUND(SUM(e.area_km2) / a.area_municipio_km2 * 100, 2)        AS pct_desmatado,
    SUM(e.n_infractions)                                          AS n_infractions,
    ROUND(SUM(e.fine_values), 2)                                  AS total_fines
FROM project2.analytics.egs_final e
LEFT JOIN project2.marts.municipality_area a ON e.geocode_ibge = a.geocode_ibge
GROUP BY e.geocode_ibge, e.mun, e.uf, e.municipality_name, a.area_municipio_km2
ORDER BY AVG(e.egs) DESC, e.geocode_ibge;
```

Uma linha por município (805), sem filtro de consecutividade, sem populações separadas. O `ORDER BY AVG(e.egs) DESC, e.geocode_ibge` é o desempate determinístico na sua forma **revisada** (Fix S16.1, revisto pela auditoria de 2026-07-20): a primeira versão ordenava por `avg_egs_18y` — a coluna **arredondada** a 3 casas — o que criava empates artificiais que o geocode resolvia *contra* a ordem verdadeira (Monte Alegre 1,10893 vs. Aveiro 1,10870, ambos "1.109", e o geocode de Aveiro é menor — a próxima execução teria invertido o top 3/4 publicado). Ordenar por `AVG(e.egs)` (a média não-arredondada, recomputada no `ORDER BY`) preserva a ordem real; o geocode só desempata empates exatos (ex.: municípios com egs todo zero). Lição: desempate determinístico sobre uma coluna arredondada é determinístico *e* errado — o critério de ordem tem que ser a grandeza original, não a sua versão de exibição. As demais construções:

- **`AVG(e.egs)` — a média 0-fill.** Como `egs` é 0 (nunca `NULL`) nos anos sem pressão, esta média simples sobre 18 anos é, algebricamente, `média(egs | anos com pressão) × fração(anos com pressão)` — identidade verificada nos dados a ~1e-16 e monitorada pelo check `identity_mismatches`. É o "score composto" severidade × persistência computado como uma média direta, não como fórmula ponderada escondida. Substitui streaks + `priority_score` (removidos; Fixes S2/S3/S7 superados): dilui eventos pontuais sem regra arbitrária de "N anos consecutivos" — o exemplo trabalhado é Nova Nazaré/MT (maior severidade bruta do dataset, 2/18 anos de pressão, rebaixada para fora do top 10 pela média 0-fill sozinha).
- **`FILTER (WHERE e.year >= 2023)`** — cláusula do SQL padrão que restringe *uma* agregada específica sem afetar as demais nem exigir subquery: `avg_egs_3y` é a média 0-fill só de 2023–2025. Alternativa idiomática ao `AVG(CASE WHEN ... THEN egs END)` — mais legível, mesma semântica. (Nota herdada do S9: o dado PRODES do último ano pode não estar consolidado — "último ano sujeito a revisão".)
- **`COVAR_POP(e.egs, e.year) / VAR_POP(e.year)`** — o slope OLS de egs contra ano, computado manualmente pela definição (β = cov(x,y)/var(x)). Por que não `REGR_SLOPE()` nativo: havia um relato de comportamento não verificado (issue #12299) e a forma manual espelha exatamente o `cov(year, egs)/var(year)` do R — e as versões `_POP` vs. amostral dão o mesmo resultado aqui, porque a normalização (n vs. n−1) cancela na razão. Ressalva de leitura, validada com casos extremos: com poucos anos não-nulos o slope é dirigido pela posição de um ou dois pontos (evento único em 2024 → +0,005; dois eventos 2008/2017 → −0,017 — a distinção "problema novo" vs. "problema antigo" mora na segunda casa decimal). Por isso vem **acompanhado** de `avg_egs_3y` e de `n_years_pressure` como indicador de confiabilidade, nunca sozinho.
- **`SUM(CASE WHEN ... THEN 1 ELSE 0 END)`** ×4 — agregação condicional (o pivô manual clássico): transforma o `gap_type` categórico em quatro colunas de contagem lado a lado. O check `mismatched_year_counts` garante que as três somam 18 em todo município.
- **`pct_desmatado`** (resolve o Fix S12): total desmatado no painel como % do território do próprio município. Coluna de contexto, não critério de ordenação — captura um eixo diferente do avg_egs_18y (proporção do município já perdida vs. desproporção da resposta); o exemplo validado é Cujubim/RO, 29,79% do território desmatado no painel (máximo do dataset) com avg_egs_18y de só 0,578. Distribuição checada: mediana 0,97%, p75 3,19%.

O que **não** está mais aqui, e por quê: a técnica de gaps-and-islands (`year − ROW_NUMBER()` constante dentro de sequências consecutivas) e o `PERCENTILE_CONT ... WITHIN GROUP` + `CROSS JOIN` de broadcast do p75 saíram do pipeline junto com os rankings antigos. As duas técnicas continuam valendo como repertório de SQL analítico (a explicação detalhada está na versão anterior deste guia, no histórico do repositório) — mas o pipeline atual não precisa delas, e mantê-las explicadas aqui sugeriria que ainda fazem parte do sistema.

### 3.6 annual_summary

```sql
SELECT
    year,
    COUNT(*)                                                        AS n_municipalities,
    SUM(CASE WHEN gap_type = 'absolute_gap' THEN 1 ELSE 0 END)      AS n_absolute_gap,
    ...
    ROUND(AVG(CASE WHEN gap_type = 'measured_gap' THEN egs END), 3) AS avg_egs_measured_gap
FROM project2.analytics.egs_final
GROUP BY year ORDER BY year;
```

Mesma agregação condicional do ranking, uma linha por ano. Detalhe fino no `avg_egs_measured_gap`: o `CASE` sem `ELSE` retorna `NULL` fora de measured_gap, e `AVG` ignora nulos — então essa média é *só* dos anos measured_gap, deliberadamente (é a única média por categoria do pipeline, e aqui a restrição é o ponto).

### 3.7 ANALYTICS CHECKS

20 checks (o 19º, `n_floor_active_nominal = 61`, entrou na auditoria de 2026-07-20 junto com a persistência de `fine_values_nominal` em `egs_final`; o 20º, `deflator_2008 = 2.5826`, entrou na terceira auditoria — `deflator_2025 = 1.0` vale por construção para *qualquer* série, então só ele não pega um download errado do Sidra com a estrutura certa; este pina o valor real, reproduzido identicamente em Python/R/DuckDB), incluindo três que são **invariantes do design**, não contagens: `null_egs = 0` (a fórmula unificada nunca produz nulo), `identity_mismatches = 0` (a identidade algébrica do 0-fill vale em todos os 552 municípios com pressão), `n_floor_active = 28` (a população exata do piso, fixada pela validação). Checks de distribuição (`median/p75/max_pct_desmatado`) usam `MEDIAN` e `PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY ...)` — esta última é uma *ordered-set aggregate*: diferente de `SUM`/`AVG`, precisa da cláusula `WITHIN GROUP` para saber a ordenação sobre a qual interpola o percentil.

---

## 4. 04_export.sql

```sql
COPY project2.analytics.egs_final
    TO 'C:/Users/diogo/projects/project2/output/pbi_egs_final.parquet' (FORMAT PARQUET);
COPY project2.analytics.egs_ranking
    TO 'C:/Users/diogo/projects/project2/output/pbi_egs_ranking.parquet' (FORMAT PARQUET);
COPY project2.analytics.annual_summary
    TO 'C:/Users/diogo/projects/project2/output/pbi_annual_summary.parquet' (FORMAT PARQUET);
```

Três parquets agora (eram quatro): `pbi_egs_ranking.parquet` substitui os dois arquivos de ranking antigos. `COPY ... TO ... (FORMAT PARQUET)` materializa a tabela como Parquet — colunar, comprimido, lido nativamente pelo Power BI. O path é absoluto e literal, não `getvariable('data_root')`: não havia confirmação de que a cláusula `TO` aceita expressão em vez de literal (a sintaxe do `COPY` historicamente segue o Postgres, que exige literal) — incerteza documentada em vez de suposição arriscada. A pasta `output/` precisa existir antes (o `COPY` não cria diretórios), e o arquivo só deve rodar depois dos checks de 01–03.

**Check pós-export (novo na terceira auditoria de 2026-07-20).** O arquivo agora termina no seu primeiro check, `export_ranking_stale`: relê o parquet recém-escrito e compara a ordem física das 805 linhas com o ranking recomputado de `egs_final` (`row_number() OVER (ORDER BY AVG(egs) DESC, geocode)` — a mesma regra do `ORDER BY` de `egs_ranking`). É a guarda para o modo de falha que a auditoria de 2026-07-20 encontrou de verdade em produção (S18 item 7): parquet em disco gerado *antes* de uma correção de ordenação — conteúdo plausível, contagem certa, ordem errada; nenhum check de contagem pega. Depende de `preserve_insertion_order = true` (padrão do DuckDB) para a leitura preservar a ordem do arquivo. Nota de reprodutibilidade relacionada (terceira auditoria): `total_desmatado_km2` (`ROUND(SUM(...), 1)`) pode divergir em ±0,1 entre motores/threads por ordem de soma em ponto flutuante — a coluna não é bit-reproduzível; nenhum efeito em ranking.

---

## Pendências e observações conhecidas (registradas, não corrigidas por design)

- Os checks continuam sendo leitura visual — o formato consolidado com coluna `status` reduz o custo de conferir (um grid por arquivo, 54 no total), mas nada aborta a execução numa falha. A função `error()` do DuckDB poderia, em princípio, transformar um check em falha ativa — não implementado, sintaxe não confirmada.
- `04_export.sql` usa path absoluto hardcoded — ver §4.
- Nenhum arquivo valida pré-requisitos de ordem (rodar `03` sem `02` falha com "table not found" seco, sem mensagem amigável).
- O EGS é tratado como **ordinal** na prática: a ordenação é robusta (testada), mas distâncias entre scores não têm interpretação substantiva direta — nenhuma análise deve tratar 1,18 vs. 0,99 como "20% pior".
