# Níveis de profundidade L0–L3

Os quatro níveis controlam **quanto** o DCL diagnostica e **se/quanto** ele edita o código. Vão de diagnóstico puro (L0) a refactors estruturais com gate de CII agressivo (L3). Cada nível inclui tudo do anterior. Sempre rode com `--reporter=json` (ou `--json-path=<file>`) para parsear o que corrigir e onde; veja `references/output-parsing.md`.

Os templates de config por nível estão em `scripts/config-templates/`. Os tiers de correção (auto, manual, refactor) estão detalhados em `references/fix-playbook.md`.

## Tabela comparativa

| Nível | Edita? | Regras | Anti-patterns | Métricas | Refactor | Gate CI |
|-------|--------|--------|---------------|----------|----------|---------|
| **L0** report-only | Não | Lê e reporta (sem aplicar fix) | Reporta se já configurados | Reporta se já configuradas | Não | Nenhum (só diagnóstico) |
| **L1** safe-fix | Sim (seguro) | Aplica fixes de regras 🛠 + SDK | Reporta | Reporta | Não | Opcional: default `--fatal-warnings` (exit 1) |
| **L2** standard | Sim | L1 + fixes manuais de regra por arquivo | Habilita `anti-patterns:` | Thresholds moderados (defaults recomendados) | Não | Default `--fatal-warnings`; opcional `--set-exit-on-violation-level` |
| **L3** deep | Sim (estrutural) | L2 + tudo de regra restante | Habilitados, firam pelos thresholds | Thresholds agressivos | Sim (extract-method, flatten, split params) | `--set-exit-on-violation-level=warning` (exit 2) |

---

## L0 — report-only

**Objetivo:** diagnóstico puro. Levantar e priorizar violações sem tocar em nenhuma linha de código.

**O que roda:**
```bash
dart run dart_code_linter:metrics analyze lib --reporter=json > /tmp/dcl.json
# parsear para lista priorizada (nada de edição):
python3 scripts/parse-dcl-json.py /tmp/dcl.json
```
Para evitar exit não-zero atrapalhando o pipeline de relatório (lembre que `--fatal-warnings` é ON por default), use também `--no-fatal-warnings`:
```bash
dart run dart_code_linter:metrics analyze lib --reporter=json --no-fatal-warnings > /tmp/dcl.json
```

**Config-template:** `scripts/config-templates/l0-report.yaml` — só regras/métricas para *observar*, sem `anti-patterns:`. Métricas só são reportadas para ids declarados em `metrics:` (ou passados por flag de threshold na CLI).

**Tiers do fix-playbook aplicáveis:** nenhum. L0 não corrige nada.

**Exit/gate:** sem gate. Trate o relatório como saída de leitura; não falhe o build por causa dele. Se rodar em CI só para coletar, prefira `--no-fatal-warnings` para não disparar exit 1 inadvertidamente.

**Quando escolher:** primeira passada num código desconhecido; auditoria/inventário de débito técnico; quando você quer entender o blast radius antes de mexer; quando não há autorização para editar.

---

## L1 — safe-fix

**Objetivo:** L0 + aplicar apenas correções mecânicas e de baixo risco. Sem refactor, sem mudança de comportamento.

**O que roda:**
```bash
# 1) diagnóstico (igual L0)
dart run dart_code_linter:metrics analyze lib --reporter=json > /tmp/dcl.json
python3 scripts/parse-dcl-json.py /tmp/dcl.json

# 2) fixes seguros, do menor blast radius para o maior:
dart fix --apply                                   # fixes do analyzer/SDK (NÃO regras DCL)
dart format .                                       # whitespace/trailing commas
dart run dart_code_linter:metrics fix lib           # fixes das regras DCL 🛠 (working tree)

# 3) re-verificar
bash scripts/dcl-verify.sh --target lib
```
Lembrete: `fix` é real no 4.1.2 porém pouco documentado — valide em branch descartável. `dart fix --apply` cobre regras do SDK/package:lints, não regras DCL. Métricas e anti-patterns NÃO são auto-corrigíveis aqui.

**Config-template:** `scripts/config-templates/l1-safe.yaml` — habilita as regras com 🛠 (auto-fixáveis) e as regras de SDK relevantes; ainda sem `anti-patterns:` e sem thresholds de métrica agressivos.

**Tiers do fix-playbook aplicáveis:** apenas o tier de **auto-fix** (regras 🛠 via `dcl fix`/IDE; SDK via `dart fix`/`dart format`). Nada de manual nem refactor.

**Exit/gate:** opcional. Por default `--fatal-warnings` está ON, então `analyze` pode sair com exit 1 mesmo sem `--set-exit-on-violation-level`. Para um gate só-mecânico sem barrar métricas, pode usar `--no-fatal-warnings`.

**Quando escolher:** higienização rápida e segura; pré-commit; quando você quer reduzir ruído antes de uma revisão maior sem risco de regressão semântica.

---

## L2 — standard

**Objetivo:** L1 + habilitar anti-patterns, aplicar thresholds de métrica moderados e corrigir manualmente as violações de regra não auto-fixáveis, arquivo a arquivo, re-verificando.

