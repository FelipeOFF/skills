#!/usr/bin/env bash
#
# dcl-run.sh — wrapper para rodar o dart_code_linter (DCL) emitindo JSON.
#
# Garante `pub get` (Flutter ou Dart, detectado pelo pubspec.yaml) e roda um
# comando do DCL via `dart run dart_code_linter:metrics <command> <target>
# --reporter=json`. O DCL NÃO tem binário standalone `dcl`; o entrypoint
# canônico é o `metrics` runner. Veja SKILL.md (Step 2) e
# references/cli-reference.md.
#
# IMPORTANTE: o DCL sai com código != 0 quando há violações (exit 1 por
# --fatal-warnings ON-by-default, 2 por --set-exit-on-violation-level, 3 por
# Severity.error, etc — ver references/ci.md). Quando o objetivo é apenas
# COLETAR o JSON, isso não é uma falha do wrapper: este script captura o exit
# code do DCL, ainda produz o JSON, imprime o código no stderr e sai 0 numa
# coleta limpa. Decisões de gate/CI ficam para dcl-verify.sh / references/ci.md,
# não para este coletor.
#
# USAGE:
#   bash scripts/dcl-run.sh [opções] [-- <args extras passados verbatim ao DCL>]
#
# OPÇÕES:
#   --target <path>      Diretório/arquivo a analisar (default: lib). O DCL
#                        EXIGE um target; bare `analyze` falha. REPETÍVEL:
#                        passe --target várias vezes para analisar múltiplos
#                        paths num único run (ex.: arquivos de uma PR).
#   --command <cmd>      Comando do DCL (default: analyze). Ex.: analyze, fix,
#                        check-unused-files, check-unused-code,
#                        check-unused-l10n, check-unnecessary-nullable.
#   --json-out <file>    Grava o JSON nesse arquivo. Para `analyze`/`fix` usa
#                        --json-path <file>; para os demais comandos redireciona
#                        o stdout. Sem esta flag, o JSON vai para stdout.
#   --root-folder <path> Repassado ao DCL como --root-folder <path> (default do
#                        DCL: diretório atual; deve existir).
#   --no-pub-get         Pula o `pub get` (assume deps já resolvidas).
#   -h, --help           Mostra esta ajuda e sai.
#
# Tudo que vier DEPOIS de um literal `--` é repassado verbatim ao DCL (ex.:
# --exclude, --no-fatal-warnings, --set-exit-on-violation-level=warning,
# --class-pattern, --monorepo, thresholds de métrica, etc).
#
# EXEMPLOS:
#   # analyze em lib, JSON no stdout
#   bash scripts/dcl-run.sh
#
#   # analyze em lib, JSON gravado em arquivo
#   bash scripts/dcl-run.sh --target lib --json-out /tmp/dcl.json
#
#   # métricas-only (sem fatal warnings), passthrough após --
#   bash scripts/dcl-run.sh --target lib --json-out /tmp/dcl.json -- --no-fatal-warnings
#
#   # checar arquivos não usados em lib, JSON em arquivo
#   bash scripts/dcl-run.sh --command check-unused-files --target lib --json-out /tmp/unused.json
#
#   # excluir codegen adicional via passthrough
#   bash scripts/dcl-run.sh --target lib -- --exclude='{/**.g.dart,/**.gr.dart,/**.config.dart}'
#
set -euo pipefail

# --- defaults ---------------------------------------------------------------
# TARGETS é um array: --target é repetível, permitindo múltiplos paths num
# único analyze (o DCL aceita vários paths). Default vira ("lib") se nenhum
# --target for passado.
TARGETS=()
COMMAND="analyze"
JSON_OUT=""
ROOT_FOLDER=""
RUN_PUB_GET=1
PASSTHROUGH=()

# --- help -------------------------------------------------------------------
print_help() {
  # Imprime o bloco de comentário do topo (linhas iniciadas por '# ').
  sed -n '2,/^set -euo pipefail/p' "$0" | sed 's/^# \{0,1\}//; s/^#$//' | sed '$d'
}

