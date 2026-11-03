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
    "sporevm-x86_64-linux-6.1.191-bzImage": "13ca22ff42b795c33365c89fad3e7d5bbf0a972cdaedc7f70f2f78270ee7bb82",
    "sporevm-x86_64-linux-6.1.191-bzImage.config": "a2a34bd5044125f9fb21e2f2079fe68ab2ad5e01758b4d4f37be450c88489a76",
    "sporevm-x86_64-linux-6.1.191-bzImage.sha256": "7ac2bb6df9c45897c1c6ff1d74e41e4e7c391e43f9dea751ff25e1025e8b5ac9",
    "sporevm-x86_64-linux-6.1.191.manifest.json": "5fd5ad9848ba109ece6691de28d6ffd1277a767511d30ef7807948b1e8bfc0be",
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
