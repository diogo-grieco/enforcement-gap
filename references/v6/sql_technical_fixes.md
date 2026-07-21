# SQL — Pendências Técnicas (sql_technical_fixes)

**Propósito:** registro de questões abertas encontradas na leitura do pipeline SQL (`01_staging.sql` → `04_export.sql`), no mesmo espírito do `p2_technical_fixes.txt` do projeto — mas aqui são itens **ainda não corrigidos**, levantados numa sessão de revisão externa (Claude), para investigação e decisão do autor. Documento vivo: continue adicionando entradas conforme a leitura avança.

**Convenção de entrada:** Status (aberto / em investigação / decidido / descartado) — Localização exata — Achado — Por que importa — Próximo passo.

**Aberto em:** 2026-07-16.

---

## Fix S1 — EGS não é uma métrica única entre `gap_type`

**Status:** RESOLVIDO (documentação) — 2026-07-16; **SUPERADO pela redesign — 2026-07-20.** A decisão original (opção (b), documentar a exceção sem unificar o cálculo) e a nota "Não alterado" abaixo descrevem o estado de 2026-07-16 e valeram por quatro dias: a v5 substituiu exatamente esse `CASE` pela fórmula unificada com piso no denominador (ver "Registro empírico" no fim do documento), eliminando na raiz a incomensurabilidade que este fix documentava. A resolução vigente do S1 é a da redesign, não a opção (b); o texto abaixo fica como registro histórico.

**Edições feitas:**
- `final_reference.md` §4 — parágrafo do EGS reescrito: agora diz explicitamente "computed for `measured_gap` cases", com uma nota de correção logo abaixo explicando a fórmula alternativa de `absolute_gap` e deixando registrado que nenhum dos dois rankings usa `egs` para ordenar (achado da conversa: `priority_score` é idêntico nas duas tabelas e não depende de `egs`).
- `p2_writing_sample.md`, seção "Por que essa fórmula, e não outra" — logo após a fórmula, um parágrafo novo explicando a exceção de `absolute_gap` e a mesma nota sobre os rankings não dependerem do EGS para ordenar.
- Cópias completas dos dois arquivos, com a edição aplicada, estão na pasta de saída — para você comparar com os originais e aplicar por cima.

**Não alterado (fora do escopo de "só documentar"):** nome da coluna `egs` no SQL, e o `CASE` que a calcula — permanecem como estão.

**Localização:** `03_analytics.sql`, CTE final de `egs_final`:

```sql
CASE gap_type
    WHEN 'no_pressure'  THEN NULL
    WHEN 'absolute_gap' THEN LOG(1 + area_km2)
    WHEN 'measured_gap' THEN LOG(1 + area_km2) / SQRT(LOG(1 + n_infractions) * LOG(1 + fine_values))
END AS egs
```

**Achado:** a coluna `egs` não é a mesma grandeza para as três categorias. Para `measured_gap` é a razão descrita na documentação (log área / raiz do produto de dois logs de enforcement) — a fórmula que aparece em `final_reference.md` §4 e em `p2_writing_sample.md`. Para `absolute_gap`, `egs` é só `LOG(1 + area_km2)`: magnitude de desmatamento, sem nenhuma informação de enforcement embutida. São duas escalas e dois significados diferentes sob o mesmo nome de coluna.

Isso contradiz uma afirmação explícita do `final_reference.md` §4: *"computed only where both deforested area and enforcement response are present and material"* — o que implicaria `egs = NULL` fora de `measured_gap`. Não é o que o código faz: `absolute_gap` recebe um valor não-nulo. O `p2_writing_sample.md` também apresenta a fórmula no singular, sem mencionar a exceção.

**Por que importa:** qualquer uso do parquet `pbi_egs_final.parquet` que agregue ou ordene por `egs` sem filtrar por `gap_type` (ex.: `AVG(egs)` no Power BI, um `ORDER BY egs DESC` genérico) mistura silenciosamente as duas grandezas. `annual_summary` já se protege disso (`avg_egs_measured_gap` filtra explicitamente), mas o parquet bruto não.

**Próximo passo — duas saídas possíveis, escolher uma:**
1. **Unificar:** `egs = NULL` também para `absolute_gap` (bate com o que a doc já afirma); se a magnitude de área ainda for útil para ordenar/visualizar esses casos no dashboard, expor como coluna separada (`deforestation_magnitude` ou similar), não como `egs`.
2. **Documentar a exceção:** manter as duas fórmulas, mas corrigir `final_reference.md` §4 e a seção "Por que essa fórmula" do writing sample para declarar explicitamente que `absolute_gap` usa uma fórmula-substituta (e por quê — provavelmente para evitar `NULL`/divisão indefinida quando `fine_values ≈ 0`), e nomear a coluna de forma que não sugira comparabilidade (`egs_or_area_log`, por exemplo).

Qualquer uma resolve a divergência doc↔código; a escolha errada é deixar como está.

---

## Fix S2 — `first_year`/`last_year` podem cobrir streaks não contíguos

**Status:** SUPERADO pela redesign (2026-07-20) — a nova metodologia (ver "Registro empírico" no fim do documento) abandona a detecção de streaks por completo: os rankings passam a ordenar por média do EGS 0-fill sobre os 18 anos, sem exigência de consecutividade. O problema descrito abaixo deixa de existir porque as colunas `first_year`/`last_year`/`max_streak` saem do design. Mantido como registro histórico.

**Localização:** `03_analytics.sql`, `ranking_absolute_gap` e `ranking_measured_gap`, agregação final:

```sql
SELECT
    geocode_ibge, mun, uf, municipality_name,
    MAX(streak_length)  AS max_streak,
    ...
    MIN(streak_start)   AS first_year,
    MAX(streak_end)     AS last_year,
    ...
FROM streaks
WHERE streak_length >= 3
GROUP BY geocode_ibge, mun, uf, municipality_name
```

**Achado:** se um município tiver mais de uma sequência consecutiva qualificante (ex.: `absolute_gap` em 2008–2011 *e*, separadamente, em 2016–2019 — duas ilhas, cada uma ≥ 3 anos), o `GROUP BY` final colapsa as duas em uma única linha. `max_streak` reporta corretamente o tamanho da maior sequência isolada (4), mas `first_year`/`last_year` viram `MIN`/`MAX` através de *todas* as sequências qualificantes, dando 2008–2019 — lê como 12 anos contínuos que nunca existiram. O comentário do arquivo ("`SUM` acumula área através de streaks ≥ 3, total persistence") justifica isso para `total_deforested_km2`, mas não trata `first_year`/`last_year` como sujeitos ao mesmo problema — e para essas duas colunas, ao contrário da área, a soma/faixa *não* é uma leitura razoável de "persistência total": é uma leitura enganosa de continuidade.

**Por que importa:** a palavra "sustentado" no `p2_writing_sample.md" ("238 casos de gap absoluto sustentado") depende implicitamente de continuidade. Se casos do top 10 atual tiverem múltiplas sequências separadas, a narrativa deveria dizer "N anos no total, em M períodos" em vez de implicar um intervalo contínuo.

**Próximo passo — query diagnóstica** (rodar dentro do `03_analytics.sql`, adaptando a CTE `streaks` de cada ranking):

```sql
-- quantos municípios têm mais de uma sequência qualificante (>= 3 anos)?
SELECT geocode_ibge, mun, COUNT(*) AS n_qualifying_streaks
FROM streaks
WHERE streak_length >= 3
GROUP BY geocode_ibge, mun
HAVING COUNT(*) > 1
ORDER BY n_qualifying_streaks DESC;
```

Rodar essa query para os dois rankings, sem filtrar ainda ao top 10 — depois cruzar especificamente com os 20 municípios já citados em `p2_municipal_research.md`. Se a lista vier vazia, o problema é teórico e pode ser fechado como "verificado, sem caso real". Se não vier vazia, decidir: (a) reportar `first_year`/`last_year` só da maior sequência (mais correto, perde informação sobre sequências anteriores), ou (b) manter o `MIN`/`MAX` mas adicionar uma coluna `n_qualifying_streaks` que sinalize descontinuidade, deixando o leitor do dashboard perceber.

---

## Fix S3 — `avg_egs` em `ranking_measured_gap` é média de médias, não ponderada

**Status:** SUPERADO pela redesign (2026-07-20) — a nova média (`AVG(egs_0fill)` sobre o painel completo de 18 anos, sem CTE intermediária de streaks) é uma média simples direta, sem o problema de média-de-médias. Mantido como registro histórico.

**Localização:** `03_analytics.sql`, `ranking_measured_gap`:

```sql
streaks AS (
    SELECT ...,
           ROUND(AVG(egs), 3) AS avg_egs,   -- média por sequência
           ...
    FROM qualifying
    GROUP BY ..., year - rn
)
SELECT ...,
       ROUND(AVG(avg_egs), 3) AS avg_egs,   -- média das médias por sequência
       ...
