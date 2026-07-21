# Portfolio Reference — Technical & Conceptual Update
**Versão:** 1.0 | **Data:** 2026-05-04  
**Contexto:** P2 em fase final (pipeline v3, Power BI pendente). Documento para contextualização ao retomar P1, P3, P4.

---

## 1. Posicionamento do Portfolio

**Objetivo estratégico:** transição para análise de dados aplicada e doutorado quantitativo. Construir sinal técnico, não acumular credenciais.

**Posicionamento:** quantitative applied researcher (policy / environment / humanitarian).

**Princípio operacional:** converter expertise existente em outputs rigorosos, técnicos e visíveis.

### Narrativa de sistema

O portfolio não é quatro projetos separados. É um ciclo completo de gestão baseada em evidências:

```
P3 — Detecta sinais antecipados (mídia, atenção pública)
  ↓
P2 — Monitora se o enforcement está respondendo à pressão real
  ↓
P1 — Decide onde alocar intervenção sob restrições de capacidade
  ↓
P4 — Avalia se o enforcement reduz desmatamento (inferência causal)
```

Essa cadeia — **detecção → monitoramento → alocação → avaliação** — transforma o portfolio num sistema coerente, não numa coleção de exercícios técnicos. É o argumento central para o website e para qualquer entrevista.

---

## 2. P2 como Âncora de Qualidade

P2 é o projeto mais forte por três razões combinadas: dados reais de acesso público, pipeline SQL reproduzível end-to-end, e decisões analíticas com validação empírica documentada. O que foi estabelecido em P2 define o padrão mínimo para os outros projetos.

### 2.1 O que P2 entregou (estado v3, 2026-05-04)

**Dados:**
- PRODES (INPE): 800 municípios × 18 anos (2008–2025), Amazônia Legal
- IBAMA: 60.707 autos filtrados (pipeline v3), 9 fixes documentados
- Unidade de análise: município-ano (14.490 observações)

**Indicador central — EGS:**
```
EGS = LOG(1 + area_km2) / SQRT(LOG(1 + n_autos) * LOG(1 + val_multas))
```
- Alto EGS = gap maior = maior prioridade de inspeção
- Numerador: pressão de desmatamento
- Denominador: média geométrica de presença (n_autos) e intensidade (val_multas)

**Classificação (pipeline v3):**
| tipo_egs | n | % |
|---|---|---|
| completo | 7.893 | 54.5% |
| gap_absoluto | 3.784 | 26.1% |
| sem_pressao | 2.813 | 19.4% |

**Priority score (gap_absoluto persistente):**
```
priority_score = LOG(max_streak) × LOG(1 + total_desmatado_km2)
```
Requer streak ≥ 3 anos consecutivos e area_km2 ≥ 1 km².

**Thresholds empíricos:**
- p75 EGS = 0.5891 (qualificação no ranking completo)
- streak_min = 3 anos (ciclo eleitoral — decisão de design documentada)
- val_multa threshold = 0.01 (evita floating-point contamination)

**Pipeline SQL (DuckDB):**
```
01_staging.sql → 02_marts.sql → 03_analytics.sql
```
Três layers, 9 fixes documentados, checks de integridade em cada camada.

### 2.2 Padrões metodológicos estabelecidos

Esses padrões foram estabelecidos em P2 através de falhas, correções e validação empírica. Devem ser aplicados aos outros projetos desde o início, não retroativamente.

**Padrão 1: Nenhuma decisão analítica sem base empírica.**
Cada parâmetro tem uma origem documentada: p75 calculado dinamicamente, streak_min justificado por ciclo eleitoral, join temporal validado com 4 sub-análises. Qualquer constante inline ("magic number") sem justificativa é um risco de auditoria.

**Padrão 2: Funil de filtragem documentado.**
Em P2: 309.116 registros brutos → 60.707 filtrados. Cada etapa de remoção documentada com contagem e justificativa. Filters semânticos com análise das distribuições dos campos relevantes antes de escrever a query.

**Padrão 3: Análise de sensibilidade antes de publicar.**
Em P2: 17.4% dos gap_absoluto mudariam com join t+1. P1 tem problema equivalente com os pesos 60/40. P3 tem o problema da threshold de sinal. Nenhum resultado deve ser apresentado sem robustness check documentado.

