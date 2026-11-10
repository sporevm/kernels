#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/kernel-architecture.sh
source "${SCRIPT_DIR}/kernel-architecture.sh"

KERNEL_VERSION="${SPOREVM_KERNEL_VERSION:-6.1.191}"
KERNEL_ARCH="${SPOREVM_KERNEL_ARCH:-arm64}"
DEFAULT_DOCKER_IMAGE="sporevm-kernel-builder:ubuntu-22.04"
DOCKER_IMAGE="${SPOREVM_KERNEL_DOCKER_IMAGE:-${DEFAULT_DOCKER_IMAGE}}"
DOCKER_PLATFORM="${SPOREVM_KERNEL_DOCKER_PLATFORM:-linux/amd64}"
BUILD_DIR="${SPOREVM_KERNEL_BUILD_DIR:-}"
BUILD_VOLUME="${SPOREVM_KERNEL_BUILD_VOLUME:-sporevm-kernel}"
KBUILD_BUILD_USER="${SPOREVM_KERNEL_BUILD_USER:-root}"
KBUILD_BUILD_HOST="${SPOREVM_KERNEL_BUILD_HOST:-906884a1e5be}"
KBUILD_BUILD_TIMESTAMP="${SPOREVM_KERNEL_BUILD_TIMESTAMP:-Sat Jul 18 04:00:42 UTC 2026}"
KBUILD_BUILD_VERSION="${SPOREVM_KERNEL_BUILD_VERSION:-1}"
DEFAULT_KERNEL_TARBALL_SHA256=""
if [[ "${KERNEL_VERSION}" == "6.1.191" ]]; then
  DEFAULT_KERNEL_TARBALL_SHA256="02f15b77d213e15607923832ef9382e2414ea90df6c007f15a910e139645c35d"
fi
KERNEL_TARBALL_SHA256="${SPOREVM_KERNEL_TARBALL_SHA256:-${DEFAULT_KERNEL_TARBALL_SHA256}}"
resolve_kernel_architecture "${KERNEL_ARCH}" "${DOCKER_PLATFORM}"
KERNEL_CROSS_COMPILE="${SPOREVM_KERNEL_CROSS_COMPILE-${KERNEL_DEFAULT_CROSS_COMPILE}}"
validate_kernel_cross_compile "${KERNEL_ARCH}" "${KERNEL_CROSS_COMPILE}"

if [[ -z "${KERNEL_TARBALL_SHA256}" ]]; then
  echo "missing SPOREVM_KERNEL_TARBALL_SHA256 for Linux ${KERNEL_VERSION}" >&2
  exit 1
fi

OUTPUT_PATH="${1:-${REPO_ROOT}/dist/sporevm-${KERNEL_ARCH}-linux-${KERNEL_VERSION}-${KERNEL_IMAGE_SUFFIX}}"
CONFIG_PATH="${OUTPUT_PATH}.config"
mkdir -p "$(dirname "${OUTPUT_PATH}")"
OUTPUT_DIR="$(cd "$(dirname "${OUTPUT_PATH}")" && pwd)"
OUTPUT_BASENAME="$(basename "${OUTPUT_PATH}")"
CONFIG_BASENAME="$(basename "${CONFIG_PATH}")"
if [[ -n "${BUILD_DIR}" ]]; then
  mkdir -p "${BUILD_DIR}"
  BUILD_MOUNT="$(cd "${BUILD_DIR}" && pwd):/build"
else
  BUILD_MOUNT="${BUILD_VOLUME}:/build"
fi

if [[ "${DOCKER_IMAGE}" == "${DEFAULT_DOCKER_IMAGE}" ]]; then
  docker build \
    --load \
    --platform "${DOCKER_PLATFORM}" \
    --tag "${DOCKER_IMAGE}" \
    --file "${REPO_ROOT}/Dockerfile" \
    "${REPO_ROOT}"
fi

