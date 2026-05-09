#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="WallhavenMac"
PROJECT_FILE="${ROOT_DIR}/project.yml"
DERIVED_DATA_DIR="${ROOT_DIR}/build/local-derived"
APP_PATH="${DERIVED_DATA_DIR}/Build/Products/Release/${APP_NAME}.app"
INSTALL_PATH="/Applications/${APP_NAME}.app"
source "${ROOT_DIR}/Scripts/versioning.sh"

APP_VERSION="$(bump_patch_version "${PROJECT_FILE}")"

cd "${ROOT_DIR}"

echo "Bumped ${APP_NAME} to ${APP_VERSION}."
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

echo "Replacing ${INSTALL_PATH}..."
osascript -e "tell application \"${APP_NAME}\" to quit" >/dev/null 2>&1 || true
rm -rf "${INSTALL_PATH}"
ditto "${APP_PATH}" "${INSTALL_PATH}"
codesign --verify --deep --strict --verbose=2 "${INSTALL_PATH}"
open -a "${INSTALL_PATH}"

echo "Installed ${APP_NAME} ${APP_VERSION} at ${INSTALL_PATH}."
