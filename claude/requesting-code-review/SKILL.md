---
name: requesting-code-review
description: Sends finished work to a fresh reviewer agent with a precise brief (what was built, what it should do, the exact commit range) so problems are caught before they cascade into the next task, then routes the findings to receiving-code-review. Use after each task in subagent-driven-development, after a major feature or a complex bug fix, before merging to main, or when stuck and wanting a fresh view; also for "review my changes", "get this reviewed" or "is this ready to merge". Not for deep Rust security audits (use rust-review) and not for acting on feedback already received (use receiving-code-review).
argument-hint: [description | base ref] [plan or requirements]
---

# Requesting code review

A reviewer that sees only the diff and the requirements judges the work product, not your
reasoning, and its output (the findings) is small. Reviewing the diff inline in the
coordinating thread spends the context you need to keep driving the work, so delegate it.
Review early and often: an issue found after one task is cheap, after five it is tangled.

## When to request

Always:

- after each task in `subagent-driven-development`
- after finishing a major feature or a complex bug fix
- before merging to the main branch (see `finishing-a-development-branch`)

Worth it:

- when stuck, for a fresh view
- before a refactor, as a baseline

"It is a small change" is not a reason to skip. Small changes are where the unreviewed
assumption hides; a small diff also makes a cheap review.

## Steps

### 1. Fix the commit range

```bash
BASE_SHA=$(git merge-base origin/main HEAD)   # whole branch; or: git rev-parse HEAD~1 for one commit
HEAD_SHA=$(git rev-parse HEAD)
git diff --stat "$BASE_SHA..$HEAD_SHA"
```

For one task of a plan, use the commit before the task started as the base. Uncommitted
work cannot be reviewed by range: commit it first, or tell the reviewer to run
`git diff` and `git diff --staged` instead.

### 2. Pick the reviewer through `agent-router`

Use the `reviewer` agent (Sonnet, high effort, read-only). Override to `model: opus` when
the diff touches authentication, authorization, secrets, rate limiting or other
security-sensitive paths, as the router's review row says. If the project has not
installed the `agent-router` templates, spawn a `general-purpose` agent with the same
prompt and the `model` from the `agent-router` fallback table (`sonnet`, or `opus` for
security-sensitive paths). For a deep security audit of a Rust codebase, do not use this skill: the user
has to ask for `rust-review` by name.

The `reviewer` agent already reads `AGENTS.md` / `CLAUDE.md`, obtains the diff and reports
project-rule gaps. The prompt below adds what it cannot know: what the change is meant to
do, and the severity scale to answer in. Do not repeat its checklist.

### 3. Fill the template and dispatch

Template: [references/code-reviewer.md](references/code-reviewer.md). Fill four fields:

| Field | Content |
| --- | --- |
| `{DESCRIPTION}` | One or two sentences on what was built |
| `{REQUIREMENTS}` | The plan task, spec path or acceptance criteria (paths beat pasted text) |
| `{BASE_SHA}` / `{HEAD_SHA}` | The range from step 1 |

Pass the brief only, never your session history: a reviewer primed with your reasoning
agrees with it. Spawn it with the `Agent` tool (`subagent_type: "reviewer"`, plus
`model: "opus"` when overridden). Review of a large diff may be split by directory only
when the pieces are independent; see `dispatching-parallel-agents`.

### 4. Act on the result with `receiving-code-review`

Treat the report as input to verify, not orders. `receiving-code-review` covers it in
detail; the short version:

- **Critical**: fix now, before anything else.
- **Important**: fix before moving to the next task.
- **Minor**: note for later or fix if trivial; do not let them block.
- **Reviewer is wrong**: say why with code or a passing test, and ask for clarification if
  its claim cannot be checked.

After fixes, rerun the build and tests (and the review, if the changes were substantial).
Anything the reviewer "declined to judge" is the user's call or the plan's author's; raise it,
do not silently drop it.

## Example

```
Just finished Task 2 of docs/plans/2026-10-16-index-repair.md: verifyIndex() and repairIndex().

BASE_SHA=a7981ec (end of Task 1)   HEAD_SHA=3df7661

Agent(subagent_type: "reviewer"), prompt = filled template:
  DESCRIPTION:  Added verifyIndex() and repairIndex() covering 4 corruption types
  REQUIREMENTS: Task 2 in docs/plans/2026-10-16-index-repair.md

Report:  Verdict: fix first
  Important: repairIndex has no progress output, search.ts:25 swallows bad dates
  Minor:     magic number 100 at indexer.ts:130
Fix the two Important items, rerun the suite, continue to Task 3.
```

## Mistakes

| Mistake | Fix |
| --- | --- |
| Reviewing the diff inline "to save a dispatch" | Delegate; only the findings come back |
| Handing the reviewer your session history | Description, requirements and range only |
| Vague requirements ("make it work") | Point at the plan task or acceptance criteria |
| Reviewing uncommitted work by range | Commit first or name the `git diff` commands |
| Proceeding with open Critical or Important items | Fix, then continue |
| Arguing with a correct finding | Verify it; if right, fix it |

If a review turns up a decision worth keeping (a design call, a pattern the reviewer
caught repeatedly), `remember` it when Cortex is connected.
