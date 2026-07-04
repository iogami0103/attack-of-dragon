[CmdletBinding()]
param(
    [switch]$SkipFetch,
    [switch]$RunFlutterChecks,
    [switch]$BuildDebugApk
)

$ErrorActionPreference = 'Stop'
$Rtk = 'C:\Users\iogam\bin\rtk.exe'

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ''
    Write-Host "== $Title =="
}

function Invoke-Rtk {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure,
        [switch]$Quiet
    )

    $oldErrorActionPreference = $ErrorActionPreference
    $hasNativeErrorPreference = Test-Path -LiteralPath 'variable:PSNativeCommandUseErrorActionPreference'
    if ($hasNativeErrorPreference) {
        $oldNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    try {
        $ErrorActionPreference = 'Continue'
        $output = & $Rtk @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldErrorActionPreference
        if ($hasNativeErrorPreference) {
            $PSNativeCommandUseErrorActionPreference = $oldNativeErrorPreference
        }
    }

    if ($output -and -not $Quiet) {
        $output | ForEach-Object { Write-Host $_ }
    }

    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw "Command failed ($exitCode): $Rtk $($Arguments -join ' ')"
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output)
    }
}

if (-not (Test-Path -LiteralPath $Rtk)) {
    throw "RTK was not found at $Rtk"
}

$rootOutput = & $Rtk git rev-parse --show-toplevel 2>&1
if ($LASTEXITCODE -ne 0) {
    $rootOutput | ForEach-Object { Write-Host $_ }
    throw 'This script must be run inside the git repository.'
}

$repoRoot = ($rootOutput | Select-Object -First 1).ToString().Trim()
Set-Location -LiteralPath $repoRoot

Write-Section 'Repository'
$origin = Invoke-Rtk -Arguments @('git', 'remote', 'get-url', 'origin')
$originUrl = ($origin.Output | Select-Object -First 1).ToString().Trim()
if ($originUrl -ne 'https://github.com/iogami0103/attack-of-dragon.git') {
    Write-Warning "Unexpected origin remote: $originUrl"
}

Invoke-Rtk -Arguments @('git', 'status', '--short', '--branch') | Out-Null

if (-not $SkipFetch) {
    Write-Section 'Fetch'
    Invoke-Rtk -Arguments @('git', 'fetch', '--prune', 'origin') | Out-Null
}

Write-Section 'Branch'
$branch = & $Rtk git branch --show-current 2>&1
if ($LASTEXITCODE -ne 0) {
    $branch | ForEach-Object { Write-Host $_ }
    throw 'Could not read current branch.'
}

$branchName = ($branch | Select-Object -First 1).ToString().Trim()
Write-Host "Current branch: $branchName"

$upstream = & $Rtk git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>$null
if ($LASTEXITCODE -eq 0) {
    $upstreamName = ($upstream | Select-Object -First 1).ToString().Trim()
    Write-Host "Upstream: $upstreamName"

    $counts = & $Rtk git rev-list --left-right --count 'HEAD...@{upstream}' 2>&1
    if ($LASTEXITCODE -eq 0) {
        $parts = (($counts | Select-Object -First 1).ToString().Trim() -split '\s+')
        if ($parts.Count -eq 2) {
            Write-Host "Ahead: $($parts[0])"
            Write-Host "Behind: $($parts[1])"
        }
    }
} else {
    Write-Warning 'Current branch has no upstream.'
}

Write-Section 'Working tree'
$dirty = & $Rtk git status --porcelain 2>&1
if ($LASTEXITCODE -ne 0) {
    $dirty | ForEach-Object { Write-Host $_ }
    throw 'Could not read working tree status.'
}

if ($dirty) {
    Write-Warning 'Working tree has local changes.'
} else {
    Write-Host 'Working tree is clean.'
}

Write-Section 'GitHub CLI'
$ghVersion = Invoke-Rtk -Arguments @('gh', '--version') -AllowFailure
if ($ghVersion.ExitCode -eq 0) {
    $ghAuth = Invoke-Rtk -Arguments @('gh', 'auth', 'status') -AllowFailure
    if ($ghAuth.ExitCode -ne 0) {
        Write-Warning 'gh is installed but not logged in. Run gh auth login before local PR automation.'
    }
} else {
    Write-Warning 'gh is not available. Install GitHub CLI or use the Codex GitHub connector for PR automation.'
}

Write-Section 'Ignored local files'
$trackedWrangler = Invoke-Rtk -Arguments @('git', 'ls-files', '--error-unmatch', 'server/score-submit-worker/wrangler.toml') -AllowFailure -Quiet
if ($trackedWrangler.ExitCode -eq 0) {
    Write-Warning 'server/score-submit-worker/wrangler.toml is tracked; it should remain local only.'
} else {
    Write-Host 'Wrangler local config is not tracked.'
}

$ignoreTargets = @(
    'android/key.properties',
    'GoogleService-Info.plist',
    'google-services.json',
    '.env',
    'server/score-submit-worker/wrangler.toml'
)

foreach ($target in $ignoreTargets) {
    & $Rtk git check-ignore -q -- $target
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Ignored: $target"
    } else {
        Write-Warning "Not ignored: $target"
    }
}

if ($RunFlutterChecks) {
    Write-Section 'Flutter checks'
    Invoke-Rtk -Arguments @('flutter', 'analyze') | Out-Null
    Invoke-Rtk -Arguments @('flutter', 'test') | Out-Null
}

if ($BuildDebugApk) {
    Write-Section 'Android debug build'
    Invoke-Rtk -Arguments @('flutter', 'build', 'apk', '--debug') | Out-Null
}

Write-Section 'Done'
Write-Host 'GitHub workflow check finished.'
