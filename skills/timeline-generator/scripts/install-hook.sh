#!/usr/bin/env bash
# timeline-generator: install/uninstall Claude Code hooks.
#
# Hooks installed:
#   Stop              → after assistant turn, run update.py --auto (idempotent)
#   PostToolUse Edit  → if Edit touched .planning/STATE.md, refresh timeline
#
# Args:
#   --scope project|global   default: project (.claude/settings.json in cwd)
#   --uninstall              remove entries matching the timeline-generator command
#   --out PATH               timeline HTML path passed to update.py
set -euo pipefail

SCOPE="project"
UNINSTALL=false
OUT="docs/timeline.html"
SKILL_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPDATE="$SKILL_ROOT/scripts/update.py"

while [ $# -gt 0 ]; do
  case "$1" in
    --scope)     SCOPE="$2"; shift 2 ;;
    --uninstall) UNINSTALL=true; shift ;;
    --out)       OUT="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ "$SCOPE" = "global" ]; then
  SETTINGS="$HOME/.claude/settings.json"
else
  SETTINGS=".claude/settings.json"
  mkdir -p .claude
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required to install hooks. Install with: brew install jq" >&2
  exit 1
fi

[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

CMD_AUTO="python3 \"$UPDATE\" --auto --out \"$OUT\""
CMD_WATCH="python3 \"$UPDATE\" --watch .planning/STATE.md --out \"$OUT\""

if $UNINSTALL; then
  tmp=$(mktemp)
  jq --arg c1 "$CMD_AUTO" --arg c2 "$CMD_WATCH" '
    .hooks.Stop        = ((.hooks.Stop // []) | map(select(.hooks // [] | all(.command // "" | (. != $c1 and . != $c2)))))
  | .hooks.PostToolUse = ((.hooks.PostToolUse // []) | map(select(.hooks // [] | all(.command // "" | (. != $c1 and . != $c2)))))
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "✓ Hooks removed from $SETTINGS"
  exit 0
fi

tmp=$(mktemp)
jq --arg c1 "$CMD_AUTO" --arg c2 "$CMD_WATCH" '
  .hooks //= {}
| .hooks.Stop //= []
| .hooks.PostToolUse //= []
| if (.hooks.Stop | map(.hooks // [] | map(.command) | flatten) | flatten | index($c1) | not)
    then .hooks.Stop += [{matcher: ".*", hooks: [{type:"command", command:$c1}]}] else . end
| if (.hooks.PostToolUse | map(.hooks // [] | map(.command) | flatten) | flatten | index($c2) | not)
    then .hooks.PostToolUse += [{matcher: "Edit|Write", hooks: [{type:"command", command:$c2}]}] else . end
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"

echo "✓ Hooks installed at $SETTINGS"
echo "  Stop        → $CMD_AUTO"
echo "  PostToolUse → $CMD_WATCH (Edit|Write match)"
