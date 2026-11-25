#!/bin/bash
# Builds an UNSIGNED CLMRS.ipa (sign it afterwards with KSign). Needs Xcode (macOS).
set -euo pipefail
cd "$(dirname "$0")"
OUT=build
APP="$OUT/Payload/CLMRS.app"
rm -rf "$OUT"
mkdir -p "$APP"

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
xcrun --sdk iphoneos swiftc -parse-as-library -O \
  -target arm64-apple-ios15.0 -sdk "$SDK" \
  Sources/CLMRS.swift -o "$APP/CLMRS"

cp Info.plist "$APP/Info.plist"
cp Icons/*.png "$APP/"
printf 'APPL????' > "$APP/PkgInfo"

(cd "$OUT" && zip -qry CLMRS.ipa Payload)
echo "Built: $OUT/CLMRS.ipa"
