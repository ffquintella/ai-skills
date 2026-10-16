# Sources

Adapted (rewritten, not copied) from the `requesting-code-review` skill in
[obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/requesting-code-review)
(`SKILL.md` and `code-reviewer.md`), read 2026-10-16, commit bb92a77. Changes: tighter
wording; the reviewer is this repository's `reviewer` agent via `agent-router` (Opus
override for security paths, `general-purpose` fallback) instead of a bare general-purpose
agent; the prompt template no longer repeats the project-rules checks the `reviewer`
agent already makes and maps its scale to Critical/Important/Minor; pointer to
`rust-review` for deep Rust audits; the rationalization table shortened to a mistakes
table; plan paths made project-neutral.
