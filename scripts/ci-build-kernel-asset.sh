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
KERNEL_RELEASE_DIR="${REPO_ROOT}/dist/kernels"

require_command docker
require_command git
require_command python3

cd "${REPO_ROOT}"
rm -rf "${KERNEL_RELEASE_DIR}"
mkdir -p "${KERNEL_RELEASE_DIR}"

export SPOREVM_KERNEL_BUILD_DIR="${SPOREVM_KERNEL_BUILD_DIR:-${REPO_ROOT}/.kernel-cache/sporevm}"

echo "--- :penguin: Build SporeVM kernel release assets"
"${SCRIPT_DIR}/build-release-asset.sh" "${KERNEL_RELEASE_DIR}"
