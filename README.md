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

# replace existing installed skills (run per format)
./tools/install-skills.sh claude /tmp/agent-skills --overwrite
./tools/install-skills.sh codex /tmp/agent-skills --overwrite
```

The script installs into format-specific folders under the base directory:

- Claude: `<base>/.claude/skills`
- Codex: `<base>/.codex/skills`

For example, `./tools/install-skills.sh all /tmp/agent-skills` installs to:

- `/tmp/agent-skills/.claude/skills`
- `/tmp/agent-skills/.codex/skills`

If the destination already exists and is non-empty, the script exits unless `--overwrite` is provided.
Existing empty destination directories are populated in place during install.
For `all`, the script validates both Claude and Codex targets first, then performs installs sequentially.
Combined overwrite for `all` is intentionally blocked; run overwrite installs per format.
