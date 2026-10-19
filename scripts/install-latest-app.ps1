param(
    [string]$DeviceId = "142922559S104057"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
$environmentFile = Join-Path $projectRoot "supabase.env.json"
$buildStartedAt = Get-Date

if (-not (Test-Path $environmentFile)) {
    throw "Missing supabase.env.json. Create it before building the app."
}

if (Test-Path $apkPath) {
    Remove-Item $apkPath -Force
}

Push-Location $projectRoot
try {
    & flutter build apk --release --dart-define-from-file=supabase.env.json
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter release build failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path $apkPath)) {
    throw "Flutter reported success, but no release APK was produced."
}

$apk = Get-Item $apkPath
if ($apk.LastWriteTime -lt $buildStartedAt -or $apk.Length -le 0) {
    throw "The release APK was not produced by this build."
}

Write-Host "Installing APK built at $($apk.LastWriteTime): $apkPath"
& flutter install -d $DeviceId --use-application-binary=$apkPath
if ($LASTEXITCODE -ne 0) {
    throw "Flutter installation failed with exit code $LASTEXITCODE."
}

Write-Host "Latest release installed on device $DeviceId."
