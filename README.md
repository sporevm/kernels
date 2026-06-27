# SporeVM Kernels

Build and publish Linux kernel release assets for SporeVM.

## Assets

This repository publishes:

- `sporevm-arm64-linux-<version>-Image`
- `sporevm-arm64-linux-<version>-Image.config`
- `sporevm-arm64-linux-<version>-Image.sha256`
- `sporevm-arm64-linux-<version>.manifest.json`
- `sporevm-run-arm64-linux-<version>-Image`
- `sporevm-run-arm64-linux-<version>-Image.config`
- `sporevm-run-arm64-linux-<version>-Image.sha256`
- `sporevm-run-arm64-linux-<version>.manifest.json`

The legacy `sporevm` kernel enables `/dev/mem` for the diskless fork smoke
helper. The `sporevm-run` kernel disables `/dev/mem` and includes the initrd,
rootfs, Docker, cgroup, namespace, networking, and filesystem support needed by
`spore run`.

## Build

Build one asset locally:

```sh
scripts/build-release-asset.sh sporevm dist/kernels
scripts/build-release-asset.sh sporevm-run dist/kernels
```

Useful environment variables:

- `SPOREVM_KERNEL_VERSION`, default `6.1.155`
- `SPOREVM_KERNEL_ARCH`, default `arm64`
- `SPOREVM_KERNEL_DOCKER_IMAGE`, default `ubuntu:22.04`
- `SPOREVM_KERNEL_DOCKER_PLATFORM`, default `linux/amd64`
- `SPOREVM_KERNEL_CROSS_COMPILE`, default `aarch64-linux-gnu-` when needed
- `SPOREVM_KERNEL_TARBALL_SHA256`
- `SPOREVM_KERNEL_BUILD_DIR`, optional host cache directory mounted at `/build`
- `SPOREVM_KERNELS_GITHUB_REPOSITORY`, default `buildkite/sporevm-kernels`
- `SPOREVM_KERNELS_GITHUB_RELEASE_TOKEN`, used by tagged release publishing

## CI

Buildkite builds `sporevm` and `sporevm-run` in parallel on hosted agents. Each
step uploads its own release assets. Tagged builds then publish those assets and
`dist/kernels.tar.gz` to the matching GitHub Release.
