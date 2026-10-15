# Usage guide

How to install the skills in this repository and how to use `agent-router` day to day.

## 1. Install

From the repository root:

```bash
./install.sh
```

The installer walks through four questions:

1. **Scope**: user level (`~/.claude/skills`, `~/.agents/skills`) or a project directory.
2. **Action**: *install* adds missing skills and leaves installed ones alone; *update* also overwrites installed skills with the repo version.
3. **Skills**: type the numbers you want, or `a` for all. Each line shows the vendor and the status (`installed`, `update available`, `not installed`).
4. **Agent templates**: whether to copy the agents under `assets/agents/` into `.claude/agents/` (Claude) or `.codex/agents/` (Codex). Existing agents are never overwritten.

Vendors that are not installed on the machine are skipped automatically.

Non-interactive examples:

```bash
./install.sh --list
```

```bash
./install.sh --all --update
```

```bash
./install.sh --all --agents --project ~/dev/my-repo
```

```bash
./install.sh --vendor openai --all
```

After installing, start a new Claude Code or Codex session so the skills list reloads.

## 2. Finish the agent templates

The agent templates are generic. Open the copied files and replace every `<placeholder>`:

| Placeholder | Replace with |
| --- | --- |
| `<build command>` | The project build, e.g. `dotnet build app.sln` or `npm run build` |
| `<test command with filter>` | A fast, targeted test run, e.g. `dotnet test tests/tests.csproj --filter FullyQualifiedName~Auth` |
| `<full test command>` | The complete test suite |
| `<Project rule N ...>` | The non-negotiable rules from the project's AGENTS.md / CLAUDE.md (auth attributes, config ownership, secrets) |

For Codex, also add the `[agents]` table from `assets/config.toml.example` to `.codex/config.toml` so subagents get a cheap default model and a concurrency cap.

## 3. Use agent-router

The skill loads automatically when you ask to implement, fix, refactor, test, review, investigate, document or plan something. You can also invoke it explicitly:

- **Claude Code**: `/agent-router add a health endpoint like the existing status one`
- **Codex**: `$agent-router add a health endpoint like the existing status one`

The coordinator then:

1. Classifies the task into a tier (inline, lookup, routine change, complex change, review, verify, plan).
2. Picks the agent, model and effort from the routing table and prints one line so the decision is visible:

   ```
   router: tier=routine agent=builder model=sonnet effort=high agents=1 verify=<test command>
   ```

3. Decides between one agent and several. It fans out only when the request holds 2 or more problems that are independent (no shared root cause, files or resources, and already localised); the split, per-domain briefs and integration then follow `dispatching-parallel-agents`, with each domain routed to its own tier.
4. Writes a brief with objective, boundaries, verification command and output contract, and delegates.
5. Checks the evidence (exit codes, failing tests). On failure it escalates one rung: scout -> builder -> architect -> architect on the frontier model. Two failures at the top means the task needs re-scoping and it asks you. After a fan-out it runs the full suite once more, since per-agent greens do not prove the combination.

If the router answers `inline`, the coordinator just does the work without spawning anything.

### Tiers at a glance

| Tier | Claude Code | OpenAI Codex |
| --- | --- | --- |
| lookup / verify | `scout`, `test-runner` on Haiku 4.5 | `scout`, `test-runner` on `gpt-5.6-luna`, low |
| routine change / review | `builder`, `reviewer` on Sonnet 5, high | `builder`, `reviewer` on `gpt-5.6-terra`, high |
| complex change | `architect` on Opus 5, xhigh | `architect` on `gpt-5.6-sol`, xhigh |
| frontier escalation | `architect` with `model: fable` | `architect` with `model = "gpt-6-astra"` |

### Tuning cost

- If mechanical work looks expensive, lower the effort of `builder` (`medium`) before switching to a cheaper model.
- Never spawn more agents than there are independent questions; dependent steps go to one agent.
- Keep file-editing agents in the foreground (Claude) or with `workspace-write` sandbox (Codex); lock everything else to read-only.

## 4. Use cortex-memory

Needs the Cortex MCP server (`hypermnesia-mcp`). If it is not installed yet, configure
the host you use:

