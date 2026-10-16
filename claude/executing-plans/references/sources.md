# Sources

Adapted (rewritten, not copied) from the `executing-plans` skill in
[obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/executing-plans)
(`SKILL.md`, `scripts/task-start`, `scripts/task-done`), read 2026-10-16, commit bb92a77.

Changes: tighter wording and no all-caps rules; an explicit critical review of the plan with
a single pause to raise concerns before starting; the final review routed through
`agent-router` (`reviewer`, `opus` for security-sensitive code) and `requesting-code-review`;
the scripts kept and adapted to the `.ai-skills/sdd/` workspace shared with
`subagent-driven-development`, which must be installed next to this skill; plan and spec
locations follow the project's AGENTS.md (default `docs/plans/`); the Graphviz diagram was
dropped.