**Padrão 4: Limites interpretativos explícitos.**
PRODES ≠ ilegalidade confirmada. IBAMA ≠ enforcement total. EGS ≠ efetividade. Cada projeto deve ter sua seção equivalente: o que o indicador mede e o que ele não mede. Isso não é fraqueza metodológica — é o sinal de que o analista entende validade de constructo.

**Padrão 5: Checks de integridade no pipeline.**
`stopifnot` no R. `-- Expected: 0` nos SQL checks. Qualquer pipeline sem verificação de contagem, nulos e range de valores é não-auditável. Em P1 e P3, construir essa camada desde a primeira iteração.

**Padrão 6: Decisão-output chain explícita.**
Cada projeto deve responder em menos de 5 segundos: qual a decisão, sob qual restrição, qual a regra, qual a ação imediata. P2 entrega isso: "inspecionar top-N municípios por priority_score, com N configurável no Power BI." P1 e P3 precisam do mesmo.

---

## 3. P1 — Targeting System: Avaliação e Questões Abertas

### 3.1 Estado atual (conforme summary)

**Decisão:** alocar orçamento de intervenção socioambiental em 40 municípios.  
**Regra:** `Rank = 0.6 × deforestation + 0.4 × vulnerability`  
**Classificação:** 4 quadrantes (alta/baixa pressão × alta/baixa vulnerabilidade).  
**Ação:** financiar top-40; tipo de intervenção por quadrante.

O design é conceitualmente correto — a lógica de quadrantes é acionável e comunicável. O problema é que está subdesenvolvido nos pontos onde P2 mostrou que o diabo mora.

### 3.2 Questões abertas críticas (resolver antes de construir)

**Q1: Por que 60/40?**  
O peso 60/40 em deforestation/vulnerability não tem justificativa documentada. Em P2, o equivalente seria usar p75 hardcoded sem calcular. Três alternativas:  
- Análise de sensibilidade bootstrap: testar 50/50, 60/40, 70/30 e verificar se o top-40 é estável. Se ≥ 80% das municípios permanecem no top-40 em todos os cenários, o resultado é robusto e o peso é defensável como escolha de design.  
- Decisão de política explícita: "deforestation recebe peso maior porque é o critério primário de elegibilidade programática" — precisaria de citação ou protocolo de referência.  
- Estimação de pesos por regressão: regredir outcomes (enforcement posterior, redução de desmatamento) no score para encontrar pesos ótimos preditivos. Mais sofisticado, justificável para PhD.

**Q2: O que é o threshold de classificação dos quadrantes?**  
Alta/baixa pressão e alta/baixa vulnerabilidade precisam de um ponto de corte. Três opções com implicações distintas:  
- Mediana (p50): corte simétrico, 25% em cada quadrante — defensável como distribuição igual de categorias.  
- p75: corte mais restritivo, "alta" pressão = top 25% — maximiza especificidade, reduz recall.  
- Threshold por política: cutoff derivado de critério externo (ex: municípios acima da média nacional de desmatamento PRODES). Mais defensável para audiência de policy, mas exige fonte.  
A escolha tem impacto direto em quantos municípios entram no top-40 de cada categoria.

**Q3: Qual a fonte de dados de vulnerabilidade e quais indicadores?**  
O summary menciona "income deprivation, service access, and related vulnerability proxies" mas não especifica. Fontes candidatas:  
- IBGE Censo 2022: renda per capita, acesso a serviços, taxa de analfabetismo — mais atualizado.  
- Atlas de Desenvolvimento Humano (PNUD/FJP): IDH municipal por dimensões — já normalizado, fácil de usar.  
- IVS (IPEA): Índice de Vulnerabilidade Social — já composto, mais defensável metodologicamente mas menos transparente.  
- CadÚnico: proxy de vulnerabilidade extrema — alta granularidade, mas acesso pode ser restrito.  
Recomendação: IBGE Censo 2022 para transparência e reprodutibilidade.

