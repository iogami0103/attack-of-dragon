#!/usr/bin/env bash
set -u
set -o pipefail

CACHE_ROOT="${IOS_INSTALL_CACHE_DIR:-$HOME/Library/Caches/AttackOfTheDragon}"
SOURCE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK_ROOT="${IOS_INSTALL_WORK_DIR:-$CACHE_ROOT/iOSBuild}"
ROOT_DIR="$SOURCE_ROOT"
APP_PATH="$WORK_ROOT/build/ios/Release-iphoneos/Runner.app"
PACKAGE_BUNDLE_ID="${PACKAGE_BUNDLE_ID:-io.github.iogami0103.attackofthedragon}"
DEVICE_ID="${DEVICE_ID:-}"
EXIT_CODE=0
SOURCE_FINGERPRINT=""
STAMP_FILE=""

if command -v rtk >/dev/null 2>&1; then
  RTK=(rtk)
else
  RTK=()
fi

run() {
  "${RTK[@]}" "$@"
}

pause_on_exit() {
  if [ "${NO_PAUSE:-}" != "1" ]; then
    printf "\nPress Return to close this window..."
    read -r _ || true
  fi
}

fail() {
  printf "\nERROR: %s\n" "$1"
  EXIT_CODE=1
}

confirm_iphone_unlocked() {
  if [ "${NO_PAUSE:-}" = "1" ] || [ "${SKIP_INSTALL_PROMPT:-}" = "1" ]; then
    return 0
  fi

  echo
  echo "iPhone installation is about to start."
  echo "Unlock the iPhone now, keep the Home Screen open, then press Return here."
  printf "Ready? "
  read -r _ || true
}

device_stamp_path() {
  SAFE_DEVICE_ID="$(printf "%s" "$DEVICE_ID" | tr -c 'A-Za-z0-9_.-' '_')"
  printf "%s/last-installed-%s.sha256" "$CACHE_ROOT" "$SAFE_DEVICE_ID"
}

device_has_installed_app() {
  APP_INFO_LOG="$(mktemp -t dragon-ios-app-info.XXXXXX.log)"
  if run xcrun devicectl device info apps \
    --device "$DEVICE_ID" \
    --bundle-id "$PACKAGE_BUNDLE_ID" \
    --timeout 30 >"$APP_INFO_LOG" 2>&1; then
    if grep -q "$PACKAGE_BUNDLE_ID" "$APP_INFO_LOG"; then
      rm -f "$APP_INFO_LOG"
      return 0
    fi
  fi

  rm -f "$APP_INFO_LOG"
  return 1
}

app_content_fingerprint() {
  (
    cd "$SOURCE_ROOT" || exit 1
    printf "bundle=%s\n" "$PACKAGE_BUNDLE_ID"
    printf "flutter=%s\n" "$(run flutter --version 2>/dev/null | head -n 1)"
    printf "xcode=%s\n" "$(xcodebuild -version 2>/dev/null | tr '\n' ' ')"

    {
      for file in pubspec.yaml pubspec.lock; do
        [ -f "$file" ] && printf "%s\0" "$file"
      done

      for dir in lib assets ios third_party; do
        [ -d "$dir" ] || continue
        find "$dir" -type f \
          ! -path 'ios/Pods/*' \
          ! -path 'ios/Flutter/ephemeral/*' \
          ! -path '*/.DS_Store' \
          ! -name '*.xcuserstate' \
          ! -name '*.xcresult' \
          -print0
      done
    } | LC_ALL=C sort -z | while IFS= read -r -d '' file; do
      shasum -a 256 "$file"
    done
  ) | shasum -a 256 | awk '{print $1}'
}

