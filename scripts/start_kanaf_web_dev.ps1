param(
    [switch]$BackendOnly,
    [int]$WebPort = 53610
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $repoRoot 'backend\orphan_care_backend'
$frontendRoot = Join-Path $repoRoot 'frontend\orphan_care_app'
$backendUrl = 'http://127.0.0.1:8000'
$apiBaseUrl = "$backendUrl/api"

function Get-WorkingPython {
    $venvPython = Join-Path $backendRoot 'venv\Scripts\python.exe'
    if (Test-Path $venvPython) {
        try {
            & $venvPython --version *> $null
            if ($LASTEXITCODE -eq 0) {
                return $venvPython
            }
        } catch {
            Write-Warning 'Local backend venv is not usable; falling back to system Python.'
        }
    }

    return 'python'
}

function Test-BackendHealth {
    try {
        $response = Invoke-RestMethod -Uri "$apiBaseUrl/health/" -Method Get -TimeoutSec 4
        return $response.status -eq 'ok'
    } catch {
        return $false
    }
}

$python = Get-WorkingPython

$env:DEBUG = 'debug'
$env:SECRET_KEY = 'django-insecure-kanaf-local-development-key-change-before-production'
$env:ALLOWED_HOSTS = 'localhost,127.0.0.1,0.0.0.0'
$env:CSRF_TRUSTED_ORIGINS = 'http://localhost:8000,http://127.0.0.1:8000,http://localhost:53610,http://127.0.0.1:53610'
$env:CORS_ALLOWED_ORIGIN_REGEXES = '^http://localhost:\d+$,^http://127\.0\.0\.1:\d+$'

Write-Host "Using Python: $python"
Write-Host 'Applying backend migrations...'
Push-Location $backendRoot
try {
    & $python manage.py migrate --noinput
} finally {
    Pop-Location
}

if (Test-BackendHealth) {
    Write-Host "Backend is already healthy at $backendUrl"
} else {
    Write-Host "Starting Kanaf backend at $backendUrl ..."
    $backendOut = Join-Path $backendRoot 'runserver.out'
    $backendErr = Join-Path $backendRoot 'runserver.err'
    Start-Process `
        -FilePath $python `
        -ArgumentList @('manage.py', 'runserver', '127.0.0.1:8000', '--noreload') `
        -WorkingDirectory $backendRoot `
        -RedirectStandardOutput $backendOut `
        -RedirectStandardError $backendErr `
        -WindowStyle Hidden

    $isHealthy = $false
    for ($attempt = 1; $attempt -le 20; $attempt++) {
        Start-Sleep -Milliseconds 500
        if (Test-BackendHealth) {
            $isHealthy = $true
            break
        }
    }

    if (-not $isHealthy) {
        Write-Error "Backend did not become healthy. Check: $backendErr"
    }
}

if ($BackendOnly) {
    Write-Host "Backend is ready at $backendUrl"
    exit 0
}

Write-Host "Starting Flutter web with API_BASE_URL=$apiBaseUrl"
Push-Location $frontendRoot
try {
    flutter run -d chrome --web-port $WebPort --dart-define=API_BASE_URL=$apiBaseUrl
} finally {
    Pop-Location
}
