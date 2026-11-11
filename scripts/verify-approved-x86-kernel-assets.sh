#!/usr/bin/env bash
set -euo pipefail

die() {
  printf '[verify-approved-x86-kernel-assets] error: %s\n' "$*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ASSET_DIR="${1:-${REPO_ROOT}/approved/x86_64/6.1.191}"

command -v python3 >/dev/null 2>&1 || die "missing required command: python3"

ASSET_DIR="${ASSET_DIR}" python3 - <<'PY' || die "approved x86_64 asset verification failed"
import hashlib
import json
import os
import pathlib
import sys

asset_dir = pathlib.Path(os.environ["ASSET_DIR"])
expected_hashes = {
    "sporevm-x86_64-linux-6.1.191-bzImage": "fdb9746e3fbf060097696f7b92c5f33a991d9a80f02aacec0ca389f3705d5373",
    "sporevm-x86_64-linux-6.1.191-bzImage.config": "ec496d32864129cadce7f0b36153d72a4d19a973acae80b17efcec0776cca002",
    "sporevm-x86_64-linux-6.1.191-bzImage.sha256": "1a570fd2c39d9fb510ad967207cbfbef600c7fc3e92b7568a587fd0d91528ca9",
    "sporevm-x86_64-linux-6.1.191.manifest.json": "9e0051376dffe47f9481d0cbffae79967789b0677f567dd8d4bfebb1b1356d49",
}

for name, expected in expected_hashes.items():
    path = asset_dir / name
    if not path.is_file() or path.is_symlink():
        print(f"missing regular approved asset: {path}", file=sys.stderr)
        raise SystemExit(1)
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != expected:
        print(f"{path} SHA-256 is {actual}; expected {expected}", file=sys.stderr)
        raise SystemExit(1)

image_name = "sporevm-x86_64-linux-6.1.191-bzImage"
image_sha256 = expected_hashes[image_name]
checksum_path = asset_dir / f"{image_name}.sha256"
manifest_path = asset_dir / "sporevm-x86_64-linux-6.1.191.manifest.json"

if checksum_path.read_text() != f"{image_sha256}  {image_name}\n":
    print(f"{checksum_path} does not contain the approved image checksum", file=sys.stderr)
    raise SystemExit(1)

manifest = json.loads(manifest_path.read_text())
if manifest.get("arch") != "x86_64" or manifest.get("linux_version") != "6.1.191":
    print(f"{manifest_path} does not describe the approved x86_64 Linux 6.1.191 kernel", file=sys.stderr)
    raise SystemExit(1)
if manifest.get("sha256") != image_sha256:
    print(f"{manifest_path} does not contain the approved image checksum", file=sys.stderr)
    raise SystemExit(1)
PY

printf '[verify-approved-x86-kernel-assets] verified %s\n' "${ASSET_DIR}"
