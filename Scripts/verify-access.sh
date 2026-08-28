#!/usr/bin/env bash
#
# Checks that this machine can fetch the private binary the manifest points at.
#
# SPM reports a failed binary download as a checksum or "invalid archive" error, which
# points nowhere near the real cause — missing credentials. Run this first.
#
#   Scripts/verify-access.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Read the URL the manifest actually resolves to, rather than reconstructing it here and
# risking the two drifting apart.
URL="$(swift package --package-path "$ROOT" dump-package \
        | /usr/bin/python3 -c 'import json,sys; print(next(t["url"] for t in json.load(sys.stdin)["targets"] if t["type"]=="binary"))')"

echo "Binary target:"
echo "  $URL"
echo

if [[ ! -f "$HOME/.netrc" ]]; then
  cat >&2 <<'MISSING'
error: ~/.netrc not found.

  SPM sends no Xcode credentials when downloading a binary target, so a private
  release asset needs a .netrc entry:

      machine github.com
        login <your-github-username>
        password <a PAT with 'repo' scope>

  Then:  chmod 600 ~/.netrc
  A PAT is created at https://github.com/settings/tokens
MISSING
  exit 1
fi

perms="$(stat -f '%Lp' "$HOME/.netrc")"
if [[ "$perms" != "600" ]]; then
  echo "warning: ~/.netrc is mode $perms; it holds a token. Run: chmod 600 ~/.netrc" >&2
fi

if ! grep -q 'machine[[:space:]]\+github\.com' "$HOME/.netrc"; then
  echo "error: ~/.netrc has no 'machine github.com' entry." >&2
  exit 1
fi

# --netrc so curl authenticates exactly the way SPM will; -L because GitHub redirects a
# private asset to a pre-signed URL on another host.
code="$(curl -sS -L --netrc -o /dev/null -w '%{http_code}' -r 0-0 "$URL" || true)"

case "$code" in
  200|206) echo "✅ Reachable — SPM can fetch this binary." ;;
  401|403) echo "❌ $code: credentials rejected. Check the PAT's scope and expiry." >&2; exit 1 ;;
  404)     echo "❌ 404: no such asset. Has the release been cut and the zip uploaded?" >&2; exit 1 ;;
  *)       echo "❌ Unexpected HTTP $code." >&2; exit 1 ;;
esac
