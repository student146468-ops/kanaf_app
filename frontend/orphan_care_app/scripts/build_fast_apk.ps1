param(
    [switch]$Release,
    [ValidateSet('android-arm64', 'android-arm', 'android-x64', 'all')]
    [string]$TargetPlatform = 'android-arm64',
    [string]$ApiBaseUrl = 'https://kanafapp.pythonanywhere.com/api'
)

$ErrorActionPreference = 'Stop'
# Check native exit codes ourselves on both Windows PowerShell 5.1 and PowerShell 7.
$PSNativeCommandUseErrorActionPreference = $false
$projectRoot = Split-Path -Parent $PSScriptRoot
$timer = [System.Diagnostics.Stopwatch]::StartNew()

function Invoke-Flutter {
    param([string[]]$FlutterArguments)

    & $script:flutterCommand @FlutterArguments
    if ($LASTEXITCODE -ne 0) {
        throw "flutter $($FlutterArguments -join ' ') failed (exit code $LASTEXITCODE)."
    }
}

function Test-DependenciesCurrent {
    $pubspec = Join-Path $projectRoot 'pubspec.yaml'
    $lockFile = Join-Path $projectRoot 'pubspec.lock'
    $configFile = Join-Path $projectRoot '.dart_tool/package_config.json'
    $pluginsFile = Join-Path $projectRoot '.flutter-plugins-dependencies'
    foreach ($requiredFile in @($lockFile, $configFile, $pluginsFile)) {
        if (-not (Test-Path -LiteralPath $requiredFile -PathType Leaf)) {
            return $false
        }
    }

    # A new/changed manifest or lockfile requires dependency resolution.
    $manifestTime = (Get-Item -LiteralPath $pubspec).LastWriteTimeUtc
    $lockTime = (Get-Item -LiteralPath $lockFile).LastWriteTimeUtc
    $configTime = (Get-Item -LiteralPath $configFile).LastWriteTimeUtc
    if ($lockTime -lt $manifestTime -or $configTime -lt $manifestTime -or $configTime -lt $lockTime) {
        return $false
    }

    try {
        $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
        if ($config.configVersion -ne 2 -or -not $config.packages -or -not $config.flutterRoot) {
            return $false
        }

        # Copied caches and SDK upgrades must not silently reuse old dependencies.
        $sdkRoot = Split-Path -Parent (Split-Path -Parent $script:flutterCommand)
        $configuredSdk = ([System.Uri]$config.flutterRoot).LocalPath.TrimEnd('\', '/')
        if ($configuredSdk -ne $sdkRoot.TrimEnd('\', '/')) {
            return $false
        }
        $versionFile = Join-Path $sdkRoot 'bin/cache/flutter.version.json'
        if (-not (Test-Path -LiteralPath $versionFile -PathType Leaf)) {
            return $false
        }
        $sdkVersion = Get-Content -LiteralPath $versionFile -Raw | ConvertFrom-Json
        if ($config.flutterVersion -ne $sdkVersion.frameworkVersion -or
            $config.generatorVersion -ne $sdkVersion.dartSdkVersion) {
            return $false
        }

        $configUri = [System.Uri]::new($configFile)
        foreach ($package in $config.packages) {
            $packageUri = [System.Uri]::new($configUri, [string]$package.rootUri)
            if (-not $packageUri.IsFile -or
                -not (Test-Path -LiteralPath $packageUri.LocalPath -PathType Container)) {
                return $false
            }
        }
        return $true
    } catch {
        return $false
    }
}

Push-Location $projectRoot
try {
    $script:flutterCommand = (Get-Command flutter -CommandType Application -ErrorAction Stop |
        Select-Object -First 1).Source
    $apiUri = $null
    if (-not [System.Uri]::TryCreate($ApiBaseUrl, [System.UriKind]::Absolute, [ref]$apiUri) -or
        $apiUri.Scheme -notin @('http', 'https')) {
        throw 'ApiBaseUrl must be an absolute HTTP or HTTPS URL.'
    }
    $ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')
    $mode = if ($Release) { 'release' } else { 'debug' }
    $platforms = if ($TargetPlatform -eq 'all') { 'android-arm,android-arm64,android-x64' } else { $TargetPlatform }
    Write-Host "Building $mode APK for $TargetPlatform with API_BASE_URL=$ApiBaseUrl"
    Write-Host 'Keeping Flutter and Gradle caches. The first Android build can still take several minutes.'

    if (Test-DependenciesCurrent) {
        Write-Host 'Dependencies are current; skipping pub get.'
    } else {
        Write-Host 'Resolving dependencies for this SDK and project...'
        Invoke-Flutter -FlutterArguments @('pub', 'get')
    }

    Invoke-Flutter -FlutterArguments @(
        'build', 'apk', "--$mode", '--no-pub',
        "--target-platform=$platforms", "--dart-define=API_BASE_URL=$ApiBaseUrl"
    )

    # Only publish the artifact after Flutter succeeds. A failed build never copies an old APK.
    $apkPath = Join-Path $projectRoot "build/app/outputs/flutter-apk/app-$mode.apk"
    if (-not (Test-Path -LiteralPath $apkPath -PathType Leaf) -or
        (Get-Item -LiteralPath $apkPath).Length -eq 0) {
        throw "Flutter exited successfully but no valid APK was found at $apkPath."
    }
    $readyDirectory = Join-Path $projectRoot 'READY_APK'
    New-Item -ItemType Directory -Path $readyDirectory -Force | Out-Null
    $readyPath = Join-Path $readyDirectory "Kanaf-$mode-$TargetPlatform.apk"
    Copy-Item -LiteralPath $apkPath -Destination $readyPath -Force
    $timer.Stop()
    Write-Host "APK ready: $readyPath"
    Write-Host "Build output: $apkPath"
    Write-Host ("Completed in {0:N1} seconds." -f $timer.Elapsed.TotalSeconds)
    if ($Release) {
        Write-Host 'Release currently uses the project debug signing key; configure release signing before publishing to an app store.'
    }
} catch {
    $timer.Stop()
    [Console]::Error.WriteLine("APK build failed: $($_.Exception.Message)")
    [Console]::Error.WriteLine('No APK was published by this run. Any existing APK may be from an older build.')
    exit 1
} finally {
    Pop-Location
}