```bash
claude plugin marketplace add cdeust/Cortex
claude plugin install hypermnesia-mcp
```

```bash
codex mcp add cortex --env CORTEX_MEMORY_STORE_BACKEND=sqlite -- hypermnesia-mcp
```

The skill loads when a task touches past-session context ("what did we decide about X",
"have we hit this before"), when storing a decision or lesson, when recall returns stale
results, or when Cortex itself needs diagnosing. Explicitly: `/cortex-memory cleanup`
in Claude Code or `$cortex-memory cleanup` in Codex.

It answers four questions:

1. **Search or not** — and with which tool (`recall` by default, `unified_search` across code and wiki, `recall_hierarchical` + `drill_down` for a broad topic, `get_causal_chain` for "what caused X").
2. **Write or not** — decisions whose reason will not survive in the diff, yes; progress notes, no.
3. **Cleanup** — `consolidate` weekly, scheduled as a task or a cron job, gated on `get_grooming_health`.
4. **Removal** — `rate_memory` for bad ranking, a superseding `remember` for outdated facts, `forget` (soft) for wrong ones, `forget hard` only for data that must not exist on disk.

The store is a single local SQLite file at `~/.claude/methodology/memory.db`. The tool
catalogue and the on-disk layout are in
[claude/cortex-memory/references/tools.md](../claude/cortex-memory/references/tools.md)
and [openai/cortex-memory/references/tools.md](../openai/cortex-memory/references/tools.md).

## 5. Use graphify

[graphify](https://github.com/Graphify-Labs/graphify) turns a repository into a
knowledge graph (`graphify-out/graph.json`, `GRAPH_REPORT.md`, `graph.html`). Code is
parsed locally with tree-sitter, without any LLM; docs, PDFs, images and video go
through a model pass.

It is an **external** skill: the repo keeps no copy, because its 700-line skill is
generated per assistant and versioned with the CLI (releases ship almost daily). The
installer handles it like the others in the menu:

| Situation | What `install.sh` does |
| --- | --- |
| CLI missing | `uv tool install graphifyy` (or `pipx install graphifyy`); warns and skips if neither uv nor pipx exists |
| Skill missing | `graphify install --platform claude` (Claude Code) or `--platform codex` (Codex, writes `~/.codex/skills/graphify`) |
| `--update` | `uv tool upgrade graphifyy` (or `pipx upgrade`), then reinstalls the skill |
| `--list` | Compares the skill's `.graphify_version` stamp with `graphify --version` |
| `--project DIR` | `graphify install --project` inside `DIR`. graphify has no skill-only project install, so this **also** writes the always-on block: `CLAUDE.md` plus PreToolUse hooks in `.claude/settings.json`, or `AGENTS.md` plus `.codex/hooks.json`. Remove with `graphify uninstall --project` |

At user scope, `graphify install` also adds a short `## graphify` registration block to
`~/.claude/CLAUDE.md`. The graphify CLI refreshes user-scope skills on its own after a
package upgrade; project-scope copies only refresh through `--update`.

Build the first graph from your assistant:

- **Claude Code**: `/graphify .`
- **Codex**: `$graphify .` (needs `multi_agent = true` under `[features]` in `~/.codex/config.toml` for parallel extraction)

After that, `agent-router` routes lookups to `scout` with a graph-first brief
(`graphify query`, `explain`, `path`, `affected`), refreshes a stale graph with
`graphify update .` (code only, no LLM), and falls back to grep when no node matches.
If a project also uses Cortex's code graph, the router uses graphify when
`graphify-out/` exists and Cortex otherwise.

Optional, per project: `graphify hook install` adds a git post-commit hook that
rebuilds the code graph after every commit.

`scout` agents already copied into `.claude/agents/` or `.codex/agents/` are never
overwritten, so copy the graph-first paragraph from
[claude/agent-router/assets/agents/scout.md](../claude/agent-router/assets/agents/scout.md)
or [openai/agent-router/assets/agents/scout.toml](../openai/agent-router/assets/agents/scout.toml)
into your existing `scout` by hand.

## 6. Update later

Pull the repository and run:

```bash
./install.sh --all --update
```

Agent templates you have already customised are not touched; only the skill folders are replaced. For graphify this also upgrades the CLI.
