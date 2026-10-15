# ai-skills: agent instructions

Agent skills for Claude Code (`claude/`) and OpenAI Codex (`openai/`), installed by
`install.sh`. Most skills exist twice, once per vendor, and change together.

## Persistent memory (Cortex)

This repository uses [Cortex](https://github.com/cdeust/Cortex) for memory across
sessions. Claude Code and Codex share one local store
(`~/.claude/methodology/memory.db`), so a decision recorded from either host is visible
in both. The `cortex-memory` skill holds the full method; these are the rules for this
repository.

### Check it is there

Call `memory_stats` once if you are unsure. If the Cortex tools are missing, install
them with `./install.sh` (it sets up the plugin on Claude Code and the MCP server on
Codex) and restart the session. Do not block on it: the repository and `git log` stay
authoritative without memory.

### Search before you change something with history

Run one `recall` before working on:

- `install.sh`, especially the external steps (graphify, the Cortex plugin and MCP server);
- a skill that has a twin in the other vendor folder;
- anything the user describes as "again", "like last time" or "we decided".

Ask a question, not keywords, and scope it to this repository by passing the absolute
path of its root (`git rev-parse --show-toplevel`) as `directory`:

```
recall({query: "Why does install.sh pin Python 3.12 for the Cortex server?",
        directory: "<repository root>"})
```

Treat what comes back as true when written. Before acting on a recalled file, flag or
command, confirm it still exists in the repository. If a result has `superseded_by_id`,
follow it.

### What to remember here

Record with `remember` (tag `decision` or `lesson`, include a file path or commit so it
can be verified):

- **Why a skill is adapted rather than copied**, and what changed from upstream, when it is not already in that skill's `references/sources.md`.
- **Upstream quirks found by testing**, for example a third-party CLI that writes extra files, needs a specific Python, or behaves differently at project scope.
- **Vendor differences**: when the Claude and Codex versions of a skill deliberately diverge, and why.
- **Install paths that were not verified** (no network, no CLI on the test machine), so the next session tests them instead of trusting them.
- **Corrections from the user** about how skills in this repository should be written.

Do not remember routine edits, file contents, test runs or anything already in the
README, `docs/USAGE.md`, a `sources.md` or the commit message: the repository is the
record for those, and the Claude Code plugin already captures tool output on its own.

When a decision changes, `remember` the new one with `supersedes_id` set to the old
memory. Do not delete the old one.

### Code questions use the graphify graph

This repository has a graphify graph (`graphify-out/graph.json`), and Cortex also
indexes the code on its own. Use one: graphify for code structure (`graphify query`,
`explain`, `path`, `affected`, as the `agent-router` skill describes), Cortex for
decisions and history. Do not run `unified_search` or `codebase_analyze` for a code
question here.

### Maintenance

`consolidate` runs weekly from a scheduled task, not at the end of each session. Check
`get_grooming_health` before running it by hand.

### Codex

Codex has no Cortex hooks: nothing is recalled or captured automatically. Call `recall`
at the start of work that matches the list above, and `remember` when one of the
memory-worthy events happens. The MCP server is registered as `cortex`.
