# Troubleshooting e pitfalls

Catálogo de armadilhas do `dart_code_linter` (DCL) no formato **Sintoma -> Causa -> Correção**. O entrypoint canônico é sempre `dart run dart_code_linter:metrics <command> <target>` (não existe binário `dcl`). Cruze com `references/setup.md` (config + compatibilidade), `references/cli-reference.md` (flags), `references/ci.md` (exit codes) e `references/output-parsing.md` (JSON).

## Tabela-resumo

| # | Sintoma | Causa | Correção |
|---|---------|-------|----------|
| 1 | `dart run` falha ao resolver o pacote DCL | `dart pub get` não rodou após adicionar a dependência | `dart pub get` (Flutter: `flutter pub get`) antes de qualquer `dart run dart_code_linter:metrics` |
| 2 | `Invalid number of directories or files. At least one must be specified.` | `analyze` chamado sem target | Sempre passe um dir/arquivo: `analyze lib` |
| 3 | Codegen aparece nos resultados (ex.: `*.gr.dart`, `*.config.dart`) | `--exclude` default só cobre `{/**.g.dart,/**.freezed.dart}` | Passe `--exclude` cobrindo o outro codegen |
| 4 | `analyze` sai com exit code != 0 sem `--set-exit-on-violation-level` | `--fatal-warnings` está **ON por default** | Use `--no-fatal-warnings` para gating metrics-only |
| 5 | Plugin não carrega, zero output, sem erro | Bloco de plugin errado para o SDK | Use `plugins:`/`diagnostics:` (Dart ≥ 3.9) ou `analyzer.plugins:` (< 3.9); recarregue a IDE |
| 6 | Regra que exige config nunca dispara no protocolo novo | `avoid-banned-imports` / `ban-name` não são suportadas via `plugins:`/`diagnostics:` | Use o bloco legacy `analyzer.plugins:` para essas regras |
| 7 | `check-unused-files` reporta falsos negativos em monorepo | Sem `--monorepo`, arquivos exportados são considerados usados | Rode com `--monorepo` e um `analysis_options.yaml` na raiz (melos) |
| 8 | `check-unused-files` lento ou travando | Issue histórica do DCM em `lib/` grande | Reduza o escopo (subdiretório), não rode na árvore inteira |
| 9 | `check-unused-l10n` não acha as classes de localização | `--class-pattern` default `I18n$` não casa com sua classe | Passe `-p '<regex>'` correspondente ao nome real |
| 10 | Flag de threshold do CLI ignorada ou warning de valor inválido | Flags de threshold do CLI **sobrescrevem** o config; valor não-inteiro é rejeitado | Passe inteiros; a flag CLI ganha do `analysis_options.yaml` |
| 11 | `Could not find reporter` / reporter rejeitado | Reporter não suportado pelo comando | `analyze`/`fix`: 8 reporters; `check-*`: só `console` e `json` |
| 12 | Arquivos sumiram após `check-unused-files` | `--delete-files`/`-d` é destrutivo | Nunca rode em árvore suja nem unattended |
| 13 | Localização do JSON aponta uma linha/coluna a menos que o editor | `line`/`column` do source_span são **0-based** | Some +1 ao reconciliar com editores 1-based |
| 14 | `command "check-dependencies" not found` (exit 64) | `check-dependencies` é só do DCM, não existe no DCL | Use os 6 comandos reais (ver abaixo) |
| 15 | Erro de versão / resolução do `analyzer` ou do SDK | Mismatch entre versão do DCL, do `analyzer` e do Dart SDK | Alinhe pela tabela de compatibilidade em `references/setup.md` |

## Detalhamento por item

### 1. Esquecer `dart pub get`
**Sintoma:** `dart run dart_code_linter:metrics ...` falha ao resolver o pacote.
**Causa:** a dependência foi adicionada ao `pubspec.yaml` mas as dependências não foram baixadas.
**Correção:** rode `dart pub get` (Flutter: `flutter pub get`) primeiro. O wrapper `scripts/dcl-run.sh` já garante isso.

### 2. `analyze` sem target
**Sintoma:** `Invalid number of directories or files. At least one must be specified.`
**Causa:** `analyze` exige pelo menos um dir/arquivo; chamada nua falha.
**Correção:** sempre passe o alvo, ex.: `dart run dart_code_linter:metrics analyze lib`.

### 3. `--exclude` default escondendo codegen
**Sintoma:** arquivos gerados aparecem (ou não) inesperadamente nos resultados.
**Causa:** o default de `--exclude` é o glob `{/**.g.dart,/**.freezed.dart}` — cobre só esses dois. Outros codegen (`*.gr.dart`, `*.config.dart`) não são excluídos.
**Correção:** passe `--exclude` com um glob que cubra o codegen do projeto. Lembre que sobrescrever o default remove a exclusão de `*.g.dart`/`*.freezed.dart`, então inclua-os também se quiser mantê-los fora.

### 4. `--fatal-warnings` ON por default
**Sintoma:** `analyze` sai com exit != 0 mesmo sem `--set-exit-on-violation-level`.
**Causa:** `--[no-]fatal-warnings` tem **default ON (true)**; trata issues de nível warning como fatais (exit 1).
**Correção:** para gating só de métricas, use `--no-fatal-warnings`. Detalhes de exit codes em `references/ci.md`.

