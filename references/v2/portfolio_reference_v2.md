# Portfolio Reference — Technical & Conceptual Update
**Versão:** 3.0 | **Data:** 2026-05-07
**Contexto:** P2 em fase final (pipeline v3, script R exploração seção IBAMA locked, Power BI pendente). Documento para contextualização ao retomar P1, P3, P4.
**Changelog v3:** script R seção IBAMA locked; val_multa total confirmado R$26.814.492.927; lag numbers corrigidos (ver session_reference_v3); próximas etapas atualizadas.
**Changelog v2:** revisão crítica completa — narrativa de sistema corrigida, P3 reposicionado como instrumento de advocacy, P4 reframed, P1 Jaccard corrigido, usuários primários por projeto adicionados.

---

## ⚠ Flags de risco — ler antes de qualquer outra seção

**Flag 1 — Narrativa do portfolio depende de decisão de design em P3.**
A versão anterior posicionava P3 como "detecção antecipada" que precede P2. Isso exigia precedência temporal (sinal midiático → desmatamento), que pode não se confirmar empiricamente. A narrativa foi corrigida: P3 e P2 são instrumentos paralelos, não sequenciais. O argumento de coerência do portfolio não depende mais de uma condição causal não verificada.

**Flag 2 — P3 requer teste empírico de cobertura GDELT antes de qualquer build.**
Para os top-20 municípios do ranking gap_absoluto de P2 (Governador Luiz Rocha, Fortuna, Arame, etc.), verificar volume de eventos GDELT geocodificados nessas localidades. Se a resposta for zero ou próximo de zero para a maioria, a unidade de análise tem que ser estado, não município. Essa decisão bloqueia toda a arquitetura de P3.

**Flag 3 — P4 sem controles time-varying é limitação, não vantagem.**
"Usa exatamente os dados de P2 sem dados adicionais" foi apresentado como ponto forte na v1. É o contrário: ausência de controles para preços de commodities, expansão de infraestrutura e ciclos eleitorais locais limita a interpretação do coeficiente. Ver seção 5.

---

## 1. Posicionamento do Portfolio

**Objetivo estratégico:** transição para análise de dados aplicada e doutorado quantitativo. Construir sinal técnico, não acumular credenciais.

**Posicionamento:** quantitative applied researcher (policy / environment / humanitarian).

**Princípio operacional:** converter expertise existente em outputs rigorosos, técnicos e visíveis.

### Narrativa de sistema (corrigida v2)

O portfolio não é quatro projetos separados. É um sistema de monitoramento, alocação e avaliação de enforcement ambiental:

```
P2 — Monitora onde o gap de enforcement é persistente (PRODES + IBAMA)   ──┐
                                                                             ├──→ P1 — Aloca intervenção sob restrições de capacidade
P3 — Mapeia onde o gap tem atenção pública (GDELT + NewsAPI)             ──┘         ↓
                                                                                    P4 — Avalia se enforcement reduz desmatamento
```

P3 e P2 são instrumentos paralelos que informam a mesma decisão de alocação. A integração mais forte do portfolio é o argumento cruzado: municípios que aparecem simultaneamente no quadrante gap_absoluto persistente (P2) **e** no quadrante de baixa atenção (P3) são os candidatos mais fortes para intervenção integrada — enforcement *e* comunicação.

> **Nota sobre a narrativa anterior:** A cadeia linear P3 → P2 → P1 → P4 dependia de P3 detectar sinais *antes* de P2 monitorar, o que exige precedência temporal do sinal midiático sobre o desmatamento. O reposicionamento de P3 como instrumento de advocacy (seção 4) elimina essa dependência causal e torna a narrativa mais honesta e defensável.

---

## 2. P2 como Âncora de Qualidade

P2 é o projeto mais forte por três razões combinadas: dados reais de acesso público, pipeline SQL reproduzível end-to-end, e decisões analíticas com validação empírica documentada. O que foi estabelecido em P2 define o padrão mínimo para os outros projetos.

### 2.1 O que P2 entregou (estado v3, 2026-05-07)

