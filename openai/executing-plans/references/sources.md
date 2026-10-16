# Sources

Adapted (rewritten, not copied) from the `executing-plans` skill in
[obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/executing-plans)
(`SKILL.md`, `scripts/task-start`, `scripts/task-done`), read 2026-10-16, commit bb92a77.

Changes: tighter wording and no all-caps rules; an explicit critical review of the plan with
a single pause to raise concerns before starting; the final review routed through
`agent-router` (`reviewer` subagent via `spawn_agent`, `gpt-5.6-sol` for security-sensitive
code) and `requesting-code-review`; the scripts kept and adapted to the `.ai-skills/sdd/`
workspace shared with `subagent-driven-development`, which must be installed next to this
skill; plan and spec locations follow the project's AGENTS.md (default `docs/plans/`); a
note for Codex App worktrees on a detached HEAD; the Graphviz diagram was dropped.
