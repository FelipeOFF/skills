# Interpretando o output (JSON) do DCL

Este guia ensina a ler o output do DCL para saber **o que** corrigir e **onde**. É a base do Step 3 do `SKILL.md` (parse) e alimenta os Steps 4–5 (fix + verify).

## 1. Sempre use `--reporter=json` (ou `--json-path`)

O reporter `console` é humano, colorido e agrupado por arquivo, mas **não é estruturado** — não dá para extrair com segurança `path`, linha, coluna e `ruleId` dele. Para parsing por LLM ou script, use sempre JSON:

```bash
# JSON para stdout
dart run dart_code_linter:metrics analyze lib --reporter=json > /tmp/dcl.json
# JSON para arquivo (ainda imprime um resumo no console)
dart run dart_code_linter:metrics analyze lib --json-path=/tmp/dcl.json
```

Observações dos facts:

- `--reporter=json` é o melhor formato para parsing por LLM/script.
- `--json-path=file` escreve o JSON no arquivo **e** imprime um resumo no console.
- Os comandos `analyze`/`fix` suportam todos os 8 reporters; os comandos `check-unused-*` e `check-unnecessary-nullable` suportam **apenas** `console` e `json`.

## 2. O schema JSON completo

### Root

```json
{ "formatVersion": <int>, "timestamp": "YYYY-MM-DD HH:MM:SS", "records": [<LintFileReport>...], "summary": [{"status":...,"title":...,"value":...,"violations":...}] }
```

### `records[]` (LintFileReport) — um por arquivo `.dart`

```json
{ "path": "<relative>", "fileMetrics": [<MetricValue>...],
  "classes": {"<ClassName>": {"codeSpan": <span>, "metrics": [<MetricValue>...]}},
  "functions": {"<funcName>": {"codeSpan": <span>, "metrics": [<MetricValue>...]}},
  "issues": [<Issue>...], "antiPatternCases": [<Issue>...] }
```

### `Issue` (presente em `issues` e em `antiPatternCases`)

```json
{ "ruleId": "<rule-id>", "documentation": "<url>",
  "codeSpan": {"start": {"offset":n,"line":n,"column":n}, "end": {...}, "text": "<source text>"},
  "severity": "error|warning|performance|style|none",
  "message": "<human>", "verboseMessage": "<recommendation>",
  "suggestions": [{"comment": "...", "replacement": "..."}] }
```

### `MetricValue` (presente em `metrics` e em `fileMetrics`)

```json
{ "metricsId": "cyclomatic-complexity", "value": <num>, "unitType": "<str>",
  "level": "none|noted|warning|alarm",
  "comment": "This method has a cyclomatic complexity of N, which exceeds the maximum of T allowed.",
  "recommendation": "<str>", "context": [{"message":"...","codeSpan": <span>}] }
```

## 3. Mapa "onde achar o quê"

| O que você quer | Onde está no JSON |
|---|---|
| Arquivo | `records[].path` |
| Violações de **regra** | `records[].issues[]` (`ruleId` + `message` + `codeSpan.start.line/column` + `codeSpan.text`) |
| **Anti-patterns** (`long-method`, `long-parameter-list`) | `records[].antiPatternCases[]` (mesma forma `Issue`) |
| Violações de **métrica** | entradas em `records[].functions` / `records[].classes` / `records[].fileMetrics` cujo `metrics[].level != "none"` |
| Valor medido vs. threshold | campo `comment` do `MetricValue` (ex.: "...complexity of N, which exceeds the maximum of T allowed.") |
| Issues auto-fixáveis | `Issue.suggestions[].replacement` (quando presente) |

Mapeamento direto para o Step 4 do `SKILL.md`: rule hits → `issues[]`; anti-pattern hits → `antiPatternCases[]`; metric hits → `metrics[]` com `level != "none"`.

Lembre das duas escalas distintas (dos facts):

- **`Issue.severity`** (regras e `--fatal-*`): `error` > `warning` > `performance` > `style` > `none`.
- **`MetricValue.level`** (métricas e `--set-exit-on-violation-level`): `none` (verde, abaixo do threshold) < `noted` (azul, 80–100% do threshold) < `warning` (amarelo, 100–200%) < `alarm` (vermelho, >200%).

## 4. CAVEAT crítico: `line`/`column` são 0-BASED

