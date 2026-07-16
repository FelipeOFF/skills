---
name: timeline-generator
description: Generates and maintains a live drag-and-drop Gantt HTML timeline from any task source (Jira URL, Linear, GSD .planning/, plain text list). Supports daily granularity, today-marker auto-positioned, current/next/done task panels, drag-to-reorder cards, drag-to-move + resize bars with tooltip, localStorage drag overrides with import/export, --hook flag installs Claude Code hooks for auto-update on phase completion or file edits, --redesign flag delegates visual refinement to ui-ux-pro-max subagent. Use when user asks to visualize tasks/roadmap on a timeline, build a Gantt chart, see what is in execution now, or maintain a living project timeline.
---

# timeline-generator

Generates a single self-contained HTML file with an interactive Gantt timeline. Lives as a project artifact and updates automatically as work progresses.

## Inputs supported

| Source | Form | Example |
|---|---|---|
| GSD project | auto-detect `.planning/` in cwd | `/timeline-generator` |
| Jira | URL or issue key (epic discovers children) | `/timeline-generator https://x.atlassian.net/browse/PROJ-100` |
| Linear | URL or issue key | `/timeline-generator linear.app/team/issue/ABC-1` |
| Manual list | paragraph or bulleted text | pasted in chat |
| JSON | structured schema (see `examples/schema.json`) | `/timeline-generator data.json` |

## Flags