**Q4: P1 é cross-sectional ou longitudinal?**  
O design atual parece ser estático (um recorte temporal). Mas P2 mostrou que persistência é o sinal mais importante — municípios que permanecem no gap por múltiplos anos têm prioridade diferente dos que flutuam. P1 poderia incorporar tendência temporal:  
- Usar média de deforestation dos últimos 3 anos em vez do valor pontual.  
- Identificar municípios em trajetória de piora vs estabilização.  
- Prioridade diferente para "crônico" vs "emergente".  
Isso não complica o output — ainda é uma tabela rankeada — mas muda o que o rank representa.

**Q5: Qual a relação entre P1 e P2?**  
P2 identifica municípios com gap de enforcement persistente (gap_absoluto, streak ≥ 3). P1 identifica municípios com alta pressão E alta vulnerabilidade. A interseção é o argumento mais forte do portfolio:  
*"Municípios que aparecem simultaneamente no ranking gap_absoluto (P2) e no quadrante crítico (P1) são os candidatos mais fortes para intervenção integrada."*  
Isso só funciona se P1 e P2 usarem o mesmo geocode municipal como chave de join — o que é possível se ambos usam PRODES como fonte de deforestation. **Usar a mesma base PRODES é o que viabiliza o portfolio como sistema.**

### 3.3 O que fazer ao retomar P1

1. Definir fontes de dados exatas e baixar antes de escrever qualquer código.
2. Definir thresholds com justificativa documentada (escolher uma das opções em Q2).
3. Construir análise de sensibilidade bootstrap nos pesos (Q1) — 100 simulações com pesos aleatórios entre 40/60 e 70/30, calcular Jaccard index do top-40. Se ≥ 0.75, reportar resultado como robusto.
4. Adicionar dimensão temporal na deforestation (média 3 anos).
5. Adicionar join com gap_absoluto do P2 como camada de validação cruzada.

**Inferential extension (P1 INFERENTIAL do summary):**  
Regredir deforestation_t+1 no score P1_t. Se o score prevê desmatamento futuro, é um índice de alerta, não só de alocação. Isso muda o framing de "onde alocar" para "onde o risco vai piorar" — mais atraente para policy.

---

## 4. P3 — Signal Pipeline: Avaliação e Questões Abertas

### 4.1 Estado atual (conforme summary)

**Decisão:** priorizar regiões para advocacy/monitoramento com base em anomalias de atenção pública.  
**Dados:** GDELT Project + NewsAPI + DETER realtime (Twitter API descartado — pago desde 2023).  
**Escala:** milhões de registros, justificando BigQuery.  
**Indicadores:** mention volume, growth rate, signal score (composição dos dois).  
**Regra:** growth rate > p90 AND volume > baseline → flag region.

### 4.2 Questões abertas críticas

**Q1: GDELT é a fonte certa?**  
GDELT é genuinamente grande (bilhões de eventos desde 1979, atualizado a cada 15 minutos) e tem dataset público no BigQuery — o que valida a escolha de infraestrutura. Mas tem problemas conhecidos:  
- Cobertura desigual por idioma: português sub-representado em relação ao inglês.  
- Atribuição geográfica imperfeita: eventos são geocodificados pelo local mais mencionado no artigo, não necessariamente o local do evento.  
- Sem acesso direto ao texto: GDELT é metadata (URLs, geocodes, sentiment scores do GCAM), não conteúdo.  
Para P3, GDELT é defensável como escolha de infraestrutura e escala, mas a limitação de cobertura em português precisa estar na seção de interpretive limits.

**Q2: Como definir o signal score empiricamente?**  
O summary define o sinal como "growth rate > p90 AND mention volume > baseline". Mas:  
- Qual é o baseline? Média rolling de 30 dias? Média histórica por região? Z-score?  
- O p90 é calculado sobre qual distribuição? Todas as regiões no mesmo período? Cada região separadamente?  
- Se calculado globalmente: regiões sempre com alto volume (AM, PA) nunca atingem crescimento relativo significativo.  
- Se calculado por região: regiões com zero histórico têm threshold artificialmente baixo.  
Em P2, o equivalente foi o problema do p75 hardcoded vs dinâmico. A solução é calcular threshold intra-região com Z-score rolling: `(volume_t - mean_rolling_90d) / std_rolling_90d > 2`. Regiões com histórico curto têm Z-score menos confiável — documentar como limitação.

