# Playbook de correção

Como o LLM realmente **corrige** cada tipo de violação do DCL. Este é o documento mais importante da skill para a fase de fix (L1+ do `SKILL.md`).

Princípio que rege tudo: corrija do **menor blast radius para o maior**, e **re-analise + `dart analyze` + testes após CADA lote** (Step 5 do `SKILL.md`, via `scripts/dcl-verify.sh`). Nunca aplique `suggestions[].replacement` às cegas — confira que casa com o `codeSpan` antes de aceitar.

---

## A — Ordem de correção (menor blast radius primeiro)

Aplique nesta ordem, um lote por vez:

1. **Auto-fixes seguros (L1+)** — mecânicos, baixo risco:
   ```bash
   dart fix --apply                                  # regras do SDK (analyzer/package:lints), NÃO regras DCL
   dart format .                                      # formatação/whitespace/vírgulas
   dart run dart_code_linter:metrics fix <target>     # regras DCL marcadas 🛠
   ```
   > ⚠️ **Em PR / changed-files mode, escope os fixers ao diff.** `dart fix --apply` (sem alvo) e `dart format .` (`.`) atuam no **projeto inteiro** e poluem o diff com arquivos que o PR não tocou. Restrinja aos arquivos alterados:
   > ```bash
   > dart format <arquivos-do-PR>                      # nunca `dart format .` em PR-mode
   > dart fix --apply <arquivos-ou-dirs-do-PR>         # restrinja o escopo (ou pule)
   > dart run dart_code_linter:metrics fix <arquivos-do-PR>
   > ```
   > Os arquivos do PR saem de `scripts/dcl-changed-files.sh --no-analyze`.
2. **Correções manuais de regra (L2+)** — para regras **não-🛠**: aplique a receita por regra da Seção C, arquivo por arquivo.
3. **Refactors estruturais (L3)** — para **métricas** e **anti-patterns** (`long-method`, `cyclomatic-complexity` alto, `maximum-nesting-level`, `long-parameter-list`): extract method, early-return, agrupar params. Receitas na Seção D.

Após **cada** lote:
```bash
bash scripts/dcl-verify.sh --target lib   # re-roda DCL analyze + dart analyze + dart/flutter test
```
Um fix só está "pronto" quando o DCL reporta a violação sumida **E** `dart analyze` está limpo **E** os testes passam. Se um lote introduz nova violação ou quebra de teste, reverta esse lote e tente um fix mais estreito. Em `branch+verify`, faça commit atômico de cada lote limpo (`dcl: fix <ruleId> in <files>`).

> Regra de ouro: **nunca** aplique `suggestions[].replacement` do JSON sem antes verificar que o `codeSpan` (lembre: `line`/`column` são **0-based**) corresponde ao trecho real, e sempre re-analise depois.

---

## B — Fronteira de ferramentas (quem corrige o quê)

| Ferramenta | Cobre | NÃO cobre |
|---|---|---|
| `dart fix --apply` | fixes do analyzer core / `package:lints` (regras do SDK) | regras DCL, métricas, anti-patterns |
| `dart format .` | formatação, whitespace, trailing commas | qualquer regra de lógica/semântica |
| `dart run dart_code_linter:metrics fix <target>` | regras **DCL marcadas 🛠** (aplica fixes ao working tree) | regras DCL não-🛠, métricas, anti-patterns |
| IDE Quick Fix (analyzer-plugin) | mesmas ~40 regras 🛠 de 84, uma a uma | regras não-🛠, métricas, anti-patterns |
| **Manual / LLM** | regras não-fixable + **todas** as métricas + **ambos** anti-patterns (`long-method`, `long-parameter-list`) | — |

Pontos de atenção (das facts):
- O comando `fix` do DCL é real no 4.1.2 mas **levemente documentado** — rode primeiro num branch descartável e verifique o diff antes de confiar.
- Métricas e anti-patterns **não são auto-corrigíveis** por nenhuma ferramenta: são sempre manuais/LLM (extract method, reduzir nesting, agrupar params).
- `dart fix` e `dart format` operam em nível de SDK e **não conhecem** regras DCL — não conte com eles para resolver violações DCL.

---

## C — Receitas por regra (correção manual)

Legenda: **🛠** = há fix automático (prefira `dcl fix` / IDE Quick Fix em vez de editar à mão). **manual** = só dá editando.

