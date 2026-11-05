#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
KERNEL_RELEASE_DIR="${REPO_ROOT}/dist/kernels"
APPROVED_X86_64_DIR="${REPO_ROOT}/approved/x86_64/6.1.191"

echo "--- :package: Stage approved SporeVM x86_64 kernel release assets"
rm -rf "${KERNEL_RELEASE_DIR}"
mkdir -p "${KERNEL_RELEASE_DIR}"
cp \
  "${APPROVED_X86_64_DIR}/sporevm-x86_64-linux-6.1.191-bzImage" \
  "${APPROVED_X86_64_DIR}/sporevm-x86_64-linux-6.1.191-bzImage.config" \
  "${APPROVED_X86_64_DIR}/sporevm-x86_64-linux-6.1.191-bzImage.sha256" \
  "${APPROVED_X86_64_DIR}/sporevm-x86_64-linux-6.1.191.manifest.json" \
  "${KERNEL_RELEASE_DIR}/"
"${SCRIPT_DIR}/verify-approved-x86-kernel-assets.sh" "${KERNEL_RELEASE_DIR}"
