#!/usr/bin/env python3
"""parse-dcl-json.py — achata o JSON do `analyze` do DCL numa lista priorizada.

Esta é a etapa 3 (Step 3 — parse the output) do SKILL.md: transforma o JSON do
reporter `json` do dart_code_linter (gerado por
`dart run dart_code_linter:metrics analyze lib --reporter=json` ou pelo wrapper
`scripts/dcl-run.sh`) numa lista plana de violações, ordenada por prioridade,
fácil de ler por humano ou agente.

Fontes de violação em cada `records[]` (LintFileReport):
  - issues[]            -> kind=rule         (campo de id: ruleId)
  - antiPatternCases[]  -> kind=anti-pattern (campo de id: ruleId)
  - fileMetrics[],
    classes{}.metrics[],
    functions{}.metrics[] onde level != "none" -> kind=metric (id: metricsId)

ATENÇÃO — linhas/colunas 0-based: o DCL usa source_span (SourceLocation), cujos
line/column são 0-BASED. Este script SOMA +1 a line e column para casar com a
exibição 1-based de editores. Off-by-one clássico — já corrigido aqui.

Saída de texto, uma linha por violação:
  PATH:LINE:COL  [SEV/LEVEL]  ID  — MESSAGE   (+ " (auto-fixable)" se houver fix)
Depois, um resumo: total + contagem por severidade/level + quantas auto-fixable.

Uso:
  python3 scripts/parse-dcl-json.py /tmp/dcl.json
  dart run dart_code_linter:metrics analyze lib --reporter=json | \
      python3 scripts/parse-dcl-json.py -
"""

import argparse
import json
import sys

# Rank de prioridade (menor = mais urgente). Mistura a enum Severity de
# rules/issues (error, warning, performance, style, none) com a enum
# MetricValueLevel de metrics (none, noted, warning, alarm).
# Ordem pedida: error > alarm > warning(rule) ~ warning(level) > performance
#               > noted > style > none.
PRIORITY = {
    "error": 0,
    "alarm": 1,
    "warning": 2,  # cobre tanto Severity.warning (rule) quanto level=warning (metric)
    "performance": 3,
    "noted": 4,
    "style": 5,
    "none": 6,
}

# Ordem estável usada no resumo (todas as chaves conhecidas das duas enums).
SUMMARY_ORDER = ["error", "alarm", "warning", "performance", "noted", "style", "none"]


def _rank(key):
    """Rank de prioridade de uma severity/level; desconhecidos vão pro fim.

    Robusto a chaves não-hashable / não-str vindas de JSON malformado
    (ex.: severity/level como lista ou objeto): caem para o fim.
    """
    if not isinstance(key, str):
        return len(PRIORITY)
    return PRIORITY.get(key, len(PRIORITY))


def _as_str(value):
    """Coage um campo a str (ou None).

    JSON malformado pode trazer int/list/dict onde se espera string (path,
    ruleId, metricsId, severity, level). Normalizamos para str para manter
    sort e uso como chave de dict estáveis; None é preservado.
    """
    if value is None or isinstance(value, str):
        return value
    return str(value)


def _loc(code_span):
    """Extrai (line, column) 1-based de um codeSpan, somando +1 ao 0-based do DCL.

    Robusto a codeSpan/start ausentes ou não-dict.
    """
    if not isinstance(code_span, dict):
        return None, None
    start = code_span.get("start")
    if not isinstance(start, dict):
        return None, None
    line = start.get("line")
    column = start.get("column")
    line = line + 1 if isinstance(line, int) else None
    column = column + 1 if isinstance(column, int) else None
    return line, column


def _has_fix(issue):
    """True se o issue traz sugestões de correção não-vazias (suggestions[])."""
    suggestions = issue.get("suggestions")
    return bool(isinstance(suggestions, list) and len(suggestions) > 0)


def _collect_issues(record, path, issue_list, kind):
    """Achata issues[] (rule) ou antiPatternCases[] (anti-pattern)."""
    out = []
    if not isinstance(issue_list, list):
        return out
    for issue in issue_list:
        if not isinstance(issue, dict):
            continue
        line, column = _loc(issue.get("codeSpan"))
        # Coerção defensiva: severity/id podem vir não-string em JSON malformado.
        severity = _as_str(issue.get("severity"))
        out.append(
            {
                "path": path,
                "line": line,
                "column": column,
                "kind": kind,
                "id": _as_str(issue.get("ruleId")),
                # issues usam `severity` (a enum Severity de rules).
                "severity": severity,
                "level": None,
                "rank_key": severity,
                "message": issue.get("message"),
                "has_fix": _has_fix(issue),
            }
        )
    return out


