#!/usr/bin/env bash
# serve-filmcraft-web.sh: run the browser version of FilmCraft on this Mac and open it in Chrome.
#
#   ./serve-filmcraft-web.sh                 # download the latest release's web build (once), serve it, open Chrome
#   ./serve-filmcraft-web.sh --port 9000     # another port (default 8765)
#   ./serve-filmcraft-web.sh --no-open       # serve only, don't open a browser
#   ./serve-filmcraft-web.sh --update        # re-download even if this version is already unpacked
#
# The web build is a static site (index.html + wasm) from the GitHub release asset
# filmcraft-web-<version>.zip. It is unpacked under ~/FilmCraft-Web/ and served with Python's
# built-in HTTP server on http://localhost:<port>/ (localhost counts as a secure context, so
# WebGPU works). Nothing is uploaded anywhere; media stay in the browser. Stop with Ctrl+C.
set -euo pipefail

REPO="storytold/filmcraft"
ROOT="$HOME/FilmCraft-Web"
PORT=8765
OPEN=1
UPDATE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --port) PORT="$2"; shift 2 ;;
    --no-open) OPEN=0; shift ;;
    --update) UPDATE=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
command -v curl >/dev/null || die "curl is missing"
command -v python3 >/dev/null || die "python3 is missing (install the Xcode Command Line Tools)"

say "Looking up the latest release of $REPO"
TAG=""
LATEST_URL="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null || true)"
case "$LATEST_URL" in */releases/tag/*) TAG="${LATEST_URL##*/releases/tag/}" ;; esac
if [ -z "$TAG" ]; then
  RELEASE_JSON="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null || true)"
  TAG="$(printf '%s\n' "$RELEASE_JSON" | grep '"tag_name"' | head -1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
fi
[ -n "$TAG" ] || die "could not find the latest release tag on GitHub (network?)"
VER="${TAG#v}"
SITE="$ROOT/filmcraft-web-$VER"
echo "latest release: $VER"

if [ "$UPDATE" = 1 ] || [ ! -f "$SITE/index.html" ]; then
  ZIP="filmcraft-web-$VER.zip"
  BASE="https://github.com/$REPO/releases/download/$TAG"
  TMP="$(mktemp -d /tmp/filmcraft-web.XXXXXX)"
  trap 'rm -rf "$TMP"' EXIT
  say "Downloading $ZIP"
  curl -fL --progress-bar -o "$TMP/SHA256SUMS.txt" "$BASE/SHA256SUMS.txt"
  curl -fL --progress-bar -o "$TMP/$ZIP" "$BASE/$ZIP"
  expected="$(grep -E "[ *]$ZIP\$" "$TMP/SHA256SUMS.txt" | awk '{print $1}' | head -1)"
  actual="$(shasum -a 256 "$TMP/$ZIP" | awk '{print $1}')"
  [ -n "$expected" ] || die "SHA256SUMS.txt has no entry for $ZIP"
  [ "$expected" = "$actual" ] || die "checksum mismatch for $ZIP (download corrupted?)"
  echo "checksum ok"
  mkdir -p "$ROOT"
  rm -rf "$SITE"
  unzip -q -o "$TMP/$ZIP" -d "$ROOT"
  [ -f "$SITE/index.html" ] || die "the zip did not contain filmcraft-web-$VER/index.html"
else
  echo "already unpacked: $SITE (use --update to re-download)"
fi

URL="http://localhost:$PORT/"
say "Serving $SITE on $URL (Ctrl+C stops it)"
if [ "$OPEN" = 1 ]; then
  # Give the server a moment to start, then open the page in the default browser (or Chrome).
  ( sleep 1; open -a "Google Chrome" "$URL" 2>/dev/null || open "$URL" ) &
fi
cd "$SITE"
exec python3 -m http.server "$PORT" --bind 127.0.0.1
