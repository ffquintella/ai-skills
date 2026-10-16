---
name: finishing-a-development-branch
description: Closes out finished work on a branch - verifies the tests first, detects whether you are in a normal checkout, a linked worktree or a detached HEAD, confirms the base branch, offers exactly four options (merge locally, push and open a PR, keep as is, discard with a typed confirmation), runs the chosen one and removes the worktree only after a merge or a confirmed discard. Never force-pushes and never deletes a branch without explicit confirmation. Use when implementation is complete and the user asks to "finish this branch", "merge it", "open a PR", "wrap this up" or "clean up", and at the end of `executing-plans` or `subagent-driven-development`. Not for work that is still failing or incomplete.
argument-hint: [base branch]
---

# Finishing a development branch

Order: verify tests, detect the environment, confirm the base, present the options, run
the choice, clean up. The integration decision belongs to the user: present the menu and
wait, do not pick for them.

Say at the start: "Using `finishing-a-development-branch` to complete this work."

## Step 1: verify the tests

Follow `verification-before-completion`: run the project's full test suite and build now,
read the exit code and the counts. For a long run, hand it to `test-runner` through
`agent-router`. If anything fails, show the failures and stop; the menu comes only after a
green run. Uncommitted work that should be part of the branch is committed first.

## Step 2: detect the environment

Capture these now, while still inside the workspace; the later steps change directory.

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
BRANCH=$(git branch --show-current)          # empty means detached HEAD
```

| State | Menu | Cleanup |
| --- | --- | --- |
| `GIT_DIR` equals `GIT_COMMON` (normal checkout) | 4 options | No worktree |
| Differ, on a named branch | 4 options | Step 6 |
| Differ, detached HEAD | 2 options (no merge, no discard) | Host owns it, leave it |

## Step 3: confirm the base branch

The base is what this work forked from: named in the plan, the conversation or the
branch's upstream. If it is not clear, ask "This branch split from `<best guess>`, is that
correct?" Merging into the wrong base is expensive to undo.

## Step 4: present the options

Named branch, exactly these four:

```
Implementation complete. What would you like to do?

1. Merge back to <base> locally
2. Push and open a Pull Request
3. Keep the branch as is (I'll handle it later)
4. Discard this work

Which option?
```

Detached HEAD (externally managed workspace), exactly these two:

```
Implementation complete. You are on a detached HEAD (externally managed workspace).

1. Push as a new branch and open a Pull Request
2. Keep as is (I'll handle it later)

Which option?
```

Wait for the answer.

## Step 5: run the choice

### Merge locally

Merge from the main checkout, never from inside the worktree being removed.

```bash
MAIN_ROOT=$(git -C "$(git rev-parse --git-common-dir)/.." rev-parse --show-toplevel)
cd "$MAIN_ROOT"
git checkout <base>
git pull
git merge <branch>
```

Run the tests on the merged result (same rules as step 1). If they fail, stop and leave the
worktree and branch in place: nothing was pushed, so the merge is local and recoverable.
If they pass, clean up the worktree (step 6), then ask: "Delete branch `<branch>`?" Only
after a yes: `git branch -d <branch>`. If `-d` refuses because the branch is not fully
merged, report it and ask; do not switch to `-D` on your own.

### Push and open a PR

```bash
git push -u origin <branch>
# detached HEAD: git push origin HEAD:refs/heads/<new-branch>
```

If the push is rejected, the remote moved: fetch and investigate, and ask the user before
anything else. Never force-push unless the user asks for it in so many words.

Then open the PR against `<base>` with the forge's CLI (for example `gh pr create`) or the
URL the push prints, following the repository's PR template and conventions. Write a body
with a short summary of the change and how it was tested, and end it with whatever
attribution the host requires (a Claude Code session's attribution reminder, for
instance). Report the PR URL. Keep the worktree: the user will iterate on review feedback
there.

### Keep as is

Report: "Keeping branch `<name>`. Worktree preserved at `<path>`."

### Discard

Show what would be lost and require the typed word:

```
This will permanently delete:
- Branch <name>
- Commits: <list from git log <base>..<branch> --oneline>
- Worktree at <path>

Type 'discard' to confirm.
```

Anything other than the exact word `discard` (including "yes" or "go ahead") is not a
confirmation: ask again or stop. After it, `cd "$MAIN_ROOT"`, clean up the worktree
(step 6), then `git branch -D <branch>`.

## Step 6: clean up the workspace

Runs only after a merge or a confirmed discard, from outside the worktree and using the
values captured in step 2.

- `GIT_DIR` equals `GIT_COMMON`: no worktree, done.
- Worktree under `.worktrees/` or `worktrees/` that `using-git-worktrees` created:
  ```bash
  git worktree remove "$WORKTREE_PATH"
  git worktree prune
  ```
- Worktree made by `EnterWorktree`: leave it with `ExitWorktree` and choose removal.
- Anything else (a desktop app worktree, one you did not create): the host owns it. Leave
  it in place. Never clean up other worktrees you came across.

If `git worktree remove` refuses with "contains modified or untracked files", those files
exist nowhere else. Never add `--force` on your own. List them
(`git -C "$WORKTREE_PATH" status --porcelain -uall`) and ask: commit them to the branch,
move them to the main checkout, or delete them (unrecoverable). Do what the user picks,
then remove.

## Quick reference

| Option | Merges | Pushes | Keeps worktree | Branch |
| --- | --- | --- | --- | --- |
| Merge locally | yes | no | removed | deleted only on confirmation |
| Push and PR | no | yes | kept | kept |
| Keep as is | no | no | kept | kept |
| Discard | no | no | removed | `-D` after typed `discard` |

## Mistakes to avoid

- Offering the menu on a red suite, or reusing an earlier green run.
- Merging into a base nobody confirmed.
- Deleting a branch, force-pushing, or passing `--force` to `git worktree remove` without
  an explicit yes.
- Removing the worktree after opening a PR; feedback gets fixed there.
- Treating "get rid of it" as the `discard` confirmation.

If the branch's decisions should outlive the session (why it was discarded, why a base was
chosen), `remember` them when Cortex is connected.
