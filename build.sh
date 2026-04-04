#!/bin/bash

# Exit on error, unset variables, and pipe failures
set -euo pipefail

# Extract version from Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info/Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info/Info.plist)

echo "Building Weathervane version $VERSION (build $BUILD)..."

# Paths
BUILD_DIR=".build"
UNIVERSAL_OUTPUT="$BUILD_DIR/universal"
ARM64_PATH="$BUILD_DIR/arm64-apple-macosx/release/Weathervane"
X86_64_PATH="$BUILD_DIR/x86_64-apple-macosx/release/Weathervane"
UNIVERSAL_BINARY="$UNIVERSAL_OUTPUT/Weathervane"

# Clean previous universal output
rm -rf "$UNIVERSAL_OUTPUT"
mkdir -p "$UNIVERSAL_OUTPUT"

# Build for Apple Silicon and Intel
echo "Building for arm64..."
swift build -c release --arch arm64

echo "Building for x86_64..."
swift build -c release --arch x86_64

# Create universal binary
echo "Creating universal binary..."
lipo -create "$ARM64_PATH" "$X86_64_PATH" -output "$UNIVERSAL_BINARY"

# Verify architecture of universal binary
echo "Verifying architectures in universal binary:"
lipo -info "$UNIVERSAL_BINARY"

# Create application bundle
echo "Creating application bundle..."
APP_DIR="Weathervane.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy universal binary and rename to match app name
cp "$UNIVERSAL_BINARY" "$MACOS_DIR/Weathervane"
chmod +x "$MACOS_DIR/Weathervane"

# Copy Info.plist
cp Info/Info.plist "$CONTENTS_DIR/"

# Sign the application
if [ -z "${CI:-}" ]; then
  if [ -n "${APPLE_DEVELOPER_CERTIFICATE_P12_BASE64:-}" ] && [ -n "${APPLE_DEVELOPER_CERTIFICATE_PASSWORD:-}" ]; then
    echo "Code signing the application with Developer ID..."

    KEYCHAIN_PATH=${RUNNER_TEMP:-/tmp}/app-signing.keychain-db
    KEYCHAIN_PASSWORD="temporary-password"

    security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
    security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
    security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

    echo $APPLE_DEVELOPER_CERTIFICATE_P12_BASE64 | base64 --decode > certificate.p12
    security import certificate.p12 -k "$KEYCHAIN_PATH" -P "$APPLE_DEVELOPER_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

    echo "Available signing identities:"
    security find-identity -v -p codesigning "$KEYCHAIN_PATH"

    IDENTITY_HASH=$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" | grep -o '[A-F0-9]\{40\}' | head -1)

    if [ -z "$IDENTITY_HASH" ]; then
      echo "No signing identity found in keychain. Using ad-hoc signing instead."
      /usr/bin/codesign --force --options runtime --sign - "$APP_DIR" --deep
    else
      echo "Signing with identity hash: $IDENTITY_HASH"
      /usr/bin/codesign --force --options runtime --entitlements "Info/Weathervane.entitlements" \
        --sign "$IDENTITY_HASH" \
        --keychain "$KEYCHAIN_PATH" \
        "$APP_DIR" --deep --timestamp
    fi

    echo "Verifying signature..."
    codesign -vvv --deep --strict "$APP_DIR" || echo "Warning: Signature verification failed, but continuing..."
    rm certificate.p12
  else
    echo "No Developer ID certificate provided, using ad-hoc signing instead..."

    if [ -r "Info/Weathervane.entitlements" ]; then
      echo "Using entitlements file..."
      /usr/bin/codesign --force --options runtime --entitlements "Info/Weathervane.entitlements" --sign - "$APP_DIR" --deep
    else
      echo "Entitlements file not found or not readable, using basic ad-hoc signing..."
      /usr/bin/codesign --force --options runtime --sign - "$APP_DIR" --deep
    fi

    echo "Note: App is signed with ad-hoc signature. Users will need to right-click and select Open"
    echo "or use 'xattr -cr Weathervane.app' after downloading to bypass Gatekeeper."
  fi
else
  echo "CI environment detected; skipping codesign in build.sh (handled by workflow)"
fi

echo "Application bundle created: $APP_DIR"
echo "To run the application, use: open $APP_DIR"
