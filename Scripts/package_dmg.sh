#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="WallhavenMac"
PROJECT_FILE="${ROOT_DIR}/project.yml"
source "${ROOT_DIR}/Scripts/versioning.sh"

if [[ -n "${VERSION:-}" ]]; then
    APP_VERSION="${VERSION}"
else
    APP_VERSION="$(bump_patch_version "${PROJECT_FILE}")"
fi

VOLUME_NAME="${APP_NAME} ${APP_VERSION}"

BUILD_DIR="${ROOT_DIR}/build/package"
DERIVED_DATA_DIR="${BUILD_DIR}/DerivedData"
STAGE_DIR="${BUILD_DIR}/dmg-root"
MOUNT_DIR="${BUILD_DIR}/dmg-mount"
DIST_DIR="${ROOT_DIR}/dist"

APP_PATH="${DERIVED_DATA_DIR}/Build/Products/Release/${APP_NAME}.app"
DMG_PATH="${DIST_DIR}/${APP_NAME}-${APP_VERSION}.dmg"
TEMP_DMG_PATH="${DIST_DIR}/${APP_NAME}-${APP_VERSION}.tmp.dmg"
MOUNT_DEVICE=""

cleanup() {
    if [[ -n "${MOUNT_DEVICE}" ]]; then
        hdiutil detach "${MOUNT_DEVICE}" -quiet || true
    fi
    rm -rf "${MOUNT_DIR}" "${STAGE_DIR}" "${TEMP_DMG_PATH}"
}
trap cleanup EXIT

cd "${ROOT_DIR}"

echo "Generating Xcode project..."
xcodegen generate

echo "Building ${APP_NAME} Release..."
xcodebuild \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -derivedDataPath "${DERIVED_DATA_DIR}" \
    -destination "platform=macOS" \
    -quiet \
    build

if [[ ! -d "${APP_PATH}" ]]; then
    echo "error: missing app bundle at ${APP_PATH}" >&2
    exit 1
fi

echo "Preparing DMG staging folder..."
rm -rf "${STAGE_DIR}" "${MOUNT_DIR}" "${TEMP_DMG_PATH}" "${DMG_PATH}"
mkdir -p "${STAGE_DIR}" "${MOUNT_DIR}" "${DIST_DIR}"
ditto "${APP_PATH}" "${STAGE_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGE_DIR}/Applications"

echo "Creating read-write DMG..."
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGE_DIR}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size 220m \
    "${TEMP_DMG_PATH}"

echo "Arranging DMG window..."
MOUNT_DEVICE="$(
    hdiutil attach "${TEMP_DMG_PATH}" \
        -mountpoint "${MOUNT_DIR}" \
        -nobrowse \
        -noverify \
        -noautoopen | awk '/Apple_HFS/ { print $1; exit }'
)"

sleep 1

osascript >/dev/null 2>/dev/null <<APPLESCRIPT || true
set dmgFolder to POSIX file "${MOUNT_DIR}" as alias
tell application "Finder"
    open dmgFolder
    set current view of container window of dmgFolder to icon view
    set toolbar visible of container window of dmgFolder to false
    set statusbar visible of container window of dmgFolder to false
    set bounds of container window of dmgFolder to {100, 100, 660, 420}
    set arrangement of icon view options of container window of dmgFolder to not arranged
    set icon size of icon view options of container window of dmgFolder to 96
    set position of item "${APP_NAME}.app" of dmgFolder to {160, 160}
    set position of item "Applications" of dmgFolder to {400, 160}
    update dmgFolder without registering applications
    delay 1
    close container window of dmgFolder
end tell
APPLESCRIPT

sync
hdiutil detach "${MOUNT_DEVICE}" -quiet
MOUNT_DEVICE=""

echo "Compressing DMG..."
hdiutil convert \
    "${TEMP_DMG_PATH}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_PATH}"

echo "Verifying DMG..."
hdiutil verify "${DMG_PATH}"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

echo "Created ${DMG_PATH}"