**Q3: A validação cruzada com PRODES/P2 é o achado mais importante.**  
O summary menciona isso como "P3 INFERENTIAL" mas deveria ser parte do design core, não uma extensão:  
- Se signal score prediz desmatamento PRODES subsequente: P3 é um early warning válido — achado metodologicamente relevante.  
- Se desmatamento prediz signal score: mídia é reativa, não antecipativa — também é um achado, mas muda o posicionamento do projeto de "early warning" para "monitoramento de cobertura".  
- Se não há relação: o sinal de mídia é desconectado da realidade física — limitação crítica.  
Recomendação: fazer esse teste antes de construir o dashboard. Se a direção causal for reativa (PRODES → sinal), o projeto se posiciona como "tracking de atenção pública", não "early warning". Isso não invalida o projeto, mas muda o framing.

**Q4: BigQuery vs DuckDB**  
BigQuery faz sentido se GDELT for usado como fonte (já disponível como BQ public dataset). Para o volume de GDELT, DuckDB não escalaria bem (dezenas de GB por ano). A arquitetura BigQuery → analytics table → Power BI é o stack correto para P3.  
Diferença técnica relevante para o portfolio: DuckDB (P2) demonstra competência com dados locais e pipeline reproduzível. BigQuery (P3) demonstra competência com dados na nuvem e SQL em escala. Os dois juntos cobrem stacks diferentes — boa diferenciação.

**Q5: Unidade de análise — região-dia é correto?**  
Região-dia gera tabelas grandes e sinal ruidoso. Considerar:  
- Região-semana para sinais mais estáveis.  
- Município-dia se GDELT tiver granularidade municipal suficiente (improvável para Brasil interior).  
- Estado-dia como unidade intermediária.  
DETER realtime opera com polígonos diários — se integrado com GDELT, a unidade de análise deve ser compatível. Verificar granularidade geográfica do GDELT para o Brasil antes de definir a unidade.

### 4.3 O que fazer ao retomar P3

1. Verificar cobertura do GDELT para Brasil/português antes de qualquer build (query exploratória no BQ public dataset).
2. Decidir Z-score rolling como threshold de sinal — documentar janela temporal e parâmetros.
3. Fazer o teste PRODES ↔ signal score (Granger ou correlação com lag) antes de construir o dashboard — o resultado define o framing do projeto.
4. Usar estado como unidade de análise se GDELT não tiver granularidade municipal.

---

## 5. P4 — Extension Layer: Decisão e Design Técnico

### 5.1 Análise das opções

O summary identifica três direções. Com P2 finalizado e o panel de 14.490 observações disponível, a escolha é mais clara do que parecia quando o summary foi escrito.

**Opção A: NLP sobre textos policy/administrativos**  
Ponto forte: demonstra Python + NLP, diferencia do resto do portfolio.  
Problemas: (1) requer corpus de textos policy sobre enforcement ambiental em português — acesso não garantido. (2) A conexão com P2 é fraca — NLP sobre textos é metodologicamente distante do sistema de monitoramento. (3) Risco de virar projeto genérico de NLP sem ancoragem nos dados reais.  
Viável, mas o argumento de coerência do portfolio é mais fraco.

**Opção B: ML preditivo sobre P2**  
Treinar um classificador para prever gap_absoluto_t+1 com base em características do município.  
Ponto forte: usa os dados do P2, demonstra Python + sklearn.  
Problemas: (1) os dados do P2 não têm features de território além de area_km2 — precisaria de dados adicionais (IBGE censo, infraestrutura, bioma) que não estão no pipeline atual. (2) O modelo preditivo sem features ricas é trivial e defensável apenas pelo EGS do ano anterior. (3) Risco de virar um exercício de overfitting em vez de análise substantiva.  
Viável com dados adicionais. Mas exige scope adicional significativo.

**Opção C: Econometria — TWFE + event study [RECOMENDADA]**  
Two-way fixed effects panel regression e event study em torno do choque de 2019 (desmantelamento do IBAMA sob Bolsonaro).  
Pontos fortes:  
- Usa exatamente os dados do P2 sem dados adicionais.  
- O choque de 2019 é documentado, geograficamente variável, e sharp — condições adequadas para event study.  
- É a extensão inferencial natural de um sistema de monitoramento: P2 responde "onde o gap existe", P4 responde "o enforcement reduz o desmatamento?".  
- Python tem suporte adequado via `linearmodels` (TWFE) e `econml` ou implementação manual do event study.  
- Demonstra capacidade inferencial — o sinal mais valioso para doutorado quantitativo.  
- É defensável metodologicamente com as ressalvas corretas.

