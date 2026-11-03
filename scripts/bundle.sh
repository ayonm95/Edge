#!/usr/bin/env bash
# ==============================================================================
# bundle.sh — Compile and assemble Edge.app macOS Menu Bar Bundle
# ==============================================================================
set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration & Argument Parsing
# ------------------------------------------------------------------------------
CONFIGURATION="release"
LAUNCH_AFTER_BUILD=false
CLEAN_BUILD=false

APP_NAME="Edge"
BUNDLE_ID="com.edge.slider"
VERSION="1.0.0"
BUILD_NUMBER="1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

print_usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -c, --configuration <release|debug>  Build configuration (default: release)
  --run                                Launch Edge.app immediately after bundling
  --clean                              Clean build artifacts before compiling
  -h, --help                           Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--configuration)
            CONFIGURATION="$2"
            shift 2
            ;;
        --run)
            LAUNCH_AFTER_BUILD=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            print_usage
            exit 1
            ;;
    esac
done

echo "==> Packaging ${APP_NAME} (${CONFIGURATION})..."

cd "${PROJECT_ROOT}"

if [ "${CLEAN_BUILD}" = true ]; then
    echo "==> Cleaning SwiftPM cache..."
    swift package clean
fi

# ------------------------------------------------------------------------------
# 1. Compile Swift Executable
# ------------------------------------------------------------------------------
echo "==> Building ${APP_NAME} via swift build (-c ${CONFIGURATION})..."
swift build -c "${CONFIGURATION}"

BUILD_BIN="${PROJECT_ROOT}/.build/${CONFIGURATION}/${APP_NAME}"
if [ ! -f "${BUILD_BIN}" ]; then
    echo "Error: Compiled binary not found at ${BUILD_BIN}" >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# 2. Assemble App Bundle Directory Hierarchy
# ------------------------------------------------------------------------------
DIST_DIR="${PROJECT_ROOT}/build"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Creating bundle layout at ${APP_DIR}..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy binary
cp "${BUILD_BIN}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# ------------------------------------------------------------------------------
# 3. Create Info.plist & PkgInfo
# ------------------------------------------------------------------------------
echo "==> Writing Info.plist..."
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Edge. All rights reserved.</string>
</dict>
</plist>
EOF

echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Copy resources if present
if [ -d "${PROJECT_ROOT}/Sources/Edge/Resources" ]; then
    echo "==> Copying project resources..."
    cp -R "${PROJECT_ROOT}/Sources/Edge/Resources/"* "${RESOURCES_DIR}/" 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 4. Ad-Hoc Code Signing & Verification
# ------------------------------------------------------------------------------
echo "==> Ad-hoc signing ${APP_NAME}.app..."
codesign --force --deep --sign - "${APP_DIR}"

echo "==> Verifying code signature..."
codesign --verify --deep --strict "${APP_DIR}"

echo "==> Successfully bundled: ${APP_DIR}"

# ------------------------------------------------------------------------------
# 5. Launch Application (Optional)
# ------------------------------------------------------------------------------
if [ "${LAUNCH_AFTER_BUILD}" = true ]; then
    echo "==> Launching ${APP_NAME}.app..."
    open "${APP_DIR}"
fi
