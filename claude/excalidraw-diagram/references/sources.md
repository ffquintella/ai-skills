# Sources

Adapted (rewritten, not copied) from
[coleam00/excalidraw-diagram-skill](https://github.com/coleam00/excalidraw-diagram-skill)
(`README.md`, `SKILL.md`, `references/*`), read 2026-10-08. The upstream page did not show
a license; this is an independent rewrite of the method, not a redistribution of its files.

Kept: the "argue, don't display" philosophy, isomorphism and education tests, depth
assessment, pattern-per-concept mapping, minimal-container rule, section-by-section
generation, and the mandatory render-and-inspect loop with Playwright and Excalidraw's
`exportToSvg`.

Changed: palette values, templates and format notes written from scratch; the renderer
(`scripts/render_excalidraw.py`, `scripts/render_template.html`) is new, uses a PEP 723
inline dependency instead of a project file, and adds a validator for ids, bindings and
probable text overflow (`--check` runs it without a browser).

Not verified: the validator was tested; the browser render path was not run in the
authoring environment (no Playwright, and Excalidraw would not load in the in-app
browser), so treat the first render as the real test.
