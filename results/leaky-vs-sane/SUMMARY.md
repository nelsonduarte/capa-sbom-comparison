# Experiment: can a tool tell a leaky release from a sane one?

Two releases of the same product (capa_dataguard). They differ in **one line**:
the public report interpolates the audited pseudonym token (sane) or the raw
`@secret` email (leaky). Same dependencies, same file names, same module graph.

## What each tool saw

| tool | sane | leaky | told them apart? |
|------|------|-------|------------------|
| syft | 6 components | 6 components | **no - identical inventory** |
| cdxgen | 0 components | 0 components | **no - identical inventory** |
| capa (default tier) | ok, 0 warnings | ok, **3 warnings** naming the flow | **yes - artifact differs** |
| capa (strict tier) | compiles | **REFUSES** to compile (1 error) | **yes - hard gate** |

## The point

A package-inventory scanner reads the dependency manifest, not the code, so it
emits the **same SBOM** whether or not the release exfiltrates a secret. Capa reads
the flow: at the default tier the leak is recorded as a warning that names the exact
`@secret`-to-sink path, and under the strict enforcement tier the leaky release
**refuses to compile** and cannot be certified.

The rejection (strict tier, leaky release):

```
dataguard.capa:67:42: error: information-flow: a @secret value reaches Fs.write (argument 2), a public sink that sends data out of the program. Route it through declassify(value, reason: "...") if this disclosure is intended.
```

_Regenerate with `./leaky_vs_sane.sh <path-to-capa_dataguard>`._
