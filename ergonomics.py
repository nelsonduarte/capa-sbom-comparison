#!/usr/bin/env python3
"""Measure the annotation burden of the capability discipline.

Reads capa --manifest JSON files (one per application) and reports, per
application and in aggregate, two facts derived from the compiler's own
`is_capability` flag on each parameter:

  - the share of functions that take NO capability parameter (pure logic);
  - the share of all parameters that are capabilities (the plumbing).

The claim it supports is not that the discipline is pleasant, only that
the capability threading is concentrated at the authority boundary rather
than spread through the code.

Usage: ergonomics.py <dir-of-manifest-json-files>
"""
import glob
import json
import os
import sys


def main(d):
    tot_fn = cap_fn = tot_p = cap_p = 0
    rows = []
    for f in sorted(glob.glob(os.path.join(d, "*.json"))):
        try:
            m = json.load(open(f, encoding="utf-8"))
        except Exception:
            continue
        fns = m.get("functions", [])
        if not fns:
            continue
        tf = len(fns)
        cf = tp = cp = 0
        for fn in fns:
            ps = fn.get("params", []) or []
            caps = [p for p in ps if p.get("is_capability")]
            tp += len(ps)
            cp += len(caps)
            if caps:
                cf += 1
        pure = tf - cf
        rows.append((os.path.basename(f)[:-5], tf, pure, tp, cp))
        tot_fn += tf
        cap_fn += cf
        tot_p += tp
        cap_p += cp

    def pct(n, d):
        return round(100 * n / d) if d else 0

    print(f"| application | functions | pure (no cap) | pure % | cap params | all params | cap % |")
    print(f"|-------------|----------:|--------------:|-------:|-----------:|-----------:|------:|")
    for name, tf, pure, tp, cp in rows:
        print(f"| {name} | {tf} | {pure} | {pct(pure, tf)}% | {cp} | {tp} | {pct(cp, tp)}% |")
    pure = tot_fn - cap_fn
    print(f"| **total** | **{tot_fn}** | **{pure}** | **{pct(pure, tot_fn)}%** | **{cap_p}** | **{tot_p}** | **{pct(cap_p, tot_p)}%** |")
    print()
    print(f"Across {len(rows)} applications: **{pct(pure, tot_fn)}%** of functions take no "
          f"capability parameter, and capabilities are **{pct(cap_p, tot_p)}%** of all parameters.")


if __name__ == "__main__":
    main(sys.argv[1])
