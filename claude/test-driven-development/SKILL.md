---
name: test-driven-development
description: Enforces red-green-refactor when implementing a feature, fixing a bug, refactoring or changing behavior - write one failing test, watch it fail for the right reason, write the minimum code to pass, then clean up. Also routes the test runs to the cheap test-runner agent so verbose output stays out of the main context. Use it before writing any production code for a change that has observable behavior, and when asked to "add tests", "fix this bug" or "do TDD". Skip for throwaway prototypes, generated code and pure configuration unless the user says otherwise.
argument-hint: [feature | bugfix | refactor] [description]
---

# Test-driven development

**Rule: no production code without a test that failed first.** A test written after the
code passes immediately, so it proves nothing about whether it can catch the bug. If code
was already written before its test, delete it and start from the test; do not keep it
"as reference" and do not adapt it while writing the test.

Applies to features, bug fixes, refactors and behavior changes. Ask the user before
skipping it for a prototype, generated code or configuration-only change.

## The cycle

### 1. Red: one failing test

- One behavior per test, named after that behavior (`rejects_expired_token`, not `test1`).
- Exercise real code. Mock only what is slow or external (network, clock, filesystem
  outside a temp dir), never the unit under test.
- Write the expected value by hand as a literal. Do not compute it with the code or the
  helpers under test.

### 2. Verify red (mandatory, never skip)

Run the narrowest filter that selects the new test and read the failure message. It must
fail because the behavior is missing, not because of a typo, a missing import or a
compile error. If it passes, the test is wrong or the behavior already exists: fix the
test. If it errors for the wrong reason, fix the test and rerun until the reason is right.

### 3. Green: minimum code

Write the simplest code that makes this test pass. No extra options, no
"while I'm here" features, no generality the test does not demand. Rerun the same filter.

### 4. Verify green

Run the **full** suite (and the build/linter if the project has one), not just the new
test. Everything passes, output is clean. If something else broke, fix it now; report
failures you did not cause instead of hiding them.

### 5. Refactor (only when green)

Remove duplication, improve names, extract helpers. No new behavior. Rerun the suite after
each step. Then start the next failing test.

## Bug fixes

First write a test that reproduces the bug and watch it fail with the symptom the user
reported. Then run the cycle. The test is the proof of the fix and the regression guard;
a fix without one is a guess.

## Delegating the runs

Test output is the biggest context cost in this loop. With the `agent-router` templates
installed, send each run to `test-runner` (Haiku) with the exact command and ask for
failures only; keep the writing of tests and code in the main thread or in `builder`.
Without it, pipe output through a filter (`| tail -40`, `| grep -E "FAIL|Error"`).

## When the test is hard to write

| Symptom | Likely meaning | Do |
| --- | --- | --- |
| Don't know how to test it | The interface is not designed yet | Write the call you wish existed, then make it so |
| Setup is huge | Too much coupling | Simplify the interface, split the unit |
| Must mock everything | Dependencies are hidden | Inject them; or use a real component in an integration test |
| Test needs production-only hooks | Test code leaking into production | Put helpers in test utilities |

## Excuses that mean "stop and restart from the test"

"Too simple to test", "I'll add tests after", "I tested it manually", "deleting this
work is wasteful", "it's about the spirit, not the ritual", "just this once". Also: a
test that passed on its first run, tests added after the implementation, code kept
"for reference". Manual testing is not repeatable; tests-after answer "what does this do"
instead of "what should this do".

## Done checklist

- [ ] Every new function or behavior has a test, and each was seen failing first
- [ ] Each failure was for the expected reason
- [ ] Minimum code was written to pass
- [ ] Full suite and build pass with clean output
- [ ] Real code is exercised; mocks only at external boundaries
- [ ] Edge cases and error paths covered

Cannot tick all boxes means TDD was skipped; go back.

## Writing honest tests

Rules for what a good test is (mutation check, change detectors, mocking discipline) are
in [references/writing-good-tests.md](references/writing-good-tests.md). Read it when
writing more than a trivial test, or when reviewing someone else's.
