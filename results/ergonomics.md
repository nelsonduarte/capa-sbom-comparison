# Ergonomics: how much of the code is capability plumbing?

Derived from each application's `capa --manifest` (the compiler's own
`is_capability` flag), not a textual heuristic. Measures where the
capability threading lives, not whether the discipline is pleasant.

| application | functions | pure (no cap) | pure % | cap params | all params | cap % |
|-------------|----------:|--------------:|-------:|-----------:|-----------:|------:|
| audit-trail-reporter | 68 | 58 | 85% | 15 | 129 | 12% |
| capa_claimdesk | 213 | 193 | 91% | 32 | 377 | 8% |
| capa_configbroker | 37 | 31 | 84% | 9 | 60 | 15% |
| capa_dataguard | 66 | 64 | 97% | 3 | 90 | 3% |
| capa_governance_pack | 40 | 32 | 80% | 14 | 94 | 15% |
| capa_licenseaudit | 61 | 57 | 93% | 9 | 95 | 9% |
| capa_paymentguard | 70 | 66 | 94% | 5 | 131 | 4% |
| capa_supplygate | 43 | 40 | 93% | 4 | 67 | 6% |
| policy-eval | 67 | 58 | 87% | 14 | 144 | 10% |
| sbom-watch | 60 | 50 | 83% | 15 | 127 | 12% |
| **total** | **725** | **649** | **90%** | **120** | **1314** | **9%** |

Across 10 applications: **90%** of functions take no capability parameter, and capabilities are **9%** of all parameters.

_Regenerate with `./ergonomics.sh <dir-with-the-app-repos>`._
