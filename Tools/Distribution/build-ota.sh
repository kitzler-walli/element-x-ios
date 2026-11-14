#!/bin/bash
# Builds a Release Testing (Ad Hoc) .ipa of the iPhone app with its extensions and the Apple Watch app, and
# prepares the over-the-air install folder (ipa, manifest.plist, index.html, icons) for upload to the web server.
# Same setup as kwMail's App/distribution/build-ota.sh.
#
# Usage: Tools/Distribution/build-ota.sh [output dir]   (default: build/ota in the project, which ./deploy.sh publishes)
# Bump CURRENT_PROJECT_VERSION in project.yml before each build, so installed devices see an update.
# Only devices registered in the Apple Developer account (team XM4N953GC3) can install it, the watch included.
set -euo pipefail

BASE_URL="https://cdn.kw.at/elementx"
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
OUT="${1:-$ROOT/build/ota}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cd "$ROOT"
xcodegen --quiet

SETTINGS=$(xcodebuild -project ElementX.xcodeproj -scheme ElementX -configuration Release -destination "generic/platform=iOS" -showBuildSettings 2>/dev/null)
VERSION=$(awk -F' = ' '/^ *MARKETING_VERSION = /{print $2; exit}' <<<"$SETTINGS")
BUILD=$(awk -F' = ' '/^ *CURRENT_PROJECT_VERSION = /{print $2; exit}' <<<"$SETTINGS")
echo "Building Element X $VERSION ($BUILD) for iPhone and Apple Watch"

# The local MatrixRustSDK build only has arm64 slices. Set here, not per target, so the packages built for the
# watch drop arm64_32 too. Every iPhone it can install on is arm64 anyway.
xcodebuild archive -project ElementX.xcodeproj -scheme ElementX -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$WORK/ElementX.xcarchive" \
  ARCHS=arm64 -allowProvisioningUpdates -quiet

xcodebuild -exportArchive -archivePath "$WORK/ElementX.xcarchive" -exportPath "$WORK/export" \
  -exportOptionsPlist "$HERE/ExportOptions-AdHoc.plist" -allowProvisioningUpdates -quiet

IPA=$(ls "$WORK"/export/*.ipa | head -1)
# The extensions and the watch app are separate bundles; without them the app installs but they're silently missing.
CONTENTS=$(unzip -l "$IPA")
for bundle in PlugIns/NSE.appex PlugIns/ShareExtension.appex Watch/Watch.app; do
  [[ "$CONTENTS" == *"ElementX.app/$bundle/Info.plist"* ]] || { echo "error: $bundle missing from ipa" >&2; exit 1; }
done

mkdir -p "$OUT"
cp "$IPA" "$OUT/ElementX.ipa"
for file in manifest.plist index.html; do
  sed -e "s#__BASE_URL__#$BASE_URL#g" -e "s#__VERSION__#$VERSION#g" -e "s#__BUILD__#$BUILD#g" "$HERE/ota/$file.template" > "$OUT/$file"
done
ICON="$ROOT/ElementX/Resources/AppIcon.icon/Assets/AppIcon.png"
sips -z 512 512 "$ICON" --out "$OUT/icon-512.png" >/dev/null
sips -z 120 120 "$ICON" --out "$OUT/icon-120.png" >/dev/null

echo "Ready to upload to $BASE_URL:"
ls -lh "$OUT"
