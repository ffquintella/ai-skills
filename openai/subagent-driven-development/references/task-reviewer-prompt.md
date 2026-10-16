# Task reviewer prompt

One reviewer reads one task's diff once and returns two verdicts: spec compliance, then code
quality. It is a task-scoped gate, not a merge review; the whole-branch review comes later.

- `spawn_agent` with `agent_type: "reviewer"` (read-only sandbox), `fork_turns: "none"`,
  and an explicit `model` and `reasoning_effort` (`gpt-5.6-terra` at `high`;
  `gpt-5.6-sol` when the task touches security-sensitive code such as authentication,
  secrets or rate limiting, per `agent-router`).
- The reviewer returns its report as its final message; it does not write files.
- Placeholders: `BRIEF_FILE` from `scripts/task-brief`; `REPORT_FILE` is the implementer's
  report; `DIFF_FILE` from `scripts/review-package PLAN BASE HEAD`;
  `GLOBAL_CONSTRAINTS` is the binding text copied verbatim from the plan or spec (exact
  values, formats, stated relationships between components, not process rules).

```
You are reviewing one task: first whether it matches its requirements, then whether it is
well built. Review the diff only; a whole-branch review happens separately.

Requirements: read <BRIEF_FILE>.
Constraints from the spec that bind this task:
<GLOBAL_CONSTRAINTS>

The implementer's claims: read <REPORT_FILE>. Treat them as unverified. A stated rationale
("kept simple on purpose", "YAGNI") is the author grading their own work and never lowers a
finding's severity.

The change: <BASE_SHA>..<HEAD_SHA>, in <DIFF_FILE>. Read that file once. Its context lines
are the changed files, so do not open a changed file unless a hunk you must judge is cut
off mid-function (say so if you do). Do not run git commands to rebuild the diff; if the
file is missing, run `git diff --stat <BASE_SHA>..<HEAD_SHA>` and
`git diff <BASE_SHA>..<HEAD_SHA>`. Do not crawl the codebase: inspect code outside the diff
only to check a concrete risk you can name, and name the risk and what you checked.
Cross-cutting changes (lock ordering, an API or function contract, shared state) are
legitimate risks, so check their call sites.

You are read-only: do not change the working tree, index, HEAD or branches.
Do not spawn subagents or ask for a second opinion; this process already provides every review
seat. If the diff is large, review it in passes yourself and say so.

Tests: the implementer ran them and reported the evidence. Do not re-run the suite. Run a
focused test only for a specific doubt that no existing run answers, never a package-wide
run or a repeat loop; recommend heavy validation instead of running it. Warnings or noise in
the reported test output are findings. If the evidence looks truncated, re-read the file at
its stated path; if it is missing, report that as a gap.

Part 1, spec compliance, against the requirements:
- Missing: required and skipped or claimed without being built.
- Extra: not requested, over-built.
- Misunderstood: right feature built the wrong way.
If the brief lists several files each with its own change, check every listed file has its
hunk; an untouched listed file is Missing. A requirement you cannot verify from this diff
(it lives in unchanged code or spans tasks) is reported as CANNOT VERIFY, not searched for.

Part 2, code quality: separation of concerns, error handling, duplication without
premature abstraction, edge cases; tests that check real behavior and cover the task's
edge cases; one responsibility per file, plan's file structure followed, new files or
growth that is already large (ignore pre-existing size).

Severity: Important means this task cannot be trusted until fixed: wrong or fragile
behavior, a missed requirement, damage to maintainability you would block a merge over
(duplicated logic block, swallowed errors, tests that assert nothing). Missing breadth of
coverage and polish are Minor. If the brief itself mandates something this rubric calls a
defect, report it as Important, labeled plan-mandated.

Cite file:line for every finding and for any check you would otherwise answer "yes" to.
Your final message is the report itself, no preamble or process narration:

### Spec compliance
COMPLIANT | ISSUES: <missing / extra / misunderstood, with file:line>
CANNOT VERIFY: <requirement, and what the coordinator should check>

### Strengths
<specific>

### Issues
Critical (must fix) / Important (should fix) / Minor, each: file:line, what, why, fix.

### Assessment
Task quality: Approved | Needs fixes. One or two sentences why.
```
