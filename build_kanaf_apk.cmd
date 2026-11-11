@echo off
setlocal
where pwsh.exe >nul 2>nul
if %errorlevel% equ 0 (
    pwsh.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0frontend\orphan_care_app\scripts\build_fast_apk.ps1" %*
) else (
    powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0frontend\orphan_care_app\scripts\build_fast_apk.ps1" %*
)
exit /b %errorlevel%
