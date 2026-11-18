# Tool-output spike (working name: LayerScan)

**Status:** draft plan. **Purpose:** find out exactly what Trivy, Syft, Grype, and Dive emit for layer-level data before freezing the normalized schema or writing production code.

The design in `schema/scan-result.v1.schema.json` is built from documentation and older source code. Every claim below marked *provisional* must be confirmed against real output from the pinned tool versions.

## Goal and non-goals

**Goal:** answer the open questions below with evidence (captured JSON), then revise the schema and record the decisions as ADRs.

**Non-goals:** no production parser, runner, API, or Action during the spike. Throwaway scripts are fine. Stop at the exit criteria.

## Ground rules

- Never run (`docker run`) any test image. The spike only builds, saves, and reads images.
- Local Docker is fine for building test images. The eventual service stays daemonless.
- Use only documented fake credentials (the AWS example keys). Create secrets inside `RUN` steps rather than committing files that contain them, so push protection and secret scanning on the repo stay quiet.
- Pin and record every tool version and vulnerability database version in `testdata/raw/MANIFEST.md`.
- Never commit built image archives (`testdata/archives/` is gitignored). Commit only the Dockerfiles and the captured JSON.
- Treat everything as measured, not assumed. If a tool's output contradicts this document, the output wins.

## Test images

| Image | Purpose | How |
|---|---|---|
| `trap` | Secret added in one layer, deleted in the next. The headline demo. | See below. |
| `shadowed-package` | A package with known findings installed in one layer and removed in the next. Compares all-layers vs squashed scope. | Pick a package after scanning the base; record the choice. |
| `base-secret` | Secret lives in an inherited (base) layer. Tests whether it is scanned or skipped. | Build `spike/secret-base`, then `FROM` it. |
| `vuln` | Stable, known vulnerabilities. | Pin an intentionally old base image by digest and record the digest. |
| `clean` | Minimal image that should pass. | A minimal image such as distroless static. |
| `large` | Cost measurement only. | Any large public image, pinned by digest. |

`trap` Dockerfile (the two `RUN` steps must stay separate, or the secret never lands in a layer by itself):

```dockerfile
FROM alpine:3.20
RUN mkdir /app && echo "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE" > /app/.env \
 && echo "AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" >> /app/.env
RUN rm /app/.env
```

Label every test image as intentionally vulnerable and never meant to be run.

## Open questions

### Trivy
- **Q1.** Does every vulnerability, secret, and misconfiguration finding carry layer data (`DiffID`, digest)? Is the Dockerfile command (`CreatedBy`) present in the JSON?
- **Q2.** For `trap`: is the removed secret reported? Is it flagged as deleted? Does Trivy say which layer removed it?
- **Q3.** For `base-secret`: is the inherited-layer secret reported or skipped? (Older source suggests base layers are skipped for secrets; confirm.)

### Syft and Grype
- **Q4.** Does `--scope all-layers` include the removed package in `shadowed-package`? How does it differ from the default squashed output? Do package locations record a layer identifier, and is it a DiffID or a compressed digest?
- **Q5.** Can Grype scan the Syft SBOM, and does it scan the archive directly? Do matches keep layer info in each mode? Are the results identical?

### Dive
- **Q6.** What does the JSON contain? Layer list (index, id, size, command)? Any per-file removed/modified detail, or only aggregate efficiency numbers?
- **Q7.** Does Dive read `docker-archive` and OCI archive inputs without a daemon? How does CI mode behave (exit codes, thresholds)?
- **Fallback:** if Dive's JSON lacks per-file detail, evaluate `anchore/stereoscope` (squashed file tree per layer) for removed-file detection.

### Cross-cutting
- **Q8.** Which identifier do all tools share for a layer (DiffID, digest, index)? Produce a mapping table for `trap`.
- **Q9.** How do history entries that create no layer (`ENV`, `CMD`, ...) show up in each tool? How should `created_by` map to layers?
- **Q10.** Does one archive (from `docker save` and from `go-containerregistry`) work for all tools? Any differences versus an OCI layout?
- **Q11.** What uniquely identifies "the same finding" across Trivy and Grype (vuln id, package name, version, ecosystem, path)? Note naming and version-format differences.
- **Q12.** Cost: wall time, peak memory, and database size per tool on `clean` and `large`.

## Tasks

- [ ] **A1.** Create `testdata/images/<name>/Dockerfile` for each image above.
- [ ] **A2.** Script: build each image and export `testdata/archives/<name>.tar` (gitignored). Also export an OCI layout version for `trap`.
- [ ] **B1.** Install pinned versions of Trivy, Syft, Grype, Dive. Record versions and DB versions.
- [ ] **B2.** Run every tool on every image (commands below). Save raw output to `testdata/raw/<image>/<tool>.json`.
- [ ] **B3.** Record each exact command line and exit code in `testdata/raw/MANIFEST.md`.
- [ ] **C1.** Answer Q1 to Q12 in `docs/SPIKE-FINDINGS.md`: question, answer, evidence (file and JSON path), schema impact.
- [ ] **C2.** Build the layer mapping table for `trap` (Q8).
- [ ] **D1.** Revise `schema/scan-result.v1.schema.json` from the findings.
- [ ] **D2.** Hand-build (or script) a normalized result for `trap` that validates against the schema and shows the shadowed secret and a failing verdict.
- [ ] **E1.** Write the ADRs listed below.

## Starting-point commands

Confirm every flag with `--help` for the pinned versions.

```bash
docker build -t spike/trap:1 testdata/images/trap
docker save spike/trap:1 -o testdata/archives/trap.tar

trivy image --input testdata/archives/trap.tar --format json \
  --scanners vuln,secret,misconfig -o testdata/raw/trap/trivy.json

syft docker-archive:testdata/archives/trap.tar --scope all-layers \
  -o syft-json=testdata/raw/trap/syft-all-layers.json
syft docker-archive:testdata/archives/trap.tar \
  -o syft-json=testdata/raw/trap/syft-squashed.json

grype sbom:testdata/raw/trap/syft-all-layers.json -o json > testdata/raw/trap/grype-from-sbom.json
grype docker-archive:testdata/archives/trap.tar -o json > testdata/raw/trap/grype-direct.json

dive docker-archive://testdata/archives/trap.tar --json testdata/raw/trap/dive.json
# if the interactive UI starts, add --ci; record the exit code either way
```

## Deliverables

- `testdata/images/*/Dockerfile`
- `testdata/raw/<image>/<tool>.json` and `testdata/raw/MANIFEST.md`
- `docs/SPIKE-FINDINGS.md`
- Revised `schema/scan-result.v1.schema.json`
- A validating normalized example for `trap`

## Exit criteria

1. Every question has an answer with evidence, or is marked unresolved with a reason.
2. Decisions recorded for: layer join key, Grype input mode (image vs Syft SBOM), Dive adapter vs stereoscope, and handling of base-layer secrets.
3. The `trap` example validates against the schema and demonstrates a shadowed secret with a failing verdict.

## ADRs to write afterward

- **ADR-001:** Pull once to a local archive; all tools read the same archive; the image is never run.
- **ADR-002:** Layer join key across tools.
- **ADR-003:** Dive as an adapter, with stereoscope as the fallback.
- **ADR-004:** Layer attribution (first appearance) instead of scanning isolated layer diffs.
- **ADR-005:** Tool-failure policy: when one scanner fails, is the verdict `error` or a partial result?
