#!/usr/bin/env bash
set -euo pipefail

skip_fetch=0
run_flutter_checks=0
build_debug_apk=0

for arg in "$@"; do
  case "$arg" in
    --skip-fetch|-SkipFetch)
      skip_fetch=1
      ;;
    --run-flutter-checks|-RunFlutterChecks)
      run_flutter_checks=1
      ;;
    --build-debug-apk|-BuildDebugApk)
      build_debug_apk=1
      ;;
    -h|--help)
      cat <<'EOF'
Usage: bash tools/github_workflow_check.sh [options]

Options:
  --skip-fetch          Do not fetch origin.
  --run-flutter-checks  Run flutter analyze and flutter test.
  --build-debug-apk     Run flutter build apk --debug.
EOF
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

section() {
  printf '\n== %s ==\n' "$1"
}

resolve_rtk() {
  if [ -n "${RTK_PATH:-}" ]; then
    printf '%s\n' "$RTK_PATH"
    return
  fi

  if [ -x /opt/homebrew/bin/rtk ]; then
    printf '%s\n' /opt/homebrew/bin/rtk
    return
  fi

  if [ -x /usr/local/bin/rtk ]; then
    printf '%s\n' /usr/local/bin/rtk
    return
  fi

  if command -v rtk >/dev/null 2>&1; then
    command -v rtk
    return
  fi

  return 1
}

rtk="$(resolve_rtk)" || {
  echo "RTK was not found. Install it or set RTK_PATH." >&2
  exit 1
}

run() {
  "$rtk" "$@"
}

run_allow_failure() {
  set +e
  "$rtk" "$@"
  status=$?
  set -e
  return "$status"
}

repo_root="$(run git rev-parse --show-toplevel | head -n 1 | tr -d '\r')"
if [ -z "$repo_root" ]; then
  echo "This script must be run inside the git repository." >&2
  exit 1
fi

cd "$repo_root"

section "Repository"
origin_url="$(run git remote get-url origin | head -n 1 | tr -d '\r')"
if [ "$origin_url" != "https://github.com/iogami0103/attack-of-dragon.git" ]; then
  echo "WARNING: Unexpected origin remote: $origin_url" >&2
fi

run git status --short --branch

if [ "$skip_fetch" -eq 0 ]; then
  section "Fetch"
  run git fetch --prune origin
fi

section "Branch"
branch_name="$(run git branch --show-current | head -n 1 | tr -d '\r')"
echo "Current branch: $branch_name"

if upstream_name="$(run git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null | head -n 1 | tr -d '\r')"; then
  echo "Upstream: $upstream_name"
  if counts="$(run git rev-list --left-right --count 'HEAD...@{upstream}' 2>/dev/null | head -n 1 | tr -d '\r')"; then
    set -- $counts
    if [ "$#" -eq 2 ]; then
      echo "Ahead: $1"
      echo "Behind: $2"
    fi
  fi
else
  echo "WARNING: Current branch has no upstream." >&2
fi

section "Working tree"
dirty="$(run git status --porcelain | awk '{ line=$0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", line); if (line != "" && line != "ok") print $0 }')"
if [ -n "$dirty" ]; then
  echo "WARNING: Working tree has local changes." >&2
  printf '%s\n' "$dirty"
else
  echo "Working tree is clean."
fi

section "GitHub CLI"
if run_allow_failure gh --version; then
  if ! run_allow_failure gh auth status; then
    echo "WARNING: gh is installed but not logged in. Run gh auth login before local PR automation." >&2
  fi
else
  echo "WARNING: gh is not available. Install GitHub CLI or use the Codex GitHub connector for PR automation." >&2
fi

section "Ignored local files"
if run_allow_failure git ls-files --error-unmatch server/score-submit-worker/wrangler.toml >/dev/null 2>&1; then
  echo "WARNING: server/score-submit-worker/wrangler.toml is tracked; it should remain local only." >&2
else
  echo "Wrangler local config is not tracked."
fi

ignore_targets=(
  android/key.properties
  GoogleService-Info.plist
  google-services.json
  .env
  server/score-submit-worker/wrangler.toml
)

for target in "${ignore_targets[@]}"; do
  if run_allow_failure git check-ignore -q -- "$target"; then
    echo "Ignored: $target"
  else
    echo "WARNING: Not ignored: $target" >&2
  fi
done

section "Worker checks"
run node --check server/score-submit-worker/worker.js
run node --test server/score-submit-worker/worker.test.mjs

if [ "$run_flutter_checks" -eq 1 ]; then
  section "Flutter checks"
  run flutter analyze
  run flutter test
fi

if [ "$build_debug_apk" -eq 1 ]; then
  section "Android debug build"
  run flutter build apk --debug
fi

section "Done"
echo "GitHub workflow check finished."
