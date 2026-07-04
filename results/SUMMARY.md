# Results

Component counts each tool produced on the same targets.

## Target A - a Capa project (`capa_paymentguard`)

| tool | components | what it captured |
|------|-----------:|------------------|
| syft | 6 | only GitHub Actions quoted in CI YAML; none of the real deps |
| cdxgen | - | emits a BOM with zero components; no recognized manifest |
| **capa** | **72** | functions + capabilities, **plus the authority surface below** |

### Authority surface (capa only)

```
program              : main.capa
capa_version         : 1.15.1
functions analyzed   : 70
user_defined_caps    : []

entry point          : main  (main.capa:168:5)
  declared           : ['Fs', 'Stdio']
  transitively used  : ['Fs', 'Stdio']
  PROVABLY EXCLUDED   : ['Clock', 'Db', 'Env', 'Net', 'Proc', 'Random', 'Unsafe']

program-wide reachable authority : ['Fs', 'Stdio']
```

## Target B - a Python project (the Capa compiler itself)

| tool | components | what it captured |
|------|-----------:|------------------|
| cdxgen | 114 | clean, deduplicated Python dependency inventory |
| syft | 1216 | wider net: language packages + OS/runtime binaries in the tree |
| capa | - | N/A - capa analyzes Capa source, not PyPI |

_Regenerate everything with `./compare.sh`._