def _collect_metrics(record, path, metric_list, entity_span=None):
    """Achata uma lista de MetricValue, mantendo só level != 'none'.

    MetricValue não carrega codeSpan próprio: a localização vem da entidade
    (classe/função) que a contém. Passamos `entity_span` para que violações de
    métrica apontem a linha da função/classe. fileMetrics não têm entidade
    (nível de arquivo), então ficam sem line/column.
    """
    out = []
    if not isinstance(metric_list, list):
        return out
    entity_line, entity_column = _loc(entity_span)
    for metric in metric_list:
        if not isinstance(metric, dict):
            continue
        # Coerção defensiva: level/id podem vir não-string em JSON malformado.
        level = _as_str(metric.get("level"))
        if level == "none" or level is None:
            continue
        out.append(
            {
                "path": path,
                "line": entity_line,
                "column": entity_column,
                "kind": "metric",
                "id": _as_str(metric.get("metricsId")),
                "severity": None,
                "level": level,
                "rank_key": level,
                "message": metric.get("comment"),
                "has_fix": False,  # métricas/anti-patterns não são auto-fixable
            }
        )
    return out


def _iter_entity_metrics(entities, path):
    """Achata metrics[] de um dict de classes{} ou functions{}."""
    out = []
    if not isinstance(entities, dict):
        return out
    for entity in entities.values():
        if not isinstance(entity, dict):
            continue
        out.extend(
            _collect_metrics(
                None, path, entity.get("metrics"), entity.get("codeSpan")
            )
        )
    return out


def collect_violations(data):
    """Percorre records[] e devolve a lista plana de violações."""
    violations = []
    if not isinstance(data, dict):
        return violations
    records = data.get("records")
    if not isinstance(records, list):
        return violations
    for record in records:
        if not isinstance(record, dict):
            continue
        path = _as_str(record.get("path"))
        violations.extend(
            _collect_issues(record, path, record.get("issues"), "rule")
        )
        violations.extend(
            _collect_issues(
                record, path, record.get("antiPatternCases"), "anti-pattern"
            )
        )
        violations.extend(_collect_metrics(record, path, record.get("fileMetrics")))
        violations.extend(_iter_entity_metrics(record.get("classes"), path))
        violations.extend(_iter_entity_metrics(record.get("functions"), path))
    return violations


def sort_violations(violations):
    """Ordena por prioridade; empata por path, depois line, depois id."""
    return sorted(
        violations,
        key=lambda v: (
            _rank(v.get("rank_key")),
            v.get("path") or "",
            v.get("line") if v.get("line") is not None else 1 << 30,
            v.get("column") if v.get("column") is not None else 1 << 30,
            v.get("id") or "",
        ),
    )


def filter_violations(violations, kind=None, fixable_only=False):
    """Aplica os filtros --kind e --fixable-only."""
    out = violations
    if kind:
        out = [v for v in out if v.get("kind") == kind]
    if fixable_only:
        out = [v for v in out if v.get("has_fix")]
    return out


def _sev_or_level(v):
    """Rótulo a exibir no campo [SEV/LEVEL]: severity (issues) ou level (metrics).

    Backstop: garante str hashable mesmo se a coerção de coleta for contornada.
    """
    label = v.get("severity") or v.get("level") or "none"
    return label if isinstance(label, str) else "none"


def format_text_line(v):
    """Formata uma violação na linha de texto humana/agent-friendly."""
    line = v.get("line")
    column = v.get("column")
    line_s = str(line) if line is not None else "?"
    col_s = str(column) if column is not None else "?"
    label = _sev_or_level(v)
    vid = v.get("id") or "?"
    message = v.get("message") or ""
    suffix = " (auto-fixable)" if v.get("has_fix") else ""
    return (
        f"{v.get('path') or '?'}:{line_s}:{col_s}  "
        f"[{label}]  {vid}  — {message}{suffix}"
    )


def build_summary(violations):
    """Conta total, por severity/level e quantas auto-fixable."""
    counts = {}
    fixable = 0
    for v in violations:
        key = _sev_or_level(v)
        counts[key] = counts.get(key, 0) + 1
        if v.get("has_fix"):
            fixable += 1
    return {"total": len(violations), "counts": counts, "fixable": fixable}


