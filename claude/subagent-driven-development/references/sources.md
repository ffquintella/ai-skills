# Sources

Adapted (rewritten, not copied) from the `subagent-driven-development` skill in
[obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/subagent-driven-development)
(`SKILL.md`, `implementer-prompt.md`, `task-reviewer-prompt.md`, `re-review-prompt.md`,
`scripts/sdd-workspace`, `scripts/task-brief`, `scripts/review-package`) and the "Cheaper
orchestration" note in its `using-superpowers/references/claude-code-tools.md`, read
2026-10-16, commit bb92a77. The orchestrator note is upstream's claim about Claude Code's
nested agents and was not tested here.

Changes: tighter wording and no all-caps rules; "Model Selection" replaced by a pointer to
`agent-router` (implementer `builder` or `architect`, reviewer `reviewer`, runs
`test-runner`) with its escalation ladder; the fix loop is capped at three rounds (resume the
implementer once, then climb to `architect`) instead of five, to match the router's two-rung
ladder; the templates override the `builder` defaults (do not commit, 40-line report); status
marks in the reviewer output are plain words instead of symbols; the workspace moved from
`.superpowers/sdd/` to `.ai-skills/sdd/`; plan and spec locations follow the project's
AGENTS.md (default `docs/plans/`); the final review uses `requesting-code-review`; the
Graphviz diagrams were dropped.
