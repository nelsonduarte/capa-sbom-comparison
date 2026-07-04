#!/usr/bin/env bash
#
# compare.sh - run syft, cdxgen and capa over the same targets and
# capture their SBOM output side by side, then write a summary.
#
# The point is not a benchmark. It is to show, on real projects, that
# syft/cdxgen produce a PACKAGE INVENTORY (what ships) while capa also
# produces a CAPABILITY / AUTHORITY surface (what the code can reach,
# and what it provably cannot) - a dimension the scanners do not have.
#
# Usage:
#   ./compare.sh <capa-project-dir> <capa-entrypoint.capa> <python-project-dir>
#
# Requirements on PATH: syft, npx (for @cyclonedx/cdxgen), and capa
# (or `python -m capa`). Missing tools are reported and skipped, not
# fatal - so the parts you can run still run.
#
set -uo pipefail

CAPA_PROJ="${1:?need a Capa project dir}"
CAPA_MAIN="${2:?need the Capa entrypoint .capa file}"
PY_PROJ="${3:?need a Python project dir}"

HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/results"
CAP_OUT="$OUT/capa-project"
PY_OUT="$OUT/python-project"
mkdir -p "$CAP_OUT" "$PY_OUT"

# capa may be an installed shim or `python -m capa`.
CAPA="capa"
command -v capa >/dev/null 2>&1 || CAPA="python -m capa"

have() { command -v "$1" >/dev/null 2>&1; }
count() { python -c "import json,sys;print(len(json.load(open(sys.argv[1],encoding='utf-8')).get('components',[])))" "$1" 2>/dev/null || echo "?"; }

echo "==> tool versions"
{ echo "date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'syft:   '; have syft && syft version 2>/dev/null | awk '/Version:/{print $2}' | head -1 || echo "MISSING"
  printf 'cdxgen: '; have npx && (npx --yes @cyclonedx/cdxgen@latest --version 2>/dev/null | tail -1) || echo "MISSING"
  printf 'capa:   '; $CAPA --version 2>/dev/null || echo "MISSING"
} | tee "$OUT/versions.txt"

# ---------------------------------------------------------------------
# 1. The scanners on the Capa project - they do not understand capa.lock
# ---------------------------------------------------------------------
echo "==> [capa project] syft"
if have syft; then
  syft scan "$CAPA_PROJ" -o cyclonedx-json="$CAP_OUT/syft.cyclonedx.json" -q 2>"$CAP_OUT/syft.log" \
    && echo "    syft components: $(count "$CAP_OUT/syft.cyclonedx.json")"
fi

echo "==> [capa project] cdxgen"
if have npx; then
  ( cd "$CAPA_PROJ" && npx --yes @cyclonedx/cdxgen@latest -o "$CAP_OUT/cdxgen.cyclonedx.json" . ) \
    >"$CAP_OUT/cdxgen.log" 2>&1 || true
  if [ -f "$CAP_OUT/cdxgen.cyclonedx.json" ]; then
    echo "    cdxgen components: $(count "$CAP_OUT/cdxgen.cyclonedx.json")"
  else
    echo "    cdxgen: no BOM emitted (no recognized manifest)" | tee -a "$CAP_OUT/cdxgen.log"
  fi
fi

# ---------------------------------------------------------------------
# 2. capa on the same project - inventory PLUS authority
# ---------------------------------------------------------------------
# capa resolves imported modules and dependencies relative to the
# project root, so run it from inside the project with a relative
# entrypoint.
CAPA_ENTRY="$(basename "$CAPA_MAIN")"

echo "==> [capa project] capa --cyclonedx"
( cd "$CAPA_PROJ" && $CAPA --cyclonedx "$CAPA_ENTRY" ) > "$CAP_OUT/capa.cyclonedx.json" 2>"$CAP_OUT/capa.log" \
  && echo "    capa components: $(count "$CAP_OUT/capa.cyclonedx.json")"

echo "==> [capa project] capa --manifest (capability surface)"
( cd "$CAPA_PROJ" && $CAPA --manifest "$CAPA_ENTRY" ) > "$CAP_OUT/capa.manifest.json" 2>>"$CAP_OUT/capa.log"
python "$HERE/extract_capabilities.py" "$CAP_OUT/capa.manifest.json" > "$CAP_OUT/capability-surface.txt" \
  && cat "$CAP_OUT/capability-surface.txt"

# ---------------------------------------------------------------------
# 3. In fairness: the scanners on a real Python project (the compiler)
# ---------------------------------------------------------------------
echo "==> [python project] cdxgen"
if have npx; then
  ( cd "$PY_PROJ" && npx --yes @cyclonedx/cdxgen@latest -o "$PY_OUT/cdxgen.cyclonedx.json" -t python . ) \
    >"$PY_OUT/cdxgen.log" 2>&1 || true
  [ -f "$PY_OUT/cdxgen.cyclonedx.json" ] && echo "    cdxgen components: $(count "$PY_OUT/cdxgen.cyclonedx.json")"
fi

echo "==> [python project] syft (wide scan - summarized, not committed in full)"
if have syft; then
  syft scan "$PY_PROJ" -o cyclonedx-json="$PY_OUT/syft.full.json" -q 2>"$PY_OUT/syft.log"
  n="$(count "$PY_OUT/syft.full.json")"
  python -c "
import json,sys
c=json.load(open(sys.argv[1],encoding='utf-8')).get('components',[])
print('syft components:', len(c))
print('sample (first 20):')
for x in c[:20]: print('  -', x.get('name'), x.get('version'))
" "$PY_OUT/syft.full.json" > "$PY_OUT/syft.summary.txt"
  rm -f "$PY_OUT/syft.full.json"   # too large / noisy to commit; regenerate on demand
  echo "    syft components: $n (full JSON not kept - see syft.summary.txt)"
fi

# ---------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------
python "$HERE/summarize.py" "$OUT" > "$OUT/SUMMARY.md"
echo "==> wrote $OUT/SUMMARY.md"
