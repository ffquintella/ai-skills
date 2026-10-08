---
name: excalidraw-diagram
description: Creates Excalidraw diagrams (.excalidraw JSON) that explain a concept visually - architectures, workflows, protocols, data flows, comparisons - then validates the file and renders it to PNG to check the layout before delivering. Use when the user asks for a diagram, flowchart, architecture sketch, sequence or process picture, "draw this", or an Excalidraw file, especially when the diagram should teach something with real examples (payloads, event names, code) instead of labelled boxes. Not for charts of numeric data and not for Mermaid-only requests.
---

# Excalidraw diagram

Produces a `.excalidraw` file the user can open at excalidraw.com or in the editor
extensions. The goal is a diagram that **argues**: its structure carries the idea, not
only its labels. Method adapted from coleam00's `excalidraw-diagram-skill`
(see [references/sources.md](references/sources.md)).

Two tests before and after drawing:

- **Isomorphism**: with all text removed, does the shape of the diagram still convey the
  concept (fan-out, loop, funnel, timeline, gap)?
- **Education**: would a reader learn something concrete (a real format, event name,
  command, example value), or only that boxes are connected?

## Step 1: choose the depth

| Kind | When | Content |
| --- | --- | --- |
| Conceptual | Overview, mental model, pitch | Abstract shapes, few labels, strong pattern |
| Technical | Architecture, protocol, pipeline someone will build from | Real names plus **evidence artifacts**: code snippets, JSON payloads, event timelines, sample inputs and outputs |

For a technical diagram, look up the real specs, field names, endpoints or event names
first (read the code in the repository, or the docs). Do not invent plausible-looking
payloads.

## Step 2: design

1. List the concepts and what each does and connects to.
2. Give each major concept a **visual pattern** that matches its behavior; vary them:

   | Behavior | Pattern |
   | --- | --- |
   | One source, many outputs | Fan-out |
   | Many inputs, one result | Convergence / funnel |
   | Parent and children | Tree |
   | Ordered steps over time | Timeline (line plus marker dots) |
   | Repeats | Cycle |
   | Fuzzy or external | Cloud / overlapping ellipses |
   | Sequential transformation | Assembly line |
   | Before and after, A versus B | Side by side |
   | Missing link, failure | Gap or break in a line |

3. Sketch the eye path: left to right or top to bottom for sequences, radial for a hub.
   Say the order in a sentence before writing JSON.

## Step 3: rules that make it read well

- **Minimal containers.** Default to free-floating text. Use a shape only for a focal
  point, something connected by arrows, or a distinct system component. Fewer than about
  30% of the text elements should sit inside a container.
- **No card grids.** Equal boxes in rows say "list", not "argument". Size encodes rank:
  hero ~300x150, primary ~180x90, secondary ~120x60, small ~60x40.
- **Whitespace is emphasis.** The most important element gets about 200 px of clear space.
- **Every relationship has an arrow or line.** Proximity alone does not connect things.
- **Shape means something**: ellipse start/end or external, diamond decision, rectangle
  step. Small 10 to 20 px dots work as timeline markers and bullets.
- **Hierarchy by type, not boxes**: title, subtitle, body differ in size and color.
- **Color encodes meaning** and comes from
  [references/color-palette.md](references/color-palette.md). Do not invent colors; pair a
  dark stroke with a light fill.
- **Clean style**: `roughness` 0, `opacity` 100, `strokeWidth` 1 (dividers), 2 (shapes,
  arrows), 3 (rare emphasis). Hand-drawn look (`roughness` 1, `fontFamily` 5) only if the
  user asks.

## Step 4: write the JSON

Element format, the document wrapper and the binding rules are in
[references/json-schema.md](references/json-schema.md); copy-paste templates are in
[references/element-templates.md](references/element-templates.md).

- Write the JSON by hand. Do not delegate it to another agent and do not generate it with
  a script: positions and bindings depend on the design decisions you just made.
- **Large diagrams: one section at a time** (entry, routing, main body, outputs), appending
  to the file. A single giant write truncates and gets sloppy. Then re-read the whole file
  for cross-section arrows and ids.
- Descriptive ids (`trigger_rect`, `arrow_fan_left`); seeds namespaced per section
  (100xxx, 200xxx).
- Whenever an arrow or label attaches to a shape, update **both sides**: the arrow's
  `startBinding`/`endBinding` and the shape's `boundElements`; likewise a contained text's
  `containerId` and the container's `boundElements`.

## Step 5: validate and render (mandatory)

```bash
uv run scripts/render_excalidraw.py path/to/diagram.excalidraw
```

(`uv` reads the script's inline dependency; run
`uv run --with playwright playwright install chromium` once for the browser. Rendering
loads Excalidraw from esm.sh, so it needs network access. Add `--check` to validate
without rendering; that part needs only `python3`.)

The script first validates the file (type, unique ids, binding consistency, text that
probably overflows its container) and prints `error:` and `warning:` lines. Fix errors
before anything else, and fix warnings unless you can say why they are harmless. It then
writes a PNG next to the source.

**Open the PNG and look at it** (attach it with the image viewer), against the design, not only for bugs:

1. Does the structure show the planned patterns and eye path? Does the hierarchy read?
2. Defects: clipped or overflowing text, overlaps, arrows crossing other elements, wrong
   arrowheads, ambiguous labels, uneven spacing, tiny text, lopsided composition.
3. Fix by changing coordinates, widening containers, adding arrow waypoints, moving labels,
   rebalancing sizes. Re-render. Expect 2 to 4 rounds; keep improving the composition even
   when nothing is broken.

If rendering is impossible (no network, no browser), say so, run `--check`, and tell the
user the layout was not visually verified.

## Checklist before delivering

- [ ] Depth chosen; technical diagrams use researched real values and evidence artifacts
- [ ] Passes isomorphism and education tests; patterns vary; no uniform card grid
- [ ] Fewer than ~30% of texts in containers; hierarchy by size and color
- [ ] Every relationship connected; flow direction clear; sizes reflect importance
- [ ] Palette colors only; roughness 0, opacity 100; text readable (16 px or more)
- [ ] `render_excalidraw.py` reports no errors; PNG reviewed; no overflow, overlap or
      bad arrow routes; spacing and balance even
- [ ] Told the user the file path (and PNG path)
