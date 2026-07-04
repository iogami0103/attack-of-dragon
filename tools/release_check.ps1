param(
  [switch] $RequireReleaseSigning
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$rtk = "C:\Users\iogam\bin\rtk.exe"

if (-not (Test-Path $rtk)) {
  throw "rtk.exe was not found: $rtk"
}

function Invoke-ReleaseStep {
  param(
    [Parameter(Mandatory = $true)]
    [string] $Name,

    [Parameter(Mandatory = $true)]
    [string[]] $Command
  )

  Write-Host ""
  Write-Host "==> $Name"
  & $rtk @Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

function Assert-AndroidReleaseSigning {
  $propertiesPath = Join-Path $repoRoot "android/key.properties"
  if (-not (Test-Path $propertiesPath)) {
    throw "android/key.properties is required for store release signing."
  }

  $properties = @{}
  Get-Content $propertiesPath | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -ne 0 -and -not $line.StartsWith("#")) {
      $parts = $line.Split("=", 2)
      if ($parts.Length -eq 2) {
        $properties[$parts[0].Trim()] = $parts[1].Trim()
      }
    }
  }

  foreach ($key in @("storeFile", "storePassword", "keyAlias", "keyPassword")) {
    if (-not $properties.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($properties[$key])) {
      throw "android/key.properties is missing '$key'."
    }
  }

  $storeFile = Join-Path (Join-Path $repoRoot "android") $properties["storeFile"]
  if (-not (Test-Path $storeFile)) {
    throw "Android keystore was not found: $storeFile"
  }
}

Push-Location $repoRoot
try {
  if ($RequireReleaseSigning) {
    Assert-AndroidReleaseSigning
  }

  Invoke-ReleaseStep "Flutter analyze" @("flutter", "analyze")
  Invoke-ReleaseStep "Flutter test" @("flutter", "test")
  Invoke-ReleaseStep "Web release build" @("flutter", "build", "web", "--release")
  Invoke-ReleaseStep "Android app bundle release build" @("flutter", "build", "appbundle", "--release")
  Invoke-ReleaseStep "Windows release build" @("flutter", "build", "windows", "--release")
  Invoke-ReleaseStep "Worker syntax check" @("node", "--check", "server/score-submit-worker/worker.js")
  Invoke-ReleaseStep "Git whitespace check" @("git", "diff", "--check")

  Write-Host ""
  Write-Host "Release checks completed."
} finally {
  Pop-Location
}
