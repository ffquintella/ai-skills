# ai-skills

A collection of agent skills useful for code development.

Skills are grouped by the vendor whose tooling and model lineup they target. Each
skill is a folder with a `SKILL.md` (frontmatter `name` + `description`, then the
instructions) and optional `references/` and `assets/`.

| Skill | Claude Code | OpenAI Codex |
| --- | --- | --- |
| **agent-router**: picks the agent, model tier and effort level for a task before delegating, with an escalation ladder | [claude/agent-router](claude/agent-router/SKILL.md) | [openai/agent-router](openai/agent-router/SKILL.md) |

## Installing skills

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

Where things land:

- **Claude Code**: `~/.claude/skills/<skill>` (or `DIR/.claude/skills`); agent templates in `.claude/agents/`.
- **OpenAI Codex**: `~/.agents/skills/<skill>` (or `DIR/.agents/skills`), invoked with `$<skill>`; agent templates in `.codex/agents/`, and `assets/config.toml.example` shows the matching `[agents]` defaults for `.codex/config.toml`.

Templates contain `<placeholders>` (build command, test filter, project rules) that
must be filled in for the target repository.
