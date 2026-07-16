# Gate de CI e exit codes

Como o DCL sinaliza falhas ao CI e como configurar o gate. O `analyze` (e `fix`) saem com código não-zero conforme a severidade dos issues e o nível das violações de métrica. O CI deve falhar nesses códigos.

## Tabela de exit codes

Valores conforme `cli_runner.dart` / `analyze_command.dart`:

| code | quando (analyze) |
|---|---|
| 0 | success |
| 1 | unexpected Exception ("Oops; metrics has exited unexpectedly"); OR a `--fatal-warnings`/performance/style issue present (and count exceeds threshold if set) |
| 2 | metric/rule violation at MetricValueLevel ≥ `--set-exit-on-violation-level` |
| 3 | any issue with `Severity.error` present (checked FIRST) |
| 64 | usage error (UsageException — bad args/unknown command) |

Caso `unused-*`: os comandos `check-unused-files`, `check-unused-code`, `check-unused-l10n` e `check-unnecessary-nullable` saem com **exit 1** quando algo unused/found é detectado e `--fatal-unused` está ligado (default on).

Observação importante: o código `3` (Severity.error) é checado PRIMEIRO. Se houver um issue de severidade `error`, o exit é `3` mesmo que também existam violações de métrica que justificariam `2`.

## Dois enums distintos

O DCL trabalha com duas escalas de gravidade independentes. Não as confunda — uma vale para regras/issues, a outra para métricas.

### 1. Severity (regras & issues) → flags `--fatal-*`

Aplica-se a violações de **rules** e anti-patterns. Valores:

```
error  >  warning  >  performance  >  style  >  none
```

Controlado pelas flags `--[no-]fatal-*` (todas em `analyze` e `fix`):

| Flag | Default | Efeito |
|---|---|---|
| `--[no-]fatal-warnings` | **ON (true)** | Treat warning level issues as fatal. |
| `--[no-]fatal-performance` | off | Treat performance level issues as fatal. |
| `--[no-]fatal-style` | off | Treat style level issues as fatal. |
| `--fatal-warnings-threshold` | null (valueHelp `all`) | conta máxima tolerada antes de tornar fatal |
| `--fatal-performance-threshold` | null | analyze only |
| `--fatal-style-threshold` | null | analyze only |

Issues de `Severity.error` sempre disparam exit `3` (independem de flag). As demais severidades só tornam o exit não-zero (`1`) quando a `--fatal-*` correspondente está ligada.

### 2. MetricValueLevel (métricas) → flag `--set-exit-on-violation-level`

Aplica-se a violações de **metrics** (cyclomatic-complexity, nesting, etc.). Valores, do verde ao vermelho:

| level | cor | faixa vs threshold |
|---|---|---|
| `none` | green | abaixo do threshold |
| `noted` | blue | 80–100% do threshold |
| `warning` | yellow | 100–200% do threshold |
| `alarm` | red | > 200% do threshold |

A flag `--set-exit-on-violation-level` aceita **apenas** `noted`, `warning`, `alarm` (não aceita `none`):

> "Set exit code 2 if code violations same or higher level than selected are detected."

Ou seja, `--set-exit-on-violation-level=warning` faz o DCL sair com `2` quando qualquer métrica atingir `warning` (yellow) ou `alarm` (red).

## Como fazer o CI falhar

Duas alavancas, normalmente combinadas:

1. **Gate por métrica:** `--set-exit-on-violation-level=warning` → exit `2` em violações de métrica ≥ yellow.
2. **Gate por regra:** o default `--fatal-warnings` já está ON → exit `1` quando há rule warnings. Não precisa passar nada para isso valer.

Comando recomendado para um gate estrito (regras + métricas):

```bash
dart run dart_code_linter:metrics analyze lib --reporter=github --set-exit-on-violation-level=warning
```

## Como afrouxar o gate

Para gatear **só por métrica** (ignorando rule warnings), desligue o fatal padrão:

```bash
dart run dart_code_linter:metrics analyze lib --no-fatal-warnings --set-exit-on-violation-level=alarm
```

`--no-fatal-warnings` evita que rule warnings derrubem o build; o `--set-exit-on-violation-level` continua governando o exit por métrica. Cuidado: com `--fatal-warnings` ON (default), o `analyze` pode sair não-zero mesmo sem `--set-exit-on-violation-level`.

## Reporters em CI

Os reporters `github` e `gitlab` geram **annotations inline** (na PR / merge request). Use `html`/`json` quando quiser **artefatos** (relatório navegável ou parsing por script). Detalhe por reporter em `references/cli-reference.md`.

| reporter | uso em CI |
|---|---|
| `github` | GitHub Actions annotations (inline na PR). Melhor para GitHub. |
| `gitlab` | GitLab Code Quality (variante Code Climate). Melhor para GitLab. |
| `codeclimate` | Code Climate JSON — quality gates genéricos. |
| `checkstyle` | Checkstyle XML — ingestão por CI. |
| `html` | site HTML estático em `--output-directory` (default `metrics`) → artefato. |
| `json` | machine-readable → artefato para parsing/LLM. |

## GitHub Actions

```yaml
name: dcl
on: [pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1
        # Flutter: use subosito/flutter-action@v2 e troque dart por flutter abaixo
      - run: dart pub get
      - run: dart run dart_code_linter:metrics analyze lib --reporter=github --set-exit-on-violation-level=warning
```

O reporter `github` emite as annotations inline nos arquivos da PR. O step falha (exit `2` por métrica e/ou `1` pelo `--fatal-warnings` default), reprovando o job.

## GitLab CI

O reporter `gitlab` produz um Code Quality report (variante Code Climate JSON) que o GitLab consome como artefato e exibe no widget da merge request:

```yaml
dcl:
  image: dart:stable
  # Flutter: use uma imagem flutter e troque dart por flutter
  script:
    - dart pub get
    - dart run dart_code_linter:metrics analyze lib --reporter=gitlab --set-exit-on-violation-level=warning > gl-code-quality-report.json
  artifacts:
    reports:
      codequality: gl-code-quality-report.json
```

Redirecione a saída `gitlab` para o arquivo declarado em `artifacts.reports.codequality`. O job também falha pelo exit code quando há violações no nível configurado.

## Pitfalls de CI

- `--fatal-warnings` está **ON por default** → `analyze` pode sair não-zero sem `--set-exit-on-violation-level`. Para gate só por métrica use `--no-fatal-warnings`.
- `analyze` exige um target (`analyze lib`); bare `analyze` é usage error (exit `64`).
- Rode `dart pub get` (Flutter: `flutter pub get`) antes do `dart run`, senão o comando não resolve o DCL.
- Severity (`error`/`warning`/`performance`/`style`/`none`, via `--fatal-*`) e MetricValueLevel (`none`/`noted`/`warning`/`alarm`, via `--set-exit-on-violation-level`) são enums distintos — `warning` significa coisas diferentes em cada um.
- `--set-exit-on-violation-level` não aceita `none`; só `noted`, `warning`, `alarm`.
