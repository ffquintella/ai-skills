# Sources

Adapted (rewritten, not copied) from the `rust-review` plugin in
[trailofbits/skills](https://github.com/trailofbits/skills/tree/main/plugins/rust-review)
(README, `SKILL.md`, `prompts/clusters/manifest.json`, and the worker, dedup-judge and
fp-judge agents), read 2026-10-08. Authors of the original: Andrea Cappa (Aptos Labs) and
Pawel Platek (Trail of Bits); its bug-class coverage derives from RustSec advisories and
their audits.

Changes: the Python run planner is replaced by a manual plan from `references/clusters.md`
plus `scripts/probe.sh`; the 55 per-class finder prompts are replaced by one-line pass
descriptions and a shared worker brief (so the passes are less detailed than upstream);
cache-primer and task-ledger bookkeeping dropped; judges condensed into
`references/judges.md`; `scripts/generate_sarif.py` written from scratch. The skill is
user-invoked only. Not ported: the upstream test suite and artifact validator.
