$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$apiBaseUrl = 'http://127.0.0.1:8000/api'
Write-Host "Building USB reverse debug APK with API_BASE_URL=$apiBaseUrl"

flutter build apk --debug --dart-define=API_BASE_URL=$apiBaseUrl

$apkPath = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-debug.apk'
$readyApkDir = Join-Path $projectRoot 'READY_APK'
$readyApkPath = Join-Path $readyApkDir 'Kanaf-usb-debug.apk'
New-Item -ItemType Directory -Force -Path $readyApkDir | Out-Null
Copy-Item -Force -Path $apkPath -Destination $readyApkPath

Write-Host "APK ready: $apkPath"
Write-Host "READY_APK copy: $readyApkPath"
Write-Host 'Before testing this APK over USB, run: .\scripts\start_usb_reverse_backend_access.ps1'
