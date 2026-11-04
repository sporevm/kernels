#!/usr/bin/env bash
# Disposable validation branch only; never used to publish a release.
set -euo pipefail

arch="${1:?expected arm64 or x86_64}"
version="${2:?expected 6.1.155 or 6.1.191}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
core_commit=a6b697876ddcdece29e99a2b7745df7e24532362
artifact_build=01a1a0ef-dcee-406d-9bcf-7b0504f3279d
case "${arch}:$(uname -sm)" in
  'arm64:Linux aarch64') release=v0.6.3; image_kind=Image ;;
  'x86_64:Linux x86_64') release=v0.7.0; image_kind=bzImage ;;
  *) echo "Native host architecture mismatch" >&2; exit 1 ;;
esac
case "${version}" in
  6.1.155|6.1.191) ;;
  *) echo "Unexpected kernel version" >&2; exit 1 ;;
esac
[[ -r /dev/kvm && -w /dev/kvm ]]

evidence="${repo_root}/dist/native-validation/${arch}-${version}"
mkdir -p "${evidence}"
exec > >(tee "${evidence}/validation.log") 2>&1
work="$(mktemp -d /tmp/sporevm-kernel-validation.XXXXXX)"
trap 'rm -rf "${work}"' EXIT
seed="${work}/seed"
mkdir -p "${seed}"
asset="sporevm-${arch}-linux-${version}-${image_kind}"

echo "--- Verify ${arch} Linux ${version} artifacts"
if [[ "${version}" == 6.1.191 ]]; then
  mkdir -p "${work}/download"
  buildkite-agent artifact download --build "${artifact_build}" \
    "dist/kernels/sporevm-${arch}-linux-${version}*" "${work}/download"
  cp "${work}/download/dist/kernels/"* "${seed}/"
else
  for suffix in "" .config .sha256; do
    curl -fsSL --retry 3 \
      "https://github.com/sporevm/kernels/releases/download/${release}/${asset}${suffix}" \
      -o "${seed}/${asset}${suffix}"
  done
fi
(cd "${seed}" && sha256sum -c "${asset}.sha256")
sha256sum "${seed}/${asset}" "${seed}/${asset}.config" | tee "${evidence}/artifact-sha256.txt"
if [[ "${version}" == 6.1.191 ]]; then
  cp "${seed}/sporevm-${arch}-linux-${version}.manifest.json" "${evidence}/"
  if [[ "${arch}" == x86_64 ]]; then
    printf '%s  %s\n' 13ca22ff42b795c33365c89fad3e7d5bbf0a972cdaedc7f70f2f78270ee7bb82 "${seed}/${asset}" | sha256sum -c -
  fi
fi

echo "--- Prepare isolated core checkout ${core_commit}"
git clone --quiet --no-checkout https://github.com/sporevm/sporevm.git "${work}/core"
git -C "${work}/core" checkout --quiet --detach "${core_commit}"
cd "${work}/core"
if [[ "${version}" == 6.1.191 ]]; then
  # Update only consumer pins and asset names, preserving all smoke assertions.
  git apply "${repo_root}/.buildkite/native-candidate.patch"
fi
if [[ "${arch}" == arm64 ]]; then
  # Existing capture smoke must count child manifests, not shared-chunks.
  # Apply the same correction to both control and candidate.
  git apply "${repo_root}/.buildkite/native-smoke-compat.patch"
fi
git diff --check
git diff >"${evidence}/test-only-core-changes.patch"
printf 'core=%s\narch=%s\nversion=%s\nartifact_build=%s\n' \
  "$(git rev-parse HEAD)" "${arch}" "${version}" "${artifact_build}" | tee "${evidence}/identity.txt"
mise trust "${work}/core/mise.toml"
mise install

export SPORE_BACKEND=kvm
export SPOREVM_KERNEL_VERSION="${version}"
export SPOREVM_KERNEL_RELEASE="${release}"
export SPOREVM_KERNEL_CACHE_DIR="${work}/kernel-cache"
export SPOREVM_ROOTFS_CACHE_DIR="${work}/rootfs-cache"
export SPOREVM_RUNTIME_DIR="${work}/runtime"
export SPOREVM_X86_MANAGED_KERNEL_SEED_DIR="${seed}"
unset SPOREVM_KERNEL_IMAGE SPOREVM_RUN_INITRD
managed="${SPOREVM_KERNEL_CACHE_DIR}/sporevm-kernels/${release}"
mkdir -p "${managed}" "${SPOREVM_RUNTIME_DIR}"
chmod 0700 "${SPOREVM_RUNTIME_DIR}"
cp "${seed}/${asset}" "${seed}/${asset}.config" "${seed}/${asset}.sha256" "${managed}/"
chmod 0444 "${managed}/"*
mise exec -- scripts/kernel/ensure-managed-kernel.sh run
mise run build:release

echo "--- Assert guest kernel identity through native SporeVM/KVM"
mise exec -- zig-out/bin/spore run --backend kvm --memory 512mib \
  --image docker.io/library/alpine:3.20 -- /bin/uname -r | tee "${evidence}/guest-uname.txt"
grep -Fxq "${version}" "${evidence}/guest-uname.txt"

if [[ "${arch}" == x86_64 ]]; then
  mise run smoke:x86-slice3b
  mise run smoke:x86-slice3c
else
  echo "--- ARM64 product, filesystem, network, capture/fork, and build tests"
  failed=0
  for smoke in \
    run/basic run/file-locking run/cgroup \
    network/config network/dns network/http network/deny network/bind-service network/forward \
    run/capture lifecycle/basic rootfs/writable; do
    echo "--- ${smoke}"
    if mise exec -- bash "test/smoke/${smoke}.sh"; then
      printf '%s: PASS\n' "${smoke}" >>"${evidence}/cases.txt"
    else
      printf '%s: FAIL\n' "${smoke}" >>"${evidence}/cases.txt"
      failed=1
    fi
  done
  if mise exec -- bash scripts/ci/spore-build-smoke.sh; then
    echo 'VM-backed build: PASS' >>"${evidence}/cases.txt"
  else
    echo 'VM-backed build: FAIL' >>"${evidence}/cases.txt"
    failed=1
  fi
  cat "${evidence}/cases.txt"
  [[ "${failed}" == 0 ]] || exit 1
fi
echo "Native ${arch} Linux ${version}: PASS" | tee "${evidence}/result.txt"
