#!/usr/bin/env bash
#
# dcl-changed-files.sh — resolve os arquivos .dart alterados de um branch ou PR
# e roda `dart run dart_code_linter:metrics analyze` apenas sobre eles.
#
# DCL aceita múltiplos paths em um único analyze, então o subconjunto de
# arquivos alterados é passado de uma vez. Arquivos deletados, *.g.dart e
# *.freezed.dart são filtrados; se nada sobrar, sai 0 (nada a lintar).
#
# Uso:
#   bash scripts/dcl-changed-files.sh [opções]
#
# Opções:
#   --base <ref>       Base de comparação para o diff (default: origin/main).
#   --pr <number>      Resolve os arquivos de um PR do GitHub via gh CLI.
#   --staged           Usa apenas mudanças staged (git diff --cached).
#   --json-out <file>  Grava a saída JSON do analyze nesse arquivo.
#   --analyze          Roda DCL analyze sobre os arquivos (default).
#   --no-analyze       Apenas lista os arquivos resolvidos; não roda DCL.
#   -h, --help         Mostra esta ajuda.
#
# Exemplos:
#   # branch local vs base (origin/main)
#   bash scripts/dcl-changed-files.sh --base origin/main --json-out /tmp/dcl-pr.json
#
#   # um PR do GitHub por número (usa gh CLI)
#   bash scripts/dcl-changed-files.sh --pr 123 --json-out /tmp/dcl-pr.json
#
# CAVEAT: as checagens unused-* (check-unused-files / check-unused-code /
# check-unused-l10n) precisam do projeto inteiro para serem corretas — um
# subconjunto de arquivos gera falsos positivos. Rode-as no projeto completo,
# não neste modo de arquivos alterados.

set -euo pipefail

# ---- defaults ----------------------------------------------------------------
BASE="origin/main"
PR=""
STAGED=0
JSON_OUT=""
ANALYZE=1

usage() {
  sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
}

# ---- parse args --------------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --base)
      [ "$#" -ge 2 ] || { echo "error: --base requires a <ref>" >&2; exit 64; }
      BASE="$2"; shift 2 ;;
    --pr)
      [ "$#" -ge 2 ] || { echo "error: --pr requires a <number>" >&2; exit 64; }
      PR="$2"; shift 2 ;;
    --staged)
      STAGED=1; shift ;;
    --json-out)
      [ "$#" -ge 2 ] || { echo "error: --json-out requires a <file>" >&2; exit 64; }
      JSON_OUT="$2"; shift 2 ;;
    --analyze)
      ANALYZE=1; shift ;;
    --no-analyze)
      ANALYZE=0; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "error: unknown argument: $1" >&2
      echo "run with --help for usage." >&2
      exit 64 ;;
  esac
done

# ---- resolve changed files into a NUL-delimited temp list -------------------
# NUL-delimitado (git -z) + core.quotePath=false => robusto a espaços, newlines
# e unicode nos paths. NÃO capturamos NUL em $() (bash descarta bytes NUL), por
# isso usamos um arquivo temporário.
TMPLIST="$(mktemp)"
trap 'rm -f "$TMPLIST"' EXIT

if [ -n "$PR" ]; then
  command -v gh >/dev/null 2>&1 || {
    echo "error: --pr requires the gh CLI, which was not found on PATH." >&2
    exit 64
  }
  # Distingue 'gh ok, sem .dart' de 'gh falhou'. Se AMBAS as tentativas falham,
  # erro hard (exit 1): jamais reportar gate limpo para um PR que nunca foi
  # analisado (auth expirada, rede, repo errado, rate limit, PR inexistente).
  GH_RAW=""
  if GH_RAW="$(gh pr diff "$PR" --name-only)"; then
    :
  elif GH_RAW="$(gh pr view "$PR" --json files -q '.files[].path')"; then
    :
  else
    echo "error: gh não conseguiu resolver os arquivos do PR #$PR. Recusando reportar gate limpo para um PR não analisado." >&2
    exit 1
  fi
  # paths do GitHub são '/'-separados e sem newline; converte para NUL.
  printf '%s\n' "$GH_RAW" | tr '\n' '\0' >"$TMPLIST"
elif [ "$STAGED" -eq 1 ]; then
  if ! git -c core.quotePath=false diff -z --name-only --cached --diff-filter=ACMR >"$TMPLIST"; then
    echo "error: 'git diff --cached' falhou (não é um repositório git?)." >&2
    exit 65
  fi
else
  if ! git -c core.quotePath=false diff -z --name-only --diff-filter=ACMR "${BASE}...HEAD" >"$TMPLIST"; then
    echo "error: 'git diff' falhou para a base '${BASE}' (não é um repo, ref desconhecida ou clone shallow). Se a base não foi baixada, rode 'git fetch origin ${BASE}'." >&2
    exit 65
  fi
fi

# ---- filter: *.dart, drop generated, drop nonexistent (deleted) -------------
# Leitura NUL-delimitada a partir de arquivo (não de pipe) para popular FILES[]
# no shell atual.
FILES=()
while IFS= read -r -d '' f; do
  [ -n "$f" ] || continue
  case "$f" in
    *.dart) ;;            # keep
    *) continue ;;        # not Dart
  esac
  case "$f" in
    *.g.dart|*.freezed.dart) continue ;;  # generated
  esac
  [ -f "$f" ] || continue               # deleted / missing on disk
  case "$f" in
    -*) f="./$f" ;;       # ./-prefix: path com '-' inicial nunca vira "opção"
  esac
  FILES+=("$f")
done <"$TMPLIST"

# ---- nothing to lint ---------------------------------------------------------
if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No changed .dart files to lint (after excluding generated/deleted files). Nothing to do." >&2
  exit 0
fi

# ---- report the resolved list to stderr -------------------------------------
echo "Resolved ${#FILES[@]} changed .dart file(s):" >&2
for f in "${FILES[@]}"; do
  echo "  $f" >&2
done

# ---- list-only mode ----------------------------------------------------------
if [ "$ANALYZE" -eq 0 ]; then
  for f in "${FILES[@]}"; do
    echo "$f"
  done
  exit 0
fi

# ---- analyze the resolved files ---------------------------------------------
# Prefer the sibling wrapper if present; else call DCL directly. DCL accepts
# multiple paths in a single analyze invocation.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -n "$JSON_OUT" ]; then
  if [ -f "${SCRIPT_DIR}/dcl-run.sh" ]; then
    # Passa UM --target por arquivo (dcl-run.sh aceita --target repetível).
    # NÃO colapsar em "${FILES[*]}": viraria um único path inválido.
    RUN_ARGS=()
    for f in "${FILES[@]}"; do RUN_ARGS+=(--target "$f"); done
    bash "${SCRIPT_DIR}/dcl-run.sh" "${RUN_ARGS[@]}" --json-out "$JSON_OUT"
  else
    dart run dart_code_linter:metrics analyze "${FILES[@]}" --reporter=json >"$JSON_OUT"
  fi
else
  dart run dart_code_linter:metrics analyze "${FILES[@]}" --reporter=json
fi
