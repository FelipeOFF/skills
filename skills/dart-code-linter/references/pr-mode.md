# Modo PR / arquivos alterados

Em vez de analisar `lib` inteiro, este modo roda o DCL apenas sobre os arquivos
`.dart` que mudaram numa branch ou numa pull request, e você corrige só esses.
O `analyze` aceita **múltiplos paths/arquivos** como argumentos, então o fluxo é:
descobrir os arquivos alterados → filtrar → passar a lista filtrada para um único
`analyze ... --reporter=json` → corrigir somente esses arquivos.

> O alvo padrão `--exclude` do DCL já é `{/**.g.dart,/**.freezed.dart}`. Mesmo
> assim, **filtre os gerados na origem** (ver abaixo): passar um `*.g.dart`
> explícito como path posicional contorna o `--exclude` em alguns casos, e você
> não quer gastar análise neles.

## Duas fontes de arquivos alterados

### 1. git diff local

Compare a branch atual com a base. `--diff-filter=ACMR` mantém apenas
**A**dded, **C**opied, **M**odified e **R**enamed — ou seja, exclui deletados
(**D**), que não devem ir para o `analyze` (o arquivo não existe mais).

```bash
# commits da branch vs base (three-dot = desde o merge-base)
git diff --name-only --diff-filter=ACMR <base>...HEAD

# exemplo concreto
git diff --name-only --diff-filter=ACMR origin/main...HEAD
```

Variações úteis:

```bash
# apenas staged (index vs HEAD) — pre-commit
git diff --name-only --diff-filter=ACMR --cached

# working tree não-commitado (modificações ainda não em stage)
git diff --name-only --diff-filter=ACMR

# staged + working tree (HEAD vs árvore atual)
git diff --name-only --diff-filter=ACMR HEAD
```

### 2. GitHub PR via gh CLI

Para uma PR por número, sem precisar dar checkout nela:

```bash
# lista os caminhos alterados na PR #<n>
gh pr diff <n> --name-only

# alternativa estruturada (JSON) — traz path + status de cada arquivo
gh pr view <n> --json files
```

O `gh pr view <n> --json files` retorna objetos com `path` e o status de
adição/remoção, útil para descartar deletados/renomeados de forma programática.

## Filtragem (sempre aplicar)

Independente da fonte, reduza a lista a arquivos que valem análise:

1. **Só `.dart`** — descarte tudo que não termina em `.dart`.
2. **Sem deletados** — `--diff-filter=ACMR` já cobre isso no git; no `gh`,
   ignore arquivos cujo status é deleção.
3. **Sem gerados** — exclua `*.g.dart` e `*.freezed.dart` (mesmos globs do
   `--exclude` default do DCL). Se o projeto usa outros codegens
   (`*.gr.dart`, `*.config.dart`), exclua-os também.

```bash
git diff --name-only --diff-filter=ACMR origin/main...HEAD \
  | grep '\.dart$' \
  | grep -v -e '\.g\.dart$' -e '\.freezed\.dart$'
```

## Rodando o analyze na lista filtrada

O `analyze` aceita os arquivos como múltiplos argumentos posicionais. Mesmo
analisando arquivos isolados, **o DCL continua resolvendo o `analysis_options.yaml`
do projeto** (regras, métricas e plugin wiring valem normalmente — você não perde
a config por passar paths individuais).

```bash
files=$(git diff --name-only --diff-filter=ACMR origin/main...HEAD \
  | grep '\.dart$' \
  | grep -v -e '\.g\.dart$' -e '\.freezed\.dart$')

# nenhum arquivo? não faça nada (ver edge cases)
[ -z "$files" ] && echo "Nenhum .dart alterado" && exit 0

dart run dart_code_linter:metrics analyze $files --reporter=json > /tmp/dcl-pr.json
```

Depois é o fluxo normal da skill: parsear o JSON
(`python3 scripts/parse-dcl-json.py /tmp/dcl-pr.json`), corrigir apenas esses
arquivos e re-verificar (`scripts/dcl-verify.sh`).

## Helper: `scripts/dcl-changed-files.sh`

O wrapper encapsula descoberta + filtragem + `analyze --reporter=json`. Flags:

| Flag | Valor | Significado |
|------|-------|-------------|
| `--base` | ref git (ex. `origin/main`) | diff local da branch atual contra essa base (`<base>...HEAD`) |
| `--pr` | número da PR | resolve os arquivos via `gh` (sem checkout) |
| `--json-out` | caminho | onde gravar o JSON do `analyze` (ex. `/tmp/dcl-pr.json`) |

Ele já filtra para `.dart`, descarta deletados e exclui `*.g.dart`/`*.freezed.dart`.

### Exemplo 1 — branch local contra uma base

```bash
bash scripts/dcl-changed-files.sh --base origin/main --json-out /tmp/dcl-pr.json
```

### Exemplo 2 — PR por número (via gh)

```bash
bash scripts/dcl-changed-files.sh --pr 123 --json-out /tmp/dcl-pr.json
```

## Edge cases

- **Nenhum `.dart` alterado** — a lista filtrada fica vazia. **Não rode**
  `analyze` com lista vazia (sem alvo, ele erra com *"Invalid number of
  directories or files. At least one must be specified."*). Apenas reporte
  "nada a analisar" e saia com sucesso.
- **Arquivos renomeados** — `--diff-filter=ACMR` inclui **R** (rename); o caminho
  que volta é o **novo** nome (destino), que é o que você quer analisar. O caminho
  antigo não aparece, então não há risco de apontar para arquivo inexistente.
- **Base ref não baixada** — se `<base>` (ex. `origin/main`) não está local,
  o `git diff` falha ou compara contra algo errado. Faça
  `git fetch origin <base>` antes:
  ```bash
  git fetch origin main
  git diff --name-only --diff-filter=ACMR origin/main...HEAD
  ```
- **Arquivo isolado vs projeto inteiro** — analisar arquivos individuais **não**
  troca a config: o DCL ainda resolve o `analysis_options.yaml` do projeto. O que
  muda é o **escopo de detecção**, não as regras.
- **Violações cross-file (`unused-*`)** — análise por-arquivo pode **perder**
  violações que dependem de varrer o projeto todo. As checagens de não-usado
  (`check-unused-files`, `check-unused-code`, `check-unused-l10n`) só fazem
  sentido sobre o conjunto completo: um símbolo "não usado" no diff pode estar
  sendo usado por um arquivo fora dele. **Para `unused-*`, rode no projeto
  inteiro (`lib`), nunca só no diff.** O modo PR é para regras e métricas
  por-arquivo.

## Opcional — postar o resultado como comentário na PR

Depois de parsear o JSON, você pode publicar um resumo na própria PR:

```bash
gh pr comment <n> --body "$(cat /tmp/dcl-pr-summary.md)"
# ou inline:
gh pr comment 123 --body "DCL: 3 violações em 2 arquivos alterados. Detalhes acima."
```

Para anotações inline diretamente nas linhas do diff (CI), prefira
`analyze ... --reporter=github` no GitHub Actions — ver `references/ci.md`.