FROM streaks
WHERE streak_length >= 3
GROUP BY ...
```

**Achado:** se um município tiver uma única sequência qualificante, `avg_egs` final é a média correta dos anos daquela sequência. Se tiver mais de uma (mesma população do Fix S2), o `avg_egs` final é a média *não ponderada* das médias de cada sequência — equivale à média real só quando as sequências têm o mesmo número de anos. Uma sequência de 3 anos e uma de 8 anos pesam igual no resultado, quando a de 8 deveria pesar mais se o objetivo é "EGS médio ao longo de todos os anos qualificantes".

**Por que importa:** o desvio é pequeno na prática (afeta só `avg_egs`, não `priority_score`, que usa `MAX`/`SUM` diretamente), mas se `avg_egs` for citado como "EGS médio do período" na narrativa, vale nomear como aproximação ou trocar por uma média ponderada: `SUM(avg_egs * streak_length) / SUM(streak_length)`.

**Próximo passo:** decidir depois do resultado do Fix S2 — se não houver municípios com múltiplas sequências qualificantes, este item fecha sozinho (a distinção não existe na prática).

---

## Fix S4 — macros `assert_*` como equivalente a `stopifnot()`

**Status:** DESCARTADO — 2026-07-20, decisão do autor. O padrão de checks consolidados adotado na redesign (um `UNION ALL` por arquivo, coluna `status`, falhas visíveis num grid só) foi julgado suficiente; adicionar uma camada de `error()` abortante não paga o custo de mais complexidade no pipeline. Proposta abaixo mantida como registro, não será implementada.

**Motivação:** registrada em `sql_explained.md` — os checks do pipeline SQL são "leia e compare" (nenhum lança erro automaticamente se o valor não bater), diferente do `stopifnot()` do R, que aborta sozinho. Foi exatamente por isso que a discrepância dos rankings (238 vs. "200" documentado) passou despercebida por um tempo.

**Confirmado nesta sessão** (documentação oficial do DuckDB, função `error(message)`, scalar, categoria *utility functions*): lança a mensagem de erro dada. Exemplo da própria doc: `error('access_mode')`.

**Proposta — três macros reutilizáveis**, uma vez no topo do pipeline (ou em um `00_macros.sql` rodado antes de `01_staging.sql`):

```sql
CREATE OR REPLACE MACRO assert_eq(actual, expected, label) AS
    CASE WHEN actual != expected
         THEN error(label || ': esperado ' || expected::VARCHAR || ', veio ' || actual::VARCHAR)
         ELSE actual
    END;

CREATE OR REPLACE MACRO assert_zero(actual, label) AS assert_eq(actual, 0, label);

CREATE OR REPLACE MACRO assert_close(actual, expected, tol, label) AS
    CASE WHEN ABS(actual - expected) > tol
         THEN error(label || ': esperado ~' || expected::VARCHAR || ', veio ' || actual::VARCHAR)
         ELSE actual
    END;
