---
name: systematic-debugging
description: Enforces root-cause-first debugging in four phases - investigate, compare with working code, test one hypothesis at a time, then fix with a failing test - and stops patching after three failed fixes to question the design. Use for any bug, failing test, build failure, flaky test, performance problem or unexpected behavior, especially under time pressure, when a quick fix looks obvious, or after a fix already failed. Do not skip it because the bug looks simple. Pairs with test-driven-development for the fix and agent-router for who investigates.
---

# Systematic debugging

**Rule: no fix before the root cause is understood.** A patch on a symptom hides the bug,
makes the next one harder to find, and usually costs more than the investigation would
have. Quick, obvious fixes are the case this rule exists for. Finish each phase before
starting the next.

## Phase 1: investigate

1. **Read the whole error.** Full stack trace, file paths, line numbers, error codes. Do
   not skim to the first line.
2. **Reproduce reliably.** Exact steps, and whether it happens every time. If it does not
   reproduce, gather more data (logs, inputs, environment); do not guess.
3. **Check what changed.** `git diff`, recent commits, new or bumped dependencies, config
   and environment differences.
4. **Instrument each boundary** when the system has several components (CI to build to
   signing, API to service to database). Log what enters and leaves every component and
   whether config and environment survive each hop. Run once; the evidence shows which
   boundary breaks. Then investigate that one.
5. **Trace the bad value backward** when the failure is deep in a call stack: what called
   this, with what value, and what called that, up to where the value first went wrong.
   Fix there, not where it surfaced. Technique in
   [references/techniques.md](references/techniques.md).

## Phase 2: compare

1. Find similar code in this repository that works.
2. If following a reference or pattern, read it completely first; no skimming and adapting.
3. List every difference between working and broken, however small. Do not decide which
   ones "can't matter" yet.
4. Note what the code depends on: config, environment, other components, assumptions.

## Phase 3: hypothesis

1. State one hypothesis in writing: "I think X is the cause because Y."
2. Test it with the smallest possible change, one variable at a time.
3. Worked: go to phase 4. Did not: revert that change, form a new hypothesis from what you
   learned. Never stack a second fix on top of a failed first one.
4. If you do not know, say so and research or ask. Do not present a guess as a finding.

## Phase 4: fix

1. **Failing test first**: the smallest reproduction, automated if the project has a test
   framework, otherwise a one-off script. Follow the `test-driven-development` skill.
2. **One fix** for the identified cause. No refactoring and no "while I'm here" changes.
3. **Verify**: the new test passes, the full suite and build pass, the original symptom is
   gone. Evidence, not assurance.
4. **If the fix failed**: count it. Fewer than three, go back to phase 1 with the new
   information. **Three or more: stop patching.**

### Three failed fixes means question the design

Signs: each fix exposes shared state or coupling somewhere else, fixes need large
refactors, every fix creates a new symptom. That is a structural problem, not a bad
hypothesis. Stop, tell the user what you tried and what each attempt revealed, and discuss
whether the pattern is sound before trying again. With `agent-router`, this is the point
to escalate the investigation to the `architect` subagent rather than another `builder` attempt.

## Red flags: stop and return to phase 1

- "Quick fix now, investigate later"
- "Let me just try changing X and see"
- Several changes at once
- Skipping the test and checking by hand
- Proposing a fix before tracing where the value came from
- A fourth attempt after three failures
- Each fix reveals a new problem in a different place
- The user asking "is that actually happening?", "stop guessing", or "what does the evidence
  show?": these mean phase 1 was skipped

## Excuses

| Excuse | Reality |
| --- | --- |
| "It's simple, no process needed" | Simple bugs have root causes too; the process is fast on them |
| "Emergency, no time" | Guess-and-check thrashing is slower than a short investigation |
| "Try this first, then investigate" | The first fix sets the direction and is rarely undone |
| "I'll write the test after it works" | A test written after the fix proves little |
| "Several fixes at once saves time" | You cannot tell which one worked, and you add new bugs |
| "I see the problem" | You see a symptom, not necessarily the cause |
| "One more attempt" (after two failures) | The pattern is the suspect, not the details |

## When there is really no root cause

If the cause is environmental, timing-dependent or external after a *complete*
investigation: document what you ruled out, add handling (retry, timeout, clear error
message), and add logging so the next occurrence carries evidence. Most "no root cause"
verdicts come from stopping early, so check the investigation was complete.

## Delegating the investigation

Reading logs and tracing callers is context-heavy. With the `agent-router` subagent templates,
send read-only digging ("find every caller of X and what each passes") to `scout`, test
and build runs to `test-runner`, and keep hypothesis and fix in the main thread or
`builder`. Several unrelated failures with different causes go to the
`dispatching-parallel-agents` skill; related ones are investigated together first. If the Cortex MCP server is connected and the
question is "did we hit this before", search it before reading code.

## Supporting techniques

[references/techniques.md](references/techniques.md): backward root-cause tracing with
stack instrumentation, defense in depth after the fix, condition-based waiting instead of
sleeps for flaky async tests.
[scripts/find-polluter.sh](scripts/find-polluter.sh): finds which test file leaves behind
an unwanted file or directory.
