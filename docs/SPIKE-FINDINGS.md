# Spike findings

Questions Q1 to Q12 (task C1) are not answered here yet. This file currently records
only contradictions and deviations found while building the test images (tasks A1/A2),
as required by `.github/copilot-instructions.md`.

## Pre-spike observations

### O1. `docker save` produces a hybrid archive, not a plain docker-archive

- **Contradicts:** `docs/SPIKE.md` assumes `docker save` yields a docker-archive that
  is distinct from an OCI layout (Starting-point commands; Q10; Q7 "docker-archive and
  OCI archive inputs").
- **Evidence:** Docker Desktop 29.5.3 with the containerd image store
  (`docker info` reports driver-type `io.containerd.snapshotter.v1`). The listing of
  `testdata/archives/trap.tar` contains `manifest.json`, `index.json`, `oci-layout`,
  and `blobs/sha256/*`. The `index.json` entry carries the annotations
  `io.containerd.image.name` and `org.opencontainers.image.ref.name`. Layer blobs are
  gzip-compressed, and `manifest.json` lists them base-first.
- **Consequences:**
  - A tool given `docker-archive:` reads `manifest.json`; a tool that sniffs the format
    may take the OCI path instead. They may therefore report different layer
    identifiers or metadata for the same file. This must be tested in Q10.
  - A hybrid archive does not exercise a pure OCI input. For that,
    `scripts/export-archives.sh` derives `trap-oci.tar` by deleting `manifest.json`
    from the same save. It is derived, not independently produced, so differences from
    a registry-pulled layout (for example a `go-containerregistry` pull) are not ruled out.
  - Results likely depend on the Docker image store. With the classic graph driver,
    `docker save` is expected to produce the older docker-archive layout (not tested
    here). Record the store setting in `testdata/raw/MANIFEST.md`.
- **Schema impact (proposed):** none yet. `image.layers[].digest` (compressed) and
  `diff_id` (uncompressed) both exist in this archive, so both can be populated.
  Revisit after Q8 and Q10.

### O2. `trap` base is pinned by digest (deviation from SPIKE.md)

- **Deviates from:** `docs/SPIKE.md` says the `trap` Dockerfile is "exactly as given",
  with `FROM alpine:3.20`.
- **Change:** `trap` and `secret-base` use `FROM alpine:3.20@sha256:d9e853e8…b6bc`
  (approved by the maintainer) so rebuilds are reproducible. The two `RUN` steps are
  unchanged and separate, and a `LABEL` was added as SPIKE.md requires for every image.
- **Evidence:** the pinned rebuild gives the same image ID
  (`sha256:2ae259b6…940c`) and the same layer 0 DiffID (`sha256:08bc4e53…2aa4`) as the
  earlier unpinned build.
- **Schema impact:** none.

### O3. `clean` is not a one-layer image

`gcr.io/distroless/static-debian12:nonroot` has 12 layers of its own, so `spike/clean:1`
has 13 with the trivial `COPY`. Do not assume "minimal" means few layers when comparing
layer-count or cost results.

### O4. Layer and history alignment in `trap` (input for Q9, not an answer)

`trap` has 5 history entries but 3 layers. The inherited `CMD ["/bin/sh"]` and our
`LABEL` are `empty_layer: true` and create no layer. Dropping those entries aligned the
rest one-to-one, in order, with `manifest.json` `Layers` (verified on `trap` and
`base-secret` by `scripts/verify-trap-layers.sh`). Q9 still needs the other tools'
behaviour.
