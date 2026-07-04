#!/usr/bin/env python3
"""Extract the capability / authority surface from a capa --manifest JSON.

This is the dimension syft and cdxgen do not produce: for each entry
point, which capabilities the code can actually reach, and which are
provably excluded by the type system.
"""
import json
import sys


def main(path: str) -> None:
    with open(path, encoding="utf-8") as fh:
        manifest = json.load(fh)

    fns = manifest.get("functions", [])
    used: set[str] = set()
    reach: set[str] = set()
    for f in fns:
        used.update(f.get("declared_capabilities", []) or [])
        reach.update(f.get("transitively_reachable_capabilities", []) or [])

    print(f"program              : {manifest.get('filename')}")
    print(f"capa_version         : {manifest.get('capa_version')}")
    print(f"functions analyzed   : {len(fns)}")
    print(f"user_defined_caps    : {manifest.get('user_defined_capabilities') or '[]'}")
    print()

    entry = [f for f in fns if f.get("name") == "main"] or fns
    f = entry[0]
    print(f"entry point          : {f.get('name')}  ({f.get('pos')})")
    print(f"  declared           : {sorted(f.get('declared_capabilities', []) or [])}")
    print(f"  transitively used  : {sorted(f.get('transitively_reachable_capabilities', []) or [])}")
    print(f"  PROVABLY EXCLUDED   : {sorted(f.get('provably_excluded_capabilities', []) or [])}")
    print()
    print(f"program-wide reachable authority : {sorted(reach)}")


if __name__ == "__main__":
    main(sys.argv[1])
