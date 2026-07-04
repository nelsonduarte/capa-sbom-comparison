#!/usr/bin/env bash
#
# ergonomics.sh - measure the capability annotation burden across a set
# of Capa applications by running `capa --manifest` on each and feeding
# the manifests to ergonomics.py.
#
# Usage: ./ergonomics.sh <dir-containing-the-application-repos>
#
set -uo pipefail
ROOT="${1:?need the directory that holds the application repos}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CAPA="capa"; command -v capa >/dev/null 2>&1 || CAPA="python -m capa"

# application : entrypoint
APPS="
capa_paymentguard:main.capa
capa_dataguard:dataguard.capa
capa_supplygate:supplygate.capa
capa_configbroker:configbroker.capa
capa_licenseaudit:licenseaudit.capa
capa_claimdesk:main.capa
audit-trail-reporter:reporter.capa
sbom-watch:watch.capa
policy-eval:policy_eval.capa
capa_governance_pack:governance.capa
"

TMP="$(mktemp -d)"
for pair in $APPS; do
  app="${pair%%:*}"; entry="${pair##*:}"
  [ -d "$ROOT/$app" ] || { echo "skip $app (not found)"; continue; }
  ( cd "$ROOT/$app" && $CAPA --manifest "$entry" ) > "$TMP/$app.json" 2>/dev/null
done

{
  echo "# Ergonomics: how much of the code is capability plumbing?"
  echo
  echo "Derived from each application's \`capa --manifest\` (the compiler's own"
  echo "\`is_capability\` flag), not a textual heuristic. Measures where the"
  echo "capability threading lives, not whether the discipline is pleasant."
  echo
  python "$HERE/ergonomics.py" "$TMP"
  echo
  echo "_Regenerate with \`./ergonomics.sh <dir-with-the-app-repos>\`._"
} > "$HERE/results/ergonomics.md"
rm -rf "$TMP"
echo "wrote $HERE/results/ergonomics.md"
cat "$HERE/results/ergonomics.md"
