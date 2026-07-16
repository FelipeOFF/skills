# Config templates do DCL (analysis_options.yaml por nível)

Estes quatro arquivos são fragmentos de `analysis_options.yaml` que configuram o
`dart_code_linter` (DCL) em quatro profundidades crescentes — os mesmos níveis
L0/L1/L2/L3 descritos no `SKILL.md` e em `references/levels.md`. Cada nível define
quais **metrics** (com seus thresholds), **rules** e **anti-patterns** o DCL aplica
quando você roda `dart run dart_code_linter:metrics analyze <target>`.

## Propósito

Em vez de escrever a config à mão, você escolhe o nível adequado ao momento do
projeto e cola o bloco no `analysis_options.yaml`. A escalada é cumulativa:

- **L0** estabelece linha de base de diagnóstico (thresholds recomendados, rules
  seguras, sem anti-patterns).
- **L1** acrescenta as rules auto-fixáveis (🛠) para alimentar o `dcl fix`.
- **L2** aperta thresholds, amplia rules e liga os anti-patterns.
- **L3** usa thresholds agressivos e a maior lista de rules, forçando refatoração.

## Como aplicar

1. Abra (ou crie) o `analysis_options.yaml` na raiz do projeto.
2. Copie o conteúdo do template do nível desejado para dentro dele. Se o arquivo
   já tem um bloco `analyzer:` ou `dart_code_linter:`, **mescle** as chaves em vez
   de duplicar o mapeamento.
3. **Escolha o wiring conforme o SDK** — os templates trazem o LEGACY embutido e o
   equivalente >=3.9 no comentário de topo:
   - **Dart < 3.9 (legacy, já no arquivo):** o bloco
     ```yaml
     analyzer:
       plugins:
         - dart_code_linter
     ```
     mais o bloco `dart_code_linter:` no topo.
   - **Dart >= 3.9 (recomendado):** substitua o `analyzer.plugins` pela forma
     top-level `plugins:` com `diagnostics:` (mapa `rule-id: true`), mantendo as
     mesmas `metrics`/`metrics-exclude`. As rules que exigem config obrigatória
     (`avoid-banned-imports`, `ban-name`) **não** funcionam por esse protocolo —
     para elas, fique no legacy.
4. Recarregue o IDE após editar o `analysis_options.yaml` (bloco de plugin errado
   = plugin carregado em silêncio sem efeito).
5. Rode `dart pub get` (Flutter: `flutter pub get`) antes do primeiro `dart run`.

Os templates usam apenas ids reais de metrics e rules do DCL. `metrics:` é um mapa
`id -> número`; `rules:` é uma lista de ids; `anti-patterns:` é uma lista de ids.
Os anti-patterns **não têm threshold próprio** — `long-method` se apoia em
`source-lines-of-code` e `long-parameter-list` em `number-of-parameters`, então
essas métricas precisam estar declaradas em `metrics:` para os anti-patterns
dispararem (já estão, em todos os níveis que os ativam).

## Nível -> arquivo -> o que muda

| Nível | Arquivo | Metrics (thresholds) | Rules | Anti-patterns |
|-------|---------|----------------------|-------|---------------|
| **L0** report-only | `l0-report.yaml` | cyclomatic-complexity 20, number-of-parameters 4, maximum-nesting-level 5, source-lines-of-code 50; `metrics-exclude: test/**` | lista pequena e segura (5) | nenhum |
| **L1** safe-fix | `l1-safe.yaml` | mesmos thresholds do L0 | L0 + rules auto-fixáveis (🛠) para o `dcl fix` | nenhum |
| **L2** standard | `l2-standard.yaml` | mais apertados (ex.: cyclomatic-complexity 15, maximum-nesting-level 4) + number-of-methods 10, lines-of-code 100 | lista ampla (L1 + rules manuais) | `long-method`, `long-parameter-list` |
| **L3** deep | `l3-deep.yaml` | agressivos: cyclomatic-complexity 10, number-of-parameters 3, maximum-nesting-level 3, source-lines-of-code 40, number-of-methods 10, weight-of-class 0.33, maintainability-index 50, lines-of-code 100, halstead-volume 150 | a maior lista de rules | `long-method`, `long-parameter-list` |

> `maintainability-index` é, segundo a doc do DCL, "still very experimental ...
> should not be taken as seriously"; `technical-debt` é medido por arquivo. Trate
> esses sinais com cautela. Os números acima são os thresholds recomendados pela
> ferramenta — não são aplicados automaticamente; só valem porque estão declarados
> aqui ou passados via flag de CLI.
