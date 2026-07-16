# Catálogo de regras (84)

DCL traz 84 regras (o README diz "over 70 pre-built rules"). Cada `rule-id` corresponde ao nome do diretório-fonte com `_` trocado por `-`. Os ids estão grafados exatamente como na ferramenta.

Cerca de ~40 das 84 regras têm auto-fix (marcadas com 🛠) — aplicáveis via quick-fix do IDE (VS Code Quick Fix pelo analyzer-plugin) ou pelo comando `fix` (`dart run dart_code_linter:metrics fix lib`). As demais exigem correção manual; veja as receitas em `fix-playbook.md`. Métricas e anti-patterns **não** são auto-fixáveis.

Duas regras exigem configuração obrigatória do usuário e estão marcadas **(needs config)**: `avoid-banned-imports` e `ban-name`. Elas **não** funcionam no protocolo novo de plugin (`plugins:`/`diagnostics:`) — só via legacy `analyzer.plugins:`.

## Como habilitar uma regra

A regra precisa estar declarada na configuração do `analysis_options.yaml`. A forma depende do SDK (ver `setup.md`):

- **Dart < 3.9 (legacy):** adicione o id à lista `rules:` dentro do bloco `dart_code_linter`:
```yaml
analyzer:
  plugins:
    - dart_code_linter
dart_code_linter:
  rules:
    - avoid-dynamic
    - prefer-trailing-comma
```
- **Dart ≥ 3.9 (recomendado):** declare como `rule-id: true` dentro de `plugins:` → `diagnostics:`:
```yaml
plugins:
  dart_code_linter:
    diagnostics:
      avoid-dynamic: true
      prefer-trailing-comma: true
```

Caveat: regras que exigem config (`avoid-banned-imports`, `ban-name`) **não** são suportadas no protocolo novo `diagnostics:` — use o bloco legacy `analyzer.plugins:` para elas.

## Common / Dart

| Rule id | Descrição (curta) | 🛠 |
|---|---|---|
| arguments-ordering | Impõe ordem dos argumentos nomeados | |
| avoid-banned-imports | Bane imports configurados **(needs config)** | |
| avoid-cascade-after-if-null | Cascade após `??` | |
| avoid-collection-methods-with-unrelated-types | Métodos de coleção com tipos incompatíveis | |
| avoid-double-slash-imports | Imports com barra dupla | 🛠 |
| avoid-duplicate-exports | Exports duplicados | 🛠 |
| avoid-dynamic | Uso de `dynamic` | |
| avoid-global-state | Variáveis globais mutáveis | |
| avoid-ignoring-return-values | Valores de retorno ignorados | |
| avoid-late-keyword | Uso da palavra-chave `late` | 🛠 |
| avoid-missing-enum-constant-in-map | Constante de enum ausente no map | |
| avoid-nested-conditional-expressions | Expressões condicionais aninhadas | |
| avoid-non-ascii-symbols | Símbolos não-ASCII | |
| avoid-non-null-assertion | Operador bang `!` | |
| avoid-passing-async-when-sync-expected | Passar async onde se espera sync | |
| avoid-redundant-async | `async` redundante | 🛠 |
| avoid-substring | Uso de `substring` | |
| avoid-throw-in-catch-block | `throw` dentro de bloco `catch` | |
| avoid-top-level-members-in-tests | Membros top-level em testes | 🛠 |
| avoid-unnecessary-conditionals | Condicionais desnecessárias | 🛠 |
| avoid-unnecessary-type-assertions | `is`/`whereType` desnecessários | |
| avoid-unnecessary-type-casts | `as` desnecessário | |
| avoid-unrelated-type-assertions | `is` com tipo não relacionado | |
| avoid-unused-parameters | Parâmetros não usados | 🛠 |
| ban-name | Bane nomes configurados **(needs config)** | |
| binary-expression-operand-order | Literal à esquerda em expressão binária | 🛠 |
| double-literal-format | Formato de literal `double` | 🛠 |
| format-comment | Formatação de comentário | 🛠 |
| list-all-equatable-fields | Lista todos os campos de Equatable | 🛠 |
| member-ordering | Ordenação de membros da classe | 🛠 |
| missing-test-assertion | Testes sem assertion | |
| newline-before-return | Linha em branco antes do `return` | 🛠 |
| no-blank-line-before-single-return | Sem linha em branco antes de `return` único | |
| no-boolean-literal-compare | Comparação com literal booleano | 🛠 |
| no-empty-block | Bloco vazio | |
| no-equal-arguments | Argumentos iguais | |
| no-equal-then-else | Ramos `then`/`else` iguais | 🛠 |
| no-magic-number | Números literais fora de constantes | |
| no-object-declaration | Uso do tipo `Object` | |
| only-barrel-import | Apenas barrel import | |
| prefer-async-await | `async`/`await` em vez de `.then()` | |
| prefer-commenting-analyzer-ignores | `// ignore:` sem descrição | |
| prefer-conditional-expressions | Prefere expressões condicionais | 🛠 |
| prefer-correct-identifier-length | Comprimento correto de identificador | |
| prefer-correct-test-file-name | Arquivo de teste termina em `_test.dart` | |
| prefer-correct-type-name | Nome de tipo correto | |
| prefer-enums-by-name | `byName` em enums | |
| prefer-first | `.first` em vez de `[0]` | 🛠 |
| prefer-first-or-null | Prefere `firstOrNull` | |
| prefer-immediate-return | Retorno imediato | 🛠 |
| prefer-iterable-of | `List.of` em vez de `List.from` | 🛠 |
| prefer-last | Prefere `.last` | 🛠 |
| prefer-match-file-name | Nome do arquivo casa com a classe | 🛠 |
| prefer-moving-to-variable | Cadeias de invocação duplicadas | |
| prefer-named-record-fields | Campos de record nomeados | 🛠 |
| prefer-single-quotes | Aspas simples | |
| prefer-static-class | Membros estáticos em vez de constantes globais | |
| prefer-trailing-comma | Vírgula final | 🛠 |
| tag-name | Nome da tag casa com a classe | 🛠 |

