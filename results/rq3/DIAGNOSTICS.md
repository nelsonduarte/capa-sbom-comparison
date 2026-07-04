# RQ3: analyzer diagnostic categories over the deliberate negatives

| Diagnostic category | Negatives | FP | FN |
|---|--:|--:|--:|
| capability in a data position | 1 | 0 | 0 |
| attenuated capability lacks method | 1 | 0 | 0 |
| capability aliased within one call | 1 | 0 | 0 |
| linear value consumed twice | 3 | 0 | 0 |
| linear value dropped | 1 | 0 | 0 |
| illegal typestate transition | 1 | 0 | 0 |
| secret reaches public sink | 6 | 0 | 1 |
| secret in control flow | 1 | 0 | 0 |
| type mismatch | 1 | 0 | 0 |

Total negatives: 16. False positives: 0. False negatives: 1 (closure-by-name,
which would fall in 'secret reaches public sink' if caught; see fn_closure_by_name.capa).

## Per-negative diagnostic
| Negative | Category |
|---|---|
| cap_violations.capa | capability in a data position |
| aliasing.capa | capability aliased within one call |
| consume.capa | linear value consumed twice |
| errors.capa | type mismatch |
| ct_secret_branch.capa | secret in control flow |
| ifc_leak_destructure.capa | secret reaches public sink |
| ifc_leak_field.capa | secret reaches public sink |
| linear_double_spend.capa | linear value consumed twice |
| linear_drop.capa | linear value dropped |
| typestate_skip_state.capa | illegal typestate transition |
| typestate_use_after.capa | linear value consumed twice |
| leaky_dataguard.capa | secret reaches public sink |
| leaky_supplygate.capa | secret reaches public sink |
| leaky_configbroker.capa | secret reaches public sink |
| leaky_licenseaudit.capa | attenuated capability lacks method |
| leaky_example.capa | secret reaches public sink |
