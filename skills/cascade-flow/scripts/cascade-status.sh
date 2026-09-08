#!/usr/bin/env bash
# cascade-status.sh — open PRs grouped into stacked chains.
#
# Usage:
#   cascade-status.sh                      # configured repo(s)
#   cascade-status.sh --ci                 # + CI/mergeable rollup per PR (slower)
#   cascade-status.sh --stacked            # chains + PRs whose base is not default
#   cascade-status.sh --all                # every open PR (default)
#   cascade-status.sh --full               # --stacked --ci; then classify (SKILL.md)
#   cascade-status.sh --repo owner/name    # target repo(s), repeatable
#   cascade-status.sh --help
#
# Repo resolution (first match wins): --repo args → $CASCADE_REPOS (space-separated
# owner/name) → .cascade-repos file at the git root (one owner/name per line) →
# current repo (gh repo view). Requires an authenticated gh + python3.
set -euo pipefail

WITH_CI=0
STACKED_ONLY=0
FULL=0
CLI_REPOS=""
usage() {
  sed -n '2,16p' "$0" | sed 's/^# \?//'
}

while [ $# -gt 0 ]; do
  case "$1" in
    --ci) WITH_CI=1; shift ;;
    --stacked) STACKED_ONLY=1; shift ;;
    --all) STACKED_ONLY=0; shift ;;
    --full) STACKED_ONLY=1; WITH_CI=1; FULL=1; shift ;;
    --help|-h) usage; exit 0 ;;
    --repo)
      if [ -z "${2:-}" ]; then
        echo "error: --repo requires an owner/name argument" >&2
        exit 1
      fi
      CLI_REPOS="$CLI_REPOS $2"
      shift 2 ;;
    *) echo "error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

export GH_COLOR=never
export GH_PAGER=cat
export NO_COLOR=1

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

REPOS=""
if [ -n "${CLI_REPOS// }" ]; then
  REPOS="$CLI_REPOS"
elif [ -n "${CASCADE_REPOS:-}" ]; then
  REPOS="$CASCADE_REPOS"
elif [ -f "$ROOT/.cascade-repos" ]; then
  REPOS="$(grep -vE '^[[:space:]]*(#|$)' "$ROOT/.cascade-repos" | tr '\n' ' ')"
else
  REPOS="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
fi
if [ -z "${REPOS// }" ]; then
  echo "No repos to inspect. Pass --repo owner/name, set \$CASCADE_REPOS, add a" >&2
  echo ".cascade-repos file, or run inside a gh-recognized repo." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

