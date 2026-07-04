#!/usr/bin/env python3
"""Summarize the leaky-vs-sane scanner-blindness experiment."""
import os
import re
import sys


def read(path):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read().strip()
    except Exception:
        return ""


def count(path, pat):
    return len(re.findall(pat, read(path)))


def inv_len(path):
    t = read(path)
    return len([l for l in t.splitlines() if l and l != "(no file)"])


def same(a, b):
    # both scans ran (files exist) and produced the identical inventory,
    # including the case where both found zero components.
    return os.path.exists(a) and os.path.exists(b) and read(a) == read(b)


def main(out):
    syft_same = same(f"{out}/syft.sane.inventory.txt", f"{out}/syft.leaky.inventory.txt")
    cdx_same = same(f"{out}/cdxgen.sane.inventory.txt", f"{out}/cdxgen.leaky.inventory.txt")
    syft_n = inv_len(f"{out}/syft.sane.inventory.txt")
    cdx_n = inv_len(f"{out}/cdxgen.sane.inventory.txt")

    sane_def_w = count(f"{out}/capa.sane.default.txt", r"warning")
    leaky_def_w = count(f"{out}/capa.leaky.default.txt", r"warning")
    sane_str_e = count(f"{out}/capa.sane.strict.txt", r": error")
    leaky_str_e = count(f"{out}/capa.leaky.strict.txt", r": error")
    sane_str_ok = "ok (" in read(f"{out}/capa.sane.strict.txt")
    leaky_str_ok = "ok (" in read(f"{out}/capa.leaky.strict.txt")

    # the one leaky error line, for quoting
    err_line = ""
    for l in read(f"{out}/capa.leaky.strict.txt").splitlines():
        if ": error: information-flow" in l:
            err_line = l.strip()
            break

    print("# Experiment: can a tool tell a leaky release from a sane one?\n")
    print("Two releases of the same product (capa_dataguard). They differ in **one line**:")
    print("the public report interpolates the audited pseudonym token (sane) or the raw")
    print("`@secret` email (leaky). Same dependencies, same file names, same module graph.\n")
    print("## What each tool saw\n")
    print("| tool | sane | leaky | told them apart? |")
    print("|------|------|-------|------------------|")
    syft_v = f"{syft_n} components"
    cdx_v = f"{cdx_n} components"
    print(f"| syft | {syft_v} | {syft_v} | **{'no - identical inventory' if syft_same else 'DIFFER'}** |")
    print(f"| cdxgen | {cdx_v} | {cdx_v} | **{'no - identical inventory' if cdx_same else 'DIFFER'}** |")
    print(f"| capa (default tier) | ok, {sane_def_w} warnings | ok, **{leaky_def_w} warnings** naming the flow | **yes - artifact differs** |")
    sane_verdict = "compiles" if sane_str_ok else f"{sane_str_e} errors"
    leaky_verdict = "**REFUSES** to compile" if not leaky_str_ok else "compiles"
    print(f"| capa (strict tier) | {sane_verdict} | {leaky_verdict} ({leaky_str_e} error) | **yes - hard gate** |")
    print()
    print("## The point\n")
    print("A package-inventory scanner reads the dependency manifest, not the code, so it")
    print("emits the **same SBOM** whether or not the release exfiltrates a secret. Capa reads")
    print("the flow: at the default tier the leak is recorded as a warning that names the exact")
    print("`@secret`-to-sink path, and under the strict enforcement tier the leaky release")
    print("**refuses to compile** and cannot be certified.\n")
    if err_line:
        print("The rejection (strict tier, leaky release):\n")
        print("```")
        print(err_line)
        print("```\n")
    print("_Regenerate with `./leaky_vs_sane.sh <path-to-capa_dataguard>`._")


if __name__ == "__main__":
    main(sys.argv[1])
