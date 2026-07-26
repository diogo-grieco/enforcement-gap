# IBAMA — autos de infração (versão pública, sem PII)

Derivado do dado bruto do IBAMA (`data/data_ibama/`, não versionado, contém
nome e CPF/CNPJ do autuado). Esta pasta mantém, de cada CSV anual, apenas as
13 das 84 colunas originais efetivamente lidas em algum ponto do pipeline SQL
ou da suíte `viz/`:

```
COD_MUNICIPIO, UF, DAT_HORA_AUTO_INFRACAO, DT_FATO_INFRACIONAL,
CD_TERMOS_EMBARGOS, CD_TERMOS_APREENSAO, SIT_CANCELADO,
DES_STATUS_FORMULARIO, TIPO_INFRACAO, INFRACAO_AREA,
COD_INFRACAO, CPF_CNPJ_INFRATOR, VAL_AUTO_INFRACAO
```

`NOME_INFRATOR` é descartado (não é lido por nenhum script do projeto).
`CPF_CNPJ_INFRATOR` é substituído por um **identificador substituto aleatório
e estável**: `pid_` + 16 dígitos hexadecimais sorteados, um por autuado. O mapa
`CPF/CNPJ → pid_` é construído uma única vez (global, cobrindo todos os anos),
preserva igualdade (mesmo autuado, mesmo `pid_`, em qualquer ano) — então toda
contagem que depende de identidade de autuado (curva de Lorenz da concentração
de multas, rede de infratores multi-município) é idêntica ao dado original.

Diferente de um hash do próprio CPF/CNPJ, o substituto **não é derivado do
valor original**: é aleatório. Por isso a identidade real não é recuperável a
partir do dado publicado por construção, e não por ofuscação — não há salt nem
função conhecida que, aplicada a um CPF candidato, reproduza o `pid_`. O mapa
que permitiria a reversão é mantido **apenas localmente e nunca versionado**.

Contagem de linhas idêntica ao bruto: 309.116 (verificado coluna a coluna
contra `data/data_ibama/` no momento da derivação).

Script de derivação (não incluído no pipeline executável, roda uma vez sobre
o dado bruto local; descarta o mapa ao final):

```python
import secrets
import pandas as pd
from pathlib import Path

SRC = Path("data/data_ibama")
DST = Path("data/data_ibama_public")
KEEP_COLS = ["COD_MUNICIPIO", "UF", "DAT_HORA_AUTO_INFRACAO", "DT_FATO_INFRACIONAL",
             "CD_TERMOS_EMBARGOS", "CD_TERMOS_APREENSAO", "SIT_CANCELADO",
             "DES_STATUS_FORMULARIO", "TIPO_INFRACAO", "INFRACAO_AREA",
             "COD_INFRACAO", "CPF_CNPJ_INFRATOR", "VAL_AUTO_INFRACAO"]

files = sorted(SRC.glob("auto_infracao_ano_*.csv"))

# 1) mapa global CPF/CNPJ -> substituto aleatório (um por autuado, todos os anos)
distinct = set()
for f in files:
    s = pd.read_csv(f, sep=";", dtype=str, encoding="utf-8", usecols=["CPF_CNPJ_INFRATOR"])
    distinct.update(s["CPF_CNPJ_INFRATOR"].dropna().unique())

mapping, used = {}, set()
for value in distinct:
    while True:
        pid = "pid_" + secrets.token_hex(8)   # 16 hex aleatórios
        if pid not in used:
            break
    used.add(pid)
    mapping[value] = pid

# 2) reescreve cada CSV com as 13 colunas e o substituto
for f in files:
    df = pd.read_csv(f, sep=";", dtype=str, encoding="utf-8")
    df = df[[c for c in KEEP_COLS if c in df.columns]]
    df["CPF_CNPJ_INFRATOR"] = df["CPF_CNPJ_INFRATOR"].map(
        lambda v: mapping.get(v) if pd.notna(v) else v)
    df.to_csv(DST / f.name, sep=";", index=False, encoding="utf-8")

# 3) o mapa NÃO é salvo — a reversão fica impossível a partir do repositório
del mapping
```

Para reprocessar com dados IBAMA mais recentes: baixe os novos CSVs para
`data/data_ibama/`, rode o script acima, e siga o pipeline normalmente a
partir de `data/data_ibama_public/`. (Rodar de novo gera `pid_` diferentes —
o mapa é aleatório e efêmero; isso não afeta nenhuma contagem, que depende
só de igualdade preservada.)
