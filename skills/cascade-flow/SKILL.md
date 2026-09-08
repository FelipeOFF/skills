---
name: cascade-flow
description: Use when starting a new task while a related PR is already open, when deciding which branch to base a PR on, when a PR is getting too big to review, or when the user asks for the panorama, cascade, stacked PRs, merge order, or which open PRs form a chain.
---

# Cascade flow

Work moves as **stacked PRs**: each follow-up branches off the previous PR's
head, not the repo default branch. Diffs stay reviewable. The chain merges
bottom-up. This skill never merges.

## When to use

- A related PR is still open and the new work depends on it or would conflict with it.
- The current PR mixes unrelated concerns — split a stacked follow-up.
- The user asks for the panorama / cascade / stacked PRs / merge order / open PR chain.
- Before the first edit: confirm the current branch is the right one.

**Not this skill:** a single PR against the default branch with no parent;
Graphite/`git-branchless` restacking; GitLab (the script speaks `gh`).

## Discipline

1. **Branch safety first.** `git branch --show-current` in every repo you touch.
   Never work on `main` / `master` / `trunk` / `dev` / `develop` / `release/*`.
2. **Stack, don't fork from default.** Branch from the open PR's **head** and set
   the new PR's base to that head:
   ```
   feat/auth_tokens  → main                 (root)
   feat/auth_ui      → feat/auth_tokens
   feat/auth_docs    → feat/auth_ui
   ```
   PR body line: `Stacked on: #<parent> (merge after)`.
3. **One logical unit per PR.** Split when the diff mixes unrelated concerns.
   Prefer a new stacked branch over a fat PR.
4. **Merge bottom-up. Humans approve.** Root into the default branch first,
   then each child. Merging a child first dumps it onto the parent's PR.
   This skill never merges.
5. **When the parent moves, merge it in.** `git merge` the parent into the
   stacked branch (never force-push), then re-verify. After the root lands, if
   GitHub did not retarget the child at the default branch, retarget it.

Same change across several repos: one branch per repo, each stacked on *that*
repo's own previous head. Chains are independent per repo.

## Panorama

Script next to this file. Needs authenticated `gh` and `python3`.

```bash
bash <this-skill>/scripts/cascade-status.sh
bash <this-skill>/scripts/cascade-status.sh --stacked
bash <this-skill>/scripts/cascade-status.sh --ci
bash <this-skill>/scripts/cascade-status.sh --full
bash <this-skill>/scripts/cascade-status.sh --repo owner/name
```

Repo resolution, first match: `--repo` → `$CASCADE_REPOS` → `.cascade-repos`
at the git root → `gh repo view`.

Each line is `#PR  [ticket]  slug  → #parent|branch` plus mergeable / draft / CI.
Chains print root-first with `└→` — that is the merge order. `--stacked` includes
PRs whose base is another open PR **or** is not the default branch (a child left
pointing at a landed parent).

A ticket key (`ABC-123`) is a label from the head branch or title, when present.

## `--full` — classify, then act

The script is the data spine. Then classify every open PR in the chains
(`reviewDecision` + unresolved review threads):

```bash
gh pr view <N> --json number,reviewDecision,mergeable,isDraft,reviews
gh api graphql -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){reviewThreads(first:100){totalCount nodes{isResolved}}}}}' -F o=<owner> -F r=<repo> -F n=<N>
```

Exactly one bucket each: **ready to merge** (unresolved = 0, CI green — human
still clicks merge, root first) · **needs review** (no reviews yet) · **needs
resolve** (unresolved > 0; if `pr-autopilot` is installed, `--resolve
--merge=false`) · **close** (obsolete).

Present the tree tagged with buckets, then the four lists. No essay.

## Common mistakes

| Excuse | Reality |
|--------|---------|
| "Target default; the diff includes the parent anyway" | Reviewers see two features. Stack. |
| "The child is green, merge it now" | Merging before the root pollutes the parent's PR. |
| "Rebase the stack and force-push" | `git merge` the parent in. |
| "One PR is faster" | Two reviewable PRs ship the same work. |
| "CI is green so this skill can merge" | Humans approve. The skill renders and stops. |
