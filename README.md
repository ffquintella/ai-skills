# ai-skills

A collection of agent skills useful for code development.

The [agent-router CLI](tools/agent-router/README.md) is a standalone Rust executable
for Windows, Linux and macOS. It reads an editable YAML model matrix, selects the
cheapest capable model, and reduces token budgets as usage quotas approach their
limits. Build/package instructions and quota-source examples are in its README;
native CI artifacts include the executable, YAML and documentation.
The plugin includes its launchers and Rust source. `install.sh`/`install.ps1`
prepare the runtime automatically when installing `agent-router` or the plugin,
reusing a compatible build or compiling with Cargo. Direct plugin installations
prepare it lazily when the bundled launcher is first used. Custom YAML survives
updates; no PATH changes are required.

Skills are grouped by the vendor whose tooling and model lineup they target. Each
skill is a folder with a `SKILL.md` (frontmatter `name` + `description`, then the
instructions) and optional `references/` and `assets/`.

| Skill | Claude Code | OpenAI Codex |
| --- | --- | --- |
| **agent-router**: picks the agent, model tier and effort level for a task before delegating, with an escalation ladder | [claude/agent-router](claude/agent-router/SKILL.md) | [openai/agent-router](openai/agent-router/SKILL.md) |
| **cortex-memory**: when to read and write Cortex persistent memory, which tool to search with, how to schedule consolidation, and when to correct or delete a memory | [claude/cortex-memory](claude/cortex-memory/SKILL.md) | [openai/cortex-memory](openai/cortex-memory/SKILL.md) |
| **test-driven-development**: red-green-refactor discipline (failing test first, minimum code, full-suite verification), with test runs delegated to the `test-runner` agent; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/test-driven-development) | [claude/test-driven-development](claude/test-driven-development/SKILL.md) | [openai/test-driven-development](openai/test-driven-development/SKILL.md) |
| **dispatching-parallel-agents**: decides whether independent problems can run in parallel, how to split and brief them, and how to integrate the results; pairs with agent-router; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/dispatching-parallel-agents) | [claude/dispatching-parallel-agents](claude/dispatching-parallel-agents/SKILL.md) | [openai/dispatching-parallel-agents](openai/dispatching-parallel-agents/SKILL.md) |
| **systematic-debugging**: root cause before any fix (investigate, compare, one hypothesis at a time, failing test), stops after three failed fixes, with tracing, defense-in-depth and flaky-test notes and a `find-polluter.sh` helper; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/systematic-debugging) | [claude/systematic-debugging](claude/systematic-debugging/SKILL.md) | [openai/systematic-debugging](openai/systematic-debugging/SKILL.md) |
| **using-ai-skills**: bootstrap: check for a skill before acting, which skill covers which stage, and the order to chain them; the plugin injects it at session start on Claude Code; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/using-superpowers) | [claude/using-ai-skills](claude/using-ai-skills/SKILL.md) | [openai/using-ai-skills](openai/using-ai-skills/SKILL.md) |
| **brainstorming**: turns a vague request into an approved design through one question at a time, 2-3 approaches and a written spec, before any code (visual companion server left out); adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/brainstorming) | [claude/brainstorming](claude/brainstorming/SKILL.md) | [openai/brainstorming](openai/brainstorming/SKILL.md) |
| **writing-plans**: turns an approved spec into bite-sized tasks with exact paths, failing tests first, commands and a suggested `agent-router` tier per task; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/writing-plans) | [claude/writing-plans](claude/writing-plans/SKILL.md) | [openai/writing-plans](openai/writing-plans/SKILL.md) |
| **subagent-driven-development**: executes a plan with one fresh implementer per task, then spec and quality review, routed through `agent-router` (builder, architect, reviewer) with a capped fix loop and a ledger; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/subagent-driven-development) | [claude/subagent-driven-development](claude/subagent-driven-development/SKILL.md) | [openai/subagent-driven-development](openai/subagent-driven-development/SKILL.md) |
| **executing-plans**: executes a plan inline in the current session: review it first, task by task with verification, stop when blocked; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/executing-plans) | [claude/executing-plans](claude/executing-plans/SKILL.md) | [openai/executing-plans](openai/executing-plans/SKILL.md) |
| **using-git-worktrees**: isolated workspace before feature work: detects existing worktrees, prefers the host's native worktrees, checks the directory is ignored, runs a baseline test; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/using-git-worktrees) | [claude/using-git-worktrees](claude/using-git-worktrees/SKILL.md) | [openai/using-git-worktrees](openai/using-git-worktrees/SKILL.md) |
| **requesting-code-review**: sends finished work to the `reviewer` agent with what was built, the requirements and the exact commit range; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/requesting-code-review) | [claude/requesting-code-review](claude/requesting-code-review/SKILL.md) | [openai/requesting-code-review](openai/requesting-code-review/SKILL.md) |
| **receiving-code-review**: verifies each review suggestion against the code before changing anything, pushes back with reasons, no performative agreement; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/receiving-code-review) | [claude/receiving-code-review](claude/receiving-code-review/SKILL.md) | [openai/receiving-code-review](openai/receiving-code-review/SKILL.md) |
| **verification-before-completion**: no "done", "fixed" or "passing" without a fresh run of the command that proves it; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/verification-before-completion) | [claude/verification-before-completion](claude/verification-before-completion/SKILL.md) | [openai/verification-before-completion](openai/verification-before-completion/SKILL.md) |
| **finishing-a-development-branch**: verifies, then offers merge, PR, keep or discard (typed confirmation) and cleans up the worktree; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/finishing-a-development-branch) | [claude/finishing-a-development-branch](claude/finishing-a-development-branch/SKILL.md) | [openai/finishing-a-development-branch](openai/finishing-a-development-branch/SKILL.md) |
| **writing-skills**: TDD for skills: watch an agent fail without the skill, write against those failures, re-test; plus this repository's twin and sources.md rules; adapted from [obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/writing-skills) | [claude/writing-skills](claude/writing-skills/SKILL.md) | [openai/writing-skills](openai/writing-skills/SKILL.md) |
| **rust-review**: deep multi-agent Rust security audit (unsafe/FFI, memory safety, concurrency, panic DoS, async) with dedup and false-positive judges and SARIF output; expensive, runs only when the user asks for it; adapted from [trailofbits/skills](https://github.com/trailofbits/skills/tree/main/plugins/rust-review) | [claude/rust-review](claude/rust-review/SKILL.md) | [openai/rust-review](openai/rust-review/SKILL.md) |
| **excalidraw-diagram**: builds `.excalidraw` diagrams that explain a concept (patterns, evidence artifacts, palette), validates bindings and renders a PNG to review the layout; adapted from [coleam00/excalidraw-diagram-skill](https://github.com/coleam00/excalidraw-diagram-skill) | [claude/excalidraw-diagram](claude/excalidraw-diagram/SKILL.md) | [openai/excalidraw-diagram](openai/excalidraw-diagram/SKILL.md) |
| **graphify** (external): maps a repository (code via tree-sitter, plus docs and media) into a knowledge graph queried with `query`/`path`/`explain`; `agent-router` and `scout` query it before grepping when `graphify-out/` exists. Not copied here: `install.sh` installs the [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify) CLI and lets it write its own versioned skill | `graphify install` → `~/.claude/skills/graphify` | `graphify install --platform codex` → `~/.codex/skills/graphify` |

## The ai-skills plugin

The repository is also a plugin for both hosts, built like
[obra/superpowers](https://github.com/obra/superpowers): one install brings every skill,
and on Claude Code a SessionStart hook injects `using-ai-skills` so the session checks for
a skill before acting.

| | Claude Code | OpenAI Codex |
| --- | --- | --- |
| Manifest | [.claude-plugin/plugin.json](.claude-plugin/plugin.json) (skills from `claude/`) | [.codex-plugin/plugin.json](.codex-plugin/plugin.json) (skills from `openai/`) |
| Marketplace | [.claude-plugin/marketplace.json](.claude-plugin/marketplace.json) | [.agents/plugins/marketplace.json](.agents/plugins/marketplace.json) |
| Bootstrap | [hooks/session-start](hooks/session-start) on startup, `/clear` and compaction | none (Codex plugins carry no hook); the skill descriptions trigger them |
| Skill names | `ai-skills:<name>` | `<name>` |
| Reads | this checkout, live | the committed tree, copied per version |

```bash
./install.sh --plugin
```

or by hand:

```bash
claude plugin marketplace add ffquintella/ai-skills && claude plugin install ai-skills@ai-skills
```

```bash
codex plugin marketplace add ffquintella/ai-skills && codex plugin add ai-skills@ai-skills
```

The plugin includes the `agent-router` launchers, Rust source and default YAML.
Its native runtime is installed outside the plugin cache. It does not automatically
install project agent templates (they need project-specific placeholders) or the
external pieces (graphify, the Cortex server): `./install.sh --plugin` prepares the
router and still installs those pieces as requested. Install either the plugin or
the copied skills, not both, or every
skill is listed twice; the installer warns when it finds copies. After changing a manifest
or a skill that Codex users get, bump the version with `scripts/bump-version.sh <x.y.z>`
(Codex keys its cache by version).

## Working on this repository

[AGENTS.md](AGENTS.md) (imported by [CLAUDE.md](CLAUDE.md)) tells Claude Code and Codex how to use
Cortex memory here: when to `recall`, what is worth a `remember`, and why code questions go to
the graphify graph instead.

## Installing skills

Full walkthrough (install, finishing the agent templates, invoking the router, tuning cost): [docs/USAGE.md](docs/USAGE.md).

Run the installer from the repository root:

```bash
./install.sh
```

On Windows, install [Git for Windows](https://gitforwindows.org) with Git Bash,
then run from Windows PowerShell 5.1 or PowerShell 7:

```powershell
.\install.ps1
.\install.ps1 --all --vendor openai --project 'C:\Dev\my project' --no-external
```

This entry point accepts the same flags below and requires no WSL. If execution
policy blocks it, use `powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1`
with the desired flags. External runtimes require `uv` or `pipx` on PATH; restart
the terminal after installing them.

It detects whether Claude Code and OpenAI Codex are installed (CLI on PATH or their
home directory) and skips any vendor that is missing. Then it asks for the scope
(user level or a project directory), the method (the plugin, or individual skills), the
action (install or update), which skills to install (numbers, or `a` for all) and whether
to copy the agent templates. Existing
agents are never overwritten; installed skills are only overwritten in update mode.

Non-interactive flags:

| Flag | Effect |
| --- | --- |
| `--list` | Show skills and their status (installed / update available / not installed) |
| `--all` | Install every skill for every detected vendor, no prompts |
| `--update` | Overwrite installed skills with the repo version |
| `--vendor claude\|openai` | Limit to one vendor |
| `--project DIR` | Install into `DIR/.claude/skills` and `DIR/.agents/skills` instead of `~` |
| `--agents` / `--no-agents` | Copy (or skip) the agent templates without asking |
| `--no-external` | Skip third-party software: the graphify CLI and the Cortex plugin / MCP server |
| `--plugin` | Install the ai-skills plugin (all skills, plus the bootstrap hook on Claude Code) instead of copying skills |
| `--skills` | Copy individual skills (the default when there is no terminal, so `--all` keeps its old meaning) |

Where things land:

- **Claude Code**: `~/.claude/skills/<skill>` (or `DIR/.claude/skills`); agent templates in `.claude/agents/`.
- **OpenAI Codex**: `~/.agents/skills/<skill>` (or `DIR/.agents/skills`), invoked with `$<skill>`; agent templates in `.codex/agents/`, and `assets/config.toml.example` shows the matching `[agents]` defaults for `.codex/config.toml`.

`cortex-memory` also installs the Cortex MCP server it drives: the `hypermnesia-mcp` plugin on
Claude Code, and the PyPI package registered with `codex mcp add` on Codex (see
[docs/USAGE.md](docs/USAGE.md#4-use-cortex-memory)). Both it and graphify need Python 3.10+;
the installer reports which interpreter it found (for example a Homebrew `python3.14`) and
warns when there is none.

External skills (graphify) are not stored in this repository. Their skill text is
generated by the tool's own CLI and stamped with its version, so the installer installs
the CLI (`uv tool install graphifyy`, or `pipx`) and runs `graphify install`; `--update`
upgrades the CLI and rewrites the skill. Needs Python 3.10+ and uv or pipx. See
[docs/USAGE.md](docs/USAGE.md#5-use-graphify).

Templates contain `<placeholders>` (build command, test filter, project rules) that
must be filled in for the target repository.