**Script R de exploração — status (2026-05-07):**
Seção IBAMA concluída e locked: filtros (3 casos, 60.707 registros), validação de datas (DAT_HORA_AUTO_INFRACAO, 0% null), val_multa total confirmado (R$26.814.492.927 via `isTRUE(all.equal())`), análises de lag documentadas como comentários. Próximo: bloco PRODES.

**Dados:**
- PRODES (INPE): 805 geocodes únicos × 18 anos (2008–2025), Amazônia Legal — painel balanceado (800 nomes únicos; 5 homônimos entre estados — `geocode_ibge` é o identificador correto)
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
Cada parâmetro tem uma origem documentada: p75 calculado dinamicamente, streak_min justificado por ciclo eleitoral, join temporal validado com 4 sub-análises. Qualquer constante inline sem justificativa é risco de auditoria.

**Padrão 2: Funil de filtragem documentado.**
Em P2: 309.116 registros brutos → 60.707 filtrados. Cada etapa de remoção documentada com contagem e justificativa. Filtros semânticos com análise das distribuições dos campos relevantes antes de escrever a query.

**Padrão 3: Análise de sensibilidade antes de publicar.**
Em P2: 17.4% dos gap_absoluto mudariam com join t+1. P1 tem problema equivalente com os pesos 60/40. P3 tem o problema do threshold de sinal. Nenhum resultado deve ser apresentado sem robustness check documentado.

**Padrão 4: Limites interpretativos explícitos.**
PRODES ≠ ilegalidade confirmada. IBAMA ≠ enforcement total. EGS ≠ efetividade. Cada projeto deve ter sua seção equivalente: o que o indicador mede e o que ele não mede.

**Padrão 5: Checks de integridade no pipeline.**
`stopifnot` no R. `-- Expected: 0` nos SQL checks. Qualquer pipeline sem verificação de contagem, nulos e range de valores é não-auditável.

**Padrão 6: Decisão-output chain explícita.**
Cada projeto deve responder em menos de 5 segundos: qual a decisão, sob qual restrição, qual a regra, qual a ação imediata. P2 entrega isso: "inspecionar top-N municípios por priority_score, com N configurável no Power BI."

---

## 3. P1 — Targeting System: Avaliação e Questões Abertas

### 3.1 Estado atual

**Decisão:** alocar orçamento de intervenção socioambiental em 40 municípios.
**Regra:** `Rank = 0.6 × deforestation + 0.4 × vulnerability`
**Classificação:** 4 quadrantes (alta/baixa pressão × alta/baixa vulnerabilidade).
**Ação:** financiar top-40; tipo de intervenção por quadrante.

O design é conceitualmente correto — a lógica de quadrantes é acionável e comunicável. O problema está nos pontos onde P2 mostrou que o diabo mora: parâmetros sem justificativa documentada.

### 3.2 Questões abertas críticas

**Q1: Por que 60/40?**
O peso 60/40 não tem justificativa documentada. Três alternativas:
- Análise de sensibilidade bootstrap: testar combinações de pesos (40/60 a 70/30) e reportar a **distribuição** de estabilidade do top-40 — por exemplo, "em 95% das simulações, ≥ 32 dos 40 municípios se mantêm no ranking". Reportar a distribuição, não um threshold de Jaccard arbitrário (ver nota abaixo).
- Decisão de política explícita: "deforestation recebe peso maior por ser critério primário de elegibilidade programática" — requer citação ou protocolo de referência.
- Estimação por regressão: regredir outcomes (desmatamento futuro) no score para encontrar pesos preditivos. Atenção: isso é fitting in-sample, não estimação causal de pesos — enquadrar como "pesos preditivos", não "pesos ótimos".

> **Nota — critério de robustez:** a v1 propunha Jaccard ≥ 0.75 como critério de aprovação. Isso substitui um magic number (60/40) por outro (0.75). O correto é reportar a distribuição completa de Jaccard across simulações e deixar a audiência julgar. Um orientador de doutorado vai perguntar por que 0.75.

**Q2: O que é o threshold de classificação dos quadrantes?**
Alta/baixa pressão e alta/baixa vulnerabilidade precisam de um ponto de corte documentado. Três opções:
- Mediana (p50): corte simétrico, 25% em cada quadrante.
- p75: "alta" pressão = top 25% — maximiza especificidade, reduz recall.
- Threshold por política: cutoff derivado de critério externo (ex: média nacional PRODES). Mais defensável para audiência de policy, mas exige fonte.

