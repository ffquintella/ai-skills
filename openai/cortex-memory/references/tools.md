# Cortex tool catalogue

All tools are exposed as `mcp__plugin_hypermnesia-mcp_cortex__<name>` on Claude Code
(57 tools, `full` profile). The Codex plugin ships a 10-tool `lean` profile:
`remember`, `recall`, `unified_search`, `recall_hierarchical`, `consolidate`,
`memory_stats`, `check_setup`, `wiki_read`, `wiki_list`, `query_methodology`.

Descriptions below are condensed from the handlers' own schemas in
`hypermnesia-mcp` 4.23.1.

## Write

| Tool | What it does |
| --- | --- |
| `remember` | Store a memory through the 4-signal predictive-coding write gate. Near-duplicates merge into what they restate; corrections supersede the memory they replace. |
| `anchor` | Mark a memory compaction-resistant: heat 1.0, protected, importance 1.0, `_anchor` tag. Survives decay, consolidation pruning, and cannot be deleted without `force`. |
| `checkpoint` | Save or restore working state (`action: save` / `restore`). The undo before a risky batch. |
| `record_session_end` | Close out a session against a domain. Fired by the SessionEnd hook on Claude Code. |

## Search and retrieve

| Tool | What it does |
| --- | --- |
| `recall` | The default search. Ranked memories, best at index 0; `format: "tabular"` for a compact column form. Records access and bumps heat. |
| `unified_search` | Runs recall and the code-graph search in parallel, merged by reciprocal-rank fusion (k=60), with `source_ranks` on every hit. Adds authored wiki pages when `project_root` is passed. Falls back to memories only when the code pipeline is disabled or unreachable. |
| `recall_hierarchical` | Fractal clusters instead of a flat list — start broad here, then `drill_down`. |
| `drill_down` | Descend one level into a cluster id of the form `L<level>-<index>`: L2 → L1 sub-clusters, L1 → the memories themselves. |
| `recall_skills` | Learned procedures (recurring successful tool sequences) applicable to the current domain, cwd and recent actions. |
| `why` | Presence-in-context evidence for `⟦rcpt:N⟧` receipt markers: which memories were injected, when, at what rank. Evidence of presence, never of causation. |

## Navigate the graph

| Tool | What it does |
| --- | --- |
| `get_causal_chain` | Bounded BFS over entities and typed relationships from a seed entity (or every entity in a memory): causation, dependency, resolution. |
| `navigate_memory` | Successor-representation walk over temporal co-access: memories read together within `window_hours` become weighted edges. |
| `narrative` | A coherent story for a directory or domain — clusters by topic and time, renders the through-line (`brief: true` for one paragraph). |
| `get_project_story` | Chronological chapters over a window (day / week / month / all) — a retrospective timeline rather than a theme. |
| `explore_features` | Active sparse-dictionary behavioural features. |

## Maintain

| Tool | What it does |
| --- | --- |
| `consolidate` | The maintenance pipeline: heat decay, staged compression, episodic → semantic promotion, synaptic plasticity on co-activated edges, pruning of orphan edges, replay of strong clusters. |
| `get_grooming_health` | Per-leg (`wiki`, `distillation`, `promotion`) backlog count, last run, days since, and whether it is stale. Read this before scheduling or running a groom. |
| `curate_distill` | Returns authoring jobs for turning memory dossiers (error→success pairs, recurring co-access families) into lesson memories. |
| `curate_wiki` | Returns authoring jobs for turning memory clusters into curated wiki pages. |
| `lesson_promotion` | Proposes promotion jobs for lessons that have proven useful at least once. Interactive only — the scheduled groomer deliberately never calls it. |
| `memory_stats` | Population diagnostics: totals by episodic / semantic / active / archived / stale / protected, average heat, entity and relationship counts, active triggers, last consolidation. |
| `get_telemetry` | Per-operation counters: count, ok/fail, bytes, results, latency sum and max. |

## Fix and delete

| Tool | What it does |
| --- | --- |
| `rate_memory` | Usefulness verdict on a memory that just surfaced. Raises `useful_count` and recomputes metamemory confidence. The cheapest correction. |
| `validate_memory` | Graded provenance check of every reference a memory makes: file paths, commit SHAs, URLs (bounded HEAD sample), artifact digests, DOI/arXiv citations. |
| `forget` | `hard: false` → `is_stale = true`, heat 0 (stops surfacing, still in the table). `hard: true` → row deleted. Protected or anchored memories need `force: true`. |
| `add_rule` / `get_rules` | Neuro-symbolic rules applied on every recall: `hard` excludes matching memories, `soft` boosts or penalises rank, `tag` attaches a tag. `get_rules` audits what is currently shaping retrieval. |

