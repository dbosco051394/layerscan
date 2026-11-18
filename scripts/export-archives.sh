#!/usr/bin/env bash
# Export the spike test images to testdata/archives/ (gitignored; never commit these).
#   <name>.tar     docker save output, for every image
#   trap-oci.tar   a pure OCI image-layout archive of trap
# Safe to re-run: each file is written to a temp name and then moved into place.
# This only READS images from the local store. It never runs one.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT}/testdata/archives"
IMAGES=(trap secret-base base-secret clean vuln)

mkdir -p "${OUT_DIR}"
WORK="$(mktemp -d)"
# Always clean up temp files, even if a command below fails.
trap 'rm -rf "${WORK}"' EXIT

for name in "${IMAGES[@]}"; do
  if ! docker image inspect "spike/${name}:1" >/dev/null 2>&1; then
    echo "error: spike/${name}:1 not found; run scripts/build-test-images.sh first" >&2
    exit 1
  fi
  echo "==> saving spike/${name}:1 -> testdata/archives/${name}.tar"
  docker save "spike/${name}:1" -o "${WORK}/${name}.tar"
  mv -f "${WORK}/${name}.tar" "${OUT_DIR}/${name}.tar"
done

# With Docker's containerd image store, `docker save` writes a hybrid archive:
# the classic docker-archive files (manifest.json) AND an OCI layout (index.json,
# oci-layout, blobs/). Removing manifest.json leaves a pure OCI layout, so tools
# must read it via the OCI path rather than the docker-archive path.
echo "==> deriving OCI layout testdata/archives/trap-oci.tar"
mkdir "${WORK}/oci"
tar -xf "${OUT_DIR}/trap.tar" -C "${WORK}/oci"
for required in oci-layout index.json blobs; do
  if [[ ! -e "${WORK}/oci/${required}" ]]; then
    echo "error: trap.tar has no ${required}; is the containerd image store enabled?" >&2
    exit 1
  fi
done
rm -f "${WORK}/oci/manifest.json" "${WORK}/oci/repositories"
tar -cf "${WORK}/trap-oci.tar" -C "${WORK}/oci" .
mv -f "${WORK}/trap-oci.tar" "${OUT_DIR}/trap-oci.tar"

echo "exported to ${OUT_DIR}"