# --- parse de argumentos ----------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target)
      [ "$#" -ge 2 ] || { echo "dcl-run: --target requer um valor" >&2; exit 64; }
      TARGETS+=("$2"); shift 2 ;;
    --command)
      [ "$#" -ge 2 ] || { echo "dcl-run: --command requer um valor" >&2; exit 64; }
      COMMAND="$2"; shift 2 ;;
    --json-out)
      [ "$#" -ge 2 ] || { echo "dcl-run: --json-out requer um valor" >&2; exit 64; }
      JSON_OUT="$2"; shift 2 ;;
    --root-folder)
      [ "$#" -ge 2 ] || { echo "dcl-run: --root-folder requer um valor" >&2; exit 64; }
      ROOT_FOLDER="$2"; shift 2 ;;
    --no-pub-get)
      RUN_PUB_GET=0; shift ;;
    -h|--help)
      print_help; exit 0 ;;
    --)
      shift
      # tudo após '--' é repassado verbatim ao DCL
      while [ "$#" -gt 0 ]; do PASSTHROUGH+=("$1"); shift; done
      break ;;
    *)
      echo "dcl-run: argumento desconhecido: $1 (use -- para passthrough ao DCL)" >&2
      exit 64 ;;
  esac
done

# --- validação --------------------------------------------------------------
# O DCL exige ao menos um target; bare `analyze` falha com
# "Invalid number of directories or files. At least one must be specified."
# Sem --target explícito, usamos o default "lib".
if [ "${#TARGETS[@]}" -eq 0 ]; then
  TARGETS=("lib")
fi

# Normaliza targets com '-' inicial para './-...' — nunca interpretados como
# opção pelo parser de args do DCL (option-injection via nome de arquivo).
NORM_TARGETS=()
for _t in "${TARGETS[@]}"; do
  case "$_t" in
    -*) NORM_TARGETS+=("./$_t") ;;
    *)  NORM_TARGETS+=("$_t") ;;
  esac
done
TARGETS=("${NORM_TARGETS[@]}")

if [ ! -f "pubspec.yaml" ]; then
  echo "dcl-run: pubspec.yaml não encontrado no diretório atual; rode dentro da raiz do projeto Dart/Flutter" >&2
  exit 64
fi

# --- detecção Flutter vs Dart -----------------------------------------------
# Flutter se o pubspec referenciar "flutter:" ou "sdk: flutter".
if grep -qE 'flutter:|sdk:[[:space:]]*flutter' pubspec.yaml; then
  RUNNER="flutter"
else
  RUNNER="dart"
fi

# --- pub get (uma vez) ------------------------------------------------------
if [ "$RUN_PUB_GET" -eq 1 ]; then
  echo "+ $RUNNER pub get" >&2
  "$RUNNER" pub get >&2
else
  echo "dcl-run: pulando pub get (--no-pub-get)" >&2
fi

# --- monta o comando do DCL -------------------------------------------------
# Roda sempre via `<runner> run dart_code_linter:metrics`.
DCL_CMD=("$RUNNER" run dart_code_linter:metrics "$COMMAND" "${TARGETS[@]}" --reporter=json)

if [ -n "$ROOT_FOLDER" ]; then
  DCL_CMD+=(--root-folder "$ROOT_FOLDER")
fi

# Destino do JSON:
#   - analyze/fix suportam --json-path <file> (escreve JSON em arquivo, imprime
#     resumo console). Preferimos --json-path para esses comandos.
#   - check-* só têm console+json no --reporter; para eles redirecionamos stdout.
REDIRECT_STDOUT=0
if [ -n "$JSON_OUT" ]; then
  case "$COMMAND" in
    analyze|fix)
      DCL_CMD+=(--json-path "$JSON_OUT") ;;
    *)
      REDIRECT_STDOUT=1 ;;
  esac
fi

# passthrough verbatim ao DCL (após o '--')
if [ "${#PASSTHROUGH[@]}" -gt 0 ]; then
  DCL_CMD+=("${PASSTHROUGH[@]}")
fi

# --- executa ----------------------------------------------------------------
# Ecoa o comando final no stderr antes de rodar.
echo "+ ${DCL_CMD[*]}" >&2

# O DCL sai != 0 em violações. Ao coletar JSON, NÃO deixamos o set -e abortar:
# capturamos o exit code, ainda produzimos o JSON e seguimos.
set +e
if [ "$REDIRECT_STDOUT" -eq 1 ]; then
  "${DCL_CMD[@]}" > "$JSON_OUT"
else
  "${DCL_CMD[@]}"
fi
DCL_EXIT=$?
set -e

# Informa o exit code real do DCL no stderr (para quem precisa do gate de CI).
echo "dcl-run: DCL exit code = $DCL_EXIT" >&2

# Coleta limpa do JSON => saímos 0 mesmo que o DCL tenha sinalizado violações.
# O julgamento de gate/CI fica para dcl-verify.sh e references/ci.md.
exit 0
