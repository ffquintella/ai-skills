# ai-skills

A collection of agent skills useful for code development.

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
| **rust-review**: deep multi-agent Rust security audit (unsafe/FFI, memory safety, concurrency, panic DoS, async) with dedup and false-positive judges and SARIF output; expensive, runs only when the user asks for it; adapted from [trailofbits/skills](https://github.com/trailofbits/skills/tree/main/plugins/rust-review) | [claude/rust-review](claude/rust-review/SKILL.md) | [openai/rust-review](openai/rust-review/SKILL.md) |
| **excalidraw-diagram**: builds `.excalidraw` diagrams that explain a concept (patterns, evidence artifacts, palette), validates bindings and renders a PNG to review the layout; adapted from [coleam00/excalidraw-diagram-skill](https://github.com/coleam00/excalidraw-diagram-skill) | [claude/excalidraw-diagram](claude/excalidraw-diagram/SKILL.md) | [openai/excalidraw-diagram](openai/excalidraw-diagram/SKILL.md) |
| **graphify** (external): maps a repository (code via tree-sitter, plus docs and media) into a knowledge graph queried with `query`/`path`/`explain`; `agent-router` and `scout` query it before grepping when `graphify-out/` exists. Not copied here: `install.sh` installs the [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify) CLI and lets it write its own versioned skill | `graphify install` → `~/.claude/skills/graphify` | `graphify install --platform codex` → `~/.codex/skills/graphify` |

## Installing skills

Full walkthrough (install, finishing the agent templates, invoking the router, tuning cost): [docs/USAGE.md](docs/USAGE.md).

Run the installer from the repository root:

```bash
./install.sh
```

It detects whether Claude Code and OpenAI Codex are installed (CLI on PATH or their
home directory) and skips any vendor that is missing. Then it asks for the scope
(user level or a project directory), the action (install or update), which skills to
install (numbers, or `a` for all) and whether to copy the agent templates. Existing
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