A escolha afeta diretamente quantos municípios entram no top-40 por categoria.

**Q3: Qual a fonte de dados de vulnerabilidade?**
Fontes candidatas em ordem de recomendação:
- IBGE Censo 2022: renda per capita, acesso a serviços — mais atualizado, máxima transparência e reprodutibilidade.
- Atlas de Desenvolvimento Humano (PNUD/FJP): IDH municipal por dimensões — já normalizado.
- IVS (IPEA): Índice de Vulnerabilidade Social — mais defensável metodologicamente, menos transparente internamente.

**Q4: P1 é cross-sectional ou longitudinal?**
O design atual parece ser estático. P2 mostrou que persistência é o sinal mais importante. P1 poderia incorporar tendência temporal sem complicar o output: usar média de deforestation dos últimos 3 anos em vez do valor pontual, e distinguir municípios em trajetória de piora versus estabilização.

**Q5: Qual a relação entre P1 e P2?**
P2 identifica municípios com gap de enforcement persistente. P1 identifica municípios com alta pressão e alta vulnerabilidade. A interseção é o argumento mais forte do portfolio: municípios que aparecem simultaneamente no ranking gap_absoluto (P2) e no quadrante crítico (P1) são candidatos para intervenção integrada. Isso só funciona se P1 e P2 usarem o mesmo geocode municipal como chave de join — viável porque ambos usam PRODES como fonte de deforestation.

**Q6: Qual a relação entre P1 e P3?**
Com o novo framing de P3 (seção 4), P1 também recebe input de P3: municípios no quadrante crítico de P1 com baixa atenção midiática (P3) têm prioridade diferente dos que já têm atenção alta. Isso amplia a lógica de quadrantes: pressão × vulnerabilidade × atenção.

### 3.3 O que fazer ao retomar P1

1. Definir fonte de vulnerabilidade e baixar antes de qualquer código.
2. Definir threshold dos quadrantes com justificativa documentada.
3. Construir análise de sensibilidade dos pesos — reportar distribuição de estabilidade do top-40, não threshold de aprovação.
4. Adicionar dimensão temporal na deforestation (média 3 anos).
5. Adicionar join com gap_absoluto do P2 e com quadrante de atenção do P3.
6. Construir checks de integridade desde o início.

**Extensão inferencial (P1):**
Regredir deforestation_{t+1} no score P1_t. Se o score prevê desmatamento futuro, é um índice de alerta, não só de alocação — muda o framing de "onde alocar" para "onde o risco vai piorar".

---

## 4. P3 — Signal Pipeline: Reposicionamento e Questões Abertas

### 4.1 Reposicionamento — de early warning para instrumento de advocacy

**O problema com o framing anterior:** P3 como "detecção antecipada" exigia que atenção midiática precedesse temporalmente o desmatamento. Se a relação causal for inversa (PRODES → mídia), P3 é um espelho atrasado de P2 — o que derruba a narrativa do portfolio. Esse teste empírico não pode ser o alicerce da coerência do sistema.

**O framing correto:** P3 é um instrumento de orientação para advocacy — responde "onde concentrar esforço de comunicação e pressão pública" dado o estado atual da atenção midiática. Não exige precedência temporal; só precisa de estado contemporâneo.

**Lógica do 2×2 (atenção × desmatamento):**

| | Alta atenção midiática | Baixa atenção midiática |
|---|---|---|
| **Alto desmatamento** | Advocacy direto — aproveitar momento, pressão sobre órgãos, amplificação | **Awareness building** — jornalismo investigativo, construção de narrativa, entrada do tema na agenda |
| **Baixo desmatamento** | Monitorar — atenção pode ser por outros motivos; verificar se houve resolução | Deprioritizar |

O quadrante mais valioso para o portfolio é alto desmatamento + baixa atenção: são os casos que P2 identifica como gap_absoluto persistente e que ninguém está cobrindo. Os municípios do interior do Maranhão e do Amazonas que lideram o ranking de P2 provavelmente caem aqui — o argumento cruzado mais forte do portfolio.

