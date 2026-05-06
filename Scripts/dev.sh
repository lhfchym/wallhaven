#!/usr/bin/env bash
set -euo pipefail

swift build
swift test

if command -v swiftlint >/dev/null 2>&1; then
    swiftlint
fi
