# Judge briefs

Run in this order, never in parallel. Both read and edit files under `<results_dir>`.

## 1. Dedup judge

Merge findings that report the **same defect**; when unsure, keep them apart.

Tiers:
1. Same file, same line, same bug class: merge without further judgment.
2. Same function, same bug class: merge only if the code snippets show the same construct
   at nearby lines. A similar description alone is not enough.
3. Same function, different bug class: merge only when both point at the same construct and
   the same attacker-controlled input. Default is not to merge.
4. Same pattern in different files or functions: never merge; list under "related" in the
   summary.

Never merge across files. Findings with no parseable location or no enclosing function skip
tiers 2 and 3.

Choosing the primary: a finding that already absorbed others stays primary; else higher
confidence wins; else the smallest ID. Raise the primary's confidence to the group's
highest. If two findings have both absorbed others, leave them unmerged.

Write: `merged_into: <primary id>` on each non-primary; `also_known_as` (absorbed IDs) and
`locations` (own plus merged, deduplicated) on the primary. Leave the primary's `location`
unchanged, never delete a file, skip findings already marked `merged_into` (so reruns are
safe). Write `dedup-summary.md`: merges by tier, related groups, counts per bug class of
surviving primaries.

## 2. False-positive and severity judge

For every primary finding set `fp_verdict` and a one-paragraph rationale in the file:

| Verdict | Meaning |
| --- | --- |
| `TRUE_POSITIVE` | Real, reachable within the threat model |
| `LIKELY_TP` | Real; reachability unclear but plausible. Prefer this to `LIKELY_FP` when unsure |
| `LIKELY_FP` | Bug-shaped, but the defined attacker cannot reach it |
| `FALSE_POSITIVE` | Not a bug; the worker misread the code |
| `OUT_OF_SCOPE` | Real, but needs capabilities beyond the threat model |

Real hardening gaps (missing lint config) are `TRUE_POSITIVE` at LOW, not false positives.
A merged group shares one verdict; if any framing of the bug is real and reachable, it
survives.

Threat model: `REMOTE` = network access only, so local-only triggers are out of scope;
`LOCAL_UNPRIVILEGED` = shell user without privileges, so same-user bugs crossing no
boundary are likely false positives; `BOTH` = judge each vector, take the higher result.

Severity (only for `TRUE_POSITIVE`/`LIKELY_TP`; the threat model verdict wins over this
table):

| | Remote | Local unprivileged |
| --- | --- | --- |
| CRITICAL | code execution, auth bypass | root escalation, sandbox escape |
| HIGH | remote DoS on attacker input (panic, overflow, exhaustion) | read or alter other users' data |
| MEDIUM | DoS under narrow conditions | local DoS, limited boundary crossing |
| LOW | theoretical, hardening | minimal boundary crossing |

Move one level up or down for: a valid safety invariant, existing mitigations, a race
window, non-default configuration, crypto or deserialization exposure, public API
reachability. Also set `attack_vector` (`Remote|Local|Both`), `exploitability`
(`Reliable|Difficult|Theoretical`) and a severity rationale.

Then write `fp-summary.md` (verdict counts derived from the files on disk, per-finding
verdicts, recurring false-positive patterns) and `REPORT.md` grouped by severity, honoring
`severity_filter` (`all|medium|high`). Write `REPORT.md` with a shell heredoc. Confirm both
`REPORT.md` and the SARIF step's inputs exist before reporting success.