**Quadrante problemático:** alta atenção + baixo desmatamento não tem interpretação clara. Pode ser: sucesso (atenção pressionou enforcement, desmatamento caiu), mismatch (atenção por outros motivos), ou dado atrasado (desmatamento ainda virá). O framing precisa declarar a ambiguidade em vez de ignorá-la.

**Usuário primário de P3:** organizações de advocacy e jornalismo (Imazon, ISA, Repórter Brasil, funders internacionais) — diferente do usuário de P2 (agências de enforcement). Essa diferenciação de usuários é ponto forte do portfolio, desde que articulada explicitamente.

### 4.2 Estado atual (conforme summary)

**Decisão:** priorizar regiões para advocacy/monitoramento com base em anomalias de atenção pública.
**Dados:** GDELT Project + NewsAPI + DETER realtime (Twitter API descartado — pago desde 2023).
**Escala:** milhões de registros, justificando BigQuery.
**Indicadores:** mention volume, growth rate, signal score.
**Regra:** growth rate > p90 AND volume > baseline → flag region.

### 4.3 Questões abertas críticas

**Q1: GDELT tem cobertura suficiente para o interior do Brasil?**
GDELT é genuinamente grande e tem dataset público no BigQuery — o que valida a escolha de infraestrutura. Mas tem problemas conhecidos para este caso de uso:
- Cobertura desigual por idioma: português sub-representado em relação ao inglês.
- Atribuição geográfica imperfeita: eventos geocodificados pelo local mais mencionado no artigo, não necessariamente o local do evento.
- Sem acesso direto ao texto: GDELT é metadata (URLs, geocodes, sentiment scores do GCAM), não conteúdo.

**Problema específico para P3:** os municípios mais relevantes do portfolio — os que lideram o gap_absoluto de P2 (Governador Luiz Rocha, Fortuna, Arame, interior do AM e PA) — provavelmente têm zero ou quase zero eventos GDELT. O GDELT indexa O Globo, Folha, BBC Brasil; não indexa O Imparcial do Maranhão. Ausência de sinal GDELT pode significar "ninguém está cobrindo" (correto para advocacy) ou "cobertura local existe mas não é capturada" (erro de classificação para awareness building).

> **Teste prioritário antes de qualquer build:** para os top-20 municípios do ranking gap_absoluto de P2, verificar volume de eventos GDELT geocodificados. Se a maioria retornar zero, a unidade de análise deve ser estado, não município. Isso é uma decisão arquitetural — bloqueia tudo o que vem depois.

**Q2: O signal score mede atenção sobre desmatamento ou atenção em geral?**
GDELT indexa eventos por categoria CAMEO e temas GCAM, mas a precisão de classificação em português para localidades do interior é questionável. Alto volume de eventos GDELT em um município pode refletir violência, eleição ou escândalo político — não desmatamento. Se P3 não consegue filtrar por tema de forma confiável, o sinal "alta atenção" é ruidoso e o quadrante do 2×2 pode estar errado.

**Q3: Como definir o signal score empiricamente?**
O summary define o sinal como "growth rate > p90 AND mention volume > baseline". Problemas não resolvidos:
- Qual o baseline? Média rolling de 30 dias? Média histórica por região? Z-score?
- O p90 é calculado sobre qual distribuição? Globalmente: regiões com alto volume histórico (AM, PA) nunca atingem crescimento relativo significativo. Por região: regiões com histórico curto têm threshold artificialmente baixo.

Solução recomendada: Z-score rolling intra-região — `(volume_t - mean_rolling_90d) / std_rolling_90d > 2`. Regiões com histórico curto têm Z-score menos confiável — documentar como limitação. Essa é a solução análoga ao problema do p75 hardcoded vs dinâmico de P2.

**Q4: Temporal — qual a frequência certa para advocacy?**
Advocacy responde a janelas de atenção de 2–3 dias (news cycle) a semanas (campanhas). Se P3 agrega por semana ou mês para reduzir ruído, pode ser lento demais para o uso de "aproveitar momento" (direct advocacy). Região-dia é ruidoso; região-semana é mais estável mas potencialmente atrasado. Decidir com base no caso de uso predominante do usuário-alvo.

