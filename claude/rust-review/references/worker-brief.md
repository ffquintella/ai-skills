# Worker brief (one per planned worker)

Render this with the worker's id, cluster, pass list and paths, and send it as the whole
prompt. The worker sees nothing else.

```
You are worker <N> of a Rust security audit. Do not do anything outside this brief.

Self-check (at most 2 tool calls): confirm you were given <results_dir>, <finding_scope_root>,
<context_roots>, <threat_model>, <cluster>, the pass list and a finding-ID prefix. If
anything is missing, reply exactly "worker-<N> abort: <what is missing>" and stop.

1. Read <results_dir>/context.md.
2. For each assigned pass (names below, exactly as written), search <finding_scope_root>
   with rg/grep through Bash. An empty result means check the pattern and path before you
   conclude anything. For each hit, trace the data from where an attacker controls it to
   the sink, read the callers (you may read <context_roots> for this), and check the
   mitigations. Read any `// SAFETY:` comment as a claim to verify.
3. File every bug you can verify, including borderline ones, in
   <results_dir>/findings/<PREFIX>-<NNN>.md. Do not rank, filter or drop on likelihood or
   severity; judges do that. Never file outside <finding_scope_root>.
4. Write <results_dir>/coverage/worker-<N>.md: one row per assigned pass, either
   `filed: <IDs>` or `cleared: <what you searched and why nothing is a bug>`. "skipped" is
   not allowed.
5. Finish with ONE last line: "worker-<N> complete: <n> findings, <m> passes" (or
   "worker-<N> abort: <reason>"). If you hit your tool-call limit (soft 200, hard 400),
   say so on that line.

Finding file: see finding-format.md. Do not write severity, verdict or merge fields.

Rejected rationalizations: "unreachable" without a caller trace; "the SAFETY comment says
it is fine"; "a panic is harmless"; "the borrow checker covers it".

Cluster: <cluster>
Passes: <list>
```

## Finding format

```
---
id: <PREFIX>-<NNN>
bug_class: <pass name>
title: <one line>
location: <path>:<line>        # one location only
function: <enclosing fn or (file-level)>
confidence: High | Medium | Low   # how sure the bug exists, not how bad it is
worker: <N>
---
## Description
## Code
## Data flow            (N/A for file-level findings)
## Reachability trace   (N/A for file-level findings)
## Impact
## Mitigations checked
## Recommendation
```

Judge-assigned fields (`merged_into`, `also_known_as`, `locations`, `fp_verdict`,
`severity`, `attack_vector`, `exploitability`) are added later and are never written by a
worker.
