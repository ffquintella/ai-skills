---
name: subagent-driven-development
description: Executes a written implementation plan by dispatching one fresh implementer agent per task, then a task review (spec compliance first, then code quality), a bounded fix loop, and only then the next task, with a whole-branch review at the end. The coordinator keeps a ledger and a "Rulings I made" list for the user, and routes every dispatch through `agent-router` (implementer `builder` or `architect`, reviewer `reviewer`, test runs `test-runner`). Use when the user has a plan (docs/plans/...) with mostly independent tasks and says "execute the plan with agents", "subagent-driven", "one agent per task", or wants a review gate after every task. Do not use when the user chose inline execution or no agent tool exists (use `executing-plans`), when there is no plan yet (use `writing-plans`), or when tasks are tightly coupled and cannot be handed over one at a time.
argument-hint: [path to plan file]
---

# Subagent-driven development

One fresh implementer agent per task, a review of that task's diff (spec compliance, then
code quality), a fix loop if the review finds problems, then the next task. A broad review
of the whole branch happens once at the end. You are the coordinator: you hand out tasks,
read verdicts, keep the ledger and decide conflicts. You do not write the code.

Each agent gets exactly what its task needs and none of your history, so it stays focused and
your context stays free for coordination. The price is a fresh context per task and per
review; `executing-plans` is the cheaper alternative when the user prefers one context plus
one final reviewer.

**Do not stop between tasks.** Do not ask "should I continue?" and do not post progress
summaries; the user asked for the plan to be executed. Conflicts, ambiguities and plan
defects are rulings: the spec is the binding authority, the plan is its argument, your
judgment settles what neither answers. Record each as `Ruling: <what you decided> - <why> -
<cost if wrong>` in the ledger and keep going. Stop and ask only for an irreversible or
destructive operation, a security-sensitive action, a side effect outside this worktree (a
merge, a push to a shared branch, a publish), or a plan so broken that every path forward is
a guess. Narrate at most one short line between tool calls.

## Setup

- Isolated workspace: `using-git-worktrees` creates or confirms one. Never start on
  `main`/`master` without the user's consent.
- Script paths below are relative to the directory holding this SKILL.md. `bash
  scripts/sdd-workspace PLAN_FILE` prints the plan's workspace,
  `<repo-root>/.ai-skills/sdd/<plan-name>/`, holding the ledger (`progress.md`), briefs,
  reports and review packages for this plan only. It writes a `.gitignore` containing `*`
  there so none of it is committed; tell the user to add `.ai-skills/` to the project's own
  ignore file too. It is in the working tree and not under `.git/` because agents cannot
  write there, and the implementer has to write its report. `git clean -fdx` deletes it;
  recover from `git log`.
- Memory does not survive compaction, and a coordinator that lost its place re-dispatches
  finished tasks, the most expensive failure of this process. Check `<workspace>/progress.md`:
  if its first line names your plan, every `Task <N>: complete` task is done, and a task
  whose last line is a fix round is mid-loop (resume at the next round). A ledger naming
  another plan is not yours. New ledger first line: `# SDD ledger - plan: <plan file>`.
  After a compaction trust the ledger and `git log` over your recollection.
- Read the plan once, with its global constraints and the spec it names (conflicts inside
  the plan resolve against the spec; no reachable spec gets a ledger note, and rulings are
  provisional). Create a task-list item per task. If `graphify-out/` exists, use it to find
  what a task touches before briefing.
- Scan before Task 1 and write the result to the ledger: one row per pair of tasks that
  share a file or interface (what one produces, what the other consumes, what you found),
  one row per task saying whether its text agrees with itself (tests against code, files
  created against files later touched), and a flag on anything the plan mandates that a
  reviewer would call a defect. "Clean" without rows is not a scan. Rule on every finding
  before dispatching and ledger each ruling.

## Who does what

Every dispatch goes through `agent-router`, which owns the agent, model and effort. This
skill only says which tier each role belongs to:

| Role | Agent (router) | Notes |
| --- | --- | --- |
| Implementer, ordinary task | `builder` (Sonnet, high) | The plan has the approach and the files. |
| Implementer, complex task | `architect` (Opus, xhigh) | Plan marks it complex, it needs design judgment, or touches auth, secrets, config schema or the composition root. |
| Task review, re-review | `reviewer` (Sonnet, high) | Opus for security-sensitive code, per the router. |
| Final whole-branch review | `reviewer` | Opus for security-sensitive code; consider it for a branch spanning many tasks. |
| Test or build runs for evidence | `test-runner` (Haiku) | Failures only. |

When the project has not installed these agents, use a general-purpose agent and set `model`
on every call: an omitted model inherits your own, usually the most expensive.

**Escalation ladder** (from the router): `builder` -> `architect` -> `architect` with
`model: fable` only when the user asks for it or a frontier-hard problem defeated `architect`.
Climb one rung when a fix round fails; attach the failure to the next brief. Do not retry at
the same level after a failed round.