### 5.2 Design técnico de P4 (Opção C)

**Questão de pesquisa:** o enforcement IBAMA (medido pelo EGS ou n_autos) causa redução de desmatamento PRODES no município seguinte?

**Dados:** egs_final do P2 — panel equilibrado, 14.490 observações, 800 municípios × 18 anos.

**Modelo 1 — TWFE básico:**
```
deforestation_{i,t} = α_i + γ_t + β × EGS_{i,t-1} + ε_{i,t}
```
- `α_i`: fixed effects municipais (controla confundidores time-invariant — ex: área total, bioma, distância de rodovias)
- `γ_t`: fixed effects anuais (controla shocks nacionais — ex: políticas federais, seca, eleições)
- `β`: efeito do enforcement passado sobre desmatamento atual
- Interpretação: não causal (time-varying confounders persistem), mas associação controlada e robusta

**Modelo 2 — Event study (choque 2019):**
```
deforestation_{i,t} = Σ_k β_k × D_{t=2019+k} + α_i + γ_t + ε_{i,t}
```
- Estimativa dos coeficientes para cada ano em torno de 2019 (-5 a +5 anos)
- Identifica se houve mudança estrutural no desmatamento após o desmantelamento institucional
- Teste de parallel trends pré-2019 é a falsificação natural
- Variação geográfica: municípios com diferentes níveis de dependência do enforcement federal são o grupo de controle natural

**Modelo 3 — Granger causality (exploratory):**
```
deforestation_{i,t} ~ deforestation_{i,t-1..k} + EGS_{i,t-1..k} + α_i
EGS_{i,t} ~ EGS_{i,t-1..k} + deforestation_{i,t-1..k} + α_i
```
- Teste bidirecional: enforcement prediz desmatamento? Desmatamento prediz enforcement?
- Resultado em qualquer direção é um achado
- Não é causalidade de Granger verdadeira com FE — enquadrar como "precedência temporal"

**Limites inferenciais a documentar:**
- TWFE não elimina confundidores time-varying (preços de commodities, ciclos eleitorais locais, expansão de infraestrutura)
- Enforcement federal é endógeno ao desmatamento — IBAMA prioriza municípios com maior pressão
- Sem instrumento exógeno credível, o coeficiente β não é interpretado como causal
- A ressalva certa é: "controlando para heterogeneidade municipal e chocks temporais, maior enforcement passado está associado a menor desmatamento subsequente" — associação robusta, não causalidade

**Implementação Python:**
```python
# utils.py       — carregamento e validação do egs_final
# data_prep.py   — construção do panel balanceado, lags, dummies de evento
# features.py    — EGS, gap_absoluto dummy, streak features
# model.py       — TWFE via linearmodels, event study manual
# evaluation.py  — coeficientes, CIs, testes de robustez
# main.py        — orchestração do pipeline
```

Pacotes principais: `linearmodels` (TWFE com within estimator), `pandas`, `statsmodels` (para Granger), `matplotlib`/`seaborn` (event study plots).

**Output-chave:** event study plot com coeficientes anuais e intervalo de confiança — visualmente compacto, tecnicamente defensável, substantivamente relevante. É o "one chart that explains everything" do P4.

---

## 6. Questões Transversais

### 6.1 Identificação causal — caveat cross-cutting

Nenhum dos quatro projetos alcança identificação causal limpa. TWFE controla confundidores time-invariant, mas não elimina time-varying. Esse limite deve ser declarado explicitamente em cada projeto:

*"Este design não permite inferência causal. Controla por heterogeneidade municipal não observada (FE municipais) e por chocks temporais comuns (FE anuais), mas não elimina confundidores time-varying como preços de commodities agrícolas, ciclos eleitorais locais, ou expansão de infraestrutura. Os coeficientes devem ser interpretados como associações parcialmente controladas, não como efeitos causais."*

Declarar esse limite com precisão é o sinal inferencial que diferencia o portfolio de exercícios técnicos ingênuos.