**Q5: Unidade de análise**
Verificar granularidade geográfica do GDELT para o Brasil antes de definir. Município-dia provavelmente inviável para interior. Estado-dia como unidade intermediária tem precedência na literatura de mídia e política ambiental — mais defensável e mais robusto à limitação de cobertura.

### 4.4 Teste de precedência temporal — de decisão central para achado secundário

Na v1, o teste PRODES ↔ sinal era central para o portfolio. No novo framing, ele se torna um achado adicional, não uma condição necessária:

- Se sinal precede PRODES: P3 tem propriedade adicional de early warning — mencionar como extensão.
- Se PRODES precede sinal: mídia é reativa — isso confirma que P3 mede estado de atenção, não predição, o que é consistente com o framing de advocacy.
- Se não há relação: sinal é desconectado do desmatamento físico — limitação crítica que exige reposicionamento.

O resultado do teste define se a seção de interpretive limits é uma nota de rodapé ou uma reestruturação do projeto.

### 4.5 O que fazer ao retomar P3

1. **Antes de qualquer outra decisão:** query exploratória no GDELT BQ public dataset para os top-20 gap_absoluto de P2. Se granularidade municipal for insuficiente, adotar estado como unidade de análise.
2. Avaliar se GDELT consegue filtrar eventos por tema "desmatamento" em português com precisão aceitável. Se não, considerar NewsAPI com filtro de keywords como fonte principal.
3. Definir Z-score rolling como threshold de sinal — documentar janela temporal e parâmetros.
4. Construir o 2×2 (atenção × desmatamento) como output central, não a lista de flags.
5. Fazer o teste de precedência temporal como achado secundário, não como validação da premissa.
6. Documentar limitações de GDELT (cobertura, atribuição geográfica, tema) desde o início.

---

## 5. P4 — Extension Layer: Decisão e Design Técnico

### 5.1 Análise das opções

**Opção A: NLP sobre textos policy/administrativos**
Ponto forte: demonstra Python + NLP, diferencia do resto do portfolio. Problemas: corpus de textos policy em português com acesso garantido não está definido; conexão com P2 é metodologicamente distante; risco de virar projeto genérico de NLP sem ancoragem nos dados reais. Argumento de coerência do portfolio mais fraco.

**Opção B: ML preditivo sobre P2**
Treinar classificador para prever gap_absoluto_{t+1}. Ponto forte: usa dados do P2, demonstra Python + sklearn. Problemas: P2 não tem features de território além de area_km2 — precisaria de dados adicionais (IBGE censo, infraestrutura, bioma). Sem features ricas, o modelo é trivial (EGS_{t-1} como único preditor). Viável com dados adicionais; scope adicional significativo.

**Opção C: Econometria — TWFE + event study [RECOMENDADA]**
Pontos fortes: usa os dados de P2; choque de 2019 é documentado e geograficamente variável; é a extensão inferencial natural do sistema de monitoramento; demonstra capacidade inferencial para doutorado quantitativo.

> **Reframing necessário (v2):** a v1 apresentou "usa exatamente os dados de P2 sem dados adicionais" como vantagem. É uma limitação. A ausência de controles para preços de commodities, expansão de infraestrutura, ciclos eleitorais locais e land tenure significa que os determinantes time-varying mais importantes do desmatamento não estão no modelo. O coeficiente β da EGS_{t-1} absorve parte desses fatores. Isso não invalida o design — mas precisa ser declarado como limitação de escopo, não como eficiência de recursos.

### 5.2 Design técnico de P4 (Opção C)

**Questão de pesquisa:** o enforcement IBAMA (medido pelo EGS ou n_autos) está associado a menor desmatamento PRODES no município no período seguinte?

**Dados:** egs_final do P2 — panel, 14.490 observações, 800 municípios × 18 anos.

**Modelo 1 — TWFE básico:**
```
deforestation_{i,t} = α_i + γ_t + β × EGS_{i,t-1} + ε_{i,t}
```
- `α_i`: fixed effects municipais (controla confundidores time-invariant)
- `γ_t`: fixed effects anuais (controla shocks nacionais)
- `β`: associação entre enforcement passado e desmatamento atual
- Interpretação: não causal (time-varying confounders persistem — ver limites abaixo)