| Flag | Effect |
|---|---|
| `--hook` | Install Claude Code hooks (Stop + PostToolUse on `.planning/STATE.md`) that auto-call `update.py` |
| `--hook --uninstall` | Remove installed hooks |
| `--redesign` | Delegate visual to `ui-ux-pro-max` subagent before writing template |
| `--regen` | Full regen ignoring previous output (drag overrides preserved in localStorage) |
| `--update "<msg>"` | Apply explicit progress note ("PROJ-N done", "PR #N merged", "Phase N complete") |
| `--out <path>` | Output HTML location (default: `docs/timeline.html`) |
| `--days <N>` | Force timeline length in days (default: derived from tasks + 10% buffer) |
| `--config` | Agent-driven setup. The skill MUST ask the user via `AskUserQuestion` (one prompt per field) for JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN, LINEAR_API_KEY, then persist each non-empty answer via `python3 scripts/config.py set KEY=VAL` (mode 0600, gitignored). Do NOT shell out to `config.py init` (that requires stdin and won't work inside an agent session). |
| `--config show` | Print resolved config (env > config.json), masks tokens |
| `--config set KEY=VAL` | Set one or more keys non-interactively |

## Workflow

When invoked:

0. **`--config` short-circuit.** If `--config` is the only arg, run the agent-driven Q&A loop:
   - For each `KEY` in `[JIRA_BASE_URL, JIRA_EMAIL, JIRA_API_TOKEN, LINEAR_API_KEY]`, call `AskUserQuestion` with the current resolved value (masked for tokens) as hint and "leave blank to skip" as an option.
   - Persist each non-empty answer by shelling out to `python3 scripts/config.py set KEY=VAL` (one call per key, or batched).
   - Print final `python3 scripts/config.py show` to confirm.
   - Exit. Do NOT proceed to render a timeline in this mode.

1. **Parse args.** If no source given and cwd has `.planning/`, default to GSD adapter. Else `AskUserQuestion` for source.

2. **Time window.** If not derivable from source (Jira due dates, GSD phases), ask user for start date + duration in days. Default start = today.

3. **Adapter dispatch.** Run `adapters/<source>.py` → normalized `Schema` (see `examples/schema.json`). Schema validation step.

   **Auth fallback for Jira/Linear sources:** if the adapter raises `RuntimeError` because credentials are missing (no env var AND no `config.json` entry), the calling agent MUST:
     - Ask the user via `AskUserQuestion` for the missing fields (Jira: BASE_URL+EMAIL+TOKEN; Linear: API_KEY).
     - Persist them by calling `python3 scripts/config.py set KEY=VAL ...` (writes `config.json` with mode 0600 inside the skill folder).
     - Re-run the adapter.
   - The agent must NEVER hardcode credentials into the schema or commit `config.json` to any repo.

4. **Lane inference — MANDATORY before render.**

   The agent MUST identify the platforms/frentes/teams that the tasks span. Each lane represents one such concern (frontend, backend, infra, mobile SDK, design, QA, marketing, etc.).

   Rules:
   - If source already encodes lanes (`#lane-tag` in manual, `assignee` field in Jira/Linear) → use it directly, ask user only to confirm names.
   - If source is ambiguous (plain text list, vague descriptions) → the agent MUST ask the user via `AskUserQuestion`:
     - "Quais plataformas / frentes essas tarefas tocam?" (max 4 multi-select options inferred + "Outras")
     - "Como você quer separar as lanes? (por equipe, por tecnologia, por fase, único lane)"
   - **Never invent lanes** with names like "Tarefas gerais" or "Trabalho 1" if the agent doesn't know — ask the user.

5. **Allocation rules — NO OVERLAPS.**

   When the adapter splits a list of N tasks across `total_days`:
   - Within the same lane, bars MUST NOT overlap (`bar_a.span[1] <= bar_b.span[0]` or vice versa).
   - The default GSD/manual/Jira/Linear adapters assign sequential non-overlapping slots automatically via cursor advancement.
   - If a custom JSON schema is provided with overlapping spans → emit a warning and request the user fix it before rendering. Do NOT silently render overlapping bars.
   - If parallel work is intentional → put it in a separate lane.

5. **Render decision.**
   - Default: invoke `scripts/generate.py` with `template/timeline.html.template`.
   - If `--redesign`: invoke `Skill('ui-ux-pro-max')` with current template + schema. Subagent iterates visual; writes back template variant.

6. **Write HTML.** Self-contained file (CSS+JS inlined). Inline `<script id="timeline-data" type="application/json">` carries data.

7. **Hook install (if `--hook`).** `scripts/install-hook.sh` adds entries to `.claude/settings.json` (project) or `~/.claude/settings.json` (global, ask user).

8. **Print path + open hint.** Format: `file://<absolute-path>` — user opens in browser.

## Update protocol

When user says "phase N complete", "PROJ-N done", "PR #N merged", or hook fires:

1. Read existing HTML, parse inline JSON.
2. Apply patch: status change, span change, new task, removal.
3. Bump `meta.updated_at` timestamp.
4. Rewrite only the `<script id="timeline-data">` block (preserves drag overrides in localStorage on reload).

`scripts/update.py --auto` polls `.planning/STATE.md` mtime + asks `gh pr view` for PR merged status when GSD source.

## Live HTML features (built into template)

- **Today marker.** Vertical golden line auto-positioned via `new Date()` − `meta.base_date`. Updates on page load.
- **Bottom panel.** 3 sections:
  - 🔥 *Em execução agora* — bars where `start ≤ today < end`
  - 📋 *Próximas* — bars where `start > today`, sorted by start
  - ✅ *Concluídas* — bars where `end ≤ today` OR `status: done`
- **Drag-to-reorder** milestone cards (HTML5 DnD).
- **Drag-to-move + resize** Gantt bars (mousedown + day-snap, tooltip with date + weekday + duration).
- **Reset / Export / Import** buttons top-right of timeline.
- **Persistence.** Drag changes → `localStorage` keyed by bar `id`. Export downloads JSON; Import accepts paste or file picker.

## Daily granularity

Grid uses `repeat(<TOTAL_DAYS>, 1fr)`. `TOTAL_DAYS` is dynamic (from `meta.total_days`). Week headers (S1, S2, …) are visual only; snap operates per day.

## File layout

```
timeline-generator/
├── SKILL.md                    (this file)
├── README.md                   (user-facing docs, examples)
├── template/
│   ├── timeline.html.template  (base HTML with {{placeholders}})
│   └── timeline.js             (drag + today marker + import/export + bottom panel)
├── scripts/
│   ├── generate.py             (orchestrator: adapter → render → write)
│   ├── update.py               (incremental patch + --auto detection)
│   └── install-hook.sh         (Claude Code hook installer)
├── adapters/
│   ├── gsd.py                  (.planning/STATE.md + ROADMAP.md → Schema)
│   ├── jira.py                 (URL/epic key → Schema; uses gh-style auth env or MCP if present)
│   ├── linear.py               (URL/issue → Schema; LINEAR_API_KEY env)
│   └── manual.py               (text list → Schema)
└── examples/
    └── schema.json             (canonical data shape)
```

## Schema (canonical, see examples/schema.json)

```json
{
  "meta": {
    "title": "string",
    "subtitle": "string",
    "base_date": "YYYY-MM-DD",
    "total_days": 70,
    "updated_at": "ISO-8601",
    "milestones": [
      {"id":"m0","label":"V0","color":"#38bdf8","span":[1,8]}
    ]
  },
  "lanes": [
    {
      "id":"backend","label":"Backend","color":"#38bdf8",
      "bars": [
        {
          "id":"bar-id","label":"PROJ-N label","span":[1,8],
          "milestone":"m0","status":"in-progress|done|pending|blocked|in-review",
          "links":[{"label":"PROJ-N","url":"https://..."}]
        }
      ]
    }
  ],
  "pins": [
    {"day":1,"label":"S1","tone":"red","text":"Assign owner + kick-off"}
  ]
}
```

## Fit-on-screen guidance for the calling agent

The HTML template is dense by default (compact paddings, ~46px lane height, ~36px bar min-height) so a typical 5-lane × 70-day Gantt fits within a single 1080p viewport without vertical scroll. Beyond that, the calling agent SHOULD:

- Keep lanes ≤ 6. Prefer merging two thin lanes (e.g. "Infra" + "DevOps" → "Infra/DevOps") over adding a 7th.
- Keep bars per lane ≤ 8. If more, group sequential bars into a single "phase" bar with sub-tasks listed in its description (links).
- Trim labels to ≤ 50 chars. Auto-fit JS will clamp to 1-3 lines based on width, but verbose labels still consume vertical space.
- Pins ≤ 5. Pins-wrap is fixed 76px height; more pins compress badly.
- Bottom panel auto-folds to 1 column on narrow screens — no action needed.

When the user asks "deixe fit na tela" or "sem scroll", the agent should reduce content density (fewer lanes/bars), NOT scale CSS. The template already prioritizes density.

## Anti-patterns

- Do NOT hardcode project names. Always parameterize via Schema.
- Do NOT call `ui-ux-pro-max` unless user passes `--redesign`. Default template is enough.
- Do NOT regenerate HTML if no data changed; emit "no-op" message.
- Do NOT remove localStorage overrides on regen — they live client-side.
- Do NOT invent generic lane names ("Tarefas", "Geral", "Trabalho"). Ask the user which platforms/frentes the work touches.
- Do NOT emit overlapping spans in the same lane. `validate_schema` will reject the render.

## Error handling

- Source unreachable (Jira 401, file not found): bail with actionable hint.
- Schema validation failure: print first failing path + expected type.
- Hook collision: detect existing entry, ask before overwriting.

## Token efficiency

Template is large (~1000 lines HTML+JS). Skill body itself stays slim. `scripts/generate.py` does string replacement on template — no LLM call needed for default render. LLM only engaged for adapter parsing of free-form text (manual.py) and `--redesign`.