Turn count beats token price: the router's defaults are the floor for implementers and
reviewers, so do not go below them on your own. The one exception is the router's: when the
plan passes its complete-specification check, it lowers each implementer one rung (complex
to `builder`, routine to `builder` on a cheaper model), and the escalation ladder starts
from there. Security-sensitive tasks are never lowered. Several
small same-shape edits (one fix repeated across files) go to **one** `builder` with one
brief listing every file, reviewed as one unit.

Agent definitions carry defaults that clash with this loop: `builder` is told not to
commit and to report in 40 lines. The templates below override both explicitly (commit, and
write a full report to a file); keep that wording.

## The task loop

Everything you paste into a dispatch and everything an agent prints back stays in your
context. Hand work over as files, and never paste earlier tasks' summaries into later
dispatches.

### 1. Dispatch the implementer

1. Record BASE: `git rev-parse HEAD`.
2. `bash scripts/task-brief PLAN_FILE N` writes the task's full text to
   `<workspace>/task-N-brief.md` and prints the path. Never make an agent read the whole plan.
3. Fill [references/implementer-prompt.md](references/implementer-prompt.md): one line on
   where the task fits, the brief path ("your requirements, exact values to use verbatim"),
   interfaces and decisions from earlier tasks that the brief cannot know, your resolution of
   any ambiguity you noticed, a pointer to any parked finding in the same area, the report
   path (`task-N-report.md`) and the test command from the brief.
4. Call the `Agent` tool in the foreground (`run_in_background: false`): a background agent
   auto-denies any permission prompt and can report an edit it never made. Keep the agent ID from the result; fix
   rounds continue that agent.
5. One implementer at a time: parallel implementers conflict.

The implementer never spawns agents, above all never a reviewer; review is yours to schedule.
The template says so.

### 2. Handle the report

The implementer replies in under 15 lines with a status and writes detail to the report file.

- **DONE**: write the review package and dispatch the reviewer.
- **DONE_WITH_CONCERNS**: read the concerns first. Correctness or scope doubts get resolved
  before review; observations (a file getting large) go to the ledger and review proceeds.
- **NEEDS_CONTEXT**: answer, then continue the same agent.
- **BLOCKED**: a context problem gets more context; a reasoning problem climbs the ladder;
  an oversized task is split; a wrong plan gets a ruling, ledgered and carried in the next
  dispatch. Never make the same tier retry unchanged after it said it is stuck.

If the report's test evidence looks thin, run the brief's test command once through
`test-runner` before reviewing.

### 3. Review the task

`bash scripts/review-package PLAN_FILE BASE HEAD` writes the commit list, stat and full diff
(10 lines of context) to a file and prints its path, so the diff never enters your context.
Use the BASE you recorded, never `HEAD~1`, which drops all but the last commit of a
multi-commit task. Never dispatch a reviewer without a diff file.

Dispatch `reviewer` with [references/task-reviewer-prompt.md](references/task-reviewer-prompt.md)
and three paths (brief, report, diff) plus the global constraints that bind this task, copied
verbatim from the plan or spec: exact values, formats, stated relationships between
components. The reviewer returns a spec-compliance verdict and a code-quality verdict;
accept nothing missing either.

- Do not ask it to re-run tests the implementer already ran, and do not add open-ended
  directives ("check all uses") without a task-specific reason.
- Do not pre-judge. A prompt containing "do not flag", "at most Minor" or "the plan chose"
  is you sparing yourself a fix loop. If you think a finding is a false positive, let the
  reviewer raise it and rule on it in the loop.
- "Cannot verify from diff" items are yours to resolve, since you hold the cross-task
  context. A confirmed gap is a failed spec review and enters the fix loop.

### 4. The fix loop

It starts on a spec failure, any Critical or Important finding, or a confirmed gap. Two
routes leave early: Minor findings go to the ledger (`Task <N>: minor (deferred): <one-liner>`)
and are handed to the final review, and a finding that conflicts with what the plan's text
requires is yours to weigh against the spec and rule on, ledgered, before you act. Do not
dismiss it because the plan mandates it, and do not dispatch a fix that contradicts the plan
without a ruling.

A round is one fix dispatch plus one scoped re-review. **At most three rounds.**

- **Round 1**: continue the same implementer (`SendMessage` to its agent ID) with the open
  findings verbatim; its context is intact. If it cannot be messaged, start a fresh
  implementer with the brief path, report path and findings; the report file is the memory.
- **Rounds 2 and 3, after a failed round**: climb a rung. Spawn a fresh `architect` with the
  brief, the report path, the open findings and: "A prior implementer attempted this task
  and the findings below remain open; you own it now. Read the report file for what was
  tried." If the task was already on `architect`, continue it once more with the failure
  attached; two failed rounds at the top rung mean the task needs re-scoping.
