#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/kernel-architecture.sh
source "${SCRIPT_DIR}/kernel-architecture.sh"

KERNEL_VERSION="${SPOREVM_KERNEL_VERSION:-6.1.155}"
KERNEL_ARCH="${SPOREVM_KERNEL_ARCH:-arm64}"
DOCKER_PLATFORM="${SPOREVM_KERNEL_DOCKER_PLATFORM:-linux/amd64}"
resolve_kernel_architecture "${KERNEL_ARCH}" "${DOCKER_PLATFORM}"

OUTPUT_PATH="${1:-${REPO_ROOT}/dist/sporevm-${KERNEL_ARCH}-linux-${KERNEL_VERSION}-${KERNEL_IMAGE_SUFFIX}}"

ENABLE_DEVMEM=0
if [[ "${KERNEL_ARCH}" == "x86_64" ]]; then
  ENABLE_DEVMEM=1
fi

SPOREVM_KERNEL_PROFILE=sporevm-run \
SPOREVM_KERNEL_ENABLE_DEVMEM="${ENABLE_DEVMEM}" \
  "${SCRIPT_DIR}/build-kernel.sh" "${OUTPUT_PATH}"
