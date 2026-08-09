param(
    [string]$ApiBaseUrl = 'https://kanafapp.pythonanywhere.com/api',
    [switch]$UseLocalBackend
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Test-ApiHealth {
    param([string]$BaseUrl)

    $healthUrl = ($BaseUrl.TrimEnd('/')) + '/health/'
    try {
        $response = Invoke-RestMethod -Uri $healthUrl -Method Get -TimeoutSec 12
        return $response.status -eq 'ok' -and $response.database -eq 'ok'
    } catch {
        Write-Warning "API health check failed at $healthUrl"
        Write-Warning $_.Exception.Message
        return $false
    }
}

if ($UseLocalBackend) {
    $localIp = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254*' } |
        Select-Object -First 1 -ExpandProperty IPAddress)

    if (-not $localIp) {
        throw 'Could not find a LAN IPv4 address for this laptop.'
    }

    $ApiBaseUrl = "http://$localIp`:8000/api"
    $networkName = (Get-NetConnectionProfile |
        Where-Object { $_.InterfaceAlias -eq (Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -eq $localIp } |
            Select-Object -First 1 -ExpandProperty InterfaceAlias) } |
        Select-Object -First 1 -ExpandProperty Name)
    if ($networkName -match 'Galaxy|Android|Hotspot|iPhone') {
        Write-Warning "The laptop appears to be connected to a phone hotspot ($networkName). If this APK is installed on the same hotspot phone, Android may not reach $ApiBaseUrl. Use build_debug_apk_for_usb_reverse.ps1 or connect both devices to a separate Wi-Fi router."
    }
}

if (-not (Test-ApiHealth -BaseUrl $ApiBaseUrl)) {
    throw "Cannot build a reliable APK because the API is not reachable: $ApiBaseUrl"
}

Write-Host "Building debug APK with API_BASE_URL=$ApiBaseUrl"

flutter build apk --debug --dart-define=API_BASE_URL=$ApiBaseUrl

$apkPath = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-debug.apk'
$readyApkDir = Join-Path $projectRoot 'READY_APK'
$readyApkPath = Join-Path $readyApkDir 'Kanaf.apk'
New-Item -ItemType Directory -Force -Path $readyApkDir | Out-Null
Copy-Item -Force -Path $apkPath -Destination $readyApkPath

Write-Host "APK ready: $apkPath"
Write-Host "READY_APK copy: $readyApkPath"
