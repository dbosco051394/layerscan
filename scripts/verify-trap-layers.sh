#!/usr/bin/env bash
# Verify the "trap" image without running it: read the saved archive with tar and show
#   1. app/.env exists in exactly one layer,
#   2. a LATER layer holds its whiteout marker app/.wh..env,
#   3. the layer index of each (0 = base-most layer).
#
# Usage: scripts/verify-trap-layers.sh [archive.tar]   (default: testdata/archives/trap.tar)
#
# Safety: layers are only LISTED (tar -t). Nothing from the image is extracted into
# the filesystem layout or executed, and file contents are never printed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="${1:-${ROOT}/testdata/archives/trap.tar}"
SECRET_PATH="app/.env"
WHITEOUT_PATH="app/.wh..env"

if [[ ! -f "${ARCHIVE}" ]]; then
  echo "error: ${ARCHIVE} not found; run scripts/build-test-images.sh and scripts/export-archives.sh" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Parse manifest.json + image config into TSV: index, blob path, diff_id, created_by.
# Image history lists every Dockerfile step; only entries without empty_layer=true
# create a layer, so they line up one-to-one with manifest "Layers".
# The created_by text can contain the (fake) key values, so redact before printing.
# python -I = isolated mode: ignores PYTHON* env vars and the current directory.
PARSE_PY='
import json, re, subprocess, sys
archive = sys.argv[1]
def member(name):
    return subprocess.run(["tar", "-xOf", archive, name], check=True, capture_output=True).stdout
manifest = json.loads(member("manifest.json"))[0]
config = json.loads(member(manifest["Config"]))
diff_ids = config["rootfs"]["diff_ids"]
history = [h for h in config.get("history", []) if not h.get("empty_layer")]
for i, blob in enumerate(manifest["Layers"]):
    cmd = history[i]["created_by"] if i < len(history) else ""
    cmd = re.sub(r"(AWS_[A-Z_]+=)[^\"\s]+", r"\1<redacted>", cmd)
    cmd = re.sub(r"\s+", " ", cmd)[:90]
    print("\t".join([str(i), blob, diff_ids[i], cmd]))
'
LAYERS="$(python -I -c "${PARSE_PY}" "${ARCHIVE}")"

echo "archive: ${ARCHIVE}"
echo
printf '%-5s %-14s %-9s %-14s %s\n' INDEX BLOB_DIGEST SIZE DIFF_ID CREATED_BY

secret_layers=()
whiteout_layers=()
while IFS=$'\t' read -r index blob diff_id created_by; do
  tar -xOf "${ARCHIVE}" "${blob}" > "${WORK}/layer"
  size="$(stat -c %s "${WORK}/layer")"
  # GNU tar auto-detects gzip on regular files. Strip any leading ./ from names.
  listing="$(tar -tf "${WORK}/layer" | sed 's|^\./||')"
  marks=""
  if grep -Fxq "${SECRET_PATH}" <<<"${listing}"; then
    secret_layers+=("${index}")
    marks+=" [has ${SECRET_PATH}]"
  fi
  if grep -Fxq "${WHITEOUT_PATH}" <<<"${listing}"; then
    whiteout_layers+=("${index}")
    marks+=" [has ${WHITEOUT_PATH}]"
  fi
  # Show the first 12 hex chars of each digest to keep the table readable.
  blob_hex="${blob##*/}"
  printf '%-5s %-14s %-9s %-14s %s%s\n' "${index}" "${blob_hex:0:12}" "${size}" "${diff_id:7:12}" "${created_by}" "${marks}"
done <<<"${LAYERS}"

echo
status=0

if [[ "${#secret_layers[@]}" -eq 1 ]]; then
  echo "PASS: ${SECRET_PATH} exists in exactly one layer: index ${secret_layers[0]}"
else
  echo "FAIL: ${SECRET_PATH} found in ${#secret_layers[@]} layers (expected 1): ${secret_layers[*]:-none}"
  status=1
fi

if [[ "${#whiteout_layers[@]}" -ge 1 ]]; then
  echo "PASS: whiteout ${WHITEOUT_PATH} found in layer index: ${whiteout_layers[*]}"
else
  echo "FAIL: no layer contains ${WHITEOUT_PATH}"
  status=1
fi

if [[ "${#secret_layers[@]}" -eq 1 && "${#whiteout_layers[@]}" -ge 1 ]]; then
  if [[ "${whiteout_layers[0]}" -gt "${secret_layers[0]}" ]]; then
    echo "PASS: whiteout (layer ${whiteout_layers[0]}) comes after the secret (layer ${secret_layers[0]}); the secret is shadowed but still shipped"
  else
    echo "FAIL: whiteout (layer ${whiteout_layers[0]}) is not after the secret (layer ${secret_layers[0]})"
    status=1
  fi
fi

exit "${status}"
