# Felipe's Skills

A single home for all my agent skills — centralized so everything installs the same way, from one place. Built to work with **Claude Code, Codex, OpenCode, Cursor**, and every other agent supported by the open [`skills`](https://github.com/vercel-labs/skills) ecosystem.

## Catalog

| Skill | What it does | Docs |
| ----- | ------------ | ---- |
| [`groom-me`](./skills/groom-me/) | Auto-runs a **non-technical grooming interview** to confirm intended behavior *before* any business-rule change. | [Read →](./skills/groom-me/README.md) |

_More skills land here over time — this repo is where they all live._

## Install

Everything installs through the [`skills`](https://github.com/vercel-labs/skills) CLI via `npx` — no clone, no global setup required.

```bash
# See every skill in this repo first
npx skills add FelipeOFF/skills --list

# Install one by name
npx skills add FelipeOFF/skills --skill=<skill-name>
```

More ways to install:

```bash
# Globally, so it's available in every project
npx skills add FelipeOFF/skills --skill=<skill-name> --global

# Only on specific agents, non-interactively
npx skills add FelipeOFF/skills --skill=<skill-name> -a claude-code -a codex -y

# Update or remove later
npx skills update <skill-name>
npx skills remove <skill-name>
```

Each skill's own page (the **Docs** column above) carries its detailed write-up and skill-specific examples.

## Repository structure

```
skills/
  <skill-name>/
    SKILL.md     # the skill itself — frontmatter (name + description) + instructions
    README.md    # detailed docs for that skill (optional, for GitHub browsing)
```

Adding a new skill is just a new folder under `skills/` with a `SKILL.md`. The `npx skills` CLI discovers it automatically by its `name` — no index or registry to maintain.

## License & credits

MIT — see [LICENSE](./LICENSE). Individual skills credit their origins on their own page (for example, [`groom-me`](./skills/groom-me/README.md) derives from Matt Pocock's `grilling` / `grill-me`).
