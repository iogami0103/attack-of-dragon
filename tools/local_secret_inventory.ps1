[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Rtk = 'C:\Users\iogam\bin\rtk.exe'

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$AllowFailure,
        [switch]$Quiet
    )

    $gitCommand = @('git') + $Arguments
    if (Test-Path -LiteralPath $Rtk) {
        $command = $Rtk
        $commandArgs = $gitCommand
    } else {
        $command = 'git'
        $commandArgs = $Arguments
    }

    $oldErrorActionPreference = $ErrorActionPreference
    $hasNativeErrorPreference = Test-Path -LiteralPath 'variable:PSNativeCommandUseErrorActionPreference'
    if ($hasNativeErrorPreference) {
        $oldNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    try {
        $ErrorActionPreference = 'Continue'
        $output = & $command @commandArgs 2>&1
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
        throw "Command failed ($exitCode): git $($Arguments -join ' ')"
    }

    [pscustomobject]@{
        ExitCode = $exitCode
        Output = @($output)
    }
}

function Write-Section {
    param([Parameter(Mandatory = $true)][string]$Title)
    Write-Host ''
    Write-Host "== $Title =="
}

function Test-LocalSecret {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Purpose,
        [switch]$RequiredForRelease
    )

    $exists = Test-Path -LiteralPath $Path
    $ignore = Invoke-Git -Arguments @('check-ignore', '-q', '--', $Path) -AllowFailure -Quiet
    $ignored = $ignore.ExitCode -eq 0

    $status = if ($exists) { 'present' } else { 'missing' }
    $importance = if ($RequiredForRelease) { 'release' } else { 'optional' }
    $ignoreStatus = if ($ignored) { 'ignored' } else { 'NOT ignored' }

    Write-Host ("{0,-8} {1,-8} {2,-11} {3} - {4}" -f $status, $importance, $ignoreStatus, $Path, $Purpose)
}

$root = Invoke-Git -Arguments @('rev-parse', '--show-toplevel') -Quiet
if ($root.ExitCode -ne 0 -or -not $root.Output) {
    throw 'This script must be run inside the git repository.'
}

Set-Location -LiteralPath (($root.Output | Select-Object -First 1).ToString().Trim())

Write-Section 'Tracked secret guard'
$tracked = Invoke-Git -Arguments @(
    'ls-files',
    '--',
    'android/key.properties',
    'android/**/*.jks',
    'android/**/*.keystore',
    'server/score-submit-worker/wrangler.toml',
    'server/score-submit-worker/.dev.vars',
    'GoogleService-Info.plist',
    'google-services.json',
    '*.env',
    '.env',
    '.env.*',
    '*.p8',
    '*.p12',
    '*.mobileprovision'
) -Quiet

if ($tracked.Output.Count -gt 0) {
    Write-Warning 'One or more secret-like files are tracked by Git:'
    $tracked.Output | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Host 'No secret-like files are tracked by Git.'
}

Write-Section 'Local secret files'
Test-LocalSecret -Path 'android/key.properties' -Purpose 'Android release signing properties' -RequiredForRelease

if (Test-Path -LiteralPath 'android/key.properties') {
    $storeFileLine = Select-String -LiteralPath 'android/key.properties' -Pattern '^\s*storeFile\s*=\s*(.+)\s*$' | Select-Object -First 1
    if ($storeFileLine) {
        $storeFile = $storeFileLine.Matches[0].Groups[1].Value.Trim()
        if ([System.IO.Path]::IsPathRooted($storeFile)) {
            Test-LocalSecret -Path $storeFile -Purpose 'Android upload keystore referenced by key.properties' -RequiredForRelease
        } else {
            Test-LocalSecret -Path (Join-Path 'android' $storeFile) -Purpose 'Android upload keystore referenced by key.properties' -RequiredForRelease
        }
    } else {
        Write-Warning 'android/key.properties exists, but storeFile was not found.'
    }
} else {
    Test-LocalSecret -Path 'android/app/upload-keystore.jks' -Purpose 'Expected Android upload keystore from example' -RequiredForRelease
}

Test-LocalSecret -Path 'server/score-submit-worker/wrangler.toml' -Purpose 'Cloudflare Worker and D1 local config' -RequiredForRelease
Test-LocalSecret -Path 'server/score-submit-worker/.dev.vars' -Purpose 'Cloudflare Worker local environment variables'
Test-LocalSecret -Path 'ios/Runner/GoogleService-Info.plist' -Purpose 'Optional iOS Google/Firebase config'
Test-LocalSecret -Path 'android/app/google-services.json' -Purpose 'Optional Android Google/Firebase config'

Write-Section 'Next steps'
Write-Host 'If required files are missing, restore them from the password manager or encrypted backup.'
Write-Host 'Do not paste secret values into GitHub, docs, PR comments, or Codex final answers.'
