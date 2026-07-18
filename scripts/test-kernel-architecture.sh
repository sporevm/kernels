#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/kernel-architecture.sh
source "${SCRIPT_DIR}/kernel-architecture.sh"

assert_equal() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [[ "${actual}" != "${expected}" ]]; then
    printf '[test-kernel-architecture] %s: expected %q, got %q\n' \
      "${label}" "${expected}" "${actual}" >&2
    exit 1
  fi
}

resolve_kernel_architecture arm64 linux/amd64
assert_equal arm64 "${KERNEL_MAKE_ARCH}" "arm64 make arch"
assert_equal Image "${KERNEL_BUILD_TARGET}" "arm64 build target"
assert_equal arch/arm64/boot/Image "${KERNEL_BOOT_PATH}" "arm64 boot path"
assert_equal Image "${KERNEL_IMAGE_SUFFIX}" "arm64 asset suffix"
assert_equal aarch64-linux-gnu- "${KERNEL_DEFAULT_CROSS_COMPILE}" "arm64 cross compiler"
assert_equal gcc-aarch64-linux-gnu "${KERNEL_CROSS_PACKAGE}" "arm64 cross package"

resolve_kernel_architecture arm64 linux/arm64
assert_equal "" "${KERNEL_DEFAULT_CROSS_COMPILE}" "native arm64 compiler"
assert_equal "" "${KERNEL_CROSS_PACKAGE}" "native arm64 cross package"

resolve_kernel_architecture arm64 linux/amd64
resolve_kernel_cross_package arm64 ""
assert_equal "" "${KERNEL_CROSS_PACKAGE}" "empty arm64 cross-compiler override"

resolve_kernel_architecture x86_64 linux/amd64
assert_equal x86_64 "${KERNEL_MAKE_ARCH}" "x86_64 make arch"
assert_equal bzImage "${KERNEL_BUILD_TARGET}" "x86_64 build target"
assert_equal arch/x86/boot/bzImage "${KERNEL_BOOT_PATH}" "x86_64 boot path"
assert_equal bzImage "${KERNEL_IMAGE_SUFFIX}" "x86_64 asset suffix"
assert_equal "" "${KERNEL_DEFAULT_CROSS_COMPILE}" "x86_64 compiler"
assert_equal "" "${KERNEL_CROSS_PACKAGE}" "x86_64 cross package"

if resolve_kernel_cross_package x86_64 x86_64-linux-gnu- >/dev/null 2>&1; then
  printf '[test-kernel-architecture] x86_64 cross compiler was accepted\n' >&2
  exit 1
fi

if resolve_kernel_architecture riscv64 linux/amd64 >/dev/null 2>&1; then
  printf '[test-kernel-architecture] unsupported architecture was accepted\n' >&2
  exit 1
fi

printf '[test-kernel-architecture] ok\n'
