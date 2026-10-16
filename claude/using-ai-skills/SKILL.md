---
name: using-ai-skills
description: Bootstrap for the ai-skills collection - says to check for a matching skill before acting (including before clarifying questions or exploring the code), which skill covers which stage of development work, and the order to chain them in. The ai-skills plugin injects it at session start; load it by hand when the skills were installed without the plugin. Use at the start of a conversation and whenever unsure which skill applies. Ignore it inside a subagent dispatched for one specific task.
argument-hint: [task to find a skill for]
---

# Using ai-skills

If you were dispatched as a subagent for one specific task, ignore this skill and do the
task.

## The rule

Before responding or acting, including before a clarifying question or a look at the code,
check whether a skill covers the task. If one plausibly does, invoke it with the `Skill`
tool and follow it; drop it if it turns out not to fit. Reading a skill costs a few hundred
tokens, while skipping one usually costs a redo: the skills hold the steps that are easy
to skip under pressure (the failing test first, the root cause before the fix, fresh
evidence before "done").

Installed through the plugin, the skills are named `ai-skills:<name>`; installed by
`install.sh`, they are plain `<name>`. Say in one line which skill you are using and why.

## Which skill when

| Situation | Skill |
| --- | --- |
| "Let's build / add / change X", anything new, before plan mode | `brainstorming` |
| An approved design or spec that needs implementing | `writing-plans` |
| Feature work that should not touch the current checkout | `using-git-worktrees` |
| Executing a plan with agents (default when agents are available) | `subagent-driven-development` |
| Executing a plan yourself, in this session | `executing-plans` |
| Writing any production code with observable behavior | `test-driven-development` |
| A bug, failing test, flaky test or unexpected behavior | `systematic-debugging` |
| Delegating anything: which agent, model and effort | `agent-router` |
| Two or more independent problems at once | `dispatching-parallel-agents` |
| A task or feature is done, or before a merge | `requesting-code-review` |
| Review feedback arrived (PR comments, a reviewer report) | `receiving-code-review` |
| About to say "done", "fixed", "passing" or to commit | `verification-before-completion` |
| Work is verified and needs merging, a PR or cleanup | `finishing-a-development-branch` |
| "What did we decide", "did we hit this before" | `cortex-memory` |
| Creating or editing a skill | `writing-skills` |
| A diagram that explains a concept | `excalidraw-diagram` |
| A Rust security audit, only when the user asks for it by name | `rust-review` |

The usual chain for new work: `brainstorming` -> `writing-plans` -> `using-git-worktrees`
-> `subagent-driven-development` (each task through `test-driven-development` and
`requesting-code-review`) -> `verification-before-completion` ->
`finishing-a-development-branch`. A bug enters at `systematic-debugging` instead.

Skills from other sources (plugins, `~/.claude/skills`, project skills) follow the same
rule.

## Priority

Process skills come first because they decide how to approach the task; domain skills
(frontend design, a framework guide) then carry it out. "Build X" starts with
`brainstorming`; "fix this bug" starts with `systematic-debugging`.

Instructions from the user, CLAUDE.md and AGENTS.md override skills, and skills override
default behavior. Skip a skill's workflow only when the user says so.

## Thoughts that mean you are about to skip a skill

| Thought | Why it is wrong |
| --- | --- |
| "It is just a quick question" | Questions are tasks; the check takes seconds. |
| "Let me look at the code first" | Skills say how to explore; check before exploring. |
| "I remember what that skill says" | Skills change; read the current version. |
| "The skill is overkill here" | Small tasks are where skipped steps go unnoticed. |
| "I'll do this one thing first" | The first action is the one the skill shapes. |

## Claude Code notes

- Delegation goes through the `Agent` tool; `agent-router` picks `subagent_type`, model and
  effort. Its agent templates (`scout`, `builder`, `architect`, `reviewer`, `test-runner`)
  are copied into `.claude/agents/` by `install.sh --agents`; the plugin does not ship them,
  because they need project-specific placeholders filled in.
- Use the session's task list for a skill's checklist, one item per step.
