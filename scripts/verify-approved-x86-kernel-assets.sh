#!/usr/bin/env bash
set -euo pipefail

die() {
  printf '[verify-approved-x86-kernel-assets] error: %s\n' "$*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ASSET_DIR="${1:-${REPO_ROOT}/approved/x86_64/6.1.155}"

command -v python3 >/dev/null 2>&1 || die "missing required command: python3"

ASSET_DIR="${ASSET_DIR}" python3 - <<'PY' || die "approved x86_64 asset verification failed"
import hashlib
import json
import os
import pathlib
import sys

asset_dir = pathlib.Path(os.environ["ASSET_DIR"])
expected_hashes = {
    "sporevm-x86_64-linux-6.1.155-bzImage": "07a9b6d8a9efd2b7c5e886d1c010e67245fa132c8b48cf567f200099b55abee8",
    "sporevm-x86_64-linux-6.1.155-bzImage.config": "d67ef9eb0cfee797d1edb09027214b312361139db2621d483edfe0debd13e95e",
    "sporevm-x86_64-linux-6.1.155-bzImage.sha256": "c7ad2f454aa7a56cdf19f7199748c3aaea8472f0994499c03081eb6b4239f243",
    "sporevm-x86_64-linux-6.1.155.manifest.json": "d26c201232657e3e95801395b6b1818cead3d574b6cbe2fb2a77e117c8e7a713",
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

image_name = "sporevm-x86_64-linux-6.1.155-bzImage"
image_sha256 = expected_hashes[image_name]
checksum_path = asset_dir / f"{image_name}.sha256"
manifest_path = asset_dir / "sporevm-x86_64-linux-6.1.155.manifest.json"

if checksum_path.read_text() != f"{image_sha256}  {image_name}\n":
    print(f"{checksum_path} does not contain the approved image checksum", file=sys.stderr)
    raise SystemExit(1)

manifest = json.loads(manifest_path.read_text())
if manifest.get("arch") != "x86_64" or manifest.get("linux_version") != "6.1.155":
    print(f"{manifest_path} does not describe the approved x86_64 Linux 6.1.155 kernel", file=sys.stderr)
    raise SystemExit(1)
if manifest.get("sha256") != image_sha256:
    print(f"{manifest_path} does not contain the approved image checksum", file=sys.stderr)
    raise SystemExit(1)
PY

printf '[verify-approved-x86-kernel-assets] verified %s\n' "${ASSET_DIR}"
