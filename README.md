# ai-skills

A collection of agent skills useful for code development.

## Project structure

```text
skills/
  claude/
    code-review.md
  codex/
    code-review.json
tools/
  install-skills.sh
```

- `skills/claude`: Claude-format skills.
- `skills/codex`: Codex-format skills.
- `tools/install-skills.sh`: Installs one or both skill sets into local agent skill folders.

## Install skills

```bash
# install both
./tools/install-skills.sh all

# install only one format
./tools/install-skills.sh claude
./tools/install-skills.sh codex

# custom destination base directory
./tools/install-skills.sh all /tmp/agent-skills

# replace existing installed skills
./tools/install-skills.sh all /tmp/agent-skills --overwrite
```

The script installs into format-specific folders under the base directory:

- Claude: `<base>/.claude/skills`
- Codex: `<base>/.codex/skills`

For example, `./tools/install-skills.sh all /tmp/agent-skills` installs to:

- `/tmp/agent-skills/.claude/skills`
- `/tmp/agent-skills/.codex/skills`

If the destination already has files, the script exits without changing anything unless `--overwrite` is provided.
