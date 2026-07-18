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

## Build

Build one asset locally:

```sh
scripts/build-release-asset.sh dist/kernels

SPOREVM_KERNEL_ARCH=x86_64 \
  scripts/build-release-asset.sh dist/kernels-x86_64
```

Useful environment variables:

- `SPOREVM_KERNEL_VERSION`, default `6.1.155`
- `SPOREVM_KERNEL_ARCH`, `arm64` by default; also supports `x86_64`
- `SPOREVM_KERNEL_DOCKER_IMAGE`, default `ubuntu:22.04`
- `SPOREVM_KERNEL_DOCKER_PLATFORM`, default `linux/amd64`
- `SPOREVM_KERNEL_CROSS_COMPILE`, default `aarch64-linux-gnu-` when needed
- `SPOREVM_KERNEL_TARBALL_SHA256`
- `SPOREVM_KERNEL_BUILD_DIR`, optional host cache directory mounted at `/build`
- `SPOREVM_KERNELS_GITHUB_REPOSITORY`, default `sporevm/kernels`
- `SPOREVM_KERNELS_GITHUB_RELEASE_TOKEN`, used by tagged release publishing

## CI

Buildkite builds both architectures on hosted agents. Tagged builds then
publish the assets and `dist/kernels.tar.gz` to the matching GitHub Release.
