# Worked example

After a refactor, six tests failed across three files. Grouping by cause gave three
independent domains:

| Domain | File | Symptom |
| --- | --- | --- |
| Abort timing | `abort.test` | tests finish before the abort is observed |
| Batch completion | `batch.test` | completion event never delivered |
| Approval race | `approval.test` | tool runs before approval resolves |

Three `builder` agents were dispatched in one message, one per file, each with the
failing test names, the error text, the test command with a filter, and the constraint
"fix the cause, do not lengthen timeouts". They returned: event-based waiting instead of
a fixed delay; a field moved to the correct place in an event payload; an await added for
async tool execution. No two touched the same file. The full suite passed on the merged
result.

The point of the split: none of the three needed to know about the others, so nothing
the coordinator read for one was re-billed for the others.
