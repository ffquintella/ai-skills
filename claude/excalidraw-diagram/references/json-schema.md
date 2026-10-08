# .excalidraw format

## Document

```json
{
  "type": "excalidraw",
  "version": 2,
  "source": "claude-code",
  "elements": [],
  "appState": { "viewBackgroundColor": "#ffffff", "gridSize": 20 },
  "files": {}
}
```

## Common element fields

`id` (unique string), `type`, `x`, `y`, `width`, `height`, `angle` (0), `strokeColor`,
`backgroundColor` (hex or `"transparent"`), `fillStyle` (`solid` | `hachure` | `cross-hatch`),
`strokeWidth` (1, 2 or 4), `strokeStyle` (`solid` | `dashed` | `dotted`), `roughness`
(0 clean, 1 sketchy, 2 rough), `opacity` (0 to 100, use 100), `seed` (integer, unique per
element), `version` (1), `versionNonce` (integer), `isDeleted` (false), `groupIds` ([]),
`frameId` (null), `roundness` (null, or `{"type": 3}` for rounded rectangles; `{"type": 2}`
for curved lines), `boundElements` (null or list), `updated` (timestamp ms), `link` (null),
`locked` (false).

## Types

| `type` | Use | Extra fields |
| --- | --- | --- |
| `rectangle` | step, component, code box | `roundness` |
| `ellipse` | start, end, external, marker dot | |
| `diamond` | decision | |
| `text` | any label, free-floating or in a shape | see below |
| `arrow` | directed connection | see below |
| `line` | divider, timeline, tree branch | `points` |
| `frame` | named grouping region | `name` |

## Text

`text`, `originalText` (same string), `fontSize` (16 or more), `fontFamily`
(1 hand-drawn, 2 sans, 3 monospace, 5 Excalifont), `textAlign` (`left|center|right`),
`verticalAlign` (`top|middle|bottom`), `containerId` (id of the shape it sits in, or null),
`lineHeight` (1.25), `autoResize` (true).

- The `text` value holds only the words to show; `\n` for line breaks.
- Size the box yourself: width about `0.6 x fontSize x longest line`, height about
  `lineHeight x fontSize x lines`. Underestimating makes text overflow its container.
- Text inside a shape: set `containerId` to the shape, set the shape's `boundElements` to
  include `{ "id": "<text id>", "type": "text" }`, center both alignments, and position the
  text at the shape's center.

## Arrow and line

- `points`: list of `[x, y]` relative to the element's `x`, `y`; the first is `[0, 0]`.
  Add intermediate points to route around elements.
- `width`, `height`: extent of the points.
- `startArrowhead`, `endArrowhead`: `null | "arrow" | "bar" | "dot" | "triangle"`.
  A plain arrow is `startArrowhead: null`, `endArrowhead: "arrow"`.
- `startBinding`, `endBinding`: `null` or `{ "elementId": "<shape id>", "focus": 0, "gap": 2 }`.
- `elbowed`: false (true for right-angle routing).

## Binding rules (both sides, always)

| Relationship | One side | Other side |
| --- | --- | --- |
| Arrow starts or ends at a shape | arrow `startBinding` / `endBinding` with `elementId` | shape `boundElements` includes `{ "id": "<arrow id>", "type": "arrow" }` |
| Text sits in a shape | text `containerId` | shape `boundElements` includes `{ "id": "<text id>", "type": "text" }` |

The validator warns on any one-sided binding and errors on an id that does not exist.
An arrow end should be placed on the shape's edge (center of a side), not inside it.
