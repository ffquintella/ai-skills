---
name: verification-before-completion
description: Gates every claim of success behind fresh evidence - identify the command that proves the claim, run it now, read the full output and exit code, then state the claim together with what you saw. Covers "tests pass", "build succeeds", "linter clean", "bug fixed" (reproduce the original symptom), "subagent completed" (check the diff, not the report) and "requirements met" (line-by-line checklist). Use before saying work is done, fixed or passing, before committing, opening a PR, moving to the next task or reporting a delegated result, and whenever you catch yourself writing "should work", "probably" or "looks correct". Not needed for pure questions or for work that makes no claim about state.
---

# Verification before completion

**Rule: no claim that work is done, fixed or passing without evidence from a command run
in this turn.** A claim without a fresh run is a guess, and an earlier run only proves
the tree as it was then. Wording does not change this: "should pass", "looks good" and
"I'm confident" are claims too.

## The gate

Before saying anything about status, in this order:

1. **Identify** the command that would prove the claim. If you cannot name one, the claim
   cannot be made yet.
2. **Run** the full command, fresh. Not a subset, not a cached result, not the run from
   before the last edit.
3. **Read** the whole output and the exit code. Count the failures; do not stop at the
   first green line.
4. **Compare** the output with the claim. If it does not confirm it, report the real
   status with the output as evidence. If it does, state the claim and quote the evidence
   (`34 passed, 0 failed, exit 0`).

Only then speak. Report an unmet claim as plainly as a met one.

## What each claim needs

| Claim | Needs | Not enough |
| --- | --- | --- |
| Tests pass | Test command output with 0 failures | A previous run, "should pass" |
| Linter clean | Linter output with 0 errors | A partial run, extrapolating from tests |
| Build succeeds | Build command exit 0 | Linter passing, logs that look fine |
| Bug fixed | The original symptom no longer reproduces | Code changed, so assumed fixed |
| Regression test works | Red-green seen: passes, fails with the fix reverted, passes again | It passed once |
| Subagent completed | The diff shows the changes you asked for | The subagent reported success |
| Requirements met | A line-by-line check against the plan or request | Tests passing |

## Patterns

- **Bug fixed**: rerun the exact reproduction the user gave (the failing command, request
  or test). If there was none, write one first; see `systematic-debugging` and
  `test-driven-development`.
- **Regression test**: write it, run it green, revert the fix, run it and watch it fail,
  restore the fix, run it green. Without the red step it may test nothing.
- **Requirements**: re-read the plan or request, list each requirement, check each against
  the code or an output, then report the gaps or completion. Passing tests do not cover a
  requirement nobody wrote a test for.
- **Delegated work**: a subagent's report says what it intended. Read `git diff` (and
  `git status` for new files), run the verification yourself, then report the actual
  state. See `subagent-driven-development` for the review loop.

## Delegating long runs

Full test suites and builds produce the output that floods the main context. With the
`agent-router` subagent templates installed (`.codex/agents/`), spawn `test-runner` with
`agent_type`, `fork_turns: "none"`, an explicit `model` and `reasoning_effort`, the exact
command, and a request for the exit code and failures only. Wait with `wait_agent` (5 to 10
minute timeouts), not short polls. The evidence still has to come from that run, and you
quote it. Without the templates, filter in the shell (`| tail -40`,
`| grep -E "FAIL|Error"`) and keep the exit code (`; echo "exit $?"`, or `set -o pipefail`).

## Red flags

Stop and run the check when you notice:

- "should", "probably", "seems to", "I think it works"
- Satisfaction before verification ("Done!", "Perfect!")
- About to commit, push or open a PR with no run since the last edit
- Trusting a subagent's success message
- A partial check offered as the whole one ("linter passed" for a build claim)
- Tiredness or "just this once"

## When it applies

Before any success or completion statement, however phrased; before committing, opening a
PR, ending a task or moving to the next one; and before handing work to another subagent as
finished. `finishing-a-development-branch` calls this gate as its first step.

If the check cannot be run (no network, missing tool, no test for it), say exactly that and
what remains unverified; do not substitute a weaker check and call it done.
