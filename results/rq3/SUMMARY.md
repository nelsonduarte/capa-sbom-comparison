# RQ3: analyzer coverage and precision

## Table A - coverage
| Program set | Programs | Accepted | Rejected | Expected |
|---|--:|--:|--:|---|
| Valid corpus | 198 | 198 | 0 | all accepted |
| Deliberate negatives | 4 | 0 | 4 | verified rejected |
| claimdesk negatives | 7 | 0 | 7 | verified rejected |
| leaky_* variants (5 projects) | 5 | 0 | 5 | verified rejected |

## Table B - precision by discipline
| Discipline | Negatives | Rejected | FN | Representative diagnostic |
|---|--:|--:|--:|---|
| Capability (undeclared authority) | 2 | 2 | 0 | undefined name 'fs' / no method 'write' |
| Linearity (consume / alias) | 4 | 4 | 0 | capability was consumed earlier |
| Typestate | 2 | 2 | 0 | argument expects Claim[UnderReview], got Claim[Draft] |
| Information flow (@secret) | 7 | 7 | 1 | @secret value reaches public sink |

False positives: 0 (all 198 valid programs accepted).
False negatives: 1 (closure-by-name, exercised in fn_closure_by_name.capa: accepted by --check, leaks at runtime; documented residual).
Note: errors.capa (1) is a base type-checking negative, rejected, outside the four security disciplines.
