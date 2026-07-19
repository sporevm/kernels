#!/usr/bin/env bash

# Resolve the Linux Kbuild and release-asset names for one guest architecture.
# Callers set their own defaults before invoking this function.
validate_kernel_cross_compile() {
  local kernel_arch="$1"
  local cross_compile="$2"

  if [[ "${kernel_arch}" == "x86_64" && -n "${cross_compile}" ]]; then
    printf 'SPOREVM_KERNEL_CROSS_COMPILE is not supported for x86_64 builds\n' >&2
    return 1
  fi
}

# shellcheck disable=SC2034 # Assignments are the sourced helper's interface.
resolve_kernel_architecture() {
  local kernel_arch="$1"
  local docker_platform="$2"

  case "${kernel_arch}" in
    arm64)
      KERNEL_MAKE_ARCH="arm64"
      KERNEL_BUILD_TARGET="Image"
      KERNEL_BOOT_PATH="arch/arm64/boot/Image"
      KERNEL_IMAGE_SUFFIX="Image"
      if [[ "${docker_platform}" == "linux/arm64" ]]; then
        KERNEL_DEFAULT_CROSS_COMPILE=""
      else
        KERNEL_DEFAULT_CROSS_COMPILE="aarch64-linux-gnu-"
      fi
      ;;
    x86_64)
      if [[ "${docker_platform}" != "linux/amd64" ]]; then
        printf 'x86_64 builds require SPOREVM_KERNEL_DOCKER_PLATFORM=linux/amd64\n' >&2
        return 1
      fi
      KERNEL_MAKE_ARCH="x86_64"
      KERNEL_BUILD_TARGET="bzImage"
      KERNEL_BOOT_PATH="arch/x86/boot/bzImage"
      KERNEL_IMAGE_SUFFIX="bzImage"
      KERNEL_DEFAULT_CROSS_COMPILE=""
      ;;
    *)
      printf 'unsupported SPOREVM_KERNEL_ARCH: %s\n' "${kernel_arch}" >&2
      printf 'expected arm64 or x86_64\n' >&2
      return 1
      ;;
  esac
}
