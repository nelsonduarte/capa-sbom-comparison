# Inventory vs. Authority: Capa next to syft and cdxgen

A small, reproducible field comparison of three SBOM tools on **the same
real projects**. The numbers in this repo were produced by
[`compare.sh`](compare.sh); the raw outputs are committed under
[`results/`](results/).

## The question each tool answers

`syft` and `cdxgen` are package-inventory scanners. They answer:

> **What is inside this artifact?** — a bill of materials, discovered by
> scanning files and lockfiles.

Capa answers a different question:

> **What can this code actually do?** — a bill of *authority*, derived by
> construction from the type system: which capabilities each entry point
> can reach, and which it *provably cannot*.

The first is inference over what ships. The second is proof over what is
reachable. Neither subsumes the other — but only one of them can hand you
a payment processor together with a proof that it cannot open a socket.

## What the runs show

### Target A — a Capa project (`capa_paymentguard`)

A working Capa program: a payment-risk pipeline, 70 functions across nine
modules, two dependencies pinned by tag + commit + signing key in
`capa.lock`.

| tool | components | what it captured |
|------|-----------:|------------------|
| syft | **6** | only the GitHub Actions quoted in the CI workflow YAML — none of the program's real dependencies, no capabilities |
| cdxgen | **0** | emits a BOM with zero components — no manifest it recognizes (`package.json` / `requirements.txt` absent) |
| **capa** | **72** | a component per function and capability, **plus the authority surface below** |

The authority surface no scanner produces
([`results/capa-project/capability-surface.txt`](results/capa-project/capability-surface.txt)):

```
entry point          : main  (main.capa:168:5)
  declared           : ['Fs', 'Stdio']
  transitively used  : ['Fs', 'Stdio']
  PROVABLY EXCLUDED   : ['Clock', 'Db', 'Env', 'Net', 'Proc', 'Random', 'Unsafe']
```

Read the last line precisely. It does not say *"we scanned and found no
networking code."* It says the compiler **proved** that no path from this
payment processor reaches a socket, spawns a process, or reads an
environment secret. That is a claim a reviewer, an auditor, or a CI gate
can rely on — and it is exactly the claim a package inventory cannot make.

### Target B — a Python project (the Capa compiler itself)

In fairness: point the scanners at something they are built for.

| tool | components | what it captured |
|------|-----------:|------------------|
| cdxgen | **114** | a clean, deduplicated Python dependency inventory (uvicorn, urllib3, starlette, semgrep, …), each with version and purl |
| syft | **1216** | a wider net still — language packages plus OS and runtime binaries found in the tree |
| capa | — | N/A — Capa analyzes Capa source, not PyPI |

**Breadth belongs to the scanners.** They cover ecosystems Capa will
never touch, and a real supply-chain program needs that inventory. What
they cannot do is state what the shipped code is *allowed* to do.

## Can a tool tell a leaky release from a sane one?

The sharper experiment. Two releases of the same product (`capa_dataguard`)
that differ in **one line**: a subject line in the public report carries the
audited pseudonym token (sane) or the raw `@secret` email (leaky). Same
dependencies, same file names, same module graph. Full outputs are in
[`results/leaky-vs-sane/`](results/leaky-vs-sane/); rebuild with
`./leaky_vs_sane.sh <path-to-capa_dataguard>`.

| tool | sane | leaky | told them apart? |
|------|------|-------|------------------|
| syft | 6 components | 6 components | **no** - identical inventory |
| cdxgen | 0 components | 0 components | **no** - identical inventory |
| capa (default tier) | ok, 0 warnings | ok, **3 warnings** naming the flow | **yes** - the artifact differs |
| capa (strict tier) | compiles | **refuses to compile** | **yes** - a hard gate |

A package-inventory scanner reads the dependency manifest, not the code, so it
emits the identical SBOM whether or not the release exfiltrates a secret. Capa
reads the flow. Under the strict enforcement tier the leaky release is rejected:

```
dataguard.capa:67:42: error: information-flow: a @secret value reaches Fs.write
(argument 2), a public sink that sends data out of the program. Route it through
declassify(value, reason: "...") if this disclosure is intended.
```

## Analyzer coverage and precision

Does the analyzer accept the programs meant to be valid and reject the
intended violations, and with what false-positive / false-negative profile?
Run `capa --check` over the whole corpus and every deliberate negative.
Regenerate with [`./rq3_eval.sh`](rq3_eval.sh) and
[`./rq3_diagnostics.sh`](rq3_diagnostics.sh); full output in
[`results/rq3/`](results/rq3/).

**Coverage.**

| Program set | Programs | Accepted | Rejected | Expected |
|-------------|---------:|---------:|---------:|----------|
| Valid corpus | 198 | **198** | 0 | all accepted |
| Deliberate negatives | 4 | 0 | **4** | verified rejected |
| claimdesk negatives | 7 | 0 | **7** | verified rejected |
| leaky_* variants (5 projects) | 5 | 0 | **5** | verified rejected |

**Precision, by discipline.**

