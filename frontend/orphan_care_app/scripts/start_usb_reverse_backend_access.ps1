$ErrorActionPreference = 'Stop'

$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) {
    $sdkAdb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
    if (Test-Path $sdkAdb) {
        $adb = [pscustomobject]@{ Source = $sdkAdb }
    }
}

if (-not $adb) {
    throw 'adb.exe was not found. Install Android platform-tools or add adb to PATH.'
}

$devices = & $adb.Source devices
$deviceLines = $devices | Where-Object { $_ -match "`tdevice$" }
if (-not $deviceLines) {
    throw 'No authorized Android device found. Connect the phone by USB, enable USB debugging, and accept the authorization prompt.'
}

& $adb.Source reverse tcp:8000 tcp:8000
Write-Host 'USB reverse is active: Android http://127.0.0.1:8000 -> laptop http://127.0.0.1:8000'
Write-Host 'The USB debug APK should use: http://127.0.0.1:8000/api'