### 6.2 Escopo — viés estrutural da Amazônia Legal

P2 é explicitamente restrito à Amazônia Legal. P1 usa PRODES — mesmo bioma. P3 usa GDELT — sem restrição geográfica. P4 usa os dados de P2 — mesmo escopo.

O portfolio como está tem viés de cobertura: Cerrado, Caatinga, Mata Atlântica ficam de fora. Esse viés reproduz o viés estrutural dos sistemas de monitoramento brasileiros — e deve ser declarado como limitação no README e no site, não ignorado. A extensão para outros biomas é tecnicamente viável mas requer spatial join (coordenadas IBAMA × polígonos de bioma) e harmonização de séries PRODES por bioma — fora do escopo do MVP.

### 6.3 Stack técnico por projeto

| Projeto | Stack principal | Diferenciação |
|---|---|---|
| P1 | R + tidyverse + ggplot | Análise exploratória + visualização de decisão |
| P2 | DuckDB + SQL + R + Power BI | Pipeline local, dados reais, 9 fixes documentados |
| P3 | BigQuery + SQL + Power BI | Cloud, escala, dados de alta frequência |
| P4 | Python + linearmodels | Inferência econométrica, extensão do P2 |

Cada projeto usa uma ferramenta principal distinta. Essa diversidade é intencional e deve ser comunicada: demonstra capacidade de escolher o stack certo para o problema, não dependência de uma única ferramenta.

### 6.4 GitHub e reprodutibilidade

P2 tem o pipeline mais rigoroso do portfolio. A disciplina de reproducibility estabelecida (README, sequência de execução, checks por camada) deve ser replicada nos outros projetos. Critério mínimo por projeto:

- `README.md` com: fontes de dados, sequência de execução, outputs esperados, limitações conhecidas.
- Sem dados brutos no repositório se houver restrições de licença.
- Checks de integridade executáveis (não só comentados).
- Sem magic numbers sem comentário de justificativa.

### 6.5 Website — o que mostrar primeiro

A regra do summary original permanece válida: cada projeto responde em < 5 segundos. O que falta é a camada de coerência — mostrar o sistema, não apenas os projetos. Sugestão para o top block do site:

```
SISTEMA: Onde o desmatamento acontece sem resposta institucional?
  P3 → Detecta atenção pública (GDELT + BigQuery)
  P2 → Monitora o gap de enforcement (PRODES + IBAMA + DuckDB)
  P1 → Aloca intervenção (PRODES + vulnerabilidade + R)
  P4 → Estima se enforcement funciona (panel econometrics + Python)
```

Esse framing transforma quatro projetos em um argumento.

---

## 7. Prioridades ao Retomar Outros Projetos

### Ao iniciar P1
1. Confirmar fonte de vulnerabilidade (IBGE Censo 2022 recomendado).
2. Definir e documentar threshold de classificação antes de qualquer código.
3. Construir análise de sensibilidade dos pesos (bootstrap).
4. Usar mesmo geocode IBGE do P2 como chave de join.
5. Adicionar join com gap_absoluto do P2 como validação cruzada.
6. Construir checks de integridade no início (não retrospectivamente).

### Ao iniciar P3
1. Query exploratória no GDELT BQ public dataset para verificar cobertura Brasil/português.
2. Definir unidade de análise empiricamente (município vs estado vs região).
3. Testar precedência temporal sinal ↔ PRODES antes de construir dashboard.
4. Definir Z-score rolling como threshold de sinal.
5. Documentar limitações de GDELT (cobertura, atribuição geográfica) desde o início.

### Ao iniciar P4
1. Exportar egs_final como parquet ou CSV para uso em Python.
2. Construir panel balanceado (verificar municípios com dados faltantes por ano).
3. Implementar TWFE primeiro (mais simples) antes do event study.
4. Calcular os lags corretamente (EGS_{t-1} para prever deforestation_t).
5. Documentar identificação — o que o design controla e o que não controla.
6. Event study plot é o output central — priorizar sobre tabelas.

---

*Gerado 2026-05-04. Baseado em: Portfolio Projects Summary v2, Portfolio Strategy Summary, e estado atual do P2 (pipeline v3, 60.707 registros, 14.490 observações, p75 = 0.5891).*