| Regra | Fix |
|---|---|
| `avoid-non-null-assertion` | manual |
| `no-magic-number` | manual |
| `avoid-dynamic` | manual |
| `avoid-nested-conditional-expressions` | manual |
| `prefer-conditional-expressions` | 🛠 |
| `newline-before-return` | 🛠 |
| `no-empty-block` | manual |
| `avoid-unused-parameters` | 🛠 |
| `no-boolean-literal-compare` | 🛠 |
| `prefer-trailing-comma` | 🛠 |
| `member-ordering` | 🛠 |
| `avoid-throw-in-catch-block` | manual |
| `prefer-async-await` | manual |

### avoid-non-null-assertion (manual)
Elimine o `!` (bang). Trate o `null` explicitamente.
```dart
// before
final name = user.profile!.name;

// after
final profile = user.profile;
if (profile == null) return;
final name = profile.name;
// ou: final name = user.profile?.name ?? 'anônimo';
```

### no-magic-number (manual)
Promova o literal numérico a constante nomeada.
```dart
// before
if (items.length > 7) showWarning();

// after
const maxVisibleItems = 7;
if (items.length > maxVisibleItems) showWarning();
```

### avoid-dynamic (manual)
Troque `dynamic` por um tipo concreto, genérico ou `Object?`.
```dart
// before
dynamic parse(dynamic input) => input.toString();

// after
String parse(Object? input) => input.toString();
```

### avoid-nested-conditional-expressions (manual)
Ternário aninhado vira `if`/`else` ou `switch`.
```dart
// before
final label = a ? 'x' : b ? 'y' : 'z';

// after
String label;
if (a) {
  label = 'x';
} else if (b) {
  label = 'y';
} else {
  label = 'z';
}
```

### prefer-conditional-expressions (🛠 — preferir dcl fix/IDE)
`if`/`else` de atribuição única vira ternário.
```dart
// before
if (isActive) {
  color = Colors.green;
} else {
  color = Colors.grey;
}

// after
color = isActive ? Colors.green : Colors.grey;
```

### newline-before-return (🛠 — preferir dcl fix/IDE)
Linha em branco antes do `return`.
```dart
// before
void f() {
  doWork();
  return;
}

// after
void f() {
  doWork();

  return;
}
```

### no-empty-block (manual)
Bloco vazio: preencha, remova, ou documente a intenção.
```dart
// before
void onTap() {}

// after
void onTap() {
  // no-op: ação intencionalmente vazia até a feature X chegar
}
```

### avoid-unused-parameters (🛠 — preferir dcl fix/IDE)
Remova o parâmetro não usado, ou marque-o com `_` quando a assinatura é imposta (override/callback).
```dart
// before
int compute(int a, int unused) => a * 2;

// after
int compute(int a) => a * 2;
// quando a assinatura é obrigatória (ex.: callback):
void onChanged(String _) => reload();
```

### no-boolean-literal-compare (🛠 — preferir dcl fix/IDE)
Não compare com `true`/`false`.
```dart
// before
if (isReady == true) start();
if (isReady == false) wait();

// after
if (isReady) start();
if (!isReady) wait();
```

### prefer-trailing-comma (🛠 — preferir dcl fix/IDE/`dart format`)
Vírgula final em listas multiline (melhora diff e auto-formatação).
```dart
// before
final w = Row(children: [a, b, c]);

// after
final w = Row(
  children: [a, b, c],
);
```

### member-ordering (🛠 — preferir dcl fix/IDE)
Reordene membros da classe conforme a convenção configurada (campos → construtores → métodos, etc.).
```dart
// before
class C {
  void m() {}
  final int x;
  C(this.x);
}

// after
class C {
  final int x;

  C(this.x);

  void m() {}
}
```

### avoid-throw-in-catch-block (manual)
Não dê `throw` de um objeto novo dentro do `catch` (perde o stack trace original). Re-lance com `rethrow` ou propague a causa.
```dart
// before
try {
  risky();
} catch (e) {
  throw Exception('falhou');
}

// after
try {
  risky();
} catch (e, st) {
  Error.throwWithStackTrace(StateError('falhou: $e'), st);
  // ou simplesmente: rethrow;
}
```

### prefer-async-await (manual)
Troque cadeias `.then()` por `async`/`await`.
```dart
// before
Future<int> load() {
  return fetch().then((r) => r.length);
}

// after
Future<int> load() async {
  final r = await fetch();
  return r.length;
}
```

### Regras Flutter

| Regra | Fix |
|---|---|
| `avoid-returning-widgets` | manual |
| `prefer-extracting-callbacks` | manual |
| `avoid-unnecessary-setstate` | manual |
| `use-setstate-synchronously` | manual |
| `avoid-border-all` | 🛠 |
| `prefer-const-border-radius` | 🛠 |

