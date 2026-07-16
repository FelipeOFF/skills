# render-plans-to-html

> Tool-agnostic renderer that turns Markdown plans, specs and reviews into a single self-contained interactive HTML dashboard.
>
> 🇧🇷 [Versão em Português](./README.pt-BR.md)

Works with output from [GSD](https://github.com/), [Superpowers](https://github.com/), Ralph Specum, HopLoop, or any plain `.md` file. Produces one offline-capable HTML file with sidebar navigation, status pills, severity tags, mermaid diagrams, syntax highlighting, search, and dark/light themes.

## Features

- **Multi-doc dashboard** — feed it a folder and get one navigable surface.
- **Auto-classifier** — detects PLAN / REVIEW / REQUIREMENTS / tasks / RESEARCH / design / verification / generic by filename and content heuristics.
- **Status pills** — `- [ ]` / `- [x]` checkboxes become pills with `done/total` metric per doc.
- **Severity tags** — `**CRITICAL**`, `**HIGH**`, `**MEDIUM**`, `**LOW**` rendered as colored counters.
- **Mermaid diagrams** — fenced ` ```mermaid ` blocks render live (vendored mermaid).
- **Syntax highlight** — vendored highlight.js with stable theme.
- **Dark / light theme** — toggle persisted in `localStorage`.
- **Copy as prompt** — copies the active doc back as plain text for re-prompting an LLM.
- **Self-contained output** — single `.html` with all CSS and JS inlined. No external network at runtime.
- **Available as a skill** for both [Claude Code](https://claude.com/claude-code) and Codex.

## Quickstart — zero install

Run the renderer directly via `npx` (no install needed):

```bash
npx --yes render-plans-to-html docs/ --out plans.html
```

That is also exactly how the skill invokes itself when an agent decides to render. The first call downloads the package (~800 KB) into the npm cache; subsequent calls are instant.

## Install as a skill (Claude Code and/or Codex)

For agents to discover the skill by description (so the user can just say "render this plan to HTML"), register it once into the agent's skills directory:

```bash
npx render-plans-to-html-install              # auto-detect ~/.claude and/or ~/.agents
npx render-plans-to-html-install --claude     # Claude Code only
npx render-plans-to-html-install --codex      # Codex only
npx render-plans-to-html-install --all        # install to both
npx render-plans-to-html-install --uninstall  # remove
```

Or straight from GitHub:

```bash
npx --package=github:FelipeOFF/render-plans-to-html -- render-plans-to-html-install --all
```

The installer copies the SKILL.md and CLI to the agent's skills directory, runs `npm install --omit=dev`, and symlinks `render-plans` into `~/.local/bin`.

| Agent | Skills directory |
|-------|------------------|
| Claude Code | `~/.claude/skills/render-plans-to-html` |
| Codex | `~/.agents/skills/render-plans-to-html` |

Both can be overridden via `CLAUDE_SKILLS_DIR` and `CODEX_SKILLS_DIR` environment variables.

## v0.2 dashboard flags

| Flag | Default | Purpose |
|------|---------|---------|
| `--lang` | auto-detect | Force UI language: `pt-BR`, `en`, `es` |
| `--default-agent` | `sonnet` | Agent shown in headline cards (`opus`/`sonnet`/`haiku`/`codex`) |
| `--seconds-per-step-{small,medium,large}` | 30 / 60 / 120 | ETA seconds per step bucket |
| `--tokens-per-step-{small,medium,large}` | 1500 / 3500 / 8000 | Token estimate per step bucket |
| `--price-{agent}-{in,out}` | bundled defaults | Override USD/M tokens per agent |
| `--burndown-commits` | 12 | Commits per file scanned for the burndown timeline |
| `--config <file>` | — | JSON file with the same keys as the flags |

## Local development

```bash
git clone https://github.com/FelipeOFF/render-plans-to-html.git
cd render-plans-to-html
npm install
node bin/render-plans.js docs/ --out plans.html
```

| Agent | Skills directory |
|-------|------------------|
| Claude Code | `~/.claude/skills/render-plans-to-html` |
| Codex | `~/.agents/skills/render-plans-to-html` |

Both can be overridden via `CLAUDE_SKILLS_DIR` and `CODEX_SKILLS_DIR` environment variables.

## Usage

```bash
npx --yes render-plans-to-html <path>[,path2,...] [--out output.html] [--title "Phase v1.9"] [--theme dark]
```

`<path>` accepts:

- a single `.md` file,
- a folder (recursive `*.md` discovery),
- a comma-separated list of paths.

### Examples

```bash
# Single plan
npx --yes render-plans-to-html docs/plan.md --out plan.html

# Whole phase folder
npx --yes render-plans-to-html .planning/phase-3 --out phase-3.html --title "Phase 3"

# Mixed list
npx --yes render-plans-to-html PLAN.md,REVIEW.md,RESEARCH.md --out review.html
```

## Requirements

- Node.js ≥ 20
- npm

## Project layout

```
src/
  cli.js        # arg parsing + orchestration
  discover.js   # path resolution
  classify.js   # doc-type heuristics
  extract.js    # signals (checkboxes, severity, toc, refs, mermaid)
  render.js     # marked → HTML body
  template.js   # HTML shell with inlined assets
  assemble.js   # multi-doc HTML composition
  assets/       # styles, client JS, vendored hljs and mermaid
bin/
  render-plans.js  # renderer entrypoint (npx render-plans-to-html)
  install.js       # optional installer (npx render-plans-to-html-install)
skill/
  SKILL.md         # skill manifest (Claude Code / Codex)
tests/             # vitest suites
```

## Development

```bash
npm test            # run the full vitest suite
npm run test:watch  # watch mode
```

## License

MIT
