# Test images

Fixtures for the tool-output spike (see [docs/SPIKE.md](../../docs/SPIKE.md)). Each directory holds a `Dockerfile`.

> **Every image here is an intentionally insecure scanner fixture. Never run one** (`docker run`, `compose up`, etc.).
> Each carries the labels `spike.intentionally-vulnerable=true` and `spike.do-not-run=...`.
> Images are only built, saved to a tar archive, and read. Secrets are the documented AWS example keys, created inside `RUN` steps.

| Image | Purpose | Layers (on this build) |
|---|---|---|
| `trap` | Secret written in one layer (`/app/.env`), deleted in the next. Expect `app/.env` in layer 1 and the whiteout `app/.wh..env` in layer 2. Headline demo. | 3 |
| `secret-base` | Base image holding the fake secret (`/base/.env`) in its own layer. Only exists to be inherited by `base-secret`. | 2 |
| `base-secret` | `FROM spike/secret-base:1` plus one trivial layer. Tests whether a secret in an inherited layer is scanned or skipped. | 3 |
| `clean` | Minimal image expected to pass: distroless `static-debian12:nonroot` (pinned by digest) plus one trivial `COPY`. Distroless `static` already has 12 layers of its own, so the image has 13. | 13 |
| `vuln` | Stable known vulnerabilities: EOL `alpine:3.12` pinned by digest. No extra layers. | 1 |

Not created yet: `shadowed-package` and `large` (they depend on scan results from tasks B/C).

## Build order

`scripts/build-test-images.sh` builds in this order and tags each `spike/<name>:1`:

1. `trap`
2. `secret-base` (must precede `base-secret`)
3. `base-secret`
4. `clean`
5. `vuln`

Then `scripts/export-archives.sh` writes `testdata/archives/<name>.tar` for each image plus `trap-oci.tar` (gitignored; never commit archives), and `scripts/verify-trap-layers.sh` checks the `trap` layers.

## Pinned digests

| Image | Base | Digest (multi-arch index) |
|---|---|---|
| `vuln` | `alpine:3.12` | `sha256:c75ac27b49326926b803b9ed43bf088bc220d22556de1bc5f72d742c91398f69` |
| `clean` | `gcr.io/distroless/static-debian12:nonroot` | `sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab` |
| `trap`, `secret-base` | `alpine:3.20` (resolved to 3.20.10) | `sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc` |

All were looked up from the registry on 2026-11-18. Each is the index (manifest list) digest, so the Dockerfile resolves on any platform; the `vuln` base's `linux/amd64` manifest is `sha256:cb64bbe7fa613666c234e1090e91427314ee18ec6420e9426cf4e7f314056813`. `base-secret` inherits its alpine layer through `secret-base`.

Pinning `trap` to a digest deviates from the "exactly as given" Dockerfile in SPIKE.md (the two `RUN` steps are unchanged). It was approved so rebuilds stay reproducible; see `docs/SPIKE-FINDINGS.md`.

## Environment used

- Docker Desktop on Windows 11: client and server **29.5.3** (API 1.54), `linux/amd64`.
- Image store: **containerd snapshotter** (`io.containerd.snapshotter.v1`). This matters: `docker save` writes a hybrid archive containing both `manifest.json` (docker-archive) and an OCI layout (`index.json`, `oci-layout`, `blobs/`). `trap-oci.tar` is that same content with `manifest.json` removed, so it is a pure OCI layout.
- Builder: the legacy builder (the buildx plugin is not installed), so builds print a deprecation notice.
- shellcheck 0.11.0.