```

Uso, substituindo um check atual (`01_staging.sql`, raw counts):

```sql
SELECT assert_eq((SELECT COUNT(*) FROM project2.staging.prodes_raw), 14490, 'n_prodes');
SELECT assert_eq((SELECT COUNT(*) FROM project2.staging.ibama_raw), 309116, 'n_ibama');
```

E um check de tolerância (`02_marts.sql`, `total_fines ~26.814.492.927` — o "~" já sugere que igualdade exata seria frágil):

```sql
SELECT assert_close(
    (SELECT ROUND(SUM(fine_value)) FROM project2.marts.ibama_clean),
    26814492927, 1, 'total_fines'
);
```

**O que não está confirmado, e por quê isso importa antes de propagar para os 4 arquivos:**
1. Que `CASE WHEN` no motor vetorizado do DuckDB de fato avalia `error()` só nas linhas onde a condição é verdadeira (comportamento padrão esperado de qualquer engine SQL, mas não testado neste ambiente especificamente).
2. Que `Execute SQL Script` (Alt+X) do DBeaver aborta o restante do script no primeiro `error()` não capturado, em vez de seguir para a próxima instrução — esperado, mas não confirmado no seu ambiente.

**Próximo passo:** testar isolado antes de qualquer rollout — `SELECT CASE WHEN 1=2 THEN error('não deveria disparar') ELSE 1 END;`, depois um caso forçado a falhar de propósito, num arquivo de teste separado. Só depois converter os ~15 checks reais, começando por `01_staging.sql` como piloto.

---

## Fix S5 — Verificação manual: os valores de `ipca_deflator` batem com o IPCA oficial?

**Status:** RESOLVIDO — 2026-07-20. A verificação linha a linha pendente aqui foi feita, por outro caminho, no registro empírico da redesign (fim do documento): o CSV Sidra real foi lido e reconstruído em Python/R/DuckDB, os 18 anos confirmados com 12 meses cada (e o Fix S14 adicionou o check equivalente em SQL), e `deflator(2008) = 2,5826` reproduzido identicamente nas três implementações — batendo com o "~2,6" já documentado e com a âncora externa independente (~2,56×) calculada abaixo. Considero isso equivalente à verificação linha a linha que faltava: mesma fonte primária (Sidra 1737/2266), resultado idêntico em três motores diferentes.

**Localização:** `01_staging.sql`, tabela `ipca_deflator`

**Achado:** os checks existentes (`missing_years`, `invalid_deflator`) só verificam estrutura — que os 18 anos estão presentes e que nenhum deflator é nulo ou ≤ 0. Nenhum check verifica se os *valores* batem com o índice IPCA real publicado pelo IBGE. É a mesma lacuna que existia no PRODES antes do Fix 15 (que cruzou `area_km2` contra a taxa oficial do INPE em 4 anos-âncora) — pelos documentos do projeto, esse cruzamento nunca foi feito para o IPCA.

**Verificação parcial feita agora (fonte externa, não a mesma do pipeline):** recalculei o multiplicador acumulado do IPCA entre 2008 e 2025 a partir da série de variação % anual publicada por um agregador de dados de mercado (não é a série bruta do Sidra t.1737 usada pelo pipeline, mas é derivada do mesmo IPCA/IBGE). Produto de (1 + variação anual) de 2009 a 2025 ≈ **2,56×** — próximo do `"deflator(2008) ~ 2.6"` já documentado no comentário do cabeçalho de `01_staging.sql`. A ordem de grandeza bate.

**O que isso NÃO confirma:** essa checagem usa metodologia diferente da do pipeline — variação % anual acumulada, ano civil, terceira fonte — contra a metodologia real do SQL (índice número mensal, base dez/93=100, média dos 12 meses de cada ano, direto da série Sidra t.1737 v.2266). É uma checagem de ordem de grandeza, não uma verificação linha a linha do arquivo `sidra_1737_v2266_ipca_indice_200801_202512_2026_07_10.csv` real. Não tive acesso a esse arquivo nem ao `project2.duckdb` para rodar a query de fato — só recalculei um número comparável de forma independente, por fora do pipeline.

**Por que importa:** o deflator entra multiplicando `fine_values` em `egs_base`, e por consequência afeta a magnitude do EGS e o `p75` usado em `ranking_measured_gap` no painel inteiro de 18 anos. Um erro sistemático no deflator (base errada, mês trocado, arquivo baixado errado) não quebraria nenhum check estrutural existente — só desviaria os valores de forma silenciosa, sem nenhum alarme.

**Próximo passo:** com acesso ao banco, rodar `SELECT * FROM project2.staging.ipca_deflator ORDER BY year;` e comparar os 18 valores de `deflator` (ou expor o `avg_index` intermediário numa CTE separada, se for mais fácil de comparar) contra a série oficial do Sidra tabela 1737, variável 2266, baixada direto do IBGE — não contra um agregador terceiro como foi feito aqui. Vale conferir com atenção extra 2020 (ano de maior distorção — pandemia) e 2021 (IPCA de 10,06%, o segundo maior do período), além dos 4 anos-âncora já verificados no PRODES.

---

## Fix S6 — Diferença de base do `LOG()` (SQL vs. R): o que de fato precisa de harmonização

**Status:** RESOLVIDO — 2026-07-20. A distinção fina entre "invariante de verdade" e "só preserva ranking" (registrada abaixo) deixou de ser o problema prático: a redesign trata o EGS como **ordinal** em todo lugar (SQL, `final_reference.md`, writing sample) — nenhum documento interpreta o valor absoluto do score, só a ordenação. Isso resolve a opção (a) do "próximo passo" original por enquadramento, sem precisar reescrever o comentário do cabeçalho ponto a ponto. Nota nova: o piso `GREATEST(1, ...)` introduzido na fórmula unificada quebra a invariância exata de base que valia para a razão pura (o `MAX` não escala linearmente com a constante de mudança de base) — mais um motivo, não previsto originalmente, para não interpretar o EGS numericamente entre bases. A opção (b) — usar `log10()` explícito se algum dia o EGS for recalculado em R — permanece como nota para o futuro, não fechada, mas de baixo risco dado o enquadramento ordinal.

**Localização:** `03_analytics.sql`, nota de cabeçalho (*"SCALE NOTE: LOG() in DuckDB is base 10 (R's log() is natural)"*); afeta `egs` (`measured_gap` e `absolute_gap`) e `priority_score` nos dois rankings.

**Achado:** refiz a álgebra pra saber exatamente o que a troca de base muda, em vez de aceitar "é monotônico" como afirmação genérica — a nota do cabeçalho trata os três casos como se fossem a mesma situação, e não são:

- `egs` em `measured_gap` (`LOG(1+area) / SQRT(LOG(1+n) * LOG(1+fine))`) é **matematicamente invariante à base do log** — não só preserva ranking, o valor numérico é *idêntico* em qualquer base. Trocar de base multiplica todo `LOG()` pela mesma constante `k`; no numerador vira `k·LOG10(...)`, no denominador vira `√(k²·...) = k·√(...)`, e o `k` do numerador cancela exatamente com o do denominador: `EGS_b = k·LOG10(1+area) / (k·√(LOG10(1+n)·LOG10(1+fine))) = EGS_10`.
- `egs` em `absolute_gap` (`LOG(1+area)` sozinho, sem razão) **não** é invariante — escala pela constante `k` (≈2,303, a razão entre `ln` e `log10`) ao trocar de base. Preserva ordenação (`k>0`), mas o número muda.
- `priority_score` (`LOG(streak) * LOG(1+area)`, produto de dois logs, não razão) também **não** é invariante — escala por `k²`. Preserva ordenação dentro do mesmo sistema, mas não é comparável número a número entre um cálculo em SQL e um em R com `log()` natural.

**Por que importa:** hoje isso não é um bug ativo — conferi o `exploring_script.R` inteiro e ele nunca calcula `egs` nem `priority_score`; a validação em R vai só até os checkpoints de classificação (`absolute_gap = 3.063`), que não usam log nenhum. Não existe hoje nenhum lugar onde um valor de `egs`/`priority_score` calculado em R é comparado a um calculado em SQL — a nota do cabeçalho é prevenção, não documentação de um problema já ocorrido. Mas se algum dia você (ou um leitor auditando o projeto) recalcular um `priority_score` ou um `egs` de `absolute_gap` em R pra conferir contra o parquet exportado, os números não vão bater a menos que use `log10()` em vez de `log()` — e isso pode parecer erro de pipeline quando é só base de log diferente.

**Próximo passo:** duas opções, não fechei nenhuma por você — (a) deixar como está, mas reescrever o comentário do cabeçalho distinguindo explicitamente "invariante de verdade" (`egs` de `measured_gap`) de "só preserva ranking, mas muda de valor" (`egs` de `absolute_gap`, `priority_score`); (b) se algum dia adicionar um cálculo de EGS em R (para simetria com a validação que já existe para a classificação), usar `log10()` explicitamente em vez de `log()`, e documentar isso como decisão tomada, não deixar implícito.

---

## Fix S7 — `priority_score` é cego ao tempo: 2008 e 2024 pesam igual

**Status:** SUPERADO pela redesign (2026-07-20) — o `priority_score` (produto de logs) foi abandonado. A dimensão temporal passa a ser tratada por duas colunas explícitas em vez de embutida num score: média do EGS dos últimos 3 anos (2023–2025) e slope OLS do EGS 0-fill contra o ano (com ressalva de confiabilidade registrada no "Registro empírico" abaixo). Mantido como registro histórico — a análise de dominância da área sobre o streak (item b abaixo) foi um dos motivos da decisão.

**Localização:** `03_analytics.sql`, agregação final dos dois rankings:

```sql
ROUND(LOG(MAX(streak_length)) * LOG(1 + SUM(area_in_streak)), 3) AS priority_score
```

**Achado:** o score é o produto de dois logs — tamanho da maior sequência qualificante e área total desmatada somada através de todas as sequências qualificantes. Nenhum componente temporal entra: um streak de 2008–2012 com 200 km² produz exatamente o mesmo score que um streak idêntico de 2020–2024. Um desmatamento grande em 2008 é, sim, mais prioritário no ranking que um um pouco menor em 2024 — o índice não tem nenhuma noção de recência. `first_year`/`last_year` existem como colunas descritivas, mas não entram no cálculo.

Dois agravantes: (a) o score é híbrido de forma pouco coerente quando há múltiplas sequências (mesma população do Fix S2) — `MAX` pega o comprimento de *uma* sequência, `SUM` acumula área de *todas*; o score mistura uma propriedade de uma sequência com uma propriedade do conjunto. (b) A compressão logarítmica faz a área dominar na prática: `streak_length` varia de 3 a 18 → `LOG10` varia de 0,477 a 1,255 (fator ~2,6×), enquanto a área varia ordens de magnitude → `LOG10(1+area)` pode variar de ~0,3 a ~3 (fator ~10×). O comprimento do streak é um multiplicador suave; a área é o motor do ranking.

**Por que importa:** a palavra "priority" implica acionabilidade presente — "onde a fiscalização deveria olhar agora". Um score cego à recência responde outra pergunta: "onde o Estado esteve cronicamente ausente na história do painel". As duas perguntas são legítimas, mas são perguntas diferentes, e o nome atual sugere a primeira enquanto o cálculo responde a segunda. Um município que resolveu seu gap em 2015 pode ranquear acima de um que está em gap aberto hoje.

**Próximo passo — três caminhos, não mutuamente exclusivos:** (a) manter o cálculo e renomear/reenquadrar (score de persistência histórica, não de prioridade operacional), documentando a cegueira temporal como decisão; (b) adicionar recência ao score — ex.: ponderar a área de cada ano por um decaimento (`area * decay^(2025 - year)`) antes do `SUM`, ou multiplicar o score por um fator de atividade (`last_year >= 2023`); (c) manter o score como está mas expor uma coluna/filtro `is_active` (streak toca o último ano do painel) no dashboard, deixando a dimensão temporal visível sem mexer na fórmula. Antes de escolher, vale rodar: quantos municípios do top 10 atual têm `last_year < 2023`? Se todos forem recentes, o problema é teórico no topo do ranking (mas ainda real no meio da tabela).

---

## Fix S8 — Ano PRODES (ago–jul) ≠ ano civil IBAMA: desalinhamento estrutural do same-year join

**Status:** DOCUMENTADO, não corrigido — 2026-07-20. Aplicado o "próximo passo" mínimo: a ressalva agora está em três lugares — `02_marts.sql` (comentário de `ibama_clean`), `03_analytics.sql` (decisão "i" no cabeçalho de `egs_ranking`) e `final_reference.md` §4. O texto em todos os três é o mesmo: o join por mesmo ano compara o calendário oficial do PRODES (ago *t*-1–jul *t*) com o ano civil do IBAMA, as janelas se sobrepõem em ~7 dos 12 meses, e a validação de lag do R foi feita sobre a base de ano civil, não contra a janela real do PRODES. O join em si **não foi alterado** — nenhuma decisão nova sobre refazer a análise de lag no nível mensal foi tomada; fica como próximo passo opcional, não obrigatório para o MVP.

**Localização:** `03_analytics.sql` (`p.year = i.year`); afeta também a análise de lag em `exploring_script.R` §6.

**Achado:** o "ano" PRODES não é ano civil. A taxa oficial do INPE é medida de **1º de agosto a 31 de julho** — o ano PRODES `t` cobre ago/`t-1` a jul/`t` (confirmado na página oficial do PRODES/INPE-OBT nesta sessão). Já o `year` do IBAMA é extraído de `DAT_HORA_AUTO_INFRACAO` — ano civil (jan–dez). O same-year join, portanto, compara janelas temporais que só se sobrepõem em ~7 meses (jan–jul de `t`): desmatamento de ago–dez de `t-1` cai no PRODES `t`, mas um auto lavrado nesses mesmos meses cai no IBAMA `t-1`; e autos de ago–dez de `t` respondem a desmatamento que o PRODES já contabiliza em `t+1`.

**Por que importa:** a análise de lag do R (59,2% both / 4,7% only_t / 1,0% only_t1) valida o same-year join empiricamente e provavelmente já absorve parte desse desalinhamento — mas ela foi feita e interpretada assumindo anos comparáveis, e o desalinhamento pode ser exatamente o que explica parte da categoria `only_t1` e do pico de lavraturas em set–out (estação seca, início do ano PRODES novo). Além disso, um leitor técnico da área de sensoriamento remoto vai notar isso imediatamente — é melhor o texto do projeto nomear a limitação do que parecer não saber dela.

**Próximo passo:** no mínimo, documentar (no `03_analytics.sql`, no `final_reference.md` §4 e no writing sample) que o join anual cruza calendário PRODES com ano civil IBAMA e que a validação empírica de lag foi feita sobre essa base. Se quiser ir além: refazer a análise de lag no nível mensal (usando o mês de `DAT_HORA_AUTO_INFRACAO` contra a janela ago–jul real do ano PRODES) para quantificar quanto do "same-year match" é artefato de janela — é uma análise de R razoavelmente contida, usando colunas que já existem.

---

## Fix S9 — Âncora 2025 do PRODES estoura a tolerância declarada ("<5%"), e o problema geral dos anos-borda

**Status:** RESOLVIDO (documentação) — 2026-07-20. `final_reference.md` §5 reescrito: agora reporta os quatro anchors individualmente (2008 +2,9%, 2012 −3,2%, 2024 −0,4%, todos dentro de ~3%; 2025 −8,3% a −9,3%, fora), em vez da afirmação genérica "<5%"/"a few percentage points throughout". A explicação provável (estimativa preliminar do PRODES para o ano em andamento vs. dado consolidado) é a mesma que já embasa a nota "último ano sujeito a revisão" já adotada na tabela final — as duas ressalvas agora se referenciam mutuamente. **Atualização (v4.4-2026-07-20):** com a incorporação das validações da redesign ao `exploring_script.R` (o script deixou de estar congelado), o comentário foi corrigido também na fonte primária do R — os quatro âncoras agora são reportados individualmente lá, não só nos documentos derivados.

**Localização:** `exploring_script.R` §5.3 (comentário) e `final_reference.md` §5.1.

**Achado:** o comentário do R afirma que os 4 anos-âncora batem com a taxa oficial do INPE com "diff. <5%", e o `final_reference.md` diz "agreement within a few percentage points throughout". Refazendo a conta com os próprios números citados no comentário: 2008: +2,9% ✓; 2012: −3,2% ✓; 2024: −0,4% ✓; **2025: 5.258 aqui vs. 5.731–5.796 oficial = −8,3% a −9,3% ✗**. O quarto âncora não passa no critério declarado — a afirmação "<5%" é falsa como está escrita.

**Por que importa (além do erro textual):** a discrepância de 2025 tem uma explicação provável que é ela mesma uma limitação metodológica não documentada — **anos-borda**. O PRODES divulga estimativa (~50% das imagens processadas) até dezembro e só consolida no primeiro semestre seguinte; um download de abril/2026 pode conter dado municipal de 2025 ainda não consolidado. Simetricamente, o IBAMA 2025 pode estar incompleto por atraso de registro (autos lavrados em 2025 ainda entrando na base em 2026). Ambos os efeitos distorcem o último ano do painel — e streaks que "terminam em 2025" podem ser artefatos de dado incompleto, não de gap real. Os rankings usam `last_year` até 2025 sem nenhuma ressalva.

**Próximo passo:** (1) corrigir o comentário do R e o `final_reference.md` — ou o critério ("<5%") ou a lista de âncoras que o satisfazem; não deixar a afirmação como está. (2) Verificar se o CSV do TerraBrasilis usado é estimativa ou consolidado para 2025 (comparar com a taxa consolidada quando o INPE publicar). (3) Considerar uma nota de "último ano sujeito a revisão" nos rankings/dashboard, ou truncar análises de streak em 2024 como sensibilidade.

---

## Fix S10 — Limiar de resposta (R$ 0,01) é fino demais: instabilidade do EGS na fronteira e assimetria com o lado da pressão

**Status:** RESOLVIDO pela redesign (2026-07-20) — o piso no denominador (`GREATEST(1, SQRT(LOG(1+n)*LOG(1+fine)))`) elimina a explosão do EGS perto da fronteira: com resposta quase-nula o denominador vale 1 e o EGS colapsa suavemente para `LOG(1+área)`, sem descontinuidade categórica. Validação empírica: com multas deflacionadas (base 2025), o piso ativa em exatamente 28 de 3.285 município-anos de `measured_gap` (0,9%; 61 se calculado com valores nominais — corrigido 2026-07-20, dizia 62) — precisamente os casos instáveis descritos abaixo — e reproduz a fórmula antiga nos demais 99,1% (e em 100% do `absolute_gap`). Ver "Registro empírico" no fim do documento. A sugestão de sensibilidade do limiar de resposta abaixo fica dispensada: o limiar deixa de ter efeito sobre o valor do EGS (permanece apenas como rótulo descritivo `gap_type`, se mantido).

**Localização:** `03_analytics.sql`, classificação (`fine_values < 0.01`) e fórmula do EGS.

**Achado:** o lado da pressão recebeu um limiar de materialidade justificado (1 km² = uma ordem de magnitude acima da unidade mínima de mapeamento do PRODES, "removendo ruído residual"). O lado da resposta não recebeu tratamento equivalente: **um único centavo deflacionado** separa `absolute_gap` de `measured_gap`. Consequências: (a) um município-ano com uma única multa de R$ 50 é classificado como "resposta presente" — substantivamente indistinguível de resposta nula, mas categoricamente diferente; (b) o EGS é instável perto dessa fronteira: com `fine_values → 0.01`, o denominador `SQRT(LOG(1+n)*LOG(1+fine))` → valor minúsculo e o EGS explode — os maiores valores de EGS do painel tendem a ser os casos com multa quase-nula, que são exatamente os menos informativos sobre "enforcement presente mas desproporcional". O p75 e o ranking `measured_gap` herdam essa sensibilidade.

**Por que importa:** a distinção conceitual central do projeto (gap absoluto vs. gap medido) repousa sobre uma fronteira operacional que não tem justificativa substantiva própria — foi definida para excluir zero, não para definir "resposta efetiva mínima". A simetria com o lado da pressão (que tem limiar justificado) é um argumento que um parecerista faria.

**Próximo passo:** análise de sensibilidade: recalcular a distribuição de `gap_type` e os dois top-10 com limiares alternativos de resposta (ex.: R$ 1 mil, R$ 10 mil deflacionados, ou "pelo menos 1 auto com valor > 0" vs. "valor total > X"). Se os rankings forem estáveis, documentar isso como robustez (resultado forte); se não forem, o limiar precisa de justificativa substantiva (ex.: valor mínimo de multa previsto na legislação para infração de flora — verificável no Decreto 6.514/2008).

---

## Fix S11 — Checkpoint R e classificação SQL do `absolute_gap` não são estruturalmente equivalentes (concordância é empírica)

**Status:** MITIGADO (rebaixado a nota de rodapé) — 2026-07-20. O risco prático caiu com a redesign: `gap_type` não alimenta mais a fórmula do EGS (é anotação), então uma eventual divergência entre as duas semânticas não contaminaria mais o índice principal, só a coluna descritiva. Em vez de alinhar as duas semânticas (opção mais cara, não feita) ou deixar implícito, `final_reference.md` §5 agora tem uma nota explícita dizendo que a validação cruzada R↔SQL é sobre a *população resultante*, não sobre a *regra* — exatamente a formulação sugerida no "próximo passo" original.

**Localização:** `exploring_script.R` §7 vs. `03_analytics.sql` classificação.

**Achado:** as duas operacionalizações de "resposta ausente" são semanticamente diferentes. R: existe *algum registro individual* com `fine_value >= 0.01` **nominal** (via `distinct` + `anti_join`). SQL: a **soma** dos valores do município-ano, **deflacionada**, é `>= 0.01`. Casos construíveis onde divergem: três autos de R$ 0,005 nominais (nenhum registro passa no R → `absolute_gap`; soma 0,015 × deflator ≥ 0,01 no SQL → `measured_gap`); ou um auto de R$ 0,009 nominal em 2008 (falha no R; 0,009 × 2,6 = 0,023 passa no SQL). O checkpoint bate (3.063 = 3.063) porque multas reais são ordens de magnitude maiores que a fronteira — concordância **empírica**, não estrutural. Nota de honestidade: na avaliação da sessão anterior eu afirmei que as duas eram "matematicamente equivalentes porque o deflator nunca é zero" — isso está errado como argumento geral; a equivalência que existe é contingente aos dados atuais.

**Por que importa:** o `final_reference.md` trata o checkpoint R como validação independente da classificação SQL. Ele é — mas só enquanto os dados não tiverem valores na zona de divergência. Uma atualização futura do IBAMA com micro-valores poderia quebrar o checkpoint sem nenhum bug em nenhum dos dois lados.

**Próximo passo:** ou alinhar as duas semânticas (fazer o R somar por município-ano e deflacionar, espelhando o SQL), ou documentar explicitamente no R e no `final_reference.md` que a validação cruzada é sobre a *população resultante*, não sobre a *regra*, e que a concordância depende de os valores reais estarem longe da fronteira. Se o Fix S10 elevar o limiar, este item deve ser resolvido junto.

---

## Fix S12 — Nenhuma normalização por tamanho do município (efeito de unidade de área)

**Status:** RESOLVIDO pela redesign (2026-07-20) — nova fonte de dados incorporada: `AR_BR_RG_UF_RGINT_RGI_MUN_2025.xls` (IBGE, Malha Municipal Digital, áreas territoriais 2025), convertido e testado. Match 100% (805/805 municípios PRODES) contra `CD_MUN`. Nova coluna na tabela final: `total_desmatado_km2 / area_municipio_km2` (% do território desmatado na janela de 18 anos). Distribuição real: mediana 0,97%, p75 3,19%, máximo 29,8% (Cujubim, RO). Top 10 por essa razão é uma lista **diferente** da top 10 por `avg_egs_18y` — ex.: Cujubim tem avg_egs=0,578 (bem abaixo do top 15 por severidade) mas 29,8% do território desmatado no período, maior proporção do painel. Confirma que a razão captura uma dimensão distinta (pressão relativa ao tamanho do município) e não deve substituir `avg_egs`, e sim acompanhá-la como coluna de contexto — mesma lógica das colunas de totais brutos.

**Localização:** fórmula do EGS e dos rankings (`area_km2` absoluta em toda parte).

**Achado:** municípios da Amazônia Legal variam de algumas centenas a >150.000 km² (Altamira/PA é maior que muitos países). `area_km2` absoluta entra no EGS e no `priority_score` sem nenhuma normalização — por área municipal, por cobertura florestal remanescente, ou por qualquer denominador de exposição. Um município gigante com desmatamento proporcionalmente pequeno pode gerar mais km² absolutos (e mais score) que um município pequeno sendo devastado proporcionalmente. É uma instância do problema clássico de unidade de análise em dados agregados por polígono administrativo (MAUP — *modifiable areal unit problem*).

**Por que importa:** os dois top-10 podem estar, em parte, ranqueando tamanho municipal, não intensidade de gap. Note que vários do top `measured_gap` (Itaituba, Jacareacanga, Aripuanã) estão entre os maiores municípios do país — não é prova de viés (municípios grandes na fronteira do desmatamento *deveriam* ranquear alto por qualquer critério), mas a correlação score×área municipal nunca foi medida.

**Próximo passo:** diagnóstico barato antes de qualquer mudança: juntar a área territorial oficial (IBGE, disponível na mesma API de localidades já usada) e calcular a correlação entre `priority_score` e área municipal nos dois rankings. Se alta, discutir normalização (área desmatada / área municipal, ou / floresta remanescente PRODES) como análise alternativa — não necessariamente substituta: km² absolutos são defensáveis para priorização operacional (hectares reais de floresta perdida), desde que a escolha seja *documentada como escolha*.

---

## Fix S13 — Inconsistências numéricas e textuais entre documentos (varredura 2026-07-16)

**Status:** RESOLVIDO — 2026-07-20. Itens 1, 2 e 6 corrigidos; itens 3, 4 e 5 ficaram *moot* (o texto que continha o erro não sobreviveu à reescrita da redesign — verificado por busca nos documentos atuais, não presumido).

**Achados, um por linha, com resolução:**

1. **Lag numbers divergiam entre arquivos** (`02_marts.sql` "4.8%/0.7%" vs. `exploring_script.R` "4.7%/1.0%") — corrigido: `02_marts.sql` agora usa os números do R (fonte primária), com nota de correção no próprio comentário.
2. **`final_reference.md` §4 rotulava errado as categorias do lag** (chamava 4,7% de "lag one year", quando é `only_t`/mesmo-ano-só; o lag-um exclusivo é 1,0%) — corrigido, com a formulação completa das quatro categorias (59,2% / 4,7% / 1,0% / 35,1%) e nota explícita do erro anterior.
3. **"21,1 pontos percentuais"** — não aparece em nenhum documento reescrito da redesign; a passagem inteira (limiar >0 vs ≥1 do EGS antigo) foi substituída pela discussão do limiar de materialidade testado por sensibilidade. Moot.
4. **`05_rankings_audit.sql`** — não é citado em nenhum documento reescrito; a arquitetura de rankings que o motivava (streaks, dois rankings separados) não existe mais. Moot.
5. **Gramática ("A correção aplicada um deflator...")** — o parágrafo inteiro foi reescrito na redesign do writing sample. Moot.
6. **Code-switching, `p2_municipal_research.md`** ("ver ressalva already registrada") — corrigido para "já registrada" numa cópia do arquivo salva em outputs (o original em uploads é somente leitura), com nota de topo marcando o documento como histórico/superado por `final_reference.md` §10. **Atualização (auditoria 2026-07-20): a cópia corrigida nunca voltou ao repositório — o item constava como resolvido sem estar. Correção aplicada agora diretamente em `references/v5/p2_municipal_research.md`, incluindo a nota de topo.**

---

## Fix S14 — Check de "12 meses por ano" existe no R, não no SQL do IPCA

**Status:** RESOLVIDO — 2026-07-20. Check `ipca_months_not_12` adicionado ao bloco consolidado de `02_marts.sql` (reconstrói a CTE `long` do `ipca_annual`, agrupa por ano, conta meses, falha se algum ano ≠ 12). Total de checks de marts passa de 21 para 22; total do pipeline, de 46 para 47. Confirmado na re-execução real de 2026-07-20: `status = OK`, fechando 47/47 no pipeline completo.

**Localização:** `01_staging.sql`, `ipca_deflator` + seção de checks.

**Achado:** o R valida o IPCA com 5 assertivas, incluindo `all(count(ipca_raw, year)$n == 12)` — exatamente 12 meses por ano. O SQL não tem equivalente: a combinação `ignore_errors = true` + `null_padding` + o filtro regex `'^\d+(,\d+)?$'` pode descartar silenciosamente um mês malformado, e o `AVG(...)` do ano passaria a ser sobre 11 meses — deflator levemente errado, sem nenhum alarme. Os checks existentes (`missing_years`, `invalid_deflator`) não pegariam: o ano continua presente e o deflator continua positivo.

**Por que importa:** é o mesmo modo de falha silenciosa que motivou os checks de contagem de coluna adicionados na auditoria anterior (Fix 17 do projeto) — o R tem a proteção, o SQL não, e o SQL é o pipeline de produção.

**Próximo passo:** adicionar à seção de checks do `01_staging.sql` uma query que conte meses por ano na CTE `long` (ou reconstruindo-a) e compare com 12 — se o Fix S4 (macros assert) for implementado, este vira um `assert_zero` de uma linha (`COUNT(*) WHERE n_months != 12`).

---

## Fix S15 — Fontes brutas são mutáveis; os checkpoints vão quebrar para replicadores futuros

**Status:** PARCIALMENTE RESOLVIDO — 2026-07-20. Item (1) do próximo passo original feito: `README.md` ganhou a seção "Datas de download e reprodutibilidade", com a data de snapshot de cada uma das 5 fontes (quando registrada — IBAMA continua sem data rastreável em lugar nenhum, achado que o próprio fix já previa) e o aviso explícito de que os valores esperados dos checks são daquele snapshot. Itens (2) checksums SHA-256 e (3) parquets intermediários versionados **não** foram feitos — ficam como próximo passo genuíno, não urgente.

**Localização:** `README.md` (instruções de download) + todos os checkpoints numéricos (R e SQL).

**Achado:** o IBAMA revisa retroativamente os CSVs históricos de autos de infração (registros são cancelados, corrigidos, adicionados), e o PRODES consolida o último ano depois da estimativa. Os checkpoints exatos (`309.116`, `60.707`, `26.814.492.927`, `3.063`...) são fotografias do download de uma data específica — qualquer pessoa que baixar os dados no futuro e rodar o pipeline vai ver `stopifnot()` e checks falharem sem que exista nenhum bug. O README documenta a data de download apenas no nome do arquivo do IPCA; PRODES tem timestamp no nome do arquivo, IBAMA não tem data registrada em lugar nenhum.

**Por que importa:** o projeto se apresenta como reproduzível ("regeneráveis a partir das fontes primárias"), mas a reprodução literal falha por design — e um replicador não tem como distinguir "os dados mudaram na fonte" de "o pipeline está quebrado". Isso é padrão em dados administrativos vivos, mas precisa ser dito.

**Próximo passo:** (1) registrar no README as datas de download dos 4 conjuntos e o aviso explícito de que os valores esperados dos checks são específicos daquele snapshot; (2) opcionalmente, gravar checksums (SHA-256) dos arquivos brutos num `data_manifest.txt` versionado; (3) considerar publicar os agregados intermediários (não os brutos) como parquets versionados, permitindo reprodução da camada analítica sem depender da fonte viva.

---

## Fix S16 — Itens menores (estilo e determinismo), agrupados

**Status:** item 1 RESOLVIDO (2026-07-20); itens 3–4 SUPERADOS pela redesign (a arquitetura que motivava — p75 e streaks — não existe mais); item 2 aberto, baixo risco.

1. ~~**Empates no `ORDER BY priority_score DESC` sem critério de desempate**~~ — **RESOLVIDO** (e **REVISADO pelo S18**). `priority_score`/streaks não existem mais, mas o problema se recriou em `egs_ranking.avg_egs_18y` (arredondado a 3 casas, empates possíveis). A primeira correção (`ORDER BY avg_egs_18y DESC, e.geocode_ibge`) era determinística mas **errada** — ordenava pela coluna arredondada, criando empates artificiais que o geocode resolvia contra a ordem verdadeira; o S18 item 1 a substituiu pela forma vigente, `ORDER BY AVG(e.egs) DESC, e.geocode_ibge` (média não-arredondada). Ler este item junto com o S18; o estado atual do código é o do S18. (Nota adicionada na terceira auditoria, 2026-07-20 — este item descrevia a implementação superada como se fosse a vigente.)
2. **`n_infractions > 0` dentro de `absolute_gap`:** ainda vale — registros com `fine_value` NULL contam em `COUNT(i.geocode_ibge)` mas não em `SUM(fine_value)`, então um município-ano pode ser `absolute_gap` (rótulo descritivo) com `n_infractions > 0`. Coerente com a decisão de que "resposta sem efeito monetário ≠ resposta", mas visualmente contraditório num dashboard. Ainda sem nota no dicionário de dados do parquet — próximo passo genuíno, baixa prioridade, natural de anotar ao montar o Power BI.
3. ~~**p75 pooled no painel inteiro**~~ — moot: `PERCENTILE_CONT`/p75 não existe mais na v5, o EGS não é mais comparado contra um percentil para classificar.
4. ~~**`total_deforested_km2` mal nomeado**~~ — moot: a coluna equivalente em `egs_ranking` (`total_desmatado_km2`) soma a área dos 18 anos completos do painel, não de streaks qualificantes (que não existem mais) — o nome já descreve o conteúdo corretamente.

---

## Fix S17 — Check de geocode inválido no IBAMA tinha ponto cego pra NULL (achado real: 29, não 23)

**Status:** RESOLVIDO (documentação + correção do check) — 2026-07-20.

**Localização:** `01_staging.sql`, bloco de STAGING CHECKS, `invalid_geocode_ibama`.

**Achado:** o check original (`WHERE LENGTH(COD_MUNICIPIO) != 7`, "expected: 0, otherwise document it") rodou contra o `ibama_raw` real e deu 23, não 0. Investigação: os 23 são todos o mesmo valor, `COD_MUNICIPIO = '431173'` — Manoel Viana, RS, com um código de 6 dígitos malformado (o código IBGE correto é `4311759` — corrigido 2026-07-20 contra o `municipios.json`: a entrada anterior dizia 4311773 e atribuía o erro a "zero à esquerda perdido", mecanismo impossível — nenhum código IBGE começa com 0, os prefixos de UF vão de 11 a 53; mecanismo real da corrupção desconhecido). Além disso, o check original tinha um ponto cego: existem mais **6 registros com `COD_MUNICIPIO` literalmente NULL** que a condição `LENGTH(...) != 7` não pega, porque em SQL `LENGTH(NULL)` avalia para `NULL`, e `NULL != 7` não satisfaz o `WHERE` (lógica de três valores) — um falso negativo silencioso. O total real é 29.

**Por que importa:** nenhum dos dois grupos afeta `egs_final`. Manoel Viana é do Rio Grande do Sul, fora da Amazônia Legal — mesmo com o código corrigido, nunca bateria com nenhum dos 805 geocodes do PRODES. Os 6 registros com geocode nulo são linhas de lixo puro (`MUNICIPIO`, `UF` e `DES_STATUS_FORMULARIO` também nulos) e já são excluídos do `ibama_clean` pelo filtro `DES_STATUS_FORMULARIO = 'Lavrado'`, por outro motivo. Achado confirmado inofensivo — vale registrar precisamente por isso: não é óbvio até se investigar, e um check com ponto cego (mesmo que o resultado final não mude) é o tipo de coisa que definitivamente deveria ser encontrada numa auditoria.

**Próximo passo:** nenhum — já corrigido. O check em `01_staging.sql` agora é `WHERE COD_MUNICIPIO IS NULL OR LENGTH(COD_MUNICIPIO) != 7`, esperado 29, com a composição documentada no comentário do arquivo.

---

## Fix S18 — Auditoria adversarial externa (2026-07-20): drift protótipo→prosa e tiebreak arredondado

**Status:** APLICADO — 2026-07-20 (patch completo em `AUDIT_PATCH_2026-07-20.md`, blocos A–F; SQL re-executado, 51/51 checks OK, parquets regenerados).

**Achados e correções (resumo):** (1) o `ORDER BY` do `egs_ranking` ordenava pela média **arredondada** — empates artificiais resolvidos pelo geocode *contra* a ordem verdadeira (Monte Alegre 1,10893 vs Aveiro 1,10870, ambos "1.109"); corrigido para `ORDER BY AVG(e.egs) DESC, geocode`. (2) Números de protótipo (nominal) haviam driftado para a prosa: Apuí 0,748→0,743 e 0,775→0,770, com "pico histórico 2020–22" falso (máximo pontual real: 2009, 1,459, ano de auto único); "62 com nominal"→61; 0,583→0,582; Monte Alegre 1,110→1,109; "two largest federal responses" falso (máximo real: Altamira, R$3,75 bi/1.454 autos); R$112M "deflated" era nominal (deflacionado: R$115M). (3) S17 registrava código IBGE errado (correto: 4311759) e mecanismo impossível ("zero à esquerda"). (4) A unidade da validação de lag é o **auto** (n = 60.707), não o município-ano. (5) `fine_values_nominal` não era persistida — agora está em `egs_final`. (6) +4 checks (3 de `prodes_clean` + `n_floor_active_nominal = 61`): 47→51. (7) Os parquets de `output/` estavam stale em relação ao S16.1 — re-exportados. (8) Claim de "triple cross-validation" rebaixada (artefatos Python não preservados); a replicação externa da auditoria (ibama_clean exato, deflator, classificação) registrada em `final_reference.md` §5.2. (9) S13 item 6 constava resolvido sem a correção ter voltado ao repo — aplicada agora. Itens editoriais remanescentes: checklist nomeada em `final_reference.md` §11.4.

---

## Fix S19 — Terceira auditoria adversarial (2026-07-20): resíduos do patch S18 e guardas de falha silenciosa

**Status:** APLICADO — 2026-07-20 (relatório completo em `AUDIT_3_2026-07-20.md`).

**Método:** replicação independente do pipeline inteiro a partir dos CSVs brutos (DuckDB em ambiente isolado), comparada célula a célula com os parquets de produção e com o `project2.duckdb` (aberto somente-leitura). Resultado central: **pipeline e parquets corretos** — todos os 51 esperados reproduzidos exatamente; ordem do ranking confirmada (Monte Alegre #3, Aveiro #4, GLR 54, Itaituba 129, Aripuanã 140, Apuí 141); todos os números de caso da prosa recomputados e confirmados (série anual de Apuí, Cumaru, Cachoeira, Nova Nazaré, âncoras PRODES, lag 59,2/4,7/1,0/35,1).

**Achados e correções (todos aplicados nesta passada):**
1. **Resíduos do S18** — quatro lugares que o patch não alcançou, cada um contradizendo a correção aplicada nos demais: `final_reference.md` §7.6 (ainda dizia "dropped leading zero"/S17); `sql_explained.md` §3.5 (bloco de código e explicação mostravam o `ORDER BY avg_egs_18y` pré-A1 — exatamente o bug que o A1 corrigiu) e §3.4 (SELECT sem `fine_values_nominal`); `exploring_script_explained.txt` ("62" do protótipo); e o próprio S16 item 1 deste documento (descrevia a implementação superada como vigente).
2. **Prosa mais forte que o dado** (narrative): "most alarming in the entire table" para Aveiro (Nova Santa Helena/MT tem média 3y maior: 1,561 vs 1,508 — claim re-escopado ao top 20); "~47 autos/ano" rotulado como "historical level" de Apuí (47 é a média 2020–22; o histórico 2008–19 é ~35/ano); "dataset maximum is Altamira: 1,454 notices" (máximo em valor, sim; em autos é Porto Velho, 2.938 — introduzido pelo próprio patch C2); faixa de Cumaru 16–181 → 15–182; mediana de GLR 4,6 → 4,65 (valor exato; fronteira de arredondamento).
3. **Três modos de falha silenciosa sem check** → três guardas novas, verificadas contra o banco de produção antes de entrar: `total_area_prodes_clean = 140019` (02_marts — único check de magnitude do lado PRODES; sem ele um CSV trocado com a forma certa passava), `deflator_2008 = 2.5826` (03_analytics — `deflator_2025 = 1.0` vale por construção para qualquer série; este pina o valor real), `export_ranking_stale = 0` (04_export — o modo de falha do S18 item 7, parquet com ordem antiga, seguia sem guarda). Total de checks: 51 → **54** (7 + 26 + 20 + 1), contagens atualizadas em README, final_reference, narrative, writing sample e sql_explained.
4. **Git:** HEAD ainda era o commit da v3 — todo o v4/v5/v6 e o patch S18 estavam sem commit; `references/` fora do versionamento; o CSV do IPCA "versionado" divergia do commitado. Corrigido com o commit desta leva (decisão do autor, 2026-07-20).
5. **Citações:** Portaria 1.202/2024 confirmada (data, autor), mas os anexos no link da Lex são paywall — o overlap 8/20 é verificável pela matéria do O Liberal (nomeia os 8, todos PA); Portaria GM/MMA 1.716 confirmada existente (19/06/2026, critérios; programa 2026 com 89 municípios) — a 1.717 (lista) segue por obter; links SEMAS/Agência Pará/Agência Amazonas são JS e seguem não verificados por máquina — os dois últimos **adicionados** à checklist do §11.4, que só citava a SEMAS.
6. **Nota de reprodutibilidade:** `total_desmatado_km2` (ROUND(SUM,1)) diverge em ±0,1 em 10/805 municípios entre motores/threads (ordem de soma em ponto flutuante) — não é bug; documentado no §4 do sql_explained.

---

## Registro empírico — validação da redesign dos rankings (2026-07-20)

**Contexto:** a partir da discussão metodológica que superou S2/S3/S7 e resolveu S10, as decisões da nova metodologia foram testadas contra os dados reais (CSVs IBAMA 2008–2025 + TerraBrasilis 25/04/2026), reproduzindo o pipeline em Python (DuckDB indisponível no ambiente de teste). Este registro guarda os números como base empírica de cada decisão — para citação no `final_reference.md`/writing sample quando a implementação SQL for feita.

**Validação da reprodução (baseline):** os três checkpoints do pipeline bateram exatos — painel PRODES 14.490 linhas / 805 geocodes / 18 anos; `ibama_clean` 60.707 linhas (total nominal R$ 26.814.492.927); classificação 8.142 `no_pressure` / 3.285 `measured_gap` / 3.063 `absolute_gap` (checkpoint documentado: 3.063). O deflator IPCA foi reconstruído do CSV Sidra real (12 meses/ano confirmados nos 18 anos; deflator 2008 = 2,5826, coerente com o "~2,6" documentado) e o `municipality_ref` do `municipios.json` real (5.571 municípios, 0 UFs nulas via caminho `regiao-imediata`). A classificação com valores deflacionados reproduz o checkpoint exato (3.063). **Efeito do deflator no ranking final (média 0-fill):** overlap 9/10 no top 10 nominal vs. deflacionado, Spearman ≈ 1,0 nos 805 municípios — a deflação corrige os valores mas quase não move posições. Números abaixo já regenerados com deflação onde indicado.

**Decisão 1 — piso no denominador (`GREATEST(1, SQRT(LOG(1+n)*LOG(1+fine)))`), adotada.** Base empírica (multas deflacionadas, base 2025): reproduz a fórmula antiga exatamente em 100% do `absolute_gap` e em 3.257/3.285 (99,1%) do `measured_gap`. Os 28 casos divergentes (0,9%; seriam 61 com valores nominais — corrigido 2026-07-20, o registro anterior dizia 62; fixado pelo check `n_floor_active_nominal` — a deflação engorda o denominador e tira casos da zona instável) são os de denominador bruto < 1 (mínimo observado: 0,796) — exatamente os casos de instabilidade da fronteira de R$ 0,01 (S10); o piso os torna mais conservadores (EGS menor). Distribuição do denominador bruto deflacionado no `measured_gap`: mediana 2,06, p25 1,55, máximo 4,56 — ou seja, o piso é inerte para a massa dos dados.

**Decisão 2 — manter o limiar de materialidade (1 km²) na fórmula, adotada.** Base empírica em duas partes. (a) Custo de remover: 3.392 município-anos (23,4% do painel) com 0 < área < 1 km² ganhariam EGS entre 0 e 0,301 — magnitude comparável ao 5º percentil inferior dos EGS reais de anos com gap (mediana 0,585); não é efeito de canto, é injeção de ruído. (b) Análise de sensibilidade do ranking: rodando a média EGS 0-fill com limiar 1 km², 6,25 ha (mínimo mapeável PRODES) e sem limiar, os top 10/20/50 são **idênticos** nas três versões e o Spearman entre os rankings completos (805 municípios) é 0,985 — apesar de 22,7% das observações mudarem de classificação entre os limiares. Conclusão forte: o ranking é robusto à escolha do limiar; o limiar afeta apenas a estatística descritiva (o "56,2% sem pressão", confirmado exato nos dados). Citável como resultado de robustez.

**Decisão 3 — média EGS 0-fill (18 anos) como ordenação principal, adotada.** Base empírica: (a) identidade algébrica `média_0fill = média_excluindo_zeros × fração_anos_com_pressão` confirmada nos dados (diferença máxima ~1e-16); (b) correlação entre severidade (média excluindo zeros) e frequência (fração de anos com pressão) nos 552 municípios qualificados (deflacionado): Pearson 0,621 / Spearman 0,696 — as duas dimensões andam juntas, o que explica (c) overlap de 9/10 entre o top 10 por severidade pura e por 0-fill. (d) O único caso divergente: **Nova Nazaré (MT)** — maior severidade média do dataset (1,384 deflacionado; episódios isolados de 11 km² em 2008 e 63 km² em 2017, com 2/18 anos de pressão) cai para 0,154 no 0-fill e sai do top 10; entra Itupiranga (PA) (1,029 com 18/18 anos). Decisão editorial consciente: um sistema de *monitoramento de lacunas persistentes* rebaixa eventos pontuais — documentar Nova Nazaré como exemplo trabalhado da limitação, no registro do caso Barra do Bugres. Os demais 9 do top 10 têm 18/18 anos de pressão (severidade e 0-fill coincidem exatamente). Também dispensa filtro de N mínimo de anos: filtro (≥3 anos) + ordenação por severidade dá overlap 10/10 com o 0-fill.

**Decisão 4 — situação atual: média EGS últimos 3 anos (2023–2025) E slope OLS, ambas como colunas.** Base empírica da ressalva sobre o slope: teste com casos extremos deu Palmeiras do Tocantins (TO) (evento único, 2024) slope +0,005 vs. Nova Nazaré (eventos 2008/2017) slope −0,017 — a distinção "problema novo" vs. "problema antigo encerrado" fica em diferenças da segunda casa decimal; com poucos pontos não-nulos o slope é dominado pela posição exata do pico. Por isso o slope entra **acompanhado** da média recente (mais legível e robusta), não sozinho; reportar `n_anos_com_pressão` ao lado como indicador de confiabilidade. Pendência técnica herdada: verificar comportamento do `REGR_SLOPE` do DuckDB (issue #12299) antes de usar em produção.

**Tabela final decidida (colunas):** município/UF, EGS médio (0-fill, 18 anos), EGS médio últimos 3 anos (2023–2025), slope OLS, nº anos com pressão, total desmatado (km²), nº total de autos, valor total de multas (deflacionado). Duas notas de rodapé obrigatórias: (1) as colunas de totais são contexto bruto, não insumos recalculáveis do EGS (média de razões ≠ razão de somas); (2) **"último ano sujeito a revisão"** — o dado PRODES 2025 pode não estar consolidado (ver S9), e a janela de 3 anos o inclui; decisão de 2026-07-20: manter a janela 2023–2025 apenas com a nota, sem sensibilidade adicional 2022–2024.

**Validação final em DuckDB real (2026-07-20):** o pipeline reestruturado (v5 — `ipca_raw`/`municipality_ref_raw`/`municipality_area_raw` em staging; `municipality_ref`/`municipality_area`/`ipca_annual` em marts; `ipca_deflator`/`egs_ranking` em analytics) rodou de ponta a ponta no ambiente real do autor (DuckDB via DBeaver), não só em Python/R. Todos os checks consolidados (7 em staging, 21 em marts, 18 em analytics) passaram — inclusive a identidade algébrica do 0-fill e a distribuição de `pct_desmatado`, checadas via SQL, não só documentadas em texto. Único ajuste necessário: formatação de `CAST(ROUND(...) AS VARCHAR)` deixando um `.0` residual num check (`total_fines_ibama_clean`) — corrigido com `CAST(...AS BIGINT)` antes do `VARCHAR`; não era erro de dado. Fix reconfirmado em re-execução real (2026-07-20): 21/21 checks de marts OK, fechando 46/46 no pipeline completo (contagem anterior à adição do check do S14; com ele, 22 em marts e 47/47 no total).

**Verificação externa do ranking (2026-07-20):** (a) Cruzamento com a lista MMA de municípios prioritários (Portaria GM/MMA nº 1.202/2024, 81 municípios, ~71% do desmatamento de 2024 na Amazônia Legal): 8/20 do top 20 constam na lista (Cumaru do Norte, Itupiranga, Jacareacanga, Medicilândia, Mojuí dos Campos, Prainha, Santa Maria das Barreiras, Santana do Araguaia) — metodologias independentes convergindo. Lista atualizada 2026 (Portarias 1.716/1.717) não obtida; overlap real pode ser maior. (b) Limitação federal-only agora concreta: SEMAS-PA (Operação Curupira: 196 autos, R$87,9M, 30.592 ha embargados acumulados; PA −28,4% desmatamento em 2024) e IPAAM (Tamoiotatá 2025: R$144,7M em multas, 16.176 ha interditados, incluindo Maués) atuam exatamente nos estados de 18/20 municípios do topo — recomendação: nomear a métrica "lacuna de fiscalização *federal*" nos documentos. (c) Cumaru do Norte identificado como caso de *fiscalização federal presente e ineficaz* (112 autos, R$761,9M deflacionados em 12/18 anos, desmatamento persistente) — perfil distinto de "ausência", documentar se citado. (d) Apuí como validação temporal: EGS médio 0,743 em 2020–22 (pior trecho sustentado; o máximo pontual da série é 2009, 1,459, ano de auto único — corrigido 2026-07-20, o número anterior, 0,748, era do protótipo nominal; área 440 km²/ano) → resposta 2023–25 (95 autos/ano, R$115M/ano deflacionados — corrigido 2026-07-20, o "112" anterior era a média nominal) → EGS cai a 0,564, capturado pelas colunas avg_3y (0,564 < 0,668) e slope (−0,012); rank #141 no 18y é o design funcionando, não falha.

**Protótipo gerado (2026-07-20, com deflator real):** tabela completa dos 805 municípios exportada como `egms_tabela_final_prototipo.csv` (arquivo **não preservado** no repositório — constatado na auditoria de 2026-07-20; a conferência vigente é a replicação externa registrada em `final_reference.md` §5.2). Top 15 inteiramente composto por municípios com 18/18 anos de pressão (PA dominante, com MA e AM); as colunas de situação atual funcionam como desenhadas — ex.: Aveiro (PA), avg 18 anos = 1,109 vs. avg 3 anos = 1,508 e slope +0,042 (piorando agora), contra Arame (MA), avg 18 anos = 1,078 vs. avg 3 anos = 0,722 e slope −0,033 (melhorando). Referência para conferência quando o SQL definitivo for implementado.

---

## Varredura de fechamento (2026-07-20)

Releitura completa do documento contra o estado atual dos entregáveis. Resultado: dos 17 fixes S1–S17, **15 fechados** (6 pela redesign de 2026-07-20: S1, S2, S3, S7, S10, S12; mais 9 nesta passada: S17 — correção de check, independente da redesign, reclassificado na auditoria de 2026-07-20 —, S4 descartado; S5, S6, S8, S9, S11, S13, S14 resolvidos ou mitigados/documentados) e **2 com item residual de baixo risco, sem ação pendente crítica**: S15 (checksums/parquets versionados, opcional) e S16 (nota de dicionário de dados para `n_infractions` em `absolute_gap`, natural de fazer ao montar o Power BI). Nenhum item aberto bloqueia o MVP.

Arquivos tocados nesta passada: `02_marts.sql` (comentário de lag corrigido + nota de calendário S8 + check `ipca_months_not_12`), `03_analytics.sql` (nota de calendário S8 + desempate no `ORDER BY`), `README.md` (seção de datas de snapshot), `final_reference.md` (lag corrigido, âncora 2025 corrigida, nota de calendário, nota S11, contagem de checks 46→47), `sql_explained.md` (mesmas correções refletidas na explicação), `p2_municipal_research.md` (cópia corrigida em outputs, com nota de documento histórico).

---

*Itens futuros: adicionar aqui conforme a leitura dos SQLs avançar. Manter o mesmo formato (Status — Localização — Achado — Por que importa — Próximo passo) para facilitar consolidação futura com `p2_technical_fixes.txt`, se algum desses itens virar correção efetiva.*