### 5. Bloco de plugin errado para o SDK
**Sintoma:** o plugin silenciosamente não carrega — zero output, sem erro.
**Causa:** o bloco de wiring depende da versão do SDK. Dart ≥ 3.9 usa `plugins:` com `diagnostics:`; Dart < 3.9 usa `analyzer.plugins:`. Bloco errado = plugin não carregado.
**Correção:** use o bloco certo para o SDK e **recarregue a IDE** após editar o `analysis_options.yaml`.
```yaml
# Dart >= 3.9
plugins:
  dart_code_linter:
    diagnostics:
      avoid-dynamic: true
      prefer-trailing-comma: true
```
```yaml
# Dart < 3.9 (legacy)
analyzer:
  plugins:
    - dart_code_linter
dart_code_linter:
  rules:
    - avoid-dynamic
    - prefer-trailing-comma
```

### 6. Regras que exigem config não suportadas no protocolo novo
**Sintoma:** `avoid-banned-imports` ou `ban-name` nunca disparam mesmo configuradas.
**Causa:** regras que exigem config obrigatória do usuário NÃO são suportadas pelo protocolo `plugins:`/`diagnostics:` (Dart ≥ 3.9).
**Correção:** configure essas regras pelo bloco legacy `analyzer.plugins:` + `dart_code_linter:`.

### 7. Monorepo / melos e `--monorepo`
**Sintoma:** `check-unused-files` não acusa arquivos realmente não usados em monorepo (falsos negativos).
**Causa:** sem `--monorepo`, arquivos exportados são considerados usados.
**Correção:** defina um `analysis_options.yaml` na raiz e rode `check-unused-files` com `--monorepo` ("Treat all exported files as unused by default.").

### 8. `check-unused-files` lento ou travando
**Sintoma:** o comando demora muito ou trava em `lib/` grande.
**Causa:** issue histórica herdada do DCM em bases grandes.
**Correção:** reduza o escopo — aponte para um subdiretório em vez da árvore inteira.

### 9. `--class-pattern` do `check-unused-l10n`
**Sintoma:** `check-unused-l10n` não detecta as classes de localização.
**Causa:** o default de `--class-pattern`/`-p` é o regex `I18n$`; se a classe não termina em `I18n`, nada casa.
**Correção:** passe `-p '<regex>'` que corresponda ao nome real da classe que provê localização.

### 10. Flags de threshold do CLI sobrescrevem o config
**Sintoma:** o threshold do `analysis_options.yaml` é ignorado, ou um warning de valor inválido aparece.
**Causa:** as flags de threshold do CLI (`--cyclomatic-complexity`, `--lines-of-code`, etc.) **sobrescrevem** o config; valor **não-inteiro é rejeitado com warning**.
**Correção:** passe inteiros e lembre que a flag CLI vence o config quando ambos estão presentes.

### 11. Reporter não suportado pelo comando
**Sintoma:** o reporter escolhido é rejeitado.
**Causa:** o suporte a `--reporter` difere por comando.
**Correção:** `analyze`/`fix` suportam os 8 reporters (`console`, `console-verbose`, `checkstyle`, `codeclimate`, `github`, `gitlab`, `html`, `json`); `check-unused-files` suporta só `console` e `json`; `check-unused-code`, `check-unused-l10n` e `check-unnecessary-nullable` suportam só `console` e `json`.

### 12. `--delete-files` é destrutivo
**Sintoma:** arquivos foram apagados do projeto.
**Causa:** `check-unused-files --delete-files`/`-d` deleta todos os arquivos não usados.
**Correção:** nunca rode em árvore suja nem em fluxo de fix unattended. Revise a lista (sem `-d`) antes.

### 13. `line`/`column` 0-based
**Sintoma:** as posições do JSON aparecem uma unidade abaixo do que o editor mostra.
**Causa:** `offset`/`line`/`column` vêm do `SourceLocation` do `source_span` e `line`/`column` são **0-based** (off-by-one clássico vs. editores 1-based).
**Correção:** some +1 a `line`/`column` ao reportar posições para o usuário. Ver `references/output-parsing.md`.

### 14. Confundir comandos do DCM
**Sintoma:** `check-dependencies` retorna usage error (exit 64).
**Causa:** `check-dependencies` é exclusivo do DCM (comercial) e NÃO existe no DCL.
**Correção:** use os 6 comandos reais: `analyze`, `fix`, `check-unused-files`, `check-unused-code`, `check-unused-l10n`, `check-unnecessary-nullable`.

### 15. Mismatch de versão analyzer / SDK
**Sintoma:** erro de resolução envolvendo o pacote `analyzer` ou o Dart SDK.
**Causa:** a versão do DCL impõe ranges de `analyzer` e de Dart SDK; usar combinações fora desses ranges quebra a resolução.
**Correção:** alinhe DCL, `analyzer` e Dart SDK pela tabela de compatibilidade em `references/setup.md` (ex.: DCL 4.1.2 requer `analyzer >=10.0.0 <14.0.0` e Dart SDK `>=3.5.0 <4.0.0`).
