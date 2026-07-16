# Métricas e anti-patterns

Referência das 10 métricas e dos 2 anti-patterns do `dart_code_linter` (DCL). Métricas são reportadas no comando `analyze` (e `fix`) e aparecem no JSON dentro de `fileMetrics`, `classes[].metrics` e `functions[].metrics` (ver `references/output-parsing.md`). Anti-pattern hits aparecem em `antiPatternCases`.

## Catálogo das 10 métricas

| Metric id | O que mede | Threshold recomendado | Escopo |
|---|---|---|---|
| `cyclomatic-complexity` | Caminhos linearmente independentes através de um method (McCabe; base 1 + cada control-flow/conditional) | 20 | method |
| `halstead-volume` | Tamanho do method a partir de #operators + #operands | 150 | method |
| `lines-of-code` | LOC físicas de um method INCLUINDO linhas em branco + comentários | 100 | method |
| `maximum-nesting-level` | Nível máximo de aninhamento de control structures num method | 5 | method |
| `number-of-methods` | Número de methods de uma class | 10 | class |
| `number-of-parameters` | Número de parâmetros de um method | 4 | method |
| `source-lines-of-code` | Linhas de código aproximadas EXCLUINDO branco + comentários | 50 | method |
| `weight-of-class` | #methods públicos funcionais ÷ total de membros públicos | 0.33 | class |
| `maintainability-index` | Composto (cyclomatic + halstead + SLOC) — **ainda muito experimental**, "should not be taken as seriously" | 50 | method |
| `technical-debt` | Custo de retrabalho de uma solução fácil-agora-em-vez-de-melhor | 0 | file |

> Os números acima são os **defaults recomendados** pela ferramenta, NÃO aplicados automaticamente.
>
> `maintainability-index` é **experimental**: o próprio tool avisa que ele é "still very experimental ... should not be taken as seriously". Use com cautela e não o trate como gate rígido.

## Quando uma métrica é reportada

Uma métrica só é calculada/reportada para os ids que você **declarar explicitamente** sob `metrics:` no `analysis_options.yaml` (mapa `metric-id: threshold`) **ou** que passar via flag CLI de threshold no `analyze`. Sem declaração, a métrica não aparece no relatório.

Exemplo de config (ver `references/setup.md`):

```yaml
dart_code_linter:
  metrics:
    cyclomatic-complexity: 20
    number-of-parameters: 4
    maximum-nesting-level: 5
```

### Flags CLI de override (10)

Passadas ao `analyze` (e `fix`), sobrescrevem a config. Valor não-inteiro é rejeitado com warning.

```text
--cyclomatic-complexity
--halstead-volume
--lines-of-code
--maximum-nesting-level
--number-of-methods
--number-of-parameters
--source-lines-of-code
--weight-of-class
--maintainability-index
--technical-debt
```

## MetricValueLevel

Cada `MetricValue` no JSON carrega um campo `level`, calculado em função do valor versus o threshold configurado. É um enum distinto do `Severity` de rules/`--fatal-*`.

| Level | Cor | Faixa (% do threshold) |
|---|---|---|
| `none` | green | abaixo do threshold (`< threshold`) |
| `noted` | blue | 80–100% do threshold |
| `warning` | yellow | 100–200% do threshold |
| `alarm` | red | acima de 200% do threshold (`> 200%`) |

Ordenação: `none` < `noted` < `warning` < `alarm`.

A flag `--set-exit-on-violation-level` aceita **apenas** `noted`, `warning` ou `alarm` (`none` não é aceito). Ela faz o `analyze` retornar exit code 2 quando há violação de métrica em level igual ou superior ao selecionado. Ver `references/ci.md`.

## Anti-patterns (2)

Habilitados via lista `anti-patterns:` no `analysis_options.yaml`:

```yaml
dart_code_linter:
  anti-patterns:
    - long-method
    - long-parameter-list
```

| Anti-pattern | Métrica usada | Severity | Mensagem |
|---|---|---|---|
| `long-method` | `source-lines-of-code` | warning | "Long \<type\>. This \<type\> contains \<n\> lines with code." |
| `long-parameter-list` | `number-of-parameters` | warning | "Long Parameter List. This \<type\> require \<n\> arguments." |

### Caveat-chave: anti-patterns não têm threshold próprio

Os dois anti-patterns **não definem thresholds numéricos standalone** — eles fazem piggyback nos thresholds das métricas correspondentes:

- `long-method` flagra uma função cujo `source-lines-of-code` excede o threshold **e** está acima do level `none`. Funções `build` que retornam `Widget` são **excluídas** de `long-method`.
- `long-parameter-list` depende do threshold de `number-of-parameters`.

Consequência prática: as métricas correspondentes (`source-lines-of-code` e `number-of-parameters`) precisam estar **configuradas** sob `metrics:` (ou via flag CLI) para que os anti-patterns disparem. Sem o threshold da métrica, o anti-pattern não tem com o que comparar e fica inerte.
