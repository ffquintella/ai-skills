# Sources

Adapted (rewritten, not copied) from the `subagent-driven-development` skill in
[obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/subagent-driven-development)
(`SKILL.md`, `implementer-prompt.md`, `task-reviewer-prompt.md`, `re-review-prompt.md`,
`scripts/sdd-workspace`, `scripts/task-brief`, `scripts/review-package`) and the Codex notes
(spawning, `followup_task`, `wait_agent`, model routing on spawns) in its
`using-superpowers/references/codex-tools.md`, read 2026-10-16, commit bb92a77. The Codex
mechanics are upstream's claims and were not tested here.

Changes: tighter wording and no all-caps rules; "Model Selection" replaced by a pointer to
`agent-router` (implementer `builder` or `architect`, reviewer `reviewer`, runs
`test-runner`) with its escalation ladder; the fix loop is capped at three rounds (resume the
implementer with `followup_task` once, then climb to a new `architect` spawn, since model and
effort are fixed at spawn) instead of five, to match the router's two-rung ladder; the
templates override the `builder` role defaults (do not commit, 40-line report); status marks
in the reviewer output are plain words instead of symbols; the workspace moved from
`.superpowers/sdd/` to `.ai-skills/sdd/`; plan and spec locations follow the project's
AGENTS.md (default `docs/plans/`); the final review uses `requesting-code-review`; the
Graphviz diagrams were dropped. The Claude-only orchestrator note was left out.
