#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

KERNEL_VERSION="${SPOREVM_KERNEL_VERSION:-6.1.155}"
KERNEL_ARCH="${SPOREVM_KERNEL_ARCH:-arm64}"

OUTPUT_PATH="${1:-${REPO_ROOT}/dist/sporevm-${KERNEL_ARCH}-linux-${KERNEL_VERSION}-Image}"

SPOREVM_KERNEL_PROFILE=sporevm-run \
SPOREVM_KERNEL_ENABLE_DEVMEM=0 \
  "${SCRIPT_DIR}/build-kernel.sh" "${OUTPUT_PATH}"
