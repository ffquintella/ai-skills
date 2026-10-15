@AGENTS.md

## Claude Code

The `hypermnesia-mcp` plugin recalls context at session start and on every prompt, and
captures tool output by itself, so do not `remember` what a tool already printed. Its
tools are named `mcp__plugin_hypermnesia-mcp_cortex__<tool>`. An explicit `recall` is
still worth it before the work listed in AGENTS.md, since the automatic one matches the
prompt, not the files you are about to change.
