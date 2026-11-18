#!/usr/bin/env bash
# Build the spike test images in dependency order and tag them spike/<name>:1.
# Safe to re-run: docker reuses its build cache, so unchanged images are a no-op.
# This only BUILDS images. It never runs one.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGES_DIR="${ROOT}/testdata/images"

# Order matters: base-secret is built FROM spike/secret-base:1.
IMAGES=(trap secret-base base-secret clean vuln)

for name in "${IMAGES[@]}"; do
  dir="${IMAGES_DIR}/${name}"
  if [[ ! -f "${dir}/Dockerfile" ]]; then
    echo "error: missing ${dir}/Dockerfile" >&2
    exit 1
  fi
  echo "==> building spike/${name}:1"
  docker build --tag "spike/${name}:1" "${dir}"
done

echo "built: ${IMAGES[*]}"
