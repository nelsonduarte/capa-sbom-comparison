#!/usr/bin/env bash
#
# leaky_vs_sane.sh - the scanner-blindness experiment.
#
# Build two releases of the same product that differ in ONE line: whether
# a subject line in the public report carries the audited pseudonym token
# (sane) or the raw @secret email (leaky). Everything else - dependencies,
# file names, module graph - is identical.
#
# Then ask each tool to tell the two apart:
#   - syft / cdxgen: emit SBOMs for both; compare the component inventory.
#   - capa: --check both, at the default tier and the strict tier.
#
# The leak is specified here, as a documented transformation of a COPY,
# so the experiment is reproducible and the original project is untouched.
#
# Usage: ./leaky_vs_sane.sh <path-to-capa_dataguard>
#
set -uo pipefail

SRC="${1:?need a path to a capa_dataguard checkout}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/results/leaky-vs-sane"
WORK="$OUT/build"
rm -rf "$WORK"; mkdir -p "$WORK" "$OUT"

CAPA="capa"; command -v capa >/dev/null 2>&1 || CAPA="python -m capa"
have() { command -v "$1" >/dev/null 2>&1; }

# --- build the two releases -------------------------------------------
for variant in sane leaky; do
  d="$WORK/$variant"
  cp -r "$SRC" "$d"
  # isolate the pipeline: drop the standalone counter-example the repo
  # ships, so both releases are exactly the shipped pipeline.
  rm -f "$d/leaky_dataguard.capa"
done

# THE ONE-LINE DIFFERENCE: in the leaky release, the public report line
# interpolates the raw @secret email instead of the audited pseudonym
# token. This is the whole change.
sed -i 's/\${token}  region=/\${r.email}  region=/' "$WORK/leaky/report.capa"

echo "==> the entire difference between the two releases:"
diff "$WORK/sane/report.capa" "$WORK/leaky/report.capa" | tee "$OUT/the-diff.txt"

# --- 1. scanners: can they tell the two apart? ------------------------
inv() { # extract a sorted (name@version) inventory from a CycloneDX file
  python -c "
import json,sys,os
f=sys.argv[1]
if not os.path.exists(f): print('(no file)'); sys.exit()
c=json.load(open(f,encoding='utf-8')).get('components',[])
for x in sorted(('%s@%s'%(d.get('name'),d.get('version')) for d in c)): print(x)
" "$1"
}

for variant in sane leaky; do
  d="$WORK/$variant"
  if have syft; then
    syft scan "$d" -o cyclonedx-json="$OUT/syft.$variant.json" -q 2>/dev/null
    inv "$OUT/syft.$variant.json" > "$OUT/syft.$variant.inventory.txt"
  fi
  if have npx; then
    ( cd "$d" && npx --yes @cyclonedx/cdxgen@latest -o "$OUT/cdxgen.$variant.json" . ) >/dev/null 2>&1 || true
    inv "$OUT/cdxgen.$variant.json" > "$OUT/cdxgen.$variant.inventory.txt"
  fi
done

echo "==> syft inventory: sane vs leaky"
if diff -q "$OUT/syft.sane.inventory.txt" "$OUT/syft.leaky.inventory.txt" >/dev/null 2>&1; then
  echo "    IDENTICAL ($(wc -l < "$OUT/syft.sane.inventory.txt") components) - the scanner cannot tell them apart"
else
  echo "    DIFFER:"; diff "$OUT/syft.sane.inventory.txt" "$OUT/syft.leaky.inventory.txt"
fi
echo "==> cdxgen inventory: sane vs leaky"
if diff -q "$OUT/cdxgen.sane.inventory.txt" "$OUT/cdxgen.leaky.inventory.txt" >/dev/null 2>&1; then
  echo "    IDENTICAL ($(wc -l < "$OUT/cdxgen.sane.inventory.txt") components)"
else
  echo "    DIFFER:"; diff "$OUT/cdxgen.sane.inventory.txt" "$OUT/cdxgen.leaky.inventory.txt"
fi

# --- 2. capa at the default tier --------------------------------------
# capa resolves vendored deps relative to the project root, so run it
# from inside each build.
echo "==> capa --check (default tier)"
( cd "$WORK/sane"  && $CAPA --check dataguard.capa ) > "$OUT/capa.sane.default.txt"  2>&1
( cd "$WORK/leaky" && $CAPA --check dataguard.capa ) > "$OUT/capa.leaky.default.txt" 2>&1
echo "    sane : $(grep -cE 'warning' "$OUT/capa.sane.default.txt") warnings, $(grep -cE ': error' "$OUT/capa.sane.default.txt") errors"
echo "    leaky: $(grep -cE 'warning' "$OUT/capa.leaky.default.txt") warnings, $(grep -cE ': error' "$OUT/capa.leaky.default.txt") errors"

# --- 3. capa at the strict tier ---------------------------------------
# grade the sink-holding function @strict_ifc in BOTH releases (the
# enforcement tier a compliance build uses); the tier is held constant,
# only the flow differs.
for variant in sane leaky; do
  sed -i 's/^\(pub \)\?fun run_pipeline/@strict_ifc()\n&/' "$WORK/$variant/dataguard.capa"
  ( cd "$WORK/$variant" && $CAPA --check dataguard.capa ) > "$OUT/capa.$variant.strict.txt" 2>&1
done
echo "==> capa --check (strict tier: @strict_ifc on the sink)"
echo "    sane : $(grep -cE ': error' "$OUT/capa.sane.strict.txt") errors  -> $(grep -qE 'ok \(' "$OUT/capa.sane.strict.txt" && echo COMPILES || echo REJECTED)"
echo "    leaky: $(grep -cE ': error' "$OUT/capa.leaky.strict.txt") errors  -> $(grep -qE 'ok \(' "$OUT/capa.leaky.strict.txt" && echo COMPILES || echo REJECTED)"

# --- summary ----------------------------------------------------------
python "$HERE/summarize_leaky.py" "$OUT" > "$OUT/SUMMARY.md"
rm -rf "$WORK"   # snapshots are regenerable; keep only the captured outputs
echo "==> wrote $OUT/SUMMARY.md"
