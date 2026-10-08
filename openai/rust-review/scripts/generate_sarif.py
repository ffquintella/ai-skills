#!/usr/bin/env python3
"""Write REPORT.sarif from the finding files of a rust-review run.

Usage: generate_sarif.py <results-dir> [all|medium|high]

Reads <results-dir>/findings/*.md (simple `key: value` frontmatter). Skips findings
merged into another and those judged FALSE_POSITIVE, LIKELY_FP or OUT_OF_SCOPE.
Unjudged findings are kept and marked unvalidated, so a severity filter cannot hide them.
"""
import json
import re
import sys
from pathlib import Path

RANK = {"LOW": 1, "MEDIUM": 2, "HIGH": 3, "CRITICAL": 4}
LEVEL = {"LOW": "note", "MEDIUM": "warning", "HIGH": "error", "CRITICAL": "error"}
DROPPED = {"FALSE_POSITIVE", "LIKELY_FP", "OUT_OF_SCOPE"}
MIN_RANK = {"all": 0, "medium": 2, "high": 3}


def parse(path: Path):
    text = path.read_text(encoding="utf-8")
    m = re.match(r"---\n(.*?)\n---\n(.*)", text, re.S)
    if not m:
        return None
    meta = {}
    for line in m.group(1).splitlines():
        if ":" in line and not line.startswith((" ", "-")):
            k, v = line.split(":", 1)
            meta[k.strip()] = v.split("#")[0].strip() if k.strip() != "title" else v.strip()
    return meta, m.group(2)


def main(argv):
    if len(argv) < 2 or (len(argv) > 2 and argv[2] not in MIN_RANK):
        print(__doc__, file=sys.stderr)
        return 2
    root = Path(argv[1])
    floor = MIN_RANK[argv[2] if len(argv) > 2 else "all"]
    results, rules = [], {}

    for f in sorted((root / "findings").glob("*.md")):
        parsed = parse(f)
        if not parsed:
            continue
        meta, body = parsed
        if meta.get("merged_into") or meta.get("fp_verdict") in DROPPED:
            continue
        sev = meta.get("severity", "").upper()
        unvalidated = not sev
        if not unvalidated and RANK.get(sev, 0) < floor:
            continue
        loc = meta.get("location", "")
        uri, _, line = loc.rpartition(":")
        if not uri or not line.isdigit():
            uri, line = loc, "1"
        rule = meta.get("bug_class", "unknown")
        rules.setdefault(rule, {"id": rule, "name": rule})
        desc = body.split("## Description", 1)[-1].split("##", 1)[0].strip()
        results.append({
            "ruleId": rule,
            "level": LEVEL.get(sev, "warning"),
            "message": {"text": f"{meta.get('title', rule)}\n\n{desc}".strip()},
            "locations": [{"physicalLocation": {
                "artifactLocation": {"uri": uri},
                "region": {"startLine": int(line)},
            }}],
            "properties": {
                "id": meta.get("id", f.stem),
                "confidence": meta.get("confidence", ""),
                "fp_verdict": meta.get("fp_verdict", ""),
                "severity": sev or "UNVALIDATED",
                "unvalidated": unvalidated,
            },
        })

    sarif = {
        "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
        "version": "2.1.0",
        "runs": [{
            "tool": {"driver": {"name": "rust-review", "rules": list(rules.values())}},
            "results": results,
        }],
    }
    (root / "REPORT.sarif").write_text(json.dumps(sarif, indent=2), encoding="utf-8")
    print(f"wrote {root / 'REPORT.sarif'}: {len(results)} results")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
