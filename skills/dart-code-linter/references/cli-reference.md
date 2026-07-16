# Referência de CLI

Catálogo completo dos comandos e flags do `dart_code_linter` (DCL). Os valores de comandos, flags, defaults, reporters, níveis e ids são copiados verbatim dos fatos do tool — não os parafraseie.

## Entrypoint

O ponto de entrada é **sempre**:

```bash
dart run dart_code_linter:metrics <command> <target>
```

Pontos importantes:

- **Não existe** um binário standalone `dcl`. Toda invocação passa por `dart run dart_code_linter:metrics`.
- Em projetos Flutter, troque `dart run` por `flutter pub run` apenas se necessário; o entrypoint do package continua sendo `dart_code_linter:metrics`.
- O runner se chama `metrics` (descrição: "Analyze and improve your code quality.").
- Se o primeiro argumento **não** for um comando conhecido, o DCL injeta `analyze` como default. Ou seja, `... metrics lib` é tratado como `... metrics analyze lib`.
- Globais: `--version` e `help <command>`.
- **`check-dependencies` NÃO existe no DCL** (é um comando exclusivo do DCM comercial). Não o anuncie nem o utilize.

## Comandos (exatamente 6)

Todos seguem a forma `dart run dart_code_linter:metrics <cmd> <target>`. O `<target>` é um diretório ou arquivo (ex.: `lib`); é obrigatório para `analyze` (um `analyze` sem alvo gera erro).

### analyze
Reports code metrics, rules and anti-patterns violations.

```bash
dart run dart_code_linter:metrics analyze lib
```

### fix
Automatically fix code issues based on lint rules and metrics. (Real no 4.1.2, porém pouco documentado — verifique em branch descartável.)

```bash
dart run dart_code_linter:metrics fix lib
```

### check-unused-files
Check unused *.dart files.

```bash
dart run dart_code_linter:metrics check-unused-files lib
```

### check-unused-code
Checks unused code in *.dart files.

```bash
dart run dart_code_linter:metrics check-unused-code lib
```

### check-unused-l10n
Check unused localization in *.dart files.

```bash
dart run dart_code_linter:metrics check-unused-l10n lib
```

### check-unnecessary-nullable
Checks unnecessary nullable params in functions/methods/constructors.

```bash
dart run dart_code_linter:metrics check-unnecessary-nullable lib
```

## (a) Common flags — aplicam a TODOS os comandos

| Flag | Abbr | Default | Notes |
|---|---|---|---|
| `--root-folder` | | current dir | valueHelp `./` ; must exist |
| `--sdk-path` | | auto | only when compiled exe + autodetect fails |
| `--exclude` | | `{/**.g.dart,/**.freezed.dart}` | Glob; "File paths in Glob syntax to be exclude." |
| `--print-config` | `-c` | off | "Print resolved config." non-negatable |
| `--no-congratulate` | | false | "Don't show output even when there are no issues." |
| `--[no-]verbose` | | false | "Show verbose logs." |
| `--version` | | | "Reports the version of this tool." |

## (b) analyze / fix — reporter e output

| Flag | Abbr | Values / default |
|---|---|---|
| `--reporter` | `-r` | `console`, `console-verbose`, `checkstyle`, `codeclimate`, `github`, `gitlab`, `html`, `json`; default `console` |
| `--output-directory` | `-o` | default `metrics` (diretório do HTML) |
| `--json-path` | | default null; "Path to the JSON file with the output of the analysis." valueHelp `path/to/file.json` |

## (c) analyze — overrides de threshold de métricas (CLI)

Estes 10 flags sobrescrevem os thresholds definidos no config. Valor não-inteiro é rejeitado com warning.

| Flag |
|---|
| `--cyclomatic-complexity` |
| `--halstead-volume` |
| `--lines-of-code` |
| `--maximum-nesting-level` |
| `--number-of-methods` |
| `--number-of-parameters` |
| `--source-lines-of-code` |
| `--weight-of-class` |
| `--maintainability-index` |
| `--technical-debt` |

## (d) analyze / fix — exit e severity

| Flag | Values / default |
|---|---|
| `--set-exit-on-violation-level` | `noted`, `warning`, `alarm` (valueHelp `warning`). "Set exit code 2 if code violations same or higher level than selected are detected." |
| `--[no-]fatal-style` | off; "Treat style level issues as fatal." |
| `--[no-]fatal-performance` | off; "Treat performance level issues as fatal." |
| `--[no-]fatal-warnings` | **DEFAULT ON (true)**; "Treat warning level issues as fatal." |
| `--fatal-warnings-threshold` | default null (valueHelp `all`) |
| `--fatal-performance-threshold` | default null (analyze only) |
| `--fatal-style-threshold` | default null (analyze only) |

**`--fatal-warnings` está LIGADO por default** → `analyze` pode sair com código não-zero (exit 1) mesmo sem `--set-exit-on-violation-level`. Use `--no-fatal-warnings` para gating só de métricas.

## (e) check-unused-files — flags

| Flag | Abbr | Notes |
|---|---|---|
| `--reporter` | `-r` | only `console`, `json` (default `console`) |
| `--monorepo` | | "Treat all exported files as unused by default." |
| `--[no-]fatal-unused` | | DEFAULT ON; "Treat find unused file as fatal." (exit 1) |
| `--delete-files` | `-d` | "Delete all unused files." — **DESTRUCTIVE**: nunca em árvore suja ou em fluxo não-supervisionado |

Mais os common flags. Em monorepo/melos, sem `--monorepo` os arquivos exportados são considerados usados (falsos negativos).

## (f) check-unused-l10n — flags

| Flag | Abbr | Notes |
|---|---|---|
| `--class-pattern` | `-p` | default `I18n$` (regex); "The pattern to detect classes providing localization" |
| `--reporter` | `-r` | `console`, `json` (default `console`) |
| `--[no-]fatal-unused` | | DEFAULT ON |

Passe `-p '<regex>'` se a classe de localização não terminar em `I18n`.

## (g) check-unused-code / check-unnecessary-nullable — reporters

Reporters: **apenas `console`, `json`** (default `console`). Ambos têm flags de exit `fatal-unused` / `fatal-found`.

## Suporte a reporters difere por comando

| Comando | Reporters suportados |
|---|---|
| `analyze`, `fix` | todos os 8: `console`, `console-verbose`, `checkstyle`, `codeclimate`, `github`, `gitlab`, `html`, `json` |
| `check-unused-files` | **apenas** `console`, `json` |
| `check-unused-code` | **apenas** `console`, `json` |
| `check-unused-l10n` | **apenas** `console`, `json` |
| `check-unnecessary-nullable` | **apenas** `console`, `json` |

Para `analyze`, prefira `--reporter=json` ou `--json-path=file` (este escreve JSON em arquivo e ainda imprime resumo no console). Veja `references/output-parsing.md` para o schema do JSON.

## Exemplos prontos para copiar

Projeto completo, saída JSON em arquivo:

```bash
dart run dart_code_linter:metrics analyze lib --reporter=json > /tmp/dcl.json
```

Gating só de métricas (desliga o fatal default dos warnings, sai 2 a partir de yellow):

```bash
dart run dart_code_linter:metrics analyze lib --no-fatal-warnings --set-exit-on-violation-level=warning
```

Relatório HTML estático no diretório `metrics`:

```bash
dart run dart_code_linter:metrics analyze lib --reporter=html --output-directory=metrics
```

Arquivos não usados, com escopo (e excluindo codegen extra além do default):

```bash
dart run dart_code_linter:metrics check-unused-files lib --exclude='{/**.g.dart,/**.freezed.dart,/**.gr.dart}'
```