#### avoid-returning-widgets (manual)
Método que retorna `Widget` vira um `Widget` próprio (classe) ou entra no `build`.
```dart
// before
Widget _buildHeader() => const Text('título');
// ...
child: _buildHeader(),

// after
class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) => const Text('título');
}
// ...
child: const _Header(),
```

#### prefer-extracting-callbacks (manual)
Closure inline grande vira método nomeado.
```dart
// before
ElevatedButton(
  onPressed: () {
    setState(() => _count++);
    _log('tap');
    _maybeSubmit();
  },
  child: const Text('OK'),
);

// after
ElevatedButton(
  onPressed: _onOkPressed,
  child: const Text('OK'),
);
// ...
void _onOkPressed() {
  setState(() => _count++);
  _log('tap');
  _maybeSubmit();
}
```

#### avoid-unnecessary-setstate (manual)
Não chame `setState` dentro de métodos de lifecycle (`initState`, `didUpdateWidget`, `build`): a reconstrução já vai ocorrer.
```dart
// before
@override
void initState() {
  super.initState();
  setState(() => _ready = true);
}

// after
@override
void initState() {
  super.initState();
  _ready = true; // build seguinte já reflete o valor
}
```

#### use-setstate-synchronously (manual)
Não chame `setState` após um `await` sem checar `mounted`.
```dart
// before
Future<void> _refresh() async {
  final data = await _load();
  setState(() => _data = data);
}

// after
Future<void> _refresh() async {
  final data = await _load();
  if (!mounted) return;
  setState(() => _data = data);
}
```

#### avoid-border-all (🛠 — preferir dcl fix/IDE)
`Border.all()` não é `const`; use o construtor `const Border.fromBorderSide`.
```dart
// before
Container(decoration: BoxDecoration(border: Border.all(color: Colors.red)));

// after
Container(
  decoration: const BoxDecoration(
    border: Border.fromBorderSide(BorderSide(color: Colors.red)),
  ),
);
```

#### prefer-const-border-radius (🛠 — preferir dcl fix/IDE)
Use `const` no `BorderRadius`.
```dart
// before
borderRadius: BorderRadius.all(Radius.circular(8));

// after
borderRadius: const BorderRadius.all(Radius.circular(8));
```

---

## D — Receitas por métrica / anti-pattern (refactor estrutural, L3)

Métricas e anti-patterns **nunca** são auto-corrigíveis (Seção B). São sempre refactor manual. Atacar os drivers (complexidade, tamanho, nesting, params) é o que move as métricas compostas.

| Métrica / anti-pattern | Estratégia |
|---|---|
| `cyclomatic-complexity` alto | extract method (quebrar ramos) |
| `long-method` (anti-pattern, usa `source-lines-of-code`) | extract method |
| `source-lines-of-code` / `lines-of-code` | extract method |
| `maximum-nesting-level` | early-return / guard clauses para achatar |
| `number-of-parameters` | agrupar em objeto de parâmetros / named params |
| `long-parameter-list` (anti-pattern, usa `number-of-parameters`) | agrupar em objeto de parâmetros / classe de config |
| `number-of-methods` | dividir a classe (SRP) |
| `weight-of-class` | dividir a classe (SRP) |
| `technical-debt` | consequência das demais → atacar os drivers |
| `maintainability-index` | consequência (cyclomatic+halstead+SLOC) → atacar os drivers |

> Lembrete (facts): os anti-patterns `long-method` e `long-parameter-list` **não têm threshold próprio** — herdam de `source-lines-of-code` e `number-of-parameters` respectivamente. Esses metrics precisam estar configurados sob `metrics:` (ou via flag CLI) para os anti-patterns dispararem. `maintainability-index` é marcado pelo próprio tool como "still very experimental ... should not be taken as seriously".

### cyclomatic-complexity alto / long-method / source-lines-of-code / lines-of-code → extract method
Quebre o método grande em métodos focados.
```dart
// before
void process(Order o) {
  if (o.items.isEmpty) { /* ... */ }
  double total = 0;
  for (final i in o.items) {
    total += i.price * i.qty;
    if (i.discount > 0) total -= i.discount;
  }
  if (o.coupon != null) { /* aplica cupom... */ }
  // ... mais 30 linhas de notificação, log, persistência
}

// after
void process(Order o) {
  _validate(o);
  final total = _computeTotal(o);
  _persist(o, total);
  _notify(o, total);
}

double _computeTotal(Order o) {
  var total = 0.0;
  for (final i in o.items) {
    total += i.price * i.qty - (i.discount > 0 ? i.discount : 0);
  }
  return total;
}
// _validate / _persist / _notify analogamente
```

