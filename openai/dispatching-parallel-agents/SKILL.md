---
name: dispatching-parallel-subagents
description: Decides whether several problems can be worked on at the same time by separate subagents, and if so how to split them, brief each agent, dispatch them in one message and integrate the results. Use when there are 2 or more independent failures, bugs or investigations (different test files failing for unrelated reasons, separate subsystems broken, several unrelated questions) and no shared state between them. Do not use for related failures, exploratory debugging or work that edits the same files. Complements agent-router, which picks the tier of each agent.
---

# Dispatching parallel subagents

One agent per independent problem, all started together. Each agent gets a narrow brief
and its own context, so none of them inherits the coordinator's history, and the
coordinator's context stays free for integration. Which subagent, model and reasoning effort each
one gets is decided by the `agent-router` skill; this skill decides **whether and how to
split**.

## Step 1: is it really parallel

Parallelize only when all of these hold:

- There are 2 or more problems, and each can be understood without the others.
- Fixing one cannot plausibly fix or change another (otherwise they share a root cause).
- They will not edit the same files or use the same resource (database, port, fixture,
  lock file, generated output).
- You already know what is broken. Exploratory work ("something is wrong somewhere") is
  one agent or the coordinator, not several.

If any fails, use one agent working through the problems in order, or investigate the
group together first and split afterwards.

## Step 2: split into independent domains

Group failures by what they touch (file, subsystem, behavior), not by how many there
are. Six failing tests in three files with three different causes are three domains. Check
each pair: "if this is fixed, can the other still fail?" If yes, they stay separate; if
the answer is "maybe not", merge them.

Cap the count at the number of independent domains, and at 3 to 5 in practice (the
router's rule; keep `agents.max_concurrent_threads_per_session` at 3 to 5). More domains than that: run in
waves.

## Step 3: write one brief per domain

Each brief is self-contained, because the agent sees nothing else:

- **Scope**: one file, subsystem or failing-test list. Never "fix all the tests".
- **Context**: paste the real error messages, test names and the command that reproduces
  them. Do not make the agent rediscover what you already know.
- **Goal**: the root cause, fixed at the root, not symptoms silenced (no bumping
  timeouts, no skipping tests).
- **Constraints**: what it must not touch (other domains' files, production code when
  only tests are in scope, public interfaces).
- **Output**: exactly what to return: root cause in a few lines, list of files changed,
  the command run and its result.

Template:

```
Fix the failing tests in <path>:
  1. "<test name>": <error message>
  2. "<test name>": <error message>
Run with: <test command and filter>
Find the root cause and fix it there; do not just increase timeouts or skip tests.
Do not edit <paths outside scope>.
Return: root cause, files changed, and the output of the test command after the fix.
```

## Step 4: dispatch in one message

Put every agent call in the **same** message so they run concurrently; spawning one per turn
runs them one after another. Rules that keep this safe:

- Subagents that edit files need a `workspace-write` sandbox; give each a different
  set of files. Codex runs the subagents you spawn in one request concurrently and waits
  for all of them.
- If domains must touch neighbouring files, serialize those two or have each work in its
  own git worktree and merge afterwards.
- Read-only questions (`scout`, `reviewer`, both `read-only`) can all run together.

## Step 5: integrate and verify

When the subagents return:

1. Read each summary and understand what changed, not only that it says "fixed".
2. Check that no two subagents edited the same code or made incompatible assumptions.
3. Run the **full** suite and build once (through `test-runner` if installed). Per-agent
   greens do not prove the combination.
4. Spot-check one change per agent; subagents can make systematic errors that look
   consistent across their own output.

If the combined run fails, the domains were not independent after all: stop dispatching
and debug the interaction in one thread.

## Common mistakes

| Mistake | Fix |
| --- | --- |
| Scope too broad ("fix everything") | Name the file or subsystem |
| No context | Paste errors, test names, repro command |
| No constraints | State what must not change |
| Vague output request | Ask for root cause, files changed, command result |
| Subagents sent in separate messages | One message, all calls |
| Parallelizing related failures | Investigate together first |
| Skipping the combined run | Always run the full suite after merging |

Worked example: [references/example.md](references/example.md).