def print_text(violations):
    """Imprime a lista plana + o bloco de resumo em texto."""
    for v in violations:
        print(format_text_line(v))

    summary = build_summary(violations)
    print("")
    print(f"Summary: {summary['total']} violation(s)")

    # Contagens em ordem estável conhecida; extras desconhecidos no fim.
    counts = summary["counts"]
    ordered = [k for k in SUMMARY_ORDER if k in counts]
    extra = sorted(k for k in counts if k not in SUMMARY_ORDER)
    for key in ordered + extra:
        print(f"  {key}: {counts[key]}")
    print(f"  auto-fixable: {summary['fixable']}")


def to_json_array(violations):
    """Projeta as violações para o array JSON machine-readable (--json)."""
    return [
        {
            "path": v.get("path"),
            "line": v.get("line"),
            "column": v.get("column"),
            "kind": v.get("kind"),
            "id": v.get("id"),
            "severity": v.get("severity"),
            "level": v.get("level"),
            "message": v.get("message"),
            "has_fix": bool(v.get("has_fix")),
        }
        for v in violations
    ]


def load_input(path_arg):
    """Lê o JSON de argv[1] (arquivo) ou de stdin quando '-' ou ausente."""
    if path_arg in (None, "-"):
        raw = sys.stdin.read()
    else:
        with open(path_arg, "r", encoding="utf-8") as handle:
            raw = handle.read()
    return json.loads(raw)


def build_arg_parser():
    parser = argparse.ArgumentParser(
        prog="parse-dcl-json.py",
        description=(
            "Achata o JSON do `analyze` do dart_code_linter numa lista de "
            "violacoes priorizada. Le argv[1] (arquivo) ou stdin quando '-' "
            "ou omitido. NOTA: line/column do DCL sao 0-based (source_span); "
            "este script SOMA +1 para casar com editores 1-based."
        ),
    )
    parser.add_argument(
        "input",
        nargs="?",
        default="-",
        help="Caminho do JSON do DCL, ou '-' / omitido para ler de stdin.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emite um array JSON machine-readable em vez de texto.",
    )
    parser.add_argument(
        "--fixable-only",
        action="store_true",
        help="Mostra apenas violacoes auto-fixable (issue com suggestions).",
    )
    parser.add_argument(
        "--kind",
        choices=["rule", "metric", "anti-pattern"],
        default=None,
        help="Filtra por tipo de violacao: rule | metric | anti-pattern.",
    )
    return parser


def main(argv=None):
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    data = None
    try:
        data = load_input(args.input)
    except FileNotFoundError:
        print(f"error: input file not found: {args.input}", file=sys.stderr)
        # Reporter: sempre sai 0; sem dados, sem violações.
    except (json.JSONDecodeError, ValueError) as exc:
        print(f"error: could not parse JSON: {exc}", file=sys.stderr)
    except OSError as exc:
        print(f"error: could not read input: {exc}", file=sys.stderr)
    except Exception as exc:  # noqa: BLE001 — backstop p/ RecursionError etc.
        # Ex.: JSON profundamente aninhado dispara RecursionError (subclasse de
        # RuntimeError, não de ValueError). Um reporter nunca pode quebrar.
        print(f"error: could not load input: {exc}", file=sys.stderr)

    # Pipeline com backstop: nenhum dado malformado-mas-válido derruba o
    # reporter. As coerções em _as_str/_rank já cobrem o caso normal; este
    # try é a última linha de defesa do contrato "sempre exit 0".
    try:
        violations = collect_violations(data) if data is not None else []
        violations = filter_violations(
            violations, kind=args.kind, fixable_only=args.fixable_only
        )
        violations = sort_violations(violations)

        if args.json:
            print(json.dumps(to_json_array(violations), ensure_ascii=False, indent=2))
        else:
            print_text(violations)
    except Exception as exc:  # noqa: BLE001 — reporter nunca quebra
        print(f"error: could not process violations: {exc}", file=sys.stderr)
        if args.json:
            print("[]")
        else:
            print("")
            print("Summary: 0 violation(s)")
            print("  auto-fixable: 0")

    # Sempre exit 0 — é um reporter, não um gate.
    return 0


if __name__ == "__main__":
    sys.exit(main())
