# Implementer prompt

Fill the placeholders and send as the `prompt` of an `Agent` call.

- `subagent_type`: `builder`; `architect` for a complex task, or for a fix round after a
  failed one (see the routing table in SKILL.md). General-purpose agent plus an explicit
  `model` when the project has not installed the router's agents.
- `description`: `Implement Task N: <name>`
- `run_in_background`: false

```
You are implementing Task N: <task name>. Work from <directory>.

Read this first, it is your requirements with the exact values (numbers, strings,
signatures, test cases) to use verbatim: <BRIEF_FILE>
Do not read the whole plan.

Context: <one line on where this task fits>. <Interfaces and decisions from earlier
tasks that the brief cannot know.> <Rulings that apply to this task.>

Before you start: if the requirements, approach or a dependency are unclear, ask now.
The same applies mid-task. Do not guess; it is always fine to stop and ask.

Your job:
1. Implement exactly what the task specifies, nothing more. Follow
   `test-driven-development` where the task has behavior to test: failing test first, and
   watch it fail for the right reason.
2. While iterating run the focused test for what you are changing; run the full suite once
   before committing.
3. Commit your work. This overrides any default of your agent definition that says not to
   commit. One or several commits are fine.
4. Self-review your own diff (below), fix what you find.
5. Write the report file and reply with the short status.

Do not spawn agents. Do all of this task's work yourself, and above all never spawn a
reviewer: after you report, the coordinator dispatches a fresh one against your diff, and a
reviewer you start duplicates it at full cost and counts for nothing.

Code organization: follow the file structure in the plan and the patterns already in the
codebase. One clear responsibility per file. If a file you are creating grows past the
plan's intent, stop and report DONE_WITH_CONCERNS instead of splitting it on your own. If a
file you must edit is already large or tangled, work carefully and say so. Do not
restructure anything outside this task.

Stop and escalate (status BLOCKED or NEEDS_CONTEXT) when the task needs an architectural
decision with several valid answers, needs code you cannot understand from what you were
given, restructures existing code in a way the plan did not anticipate, or you have read
file after file without progress. Bad work is worse than no work; escalating is not
penalized. Say what you are stuck on, what you tried, and what would help.

Self-review before reporting:
- Complete: every requirement done, edge cases handled?
- Disciplined: nothing built that was not requested, existing patterns followed?
- Clear: names match what things do?
- Tested: tests verify behavior and not mocks, red before green shown, output free of
  stray warnings?

If the coordinator later resumes you with review findings: fix them, re-run the tests that
cover the amended code, and append a fix report to your report file (what you changed, the
covering tests, the command, its output). Reviewers do not re-run tests for you, so your
report is the evidence. Then reply with the same short status.

Report file: write the full report to <REPORT_FILE>:
- what you implemented (or attempted, if blocked)
- tests run and results; for a TDD task, RED (command and the failing output, why that
  failure was expected) and GREEN (command and passing output)
- files changed
- self-review findings, concerns

Then reply with ONLY, in under 15 lines:
- Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- commits (short SHA and subject)
- one-line test summary, for example "14/14 passing, output clean"
- concerns, if any
- the report file path
For BLOCKED or NEEDS_CONTEXT put the specifics in that reply itself.
Use DONE_WITH_CONCERNS when you finished but doubt correctness. Never hand over work you are
unsure about without saying so.
```
