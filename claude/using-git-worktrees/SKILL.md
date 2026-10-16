---
name: using-git-worktrees
description: Sets up an isolated git workspace before feature work - detects whether you are already in a linked worktree, prefers Claude Code's native worktree support (the EnterWorktree tool, isolation "worktree" on agents, desktop app worktree sessions), and only then falls back to `git worktree add` with a git-ignored directory, project setup autodetect and a baseline test run. Use when starting feature or fix work that should not touch the current checkout, before executing an implementation plan, when running several agents that edit files in parallel, or when asked for "a worktree", "an isolated branch" or "a clean workspace". Skip for read-only investigation or when the user wants to work in place.
argument-hint: [branch name or feature]
---

# Using git worktrees

Work in an isolated workspace so the user's current checkout stays untouched. Order of
preference: reuse the isolation you are already in, then the host's native worktree
support, then plain `git worktree add`. A native tool owns placement, branching and
cleanup; creating a worktree by hand behind its back leaves state the host cannot see.

Say at the start: "Using `using-git-worktrees` to set up an isolated workspace."

## Step 0: detect existing isolation

Check before creating anything.

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
BRANCH=$(git branch --show-current)
git rev-parse --show-superproject-working-tree 2>/dev/null   # prints a path inside a submodule
```

- `GIT_DIR` differs from `GIT_COMMON` and the last command prints nothing: you are already
  in a linked worktree (a desktop app worktree session, an agent started with
  `isolation: "worktree"`, or one made earlier). Do not create another. Report the path
  and branch, then go to step 2. Empty `BRANCH` means detached HEAD: say so, a branch will
  be needed when the work is finished.
- They are equal, or the last command printed a path (submodule): this is a normal
  checkout. Honor any worktree preference already stated in the user's message or in
  AGENTS.md / CLAUDE.md. If there is none, ask once: "Set up an isolated worktree? It
  keeps your current branch clean." If the user declines, work in place and go to step 2.

## Step 1: create the workspace

### 1a. Native support (preferred)

In Claude Code:

- The `EnterWorktree` tool creates a worktree and switches the session into it (and
  `ExitWorktree` leaves it). It may be a deferred tool: load it with `ToolSearch` first.
- A subagent that should edit files in isolation is started with `isolation: "worktree"`
  on the `Agent` tool; the worktree is removed afterwards if the agent made no changes.
  Use this for parallel edits (see `dispatching-parallel-agents`).
- The desktop app can start a session in its own worktree; if so, step 0 already found it.

If one of these is available, use it and go to step 2.

### 1b. `git worktree add` (no native tool)

Pick the directory in this order; an explicit preference beats what is on disk:

1. A directory named in the user's message or in AGENTS.md / CLAUDE.md.
2. An existing `.worktrees/` (preferred) or `worktrees/` at the repository root.
3. Otherwise `.worktrees/`, after telling the user.

For a project-local directory, confirm it is git-ignored before creating anything in it:

```bash
git check-ignore -q .worktrees || git check-ignore -q worktrees
```

If it is not ignored, add it to `.gitignore` and commit that change first; otherwise the
worktree's files can be committed into the repository. A directory outside the repository
needs no check.

```bash
git worktree add ".worktrees/<branch>" -b "<branch>"    # from the base you want, add it last
cd ".worktrees/<branch>"
```

Use a descriptive branch name (`feat/oauth-login`, `fix/null-session`). If the command is
refused by a sandbox permission, tell the user and continue in the current directory.

## Step 2: project setup

Install what the project needs, from the files present (use the project's own command if
README or AGENTS.md names one):

| File | Command |
| --- | --- |
| `package.json` | `npm install` (`pnpm`, `yarn` or `bun` if the lockfile says so) |
| `Cargo.toml` | `cargo build` |
| `pyproject.toml` | `poetry install`, or `pip install -e .` / `uv sync` per the project |
| `requirements.txt` | `pip install -r requirements.txt` |
| `go.mod` | `go mod download` |
| `*.sln` / `*.csproj` | `dotnet restore` |

Nothing matches: skip it. Untracked local files (`.env`, local config) are not copied into
a new worktree; ask the user before copying anything that may hold secrets.

## Step 3: clean baseline

Run the project's test suite in the new workspace before changing anything, so later
failures can be attributed. Follow `verification-before-completion`: read the exit code
and the counts, and for a long suite hand the run to `test-runner` through `agent-router`.

- Passing: report `Worktree ready at <path>, <N> tests passing, ready for <feature>`.
- Failing: show the failures and ask whether to proceed or investigate first. Do not
  start work on a red baseline without the user's say-so.

## Quick reference

| Situation | Action |
| --- | --- |
| Already in a linked worktree | Skip creation, go to step 2 |
| In a submodule | Treat as a normal checkout |
| `EnterWorktree` or app worktree available | Use it, not `git worktree add` |
| Subagent edits in parallel | `isolation: "worktree"` on the agent |
| `.worktrees/` and `worktrees/` both exist | Use `.worktrees/` |
| Project-local directory not ignored | Add to `.gitignore`, commit, then create |
| Worktree creation denied by sandbox | Say so, work in place |
| Baseline tests fail | Report and ask |

## Mistakes to avoid

- Skipping step 0 by eye: the commands settle it, and submodules look like worktrees.
- Running `git worktree add` while a native tool exists.
- Creating a project-local worktree without `git check-ignore`.
- Starting work before the baseline run.
- Removing a worktree you did not create; cleanup belongs to
  `finishing-a-development-branch`.
