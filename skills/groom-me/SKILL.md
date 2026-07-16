---
name: groom-me
description: Runs a short, NON-TECHNICAL grooming interview to confirm intended behavior BEFORE any business rule changes. Use this proactively whenever a code change would add or alter business logic — an if/else/switch, a guard clause, a validation, a calculation, an eligibility, pricing, permission or discount check, a state transition, a threshold or limit, or anything in the domain or business layer. Trigger it even when the user never says groom or grill — if the change alters WHAT the software decides, allows, or charges, stop and groom first. Also runs on demand via /groom-me. Skip only for pure refactors, formatting, renames, tests, or docs that do not change behavior.
---

# groom-me

Before you change a business rule, confirm the *intended behavior* with the person — in plain, non-technical language — so you never silently ship a decision they never actually made.

This is a business-rule-scoped variant of the `grilling` interview (credit: Matt Pocock's `grill-me`). It keeps the same core loop and adds two things: it fires **automatically** on business-logic changes, and it asks in language a **non-technical stakeholder** can actually answer.

## When to run

Run the moment a change would affect **what the software decides, allows, blocks, or charges**. Signals to watch for:

- Adding or editing an `if` / `else` / `switch`, a guard clause, a ternary, or any boolean condition.
- Validation rules, required fields, allowed values, limits, thresholds, quotas.
- Pricing, discounts, fees, taxes, eligibility, permissions, access rules.
- State transitions, status changes, or workflow steps.
- Anything living in a `domain/`, `rules/`, `policy/`, or business layer.

**Do NOT run** for pure refactors, renames, formatting, dependency bumps, logging, tests, or comments — anything that changes *how* the code is written but not *what it decides*. When you genuinely can't tell whether behavior changes, run.

## The core loop (inherited from grilling)

- Interview one **decision** at a time and wait for the answer before moving on. A batch of questions at once is bewildering.
- For each question, give your own **recommended answer** so the person reacts to a proposal instead of a blank page.
- If a **fact** can be found by reading the code, files, or tools, look it up — don't ask. Only the **decisions** are theirs.
- Walk each branch of the decision tree, resolving dependencies: settle the parent decision before the ones that hang off it.
- **Do not make the change until they confirm.** The session is stateless — it writes nothing and leaves no workspace behind. The only artifact is the shared understanding in the conversation.

## Ask non-technically — this is the whole point

The person answering may not read code. Never quote code, variable names, or technical jargon at them.

- **Translate** every technical concept into the real-world outcome it controls. Talk about customers, money, access, and behavior — not `if` statements or field names.
- **Explain each question in detail**: state what happens today, what the change would make happen, and who it affects. Ground it in a concrete scenario.
- Phrase the **recommended answer** in that same plain language.
- If a technical detail genuinely matters to the decision, explain it in one accessible sentence *before* asking — don't assume it's understood.

### Speak the person's language

Ask every question in the **person's own language**. There is no universal "locale" field to query — detect it from the context the harness gives you:

- **Read the language the person is actually writing in** this conversation and mirror it. If they write in Portuguese, ask in Portuguese; in Spanish, ask in Spanish; and so on. This is the reliable signal across every agent (Claude Code, Codex, OpenCode, Cursor, …) — the harness surfaces the conversation, and you match it.
- **Honor an explicit preference** if one is set in the agent's instructions or project config (e.g. a language rule in `CLAUDE.md` / `AGENTS.md`). An explicit instruction wins over the inferred language.
- If the language is genuinely unclear, default to English and switch the moment the person replies in another language.

The recommended answers and explanations go in that same language too — the whole point is that the person can answer comfortably.

**Example**

A change in the code raises a free-shipping threshold from `100` to `150`.

- ❌ Technical: "Should the free-shipping threshold in the `if (order.total > 100)` condition be raised to 150?"
- ✅ Non-technical: "Today, customers get free shipping once their order reaches **$100**. This change raises that to **$150** — so orders between $100 and $149 would start paying for shipping again. Is that the behavior you want? *(My recommendation: yes, raise it to $150.)*"

## How to ask — use the harness's own question UI

Ask through the structured question mechanism of whatever agent you are running in, so the person answers by picking an option rather than typing free-form:

- **Claude Code** → use the **AskUserQuestion** tool. One decision per call. Put your recommended answer first and label it "(Recommended)". The person can always choose "Other".
- **Codex / OpenCode / Cursor / any other agent** → use that agent's native structured-choice or ask-the-user mechanism in the same way.
- **No structured UI available** → ask in plain chat: one question, your recommended answer included, then wait.

Keep it to one decision per round no matter which mechanism you use.

## After confirmation

Once the intended behavior is confirmed for every branch, make the change so it matches exactly what was agreed — nothing more, nothing assumed.
