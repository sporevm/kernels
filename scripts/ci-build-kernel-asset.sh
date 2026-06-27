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
TARGET="${1:-}"
KERNEL_RELEASE_DIR="${REPO_ROOT}/dist/kernels"

case "${TARGET}" in
  sporevm|sporevm-run) ;;
  *) die "usage: $0 sporevm|sporevm-run" ;;
esac

require_command docker
require_command git
require_command python3

cd "${REPO_ROOT}"
rm -rf "${KERNEL_RELEASE_DIR}"
mkdir -p "${KERNEL_RELEASE_DIR}"

export SPOREVM_KERNEL_BUILD_DIR="${SPOREVM_KERNEL_BUILD_DIR:-${REPO_ROOT}/.kernel-cache/${TARGET}}"

echo "--- :penguin: Build ${TARGET} kernel release assets"
"${SCRIPT_DIR}/build-release-asset.sh" "${TARGET}" "${KERNEL_RELEASE_DIR}"