i=0
for slug in $REPOS; do
  i=$((i + 1))
  if ! gh -R "$slug" pr list --state open --limit 100 \
    --json number,title,headRefName,baseRefName,isDraft,mergeable,mergeStateStatus \
    > "$TMP/$i.json"; then
    echo "warn: pr list failed for $slug" >&2
    echo "[]" > "$TMP/$i.json"
  fi
  default="$(gh repo view "$slug" --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo main)"
  echo "$i	$slug	${slug##*/}	$default" >> "$TMP/repos.tsv"
  if [ "$WITH_CI" = "1" ]; then
    while read -r num; do
      [ -n "$num" ] || continue
      gh -R "$slug" pr checks "$num" --json name,conclusion,status \
        > "$TMP/ci-$i-$num.json" 2>/dev/null \
        || echo "warn: ci fetch failed for pr $num ($slug)" >&2
    done < <(python3 -c 'import json,re,sys
raw=open(sys.argv[1],encoding="utf-8").read()
try:
    data=json.loads(raw)
except json.JSONDecodeError:
    data=json.loads(re.sub(r"\x1b\[[0-9;]*m","",raw))
[print(p["number"]) for p in data]' "$TMP/$i.json" 2>/dev/null)
  fi
done

TMPDIR_IN="$TMP" WITH_CI="$WITH_CI" STACKED_ONLY="$STACKED_ONLY" python3 <<'PY'
import json, os, re

tmp = os.environ["TMPDIR_IN"]
with_ci = os.environ["WITH_CI"] == "1"
stacked_only = os.environ["STACKED_ONLY"] == "1"
ANSI = re.compile(r"\x1b\[[0-9;]*m")

def load_json(path):
    raw = open(path, encoding="utf-8").read()
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return json.loads(ANSI.sub("", raw))

repos = []
with open(f"{tmp}/repos.tsv", encoding="utf-8") as fh:
    for ln in fh:
        idx, slug, name, default = ln.rstrip("\n").split("\t")
        repos.append((idx, slug, name, default))

TICKET = re.compile(r"([A-Z]{2,10}-\d+)")
MERGE = {"MERGEABLE": "ok", "CONFLICTING": "conflict", "UNKNOWN": "…"}

def ticket(pr):
    m = TICKET.search(pr["headRefName"]) or TICKET.search(pr["title"])
    return m.group(1) if m else "—"

def ci(idx, num):
    if not with_ci:
        return ""
    try:
        checks = load_json(f"{tmp}/ci-{idx}-{num}.json")
    except (OSError, json.JSONDecodeError):
        return ""
    bad = [c for c in checks if c.get("conclusion") in ("FAILURE", "CANCELLED", "TIMED_OUT")]
    pend = [c for c in checks if c.get("status") != "COMPLETED"]
    if bad:
        return f" · CI fail {len(bad)}"
    if pend:
        return f" · CI …{len(pend)}"
    return " · CI ok" if checks else ""

todo = {"open": 0, "draft": 0, "conflict": 0, "blocked": 0}

print("=" * 66)
for idx, slug, name, default in repos:
    try:
        prs = load_json(f"{tmp}/{idx}.json")
    except (OSError, json.JSONDecodeError):
        prs = []
    heads = {pr["headRefName"]: pr for pr in prs}
    bases = {pr["baseRefName"] for pr in prs if pr["baseRefName"] in heads}

    def in_chain(pr):
        return (
            pr["baseRefName"] in heads
            or pr["headRefName"] in bases
            or pr["baseRefName"] != default
        )

    shown = [pr for pr in prs if (in_chain(pr) if stacked_only else True)]
    if not shown:
        continue
    print(f"\n# {name}  (default: {default})")
    rendered = set()

    def line(pr, depth):
        arrow = ("  " * depth) + ("└→ " if depth else "")
        merge = MERGE.get(pr.get("mergeable", ""), pr.get("mergeable", ""))
        state = pr.get("mergeStateStatus", "")
        st = f" [{state}]" if state and state != "CLEAN" else ""
        draft = " (draft)" if pr.get("isDraft") else ""
        head_slug = pr["headRefName"].split("/")[-1]
        base = pr["baseRefName"]
        base_disp = f"#{heads[base]['number']}" if base in heads else base
        t = ticket(pr)
        print(f"  {arrow}#{pr['number']}  {t:<9} {head_slug:<34} → {base_disp}")
        print(f"  {'  ' * depth}     {merge}{st}{draft}{ci(idx, pr['number'])}")
        todo["open"] += 1
        if pr.get("isDraft"):
            todo["draft"] += 1
        if pr.get("mergeable") == "CONFLICTING":
            todo["conflict"] += 1
        if state == "BLOCKED":
            todo["blocked"] += 1
        rendered.add(pr["number"])
        for child in prs:
            if child["baseRefName"] == pr["headRefName"] and child["number"] not in rendered:
                line(child, depth + 1)

    for r in sorted((p for p in shown if p["baseRefName"] not in heads), key=lambda p: p["number"]):
        line(r, 0)
    for pr in shown:
        if pr["number"] not in rendered:
            line(pr, 0)

print("\n" + "=" * 66)
print(" What's left")
bits = [f"{todo['open']} open PR(s)"]
if todo["conflict"]:
    bits.append(f"{todo['conflict']} with conflicts")
if todo["blocked"]:
    bits.append(f"{todo['blocked']} blocked")
if todo["draft"]:
    bits.append(f"{todo['draft']} draft")
print(" PRs: " + ", ".join(bits) + " — merge bottom-up (trunk-rooted first).")
PY

if [ "$FULL" = "1" ]; then
  cat <<'EOF'

==================================================================
 Full mode — classify review-state (see SKILL.md)
==================================================================
 For each open PR: reviewDecision + unresolved reviewThreads.
 Bucket: ready to merge | needs review | needs resolve | close.
 Present the tree tagged with buckets, then the four action lists.
 Merge the root first. This script does not merge.
EOF
fi
