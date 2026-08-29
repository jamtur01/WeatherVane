#!/bin/bash
set -euo pipefail

readonly APP_DIR="Weathervane.app"
readonly BUILD_DIR=".build"
readonly ARM64_BINARY="$BUILD_DIR/arm64-apple-macosx/release/Weathervane"
readonly X86_64_BINARY="$BUILD_DIR/x86_64-apple-macosx/release/Weathervane"
TASK_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/weathervane-build.XXXXXX")
readonly TASK_TEMP_DIR
readonly UNIVERSAL_BINARY="$TASK_TEMP_DIR/Weathervane"
readonly ICONSET_DIR="$TASK_TEMP_DIR/AppIcon.iconset"
readonly KEYCHAIN_PATH="$TASK_TEMP_DIR/app-signing.keychain-db"
readonly CERTIFICATE_PATH="$TASK_TEMP_DIR/certificate.p12"

keychain_created=false

cleanup() {
  local exit_status=$?
  local cleanup_failed=false
  trap - EXIT
  set +e

  if [[ "$keychain_created" == true ]]; then
    if ! security delete-keychain "$KEYCHAIN_PATH"; then
      echo "Failed to delete temporary signing keychain: $KEYCHAIN_PATH" >&2
      cleanup_failed=true
    fi
  fi
  if [[ -d "$TASK_TEMP_DIR" ]] && ! find "$TASK_TEMP_DIR" -depth -delete; then
    echo "Failed to delete temporary build directory: $TASK_TEMP_DIR" >&2
    cleanup_failed=true
  fi
  if [[ "$cleanup_failed" == true && $exit_status -eq 0 ]]; then
    exit_status=1
  fi
  exit "$exit_status"
}

reset_app_bundle() {
  if [[ -e "$APP_DIR" ]]; then
    find "$APP_DIR" -depth -delete
  fi
  mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
}

generate_icon() {
  local icon_source="Icon/icon.png"
  if [[ ! -r "$icon_source" ]]; then
    echo "App icon source is missing or unreadable: $icon_source" >&2
    return 1
  fi

  mkdir -p "$ICONSET_DIR"
  local size
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$icon_source" \
      --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    sips -z "$((size * 2))" "$((size * 2))" "$icon_source" \
      --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
}

sign_with_developer_id() {
  local certificate_base64="${APPLE_DEVELOPER_CERTIFICATE_P12_BASE64:-}"
  local certificate_password="${APPLE_DEVELOPER_CERTIFICATE_PASSWORD:-}"
  if [[ -z "$certificate_base64" || -z "$certificate_password" ]]; then
    echo "Both Developer ID certificate variables must be set." >&2
    return 1
  fi

  security create-keychain -p "temporary-password" "$KEYCHAIN_PATH"
  keychain_created=true
  security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
  security unlock-keychain -p "temporary-password" "$KEYCHAIN_PATH"
  printf '%s' "$certificate_base64" | base64 --decode >"$CERTIFICATE_PATH"
  security import "$CERTIFICATE_PATH" -k "$KEYCHAIN_PATH" \
    -P "$certificate_password" -T /usr/bin/codesign
  security set-key-partition-list -S apple-tool:,apple:,codesign: \
    -s -k "temporary-password" "$KEYCHAIN_PATH"

  local identity_hash
  identity_hash="$(security find-identity -v -p codesigning "$KEYCHAIN_PATH" |
    awk '$2 ~ /^[[:xdigit:]]{40}$/ { print $2; exit }')"
  if [[ -z "$identity_hash" ]]; then
    echo "No Developer ID signing identity was found in the imported certificate." >&2
    return 1
  fi

  /usr/bin/codesign --force --options runtime --timestamp \
    --keychain "$KEYCHAIN_PATH" --sign "$identity_hash" "$APP_DIR"
}

sign_locally() {
  local certificate_base64="${APPLE_DEVELOPER_CERTIFICATE_P12_BASE64:-}"
  local certificate_password="${APPLE_DEVELOPER_CERTIFICATE_PASSWORD:-}"
  if [[ -n "$certificate_base64" || -n "$certificate_password" ]]; then
    sign_with_developer_id
  else
    echo "No Developer ID certificate provided; applying an ad-hoc signature."
    /usr/bin/codesign --force --options runtime --sign - "$APP_DIR"
  fi
  /usr/bin/codesign --verify --deep --strict --verbose=4 "$APP_DIR"
}

trap cleanup EXIT

if [[ ! -r "Info/Info.plist" ]]; then
  echo "App metadata is missing or unreadable: Info/Info.plist" >&2
  exit 1
fi

version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info/Info.plist)
build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info/Info.plist)
echo "Building Weathervane version $version (build $build)..."

swift build -c release --arch arm64 -Xswiftc -warnings-as-errors
swift build -c release --arch x86_64 -Xswiftc -warnings-as-errors

lipo -create "$ARM64_BINARY" "$X86_64_BINARY" -output "$UNIVERSAL_BINARY"
lipo "$UNIVERSAL_BINARY" -verify_arch arm64 x86_64

reset_app_bundle
cp "$UNIVERSAL_BINARY" "$APP_DIR/Contents/MacOS/Weathervane"
chmod +x "$APP_DIR/Contents/MacOS/Weathervane"
cp Info/Info.plist "$APP_DIR/Contents/"
generate_icon

if [[ "${CI:-}" == "true" || "${CI:-}" == "1" ]]; then
  echo "CI environment detected; signing is handled by the release workflow."
else
  sign_locally
fi

echo "Application bundle created: $APP_DIR"