**Modelo 2 — Event study (choque 2019):**
```
deforestation_{i,t} = Σ_k β_k × D_{t=2019+k} + α_i + γ_t + ε_{i,t}
```
- Coeficientes para cada ano em torno de 2019 (-5 a +5 anos)
- Teste de parallel trends pré-2019 como falsificação natural

> **Problema não resolvido na v1 — definição de tratamento:** o event study requer uma definição explícita de quem é "tratado" pelo choque de 2019. A v1 propôs "municípios com diferentes níveis de dependência do enforcement federal" como grupo de controle natural, mas não definiu como medir essa dependência. Se a medida for EGS médio pré-2019 (a candidata mais óbvia), o tratamento é definido pela variável dependente defasada — problema clássico de seleção. **Essa definição precisa estar resolvida antes de qualquer código Python.**

**Modelo 3 — Granger causality (exploratory):**
```
deforestation_{i,t} ~ deforestation_{i,t-1..k} + EGS_{i,t-1..k} + α_i
EGS_{i,t} ~ EGS_{i,t-1..k} + deforestation_{i,t-1..k} + α_i
```
- Teste bidirecional: enforcement prediz desmatamento? Desmatamento prediz enforcement?
- Atenção: panel Granger com FE requer estimador específico (Holtz-Eakin ou equivalente) — não é simplesmente rodar `grangertest` em painel. Enquadrar como "precedência temporal", não "causalidade de Granger".

**Limites inferenciais a documentar:**
- TWFE não elimina confundidores time-varying (preços de commodities, ciclos eleitorais locais, expansão de infraestrutura, land tenure) — esses são os determinantes mais importantes do desmatamento e estão ausentes do modelo.
- Enforcement federal é endógeno ao desmatamento: IBAMA prioriza municípios com maior pressão. Sem instrumento exógeno credível, β não é interpretado como causal.
- Ressalva correta: "controlando para heterogeneidade municipal não observada e shocks temporais comuns, maior enforcement passado está associado a menor desmatamento subsequente — associação robusta, não efeito causal."

**Implementação Python:**
```python
# utils.py       — carregamento e validação do egs_final
# data_prep.py   — construção do panel, lags, dummies de evento
# features.py    — EGS, gap_absoluto dummy, streak features
# model.py       — TWFE via linearmodels, event study manual
# evaluation.py  — coeficientes, CIs, testes de robustez
# main.py        — orquestração do pipeline
```

Pacotes principais: `linearmodels` (TWFE with within estimator), `pandas`, `statsmodels` (Granger), `matplotlib`/`seaborn` (event study plots).

**Output-chave:** event study plot com coeficientes anuais e intervalo de confiança. É o "one chart that explains everything" do P4.

---

## 6. Questões Transversais

### 6.1 Identificação causal — caveat cross-cutting

Nenhum dos quatro projetos alcança identificação causal limpa. TWFE controla confundidores time-invariant mas não elimina time-varying. Esse limite deve ser declarado com precisão em cada projeto:

*"Este design não permite inferência causal. Controla por heterogeneidade municipal não observada (FE municipais) e por shocks temporais comuns (FE anuais), mas não elimina confundidores time-varying como preços de commodities agrícolas, ciclos eleitorais locais, ou expansão de infraestrutura. Os coeficientes devem ser interpretados como associações parcialmente controladas, não como efeitos causais."*

Declarar esse limite com precisão é o sinal inferencial que diferencia o portfolio de exercícios técnicos ingênuos.

### 6.2 Escopo — viés estrutural da Amazônia Legal

P2 é explicitamente restrito à Amazônia Legal. P1 usa PRODES — mesmo bioma. P3 usa GDELT — sem restrição geográfica. P4 usa os dados de P2 — mesmo escopo.

O portfolio tem viés de cobertura: Cerrado, Caatinga, Mata Atlântica ficam de fora. Esse viés reproduz o viés estrutural dos sistemas de monitoramento brasileiros e deve ser declarado como limitação no README e no site. Extensão para outros biomas é tecnicamente viável mas requer spatial join (coordenadas IBAMA × polígonos de bioma) e harmonização de séries PRODES por bioma — fora do escopo do MVP.

