# Setup e configuração do DCL

Guia de instalação e wiring do `dart_code_linter` (DCL). Cobre detecção do projeto, instalação, compatibilidade SDK/analyzer, wiring do plugin por versão de SDK, o esqueleto completo do bloco de config e como verificar a config resolvida.

## 1. Detecção do projeto

DCL roda em projetos Dart e Flutter (não há constraint separado de Flutter SDK — ele depende do pacote `analyzer`).

- **É um projeto Dart/Flutter?** Existe um `pubspec.yaml` na raiz.
- **É Flutter?** O `pubspec.yaml` declara dependência de `flutter` (sob `dependencies:`). Caso contrário, é Dart puro.

A variante do comando de instalação (`dart` vs `flutter`) depende dessa distinção.

## 2. Instalação

Adicione o DCL como dependência de desenvolvimento:

```bash
# Dart puro
dart pub add --dev dart_code_linter

# Flutter
flutter pub add --dev dart_code_linter
```

Isso adiciona a linha abaixo sob `dev_dependencies:` no `pubspec.yaml`:

```yaml
dev_dependencies:
  dart_code_linter: ^4.1.2
```

Em seguida resolva as dependências:

```bash
# Dart puro
dart pub get

# Flutter
flutter pub get
```

> O `pub get` é obrigatório antes de qualquer `dart run dart_code_linter:metrics ...` — sem ele o runner não resolve o pacote e o comando falha.

## 3. Compatibilidade SDK / analyzer

Tabela do README (escolha a versão de DCL compatível com seu Dart SDK e com o pacote `analyzer`):

| DCL | Analyzer | Dart SDK |
|---|---|---|
| 4.1.2 | >=10.0.0 <14.0.0 | >=3.5.0 <4.0.0 |
| 4.1.1 | >=10.0.0 <14.0.0 | >=3.5.0 <4.0.0 |
| 4.1.0 | >=10.0.0 <14.0.0 | >=3.5.0 <4.0.0 |
| 4.0.5–4.0.1 | >=10.0.0 <13.0.0 | >=3.5.0 <4.0.0 |
| 4.0.0 | >=11.0.0 <12.0.0 | >=3.5.0 <4.0.0 |
| >=3.2.0 <4.0.0 | ^8.0.0 | >=3.4.0 <4.0.0 |
| >=3.0.0 <3.2.0 | ^7.4.1 | >=3.4.0 <4.0.0 |
| >=2.0.0 <3.0.0 | ^6.0.0 | >=3.0.0 <4.0.0 |

> **Não há constraint separado de Flutter SDK** — a compatibilidade é determinada pelo pacote `analyzer`. O DCL funciona tanto para Dart puro quanto para Flutter.

## 4. Wiring do plugin por versão de SDK

O bloco que registra o plugin no `analysis_options.yaml` **depende da versão do Dart SDK**. Escolher o bloco errado faz o plugin **não carregar silenciosamente** (zero output, sem erro). Após editar o `analysis_options.yaml`, **recarregue a IDE** para o plugin recarregar.

### Dart ≥ 3.9 (recomendado) — `plugins:` / `diagnostics:`

```yaml
plugins:
  dart_code_linter:
    diagnostics:
      avoid-dynamic: true
      prefer-trailing-comma: true
```

> **Caveat:** regras que exigem config obrigatória do usuário (`avoid-banned-imports`, `ban-name`) **NÃO** são suportadas por este protocolo novo de plugin — para usá-las, recorra ao bloco legacy abaixo.

### Dart < 3.9 (legacy) — `analyzer.plugins`

```yaml
analyzer:
  plugins:
    - dart_code_linter
dart_code_linter:
  rules:
    - avoid-dynamic
    - prefer-trailing-comma
```

## 5. Esqueleto e config do bloco `dart_code_linter`

A chave top-level de configuração é `dart_code_linter`. Esqueleto completo das seções:

```yaml
dart_code_linter:
  extends:
    - ...
  metrics:
    - ...
  metrics-exclude:
    - ...
  rules:
    - ...
  rules-exclude:
    - ...
  anti-patterns:
    - ...
```

O que cada seção faz:

| Seção | Função |
|---|---|
| `extends` | Herda configuração de outro preset/arquivo base. |
| `metrics` | Métricas habilitadas, na forma `metric-id: threshold` (MAP). |
| `metrics-exclude` | Globs de arquivos isentos da avaliação de métricas. |
| `rules` | Lista de regras (rule-ids) habilitadas. |
| `rules-exclude` | Globs de arquivos isentos da avaliação de regras. |
| `anti-patterns` | Lista de anti-patterns habilitados (`long-method`, `long-parameter-list`); eles dependem dos thresholds das métricas correspondentes. |

### Exemplo funcional (README) — verbatim

```yaml
analyzer:
  plugins:
    - dart_code_linter

dart_code_linter:
  metrics:
    cyclomatic-complexity: 20
    number-of-parameters: 4
    maximum-nesting-level: 5
  metrics-exclude:
    - test/**
  rules:
    - avoid-dynamic
    - avoid-passing-async-when-sync-expected
    - avoid-redundant-async
    - avoid-unnecessary-type-assertions
    - avoid-unnecessary-type-casts
    - avoid-unrelated-type-assertions
    - avoid-unused-parameters
    - avoid-nested-conditional-expressions
    - newline-before-return
    - no-boolean-literal-compare
    - no-empty-block
    - prefer-trailing-comma
    - prefer-conditional-expressions
    - no-equal-then-else
    - prefer-moving-to-variable
    - prefer-match-file-name
```

## 6. Observações sobre o formato da config

- `metrics:` é um **MAP** de `metric-id: threshold` (não uma lista).
- `rules:` é uma **LISTA** de rule-ids.
- A forma de map por-regra herdada do DCM — `rule-id: {severity: warning, exclude: [...]}` — **NÃO é verificada no DCL** (marque como herdada/não confirmada antes de depender dela).
- A chave `formatter` **NÃO é verificada / provavelmente não existe** no DCL.
- Excludes do próprio analyzer (arquivos que o analyzer deve ignorar por completo) usam a lista de globs padrão `analyzer.exclude:`, separada dos `metrics-exclude`/`rules-exclude` do DCL.

## 7. Verificar a config resolvida

Para inspecionar a configuração efetivamente resolvida pelo DCL:

```bash
dart run dart_code_linter:metrics analyze lib --print-config
# abreviação:
dart run dart_code_linter:metrics analyze lib -c
```

A flag `--print-config` (`-c`) imprime a config resolvida (é non-negatable, default off).

> **Caveat:** as regras que exigem config (`avoid-banned-imports`, `ban-name`) **não funcionam no protocolo novo de plugin** (Dart ≥ 3.9, bloco `plugins:`/`diagnostics:`). Para usá-las, configure pelo bloco **legacy** (`analyzer.plugins` + `dart_code_linter.rules`).
