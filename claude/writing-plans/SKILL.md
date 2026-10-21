---
name: writing-plans
description: Turns an approved spec or design into a bite-sized implementation plan that an agent with no context can execute - exact file paths, interfaces, a failing test first per task (test-driven-development), exact commands with expected output, a commit per task, and a suggested agent-router tier per task (routine to builder, complex to architect) - then self-reviews it against the spec and offers subagent-driven-development or executing-plans. Use when there is a spec, design document or clear requirements for a multi-step task and before touching code - "write the plan", "plan this out", "break this into tasks", right after brainstorming. Skip for a one-file change that fits in one sentence, and when there is no approved design yet (use brainstorming first).
argument-hint: [path to spec or design document]
---

# Writing plans

Write the plan for an engineer (or agent) who has not seen this codebase or this spec. They
write idiomatic code once they know the exact interface and the exact test, and they make a
reasonable choice wherever the plan leaves one open. What they cannot know is what you
decided: which files, which names and signatures, which values from the spec, which tests
prove each task. Document those, as bite-sized tasks. DRY, YAGNI, tests first, frequent
commits.

Announce at start: "I am using the writing-plans skill to create the implementation plan."

Input is an approved spec from `brainstorming`. Without one, stop and run `brainstorming`
first. If the work will happen in an isolated worktree, `using-git-worktrees` creates it at
execution time, not now.

Save the plan where AGENTS.md / CLAUDE.md says, else `docs/plans/YYYY-MM-DD-<feature>.md`.
The user's preference overrides both. Fill in [references/plan-template.md](references/plan-template.md).

## Step 1: scope check

If the spec covers several independent subsystems, suggest one plan per subsystem; each plan
should produce working, testable software on its own.

## Step 2: map the files

Before defining tasks, list every file to create or modify and what each is responsible for;
this locks in the decomposition.

- One clear responsibility per file, with a well-defined interface.
- Files that change together live together; split by responsibility, not by layer.
- In an existing codebase follow its patterns. Do not restructure on your own, but if a file
  you must change has grown unwieldy, a split in the plan is reasonable.
- For "where is X" and "what does this touch", query `graphify-out/` first when it exists
  (`graphify query|explain|path|affected`); for earlier decisions, `recall` when Cortex is
  connected.

## Step 3: cut the tasks

A task is the smallest unit that carries its own test cycle and is worth a fresh reviewer's
gate. Fold setup, configuration, scaffolding and documentation into the task whose
deliverable needs them; split only where a reviewer could reject one task and approve its
neighbor. Each task ends with an independently testable deliverable.

Each step is one action with a checkable result:

1. Write the failing test.
2. Run it and confirm it fails for the right reason.
3. Implement the minimum to pass.
4. Run it and confirm it passes.
5. Commit.

The test-first cycle is `test-driven-development`; the plan only sequences it. For work with
no observable behavior (configuration, generated code, docs) replace steps 1 to 2 with the
verification command that proves the change.

What a step contains, and nothing more:

- **Test step**: the test's name and its assertions as code, with the spec's exact values.
- **Code step**: the exact signature (name, parameters, return type), the file, and the
  values the spec pins. The implementer writes the body; a body appears only for an
  algorithm the signature and tests do not determine, or for exact copy the spec fixes.
- **Verification step**: the command to run and the output that means it passed.
- **Reference to another task**: say which task; its Interfaces block carries the names, so
  do not repeat its code.

A plan is the set of decisions the implementer cannot make alone. A plan longer than the
code it describes has written the code instead. Lines that decide nothing ("TBD", "handle
edge cases", "add appropriate validation", "write tests for the above", a type or function
no task defines) are the opposite failure.

## Step 4: assign a tier to each task

Give every task a suggested tier from `agent-router`, so `subagent-driven-development` can
route it without re-deciding:

| Task | Tier | Agent |
| --- | --- | --- |
| Clear scope, 1 to 3 files, an existing pattern to copy | routine | `builder` |
| Multi-file, new abstraction, unclear approach, or security-sensitive (authentication, secrets, configuration schema, composition root) | complex | `architect` |

State it as a line under the task title (`**Tier:** routine (builder)`) with a short reason
when it is not obvious. It is a suggestion: the router decides at execution time, and a task
that fails at its tier escalates one step. Projects without the agent templates use a
general-purpose agent with the `model` from the `agent-router` fallback table (the effort
cannot be set on that path).

## Step 5: write the document

Use the header and task layout in [references/plan-template.md](references/plan-template.md):
goal, architecture, spec path, global constraints copied verbatim from the spec, and a Review
Focus list of the five inputs or failure modes the spec implies but no task tests yet (each
gets a test in the task that owns the code).

## Step 6: self-review

Run this checklist yourself, with the spec in front of you; it is not a subagent job. Fix
issues inline, no re-review needed.

1. **Spec coverage**: can you point to a task for every requirement? Add tasks for gaps.
2. **Step scan**: each step lets the implementer write exactly one reasonable thing. A line
   that decides nothing is a gap; a body the signature and tests already determine is a
   transcript. Fix both.
3. **Type consistency**: names, signatures and properties in later tasks match earlier ones
   (`clearLayers()` in Task 3 and `clearFullLayers()` in Task 7 is a bug).
4. **Review Focus**: every failure mode listed has a test in the task that owns it.
5. **Proportion**: a plan several times longer than its spec is a transcript. If code blocks
   are most of the document, cut bodies down to signatures, test names and assertions.
6. **Tiers**: every task has one, and none marked routine touches more than three files.

If a rejected suggestion or a design call should outlive the session, `remember` it when
Cortex is connected.

## Step 7: hand off

Link the plan and ask the user to review it before anything is built. Then offer the
execution method, with a recommendation and one sentence of reason drawn from the plan (how
much tasks depend on each other's interfaces, how many there are, what a shipped mistake
would cost):

- **`subagent-driven-development`** (recommended when agents are available): a fresh agent
  implements each task, routed by its tier, and a fresh reviewer checks it before the next
  starts. Thorough; costs a fresh context per task.
- **`executing-plans`** (inline): the coordinator implements every task in this session,
  checking in at the review points. Cheapest; no independent review until the end.

If the user already named a method, ask only whether the plan captures what they want, and
wait for that answer before implementing. Then invoke the chosen skill and no other.
