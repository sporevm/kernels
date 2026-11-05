# SporeVM Kernels

Build and publish Linux kernel release assets for SporeVM.

## Assets

This repository publishes:

- `sporevm-arm64-linux-<version>-Image`
- `sporevm-arm64-linux-<version>-Image.config`
- `sporevm-arm64-linux-<version>-Image.sha256`
- `sporevm-arm64-linux-<version>.manifest.json`
- `sporevm-x86_64-linux-<version>-bzImage`
- `sporevm-x86_64-linux-<version>-bzImage.config`
- `sporevm-x86_64-linux-<version>-bzImage.sha256`
- `sporevm-x86_64-linux-<version>.manifest.json`

Both kernels include the initrd, rootfs, Docker, cgroup, namespace, networking,
and filesystem support needed by `spore run`. ARM64 disables `/dev/mem`.
x86_64 enables it with `CONFIG_STRICT_DEVMEM=y` and
`CONFIG_IO_STRICT_DEVMEM=n` so the guest can map the reserved SporeVM board
MMIO page without exposing ordinary system RAM.

The kernel config is `tinyconfig` plus the fragments in `config/`:
`common.config` and one file per architecture. The build fails unless the final
`.config` keeps every value the fragments set.

Release publishing fails closed unless the x86_64 bzImage, checksum, and
manifest all contain the approved SHA-256
`13ca22ff42b795c33365c89fad3e7d5bbf0a972cdaedc7f70f2f78270ee7bb82`.
The exact approved x86_64 image, config, checksum, and manifest are retained in
`approved/x86_64/6.1.191/`. CI stages those files verbatim and verifies all four
file hashes before upload and again before release publication. The ARM64
release asset continues to be built normally.

## Security baseline

Both architectures target upstream Linux **6.1.191** (6.1 LTS, released
2026-10-30), including the IPv4 TCP use-after-free fix for
[CVE-2026-98432](https://www.cve.org/CVERecord?id=CVE-2026-98432), first included
in 6.1.190. This is a stable-kernel baseline, not a claim that every published
CVE applies to this configuration or that no vulnerabilities remain.

Updating the build default alone does not update x86_64 releases: rebuild and
validate its four approved artifacts, then update their pinned hashes in
`scripts/verify-approved-x86-kernel-assets.sh`. Consumers must select the new
release and Linux version separately; existing guests are not updated by a
change in this repository.

## Build

Build one asset locally:

```sh
scripts/build-release-asset.sh dist/kernels

SPOREVM_KERNEL_ARCH=x86_64 \
  scripts/build-release-asset.sh dist/kernels-x86_64
```

Useful environment variables:

- `SPOREVM_KERNEL_VERSION`, default `6.1.191`
- `SPOREVM_KERNEL_ARCH`, `arm64` by default; also supports `x86_64`
- `SPOREVM_KERNEL_DOCKER_IMAGE`, defaults to the pinned builder in `Dockerfile`
- `SPOREVM_KERNEL_DOCKER_PLATFORM`, default `linux/amd64`; ARM64 kernels also
  support native `linux/arm64` builds
- `SPOREVM_KERNEL_CROSS_COMPILE`, default `aarch64-linux-gnu-` when needed
- `SPOREVM_KERNEL_TARBALL_SHA256`
- `SPOREVM_KERNEL_BUILD_USER`, `SPOREVM_KERNEL_BUILD_HOST`,
  `SPOREVM_KERNEL_BUILD_TIMESTAMP`, and `SPOREVM_KERNEL_BUILD_VERSION`, default
  to the metadata embedded in the approved x86_64 kernel
- `SPOREVM_KERNEL_BUILD_DIR`, optional host cache directory mounted at `/build`
- `SPOREVM_KERNELS_GITHUB_REPOSITORY`, default `sporevm/kernels`
- `SPOREVM_KERNELS_GITHUB_RELEASE_TOKEN`, used by tagged release publishing

## CI

Buildkite builds ARM64 and stages the approved x86_64 artifact set on hosted
agents. Tagged builds then publish both architectures and `dist/kernels.tar.gz`
to the matching GitHub Release.
