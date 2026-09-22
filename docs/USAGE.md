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

3. Writes a brief with objective, boundaries, verification command and output contract, and delegates.
4. Checks the evidence (exit codes, failing tests). On failure it escalates one rung: scout -> builder -> architect -> architect on the frontier model. Two failures at the top means the task needs re-scoping and it asks you.

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

Needs the Cortex MCP server (`hypermnesia-mcp`). If it is not installed yet:

```bash
claude plugin marketplace add cdeust/Cortex
claude plugin install hypermnesia-mcp
```

The skill loads when a task touches past-session context ("what did we decide about X",
"have we hit this before"), when storing a decision or lesson, when recall returns stale
results, or when Cortex itself needs diagnosing. Explicitly: `/cortex-memory cleanup`.

It answers four questions:

1. **Search or not** — and with which tool (`recall` by default, `unified_search` across code and wiki, `recall_hierarchical` + `drill_down` for a broad topic, `get_causal_chain` for "what caused X").
2. **Write or not** — decisions whose reason will not survive in the diff, yes; progress notes, no.
3. **Cleanup** — `consolidate` weekly, scheduled as a task or a cron job, gated on `get_grooming_health`.
4. **Removal** — `rate_memory` for bad ranking, a superseding `remember` for outdated facts, `forget` (soft) for wrong ones, `forget hard` only for data that must not exist on disk.

The store is a single local SQLite file at `~/.claude/methodology/memory.db`. The tool
catalogue and the on-disk layout are in
[claude/cortex-memory/references/tools.md](../claude/cortex-memory/references/tools.md).

## 5. Update later

Pull the repository and run:

```bash
./install.sh --all --update
```

Agent templates you have already customised are not touched; only the skill folders are replaced.
