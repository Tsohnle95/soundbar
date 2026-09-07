#!/bin/zsh
# Builds the double-clickable Soundbar.app from the SPM release binary.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> swift build -c release"
swift build -c release

echo "==> packaging Soundbar.app"
rm -rf Soundbar.app
mkdir -p Soundbar.app/Contents/MacOS Soundbar.app/Contents/Resources
cp .build/arm64-apple-macosx/release/Soundbar Soundbar.app/Contents/MacOS/Soundbar
chmod +x Soundbar.app/Contents/MacOS/Soundbar
printf 'APPL????' > Soundbar.app/Contents/PkgInfo

/usr/bin/codesign --force --deep --sign - Soundbar.app
echo "==> done: ./Soundbar.app"
echo "    Copy to /Applications:  cp -R Soundbar.app /Applications/"
echo "    Launch at login: System Settings > General > Login Items > + > Soundbar"
