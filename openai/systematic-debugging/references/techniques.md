# Techniques

## Tracing a bad value backward

Use when the symptom is far from the mistake (a file created in the wrong directory, a
database opened at the wrong path, a wrong value deep in a library call).

1. Write down the symptom and where it appears.
2. Find the code that directly produces it.
3. Find what called that code, then what called the caller, noting the values passed.
4. Stop at the first point where a value is already wrong. That is the origin.
5. Fix at the origin, not at the symptom.

If reading is not enough, instrument **before** the risky operation, not after it fails:
log the relevant values (directory, working directory, environment, arguments) and the
current call stack. In tests write to stderr directly, because loggers are often
suppressed. Run, filter the output on a unique label, and read the callers in the stack.

If something unwanted shows up during a full test run and you do not know which test
creates it, run `scripts/find-polluter.sh`.

## Defense in depth, after the root cause is fixed

A single check can be bypassed by another code path, a refactor or a mock. When the bug
was invalid data, validate at every layer the data crosses:

1. **Entry point**: reject empty, missing or wrongly typed input at the boundary.
2. **Business logic**: check the data makes sense for this specific operation.
3. **Environment guard**: refuse dangerous actions in the wrong context (for example,
   destructive file operations outside a temp directory while tests run).
4. **Instrumentation**: log context (stack, working directory) so the next failure that
   gets past the other layers is diagnosable.

Then try to bypass each layer in a test to confirm the next one catches it.

## Condition-based waiting

Fixed sleeps and timeouts make async tests flaky under load, in parallel runs and in CI.
Replace them with a poll that waits for the actual condition:

- Helper takes a condition, a description and a timeout (about 5 s), checks every ~10 ms,
  and throws a descriptive error on timeout. Re-read the state **inside** each iteration,
  or the check never sees updates. Always have a timeout, or a never-true condition hangs
  the suite.
- Use it to wait for an event, a state change, a collection reaching a size, a file
  existing.
- A fixed delay is correct only when testing timing itself (debounce, throttle, a tool
  that emits every 100 ms), and only when you first wait for the trigger, base the delay on
  known timing (200 ms covers two 100 ms ticks) and comment why.
