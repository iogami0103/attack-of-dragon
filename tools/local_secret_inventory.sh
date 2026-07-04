#!/usr/bin/env bash
set -u

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$repo_root" ]; then
  echo "This script must be run inside the git repository." >&2
  exit 1
fi

cd "$repo_root" || exit 1

section() {
  printf '\n== %s ==\n' "$1"
}

is_ignored() {
  git check-ignore -q -- "$1"
}

check_secret() {
  path="$1"
  purpose="$2"
  importance="${3:-optional}"

  if [ -e "$path" ]; then
    status="present"
  else
    status="missing"
  fi

  if is_ignored "$path"; then
    ignored="ignored"
  else
    ignored="NOT ignored"
  fi

  printf '%-8s %-8s %-11s %s - %s\n' "$status" "$importance" "$ignored" "$path" "$purpose"
}

section "Tracked secret guard"
tracked="$(git ls-files -- \
  android/key.properties \
  'android/**/*.jks' \
  'android/**/*.keystore' \
  server/score-submit-worker/wrangler.toml \
  server/score-submit-worker/.dev.vars \
  GoogleService-Info.plist \
  google-services.json \
  '*.env' \
  .env \
  '.env.*' \
  '*.p8' \
  '*.p12' \
  '*.mobileprovision')"

if [ -n "$tracked" ]; then
  echo "WARNING: one or more secret-like files are tracked by Git:"
  printf '  %s\n' "$tracked"
else
  echo "No secret-like files are tracked by Git."
fi

section "Local secret files"
check_secret "android/key.properties" "Android release signing properties" "release"

if [ -f "android/key.properties" ]; then
  store_file="$(awk -F= '/^[[:space:]]*storeFile[[:space:]]*=/{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}' android/key.properties)"
  if [ -n "$store_file" ]; then
    case "$store_file" in
      /*) keystore_path="$store_file" ;;
      *) keystore_path="android/$store_file" ;;
    esac
    check_secret "$keystore_path" "Android upload keystore referenced by key.properties" "release"
  else
    echo "WARNING: android/key.properties exists, but storeFile was not found."
  fi
else
  check_secret "android/app/upload-keystore.jks" "Expected Android upload keystore from example" "release"
fi

check_secret "server/score-submit-worker/wrangler.toml" "Cloudflare Worker and D1 local config" "release"
check_secret "server/score-submit-worker/.dev.vars" "Cloudflare Worker local environment variables"
check_secret "ios/Runner/GoogleService-Info.plist" "Optional iOS Google/Firebase config"
check_secret "android/app/google-services.json" "Optional Android Google/Firebase config"

section "Next steps"
echo "If required files are missing, restore them from the password manager or encrypted backup."
echo "Do not paste secret values into GitHub, docs, PR comments, or Codex final answers."
