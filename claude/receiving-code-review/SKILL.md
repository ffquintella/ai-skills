---
name: receiving-code-review
description: Handles code review feedback with technical rigor - verify each suggestion against the code before changing anything, ask about every unclear item first, push back with evidence when a suggestion is wrong, implement one item at a time with tests, and skip performative agreement. Use when review comments, a reviewer agent's report or a PR's inline comments arrive, before implementing any suggestion, especially when feedback is unclear, conflicts with an earlier decision or looks technically questionable ("address the review", "fix the PR comments", "the reviewer said"). Not for requesting a review (use requesting-code-review).
argument-hint: [review text | PR number]
---

# Receiving code review

Review feedback is a set of claims about the code. Some are right, some are wrong for this
codebase, some are unclear. Check each before acting; agreeing first and verifying later
produces confident, wrong changes. The same applies to a reviewer agent's report from
`requesting-code-review` and to comments from people.

## Procedure

1. **Read all of it** before reacting to any part.
2. **Restate** each item as a concrete requirement, in your own words.
3. **Verify** against the code: does the problem exist, does the cited line say what the
   reviewer thinks, is there a reason it is written this way (`git log`, `git blame`, a
   comment, a test)? Use the `graphify` graph (`graphify query|explain|affected`) when
   it exists to see what a change touches.
4. **Evaluate**: is the suggestion correct for this codebase, stack and set of supported
   versions, and does the reviewer have the full context?
5. **Respond**: a technical acknowledgment, a question, or reasoned pushback.
6. **Implement** one item at a time, testing each (see below).

## If any item is unclear, stop

Do not implement the clear items and ask about the rest later: items are often related,
and a partial reading yields the wrong change.

```
Review items 1-6. Clear on 1, 2, 3, 6. Unclear on 4 and 5.
Wrong: implement 1, 2, 3, 6 now, ask about 4 and 5 afterwards.
Right: "Understood 1, 2, 3, 6. Need clarification on 4 and 5 before I start."
```

## Who is giving the feedback

- **The user**: trusted. Implement after you understand it; ask if scope is unclear. No
  ceremony, go to the action.
- **A reviewer agent, a bot or an outside reviewer**: check before implementing. Is it
  correct here? Would it break existing behavior? Is there a reason for the current
  code? Does it hold on every platform and version we support? If you cannot verify it,
  say so: "I can't verify this without X. Investigate, ask, or proceed?"
- **Conflicts with a decision the user already made**: stop and take it to the user
  first.

## YAGNI check

When a reviewer asks for something to be "implemented properly" (full metrics, config
options, extra endpoints, abstraction layers), grep for real usage first.

- Nothing uses it: "Nothing calls this. Remove it instead (YAGNI)?" Ask rather than
  build it.
- It is used: implement it properly.

The reviewer and you both answer to the user; a feature nobody needs is a cost, not
thoroughness.

## Order of work

For multi-item feedback, after clarifying:

1. Blocking issues (breakage, security)
2. Simple fixes (typos, imports, naming)
3. Complex fixes (refactors, logic)

Each fix gets its own test run (`test-driven-development` for behavior changes: a
failing test for the reported bug first; `systematic-debugging` if a fix does not hold).
After the last one, run the full suite and build, then say what changed per item. A
batch of untested changes hides which one broke things.

## When to push back

- The suggestion breaks existing behavior or a passing test
- The reviewer lacks context (a compatibility constraint, a requirement, a prior decision)
- It is unused or speculative (YAGNI)
- It is wrong for this stack or version
- It conflicts with the architecture the user chose

How: state the technical reason, point to the code, test or commit that shows it, and
ask a specific question if you are unsure. No defensiveness, no apology. Raise it with the
user when it is an architectural disagreement. If you are wrong after checking, say
so in one line and fix it: "Checked X, it does Y, you are right. Fixing."

If a suggestion is declined for a lasting reason (a compatibility constraint, a
deliberate trade-off), `remember` it when Cortex is connected, with the file path, so
the next review does not reopen it.

## Wording

Do not write "You're absolutely right!", "Great point!", "Thanks for catching that" or any
thanks or praise. They say nothing about whether you checked. State the fix or the
finding instead:

- "Fixed: `parse()` now rejects empty input (`src/parse.rs:42`)."
- "Checked: the build targets 10.15+, this API needs 13+. Dropping it breaks pre-13
  support. Fix the bundle ID, or drop pre-13?"
- "Grepped: no caller for this endpoint. Remove it (YAGNI)?"

If you start typing "Thanks", delete it and write what changed.

## Replying on GitHub

Reply to an inline review comment inside its thread, not as a new top-level PR comment:

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies \
  --method POST -f body="Fixed in 3df7661: ..."
```

List the comments and their ids with `gh api repos/{owner}/{repo}/pulls/{pr}/comments`.
Posting a reply is visible to others: draft it and have the user approve it unless they
already told you to respond on their behalf. Resolving threads is the reviewer's call.

## Mistakes

| Mistake | Fix |
| --- | --- |
| Agreeing before checking | Verify against the code first |
| Implementing the clear items, asking later about the rest | Clarify everything first |
| Applying all changes in one batch | One item at a time, test each |
| Assuming the reviewer is right (or wrong) | Check what it breaks, check the history |
| Building "proper" features nobody uses | Grep for usage, apply YAGNI |
| Proceeding on a claim you cannot verify | Say so and ask for direction |
| Top-level PR comment in reply to an inline one | Reply in the thread |
