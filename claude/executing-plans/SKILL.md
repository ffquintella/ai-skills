---
name: executing-plans
description: Executes a written implementation plan inline, in the current session, as the implementer yourself - review the plan critically first, raise concerns before starting, then work task by task with each task's verification, keep a ledger that survives context compaction, finish with one fresh whole-branch review, `verification-before-completion` and `finishing-a-development-branch`. Use when the user has a plan (docs/plans/...) and says "execute the plan", "implement this plan", "run through the tasks", chose inline execution over subagents, or no agent tool is available. Do not use when the user wants a fresh agent and a review gate per task (use `subagent-driven-development`), when there is no plan yet (use `brainstorming` then `writing-plans`), or when the tasks are so coupled that they cannot be ordered.
argument-hint: [path to plan file]
---

# Executing plans

Execute the plan yourself, task by task, in this session: no implementer agent and no
reviewer per task, one fresh-context review of the whole branch at the end.

Inline execution pays for one context plus one reviewer. It gives up a fresh context per
task and a second pair of eyes per task, and replaces them with: the task brief as the
spec, a ledger file as your memory, `test-driven-development` as the per-task gate, and
the final reviewer as the second pair of eyes. A fully specified plan makes this mostly
transcription plus testing, which a mid-tier session model handles well; the model that
matters most is the one reviewing at the end. Say so when the user is choosing.

Prefer `subagent-driven-development` when the user wants a review after every task, or
when the plan is long enough that its last tasks would run on a compacted context. Inline
still works on a long plan, the ledger makes it recoverable, but the last tasks get the
least of you.

## Step 1: review the plan before touching code

Read the plan once, and its spec if it names one (the spec is the authority the plan
argues from; a plan with no reachable spec gets a ledger note saying so, and rulings made
without one are provisional). Read it critically:

- Does any task contradict another task, the spec, or the plan's global constraints?
- For each task that consumes what an earlier task produces (a function, a file, a
  schema), do the names and signatures match on both sides?
- Is a step impossible as written (a command that cannot run, a file that does not exist
  yet and no task creates)?
- Does the plan mandate something that is a defect (a test that asserts nothing)?

Write one ledger row per interface a later task consumes, or the single line
`Pre-flight: no shared interfaces`. If you find concerns, raise them with the user **before
starting**, in one message, and wait: this is the one pause the skill allows, because
changing the plan is cheaper than undoing work. If the plan is sound, say so in a line and
start. Concerns about a single task's wording are not a reason to pause; handle them as
rulings when you reach that task.

## Step 2: set up

- Work in an isolated workspace: `using-git-worktrees` creates one or confirms the
  current one. Do not start on `main`/`master` without the user's consent.
- Load `test-driven-development` now; it governs every code step below.
- Create a task-list item per task. The list is a live view; the ledger is the record.
- Resolve the plan's workspace. Script paths in this skill are relative to the directory
  that holds this SKILL.md, and the scripts of `subagent-driven-development` must be
  installed next to it. Run `bash ../subagent-driven-development/scripts/sdd-workspace
  PLAN_FILE`; it prints
  `<repo-root>/.ai-skills/sdd/<plan-name>/`, holding the ledger (`progress.md`), briefs,
  test logs and review packages for this plan only. It writes a `.gitignore` containing `*`
  there so none of it is committed; tell the user to add `.ai-skills/` to the project's own
  ignore file as well. The workspace is shared with `subagent-driven-development` (same
  directory, same ledger), so a plan can change executors midway.
- Check `<workspace>/progress.md`. If its first line names your plan, every task with a
  `Task <N>: complete` line is done: resume at the first task without one, and after a
  compaction trust the ledger and `git log` over your memory. A ledger naming a different
  plan is not yours; leave it. New ledger first line: `# SDD ledger - plan: <plan file>`.
- If `graphify-out/` exists, use `graphify query|explain|affected` to find where a task
  touches the code before opening files.

## Step 3: the task loop

Everything you print and every tool result stays in your context for the rest of the
session. Send long test output to a file and read its tail; read a brief, not the plan.
Narrate at most one short line between tool calls.

