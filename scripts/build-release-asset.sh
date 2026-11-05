#!/usr/bin/env bash
set -euo pipefail

die() {
  printf '[build-release-asset] error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || die "missing required command: ${name}"
}

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return
  fi
  die "sha256 tool not found (need sha256sum or shasum)"
}

resolve_source_commit() {
  local repo_root="$1"
  local commit status

  commit="$(git -C "${repo_root}" rev-parse --verify 'HEAD^{commit}' 2>/dev/null)" ||
    die "could not determine the source commit for ${repo_root}"
  [[ -n "${commit}" ]] || die "could not determine the source commit for ${repo_root}"

  status="$(git -C "${repo_root}" status --porcelain --untracked-files=normal)" ||
    die "could not inspect the source worktree at ${repo_root}"
  [[ -z "${status}" ]] || die "source worktree is dirty; commit or stash changes before building release assets"

  printf '%s\n' "${commit}"
}

require_config_fragments() {
  local config_path="$1"
  local fragment line symbol

  for fragment in "${CONFIG_FRAGMENTS[@]}"; do
    while IFS= read -r line || [[ -n "${line}" ]]; do
      if [[ "${line}" =~ ^#\ (CONFIG_[A-Za-z0-9_]+)\ is\ not\ set$ ]]; then
        symbol="${BASH_REMATCH[1]}"
        if grep -q "^${symbol}=" "${config_path}"; then
          die "${config_path} sets ${symbol}, but ${fragment} disables it"
        fi
      elif [[ "${line}" =~ ^#.CONFIG_ ]]; then
        # kconfig also honours looser disable lines, such as trailing text.
        die "malformed disable line in ${fragment}: ${line}"
      elif [[ "${line}" =~ ^CONFIG_[A-Za-z0-9_]+= ]]; then
        grep -qxF "${line}" "${config_path}" || die "${config_path} is missing ${line} from ${fragment}"
      elif [[ -n "${line}" && "${line}" != \#* ]]; then
        die "unexpected line in ${fragment}: ${line}"
      fi
    done < "${fragment}"
  done
}

build_asset() {
  local asset_base="$1"
  local image_name image_path config_path sha256_path manifest_path kernel_sha256

  image_name="${asset_base}-${KERNEL_IMAGE_SUFFIX}"
  image_path="${OUTPUT_DIR}/${image_name}"
  config_path="${image_path}.config"
  sha256_path="${image_path}.sha256"
  manifest_path="${OUTPUT_DIR}/${asset_base}.manifest.json"

  rm -f "${image_path}" "${config_path}" "${sha256_path}" "${manifest_path}"

  SPOREVM_KERNEL_ARCH="${KERNEL_ARCH}" \
  SPOREVM_KERNEL_VERSION="${KERNEL_VERSION}" \
  SPOREVM_KERNEL_DOCKER_IMAGE="${DOCKER_IMAGE}" \
  SPOREVM_KERNEL_DOCKER_PLATFORM="${DOCKER_PLATFORM}" \
  SPOREVM_KERNEL_CROSS_COMPILE="${KERNEL_CROSS_COMPILE}" \
  SPOREVM_KERNEL_TARBALL_SHA256="${KERNEL_TARBALL_SHA256}" \
    "${SCRIPT_DIR}/build-kernel.sh" "${image_path}" >/dev/null

  [[ -f "${image_path}" ]] || die "kernel image was not created: ${image_path}"
  [[ -f "${config_path}" ]] || die "kernel config was not created: ${config_path}"

  require_config_fragments "${config_path}"

  kernel_sha256="$(sha256_file "${image_path}")"
  printf '%s  %s\n' "${kernel_sha256}" "${image_name}" > "${sha256_path}"

  ASSET_BASE="${asset_base}" \
  DOCKER_IMAGE="${DOCKER_IMAGE}" \
  DOCKER_PLATFORM="${DOCKER_PLATFORM}" \
  IMAGE_NAME="${image_name}" \
  KERNEL_ARCH="${KERNEL_ARCH}" \
  KERNEL_SHA256="${kernel_sha256}" \
  KERNEL_TARBALL_SHA256="${KERNEL_TARBALL_SHA256}" \
  KERNEL_VERSION="${KERNEL_VERSION}" \
  RELEASE_TAG="${RELEASE_TAG}" \
  SOURCE_COMMIT="${SOURCE_COMMIT}" \
  SOURCE_REPOSITORY="${SOURCE_REPOSITORY}" \
  python3 - <<'PY' > "${manifest_path}"
import json
import os

image_name = os.environ["IMAGE_NAME"]

manifest = {
    "id": os.environ["ASSET_BASE"],
    "project": "sporevm",
    "purpose": "run",
    "arch": os.environ["KERNEL_ARCH"],
    "linux_version": os.environ["KERNEL_VERSION"],
    "assets": {
        "image": image_name,
        "config": image_name + ".config",
        "sha256": image_name + ".sha256",
        "manifest": os.environ["ASSET_BASE"] + ".manifest.json",
    },
    "sha256": os.environ["KERNEL_SHA256"],
    "source": {
        "repository": os.environ["SOURCE_REPOSITORY"],
        "commit": os.environ["SOURCE_COMMIT"],
        "tag": os.environ["RELEASE_TAG"],
    },
    "builder": {
        "repository": os.environ["SOURCE_REPOSITORY"],
        "script": "scripts/build-kernel.sh",
        "docker_image": os.environ["DOCKER_IMAGE"],
        "docker_platform": os.environ["DOCKER_PLATFORM"],
        "kernel_tarball_sha256": os.environ["KERNEL_TARBALL_SHA256"],
    },
}
print(json.dumps(manifest, indent=2, sort_keys=True))
PY

  printf '[build-release-asset] wrote %s\n' "${image_path}"
  printf '[build-release-asset] wrote %s\n' "${config_path}"
  printf '[build-release-asset] wrote %s\n' "${sha256_path}"
  printf '[build-release-asset] wrote %s\n' "${manifest_path}"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=scripts/kernel-architecture.sh
source "${SCRIPT_DIR}/kernel-architecture.sh"

OUTPUT_DIR="${1:-${REPO_ROOT}/dist/kernels}"
KERNEL_VERSION="${SPOREVM_KERNEL_VERSION:-6.1.191}"
KERNEL_ARCH="${SPOREVM_KERNEL_ARCH:-arm64}"
DOCKER_IMAGE="${SPOREVM_KERNEL_DOCKER_IMAGE:-sporevm-kernel-builder:ubuntu-22.04}"
DOCKER_PLATFORM="${SPOREVM_KERNEL_DOCKER_PLATFORM:-linux/amd64}"
KERNEL_TARBALL_SHA256="${SPOREVM_KERNEL_TARBALL_SHA256:-}"
if [[ -z "${KERNEL_TARBALL_SHA256}" && "${KERNEL_VERSION}" == "6.1.191" ]]; then
  KERNEL_TARBALL_SHA256="02f15b77d213e15607923832ef9382e2414ea90df6c007f15a910e139645c35d"
fi
resolve_kernel_architecture "${KERNEL_ARCH}" "${DOCKER_PLATFORM}" || die "unsupported release kernel arch: ${KERNEL_ARCH}"
KERNEL_CROSS_COMPILE="${SPOREVM_KERNEL_CROSS_COMPILE-${KERNEL_DEFAULT_CROSS_COMPILE}}"
validate_kernel_cross_compile "${KERNEL_ARCH}" "${KERNEL_CROSS_COMPILE}" || die "unsupported cross compiler for ${KERNEL_ARCH}"

CONFIG_FRAGMENTS=("${REPO_ROOT}/config/common.config" "${REPO_ROOT}/config/${KERNEL_ARCH}.config")

require_command docker
require_command git
require_command python3

mkdir -p "${OUTPUT_DIR}"

SOURCE_COMMIT="$(resolve_source_commit "${REPO_ROOT}")"
SOURCE_REPOSITORY="${SPOREVM_KERNELS_GITHUB_REPOSITORY:-sporevm/kernels}"
RELEASE_TAG="${SPOREVM_KERNELS_RELEASE_TAG:-${BUILDKITE_TAG:-}}"

build_asset "${SPOREVM_KERNEL_ASSET_BASE:-sporevm-${KERNEL_ARCH}-linux-${KERNEL_VERSION}}"
