# Usage guide

How to install the skills in this repository and how to use `agent-router` day to day.

For a local executable that applies an editable YAML matrix and quota-aware token
budgets, see the [agent-router CLI](../tools/agent-router/README.md). It supports
manual remaining percentages, live Codex quota queries, and Claude statusline JSON.
It emits a recommendation for the caller to apply. The installer prepares it
automatically for plugins and copied `agent-router` skills, even with `--no-external`.
Use `--no-router` to skip that step. A directly installed plugin's bundled launcher
can also prepare the runtime on first use. Cargo/Rust 1.89+ and native build tools
are required only when no compatible native build is available. Set
`AI_SKILLS_ROUTER_BINARY` to reuse a trusted native binary of the same crate version.

User runtime: `${XDG_DATA_HOME:-$HOME/.local/share}/ai-skills/agent-router`.
Project runtime: `DIR/.ai-skills/agent-router`. `AI_SKILLS_ROUTER_HOME` overrides
these defaults. The installer reports the absolute binary path; the skill-local
`scripts/agent-router` launcher works without PATH changes. On Windows use Git Bash
for shell launchers, or invoke the installed `.exe` directly from PowerShell.
`--list` reports router status without compiling. Update refreshes an unmodified
matrix and preserves a custom `models.yaml`, writing new defaults to `models.yaml.dist`.

## 1. Install

From the repository root:

```bash
./install.sh
```

On Windows, install [Git for Windows](https://gitforwindows.org) including Git Bash,
then use `.\install.ps1` in PowerShell. All flags in this guide work with that
entry point too, including `--project 'C:\Dev\my project'`. WSL is not needed.
If script execution is blocked, use
`powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1`.

The installer walks through these questions:

1. **Scope**: user level (`~/.claude/skills`, `~/.agents/skills`) or a project directory.
2. **Method**: the ai-skills plugin (default; see below) or individual skills. The plugin path asks only for the action and the agent templates.
3. **Action**: *install* adds missing skills and leaves installed ones alone; *update* also overwrites installed skills with the repo version.
4. **Skills**: type the numbers you want, or `a` for all. Each line shows the vendor and the status (`installed`, `update available`, `not installed`).
5. **Agent templates**: whether to copy the agents under `assets/agents/` into `.claude/agents/` (Claude) or `.codex/agents/` (Codex). Existing agents are never overwritten.

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

### Plugin or copied skills

| | Plugin (`--plugin`) | Copied skills (`--skills`, default for `--all`) |
| --- | --- | --- |
| What you get | Every skill, as `ai-skills:<name>` on Claude Code | The skills you pick, as `<name>` |
| Bootstrap | Claude Code injects `using-ai-skills` at every session start, `/clear` and compaction | None; `using-ai-skills` loads only when its description matches |
| Updates | Claude Code reads this checkout live; Codex reinstalls the committed tree with `--update` | `--update` re-copies changed skills |
| Scope | Claude Code: user or project. Codex: user only | User or project |

Pick one. With both, every skill is listed twice; the installer prints the copies to remove.
Codex installs what is committed, so commit before `./install.sh --plugin --update`, and
bump the version (`scripts/bump-version.sh`) when the change should replace an installed
copy.

```bash
./install.sh --plugin
```

```bash
./install.sh --plugin --update --vendor openai
```

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

Needs the Cortex MCP server (`hypermnesia-mcp`). `install.sh` sets it up together with
the skill, and `--list` shows its state next to the skill (`plugin: installed`,
`MCP: registered`):

| Host | What the installer does | Update (`--update`) |
| --- | --- | --- |
| Claude Code | `claude plugin install hypermnesia-mcp --marketplace cdeust/Cortex --scope <user\|project>`; warns if the pre-4.15 `cortex` plugin is still installed | `claude plugin marketplace update cortex-plugins`, then `claude plugin update` |
| Codex | `uv tool install --python 3.12 "hypermnesia-mcp[sqlite]"` (or `pipx` with the Python 3.10+ it found), then `codex mcp add cortex` with the command's **absolute path**; pins `CORTEX_MEMORY_STORE_BACKEND=sqlite` unless `~/.claude/methodology/backend.json` selects PostgreSQL | `uv tool upgrade hypermnesia-mcp` |

Notes:

- **Python**: the Claude plugin starts from any `python3` and provisions its own 3.12 on the first launch. On Codex, uv is told to use 3.12, because otherwise it takes the first `python3` on PATH (the system 3.9 on many Macs) and the install fails.
- **First launch**: the plugin installs its runtime in the background; the tools appear in the session once that finishes. The store is created at `~/.claude/methodology/memory.db`.
- **Scope**: Codex keeps MCP servers in `~/.codex/config.toml` only, so the registration is user-level even with `--project`.
- **Skip it**: `--no-external` installs the skill without the plugin or server.

Manual equivalent, if you install without the script:

```bash
claude plugin install hypermnesia-mcp --marketplace cdeust/Cortex
```

```bash
uv tool install --python 3.12 "hypermnesia-mcp[sqlite]"
```

```bash
codex mcp add cortex --env CORTEX_MEMORY_STORE_BACKEND=sqlite -- "$(command -v hypermnesia-mcp || echo "$HOME/.local/bin/hypermnesia-mcp")"
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

## 6. The development workflow

With the plugin (or all skills) installed, new work follows one chain, each step a skill:

1. `brainstorming`: questions one at a time, 2-3 approaches, an approved spec in `docs/specs/`.
2. `writing-plans`: bite-sized tasks with exact paths, failing tests and an `agent-router` tier, saved to `docs/plans/`.
3. `using-git-worktrees`: an isolated workspace with a green baseline.
4. `subagent-driven-development` (agents) or `executing-plans` (inline): each task through `test-driven-development`, then `requesting-code-review`; feedback is handled with `receiving-code-review`.
5. `verification-before-completion`: fresh evidence before any "done".
6. `finishing-a-development-branch`: merge, PR, keep or discard.

Bugs start at `systematic-debugging` instead. `using-ai-skills` holds the full
situation-to-skill table. On Codex, the agent-driven steps need `multi_agent = true` under
`[features]` in `~/.codex/config.toml`; without it, use `executing-plans`.

`subagent-driven-development` keeps its workspace in `.ai-skills/sdd/` inside the project;
add `.ai-skills/` to the project's `.gitignore`.

## 7. Update later

Pull the repository and run:

```bash
./install.sh --all --update
```

Agent templates you have already customised are not touched; only the skill folders are replaced. For graphify this also upgrades the CLI.

With the plugin, use `./install.sh --plugin --update`: it refreshes the Claude Code
marketplace and plugin, and reinstalls the Codex plugin from the current commit.
