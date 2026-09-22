---
name: cortex-memory
description: Decides when persistent memory is worth reading or writing, which Cortex tool to search with, how to phrase the query, when to run consolidation as a background job, and when a memory should be corrected, demoted or deleted. Targets the Cortex MCP server (hypermnesia-mcp) on its default local SQLite store. Use it before answering "what did we decide / did we hit this before", before storing a decision or lesson, when recall returns stale or wrong results, when memory looks bloated, and when Cortex itself needs to be installed or diagnosed. Trigger words: cortex, memory, remember, recall, consolidate, forget, hypermnesia, memory.db.
argument-hint: [recall | write | cleanup | fix | install | diagnose] [topic]
---

# Cortex memory (OpenAI Codex edition)

Cortex is a local-first memory MCP server (`hypermnesia-mcp`, repo
[cdeust/Cortex](https://github.com/cdeust/Cortex)). Codex has a native plugin with a
10-tool `lean` surface; direct MCP registration exposes all tools instead. Neither
option adds Claude Code's lifecycle hooks, so recall, writes and consolidation happen
only when explicitly called.

Default store: **SQLite**, one file at `~/.claude/methodology/memory.db` (plus `-wal` /
`-shm`). PostgreSQL + pgvector is opt-in and changes nothing about the tool contract.
The selected backend is recorded in `~/.claude/methodology/backend.json`, and Claude Code
and Codex read the same marker, so both hosts share one store.

The native plugin exposes tools as `mcp__plugin_hypermnesia-mcp_cortex__<tool>`; direct
registration as `cortex` exposes `mcp__cortex__<tool>`. This document writes them bare
(`recall`, `consolidate`, …). The full catalogue is in
[references/tools.md](references/tools.md).

## Step 0: is Cortex actually there

One smoke test, not a ritual: call `memory_stats`. It succeeds only if the store is
reachable, and it works on both backends. If the tool is missing from the session, Cortex
is not installed — see [Installing](#installing). If it is present but errors, see
[Diagnosing](#diagnosing). Never run `pg_isready` or any PostgreSQL setup on a failure:
the default install has no PostgreSQL.

## Step 1: decide whether this is a memory moment

Reading memory costs a tool call and context; writing costs store noise. Both are cheap
individually and expensive as a habit.

| Situation | Do |
| --- | --- |
| The question is about the past ("what did we decide", "have we hit this", "why is X like this") | **Search** — this is what the store is for |
| Starting work in an area with likely history (a subsystem, a recurring bug, a migration) | **Search once**, up front, before reading files |
| The answer is fully derivable from the code, `git log`, or the current context | **Neither** — the repo is authoritative, memory is not |
| A decision was made with a reason that will not survive in the diff (why Redis and not in-process TTL, why this endpoint stays synchronous) | **Write** with `remember` |
| A non-obvious fix, a dead end that cost real time, or a correction from the user | **Write** |
| Routine progress, restating a file's contents, "we added a test" | **Do not write** — the auto-capture hook already sees tool output, and hand-writing noise buries the memories that matter |

Writes pass a local novelty gate: a near-duplicate is merged into the memory it restates
rather than filed beside it. Deliberate `remember` calls are never rejected for being
unsurprising, so the gate is not a licence to write everything.

## Step 2: search — pick the tool before phrasing the query

| Tool | Use it for | Notes |
| --- | --- | --- |
| `recall` | the default: one natural-language question | 6-signal fusion; the intent classifier routes semantic / temporal / causal / entity queries itself |
| `unified_search` | one query across memories **and** the code graph, plus authored wiki pages when `project_root` is passed | merges both rankings; falls back to memories only when the code pipeline is off or unreachable |
| `recall_hierarchical` | a broad topic you want summarised, then drilled into | pair with `drill_down` on the cluster that matters |
| `get_causal_chain` | "what caused X", "what does X depend on" | traverses typed entity edges, `direction: forward / backward / both` |
| `navigate_memory` | "what else is always read together with this memory" | co-access paths from a known `memory_id` |
| `recall_skills` | past *procedures* rather than facts | |
| `why` | which memories were actually present in context for an answer | resolves the `⟦rcpt:N⟧` markers; the `/why` command does this deterministically |
| `memory_stats`, `detect_gaps` | before trusting silence — population counts, and which entities/domains are thin or drifting | `assess_coverage` scores the store's shape (quantity, age, entity density, domain balance), not how well one topic is covered |

Query habits that pay off:

- **Ask a question, not keywords.** "Why did the deploy fail after the Redis switch" beats `redis deploy fail`. The classifier needs a shape to route.
- **Narrow with filters, not with words.** Keep the question natural and pass `domain` (project) and `tags` instead of stuffing qualifiers into the text.
- **One broad search beats three narrow ones.** Start at `limit: 10`; re-query only if the result set is clearly off-topic, and change the *angle*, not the synonyms.
- **Read the provenance grade before acting.** A memory graded `unverifiable` named references that no longer resolve on this machine. `verified` means its references resolve locally — not that the claim is true.
- **Check for supersession.** A memory that was corrected is demoted, not deleted; if a result carries `superseded_by_id`, follow it before quoting the old one.
- **Verify before recommending.** Memory records what was true when it was written. If a memory names a file, a flag or a function, confirm it still exists before acting on it.
- **Empty is a result.** If `recall` returns nothing, say the store has nothing rather than inventing continuity; `detect_gaps` tells you whether the area is thin or simply absent.
- **Recall is not free of side effects.** It records access and bumps heat, which is how the store learns what matters — so search deliberately, not in a loop.

## Step 3: background cleanup

`consolidate` is the maintenance pipeline: heat decay, staged compression (full text →
gist → tags), episodic → semantic promotion, causal-edge discovery, and replay that
strengthens clusters. Nothing in the hooks runs the full pipeline for you — session hooks
capture and checkpoint, they do not decay or compress on a schedule.

**When to run it**

- after a bulk import (`import_sessions`, `backfill_memories`, `seed_project`, `ingest_document`)
- at the end of a long, memory-heavy session
- weekly, as routine hygiene
- whenever `memory_stats` shows most memories still hot, or recall keeps surfacing the same stale cluster

Check first, then run: `get_grooming_health` reports backlog and staleness per leg, so a
run that is not due can be skipped.

```
consolidate({})
```

**Where to put the recurring job.** There is no built-in scheduler. In order of how much
setup they cost:

1. **Claude Code scheduled task** (simplest, and the one to reach for): create a weekly task whose prompt is "call the Cortex `consolidate` tool, then report `memory_stats` and `get_grooming_health`". Ask for `/schedule`, or use the `scheduled-tasks` MCP tools if the session has them. It runs in a real session, so the MCP server is already wired.
2. **cron / launchd calling headless Claude Code**: `claude -p "Run the Cortex consolidate tool and summarise memory_stats"` on a weekly timer. Use this when the machine should groom even if nobody opens the app. Pick a low-traffic slot — Cortex's own reference schedule is Sunday 03:00 — and expect the job to skip itself while an interactive session is live.
3. **The upstream groomer** (advanced, source checkout only): `scripts/groomer.py` in a clone of the Cortex repo drains the wiki and distillation legs via headless `claude -p` children, with a launchd template at `scripts/com.cortex.scheduled-groomer.plist`. Dry-run is the default; `--apply` additionally requires `CORTEX_HEADLESS_AUTHORING=1`. It spends real money — budget caps default to $5 per leg, so up to ~$10 and ~10 minutes per run. Only worth it for a large, wiki-heavy store, and read `docs/groomer-scheduling.md` in the repo first.

Do not schedule `consolidate` more often than weekly. Its own staleness threshold is six
days; running it hourly just re-cools memories you are still using.

## Step 4: wrong, stale or unwanted memories

Match the remedy to the failure — deletion is the last option, not the first.

| What is wrong | Do this |
| --- | --- |
| Still true, just not useful in results | `rate_memory` with negative feedback. Cheapest signal, and it improves ranking without losing the record. |
| Outdated — the decision changed | `remember` the new decision. Corrections supersede: the new memory records what it replaces, the old is demoted, the chain stays readable. Do **not** delete the old one; the chain is the audit trail. |
| Claims files or symbols that no longer exist | `validate_memory` to confirm the dead references, then supersede it with a rewrite against paths that resolve. |
| Genuinely wrong, never was true, or plain junk | `forget({memory_id, hard: false})` — soft delete sets heat to 0, so it stops surfacing but remains inspectable. |
| Secret, personal data, or content that must not exist on disk | `forget({memory_id, hard: true})`. Irreversible. Protected memories also need `force: true`. |
| Should never decay | `anchor` it — protection survives consolidation. |

Before a batch of deletions, take a `checkpoint`; it is the only undo. And when the user
challenges an answer, resolve `⟦rcpt:N⟧` markers with `why` first — often the memory is
fine and the retrieval was wrong, which `rate_memory` fixes and `forget` does not.

Deleting the whole store is always available and always a last resort: the SQLite file is
yours, and removing `~/.claude/methodology/memory.db*` starts over from empty.

## Installing

Claude Code (adds the marketplace, installs the plugin, runs the dependency + SQLite
post-install step):

```bash
claude plugin marketplace add cdeust/Cortex
claude plugin install hypermnesia-mcp
```

Requirements: Python 3.10+ and `uv`/`uvx` on PATH. First use creates
`~/.claude/methodology/memory.db` and downloads the embedding and reranking models once;
after that it runs offline. An existing PostgreSQL configuration is detected and kept, never
silently downgraded.

Other stdio MCP hosts run the same PyPI package — the `[sqlite]` extra enables sqlite-vec
vector search:

```bash
uvx --from "hypermnesia-mcp[sqlite]" hypermnesia-mcp
```

Codex has a native plugin exposing a 10-tool `lean` surface
(`remember`, `recall`, `unified_search`, `recall_hierarchical`, `consolidate`,
`memory_stats`, `check_setup`, `wiki_read`, `wiki_list`, `query_methodology`); the direct
registration below gives it all 57 tools instead:

```bash
codex mcp add cortex --env CORTEX_MEMORY_STORE_BACKEND=sqlite -- hypermnesia-mcp
```

If a machine still has the pre-4.15 plugin identity, the rename is
`claude plugin uninstall cortex` then `claude plugin install hypermnesia-mcp`; memories and
storage paths are untouched.

## Diagnosing

Two entry points, in this order:

1. **`/preflight`** — the shipped command. It runs the Cortex doctor and turns each failing check into the exact repair command the doctor itself proposes, ordered by dependency (Python → driver → URL → connection → extensions → filesystem). Pass the symptom as an argument. Never invent a repair the doctor did not print.
2. **`check_setup`** — backend-aware diagnostics over MCP, for when shell access is not available or the doctor cannot start.

Common failures on the SQLite default:

| Symptom | Likely cause |
| --- | --- |
| No Cortex tools in the session | The native plugin or direct MCP registration is missing, or the session predates the install — restart it |
| Server fails to start | `uv`/`uvx` or Python 3.10+ missing from PATH, or the post-install dependency step never completed: re-run `bash <plugin-dir>/scripts/install-plugin.sh` |
| `memory_stats` errors | Permissions on `~/.claude/methodology`, or a corrupt `memory.db` |
| Huge `memory.db-wal`, slow recall | A WAL that never checkpointed, or a store that has not been consolidated — run `consolidate` |
| Writes land somewhere unexpected | Backend mismatch: check `~/.claude/methodology/backend.json` and any `CORTEX_MEMORY_STORE_BACKEND` / `CORTEX_BACKEND` / `DATABASE_URL` in the environment, which override it |
| Vector search silently absent | Installed without the `[sqlite]` extra — the store works, sqlite-vec does not |

Logs and state live beside the database: `consolidate.log`, `telemetry.jsonl`,
`session-log.json`, `backend.json` in `~/.claude/methodology/`. Everything is local; nothing
is sent anywhere.

## Habits

- Search before reading files when the topic is likely to have history; one `recall` is cheaper than three greps.
- Write few memories, each with the reason attached. The store's value is in what it *does not* contain.
- Treat every recalled claim as "true when written" and verify anything you are about to act on.
- Prefer superseding over deleting: a corrected chain teaches, a hole does not.
- Consolidate weekly, from a scheduled job, not by hand at random.
