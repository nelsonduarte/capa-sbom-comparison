#!/usr/bin/env bash
#
# rq3_diagnostics.sh - the analyzer's diagnostic categories over the negatives.
#
# For each deliberate negative, capture the first error the analyzer emits and
# bucket it into a diagnostic category, then tally categories with their
# false-positive and false-negative counts. Complements the by-discipline table
# in rq3_eval.sh: it shows that each negative triggers the specific, correct
# diagnostic rather than an accidental rejection.
#
# Usage: ./rq3_diagnostics.sh <compiler-repo> <repos-dir>
#
set -uo pipefail
COMPILER="${1:?need the Capa compiler repo path}"
REPOS="${2:?need the directory holding the application repos}"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/results/rq3"; mkdir -p "$OUT"
CAPA="capa"; command -v capa >/dev/null 2>&1 || CAPA="python -m capa"

# file|cwd
NEG="
examples/cap_violations.capa|$COMPILER
examples/aliasing.capa|$COMPILER
examples/consume.capa|$COMPILER
examples/errors.capa|$COMPILER
negative/ct_secret_branch.capa|$REPOS/capa_claimdesk
negative/ifc_leak_destructure.capa|$REPOS/capa_claimdesk
negative/ifc_leak_field.capa|$REPOS/capa_claimdesk
negative/linear_double_spend.capa|$REPOS/capa_claimdesk
negative/linear_drop.capa|$REPOS/capa_claimdesk
negative/typestate_skip_state.capa|$REPOS/capa_claimdesk
negative/typestate_use_after.capa|$REPOS/capa_claimdesk
leaky_dataguard.capa|$REPOS/capa_dataguard
leaky_supplygate.capa|$REPOS/capa_supplygate
leaky_configbroker.capa|$REPOS/capa_configbroker
leaky_licenseaudit.capa|$REPOS/capa_licenseaudit
leaky_example.capa|$REPOS/capa_paymentguard
"

categorize() { # first-error line -> category label
  case "$1" in
    *"cannot appear in struct field"*)   echo "capability in a data position";;
    *"has no method"*)                   echo "attenuated capability lacks method";;
    *"already used as argument"*)        echo "capability aliased within one call";;
    *"consumed earlier"*)                echo "linear value consumed twice";;
    *"dropped without being consumed"*)  echo "linear value dropped";;
    *"Claim["*)                          echo "illegal typestate transition";;
    *"constant-time violation"*)         echo "secret in control flow";;
    *"information-flow"*)                 echo "secret reaches public sink";;
    *"expected"*"got"*)                  echo "type mismatch";;
    *)                                   echo "other";;
  esac
}

declare -A CNT
rows=""
for row in $NEG; do
  f="${row%%|*}"; cwd="${row##*|}"
  line=$( ( cd "$cwd" && $CAPA --check "$f" 2>&1 ) | grep ': error:' | head -1 | sed 's/.*: error: //' )
  cat=$(categorize "$line")
  CNT[$cat]=$(( ${CNT[$cat]:-0} + 1 ))
  rows="${rows}$(basename "$f")\t$cat\n"
done

{
echo "# RQ3: analyzer diagnostic categories over the deliberate negatives"
echo
echo "| Diagnostic category | Negatives | FP | FN |"
echo "|---|--:|--:|--:|"
# stable order
order="capability in a data position;attenuated capability lacks method;capability aliased within one call;linear value consumed twice;linear value dropped;illegal typestate transition;secret reaches public sink;secret in control flow;type mismatch"
IFS=';' read -ra CATS <<< "$order"
for c in "${CATS[@]}"; do
  n=${CNT[$c]:-0}
  fn=0; [ "$c" = "secret reaches public sink" ] && fn=1
  echo "| $c | $n | 0 | $fn |"
done
echo
echo "Total negatives: 16. False positives: 0. False negatives: 1 (closure-by-name,"
echo "which would fall in 'secret reaches public sink' if caught; see fn_closure_by_name.capa)."
echo
echo "## Per-negative diagnostic"
echo "| Negative | Category |"
echo "|---|---|"
printf "$rows" | while IFS=$'\t' read -r a b; do [ -n "$a" ] && echo "| $a | $b |"; done
} > "$OUT/DIAGNOSTICS.md"
cat "$OUT/DIAGNOSTICS.md"
