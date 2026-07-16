# Felipe's Skills

A single home for all my agent skills — centralized so everything installs the same way, from one place. Built to work with **Claude Code, Codex, OpenCode, Cursor**, and every other agent supported by the open [`skills`](https://github.com/vercel-labs/skills) ecosystem.

**23 skills**, installable one by one — you only ever load what the current task needs.

## Catalog

### Business & product
| Skill | What it does |
| ----- | ------------ |
| [`groom-me`](./skills/groom-me/) | A **non-technical grooming interview** that confirms intended behavior *before* any business-rule change. |

### Frontend & design
| Skill | What it does |
| ----- | ------------ |
| [`ant-design`](./skills/ant-design/) | Build consistent React UIs with Ant Design (antd) — layout, forms, tables, theming. |
| [`design-advisor`](./skills/design-advisor/) | Industry-specific UI/UX recommendations (550+ rules, palettes, font pairings) before you build. |
| [`frontend-project-style`](./skills/frontend-project-style/) | A configurable design system and style guide for any frontend project. |

### Flutter
| Skill | What it does |
| ----- | ------------ |
| [`absolute-flutter`](./skills/absolute-flutter/) | Scaffold and refactor Flutter apps into a layered clean architecture (rx_notifier MVVM, use cases, dio, get_it, drift, go_router). |

### Code quality & review
| Skill | What it does |
| ----- | ------------ |
| [`n-plus-one-guard`](./skills/n-plus-one-guard/) | Detect and prevent N+1 queries and redundant calls within the same request. |
| [`race-condition-guard`](./skills/race-condition-guard/) | Catch and prevent race conditions in concurrent code (TOCTOU, lost update, double-submit). |
| [`dart-code-linter`](./skills/dart-code-linter/) | Find and auto-fix Dart/Flutter code-quality issues with `dart_code_linter` (DCL). |
| [`sonarqube-analyzer`](./skills/sonarqube-analyzer/) | Analyze a self-hosted SonarQube, fetch issues, and suggest automated fixes. |
| [`pr-autopilot`](./skills/pr-autopilot/) | Orchestrate the full PR lifecycle — creation, multi-agent review, fixes, CI polling, auto-merge. |

### Docs & planning
| Skill | What it does |
| ----- | ------------ |
| [`render-plans-to-html`](./skills/render-plans-to-html/) | Render Markdown plans, specs, and reviews into one self-contained interactive HTML dashboard. |
| [`timeline-generator`](./skills/timeline-generator/) | Build and maintain a live drag-and-drop Gantt HTML timeline from any task source (Jira, Linear, GSD, plain text). |
| [`md-to-pdf`](./skills/md-to-pdf/) | Convert Markdown files to styled PDF with theme support. |

### Automation & infra
| Skill | What it does |
| ----- | ------------ |
| [`obscura`](./skills/obscura/) | Web scraping, headless browser automation, and E2E tests from your agent. |
| [`stripe-cli`](./skills/stripe-cli/) | Stripe CLI for local dev — webhook testing, fixture events, API inspection, sandbox resources. |

### sleepwell — autonomous overnight loop
Eight skills that work together to run an autonomous, self-correcting loop while you sleep.

| Skill | What it does |
| ----- | ------------ |
| [`sleepwell-loop`](./skills/sleepwell-loop/) | Start or continue the autonomous sleepwell loop. |
| [`sleepwell-modes`](./skills/sleepwell-modes/) | The four operation modes — tidy, refine, build, radical. |
| [`sleepwell-evaluator`](./skills/sleepwell-evaluator/) | Heuristically evaluate each iteration and course-correct. |
| [`sleepwell-meta`](./skills/sleepwell-meta/) | Calibrate a run from previous runs during bootstrap. |
| [`sleepwell-profile`](./skills/sleepwell-profile/) | Extract and update the user's voice profile from runtime transcripts. |
| [`sleepwell-team`](./skills/sleepwell-team/) | Multi-agent PR workflow — implement → PR → review → fix → CI → merge. |
| [`sleepwell-ci-monitor`](./skills/sleepwell-ci-monitor/) | Check CI status on each wake and persist a sentinel. |
| [`sleepwell-telemetry`](./skills/sleepwell-telemetry/) | Collect tokens and cost with multi-LLM detection. |

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

Each skill's own folder (linked in the catalog) carries its detailed write-up, bundled scripts, and skill-specific examples.

## Repository structure

```
skills/
  <skill-name>/
    SKILL.md     # the skill itself — frontmatter (name + description) + instructions
    README.md    # detailed docs for that skill (optional, for GitHub browsing)
    ...          # any bundled scripts, references, or assets the skill needs
```

Adding a new skill is just a new folder under `skills/` with a `SKILL.md`. The `npx skills` CLI discovers it automatically by its `name` — no index or registry to maintain.

## License & credits

MIT — see [LICENSE](./LICENSE). Individual skills credit their origins on their own page (for example, [`groom-me`](./skills/groom-me/) derives from Matt Pocock's `grilling` / `grill-me`). The `sonarqube-analyzer` and `md-to-pdf` skills were originally built for OpenClaw and adapted to the shared `skills` format here.