## Diagnose and profile

| Tool | What it does |
| --- | --- |
| `check_setup` | Backend-aware install verification. Runs the same checks as `python -m mcp_server.doctor`, over MCP. |
| `detect_gaps` | Isolated entities, sparse domains, temporal drift, and other blind spots. |
| `assess_coverage` | Scores the store itself on quantity, age distribution, entity density, domain balance and compression, with recommendations. Not a per-topic knowledge score. |
| `query_methodology` | The cognitive profile for the current domain plus hot memories and fired triggers. Profiles are mined from Claude Code session logs, so they are empty on hosts that have none. |
| `list_domains` / `detect_domain` | Enumerate profiled domains, or classify the current directory and first message into one. |
| `rebuild_profiles` | Full rescan of `~/.claude/projects/` to rebuild profiles from scratch (`force: true`). Run before seeding a fresh install. |
| `calibration` / `predict` / `resolve_prediction` | Record a falsifiable prediction with a confidence, settle it later, and score the confidences with a Brier score (0.25 = always saying 0.5). |

## Ingest and bootstrap

| Tool | What it does |
| --- | --- |
| `seed_project` | Five-stage structural sweep of a codebase, each discovery written through the normal gate. The cheap bootstrap. |
| `codebase_analyze` | Deeper: tree-sitter AST per file, symbols as entities, imports as relationships, cross-file symbol resolution. |
| `import_sessions` / `backfill_memories` | Walk `~/.claude/projects/` JSONL transcripts and extract decisions, errors-and-fixes, architecture notes and insights into the store. |
| `ingest_document` | Ingest a `.docx` or a Confluence storage-format XHTML export into memory and the wiki. |
| `ingest_findings` | Ingest a code-analysis findings run from disk. |
| `sync_instructions` | Render the project's hot decisions, patterns and conventions into `CLAUDE.md` between `<!-- cortex:memory-insights:start -->` markers. |
| `create_trigger` | Prospective memory: fire on a keyword in a future message, at a time, or on a context match. |

## Wiki

`wiki_read`, `wiki_write`, `wiki_list`, `wiki_link`, `wiki_rename`, `wiki_purge`,
`wiki_reindex`, `wiki_verify`, `wiki_migrate`, `wiki_adr`, `wiki_get_draft`,
`wiki_refine_draft` — a per-project wiki with ADRs, drafts and link graph, curated from
memory clusters by `curate_wiki` and the `cortex-wiki-groomer` agent.

## What the plugin already ships

Do not reimplement these; call them.

- **Commands**: `/preflight` (doctor + ordered repairs), `/why` (resolve receipt markers), `/methodology` (cognitive profile).
- **Skills**: `cortex-recall`, `cortex-recall-global`, `cortex-remember`, `cortex-remember-global`, `cortex-consolidate`, `cortex-debug-memory`, `cortex-explore-memory`, `cortex-navigate-knowledge`, `cortex-setup-project`, `cortex-import`, `cortex-automate`, `cortex-profile`, `cortex-wiki-author`.
- **Agent**: `cortex-wiki-groomer` — rewrites wiki pages to their template when an audit reports drift.
- **Hooks** (Claude Code only): SessionStart injection, UserPromptSubmit auto-recall, PostToolUse capture / preemptive context / reindex, SessionEnd lifecycle, compaction checkpoint, SubagentStart briefing, PreToolUse decision gate on Edit/Write.

## Files on disk

| Path | What it is |
| --- | --- |
| `~/.claude/methodology/memory.db` (+ `-wal`, `-shm`) | The SQLite store — the whole memory, deletable |
| `~/.claude/methodology/backend.json` | Which backend was selected; read by Claude Code and Codex alike |
| `~/.claude/methodology/consolidate.log` | Consolidation runs |
| `~/.claude/methodology/telemetry.jsonl` | Local operation telemetry (never uploaded) |
| `~/.claude/methodology/session-log.json`, `artifacts/`, `hook-cascade/` | Session bookkeeping and captured tool artifacts |
| `~/.claude/plugins/cache/cortex-plugins/hypermnesia-mcp/<version>/` | The installed plugin: `scripts/install-plugin.sh`, `mcp_server/doctor.py`, `docs/` |
