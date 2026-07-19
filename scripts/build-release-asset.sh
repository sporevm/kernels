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

require_config_bool() {
  local config_path="$1"
  local symbol="$2"
  local expected="$3"

  case "${expected}" in
    "")
      return
      ;;
    1)
      grep -qx "CONFIG_${symbol}=y" "${config_path}" || die "${config_path} missing CONFIG_${symbol}=y"
      ;;
    0)
      if grep -qx "CONFIG_${symbol}=y" "${config_path}"; then
        die "${config_path} unexpectedly enables CONFIG_${symbol}"
      fi
      grep -qx "# CONFIG_${symbol} is not set" "${config_path}" || die "${config_path} missing disabled CONFIG_${symbol}"
      ;;
    *)
      die "invalid expected config value for CONFIG_${symbol}: ${expected}"
      ;;
  esac
}

require_config_disabled() {
  local config_path="$1"
  local symbol="$2"

  if grep -Eq "^CONFIG_${symbol}=(y|m)$" "${config_path}"; then
    die "${config_path} unexpectedly enables CONFIG_${symbol}"
  fi
}

build_asset() {
  local purpose="$1"
  local asset_base="$2"
  local build_script="$3"
  local kernel_config_base="$4"
  local kernel_config_devmem="${5:-}"
  local kernel_config_strict_devmem="${6:-}"
  local kernel_config_initrd="${7:-}"
  local kernel_config_virtio_blk="${8:-}"
  local kernel_config_ext4="${9:-}"
  local kernel_config_multiuser="${10:-}"
  local kernel_config_sysvipc="${11:-}"
  local kernel_config_posix_timers="${12:-}"
  local kernel_config_binfmt_script="${13:-}"
  local -a required_enabled_config_symbols=()
  local image_name image_path config_path sha256_path manifest_path kernel_sha256

  if [[ "$#" -gt 13 ]]; then
    required_enabled_config_symbols=("${@:14}")
  fi

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
    "${SCRIPT_DIR}/${build_script}" "${image_path}" >/dev/null

  [[ -f "${image_path}" ]] || die "kernel image was not created: ${image_path}"
  [[ -f "${config_path}" ]] || die "kernel config was not created: ${config_path}"

  require_config_bool "${config_path}" "DEVMEM" "${kernel_config_devmem}"
  require_config_bool "${config_path}" "STRICT_DEVMEM" "${kernel_config_strict_devmem}"
  require_config_bool "${config_path}" "IO_STRICT_DEVMEM" "${KERNEL_CONFIG_IO_STRICT_DEVMEM}"
  require_config_bool "${config_path}" "BLK_DEV_INITRD" "${kernel_config_initrd}"
  require_config_bool "${config_path}" "VIRTIO_BLK" "${kernel_config_virtio_blk}"
  require_config_bool "${config_path}" "EXT4_FS" "${kernel_config_ext4}"
  require_config_bool "${config_path}" "SECURITY" "0"
  require_config_bool "${config_path}" "MULTIUSER" "${kernel_config_multiuser}"
  require_config_bool "${config_path}" "SYSVIPC" "${kernel_config_sysvipc}"
  require_config_bool "${config_path}" "POSIX_TIMERS" "${kernel_config_posix_timers}"
  require_config_bool "${config_path}" "BINFMT_SCRIPT" "${kernel_config_binfmt_script}"
  for symbol in "${required_enabled_config_symbols[@]}"; do
    require_config_bool "${config_path}" "${symbol}" "1"
  done
  if ((${#ARCH_REQUIRED_ENABLED_CONFIG_SYMBOLS[@]} > 0)); then
    for symbol in "${ARCH_REQUIRED_ENABLED_CONFIG_SYMBOLS[@]}"; do
      require_config_bool "${config_path}" "${symbol}" "1"
    done
  fi
  if ((${#ARCH_REQUIRED_DISABLED_CONFIG_SYMBOLS[@]} > 0)); then
    for symbol in "${ARCH_REQUIRED_DISABLED_CONFIG_SYMBOLS[@]}"; do
      require_config_disabled "${config_path}" "${symbol}"
    done
  fi

  kernel_sha256="$(sha256_file "${image_path}")"
  printf '%s  %s\n' "${kernel_sha256}" "${image_name}" > "${sha256_path}"

  ASSET_BASE="${asset_base}" \
  DOCKER_IMAGE="${DOCKER_IMAGE}" \
  DOCKER_PLATFORM="${DOCKER_PLATFORM}" \
  IMAGE_NAME="${image_name}" \
  KERNEL_ARCH="${KERNEL_ARCH}" \
  KERNEL_CONFIG_BASE="${kernel_config_base}" \
  KERNEL_CONFIG_DEVMEM="${kernel_config_devmem}" \
  KERNEL_CONFIG_STRICT_DEVMEM="${kernel_config_strict_devmem}" \
  KERNEL_CONFIG_IO_STRICT_DEVMEM="${KERNEL_CONFIG_IO_STRICT_DEVMEM}" \
  KERNEL_CONFIG_INITRD="${kernel_config_initrd}" \
  KERNEL_CONFIG_VIRTIO_BLK="${kernel_config_virtio_blk}" \
  KERNEL_CONFIG_EXT4="${kernel_config_ext4}" \
  KERNEL_CONFIG_MULTIUSER="${kernel_config_multiuser}" \
  KERNEL_CONFIG_SYSVIPC="${kernel_config_sysvipc}" \
  KERNEL_CONFIG_POSIX_TIMERS="${kernel_config_posix_timers}" \
  KERNEL_CONFIG_BINFMT_SCRIPT="${kernel_config_binfmt_script}" \
  KERNEL_SHA256="${kernel_sha256}" \
  KERNEL_TARBALL_SHA256="${KERNEL_TARBALL_SHA256}" \
  KERNEL_VERSION="${KERNEL_VERSION}" \
  PURPOSE="${purpose}" \
  RELEASE_TAG="${RELEASE_TAG}" \
  BUILD_SCRIPT="${build_script}" \
  SOURCE_COMMIT="${SOURCE_COMMIT}" \
  SOURCE_REPOSITORY="${SOURCE_REPOSITORY}" \
  python3 - <<'PY' > "${manifest_path}"
import json
import os

image_name = os.environ["IMAGE_NAME"]
kernel_config = {"base": os.environ["KERNEL_CONFIG_BASE"]}
for key, env_name in (
    ("devmem", "KERNEL_CONFIG_DEVMEM"),
    ("strict_devmem", "KERNEL_CONFIG_STRICT_DEVMEM"),
    ("io_strict_devmem", "KERNEL_CONFIG_IO_STRICT_DEVMEM"),
    ("initrd", "KERNEL_CONFIG_INITRD"),
    ("virtio_blk", "KERNEL_CONFIG_VIRTIO_BLK"),
    ("ext4", "KERNEL_CONFIG_EXT4"),
    ("multiuser", "KERNEL_CONFIG_MULTIUSER"),
    ("sysvipc", "KERNEL_CONFIG_SYSVIPC"),
    ("posix_timers", "KERNEL_CONFIG_POSIX_TIMERS"),
    ("binfmt_script", "KERNEL_CONFIG_BINFMT_SCRIPT"),
):
    value = os.environ[env_name]
    if value:
        kernel_config[key] = value == "1"

manifest = {
    "id": os.environ["ASSET_BASE"],
    "project": "sporevm",
    "purpose": os.environ["PURPOSE"],
    "arch": os.environ["KERNEL_ARCH"],
    "linux_version": os.environ["KERNEL_VERSION"],
    "assets": {
        "image": image_name,
        "config": image_name + ".config",
        "sha256": image_name + ".sha256",
        "manifest": os.environ["ASSET_BASE"] + ".manifest.json",
    },
    "kernel_config": kernel_config,
    "sha256": os.environ["KERNEL_SHA256"],
    "source": {
        "repository": os.environ["SOURCE_REPOSITORY"],
        "commit": os.environ["SOURCE_COMMIT"],
        "tag": os.environ["RELEASE_TAG"],
    },
    "builder": {
        "repository": os.environ["SOURCE_REPOSITORY"],
        "script": "scripts/" + os.environ["BUILD_SCRIPT"],
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
KERNEL_VERSION="${SPOREVM_KERNEL_VERSION:-6.1.155}"
KERNEL_ARCH="${SPOREVM_KERNEL_ARCH:-arm64}"
DOCKER_IMAGE="${SPOREVM_KERNEL_DOCKER_IMAGE:-sporevm-kernel-builder:ubuntu-22.04}"
DOCKER_PLATFORM="${SPOREVM_KERNEL_DOCKER_PLATFORM:-linux/amd64}"
KERNEL_TARBALL_SHA256="${SPOREVM_KERNEL_TARBALL_SHA256:-}"
if [[ -z "${KERNEL_TARBALL_SHA256}" && "${KERNEL_VERSION}" == "6.1.155" ]]; then
  KERNEL_TARBALL_SHA256="c29387aeee085fbcbd91236224b9df805063bac43615e75cea2c6b29604a5c73"
fi
resolve_kernel_architecture "${KERNEL_ARCH}" "${DOCKER_PLATFORM}" || die "unsupported release kernel arch: ${KERNEL_ARCH}"
KERNEL_CROSS_COMPILE="${SPOREVM_KERNEL_CROSS_COMPILE-${KERNEL_DEFAULT_CROSS_COMPILE}}"
resolve_kernel_cross_package "${KERNEL_ARCH}" "${KERNEL_CROSS_COMPILE}" || die "unsupported cross compiler for ${KERNEL_ARCH}"

KERNEL_CONFIG_DEVMEM="0"
KERNEL_CONFIG_STRICT_DEVMEM=""
KERNEL_CONFIG_IO_STRICT_DEVMEM=""
ARCH_REQUIRED_ENABLED_CONFIG_SYMBOLS=()
ARCH_REQUIRED_DISABLED_CONFIG_SYMBOLS=()
if [[ "${KERNEL_ARCH}" == "x86_64" ]]; then
  KERNEL_CONFIG_DEVMEM="1"
  KERNEL_CONFIG_STRICT_DEVMEM="1"
  KERNEL_CONFIG_IO_STRICT_DEVMEM="0"
  ARCH_REQUIRED_ENABLED_CONFIG_SYMBOLS=(
    X86_64
    SMP
    X86_LOCAL_APIC
    X86_IO_APIC
    X86_MPPARSE
    HYPERVISOR_GUEST
    PARAVIRT
    PARAVIRT_CLOCK
    KVM_GUEST
    RELOCATABLE
    VIRTIO_MMIO_CMDLINE_DEVICES
  )
  ARCH_REQUIRED_DISABLED_CONFIG_SYMBOLS=(
    ACPI
    EFI
    PCI
    VIRTIO_PCI
    RTC_CLASS
    SERIAL_8250
    KEYBOARD_ATKBD
    MOUSE_PS2
    SERIO_I8042
  )
fi

require_command docker
require_command git
require_command python3

mkdir -p "${OUTPUT_DIR}"

SOURCE_COMMIT="$(resolve_source_commit "${REPO_ROOT}")"
SOURCE_REPOSITORY="${SPOREVM_KERNELS_GITHUB_REPOSITORY:-sporevm/kernels}"
RELEASE_TAG="${SPOREVM_KERNELS_RELEASE_TAG:-${BUILDKITE_TAG:-}}"

build_asset \
  "run" \
  "${SPOREVM_KERNEL_ASSET_BASE:-sporevm-${KERNEL_ARCH}-linux-${KERNEL_VERSION}}" \
  "build-sporevm-kernel.sh" \
  "sporevm-initrd+rootfs" \
  "${KERNEL_CONFIG_DEVMEM}" \
  "${KERNEL_CONFIG_STRICT_DEVMEM}" \
  "1" \
  "1" \
  "1" \
  "1" \
  "1" \
  "1" \
  "1" \
  "HVC_DRIVER" \
  "VIRTIO" \
  "VIRTIO_MMIO" \
  "VIRTIO_CONSOLE" \
  "VIRTIO_NET" \
  "VSOCKETS" \
  "VIRTIO_VSOCKETS" \
  "EXT4_FS_SECURITY" \
  "HW_RANDOM" \
  "HW_RANDOM_VIRTIO" \
  "FILE_LOCKING" \
  "SHMEM" \
  "TMPFS" \
  "TMPFS_XATTR" \
  "FSNOTIFY" \
  "INOTIFY_USER" \
  "FHANDLE" \
  "POSIX_MQUEUE" \
  "KEYS" \
  "NAMESPACES" \
  "UTS_NS" \
  "IPC_NS" \
  "PID_NS" \
  "NET_NS" \
  "USER_NS" \
  "CGROUPS" \
  "BPF_SYSCALL" \
  "CGROUP_BPF" \
  "CGROUP_SCHED" \
  "FAIR_GROUP_SCHED" \
  "CFS_BANDWIDTH" \
  "CGROUP_CPUACCT" \
  "CGROUP_DEVICE" \
  "CGROUP_FREEZER" \
  "CGROUP_PIDS" \
  "CPUSETS" \
  "PROC_PID_CPUSET" \
  "MEMCG" \
  "PSI" \
  "SECCOMP" \
  "SECCOMP_FILTER" \
  "OVERLAY_FS" \
  "TUN" \
  "VETH" \
  "MACVLAN" \
  "IPVLAN" \
  "VXLAN" \
  "BRIDGE" \
  "BRIDGE_NETFILTER" \
  "NETFILTER" \
  "NETFILTER_ADVANCED" \
  "NF_CONNTRACK" \
  "NF_NAT" \
  "NETFILTER_XTABLES" \
  "NETFILTER_XT_TARGET_CHECKSUM" \
  "NETFILTER_XT_TARGET_MASQUERADE" \
  "NETFILTER_XT_TARGET_REDIRECT" \
  "NETFILTER_XT_MATCH_ADDRTYPE" \
  "NETFILTER_XT_MATCH_CONNTRACK" \
  "NF_TABLES" \
  "NF_TABLES_IPV4" \
  "NFT_COMPAT" \
  "NFT_CT" \
  "NFT_MASQ" \
  "NFT_NAT" \
  "NFT_REJECT" \
  "NFT_REJECT_IPV4" \
  "IP_NF_IPTABLES" \
  "IP_NF_FILTER" \
  "IP_NF_TARGET_REJECT" \
  "IP_NF_NAT" \
  "IP_NF_TARGET_MASQUERADE" \
  "IP_NF_TARGET_REDIRECT" \
  "IP_NF_MANGLE" \
  "IP_NF_RAW" \
  "MEMORY_HOTPLUG" \
  "MEMORY_HOTPLUG_DEFAULT_ONLINE" \
  "MEMORY_HOTREMOVE" \
  "MIGRATION" \
  "CONTIG_ALLOC" \
  "EXCLUSIVE_SYSTEM_RAM" \
  "SPARSEMEM_VMEMMAP" \
  "VIRTIO_MEM"