- **Every round**: the implementer fixes, re-runs the tests covering the amended code and
  appends a fix report (what changed, covering tests, the command, the output) to the same
  report file. Reviewers do not re-run tests for it. Confirm all three are present before
  re-reviewing.
- **The re-review is scoped.** `bash scripts/review-package PLAN_FILE FIX_BASE HEAD`, where
  FIX_BASE is the head the previous review saw, then
  [references/re-review-prompt.md](references/re-review-prompt.md) with the findings, brief,
  report and diff path. Each finding comes back ADDRESSED or NOT ADDRESSED, plus new breakage
  in the fix diff only. New Critical/Important breakage joins the open list; out-of-scope
  observations go to the ledger as deferred minors and never extend the loop.
- After each round append `Task <N>: fix round <R>/3 (<X> addressed, <Y> open - <one-liners>;
  commits <a7>..<b7>)`.

Never fix findings yourself: it fills your context and skips review.

**The breaker.** If round 3 leaves findings open, stop dispatching and adjudicate each one
yourself; you hold context the reviewer lacks. A finding that is wrong, contestable, or real
but not built on by later tasks is parked: `Task <N>: parked - <finding> - Ruling: <why the
code stands or is deferred>`. A real finding a later task builds on, or one that exposes a
plan defect, gets a ruling on the smallest change that unblocks the dependent work, ledgered
and carried into the next dispatch; parking a structural failure lets every later task build
on it. Adjudicate only at the cap, since doing it earlier is pre-judging. Every adjudication
is a ledger entry; a silent discard is not allowed.

### 5. Complete the task

When the review is clean, or every open finding is parked with a ruling, append in the same
call as other bookkeeping: `Task <N>: complete (commits <base7>..<head7>, review clean)` or
`..., <K> parked)`. Mark the task done and move on. Never start the next task while
Critical/Important findings are neither fixed nor parked at the cap.

## Final review

Run the full build and suite once (through `test-runner`). Then
`bash scripts/review-package PLAN_FILE MERGE_BASE HEAD` (MERGE_BASE is where the branch
started, for example `git merge-base main HEAD`) and dispatch `reviewer` using
`requesting-code-review` with the package path, the plan and spec paths, and a pointer to the
ledger's deferred-minor and parked lines so it can triage which must be fixed before merge.

If it returns findings, dispatch **one** fix agent with the complete list, not one per
finding (per-finding fixers each rebuild context and re-run suites). Then exactly one scoped
re-review of the fix range, and adjudicate any residue as in the breaker. There is no second
fix wave: a residual load-bearing finding reaches the user through
`finishing-a-development-branch`. Run the full suite again after the fix wave.

## Finish

Before deleting anything, put every ledger line containing `Ruling:` (pre-flight rulings,
parked findings, breaker adjudications, all of them) into your final message under **Rulings
I made**, in order, each with its cost if wrong, and every deferred minor under **Deferred
minors**. Both lists are exhaustive; they are the only way the decisions you took on the
user's behalf reach them. A ruling that dies with the workspace was made in secret. When one
should outlive the session (a design choice, a review suggestion rejected and why),
`remember` it if Cortex is connected (see `cortex-memory`).

When the final review is clean and its fixes are committed, delete this plan's workspace
directory (not its siblings), then use `finishing-a-development-branch`.

## Optional: run the loop through one orchestrator (Claude Code)

The coordinator is the most expensive seat: it reads every dispatch result and usually runs
on your most capable model. Claude Code allows nested agents (three layers below the main
conversation by default; `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` adjusts it), so the whole
loop can run one layer down. Only when the user asks for it, or says the session model is too
expensive for coordination, dispatch **one** orchestrator agent on a mid-tier model
(`model: sonnet`) with the plan path and the instruction to follow this skill end to end. It
dispatches its own implementers and reviewers per the routing above, and the workspace and
ledger on disk lose nothing to the extra layer. Its final message must carry **Rulings I
made** verbatim, and you relay it rather than summarize it. Do this for a whole plan only;
nesting a single task adds a seat and buys nothing.

## Common rationalizations

| Excuse | Reality |
| --- | --- |
| "Close enough on spec compliance" | A spec gap means not done: fix it or hit the cap and adjudicate. Those are the only exits. |
| "I will fix it myself, dispatching is overhead" | Controller fixes fill your context and skip review. Continue the implementer. |
| "One more round will converge" | Past the cap, rounds do not converge; the failure is structural. Adjudicate. |
| "The fix was small, skip the re-review" | Unreviewed fixes are how regressions land. Every round ends with a scoped re-review. |
| "The ledger is overhead" | It is what survives compaction. Without it whole task sequences get re-dispatched. |
| "The implementer spawned its own reviewer, free assurance" | A duplicate seat on the same diff that counts for nothing. Flag it as a defect. |
