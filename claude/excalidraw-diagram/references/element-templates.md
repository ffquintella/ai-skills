# Element templates

Copy, then change `id`, position, size, colors (from
[color-palette.md](color-palette.md)), text and a fresh `seed`. All use the clean style
(roughness 0, opacity 100).

## Free-floating text

```json
{ "id": "title", "type": "text", "x": 0, "y": 0, "width": 260, "height": 25, "angle": 0,
  "strokeColor": "#1e40af", "backgroundColor": "transparent", "fillStyle": "solid",
  "strokeWidth": 1, "strokeStyle": "solid", "roughness": 0, "opacity": 100,
  "groupIds": [], "frameId": null, "roundness": null, "seed": 100001, "version": 1,
  "versionNonce": 1, "isDeleted": false, "boundElements": null, "updated": 1,
  "link": null, "locked": false,
  "text": "Request lifecycle", "originalText": "Request lifecycle", "fontSize": 20,
  "fontFamily": 3, "textAlign": "left", "verticalAlign": "top", "containerId": null,
  "lineHeight": 1.25, "autoResize": true }
```

## Rectangle with contained text

```json
{ "id": "step_rect", "type": "rectangle", "x": 100, "y": 100, "width": 180, "height": 90,
  "angle": 0, "strokeColor": "#1e3a5f", "backgroundColor": "#60a5fa", "fillStyle": "solid",
  "strokeWidth": 2, "strokeStyle": "solid", "roughness": 0, "opacity": 100,
  "groupIds": [], "frameId": null, "roundness": { "type": 3 }, "seed": 100002, "version": 1,
  "versionNonce": 2, "isDeleted": false,
  "boundElements": [ { "id": "step_text", "type": "text" } ],
  "updated": 1, "link": null, "locked": false },
{ "id": "step_text", "type": "text", "x": 110, "y": 132, "width": 160, "height": 25,
  "angle": 0, "strokeColor": "#1f2937", "backgroundColor": "transparent", "fillStyle": "solid",
  "strokeWidth": 1, "strokeStyle": "solid", "roughness": 0, "opacity": 100,
  "groupIds": [], "frameId": null, "roundness": null, "seed": 100003, "version": 1,
  "versionNonce": 3, "isDeleted": false, "boundElements": null, "updated": 1,
  "link": null, "locked": false,
  "text": "Validate", "originalText": "Validate", "fontSize": 16, "fontFamily": 3,
  "textAlign": "center", "verticalAlign": "middle", "containerId": "step_rect",
  "lineHeight": 1.25, "autoResize": true }
```

## Ellipse, diamond

Same fields as the rectangle with `"type": "ellipse"` or `"diamond"` and `roundness: null`.
Contained text works the same way (diamonds need extra width: the usable text area is about
half the shape).

## Marker dot

```json
{ "id": "dot_1", "type": "ellipse", "x": 200, "y": 300, "width": 14, "height": 14,
  "angle": 0, "strokeColor": "#3b82f6", "backgroundColor": "#3b82f6", "fillStyle": "solid",
  "strokeWidth": 1, "strokeStyle": "solid", "roughness": 0, "opacity": 100,
  "groupIds": [], "frameId": null, "roundness": null, "seed": 100004, "version": 1,
  "versionNonce": 4, "isDeleted": false, "boundElements": null, "updated": 1,
  "link": null, "locked": false }
```

## Divider / timeline line

```json
{ "id": "timeline", "type": "line", "x": 100, "y": 300, "width": 600, "height": 0,
  "angle": 0, "strokeColor": "#64748b", "backgroundColor": "transparent", "fillStyle": "solid",
  "strokeWidth": 1, "strokeStyle": "solid", "roughness": 0, "opacity": 100,
  "groupIds": [], "frameId": null, "roundness": null, "seed": 100005, "version": 1,
  "versionNonce": 5, "isDeleted": false, "boundElements": null, "updated": 1,
  "link": null, "locked": false,
  "points": [ [0, 0], [600, 0] ], "startBinding": null, "endBinding": null,
  "startArrowhead": null, "endArrowhead": null }
```

## Bound arrow (shape A right edge to shape B left edge)

A at `x=100, width=180` so its right edge is x=280, mid-height y=145. B starts at x=400.

```json
{ "id": "a_to_b", "type": "arrow", "x": 280, "y": 145, "width": 120, "height": 0,
  "angle": 0, "strokeColor": "#1e3a5f", "backgroundColor": "transparent", "fillStyle": "solid",
  "strokeWidth": 2, "strokeStyle": "solid", "roughness": 0, "opacity": 100,
  "groupIds": [], "frameId": null, "roundness": { "type": 2 }, "seed": 100006, "version": 1,
  "versionNonce": 6, "isDeleted": false, "boundElements": null, "updated": 1,
  "link": null, "locked": false,
  "points": [ [0, 0], [120, 0] ],
  "startBinding": { "elementId": "step_rect", "focus": 0, "gap": 2 },
  "endBinding": { "elementId": "next_rect", "focus": 0, "gap": 2 },
  "startArrowhead": null, "endArrowhead": "arrow", "elbowed": false }
```

Then add `{ "id": "a_to_b", "type": "arrow" }` to `boundElements` of **both** `step_rect`
and `next_rect`.

## Evidence artifact (code or JSON box)

A rectangle with fill `#1e293b`, stroke `#0f172a`, sized to the snippet, plus one text
element (`containerId` null, `textAlign: "left"`, `verticalAlign: "top"`, `fontFamily: 3`,
`fontSize: 14` to 16, `strokeColor` `#22c55e` for JSON or `#e2e8f0` for code) placed 16 px
inside its top-left corner. Use real, short snippets; keep them under about 12 lines.
