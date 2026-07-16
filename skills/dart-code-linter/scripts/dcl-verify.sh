#!/usr/bin/env bash
#
# dcl-verify.sh — post-fix verification gate para a skill dart-code-linter (DCL).
#
# Roda TRÊS estágios e reporta PASS/FAIL de cada um, agregando o exit code final.
# Use depois de cada batch de fixes (Step 5 da SKILL): um fix só está "done"
# quando a violação do DCL sumiu E `dart analyze` está limpo E os testes passam.
#
#   Stage 1  DCL analyze     dart run dart_code_linter:metrics analyze <target> --reporter=console
#   Stage 2  dart analyze    (pulado com --skip-dart-analyze)
#   Stage 3  tests           flutter test | dart test (pulado com --skip-tests ou sem test/)
#
# Usa set -uo pipefail (NÃO -e): queremos rodar todos os estágios e agregar,
# não abortar no primeiro que falhar.
#
# USAGE:
#   bash scripts/dcl-verify.sh [--target <path>] [--skip-tests] [--skip-dart-analyze] [-h|--help]
#
# FLAGS:
#   --target <path>        Diretório/arquivo a verificar (default: lib).
#   --skip-dart-analyze    Pula o Stage 2 (dart analyze).
#   --skip-tests           Pula o Stage 3 (testes).
#   -h, --help             Mostra esta ajuda e sai.
#
# EXIT CODE:
#   0  se todos os estágios requeridos passaram.
#   1  se qualquer estágio requerido falhou (agregado).
#
# NOTAS:
#   - Stage 1 usa --reporter=console (humano). Para parsing por script/LLM,
#     troque por: dart run dart_code_linter:metrics analyze <target> --reporter=json
#     > /tmp/dcl.json  e passe o arquivo em python3 scripts/parse-dcl-json.py /tmp/dcl.json
#   - O DCL tem --fatal-warnings ON por default, então o `analyze` pode sair
#     non-zero mesmo sem --set-exit-on-violation-level. Esse é o comportamento
#     desejado num gate de verificação.
#   - Flutter vs Dart é detectado via grep em pubspec.yaml; o mesmo runner
#     (flutter/dart) é usado de forma consistente para o `test`.

set -uo pipefail

# ----------------------------------------------------------------------------
# Defaults + parse de argumentos
# ----------------------------------------------------------------------------
TARGET="lib"
SKIP_TESTS=0
SKIP_DART_ANALYZE=0

usage() {
  sed -n '2,33p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)
      if [ $# -lt 2 ]; then
        echo "error: --target requer um valor" >&2
        exit 1
      fi
      TARGET="$2"
      shift 2
      ;;
    --target=*)
      TARGET="${1#*=}"
      shift
      ;;
    --skip-tests)
      SKIP_TESTS=1
      shift
      ;;
    --skip-dart-analyze)
      SKIP_DART_ANALYZE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: argumento desconhecido: $1" >&2
      echo "use -h para ver a ajuda" >&2
      exit 1
      ;;
  esac
done

# ----------------------------------------------------------------------------
# Valida e normaliza o target
# ----------------------------------------------------------------------------
# Target vazio (ex.: --target=) analisaria o escopo errado silenciosamente.
if [ -z "$TARGET" ]; then
  echo "error: --target vazio (passe um diretório/arquivo válido)" >&2
  exit 1
fi
# './'-prefix em target com '-' inicial: nunca interpretado como opção.
case "$TARGET" in
  -*) TARGET="./$TARGET" ;;
esac

# ----------------------------------------------------------------------------
# Detecta runner: Flutter (depende de flutter no pubspec) vs Dart puro
# ----------------------------------------------------------------------------
# Mesma regex de dcl-run.sh para classificar o projeto de forma consistente.
RUNNER="dart"
if [ -f pubspec.yaml ]; then
  if grep -qE 'flutter:|sdk:[[:space:]]*flutter' pubspec.yaml; then
    RUNNER="flutter"
  fi
else
  echo "aviso: pubspec.yaml não encontrado no diretório atual; assumindo runner 'dart'. Rode na raiz do projeto Dart/Flutter." >&2
fi

# Resultado por estágio: "PASS", "FAIL" ou "SKIP"
STAGE1_RESULT="SKIP"
STAGE2_RESULT="SKIP"
STAGE3_RESULT="SKIP"
STAGE1_CODE=0
STAGE2_CODE=0
STAGE3_CODE=0

# Falha agregada apenas dos estágios REQUERIDOS
FAILED=0

print_header() {
  echo ""
  echo "==> $1"
}

# ----------------------------------------------------------------------------
# Stage 1 — DCL analyze (sempre requerido)
# ----------------------------------------------------------------------------
print_header "Stage 1/3 — DCL analyze ($TARGET)"
# Reporter console para leitura humana. Alternativa de parsing nos comentários
# do cabeçalho (--reporter=json + parse-dcl-json.py).
dart run dart_code_linter:metrics analyze "$TARGET" --reporter=console
STAGE1_CODE=$?
if [ "$STAGE1_CODE" -eq 0 ]; then
  STAGE1_RESULT="PASS"
else
  STAGE1_RESULT="FAIL"
  FAILED=1
fi

# ----------------------------------------------------------------------------
# Stage 2 — dart analyze (SDK analyzer), pulável
# ----------------------------------------------------------------------------
if [ "$SKIP_DART_ANALYZE" -eq 1 ]; then
  print_header "Stage 2/3 — dart analyze (SKIPPED via --skip-dart-analyze)"
  STAGE2_RESULT="SKIP"
else
  print_header "Stage 2/3 — dart analyze ($TARGET)"
  dart analyze "$TARGET"
  STAGE2_CODE=$?
  if [ "$STAGE2_CODE" -eq 0 ]; then
    STAGE2_RESULT="PASS"
  else
    STAGE2_RESULT="FAIL"
    FAILED=1
  fi
fi

# ----------------------------------------------------------------------------
# Stage 3 — testes (flutter test | dart test), pulável / condicional
# ----------------------------------------------------------------------------
if [ "$SKIP_TESTS" -eq 1 ]; then
  print_header "Stage 3/3 — tests (SKIPPED via --skip-tests)"
  STAGE3_RESULT="SKIP"
elif [ ! -d test ]; then
  print_header "Stage 3/3 — tests (SKIPPED: nenhum diretório test/)"
  STAGE3_RESULT="SKIP"
else
  print_header "Stage 3/3 — tests ($RUNNER test)"
  "$RUNNER" test
  STAGE3_CODE=$?
  if [ "$STAGE3_CODE" -eq 0 ]; then
    STAGE3_RESULT="PASS"
  else
    STAGE3_RESULT="FAIL"
    FAILED=1
  fi
fi

# ----------------------------------------------------------------------------
# Sumário
# ----------------------------------------------------------------------------
echo ""
echo "================ DCL VERIFY SUMMARY ================"
printf '  %-28s %s (exit %s)\n' "Stage 1 DCL analyze"  "$STAGE1_RESULT" "$STAGE1_CODE"
printf '  %-28s %s (exit %s)\n' "Stage 2 dart analyze" "$STAGE2_RESULT" "$STAGE2_CODE"
printf '  %-28s %s (exit %s)\n' "Stage 3 $RUNNER test"  "$STAGE3_RESULT" "$STAGE3_CODE"
echo "==================================================="

if [ "$FAILED" -ne 0 ]; then
  echo "RESULT: FAIL — pelo menos um estágio requerido falhou." >&2
  exit 1
fi

echo "RESULT: PASS — todos os estágios requeridos passaram."
exit 0
