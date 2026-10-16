# Plan template

Copy this structure into `docs/plans/YYYY-MM-DD-<feature>.md` (or the location the project
names) and fill it in. Every plan starts with the header.

## Header

````markdown
# [Feature name] implementation plan

> For agents: use `subagent-driven-development` (recommended) or `executing-plans` to
> implement this plan task by task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** [one sentence on what this builds]

**Architecture:** [2 to 3 sentences on the approach]

**Tech stack:** [key technologies and libraries]

**Spec:** [path to the spec or design document this plan implements; executors read both]

## Global constraints

[The spec's project-wide requirements (version floors, dependency limits, naming and copy
rules, platform requirements), one line each, exact values copied verbatim from the spec.
Every task's requirements implicitly include this section.]

## Review focus

[The five inputs or failure modes the spec implies but no task's tests exercise yet that are
most likely to bite a user, one line each, naming the input or condition and the behavior a
reasonable person would expect, most likely first. The spec says what the software must do,
not everything it will meet; its silence on an input is not permission for that input to
break the program. Then add the test that pins each line to the task that owns the code.]

---
````

## Task

`````markdown
### Task N: [component name]

**Tier:** routine (builder) | complex (architect) - [reason if not obvious]

**Files:**
- Create: `exact/path/to/file.py`
- Modify: `exact/path/to/existing.py:123-145`
- Test: `tests/exact/path/to/test.py`

**Interfaces:**
- Consumes: [what this task uses from earlier tasks, with exact signatures]
- Produces: [what later tasks rely on: exact names, parameter and return types. An
  implementer sees only their own task; this block is how they learn the names and types
  neighboring tasks use.]

- [ ] **Step 1: Write the failing test**

```python
def test_specific_behavior():
    result = function(input)
    assert result == expected
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `pytest tests/path/test.py::test_name -v`
Expected: FAIL with "function not defined"

- [ ] **Step 3: Implement `function(input: InputType) -> ResultType` in `exact/path/to/file.py`**

One line on the approach when the signature and the test leave a choice (which library
call, which data structure); a code block only for an algorithm they do not determine.

- [ ] **Step 4: Run the test and confirm it passes**

Run: `pytest tests/path/test.py::test_name -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add tests/path/test.py src/path/file.py
git commit -m "feat: add specific feature"
```
`````

Sizing rule: a task is the smallest unit that carries its own test cycle and is worth a
fresh reviewer's gate. The test-first cycle is `test-driven-development`.
