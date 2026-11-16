#!/usr/bin/env python3
"""Rebuild docs/README.md from the docs themselves: title + `**Status:**` line of every
decision and wiki page. Run after adding or changing a decision / wiki page:
    python3 tools/docs_index.py
"""
import re
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / "docs"


def title_and_status(path):
    title, status = path.stem, ""
    for line in path.read_text(encoding="utf-8").splitlines()[:12]:
        if not title or title == path.stem:
            if line.startswith("# "):
                title = line[2:].strip()
        if line.startswith("**Status:**"):
            status = line[len("**Status:**"):].strip()
    return title, status


def relink(status, prefix):
    # links inside a status line are relative to its own folder
    return re.sub(r"\]\((?!http)([^)]+)\)", lambda m: f"]({prefix}/{m.group(1)})", status)


def table(rows, head):
    out = [f"| {head[0]} | {head[1]} | Status |", "|---|---|---|"]
    out += [f"| {a} | {b} | {c} |" for a, b, c in rows]
    return out


def main():
    lines = [
        "# docs - map",
        "",
        "Made by `tools/docs_index.py` - do not edit by hand, run the script.",
        "Start at the root [README.md](../README.md) and [AGENTS.md](../AGENTS.md).",
        "",
        "| Where | What |",
        "|---|---|",
        "| [wiki/](wiki/) | How things work now, plans, backlog. Check each page's Status line |",
        "| [decision/](decision/) | Why things are built this way. A newer record can replace an older one: check Status |",
        "| [design/DESIGN.md](design/DESIGN.md) | UI style (\"Island Workshop\") |",
        "| [reference/](reference/) | Outside research (other games, Godot notes, world gen). Read instead of re-researching |",
        "| [superpowers/plans/](superpowers/plans/) | Old step-by-step build plans (done) |",
        "| [demo/](demo/) | Videos and screenshots, not docs |",
        "",
        "## Wiki",
        "",
    ]
    wiki = [(f"[{p.stem}](wiki/{p.name})", *title_and_status(p))
            for p in sorted((DOCS / "wiki").glob("*.md"))]
    lines += table([(link, t, relink(s, "wiki")) for link, t, s in wiki], ("Page", "Title"))
    lines += ["", "## Decisions", ""]
    dec = []
    for p in sorted((DOCS / "decision").glob("[0-9]*.md")):
        t, s = title_and_status(p)
        t = re.sub(r"^\d{4}\s*[-—:.]\s*", "", t)
        dec.append((f"[{p.stem[:4]}](decision/{p.name})", t, relink(s, "decision")))
    lines += table(dec, ("#", "Decision"))
    missing = [r[0] for r in wiki + dec if not r[2]]
    (DOCS / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"docs/README.md: {len(wiki)} wiki pages, {len(dec)} decisions")
    if missing:
        print("No **Status:** line:", ", ".join(missing))


if __name__ == "__main__":
    main()
