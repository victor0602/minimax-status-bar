#!/bin/bash
set -e

cd "$(dirname "$0")/.."

# Regenerate Xcode project from XcodeGen
xcodegen generate

SCHEME="minimax-status-bar"
CONFIG="Release"
EXPORT_PLIST="scripts/ExportOptions.plist"
ARTIFACTS_DIR="build"
APP_NAME="MiniMax Status Bar"
APP_FILENAME="${APP_NAME}.app"
DMG_FILENAME="${ARTIFACTS_DIR}/MiniMaxStatusBar-v3.0.0.dmg"
STAGING_DIR="${ARTIFACTS_DIR}/dmg-staging"

# Clean previous artifacts
rm -rf "${ARTIFACTS_DIR}"
mkdir -p "${ARTIFACTS_DIR}"
mkdir -p "${STAGING_DIR}"

# Step 1: Archive (disabled code signing)
xcodebuild archive \
    -project minimax-status-bar.xcodeproj \
    -scheme "${SCHEME}" \
    -configuration "${CONFIG}" \
    -archivePath "${ARTIFACTS_DIR}/${SCHEME}.xcarchive" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Step 2: Export .app from archive
xcodebuild -exportArchive \
    -archivePath "${ARTIFACTS_DIR}/${SCHEME}.xcarchive" \
    -exportPath "${ARTIFACTS_DIR}" \
    -exportOptionsPlist "${EXPORT_PLIST}"

# Step 3: Generate .icns from AppIcon assets
ICNS_TMP=$(mktemp -d)
ICNSET="${ICNS_TMP}/AppIcon.iconset"
mkdir -p "${ICNSET}"

ICONSET="Resources/Assets.xcassets/AppIcon.appiconset"

cp "${ICONSET}/icon_16.png"  "${ICNSET}/icon_16x16.png"
cp "${ICONSET}/icon_32.png"  "${ICNSET}/icon_32x32.png"
cp "${ICONSET}/icon_64.png"  "${ICNSET}/icon_64x64.png"
cp "${ICONSET}/icon_128.png" "${ICNSET}/icon_128x128.png"
cp "${ICONSET}/icon_256.png" "${ICNSET}/icon_256x256.png"
cp "${ICONSET}/icon_512.png" "${ICNSET}/icon_512x512.png"

# @2x versions (pixel-doubled)
cp "${ICONSET}/icon_32.png"  "${ICNSET}/icon_16x16@2x.png"
cp "${ICONSET}/icon_64.png"  "${ICNSET}/icon_32x32@2x.png"
cp "${ICONSET}/icon_128.png" "${ICNSET}/icon_64x64@2x.png"
cp "${ICONSET}/icon_256.png" "${ICNSET}/icon_128x128@2x.png"
cp "${ICONSET}/icon_512.png" "${ICNSET}/icon_256x256@2x.png"

iconutil -c icns "${ICNSET}" -o "${ARTIFACTS_DIR}/${APP_FILENAME}/Contents/Resources/AppIcon.icns"
rm -rf "${ICNS_TMP}"

# Step 4: Update Info.plist with icon reference
/usr/libexec/PlistBuddy \
    -c "Add :CFBundleIconFile string AppIcon.icns" \
    "${ARTIFACTS_DIR}/${APP_FILENAME}/Contents/Info.plist"

# Step 5: Copy .app to staging
cp -R "${ARTIFACTS_DIR}/${APP_FILENAME}" "${STAGING_DIR}/"

# Step 6: Ad-hoc codesign
codesign --force --deep --sign - \
    --options runtime \
    "${STAGING_DIR}/${APP_FILENAME}"

# Step 7: Create symlink to Applications
ln -sf /Applications "${STAGING_DIR}/Applications"

# Step 8: Package into .dmg
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -format UDZO \
    -ov "${DMG_FILENAME}"

# Cleanup staging
rm -rf "${STAGING_DIR}"

echo "Build complete: ${DMG_FILENAME}"
