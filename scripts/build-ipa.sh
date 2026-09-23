#!/bin/bash
# Build a device IPA for a sideloading tool to sign. Run with Xcode selected.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build-ipa"
ARCHIVE="$BUILD_DIR/TCFCanada.xcarchive"
STAGING="$BUILD_DIR/staging"
OUTPUT="$ROOT/dist/TCFCanada-QuestionBank.ipa"

python3 "$ROOT/scripts/check-cloud.py"

xcodebuild \
  -project "$ROOT/apptsst.xcodeproj" \
  -scheme apptsst \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  SUPPORTED_PLATFORMS=iphoneos \
  TARGETED_DEVICE_FAMILY=1,2 \
  CURRENT_PROJECT_VERSION=6 \
  clean archive

python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)' "$STAGING"
mkdir -p "$STAGING/Payload" "$ROOT/dist"
ditto "$ARCHIVE/Products/Applications/apptsst.app" "$STAGING/Payload/TCFCanada.app"
ditto -c -k --keepParent "$STAGING/Payload" "$OUTPUT"
python3 "$ROOT/scripts/verify-ipa.py" "$OUTPUT"