### 6.3 Stack técnico e usuários por projeto

| Projeto | Stack principal | Usuário primário | Diferenciação técnica |
|---|---|---|---|
| P1 | R + tidyverse + ggplot | Tomadores de decisão programática (ONGs, doadores) | Análise exploratória + visualização de decisão |
| P2 | DuckDB + SQL + R + Power BI | Agências de enforcement (IBAMA, estaduais) | Pipeline local, dados reais, 9 fixes documentados |
| P3 | BigQuery + SQL + Power BI | Organizações de advocacy e jornalismo | Cloud, escala, dados de alta frequência |
| P4 | Python + linearmodels | Pesquisadores, policy analysts | Inferência econométrica, extensão de P2 |

A diversidade de stacks é intencional: demonstra capacidade de escolher a ferramenta certa para o problema, não dependência de uma única ferramenta. A diversidade de usuários demonstra que o sistema serve diferentes atores num ciclo integrado de política ambiental.

### 6.4 GitHub e reprodutibilidade

P2 tem o pipeline mais rigoroso do portfolio. A disciplina de reproducibility estabelecida deve ser replicada nos outros projetos. Critério mínimo por projeto:

- `README.md` com: fontes de dados, sequência de execução, outputs esperados, limitações conhecidas.
- Sem dados brutos no repositório se houver restrições de licença.
- Checks de integridade executáveis (não só comentados).
- Sem magic numbers sem comentário de justificativa.

### 6.5 Website — o que mostrar

A regra permanece: cada projeto responde em < 5 segundos. O top block do site deve mostrar o sistema, não os projetos isolados:

```
SISTEMA: Onde o desmatamento acontece sem resposta institucional?

  P2 → Monitora o gap de enforcement       (PRODES + IBAMA + DuckDB)
  P3 → Mapeia onde o gap tem atenção       (GDELT + BigQuery)
  P1 → Aloca intervenção                   (PRODES + vulnerabilidade + R)
  P4 → Estima se enforcement funciona      (panel econometrics + Python)

O argumento integrado: municípios com gap_absoluto persistente (P2)
e baixa atenção midiática (P3) são candidatos para intervenção
simultânea de enforcement e advocacy.
```

Esse framing transforma quatro projetos em um argumento.

---

## 7. Prioridades ao Retomar Outros Projetos

### Ao iniciar P1
1. Confirmar fonte de vulnerabilidade (IBGE Censo 2022 recomendado).
2. Definir e documentar threshold de classificação antes de qualquer código.
3. Construir análise de sensibilidade dos pesos — reportar distribuição, não threshold de aprovação.
4. Usar mesmo geocode IBGE do P2 como chave de join.
5. Adicionar join com gap_absoluto do P2 e com quadrante de atenção do P3.
6. Construir checks de integridade desde o início.

### Ao iniciar P3
1. **Primeiro:** query GDELT BQ para top-20 gap_absoluto de P2 — verificar granularidade municipal. Se insuficiente, adotar estado como unidade.
2. Avaliar filtragem por tema "desmatamento" em português no GDELT.
3. Definir Z-score rolling como threshold de sinal com janela e parâmetros documentados.
4. Construir o 2×2 (atenção × desmatamento) como output central.
5. Documentar limitações de GDELT desde o início.

### Ao iniciar P4
1. **Primeiro:** definir operacionalização do "tratamento" no event study de 2019 antes de qualquer código.
2. Exportar egs_final como parquet ou CSV para Python.
3. Construir panel e verificar municípios com dados faltantes por ano.
4. Implementar TWFE primeiro (mais simples) antes do event study.
5. Documentar explicitamente os time-varying confounders ausentes do modelo.
6. Event study plot é o output central — priorizar sobre tabelas.

---

*Atualizado 2026-05-07 (v3). Gerado originalmente 2026-05-04 (v2). Baseado em: Portfolio Projects Summary v2, Portfolio Strategy Summary, estado atual do P2 (pipeline v3, 60.707 registros, 14.490 observações, p75 = 0.5891, script R seção IBAMA locked), avaliação crítica e discussão de reposicionamento de P3.*
