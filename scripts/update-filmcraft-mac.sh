#!/usr/bin/env bash
# update-filmcraft-mac.sh: install or update FilmCraft (the app and filmcraft-cli) on macOS
# from the latest GitHub release of storytold/filmcraft.
#
#   ./update-filmcraft-mac.sh            # update when a newer release exists
#   ./update-filmcraft-mac.sh --force    # reinstall the latest release even if already installed
#   ./update-filmcraft-mac.sh --check    # only report the installed and latest versions
#
# What it does: asks GitHub for the latest release tag, downloads the universal DMG and the CLI
# zip, verifies both against the release's SHA256SUMS.txt, quits FilmCraft if it is running,
# replaces /Applications/FilmCraft.app, and installs filmcraft-cli into /usr/local/bin (sudo asks
# for your password once). Nothing else on the machine is touched.
#
# macOS 13+ note: replacing an app that is already in /Applications from a terminal needs the
# "App Management" permission for the terminal app (System Settings > Privacy & Security >
# App Management). Without it the script stops with "Operation not permitted" and says so.
set -euo pipefail

REPO="storytold/filmcraft"
APP_DIR="/Applications"
CLI_DIR="/usr/local/bin"
MODE="${1:-}"

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || die "this script is for macOS"
command -v curl >/dev/null || die "curl is missing"

say "Looking up the latest release of $REPO"
# github.com/<repo>/releases/latest redirects to /releases/tag/<tag>; that needs no API token and
# has no rate limit. The API is the fallback. (Read replies into variables: `curl | grep -m1`
# makes grep close the pipe early, curl then exits 56, and pipefail turns that into a failure.)
TAG=""
LATEST_URL="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null || true)"
case "$LATEST_URL" in
  */releases/tag/*) TAG="${LATEST_URL##*/releases/tag/}" ;;
esac
if [ -z "$TAG" ]; then
  RELEASE_JSON="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null || true)"
  TAG="$(printf '%s\n' "$RELEASE_JSON" | grep '"tag_name"' | head -1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
fi
if [ -z "$TAG" ]; then
  # Last resort: the first "releases/tag/v…" link on the latest-release page.
  PAGE="$(curl -fsSL "https://github.com/$REPO/releases/latest" 2>/dev/null || true)"
  TAG="$(printf '%s\n' "$PAGE" | grep -o 'releases/tag/v[0-9][0-9.]*' | head -1 | sed 's|releases/tag/||')"
fi
[ -n "$TAG" ] || die "could not find the latest release tag on GitHub (network?)"
VER="${TAG#v}"

CLI_VER="none"
if command -v filmcraft-cli >/dev/null 2>&1; then
  CLI_VER="$(filmcraft-cli --version 2>/dev/null | awk '{print $2}')"
fi
APP_VER="none"
if [ -d "$APP_DIR/FilmCraft.app" ]; then
  APP_VER="$(defaults read "$APP_DIR/FilmCraft.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")"
fi

echo "latest release:     $VER"
echo "installed app:      $APP_VER ($APP_DIR/FilmCraft.app)"
echo "installed CLI:      $CLI_VER ($CLI_DIR/filmcraft-cli)"

if [ "$MODE" = "--check" ]; then
  exit 0
fi
if [ "$MODE" != "--force" ] && [ "$CLI_VER" = "$VER" ] && [ "$APP_VER" = "$VER" ]; then
  echo "already up to date; run with --force to reinstall"
  exit 0
fi

DMG="filmcraft-$VER-macos-universal.dmg"
CLI_ZIP="filmcraft-cli-$VER-macos-universal.zip"
BASE="https://github.com/$REPO/releases/download/$TAG"
TMP="$(mktemp -d /tmp/filmcraft-update.XXXXXX)"
trap 'cd /; rm -rf "$TMP"' EXIT
cd "$TMP"

say "Downloading $DMG and $CLI_ZIP"
curl -fL --progress-bar -o SHA256SUMS.txt "$BASE/SHA256SUMS.txt"
curl -fL --progress-bar -o "$DMG" "$BASE/$DMG"
curl -fL --progress-bar -o "$CLI_ZIP" "$BASE/$CLI_ZIP"

say "Verifying checksums"
verify() {
  local file="$1" expected actual
  expected="$(grep -E "[ *]$file\$" SHA256SUMS.txt | awk '{print $1}' | head -1)"
  actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  [ -n "$expected" ] || die "SHA256SUMS.txt has no entry for $file"
  [ "$expected" = "$actual" ] || die "checksum mismatch for $file (download corrupted?)"
  echo "ok: $file"
}
verify "$DMG"
verify "$CLI_ZIP"

say "Installing FilmCraft.app into $APP_DIR"
osascript -e 'tell application "FilmCraft" to quit' >/dev/null 2>&1 || true
sleep 1
MNT="$(hdiutil attach -nobrowse -readonly -noverify "$DMG" | awk -F'\t' '/\/Volumes\//{print $NF}' | tail -1)"
[ -n "$MNT" ] && [ -d "$MNT/FilmCraft.app" ] || die "could not mount the DMG or find FilmCraft.app in it"
# Replacing an existing signed app from a terminal needs macOS 13+'s "App Management" permission
# for the terminal app; without it, even sudo gets "Operation not permitted".
if [ -e "$APP_DIR/FilmCraft.app" ]; then
  rm -rf "$APP_DIR/FilmCraft.app" 2>/dev/null || sudo rm -rf "$APP_DIR/FilmCraft.app" 2>/dev/null || {
    hdiutil detach "$MNT" -quiet || true
    die "cannot replace $APP_DIR/FilmCraft.app (Operation not permitted).
  Fix once: System Settings > Privacy & Security > App Management > enable your terminal app
  (Terminal or iTerm), then run this script again. Or install by hand: open the DMG in Finder
  and drag FilmCraft into Applications, choosing Replace."
  }
fi
ditto "$MNT/FilmCraft.app" "$APP_DIR/FilmCraft.app" 2>/dev/null || sudo ditto "$MNT/FilmCraft.app" "$APP_DIR/FilmCraft.app"
hdiutil detach "$MNT" -quiet || hdiutil detach "$MNT" -force -quiet || true

say "Installing filmcraft-cli into $CLI_DIR (sudo may ask for your password)"
unzip -q -o "$CLI_ZIP"
sudo install -m 755 "filmcraft-cli-$VER-macos-universal/filmcraft-cli" "$CLI_DIR/filmcraft-cli"

say "Done"
echo "app: $APP_DIR/FilmCraft.app"
echo "cli: $("$CLI_DIR/filmcraft-cli" --version)"