`offset`/`line`/`column` vêm do `SourceLocation` do `source_span` → **`line` e `column` são 0-BASED**. Isso é o clássico off-by-one contra editores 1-based.

> Ao reportar uma localização ao usuário ou abrir o arquivo no editor, **some +1** em `line` e `column`. Ex.: `codeSpan.start.line = 41` no JSON corresponde à **linha 42** mostrada no editor.

## 5. `suggestions[].replacement` é o payload de auto-fix

Quando um `Issue` traz `suggestions[]`, cada item tem um `comment` (explicação) e um `replacement` (o texto que substitui o trecho). O `replacement` é o payload de auto-fix.

> **Nunca aplique um `replacement` às cegas.** Confirme que ele casa com o `codeSpan` correspondente (mesmo `start`/`end`/`text`) **antes** de aplicar, e re-analise depois (Step 5 do `SKILL.md`). Métricas e anti-patterns **não** carregam `suggestions` — não são auto-fixáveis; exigem refactor manual/LLM.

## 6. Helper `scripts/parse-dcl-json.py`

O helper achata o JSON aninhado por arquivo em uma lista plana e priorizada de violações.

- **Entrada:** um path para o arquivo JSON **ou** o JSON via stdin.
- **Saída:** uma linha por violação no formato `path:line:col [sev] ruleId — message`, mais contadores de resumo.

```bash
# a partir de um arquivo
python3 scripts/parse-dcl-json.py /tmp/dcl.json
# a partir de stdin (pipe)
dart run dart_code_linter:metrics analyze lib --reporter=json | python3 scripts/parse-dcl-json.py
```

Exemplo de uma linha de saída:

```text
lib/user/user_service.dart:42:9 [warning] avoid-non-null-assertion — Avoid using the bang operator.
```

> A coluna `line:col` impressa pelo helper já é a localização do JSON. Se for 0-based na origem, lembre da regra do +1 da seção 4 ao abrir no editor.

## 7. Exemplo trabalhado

JSON mínimo com **1 violação de regra** (em `issues`) + **1 violação de métrica** (em `functions`):

```json
{
  "formatVersion": 2,
  "timestamp": "2026-06-15 10:30:00",
  "records": [
    {
      "path": "lib/user/user_service.dart",
      "fileMetrics": [],
      "classes": {},
      "functions": {
        "loadUser": {
          "codeSpan": {"start": {"offset": 120, "line": 18, "column": 2}, "end": {"offset": 980, "line": 64, "column": 3}, "text": "Future<User> loadUser(...) { ... }"},
          "metrics": [
            {
              "metricsId": "cyclomatic-complexity",
              "value": 27,
              "unitType": "",
              "level": "alarm",
              "comment": "This method has a cyclomatic complexity of 27, which exceeds the maximum of 20 allowed.",
              "recommendation": "",
              "context": []
            }
          ]
        }
      },
      "issues": [
        {
          "ruleId": "avoid-non-null-assertion",
          "documentation": "https://dcl.apps.bancolombia.com/...",
          "codeSpan": {"start": {"offset": 410, "line": 41, "column": 8}, "end": {"offset": 418, "line": 41, "column": 16}, "text": "user!.id"},
          "severity": "warning",
          "message": "Avoid using the bang operator.",
          "verboseMessage": "Prefer null-aware access or an explicit null check.",
          "suggestions": []
        }
      ],
      "antiPatternCases": []
    }
  ],
  "summary": []
}
```

Leitura que a LLM deve extrair:

- **Violação de regra:** em `lib/user/user_service.dart`, `ruleId = avoid-non-null-assertion`, `severity = warning`, no trecho `user!.id`. JSON diz `line 41, column 8` → reportar/abrir como **linha 42, coluna 9** (regra do +1). Sem `suggestions` → correção **manual** (null-aware ou checagem explícita; ver `references/fix-playbook.md`).
- **Violação de métrica:** a função `loadUser` tem `cyclomatic-complexity` com `value 27`, `level = alarm` (`!= "none"` → é violação; `>200%` do threshold, pois 27 > 2×... na verdade acima do máximo de 20). O `comment` dá valor vs. threshold (27 vs. máximo 20). Métricas **não** são auto-fixáveis → refactor estrutural (extrair métodos, reduzir branches), conforme Step 4.3 do `SKILL.md`.
- O bloco `antiPatternCases` está vazio → nenhum `long-method`/`long-parameter-list` neste arquivo.