**Take the task.** `bash scripts/task-start PLAN_FILE N` prints the brief path and BASE (the
commit the task's review range starts from). Read the brief even for tasks you remember
from setup: you remember a summary, the brief has the exact values, signatures and test
cases. Mark the task in progress.

**Work the steps in order**, red before green, under `test-driven-development`. A test
that passes before the implementation exists is a finding about the test. Every step that
runs a command has an expected result; run it, read the output, compare:

- Matches: next step.
- The code is wrong: use `systematic-debugging`, find the cause, never bend the code to make
  the step's output match.
- The plan is wrong (a step contradicts the spec, an interface does not match what an
  earlier task made): make the smallest change that satisfies the spec, and write it down as
  `Task <N>: Ruling: <finding> - <decision and why> - <cost if wrong>`. Later tasks that
  touch the same interface read it from the ledger. A deviation without a ledgered ruling is
  a decision made in secret.

Commit as the plan's commit steps say. BASE, not `HEAD~1`, defines the task's range.

**Completion contract.** Before a task counts as done, with evidence from this session and
not from the diff looking right: every test the brief names exists and ran, every expected
result was compared with real output, every deviation has a ruling, and the task's final
test run passed.

**Close it.** `bash scripts/task-done PLAN_FILE N BASE -- <test command>` runs the brief's
test command, keeps the full output in the workspace, prints the tail, and only if it
passes appends `Task <N>: complete (commits <base>..<head>, tests: <command> -> <result>)`
to the ledger. A failing run records nothing. Then mark the task done and start the next.
Do the ledger write in the same call as other bookkeeping, not in a call of its own.

**Do not stop between tasks.** The user chose inline to spend less; "should I continue?"
spends their time instead. Decide conflicts and ambiguities as rulings and keep going. Stop
and ask only for: an irreversible or destructive operation, a security-sensitive action, a
side effect outside this worktree (a merge, a push to a shared branch, a publish), a
blocker you cannot resolve (a missing dependency, an instruction you do not understand,
repeated test failures after `systematic-debugging`), or a plan so broken that every path
forward is a guess. Never guess past a blocker.

## Step 4: final review

Before dispatching it, run the full build and suite once (through `test-runner` when
installed).

`bash ../subagent-driven-development/scripts/review-package PLAN_FILE MERGE_BASE HEAD`
(MERGE_BASE is where the branch started, for example `git merge-base main HEAD`) writes
the diff to a file. Route the review through `agent-router`: a `reviewer` agent, read-only,
using the template in `requesting-code-review`. Hand it the package path, the plan and spec
paths, the plan's review-focus notes verbatim if it has any, and a pointer to the ledger's
`Ruling:` lines so it can weigh your calls. Use `model: opus` for security-sensitive code
(the router's override), and consider it for a branch that spans many tasks. This is the
one fresh context the run buys; do not replace it with your own read of the diff.

With no agent tool available, do the review yourself as a separate pass after the last
task's ledger line, write `Final review: self-review (no agent tool)` to the ledger, and say
so in your final message: a review by the author is weaker, and the user decides whether
that is enough before merge.

**Sort the findings before acting on them.** Severity labels are advice; the gate is yours.
Re-grade each by effect: what a reasonable person using the software gets if it ships, not
whether the spec names the input that triggers it. Then:

- Critical and Important findings go into **one** fix pass. Each fix is verified by a test
  that failed first: write it, watch it fail, fix, run the whole suite. Ledger it as `Final:
  fixed <finding> - <test> RED->GREEN, suite <N>/<N>`. A fix without a failing test is a
  diff and a hope. Do not dispatch a re-review; the covering tests and the green suite
  answer "addressed" and "broke nothing".
- Minor findings go to the ledger as `Final: minor (deferred): <one-liner>` and to your
  final message. They never enter the fix pass.
- A finding you decide not to fix is a ruling: `Final: Ruling: <finding> - <why the code
  stands> - <cost if wrong>`. There is no second fix pass.

When a ruling or a rejected finding should outlive the session, `remember` it if Cortex
is connected (see `cortex-memory`).

## Step 5: finish

Collect every ledger line containing `Ruling:` into your final message under **Rulings I
made**, in order, each with its cost if wrong, and every `minor (deferred)` line under
**Deferred minors**. Both lists are exhaustive: they are the only place the decisions you
took on the user's behalf reach them.

Then, with the final review clean and its fixes committed, use `verification-before-completion`
(fresh command output, not recollection) and `finishing-a-development-branch`. Delete this
plan's workspace directory only after those; sibling directories belong to other plans.

## Common rationalizations

| Excuse | Reality |
| --- | --- |
| "I remember what Task N says" | A summary. The brief has the exact values. Read it. |
| "The plan's test is right, skip watching it fail" | A test you never saw fail proves nothing. It is one step. |
| "The plan is wrong here, I will just do the right thing" | Do it and ledger the ruling. Unledgered deviation is a secret decision. |
| "I will write the ledger after a few tasks" | Compaction does not wait. One line per task, in the call that commits. |
| "I read my own diff; the final reviewer is redundant" | Same author, same blind spots. It is the only fresh context this run buys. |
| "Tests should pass, the change was trivial" | "Should" is not evidence. The contract needs the command and its output. |
