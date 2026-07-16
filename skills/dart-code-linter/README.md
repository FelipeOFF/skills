# dart_code_linter_skill

Skill do Claude Code para usar o pacote [`dart_code_linter`](https://pub.dev/packages/dart_code_linter) (DCL) — a fork open-source mantida do dart-code-metrics (DCM) — em projetos **Dart/Flutter**: encontra problemas no código (rules, métricas, anti-patterns) e os corrige automaticamente, em **níveis de profundidade** aplicáveis, no projeto inteiro ou só nos **arquivos alterados de uma PR**.

> Entrypoint da skill: **[`SKILL.md`](./SKILL.md)**. É o arquivo que o Claude Code carrega; comece por ele.

## Instalação

Via [`npx skills`](https://github.com/vercel-labs/agent-skills) — gerenciador de skills de agentes, sem nada global instalado:

```bash
# instala no projeto atual (.claude/skills, .agents/skills, etc.)
npx skills add FelipeOFF/dart_code_linter_skill

# global (nível usuário), para todos os projetos
npx skills add FelipeOFF/dart_code_linter_skill --global

# escolher para quais agentes instalar ('*' = todos os suportados)
npx skills add FelipeOFF/dart_code_linter_skill --agent '*' -y

# só listar o que o repositório expõe, sem instalar
npx skills add FelipeOFF/dart_code_linter_skill --list
```

Confirmar / atualizar / remover (a skill se registra como `dart-code-linter`):

```bash
npx skills list                      # deve listar dart-code-linter
npx skills update dart-code-linter
npx skills remove dart-code-linter
```

### Instalação manual (alternativa)

```bash
git clone https://github.com/FelipeOFF/dart_code_linter_skill.git \
  ~/.claude/skills/dart_code_linter_skill
```

### Usar

Dentro de um projeto Dart/Flutter, peça algo como *"rode o dart_code_linter no nível L2"* ou invoque a skill `dart-code-linter`. O fluxo decisório completo (escopo, nível, segurança) está em [`SKILL.md`](./SKILL.md).

## O que ela faz

- Detecta o projeto, garante o DCL instalado e a config (`analysis_options.yaml`) certa para o SDK.
- Roda o DCL com `--reporter=json`, **parseia o output** (sabe *o quê* e *onde* corrigir) e aplica correções em lotes, **re-verificando** (DCL + `dart analyze` + testes) após cada lote.
- Funciona em escopo **projeto inteiro** ou **PR / arquivos alterados** (via `git diff` ou `gh` por número de PR).

## Níveis de profundidade

| Nível | Nome | O que faz | Edita código? |
|-------|------|-----------|---------------|
| **L0** | report-only | analisa e prioriza, não muda nada | Não |
| **L1** | safe-fix | `dart fix` + `dart format` + `dcl fix` (regras 🛠) | Sim (seguro) |
| **L2** | standard | L1 + anti-patterns + métricas moderadas + fixes manuais guiados | Sim |
| **L3** | deep | L2 + thresholds agressivos + refactors estruturais + gate de CI | Sim (estrutural) |

## Estrutura

```
SKILL.md                  # entrypoint operacional (dispatch + loop)
references/               # documentação de apoio (progressive disclosure)
  setup.md, cli-reference.md, rules-catalog.md, metrics.md,
  output-parsing.md, fix-playbook.md, levels.md, pr-mode.md,
  ci.md, troubleshooting.md
scripts/                  # ferramentas executáveis
  dcl-run.sh              # wrapper: pub get + analyze + JSON
  dcl-changed-files.sh    # resolve + analisa .dart alterados (git/gh)
  parse-dcl-json.py       # JSON -> lista priorizada de violações
  dcl-verify.sh           # gate: re-analyze + dart analyze + testes
  config-templates/       # analysis_options.yaml por nível (L0-L3)
```

## Uso rápido (dentro de um projeto Dart/Flutter)

```bash
# projeto inteiro, coletar JSON
bash scripts/dcl-run.sh --target lib --json-out /tmp/dcl.json
python3 scripts/parse-dcl-json.py /tmp/dcl.json

# só os .dart da PR #123
bash scripts/dcl-changed-files.sh --pr 123 --json-out /tmp/dcl-pr.json

# verificar após correções
bash scripts/dcl-verify.sh --target lib
```

## Proveniência

Baseado no `dart_code_linter` v4.1.2 (repo `bancolombia/dart-code-linter`, MIT). Fatos de comandos, flags, 84 rules, 10 métricas, 2 anti-patterns, schema JSON e exit codes conferidos contra pub.dev, o README do repositório e o código-fonte.
