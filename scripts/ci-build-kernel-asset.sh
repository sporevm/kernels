#!/usr/bin/env bash
set -euo pipefail

die() {
  printf '[ci-build-kernel-asset] error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || die "missing required command: ${name}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
KERNEL_ARCH="${SPOREVM_KERNEL_ARCH:-arm64}"
OUTPUT_DIR="${1:-${REPO_ROOT}/dist/kernels}"

require_command docker
require_command git
require_command python3

cd "${REPO_ROOT}"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

export SPOREVM_KERNEL_BUILD_DIR="${SPOREVM_KERNEL_BUILD_DIR:-${REPO_ROOT}/.kernel-cache/${KERNEL_ARCH}}"

echo "--- :penguin: Build SporeVM ${KERNEL_ARCH} kernel"
"${SCRIPT_DIR}/build-release-asset.sh" "${OUTPUT_DIR}"
