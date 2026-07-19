#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APPROVED_DIR="${REPO_ROOT}/approved/x86_64/6.1.155"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sporevm-approved-x86-test.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

"${SCRIPT_DIR}/verify-approved-x86-kernel-assets.sh" "${APPROVED_DIR}"

for asset_name in \
  sporevm-x86_64-linux-6.1.155-bzImage \
  sporevm-x86_64-linux-6.1.155-bzImage.config \
  sporevm-x86_64-linux-6.1.155-bzImage.sha256 \
  sporevm-x86_64-linux-6.1.155.manifest.json; do
  case_dir="${TMP_DIR}/${asset_name}"
  mkdir -p "${case_dir}"
  cp "${APPROVED_DIR}/"* "${case_dir}/"
  printf 'tampered' >> "${case_dir}/${asset_name}"
  if "${SCRIPT_DIR}/verify-approved-x86-kernel-assets.sh" "${case_dir}" >/dev/null 2>&1; then
    printf '[test-approved-x86-kernel-assets] tampered asset was accepted: %s\n' "${asset_name}" >&2
    exit 1
  fi
done

printf '[test-approved-x86-kernel-assets] ok\n'
