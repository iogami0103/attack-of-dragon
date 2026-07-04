# Project Agent Instructions

These instructions apply to the whole repository.

## Shell commands on this Windows PC

Always prefix shell commands with the absolute RTK executable path:

```powershell
C:\Users\iogam\bin\rtk.exe git status
C:\Users\iogam\bin\rtk.exe flutter analyze
C:\Users\iogam\bin\rtk.exe powershell -ExecutionPolicy Bypass -File tools\github_workflow_check.ps1
```

Use the absolute path because Codex shells may not include `C:\Users\iogam\bin` in `PATH`.

## GitHub workflow

- Remote: `origin` -> `https://github.com/iogami0103/attack-of-dragon.git`
- Before editing, run `git fetch --prune origin`, `git status --short --branch`, and `git pull --ff-only`.
- Default to a branch named `codex/<short-task>` for work that should be reviewed in GitHub.
- Commit directly to `main` only when the user explicitly asks for a direct update or the change is a small repository-maintenance task.
- Before pushing, run `powershell -ExecutionPolicy Bypass -File tools\github_workflow_check.ps1 -RunFlutterChecks`.
- Use `gh auth status` before creating PRs from the local machine. If `gh` is not logged in, ask the user to complete GitHub browser authentication.

## Verification

Use these local gates for normal code changes:

```powershell
C:\Users\iogam\bin\rtk.exe flutter analyze
C:\Users\iogam\bin\rtk.exe flutter test
```

For Android packaging-sensitive changes, also run:

```powershell
C:\Users\iogam\bin\rtk.exe flutter build apk --debug
```

## Do not commit local secrets or generated output

Keep these local only:

- `android/key.properties`
- Android keystores and certificates
- `GoogleService-Info.plist`
- `google-services.json`
- `.env` files
- `server/score-submit-worker/wrangler.toml`
- Flutter, CocoaPods, Xcode, Android, and Cloudflare generated caches
