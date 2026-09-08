# cascade-flow

Stacked-PR discipline: branch off the previous PR's head, keep each diff
reviewable, merge bottom-up. Renders the live chain of open PRs.

```bash
npx skills add FelipeOFF/skills --skill=cascade-flow
```

The skill never merges. Humans approve; the script only shows the chain.

See [SKILL.md](./SKILL.md) for the rules, the panorama script, and the
`--full` review-state buckets.
