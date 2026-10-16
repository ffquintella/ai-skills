# Sources

Adapted (rewritten, not copied) from the `using-superpowers` skill in
[obra/superpowers](https://github.com/obra/superpowers/tree/main/skills/using-superpowers)
(`SKILL.md`, `references/claude-code-tools.md`, `references/codex-tools.md`), read
2026-10-16, commit bb92a77. Changes: renamed for this collection, the capitals and the
"1% chance" wording replaced by the rule with its reason, a situation-to-skill table and
the usual chain added (upstream relies on each skill's description alone), the
rationalization table cut to five rows, and the per-harness reference files reduced to
short Claude Code and Codex notes. Like upstream, the plugin's SessionStart hook
(`hooks/session-start`) injects the Claude twin at the start of every Claude Code session;
the Codex plugin has no hook and relies on the skill description.
