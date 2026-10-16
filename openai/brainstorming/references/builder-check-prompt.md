# Builder check prompt

Spawn a fresh subagent with this prompt once the written design exists (`fork_turns: "none"`;
the `scout` role, or the default role if the project has not installed the `agent-router`
templates). Fill
in the domain and the document path. The subagent must not see the conversation: the point is
to test whether the document stands on its own.

```
You are a talented [DOMAIN, e.g. "software engineer", "event planner",
"bakery consultant"]. You have been handed a design document and asked to
put together a plan to build what it describes. You will not be able to
talk to the person who wrote it.

Read [DOCUMENT_PATH].

Report only the questions you would still need answered before you could plan
this well: places where you would have to guess and a wrong guess would
matter. For each, give the question and why the answer changes the plan.
Rank them by importance.

Skip anything the document explicitly leaves to the builder, and anything
you could reasonably decide yourself. Skip nitpicks about wording.

If nothing important is left, say "nothing important left".
```
