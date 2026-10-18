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
TAG="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"
[ -n "$TAG" ] || die "could not read the latest release tag from GitHub"
VER="${TAG#v}"

INSTALLED="none"
if command -v filmcraft-cli >/dev/null 2>&1; then
  INSTALLED="$(filmcraft-cli --version 2>/dev/null | awk '{print $2}')"
fi
APP_INSTALLED="no"
[ -d "$APP_DIR/FilmCraft.app" ] && APP_INSTALLED="yes"

echo "latest release:     $VER"
echo "installed CLI:      $INSTALLED"
echo "installed app:      $APP_INSTALLED ($APP_DIR/FilmCraft.app)"

if [ "$MODE" = "--check" ]; then
  exit 0
fi
if [ "$MODE" != "--force" ] && [ "$INSTALLED" = "$VER" ] && [ "$APP_INSTALLED" = "yes" ]; then
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
rm -rf "$APP_DIR/FilmCraft.app"
cp -R "$MNT/FilmCraft.app" "$APP_DIR/"
hdiutil detach "$MNT" -quiet || hdiutil detach "$MNT" -force -quiet || true

say "Installing filmcraft-cli into $CLI_DIR (sudo may ask for your password)"
unzip -q -o "$CLI_ZIP"
sudo install -m 755 "filmcraft-cli-$VER-macos-universal/filmcraft-cli" "$CLI_DIR/filmcraft-cli"

say "Done"
echo "app: $APP_DIR/FilmCraft.app"
echo "cli: $("$CLI_DIR/filmcraft-cli" --version)"
