#!/bin/bash
set -e

cd "$(dirname "$0")/.."

SCHEME="minimax-status-bar"
CONFIG="Release"
EXPORT_PLIST="scripts/ExportOptions.plist"
ARTIFACTS_DIR="build"
APP_NAME="MiniMax Status Bar"
APP_FILENAME="${APP_NAME}.app"
DMG_FILENAME="${ARTIFACTS_DIR}/MiniMaxStatusBar.dmg"
STAGING_DIR="${ARTIFACTS_DIR}/dmg-staging"

# Clean previous artifacts
rm -rf "${ARTIFACTS_DIR}"
mkdir -p "${ARTIFACTS_DIR}"

# Step 1: Archive (disabled code signing)
xcodebuild archive \
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

# Step 3: Package into .dmg
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

# Copy .app to staging
cp -R "${ARTIFACTS_DIR}/${APP_FILENAME}" "${STAGING_DIR}/"

# Symlink /Applications
ln -s /Applications "${STAGING_DIR}/Applications"

# Create .dmg
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -format UDZO \
    -ov \
    "${DMG_FILENAME}"

# Cleanup staging
rm -rf "${STAGING_DIR}"

echo "Build complete: ${DMG_FILENAME}"
