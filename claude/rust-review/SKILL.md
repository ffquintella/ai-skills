---
name: rust-review
description: Deep, multi-agent security review of a Rust codebase - unsafe and FFI boundaries, memory safety, concurrency, panic and recursion denial of service, async runtime mistakes, error handling and logic bugs - using parallel workers per bug-class cluster, then a dedup pass and a false-positive and severity pass, producing REPORT.md and SARIF. Expensive, so use it ONLY when the user explicitly asks for a Rust security review or audit (for example "/rust-review", "audit this crate for unsafe bugs"). Never start it on your own for ordinary review, bug fixing or feature work; use the reviewer agent for that. Not for C/C++, smart contracts or secret zeroization.
argument-hint: [scope subpath]
disable-model-invocation: true
---

# Rust security review

An audit, not a review. It fans out one worker per bug-class cluster, so a run is tens of
agent invocations and can take a long time and a lot of tokens. **Run it only because the
user asked for it by name or described a Rust security audit.** If you reached this skill
without that request, stop and offer it instead of starting. Everyday review of a diff
belongs to the `reviewer` agent.

Method and bug-class coverage adapted from Trail of Bits' `rust-review` plugin (see
[references/sources.md](references/sources.md)).

## Not for

- Pure C/C++ (use a C review), Solana/NEAR/Ink! contracts, secret-memory hygiene such as
  zeroization.
- Kernel-mode Rust: coverage is advisory only; say so in the report.

## Step 1: parameters

Take them from the request where stated, and ask once, together, for the rest. Do not
invent defaults for the first three.

| Parameter | Values | Meaning |
| --- | --- | --- |
| `threat_model` | `REMOTE`, `LOCAL_UNPRIVILEGED`, `BOTH` | Who the attacker is: network only, an unprivileged local user, or either |
| `worker_model` | `haiku`, `sonnet`, `opus` | Model for the cluster workers; judges use `sonnet` or better. Suggest `sonnet`, `opus` for a crypto, parser or sandbox crate. This skill fans out general-purpose workers and does not use the `agent-router` templates, so the choice is the user's: pass the alias exactly as given, and never fall back to the session model |
| `severity_filter` | `all`, `medium`, `high` | Minimum severity shown in the report |
| `scope_subpath` | optional path | Findings may be filed only inside it. Everything else (default `.`) is read-only context for callers and reachability |

Before spawning, tell the user the number of workers the plan produced (Step 3) and wait
for a go-ahead.

## Step 2: probe and context

1. Confirm `*.rs` files exist in scope, then run
   `scripts/probe.sh <scope>`. It prints capability flags (`has_unsafe`, `has_ffi`,
   `has_concurrency`, `has_async`, `has_packed_repr`, `has_fs_io`). The probes are
   deliberately permissive: a false positive only adds a worker.
2. Create `.rust-review-results/<UTC timestamp>/` with `findings/` and `coverage/`
   (suggest adding the folder to `.gitignore`).
3. Write `context.md` there: parameters and flags in frontmatter; body with purpose,
   scope, entry points, trust boundaries, existing hardening (fuzzing, Miri,
   `cargo-audit`, `#![forbid(unsafe_code)]`, lint config). Workers read it first.

## Step 3: plan the workers

Clusters, their gates and bug classes are in
[references/clusters.md](references/clusters.md). Select every cluster whose gate is
`always` or whose flag is true; do not drop a cluster because `unsafe` looks rare or
because the borrow checker is assumed to cover it. Plan one worker per cluster, with
these splits:

- `unsafe-boundary` and `concurrency-locking`: never split (their passes need each other's
  context).
- `recursion-dos`: one pass per worker.
- Any other cluster with more than about 5 passes in a large scope: split into two workers
  by passes.

Write the plan to `plan.json` (worker id, cluster, passes) and render each worker's brief
from [references/worker-brief.md](references/worker-brief.md) into `worker-prompts/`.

## Step 4: run the workers

- One message per wave with all the worker calls in it, up to 8 per wave (Claude Code
  `general-purpose` agent with the `worker_model` as `model`), in the **foreground**.
  Background agents auto-deny permission prompts and may report writes that never happened.
- Findings and coverage are files; each worker's reply is one completion line.
- Classify each reply: `complete`; `abort` for a missing field (a bug in the brief: fix
  and rerun once); or a failure (error, hard cap hit). Retry a failed worker once after
  deleting its partial output.
- After a worker completes, check its coverage file has a `filed` or `cleared` row for
  every assigned pass (`skipped` is invalid) and that the finding IDs it lists exist.
  Build `findings-index.txt` from the finding files on disk, not from what workers claim.

## Step 5: judges, in sequence

Never in parallel: the second reads the first's output. Briefs in
[references/judges.md](references/judges.md).

1. **Dedup judge**: merges findings that report the same defect. Biased to keep apart.
2. **FP and severity judge**: verdict per primary finding against the threat model,
   severity for the real ones, then `fp-summary.md` and `REPORT.md`.

Run both even when there are no findings; a zero-finding run still produces the full
artifact set.

## Step 6: report

1. Run `python3 -I scripts/generate_sarif.py <results-dir> <severity_filter>`; it always
   overwrites `REPORT.sarif` and includes the same set `REPORT.md` shows.
2. If the judge did not write `REPORT.md`, synthesize it from the finding files. Findings
   that were never judged are kept and labelled **unvalidated**; a strict severity filter
   must not hide them silently.
3. Return the path of `REPORT.md`, the counts per severity, and the artifacts list.
   **Disclose anything partial**: failed or truncated workers, unscanned clusters, scope
   limits. Never call a partial run complete.

Artifacts: `context.md`, `plan.json`, `worker-prompts/`, `findings/`, `findings-index.txt`,
`coverage/`, `dedup-summary.md`, `fp-summary.md`, `REPORT.md`, `REPORT.sarif`.

## Rules that keep it honest

- Search with `rg`/`grep` through Bash (agents holding Bash do not get Glob/Grep). An empty
  search result is not a clean bill: check the pattern and the path first.
- Workers file every bug they can verify, including borderline ones, and never filter by
  severity; the judges do that.
- A `// SAFETY:` comment is a claim to check, not a reason to skip.
- "Not reachable" needs a caller trace, not an assumption.
- Run this skill's cost past the user again if scope or `worker_model` changes mid-run.
