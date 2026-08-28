#!/usr/bin/env bash
#
# Cuts a Wallet SDK Swift Package release.
#
# Computes the SPM checksum of an XCFramework zip already published by the Wallet-SDK
# pipeline, rewrites Package.swift, and prints the git commands to tag it. Nothing is
# pushed and no release is created — this script only prepares the working tree.
#
#   # against the published release asset (normal path)
#   Scripts/release.sh 0.1.0-RC20
#
#   # against a locally built zip, before the pipeline has published it
#   Scripts/release.sh 0.1.0-RC20 /path/to/WalletSDK-0.1.0-RC20.xcframework.zip
#
set -euo pipefail

VERSION="${1:?usage: release.sh <version> [local-zip]}"
LOCAL_ZIP="${2:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ASSET="WalletSDK-${VERSION}.xcframework.zip"
URL="https://github.com/CredenceID/Wallet-SDK/releases/download/${VERSION}/${ASSET}"

if [[ -n "$LOCAL_ZIP" ]]; then
  [[ -f "$LOCAL_ZIP" ]] || { echo "error: no such file: $LOCAL_ZIP" >&2; exit 1; }
  ZIP="$LOCAL_ZIP"
  echo "==> Using local artifact: $ZIP"
else
  # Checksum the exact bytes a consumer will receive, not a local rebuild — a rebuild is
  # not bit-identical, and a mismatched checksum fails at resolution time for everyone.
  ZIP="$(mktemp -d)/$ASSET"
  echo "==> Downloading $ASSET"
  curl -fsSL --netrc -o "$ZIP" "$URL" || {
    echo "error: download failed. Run Scripts/verify-access.sh to diagnose." >&2
    exit 1
  }
fi

SUM="$(swift package compute-checksum "$ZIP")"
printf '    %-42s %s\n' "$ASSET" "$SUM"

/usr/bin/python3 - "$ROOT/Package.swift" "$VERSION" "$SUM" <<'PY'
import re, sys
path, version, checksum = sys.argv[1:]
text = open(path).read()
text = re.sub(r'(let release\s+= )"[^"]*"',  lambda m: f'{m.group(1)}"{version}"',  text, count=1)
text = re.sub(r'(let checksum\s+= )"[0-9a-f]{64}"', lambda m: f'{m.group(1)}"{checksum}"', text, count=1)
open(path, "w").write(text)
PY

swift package --package-path "$ROOT" dump-package > /dev/null
echo "    Package.swift -> $VERSION, manifest still valid"

cat <<NEXT

Prepared $VERSION. Nothing has been pushed.

  1. Review:  git -C "$ROOT" diff Package.swift
  2. Commit:  git -C "$ROOT" commit -am "Release $VERSION"
  3. Tag:     git -C "$ROOT" tag $VERSION
  4. Push:    git -C "$ROOT" push origin main --tags

The tag is what SPM resolves, so it must match the Wallet-SDK release tag exactly.
Consumers pin it with:  .package(url: ..., exact: "$VERSION")
NEXT