| Discipline | Negatives | Rejected | FN | Representative diagnostic |
|------------|----------:|---------:|---:|---------------------------|
| Capability (undeclared authority) | 2 | 2 | 0 | `undefined name 'fs'` / `no method 'write'` |
| Linearity (consume / alias) | 4 | 4 | 0 | `capability was consumed earlier` |
| Typestate | 2 | 2 | 0 | `expects Claim[UnderReview], got Claim[Draft]` |
| Information flow (`@secret`) | 7 | 7 | **1** | `@secret value reaches public sink` |

**Diagnostic categories** (each negative triggers the specific, correct
diagnostic, not an accidental rejection):

| Diagnostic category | Negatives | FP | FN |
|---------------------|----------:|---:|---:|
| capability in a data position | 1 | 0 | 0 |
| attenuated capability lacks method | 1 | 0 | 0 |
| capability aliased within one call | 1 | 0 | 0 |
| linear value consumed twice | 3 | 0 | 0 |
| linear value dropped | 1 | 0 | 0 |
| illegal typestate transition | 1 | 0 | 0 |
| secret reaches public sink | 6 | 0 | 1 |
| secret in control flow | 1 | 0 | 0 |
| type mismatch | 1 | 0 | 0 |

**False positives: 0** (all 198 valid programs accepted).
**False negatives: 1** — the closure-by-name shape, kept as a deliberate
residual because closing it would introduce false positives. It is not just
cited but reproduced: [`results/rq3/fn_closure_by_name.capa`](results/rq3/fn_closure_by_name.capa)
is accepted by `--check` yet leaks a `@secret` to stdout at runtime.
(`errors.capa` is a base type-checking negative, rejected, outside the four
security disciplines.)

## Decision fidelity: capability gate vs inventory gate

Can a CI gate consume the artifacts to distinguish a sane build from a
compromised one? For five sane/leaky pairs, does each approach pass the sane
build and reject the leaky one? Regenerate with
[`./rq4_fidelity.sh`](rq4_fidelity.sh); output in [`results/rq4/`](results/rq4/).

| pair | capa sane | capa leaky | inv sane | inv leaky | capa discriminates | inv discriminates |
|------|-----------|------------|---------:|----------:|--------------------|-------------------|
| paymentguard | PASS | FAIL | 6 | 6 | **yes** | no |
| dataguard | PASS | FAIL | 6 | 6 | **yes** | no |
| supplygate | PASS | FAIL | 3 | 3 | **yes** | no |
| configbroker | PASS | FAIL | 3 | 3 | **yes** | no |
| licenseaudit | PASS | FAIL | 3 | 3 | **yes** | no |
| **Fidelity** | | | | | **5/5** | **0/5** |

The capability approach certifies the sane pipeline and the analyzer rejects
the leaky module on every pair; syft emits an identical inventory for both
members of each pair, so an inventory gate gives the same decision for both.

## Side by side

| dimension | syft | cdxgen | capa |
|-----------|------|--------|------|
| Package inventory, mainstream ecosystems | strong | strong | none (Capa source only) |
| Sees a Capa project's real dependencies | no (CI Actions only) | no | yes (from `capa.lock`) |
| Dependency provenance | version + purl | version + purl | git + tag + commit + signing key |
| Capability / authority surface | — | — | declared, reachable, excluded |
| Proves an authority is *unreachable* | no | no | yes (Net, Proc, Env, … excluded) |
| How the answer is obtained | scan & infer | scan & infer | proof from the type system |
| Output formats | CycloneDX, SPDX, … | CycloneDX | CycloneDX, SPDX, VEX, SLSA |

They are not rivals. A complete supply-chain record wants **both** layers:
a scanner's inventory of *what ships*, and a capability SBOM's proof of
*what it can touch*.

## Reproduce it

Requirements on `PATH`: [`syft`](https://github.com/anchore/syft),
`npx` (for [`@cyclonedx/cdxgen`](https://github.com/CycloneDX/cdxgen)),
and `capa` (or `python -m capa` from a Capa checkout).

```sh
./compare.sh <capa-project-dir> <entrypoint.capa> <python-project-dir>

# the exact invocation used for the committed results:
./compare.sh ../capa_paymentguard ../capa_paymentguard/main.capa ../Capa_language
```

The harness writes every tool's output to `results/`, extracts the
capability surface with [`extract_capabilities.py`](extract_capabilities.py),
and rolls a table into [`results/SUMMARY.md`](results/SUMMARY.md) via
[`summarize.py`](summarize.py). Missing tools are reported and skipped,
not fatal.

## Measured with

| tool | version |
|------|---------|
| capa | 1.15.1 |
| syft | 1.46.0 |
| cdxgen | latest (via `npx`) |

Measured 2026-07-04. The syft scan of the Python project is summarized
rather than committed in full (it is large and noisy, dominated by OS /
runtime binaries in the working tree); regenerate it with `compare.sh`.

A visual version of this comparison is published as an artifact:
<https://claude.ai/code/artifact/dffa1fc2-c5a5-40e5-9321-9e1988121449>
