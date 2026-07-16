# Felipe's Skills

Agent skills I use and share. Built to work with **Claude Code, Codex, OpenCode, Cursor**, and any other agent supported by the [`skills`](https://github.com/vercel-labs/skills) ecosystem.

## Skills in this repo

| Skill | What it does |
| ----- | ------------ |
| [`groom-me`](./skills/groom-me/SKILL.md) | Auto-runs a **non-technical grooming interview** to confirm intended behavior *before* any business rule changes. |

---

# `groom-me`

`groom-me` interviews you (or your product owner / domain expert) in **plain, non-technical language** the moment a code change is about to touch a **business rule** — an `if`, a validation, a price, a permission, a threshold, a state transition. It confirms *what the software should decide* before the change ships, so a business decision is never silently made inside a code edit.

It is a business-rule-scoped, non-technical, auto-triggering variant of [Matt Pocock's `grill-me`](https://github.com/mattpocock/skills/tree/main/skills/productivity/grill-me). It keeps the proven `grilling` core loop and changes three things: **when** it fires, **who** it's for, and **how** it asks.

## Quickstart

```bash
npx skills add FelipeOFF/skills --skill=groom-me
```

Update later:

```bash
npx skills update groom-me
```

That's it. In Claude Code (and any other agent you install it on), the skill now watches for business-rule changes and grooms them before they land. You can also invoke it on demand by typing `/groom-me`.

## The difference from Matt Pocock's `grill-me`

This is the part to read carefully. `groom-me` is **not** a rename of `grill-me` — it shares its engine but is pointed at a different job.

**What is kept identical (the `grilling` core loop):**
- One decision at a time — never a batch of questions dumped at once.
- Every question comes with the agent's own **recommended answer**, so you react to a proposal, not a blank prompt.
- Facts that can be found by reading the codebase are looked up, not asked. Only the **decisions** are put to you.
- The decision tree is walked branch by branch, resolving dependencies (parent decisions before the ones that hang off them).
- Stateless — nothing is written to disk; the only artifact is the sharpened understanding in the conversation.
- Nothing is built until you confirm.

**What is different:**

| | Matt Pocock's `grill-me` | This `groom-me` |
| --- | --- | --- |
| **When it fires** | User-invoked only. It sets `disable-model-invocation: true`, so the agent never reaches for it on its own — you type `/grill-me`. | **Auto-invoked.** The agent triggers it *by itself* whenever a change would add or alter a business rule (an `if`/`switch`, a validation, a price/discount/fee, an eligibility or permission check, a threshold, a state transition, anything in the domain layer). Still available on demand via `/groom-me`. |
| **Scope** | Broad — grills *any* plan, design, or idea to stress-test your thinking. | **Narrow and specific** — scoped to business-rule and domain-logic changes. It stays quiet for pure refactors, renames, formatting, tests, and docs. |
| **Register / audience** | Written for an engineer. Questions are asked in technical terms and assume you read code. | **Fully non-technical.** Every technical concept is translated into the real-world outcome it controls (customers, money, access, behavior). Each question explains what happens today, what would change, and who it affects — so a non-technical stakeholder can answer. |
| **How it asks** | One question at a time, in plain chat. | Uses the **harness's own structured question UI** so you answer by picking an option: **AskUserQuestion** in Claude Code, the native equivalent in Codex / OpenCode / Cursor, and a plain-chat fallback only when no structured UI exists. |
| **Language** | Not specified. | **Adapts to your language.** It detects the language you're writing in from the conversation the harness surfaces and asks in that language, and honors an explicit language preference set in `CLAUDE.md` / `AGENTS.md` (config wins). |

In one line: **`grill-me` is a broad, technical, on-demand stress test; `groom-me` is a narrow, non-technical, automatic gate that catches business-rule changes and grooms them before they ship.**

## When `groom-me` runs

It runs the moment a change would affect **what the software decides, allows, blocks, or charges**:

- An `if` / `else` / `switch`, a guard clause, a ternary, or any boolean condition.
- Validation rules, required fields, allowed values, limits, thresholds, quotas.
- Pricing, discounts, fees, taxes, eligibility, permissions, access rules.
- State transitions, status changes, workflow steps.
- Anything in a `domain/`, `rules/`, `policy/`, or business layer.

It stays quiet for pure refactors, renames, formatting, dependency bumps, logging, tests, and comments — anything that changes *how* the code is written but not *what it decides*.

## What a non-technical question looks like

A change raises a free-shipping threshold from `100` to `150`.

> ❌ **Technical (what `grill-me` might ask):** "Should the free-shipping threshold in the `if (order.total > 100)` condition be raised to 150?"
>
> ✅ **Non-technical (what `groom-me` asks):** "Today, customers get free shipping once their order reaches **$100**. This change raises that to **$150** — so orders between $100 and $149 would start paying for shipping again. Is that the behavior you want? *(My recommendation: yes, raise it to $150.)*"

## Installation — in detail

`groom-me` installs through the open [`skills`](https://github.com/vercel-labs/skills) CLI (`npx skills`). You don't need to clone this repo or install anything globally first — `npx` fetches the CLI on the fly.

### Install into the current project

```bash
npx skills add FelipeOFF/skills --skill=groom-me
```

You'll be asked which agents to install it on (Claude Code, Codex, OpenCode, Cursor, …). The skill is placed under that agent's skills directory (e.g. `./.claude/skills/groom-me` for Claude Code) so it's committed with your project and shared with your team.

### Install globally (available in every project)

```bash
npx skills add FelipeOFF/skills --skill=groom-me --global
```

### Pick specific agents non-interactively

```bash
# Claude Code + Codex, project scope, no prompts
npx skills add FelipeOFF/skills --skill=groom-me -a claude-code -a codex -y
```

### Preview before installing

```bash
# List the skills this repo exposes without installing anything
npx skills add FelipeOFF/skills --list
```

### Try it once without installing

```bash
npx skills use FelipeOFF/skills --skill groom-me --agent claude-code
```

### Update or remove

```bash
npx skills update groom-me      # pull the latest version
npx skills remove groom-me      # uninstall from your agents
```

### Manual install (no CLI)

Copy `skills/groom-me/SKILL.md` into your agent's skills folder — for Claude Code that's `~/.claude/skills/groom-me/SKILL.md` (global) or `.claude/skills/groom-me/SKILL.md` (project). The skill is a single self-contained file with no dependencies.

## Credits & license

`groom-me` derives from the `grilling` / `grill-me` primitive by **[Matt Pocock](https://github.com/mattpocock/skills)**, used under the MIT License. This repo is MIT-licensed too — see [LICENSE](./LICENSE). Hack on it, adapt it, make it yours.
