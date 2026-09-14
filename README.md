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
```
