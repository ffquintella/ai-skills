# Sources

Adapted (rewritten, not copied) from the `brainstorming` skill in
[obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/brainstorming)
(`SKILL.md` and `builder-check-prompt.md`), read 2026-10-16, commit bb92a77. Changes:
tighter wording and no capitalized gates; the one-question-at-a-time dialogue, the
2 to 3 approaches with a recommendation, the sectioned playback, the design document, the
self-review and builder check and the hand-off to `writing-plans` are kept; added
`AskUserQuestion` for multiple-choice questions, a graphify / Cortex lookup before asking
about existing code, routing of the builder check to `scout`, and the document location
`docs/specs/` unless the project names another. Left out: the visual companion
(`visual-companion.md` and `scripts/`, a Node WebSocket server that serves mockups to a
browser tab), because it adds a runtime dependency and a long-running process this
repository does not otherwise need; mockups can be described in text or drawn with
`excalidraw-diagram`.