clear_extended_attributes() {
  echo "Clearing macOS extended attributes for iOS code signing..."

  xattr -cr "$ROOT_DIR" 2>/dev/null || true

  FLUTTER_BIN="$(command -v flutter 2>/dev/null || true)"
  if [ -n "$FLUTTER_BIN" ]; then
    while [ -L "$FLUTTER_BIN" ]; do
      FLUTTER_LINK="$(readlink "$FLUTTER_BIN")"
      case "$FLUTTER_LINK" in
        /*) FLUTTER_BIN="$FLUTTER_LINK" ;;
        *) FLUTTER_BIN="$(cd "$(dirname "$FLUTTER_BIN")" && cd "$(dirname "$FLUTTER_LINK")" && pwd)/$(basename "$FLUTTER_LINK")" ;;
      esac
    done
    FLUTTER_ROOT="$(cd "$(dirname "$FLUTTER_BIN")/.." 2>/dev/null && pwd || true)"
    if [ -n "$FLUTTER_ROOT" ] && [ -d "$FLUTTER_ROOT/bin/cache/artifacts/engine" ]; then
      xattr -cr "$FLUTTER_ROOT/bin/cache/artifacts/engine" 2>/dev/null || true
    fi
  fi

  rm -rf "$ROOT_DIR/build/ios" "$ROOT_DIR/build/native_assets" 2>/dev/null || true
}

prepare_build_workspace() {
  echo "Preparing clean iOS build workspace..."
  mkdir -p "$CACHE_ROOT" || return 1
  rm -rf "$WORK_ROOT"
  mkdir -p "$WORK_ROOT" || return 1
  rm -rf /tmp/attack_of_the_dragon_ios_build

  rsync -a \
    --exclude='.dart_tool/' \
    --exclude='.git/' \
    --exclude='build/' \
    --exclude='ios/Pods/' \
    --exclude='*.xcresult/' \
    "$SOURCE_ROOT/" "$WORK_ROOT/"

  ROOT_DIR="$WORK_ROOT"
  cd "$ROOT_DIR" || return 1
}

cd "$SOURCE_ROOT" || {
  echo "ERROR: Could not enter project directory: $SOURCE_ROOT"
  pause_on_exit
  exit 1
}

if [ ! -f "$SOURCE_ROOT/pubspec.yaml" ]; then
  echo "ERROR: Flutter project was not found: $SOURCE_ROOT"
  pause_on_exit
  exit 1
fi

if ! run flutter --version >/dev/null 2>&1; then
  echo "ERROR: Flutter could not be started."
  pause_on_exit
  exit 1
fi

if ! run xcrun devicectl --version >/dev/null 2>&1; then
  echo "ERROR: Xcode command line tools could not be started."
  pause_on_exit
  exit 1
fi

if [ -z "$DEVICE_ID" ]; then
  DEVICE_ID="$(run flutter devices 2>/dev/null | awk -F '•' '/ ios[[:space:]]*•/ { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }')"
fi

if [ -z "$DEVICE_ID" ]; then
  echo "ERROR: Could not find a connected iPhone."
  echo
  echo "Connect the iPhone by USB, unlock it, and trust this Mac if prompted."
  echo
  run flutter devices || true
  pause_on_exit
  exit 1
fi

echo "Project: $SOURCE_ROOT"
echo "Build:   $WORK_ROOT"
echo "Device:  $DEVICE_ID"
echo
echo "Keep the iPhone unlocked until the install finishes."
echo

mkdir -p "$CACHE_ROOT" || fail "Could not create the iOS install cache directory."

if [ "$EXIT_CODE" -eq 0 ]; then
  STAMP_FILE="$(device_stamp_path)"
  SOURCE_FINGERPRINT="$(app_content_fingerprint)" || fail "Could not calculate the app content fingerprint."
fi

if [ "$EXIT_CODE" -eq 0 ] && [ "${FORCE_INSTALL:-}" != "1" ] && [ -f "$STAMP_FILE" ] && [ "$(cat "$STAMP_FILE" 2>/dev/null)" = "$SOURCE_FINGERPRINT" ]; then
  echo "The app content matches the last successful install record for this iPhone."
  echo "Checking whether the app is currently installed..."
  if device_has_installed_app; then
    echo "The same app is already installed. Skipping build and install."
    pause_on_exit
    exit 0
  fi
  echo "The app could not be confirmed on the iPhone. Reinstalling."
  rm -f "$STAMP_FILE"
fi

if [ "$EXIT_CODE" -eq 0 ]; then
  prepare_build_workspace || fail "Could not prepare the clean build workspace."
fi

if [ "$EXIT_CODE" -eq 0 ]; then
  run flutter pub get || fail "flutter pub get failed."
fi

if [ "$EXIT_CODE" -eq 0 ]; then
  clear_extended_attributes
  run flutter build ios --release || fail "flutter build ios --release failed."
fi

if [ "$EXIT_CODE" -eq 0 ] && [ ! -d "$APP_PATH" ]; then
  fail "iOS app was not found: $APP_PATH"
fi

if [ "$EXIT_CODE" -eq 0 ]; then
  echo
  confirm_iphone_unlocked
  echo "Installing on iPhone..."
  INSTALL_LOG="$(mktemp -t dragon-ios-install.XXXXXX.log)"
  if ! run xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH" --timeout 180 2>&1 | tee "$INSTALL_LOG"; then
    if grep -q "DeviceLocked\\|device is locked\\|kAMDMobileImageMounterDeviceLocked" "$INSTALL_LOG"; then
      echo
      echo "The iPhone is locked. Unlock it, keep the screen open, then run this installer again."
    elif grep -q "developer disk image could not be mounted\\|no DDI" "$INSTALL_LOG"; then
      echo
      echo "The iPhone developer image could not be mounted. Unlock the iPhone and confirm any trust/developer prompts."
    fi
    fail "iPhone install failed."
  fi
  rm -f "$INSTALL_LOG"
  printf "%s\n" "$SOURCE_FINGERPRINT" > "$STAMP_FILE"
fi

if [ "$EXIT_CODE" -eq 0 ]; then
  echo
  echo "Launching app..."
  run xcrun devicectl device process launch --device "$DEVICE_ID" "$PACKAGE_BUNDLE_ID" >/dev/null 2>&1 || true
  echo "Done."
fi

pause_on_exit
exit "$EXIT_CODE"
