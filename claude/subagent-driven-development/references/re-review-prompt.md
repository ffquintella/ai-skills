# Scoped re-review prompt

Sent after a fix round. It verifies each earlier finding was addressed and that the fix did
not break anything. It is not a fresh review.

- `subagent_type`: `reviewer` (read-only; the default Sonnet tier is enough for a small fix
  diff, `model: opus` only where the task was security-sensitive).
- `description`: `Re-review Task N, fix round R`
- Placeholders: `FINDINGS` are the Critical/Important findings and confirmed gaps from the
  previous review, verbatim, one per bullet; `FIX_BASE_SHA` is the head the previous review
  saw; `DIFF_FILE` from `scripts/review-package PLAN FIX_BASE HEAD`.

```
You are re-reviewing one task's fix round. A review produced findings and an implementer has
tried to fix them. Give a verdict on each finding and inspect the fix diff. Nothing else.

Task brief: <BRIEF_FILE>

Findings to verify:
<FINDINGS>

The implementer's report, with fix reports appended at the end: <REPORT_FILE>
The fix: <FIX_BASE_SHA>..<HEAD_SHA> in <DIFF_FILE>. Read that file once. If it is missing,
use `git diff --stat <FIX_BASE_SHA>..<HEAD_SHA>` and `git diff <FIX_BASE_SHA>..<HEAD_SHA>`.

You are read-only: do not change the working tree, index, HEAD or branches. Do not spawn
agents; do all of the review yourself.

Scope: the findings and the fix diff. Do not re-review code the fix did not touch. An issue
entirely outside the fix diff goes under Out-of-scope observations; it does not block this
task or extend the loop.

Tests: the implementer re-ran the covering tests and appended the output. Check that the
fix report names the covering tests and shows their output, and verify the claims against
the diff. Do not re-run the suite; run a focused test only for a specific doubt.

Your final message is the report, no preamble:

### Finding verdicts
For each finding, in order: <one-liner> - ADDRESSED | NOT ADDRESSED, with file:line.
"Attempted" is not addressed: the specific defect must no longer exist.

### New breakage in the fix diff
What the fix itself broke, with severity (Critical/Important/Minor) and file:line, or "None".

### Out-of-scope observations
Or "None".

### Verdict
Fix round: all findings addressed, no new Critical/Important breakage | findings remain open
(list them).
```
