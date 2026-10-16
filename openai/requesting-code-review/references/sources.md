# Sources

Adapted (rewritten, not copied) from the `requesting-code-review` skill in
[obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/requesting-code-review)
(`SKILL.md` and `code-reviewer.md`), read 2026-10-16, commit bb92a77. Changes: tighter
wording; the reviewer is this repository's `reviewer` subagent via `agent-router`
(`gpt-5.6-sol` override for security paths, default-subagent fallback), spawned with
`fork_turns: "none"` and explicit `model` and `reasoning_effort`, instead of a bare
general-purpose subagent; the prompt template no longer repeats the project-rules checks
the `reviewer` subagent already makes and maps its scale to Critical/Important/Minor;
pointer to `rust-review` for deep Rust audits; the rationalization table shortened to a
mistakes table; plan paths made project-neutral.
