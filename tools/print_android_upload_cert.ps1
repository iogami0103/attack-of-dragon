$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$propertiesPath = Join-Path $repoRoot "android/key.properties"

if (-not (Test-Path $propertiesPath)) {
  throw "android/key.properties was not found."
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

foreach ($key in @("storeFile", "storePassword", "keyAlias")) {
  if (-not $properties.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($properties[$key])) {
    throw "android/key.properties is missing '$key'."
  }
}

$storeFile = Join-Path (Join-Path $repoRoot "android") $properties["storeFile"]
if (-not (Test-Path $storeFile)) {
  throw "Android keystore was not found: $storeFile"
}

& keytool `
  -list `
  -v `
  -keystore $storeFile `
  -alias $properties["keyAlias"] `
  -storepass $properties["storePassword"]

if ($LASTEXITCODE -ne 0) {
  throw "keytool failed with exit code $LASTEXITCODE"
}