### maximum-nesting-level → early-return / guard clauses
Inverta condições e retorne cedo para achatar o aninhamento.
```dart
// before
String classify(User? u) {
  if (u != null) {
    if (u.isActive) {
      if (u.role == 'admin') {
        return 'admin';
      }
    }
  }
  return 'none';
}

// after
String classify(User? u) {
  if (u == null) return 'none';
  if (!u.isActive) return 'none';
  if (u.role != 'admin') return 'none';

  return 'admin';
}
```

### number-of-parameters / long-parameter-list → objeto de parâmetros / named params / classe de config
```dart
// before
Widget banner(String title, String subtitle, Color bg, Color fg, IconData icon, bool dense) { /* ... */ }

// after
class BannerConfig {
  const BannerConfig({
    required this.title,
    required this.subtitle,
    required this.bg,
    required this.fg,
    required this.icon,
    this.dense = false,
  });
  final String title;
  final String subtitle;
  final Color bg;
  final Color fg;
  final IconData icon;
  final bool dense;
}

Widget banner(BannerConfig config) { /* ... */ }
```

### number-of-methods / weight-of-class → dividir a classe (SRP)
Uma classe que faz demais vira várias responsabilidades separadas.
```dart
// before
class UserManager {
  void login() {}
  void logout() {}
  void validateEmail() {}
  void hashPassword() {}
  void sendWelcomeEmail() {}
  void renderProfile() {}
  // ... muitos métodos não relacionados
}

// after
class AuthService { void login() {} void logout() {} }
class CredentialValidator { void validateEmail() {} void hashPassword() {} }
class UserNotifier { void sendWelcomeEmail() {} }
class ProfileView { void render() {} }
```

### technical-debt / maintainability-index → atacar os drivers
Não há "fix" direto: ambas são **consequência** das métricas acima. Reduza `cyclomatic-complexity`, `source-lines-of-code`/`lines-of-code` e nesting com extract-method e guard clauses, e elas caem por arrasto. Re-analise para confirmar a queda.

---

## E — Quando NÃO corrigir

Nem toda violação deve virar mudança de código. Casos legítimos de **não** mutilar o código:

- **Falsos positivos** — a regra dispara mas o código está correto para o contexto.
- **Código gerado** — `*.g.dart`, `*.freezed.dart` (já no `--exclude` default `{/**.g.dart,/**.freezed.dart}`); estenda o exclude para outros codegen (`*.gr.dart`, `*.config.dart`).
- **Conflito com convenção do projeto** — a regra contraria um padrão deliberado do time.

Mecanismos, do mais local ao mais global:

1. **Suprimir uma ocorrência** — `// ignore:` com descrição. A regra `prefer-commenting-analyzer-ignores` exige que todo `// ignore:` tenha justificativa. Use supressão **só** quando o não-nulo é provável localmente (um valor atribuído/guardado logo acima), nunca para dados externos:
   ```dart
   final cached = _cache[key];
   if (cached == null) return null;
   // ignore: avoid-non-null-assertion  -- _cache[key] checado não-nulo na linha acima
   return _cache[key]!.value;
   ```
   > ⚠️ **Nunca** suprima `avoid-non-null-assertion` em dados externos/decodificados (ex.: `json['id']!`) — é exatamente onde um `null` do backend gera crash em runtime. Aí o fix correto é um null-check ou `?? default`, não o `!`:
   > ```dart
   > final id = json['id'] as String? ?? (throw FormatException('id ausente'));
   > // ou: if (json['id'] == null) { ...trate... }
   > ```
2. **Excluir caminhos** no `analysis_options.yaml` — `metrics-exclude:` (métricas) e `rules-exclude:` (regras), em glob:
   ```yaml
   dart_code_linter:
     metrics-exclude:
       - test/**
     rules-exclude:
       - lib/generated/**
   ```
3. **Ajustar o threshold** em vez de refatorar — quando o limite default não cabe no projeto, suba o número sob `metrics:` (ou via flag CLI, que sobrescreve o config) em vez de quebrar o código:
   ```yaml
   dart_code_linter:
     metrics:
       cyclomatic-complexity: 25
       number-of-parameters: 6
   ```

Preferência: ajuste **threshold** ou **exclude** quando o problema é o limite/escopo, e reserve `// ignore:` para a exceção pontual e justificada. Mutilar código para silenciar o linter é a última opção.

Veja também: `references/troubleshooting.md` (pitfalls, monorepo/melos), `references/cli-reference.md` (flags exatas), `references/metrics.md` (thresholds e anti-patterns).