**O que roda:**
```bash
# diagnóstico com anti-patterns + métricas ligados (via config-template L2)
dart run dart_code_linter:metrics analyze lib --reporter=json > /tmp/dcl.json
python3 scripts/parse-dcl-json.py /tmp/dcl.json

# tier auto (igual L1)
dart fix --apply && dart format . && dart run dart_code_linter:metrics fix lib

# tier manual: aplicar recipe por regra do fix-playbook, por arquivo, e re-verificar a cada lote
bash scripts/dcl-verify.sh --target lib
```
Os anti-patterns (`long-method`, `long-parameter-list`) NÃO têm threshold próprio: eles dependem das métricas `source-lines-of-code` e `number-of-parameters`, que precisam estar configuradas em `metrics:` para disparar.

**Config-template:** `scripts/config-templates/l2-standard.yaml` — adiciona a lista `anti-patterns:` (com as métricas-piggyback configuradas) e thresholds moderados, alinhados aos defaults recomendados pela ferramenta (ex.: `cyclomatic-complexity: 20`, `number-of-parameters: 4`, `maximum-nesting-level: 5`, `source-lines-of-code: 50`).

**Tiers do fix-playbook aplicáveis:** **auto** (de L1) + **manual** (recipes por regra como `avoid-non-null-assertion`, `no-magic-number`, etc.). Ainda NÃO entra o tier de refactor estrutural de métrica.

**Exit/gate:** default `--fatal-warnings` (exit 1 em warnings de regra). Opcionalmente acrescente `--set-exit-on-violation-level=warning` para também barrar violações de métrica ≥ amarelo (exit 2). Veja `references/ci.md`.

**Quando escolher:** trabalho de qualidade "padrão" num módulo; quando você vai investir em corrigir regras de fato (não só as 🛠) e quer começar a medir métricas, mas ainda sem reescrever estrutura.

---

## L3 — deep

**Objetivo:** L2 + thresholds agressivos + refactors estruturais para baixar métricas e anti-patterns, com gate de CI estrito.

**O que roda:**
```bash
# diagnóstico com thresholds agressivos + anti-patterns (config-template L3)
dart run dart_code_linter:metrics analyze lib --reporter=json > /tmp/dcl.json
python3 scripts/parse-dcl-json.py /tmp/dcl.json

# tiers auto + manual (de L1/L2)
dart fix --apply && dart format . && dart run dart_code_linter:metrics fix lib

# tier refactor: extract-method, early-returns para achatar nesting, agrupar params em objetos
# (recipes em references/fix-playbook.md) — um refactor por vez, re-verificando
bash scripts/dcl-verify.sh --target lib

# gate estrito (CI ou validação final):
dart run dart_code_linter:metrics analyze lib --reporter=github --set-exit-on-violation-level=warning
```
`--set-exit-on-violation-level=warning` faz exit 2 quando há violação de métrica em nível `warning` (amarelo, 100–200% do threshold) ou superior. Refactors estruturais podem mudar comportamento — por isso o `branch+verify` é fortemente recomendado aqui e a re-verificação após CADA refactor é obrigatória.

**Config-template:** `scripts/config-templates/l3-deep.yaml` — thresholds agressivos (mais baixos que os defaults), `anti-patterns:` habilitados e firando, conjunto amplo de regras.

**Tiers do fix-playbook aplicáveis:** **auto** + **manual** + **refactor** (estrutural de métrica/anti-pattern: `long-method`, `cyclomatic-complexity` alta, `maximum-nesting-level`, `long-parameter-list`).

**Exit/gate:** estrito — `--set-exit-on-violation-level=warning` (exit 2 em métricas ≥ amarelo), combinado com o default `--fatal-warnings` (exit 1 em regras). Para anotações inline use `--reporter=github` (GitHub) ou `--reporter=gitlab` (GitLab).

**Quando escolher:** endurecer a qualidade de um módulo crítico; estabelecer/elevar o quality gate de CI; pagar débito estrutural com autorização para reescrever funções e assinaturas. Não use em código que você não pode testar bem.

---

## Combinando nível × escopo × modo de segurança

Os três eixos são independentes e devem ser escolhidos juntos no início de cada run (veja Step 1 no SKILL.md):

- **Nível × escopo (full vs PR):**
  - **Full** (`lib`, opcionalmente `test`): use para auditorias e endurecimento planejado. L0/L1 full é seguro a qualquer momento; L2/L3 full é um esforço maior — fatie por módulo.
  - **PR / changed-files** (`scripts/dcl-changed-files.sh --base origin/main` ou `--pr 123`): mantenha o nível **baixo a moderado** (L0 para review, L1/L2 para corrigir só o que o PR tocou). Evite L3 em PR-mode: refactor estrutural amplo extrapola o diff e dificulta a revisão. Detalhes em `references/pr-mode.md`.

- **Nível × modo de segurança (branch+verify vs in-place):**
  - **L0:** modo de segurança é irrelevante (não edita). `in-place` serve.
  - **L1:** `in-place` é aceitável (fixes mecânicos), mas `branch+verify` ainda é a recomendação padrão.
  - **L2 e L3:** use SEMPRE `branch+verify` — tree limpa → branch → commits atômicos por lote (`dcl: fix <ruleId> in <files>`) → re-verificação após cada lote. Quanto mais estrutural o fix (L3), mais indispensável o `branch+verify`, porque um refactor pode quebrar comportamento e você precisa poder reverter o lote isolado.

- **Regra geral:** quanto mais alto o nível, mais estreito o escopo por iteração e mais rígido o modo de segurança. Nunca rode L3 full in-place numa árvore suja. E independentemente do nível ≥ L1, a verificação do Step 5 (`scripts/dcl-verify.sh`) roda após CADA lote — sem exceção.
