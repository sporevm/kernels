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
KERNEL_ARCH="${SPOREVM_KERNEL_ARCH:-arm64}"
APPROVED_X86_64_DIR="${REPO_ROOT}/approved/x86_64/6.1.155"

case "${KERNEL_ARCH}" in
  arm64)
    DEFAULT_BUILD_DIR="${REPO_ROOT}/.kernel-cache/sporevm"
    ;;
  x86_64)
    ;;
  *)
    die "unsupported SPOREVM_KERNEL_ARCH: ${KERNEL_ARCH}"
    ;;
esac

require_command python3

cd "${REPO_ROOT}"
rm -rf "${KERNEL_RELEASE_DIR}"
mkdir -p "${KERNEL_RELEASE_DIR}"

if [[ "${KERNEL_ARCH}" == "x86_64" ]]; then
  echo "--- :package: Stage approved SporeVM x86_64 kernel release assets"
  cp \
    "${APPROVED_X86_64_DIR}/sporevm-x86_64-linux-6.1.155-bzImage" \
    "${APPROVED_X86_64_DIR}/sporevm-x86_64-linux-6.1.155-bzImage.config" \
    "${APPROVED_X86_64_DIR}/sporevm-x86_64-linux-6.1.155-bzImage.sha256" \
    "${APPROVED_X86_64_DIR}/sporevm-x86_64-linux-6.1.155.manifest.json" \
    "${KERNEL_RELEASE_DIR}/"
  "${SCRIPT_DIR}/verify-approved-x86-kernel-assets.sh" "${KERNEL_RELEASE_DIR}"
  exit 0
fi

require_command docker
require_command git

export SPOREVM_KERNEL_BUILD_DIR="${SPOREVM_KERNEL_BUILD_DIR:-${DEFAULT_BUILD_DIR}}"

echo "--- :penguin: Build SporeVM ${KERNEL_ARCH} kernel release assets"
"${SCRIPT_DIR}/build-release-asset.sh" "${KERNEL_RELEASE_DIR}"