docker run --rm \
  --ulimit nofile=65536:65536 \
  --platform "${DOCKER_PLATFORM}" \
  --hostname "${KBUILD_BUILD_HOST}" \
  -e "KERNEL_VERSION=${KERNEL_VERSION}" \
  -e "KERNEL_ARCH=${KERNEL_ARCH}" \
  -e "KERNEL_MAKE_ARCH=${KERNEL_MAKE_ARCH}" \
  -e "KERNEL_BUILD_TARGET=${KERNEL_BUILD_TARGET}" \
  -e "KERNEL_BOOT_PATH=${KERNEL_BOOT_PATH}" \
  -e "KERNEL_CROSS_COMPILE=${KERNEL_CROSS_COMPILE}" \
  -e "KERNEL_TARBALL_SHA256=${KERNEL_TARBALL_SHA256}" \
  -e "KBUILD_BUILD_USER=${KBUILD_BUILD_USER}" \
  -e "KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST}" \
  -e "KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP}" \
  -e "KBUILD_BUILD_VERSION=${KBUILD_BUILD_VERSION}" \
  -e "OUTPUT_BASENAME=${OUTPUT_BASENAME}" \
  -e "CONFIG_BASENAME=${CONFIG_BASENAME}" \
  -v "${BUILD_MOUNT}" \
  -v "${REPO_ROOT}/config:/config:ro" \
  -v "${REPO_ROOT}/patches:/patches:ro" \
  -v "${OUTPUT_DIR}:/out" \
  "${DOCKER_IMAGE}" \
  bash -lc '
    set -euo pipefail

    src="/build/linux-${KERNEL_VERSION}"
    tarball="/build/linux-${KERNEL_VERSION}.tar.xz"
    source_stamp="${src}.source.sha256"

    download_kernel_tarball() {
      rm -f "${tarball}.tmp"
      curl -fsSL \
        "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz" \
        -o "${tarball}.tmp"
      mv "${tarball}.tmp" "${tarball}"
    }

    verify_kernel_tarball() {
      echo "${KERNEL_TARBALL_SHA256}  ${tarball}" | sha256sum -c -
    }

    # Every patch applies, in name order, to both architectures. The cached
    # source tree is reused only for the same tarball and patch contents.
    shopt -s nullglob
    patches=(/patches/*.patch)
    shopt -u nullglob
    source_id="$({
      printf "%s\n" "${KERNEL_TARBALL_SHA256}"
      if (( ${#patches[@]} > 0 )); then sha256sum "${patches[@]}"; fi
    } | sha256sum | cut -d " " -f 1)"

    if [[ ! -d "${src}" || ! -f "${source_stamp}" || "$(<"${source_stamp}")" != "${source_id}" ]]; then
      rm -rf "${src}" "${source_stamp}"
      if [[ ! -f "${tarball}" ]]; then
        download_kernel_tarball
      fi
      if ! verify_kernel_tarball; then
        rm -f "${tarball}"
        download_kernel_tarball
        verify_kernel_tarball
      fi
      tar -C /build -xf "${tarball}"
      for patch_file in "${patches[@]}"; do
        echo "applying ${patch_file##*/}"
        # No fuzz: after a Linux update, a patch whose context moved fails
        # the build instead of applying somewhere else.
        patch -d "${src}" -p1 --batch --quiet --fuzz=0 --no-backup-if-mismatch < "${patch_file}"
      done
      printf "%s\n" "${source_id}" > "${source_stamp}"
    fi

    out="/build/out-${KERNEL_ARCH}-${KERNEL_VERSION}"
    rm -rf "${out}"
    mkdir -p "${out}"

    make -C "${src}" O="${out}" ARCH="${KERNEL_MAKE_ARCH}" CROSS_COMPILE="${KERNEL_CROSS_COMPILE}" tinyconfig
    "${src}/scripts/kconfig/merge_config.sh" -m -O "${out}" "${out}/.config" \
      /config/common.config "/config/${KERNEL_ARCH}.config"
    make -C "${src}" O="${out}" ARCH="${KERNEL_MAKE_ARCH}" CROSS_COMPILE="${KERNEL_CROSS_COMPILE}" olddefconfig
    make -C "${src}" O="${out}" ARCH="${KERNEL_MAKE_ARCH}" CROSS_COMPILE="${KERNEL_CROSS_COMPILE}" -j"$(nproc)" "${KERNEL_BUILD_TARGET}"

    cp "${out}/${KERNEL_BOOT_PATH}" "/out/${OUTPUT_BASENAME}"
    cp "${out}/.config" "/out/${CONFIG_BASENAME}"
  '

printf '%s\n' "${OUTPUT_PATH}"
