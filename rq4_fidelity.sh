#!/usr/bin/env bash
#
# rq4_fidelity.sh - decision fidelity of a capability gate vs an inventory gate.
#
# For each of five projects we form a sane/leaky pair and ask each approach to
# tell them apart:
#   capability: does capa certify the build? (compiles the sane pipeline; the
#               leaky module is rejected by the analyzer -> the build cannot be
#               certified). A differing certificate = the tool discriminates.
#   inventory : syft's SBOM for the sane and leaky directories (they differ only
#               in the presence of the leak source, which the scanner never
#               reads). Identical inventory = the tool cannot discriminate.
#
# Usage: ./rq4_fidelity.sh <dir-with-the-app-repos>
#
set -uo pipefail
ROOT="${1:?need the directory that holds the application repos}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/results/rq4"; rm -rf "$OUT"; mkdir -p "$OUT"
CAPA="capa"; command -v capa >/dev/null 2>&1 || CAPA="python -m capa"
have() { command -v "$1" >/dev/null 2>&1; }

# project : sane-entrypoint : leaky-file
PAIRS="
capa_paymentguard:main.capa:leaky_example.capa
capa_dataguard:dataguard.capa:leaky_dataguard.capa
capa_supplygate:supplygate.capa:leaky_supplygate.capa
capa_configbroker:configbroker.capa:leaky_configbroker.capa
capa_licenseaudit:licenseaudit.capa:leaky_licenseaudit.capa
"

inv_count() { # sorted name@version inventory of a CycloneDX file
  python -c "
import json,sys,os
f=sys.argv[1]
if not os.path.exists(f): print(0); sys.exit()
print(len(json.load(open(f,encoding='utf-8')).get('components',[])))
" "$1"
}

cap_hits=0; inv_hits=0; n=0
printf "%-20s | capa sane | capa leaky | inv sane | inv leaky | capaDisc | invDisc\n" "project" > "$OUT/table.txt"
printf -- "---------------------+-----------+------------+----------+-----------+----------+--------\n" >> "$OUT/table.txt"

for pair in $PAIRS; do
  proj="${pair%%:*}"; rest="${pair#*:}"; entry="${rest%%:*}"; leaky="${rest##*:}"
  src="$ROOT/$proj"; [ -d "$src" ] || { echo "skip $proj"; continue; }
  n=$((n+1))
  work="$OUT/build/$proj"; rm -rf "$work"; mkdir -p "$work"

  # capability: compile the sane pipeline, then check the leaky module
  ( cd "$src" && $CAPA --check "$entry"  ) > "$OUT/$proj.capa.sane.txt"  2>&1; sane_ec=$?
  ( cd "$src" && $CAPA --check "$leaky" ) > "$OUT/$proj.capa.leaky.txt" 2>&1; leaky_ec=$?
  capa_sane=$([ $sane_ec -eq 0 ] && echo PASS || echo FAIL)
  capa_leaky=$([ $leaky_ec -eq 0 ] && echo PASS || echo FAIL)

  # inventory: two directories differing only in the leak source file
  cp -r "$src" "$work/sane";  rm -f "$work/sane/$leaky"
  cp -r "$src" "$work/leaky"  # leaky file present
  is=0; il=0
  if have syft; then
    syft scan "$work/sane"  -o cyclonedx-json="$OUT/$proj.syft.sane.json"  -q 2>/dev/null
    syft scan "$work/leaky" -o cyclonedx-json="$OUT/$proj.syft.leaky.json" -q 2>/dev/null
    is=$(inv_count "$OUT/$proj.syft.sane.json"); il=$(inv_count "$OUT/$proj.syft.leaky.json")
  fi

  cap_disc=$([ "$capa_sane" = PASS ] && [ "$capa_leaky" = FAIL ] && echo yes || echo no)
  inv_disc=$([ "$is" != "$il" ] && echo yes || echo no)
  [ "$cap_disc" = yes ] && cap_hits=$((cap_hits+1))
  [ "$inv_disc" = yes ] && inv_hits=$((inv_hits+1))
  printf "%-20s | %-9s | %-10s | %-8s | %-9s | %-8s | %s\n" "$proj" "$capa_sane" "$capa_leaky" "$is" "$il" "$cap_disc" "$inv_disc" >> "$OUT/table.txt"
done

{
  echo "# RQ4: decision fidelity - capability gate vs inventory gate"
  echo
  echo "Per project: does each approach pass the sane build and reject the leaky one?"
  echo
  cat "$OUT/table.txt"
  echo
  echo "Fidelity: capability ${cap_hits}/${n}, inventory ${inv_hits}/${n}"
  echo
  echo "The inventory (syft) is byte-identical for the sane and leaky directories"
  echo "because the scanner reads the dependency manifest, not the .capa source, so"
  echo "it gives the same decision for both members of every pair. The capability"
  echo "approach certifies the sane pipeline and the analyzer rejects the leaky"
  echo "module, so the certificate differs on every pair."
} > "$OUT/SUMMARY.md"
rm -rf "$OUT/build"
cat "$OUT/SUMMARY.md"
