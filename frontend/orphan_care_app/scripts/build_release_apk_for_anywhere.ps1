param(
    [string]$ApiBaseUrl = 'https://kanafapp.pythonanywhere.com/api'
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$healthUrl = ($ApiBaseUrl.TrimEnd('/')) + '/health/'
try {
    $response = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 12
    if ($response.status -ne 'ok' -or $response.database -ne 'ok') {
        throw "Unexpected health response: $($response | ConvertTo-Json -Compress)"
    }
} catch {
    Write-Error "Cannot build the anywhere APK because the production API is not healthy at $healthUrl. Deploy/fix the backend first, then rerun this script. $($_.Exception.Message)"
}

Write-Host "Building release APK with API_BASE_URL=$ApiBaseUrl"

flutter build apk --release --dart-define=API_BASE_URL=$ApiBaseUrl

$apkPath = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-release.apk'
$readyApkDir = Join-Path $projectRoot 'READY_APK'
$readyApkPath = Join-Path $readyApkDir 'Kanaf-anywhere-release.apk'
New-Item -ItemType Directory -Force -Path $readyApkDir | Out-Null
Copy-Item -Force -Path $apkPath -Destination $readyApkPath

Write-Host "APK ready: $apkPath"
Write-Host "READY_APK copy: $readyApkPath"
