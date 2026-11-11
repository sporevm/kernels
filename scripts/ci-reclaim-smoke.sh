#!/usr/bin/env bash
set -euo pipefail

# Boots the arm64 Image this build produced under a pinned SporeVM release and
# writes to the guest's ext4 root after evicting ext4's block-allocator (buddy)
# cache. Linux 6.1.191 oopsed on exactly this until
# patches/0002-ext4-fix-NULL-folio-dereference-in-mballoc.patch, and building a
# kernel never exercises it. The probe matches sporevm's
# test/smoke/rootfs/reclaim.sh. Needs a Linux arm64 agent with KVM.

die() {
  printf '[ci-reclaim-smoke] error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local name="$1"
  command -v "$name" >/dev/null 2>&1 || die "missing required command: ${name}"
}

SPORE_VERSION="v0.18.3"
SPORE_ARCHIVE_SHA256="d014626c6007e0ebff2689b8263917cd9287ce51e62392f64b2df08ea0b2e397"

require_command buildkite-agent
require_command curl
require_command sha256sum
require_command tar
[[ "$(uname -s)-$(uname -m)" == "Linux-aarch64" ]] || die "requires Linux arm64 with KVM"

work="$(mktemp -d "${TMPDIR:-/tmp}/kernel-reclaim.XXXXXX")"
trap 'rm -rf "${work}"' EXIT

echo "--- :package: Fetch the built Image and spore ${SPORE_VERSION}"
buildkite-agent artifact download "dist/kernels/sporevm-arm64-linux-*-Image" "${work}"
kernels=("${work}"/dist/kernels/sporevm-arm64-linux-*-Image)
[[ ${#kernels[@]} -eq 1 && -f "${kernels[0]}" ]] || die "expected one arm64 Image artifact"
curl -fsSL -o "${work}/spore.tar.gz" \
  "https://github.com/sporevm/sporevm/releases/download/${SPORE_VERSION}/spore_Linux_arm64.tar.gz"
echo "${SPORE_ARCHIVE_SHA256}  ${work}/spore.tar.gz" | sha256sum -c - >/dev/null \
  || die "spore ${SPORE_VERSION} archive checksum mismatch"
tar -xzf "${work}/spore.tar.gz" -C "${work}"
spore="${work}/spore_Linux_arm64/bin/spore"
[[ -x "${spore}" ]] || die "spore binary missing from the release archive"

# shellcheck disable=SC2016 # expanded by the guest shell
probe='set -eu
test "$(awk "\$2 == \"/\" { fs = \$3 } END { print fs }" /proc/mounts)" = ext4
for round in 1 2 3; do
  dd if=/dev/zero of="/reclaim-a${round}" bs=1M count=4 conv=fsync 2>/dev/null
  sync
  echo 3 >/proc/sys/vm/drop_caches
  dd if=/dev/zero of="/reclaim-b${round}" bs=1M count=4 conv=fsync 2>/dev/null
done
test "$(( $(cat /proc/sys/kernel/tainted) & 128 ))" -eq 0
echo reclaim-ok'

echo "--- :fire: Write to ext4 after evicting the buddy cache"
mkdir -m 0700 "${work}/runtime"
if ! SPOREVM_KERNEL_IMAGE="${kernels[0]}" \
  SPOREVM_RUNTIME_DIR="${work}/runtime" \
  SPOREVM_ROOTFS_CACHE_DIR="${work}/rootfs-cache" \
  "${spore}" run \
    --backend kvm \
    --memory 256mib \
    --image docker.io/library/alpine:3.20 \
    --console-log "${work}/console.log" \
    -- /bin/sh -c "${probe}" >"${work}/stdout"; then
  cat "${work}/stdout" >&2 || true
  grep -a -E 'Internal error|Unable to handle|pc : ' "${work}/console.log" >&2 || true
  die "guest failed to write after evicting the ext4 buddy cache"
fi
grep -Fxq reclaim-ok "${work}/stdout" || die "reclaim probe did not report success"
echo "reclaim smoke ok: $(basename "${kernels[0]}")"
