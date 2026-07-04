param(
  [string] $Alias = "upload"
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$keystorePath = Join-Path $repoRoot "android/app/upload-keystore.jks"
$propertiesPath = Join-Path $repoRoot "android/key.properties"

if (Test-Path $keystorePath) {
  throw "Keystore already exists; refusing to overwrite: $keystorePath"
}

if (Test-Path $propertiesPath) {
  throw "key.properties already exists; refusing to overwrite: $propertiesPath"
}

$chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".ToCharArray()
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()

function New-Password {
  param([int] $Length = 32)

  $bytes = New-Object byte[] $Length
  $rng.GetBytes($bytes)
  -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

$storePassword = New-Password
$keyPassword = $storePassword

& keytool `
  -genkeypair `
  -v `
  -keystore $keystorePath `
  -storetype PKCS12 `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias $Alias `
  -storepass $storePassword `
  -keypass $keyPassword `
  -dname "CN=Attack of the Dragon, OU=Game, O=Attack of the Dragon, L=Tokyo, ST=Tokyo, C=JP"

if ($LASTEXITCODE -ne 0) {
  throw "keytool failed with exit code $LASTEXITCODE"
}

$content = @(
  "storeFile=app/upload-keystore.jks",
  "storePassword=$storePassword",
  "keyAlias=$Alias",
  "keyPassword=$keyPassword"
)

[System.IO.File]::WriteAllLines(
  $propertiesPath,
  $content,
  [System.Text.UTF8Encoding]::new($false)
)

Write-Host "Generated android/app/upload-keystore.jks and android/key.properties."
Write-Host "Both files are ignored by git. Back them up before submitting to a store."