## Flutter

| Rule id | Descrição (curta) | 🛠 |
|---|---|---|
| always-remove-listener | Sempre remover listener | |
| avoid-border-all | Evitar `Border.all` | 🛠 |
| avoid-expanded-as-spacer | Evitar `Expanded` como espaçador | 🛠 |
| avoid-returning-widgets | Evitar retornar widgets | |
| avoid-shrink-wrap-in-lists | Evitar `shrinkWrap` em listas | |
| avoid-unnecessary-setstate | `setState` em lifecycle | |
| avoid-wrapping-in-padding | Evitar envolver em `Padding` | |
| check-for-equals-in-render-object-setters | Checar igualdade em setters de render object | |
| consistent-update-render-object | `updateRenderObject` consistente | |
| prefer-const-border-radius | `BorderRadius` const | 🛠 |
| prefer-correct-edge-insets-constructor | Construtor `EdgeInsets` correto | 🛠 |
| prefer-define-hero-tag | Definir `heroTag` | |
| prefer-extracting-callbacks | Extrair callbacks | |
| prefer-media-query-direct-access | Acesso direto a `MediaQuery` | 🛠 |
| prefer-single-widget-per-file | Um widget por arquivo | |
| prefer-using-list-view | `ListView` em vez de `Column` em `SingleChildScrollView` | |
| use-setstate-synchronously | `setState` após `await` | |

## Flame

| Rule id | Descrição (curta) | 🛠 |
|---|---|---|
| avoid-creating-vector-in-update | Evitar criar vetor em `update` | |
| avoid-initializing-in-on-mount | Evitar inicializar em `onMount` | |
| avoid-redundant-async-on-load | `async` redundante em `onLoad` | 🛠 |
| correct-game-instantiating | Instanciação correta do game | |

## Intl

| Rule id | Descrição (curta) | 🛠 |
|---|---|---|
| prefer-intl-name | Nome `ClassName_ClassMemberName` | 🛠 |
| prefer-provide-intl-description | Fornecer descrição de Intl | |
| provide-correct-intl-args | Fornecer args corretos de Intl | |

> `use-design-system` também existe no código-fonte; descrição não confirmada.
