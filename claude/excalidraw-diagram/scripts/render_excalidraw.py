#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["playwright"]
# ///
"""Validate an .excalidraw file and render it to PNG.

Usage:
    uv run scripts/render_excalidraw.py diagram.excalidraw [-o out.png] [-s 2] [-w 1920]
    python3 scripts/render_excalidraw.py diagram.excalidraw --check     # validate only

First time only (downloads Chromium):  uv run --with playwright playwright install chromium

Rendering loads Excalidraw from esm.sh, so it needs network access. Exit codes:
0 ok, 1 invalid file or render failure, 2 usage / environment problem.
"""
import argparse
import json
import sys
from pathlib import Path

TEMPLATE = Path(__file__).with_name("render_template.html")


def validate(data):
    """Return (errors, warnings) for a parsed .excalidraw document."""
    errors, warnings = [], []
    if not isinstance(data, dict) or data.get("type") != "excalidraw":
        errors.append('top-level "type" must be "excalidraw"')
        return errors, warnings
    elements = data.get("elements")
    if not isinstance(elements, list) or not elements:
        errors.append('"elements" must be a non-empty list')
        return errors, warnings

    live = [e for e in elements if isinstance(e, dict) and not e.get("isDeleted")]
    by_id = {}
    for e in live:
        for key in ("id", "type", "x", "y"):
            if key not in e:
                errors.append(f"element {e.get('id', '?')}: missing {key!r}")
        eid = e.get("id")
        if eid in by_id:
            errors.append(f"duplicate id {eid!r}")
        by_id[eid] = e

    for e in live:
        eid, kind = e.get("id"), e.get("type")
        bound = {b.get("id"): b.get("type") for b in e.get("boundElements") or []}
        for bid in bound:
            if bid not in by_id:
                errors.append(f"{eid}: boundElements references unknown id {bid!r}")

        if e.get("opacity", 100) != 100:
            warnings.append(f"{eid}: opacity {e['opacity']} (use 100; build hierarchy with color and size)")

        if kind == "text":
            if "originalText" not in e or e.get("originalText") != e.get("text"):
                warnings.append(f"{eid}: originalText missing or different from text")
            if e.get("fontSize", 20) < 14:
                warnings.append(f"{eid}: fontSize {e['fontSize']} is hard to read")
            cid = e.get("containerId")
            if cid:
                c = by_id.get(cid)
                if c is None:
                    errors.append(f"{eid}: containerId {cid!r} not found")
                else:
                    if not any(b.get("id") == eid for b in c.get("boundElements") or []):
                        warnings.append(f"{cid}: boundElements should list text {eid!r}")
                    longest = max((len(s) for s in str(e.get("text", "")).split("\n")), default=0)
                    est = longest * e.get("fontSize", 20) * 0.6
                    if est > c.get("width", 0) - 16:
                        warnings.append(f"{eid}: text (~{int(est)}px wide) may overflow container {cid!r} ({c.get('width')}px)")

        if kind in ("arrow", "line"):
            if not e.get("points") or len(e["points"]) < 2:
                errors.append(f"{eid}: {kind} needs at least 2 points")
        if kind == "arrow":
            for side in ("startBinding", "endBinding"):
                b = e.get(side)
                if not b:
                    continue
                tid = b.get("elementId")
                target = by_id.get(tid)
                if target is None:
                    errors.append(f"{eid}: {side} references unknown id {tid!r}")
                elif not any(x.get("id") == eid for x in target.get("boundElements") or []):
                    warnings.append(f"{tid}: boundElements should list arrow {eid!r}")
    return errors, warnings


def bounds(data):
    xs, ys = [], []
    for e in data["elements"]:
        if e.get("isDeleted"):
            continue
        x, y = e.get("x", 0), e.get("y", 0)
        if e.get("type") in ("arrow", "line") and e.get("points"):
            for px, py in e["points"]:
                xs.append(x + px)
                ys.append(y + py)
        else:
            xs += [x, x + abs(e.get("width", 0))]
            ys += [y, y + abs(e.get("height", 0))]
    return (min(xs), min(ys), max(xs), max(ys)) if xs else (0, 0, 800, 600)


def render(data, out, scale, max_width):
    try:
        from playwright.sync_api import sync_playwright
    except ImportError:
        sys.exit("playwright is not installed; run this with `uv run` (see the header of this file)")
    x0, y0, x1, y1 = bounds(data)
    viewport = {"width": int(min(x1 - x0 + 160, max_width)), "height": int(max(y1 - y0 + 160, 600))}
    with sync_playwright() as p:
        try:
            browser = p.chromium.launch(headless=True)
        except Exception as exc:  # missing browser binary is the usual cause
            sys.exit(f"cannot launch Chromium ({exc}); run: uv run --with playwright playwright install chromium")
        page = browser.new_page(viewport=viewport, device_scale_factor=scale)
        page.goto(TEMPLATE.as_uri())
        try:
            page.wait_for_function("window.__moduleReady === true || !!window.__moduleError", timeout=30000)
        except Exception:
            browser.close()
            sys.exit("timed out loading Excalidraw from esm.sh (network blocked?)")
        err = page.evaluate("window.__moduleError || null")
        if err:
            browser.close()
            sys.exit(f"could not load Excalidraw: {err}")
        result = page.evaluate("(d) => window.renderDiagram(d)", json.dumps(data))
        if not result.get("success"):
            browser.close()
            sys.exit(f"render failed: {result.get('error')}")
        page.wait_for_function("window.__renderComplete === true", timeout=15000)
        svg = page.query_selector("#root svg")
        if svg is None:
            browser.close()
            sys.exit("no SVG was produced")
        svg.screenshot(path=str(out))
        browser.close()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", type=Path)
    ap.add_argument("-o", "--output", type=Path)
    ap.add_argument("-s", "--scale", type=float, default=2)
    ap.add_argument("-w", "--width", type=int, default=1920, help="max viewport width")
    ap.add_argument("--check", action="store_true", help="validate only, do not render")
    a = ap.parse_args()

    if not a.input.is_file():
        print(f"no such file: {a.input}", file=sys.stderr)
        return 2
    try:
        data = json.loads(a.input.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        print(f"invalid JSON: {exc}", file=sys.stderr)
        return 1

    errors, warnings = validate(data)
    for w in warnings:
        print(f"warning: {w}", file=sys.stderr)
    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    if errors:
        return 1
    if a.check:
        print(f"ok: {len(data['elements'])} elements, {len(warnings)} warnings")
        return 0

    out = a.output or a.input.with_suffix(".png")
    render(data, out, a.scale, a.width)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
