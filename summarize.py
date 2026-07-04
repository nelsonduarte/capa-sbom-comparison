#!/usr/bin/env python3
"""Roll the captured results up into a Markdown summary table."""
import json
import os
import re
import sys


def count(path: str):
    try:
        with open(path, encoding="utf-8") as fh:
            return len(json.load(fh).get("components", []))
    except Exception:
        return None


def syft_summary_count(path: str):
    try:
        with open(path, encoding="utf-8") as fh:
            m = re.search(r"syft components:\s*(\d+)", fh.read())
            return int(m.group(1)) if m else None
    except Exception:
        return None


def cell(n, blind_note="-"):
    return str(n) if n not in (None, 0) else blind_note


def main(out: str) -> None:
    cap = os.path.join(out, "capa-project")
    py = os.path.join(out, "python-project")

    syft_capa = count(os.path.join(cap, "syft.cyclonedx.json"))
    cdxgen_capa = count(os.path.join(cap, "cdxgen.cyclonedx.json"))
    capa_capa = count(os.path.join(cap, "capa.cyclonedx.json"))
    cdxgen_py = count(os.path.join(py, "cdxgen.cyclonedx.json"))
    syft_py = syft_summary_count(os.path.join(py, "syft.summary.txt"))

    surface = ""
    sp = os.path.join(cap, "capability-surface.txt")
    if os.path.exists(sp):
        with open(sp, encoding="utf-8") as fh:
            surface = fh.read().strip()

    print("# Results\n")
    print("Component counts each tool produced on the same targets.\n")
    print("## Target A - a Capa project (`capa_paymentguard`)\n")
    print("| tool | components | what it captured |")
    print("|------|-----------:|------------------|")
    print(f"| syft | {cell(syft_capa)} | only GitHub Actions quoted in CI YAML; none of the real deps |")
    print(f"| cdxgen | {cell(cdxgen_capa)} | emits a BOM with zero components; no recognized manifest |")
    print(f"| **capa** | **{cell(capa_capa)}** | functions + capabilities, **plus the authority surface below** |")
    print()
    print("### Authority surface (capa only)\n")
    print("```")
    print(surface)
    print("```\n")
    print("## Target B - a Python project (the Capa compiler itself)\n")
    print("| tool | components | what it captured |")
    print("|------|-----------:|------------------|")
    print(f"| cdxgen | {cell(cdxgen_py)} | clean, deduplicated Python dependency inventory |")
    print(f"| syft | {cell(syft_py)} | wider net: language packages + OS/runtime binaries in the tree |")
    print(f"| capa | - | N/A - capa analyzes Capa source, not PyPI |")
    print()
    print("_Regenerate everything with `./compare.sh`._")


if __name__ == "__main__":
    main(sys.argv[1])
