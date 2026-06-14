# Asset Management Multi-Platform Build Script
# Version management: reads from lib/core/version.dart, auto-increments on build
# Interactive target selection

param(
    [string]$Target = ""   # CLI: android / desktop / all / empty=interactive
)

$ErrorActionPreference = "Stop"
$projectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectDir

$versionFile = "$projectDir/lib/version.dart"

# -- Platform detection --
$isWindows = $PSVersionTable.PSVersion.Major -ge 5 -and [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$isLinux = (-not $isWindows) -and (Get-Variable -Name IsLinux -ErrorAction SilentlyContinue) -and $IsLinux
$isMacOS = (-not $isWindows) -and (Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue) -and $IsMacOS
if (-not $isWindows -and -not $isLinux -and -not $isMacOS) {
    $osName = (uname -s 2>$null)
    if ($osName -match "Linux") { $isLinux = $true }
    elseif ($osName -match "Darwin") { $isMacOS = $true }
}
$platformName = if ($isWindows) { "Windows" } elseif ($isLinux) { "Linux" } elseif ($isMacOS) { "macOS" } else { "Unknown" }

# -- Find Flutter --
function Find-Flutter {
    if ($env:FLUTTER_ROOT) { return $env:FLUTTER_ROOT }
    $candidates = @(
        "$projectDir/../flutter_sdk/flutter"
        "$projectDir/../../flutter_sdk/flutter"
        "$projectDir/../../../flutter_sdk/flutter"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return (Resolve-Path $c).Path }
    }
    $fromPath = (Get-Command flutter -ErrorAction SilentlyContinue).Source
    if ($fromPath) { return (Resolve-Path (Split-Path (Split-Path $fromPath -Parent) -Parent)).Path }
    Write-Error "Flutter not found. Set FLUTTER_ROOT or place flutter_sdk alongside the project."
    exit 1
}

$flutterDir = Find-Flutter
$flutterBin = if ($isWindows) { "$flutterDir/bin/flutter.bat" } else { "$flutterDir/bin/flutter" }

# -- Build functions --
function Build-Android {
    Write-Output ""
    Write-Output "=== Building Android APK ==="
    & $flutterBin build apk --release --android-skip-build-dependency-validation
    if ($LASTEXITCODE -ne 0) { throw "Android build failed" }
    Write-Output "[OK] Android APK built"
}

function Build-Windows {
    Write-Output ""
    Write-Output "=== Building Windows EXE ==="
    & $flutterBin build windows --release
    if ($LASTEXITCODE -ne 0) { throw "Windows build failed" }
    Write-Output "[OK] Windows EXE built"
}

function Build-Linux {
    Write-Output ""
    Write-Output "=== Building Linux App ==="
    & $flutterBin build linux --release
    if ($LASTEXITCODE -ne 0) { throw "Linux build failed" }
    Write-Output "[OK] Linux App built"
}

function Build-MacOS {
    Write-Output ""
    Write-Output "=== Building macOS App ==="
    & $flutterBin build macos --release
    if ($LASTEXITCODE -ne 0) { throw "macOS build failed" }
    Write-Output "[OK] macOS App built"
}

function Package-Android {
    param([string]$version)
    $apkSource = Join-Path $projectDir "build/app/outputs/flutter-apk/app-release.apk"
    $apkDest = Join-Path $projectDir "AssetManagement_v${version}.apk"
    if (-not (Test-Path $apkSource)) { throw "APK not found at $apkSource" }
    Copy-Item $apkSource $apkDest -Force -ErrorAction Stop
    Write-Output "[OK] APK -> AssetManagement_v${version}.apk"
}

function Package-Windows {
    param([string]$version)
    $winSource = "$projectDir/build/windows/x64/runner/Release"
    $zipDest = "$projectDir/AssetManagement_v${version}_win64.zip"
    if (Test-Path $zipDest) { Remove-Item $zipDest -Force }
    Compress-Archive -Path "$winSource/*" -DestinationPath $zipDest -Force
    Write-Output "[OK] ZIP -> AssetManagement_v${version}_win64.zip"
}

function Package-Linux {
    param([string]$version)
    $tarDest = "$projectDir/AssetManagement_v${version}_linux64.tar.gz"
    if (Test-Path $tarDest) { Remove-Item $tarDest -Force }
    tar -czf $tarDest -C "$projectDir/build/linux/x64/release" bundle
    Write-Output "[OK] TAR -> AssetManagement_v${version}_linux64.tar.gz"
}

function Package-MacOS {
    param([string]$version)
    $macosSource = "$projectDir/build/macos/Build/Products/Release"
    $zipDest = "$projectDir/AssetManagement_v${version}_macos.zip"
    if (Test-Path $zipDest) { Remove-Item $zipDest -Force }
    Compress-Archive -Path "$macosSource/asset_management.app" -DestinationPath $zipDest -Force
    Write-Output "[OK] ZIP -> AssetManagement_v${version}_macos.zip"
}

# -- Interactive menu --
function Show-Menu {
    param([string]$platform)
    Clear-Host
    Write-Host "=========================================="
    Write-Host "  Asset Management - Build Menu"
    Write-Host "  Platform: $platform"
    Write-Host "=========================================="
    Write-Host ""
    Write-Host "  [1] Android APK"
    Write-Host "  [2] $platform Desktop App"
    Write-Host "  [3] Android + $platform Desktop"
    if ($platform -eq "macOS") {
        Write-Host "  [4] iOS (ipa)"
        Write-Host "  [5] Android + iOS"
        Write-Host "  [6] All (Android + iOS + macOS)"
    }
    Write-Host "  [0] Exit"
    Write-Host ""
    $choice = Read-Host "Select target"
    return $choice
}

# -- Normalize user input (handle typos and variants) --
function Normalize-Choice {
    param([string]$raw)
    $lower = $raw.Trim().ToLower()
    $map = @{
        "1" = "1"; "android" = "android"; "andriod" = "android"
        "2" = "2"; "desktop" = "desktop"; "windows" = "desktop"; "linux" = "desktop"; "macos" = "desktop"
        "3" = "3"; "both" = "3"
        "4" = "4"; "ios" = "4"
        "5" = "5"
        "6" = "6"
        "0" = "0"; "exit" = "0"; "quit" = "0"
        "all" = "all"
    }
    if ($map.ContainsKey($lower)) { return $map[$lower] }
    return $null
}

# -- Version management (read from lib/core/version.dart) --
function Get-CurrentVersion {
    if (-not (Test-Path $versionFile)) {
        Write-Error "Version file not found: $versionFile"
        exit 1
    }
    $versionContent = Get-Content $versionFile -Raw
    if ($versionContent -match "version\s*=\s*'([0-9]+\.[0-9]+\.[0-9]+)'") {
        return $matches[1]
    }
    return "0.0.1"
}

# -- Bump version (patch +1) --
function Bump-Patch {
    param([string]$currentVersion)
    $verParts = $currentVersion -split '\.'
    $patch = [int]$verParts[2] + 1
    return "$($verParts[0]).$($verParts[1]).$patch"
}

# -- Update version.dart file --
function Update-VersionFile {
    param([string]$version)
    $versionContent = Get-Content $versionFile -Raw
    $versionContent = $versionContent -replace "(version\s*=\s*)'[0-9]+\.[0-9]+\.[0-9]+'", "`$1'$version'"
    Set-Content -Path $versionFile -Value $versionContent -Encoding UTF8
}

# -- Main --
function Main {
    $choice = $Target
    if (-not $choice) {
        while ($true) {
            $raw = Show-Menu $platformName
            $choice = Normalize-Choice $raw
            if ($choice) { break }
            Write-Host "Invalid input '$raw'. Please enter a number (0-3) or a target name."
            Start-Sleep -Seconds 2
        }
    } else {
        $choice = Normalize-Choice $choice
        if (-not $choice) {
            Write-Error "Unknown target: $Target"
            Write-Error "Valid targets: android, desktop, all, or a menu number (1-3)"
            exit 1
        }
    }

    $currentVersion = Get-CurrentVersion

    Write-Host "=========================================="
    Write-Host "  AssetManagement Build v$currentVersion"
    Write-Host "  Platform: $platformName"
    Write-Host "=========================================="

    try {
        switch ($choice) {
            "1" {
                Build-Android
                Package-Android $currentVersion
            }
            "2" {
                if ($isWindows) { Build-Windows; Package-Windows $currentVersion }
                elseif ($isLinux) { Build-Linux; Package-Linux $currentVersion }
                elseif ($isMacOS) { Build-MacOS; Package-MacOS $currentVersion }
            }
            "3" {
                Build-Android; Package-Android $currentVersion
                if ($isWindows) { Build-Windows; Package-Windows $currentVersion }
                elseif ($isLinux) { Build-Linux; Package-Linux $currentVersion }
                elseif ($isMacOS) { Build-MacOS; Package-MacOS $currentVersion }
            }
            "4" {
                if (-not $isMacOS) { throw "iOS builds are only supported on macOS" }
                Write-Output ""
                Write-Output "=== Building iOS ==="
                & $flutterBin build ios --release --no-codesign
                if ($LASTEXITCODE -ne 0) { throw "iOS build failed" }
                Write-Output "[OK] iOS built"
            }
            "5" {
                if (-not $isMacOS) { throw "iOS builds are only supported on macOS" }
                Build-Android; Package-Android $currentVersion
                Write-Output ""
                Write-Output "=== Building iOS ==="
                & $flutterBin build ios --release --no-codesign
                if ($LASTEXITCODE -ne 0) { throw "iOS build failed" }
                Write-Output "[OK] iOS built"
            }
            "6" {
                if (-not $isMacOS) { throw "iOS/macOS builds are only supported on macOS" }
                Build-Android; Package-Android $currentVersion
                Write-Output ""
                Write-Output "=== Building iOS ==="
                & $flutterBin build ios --release --no-codesign
                if ($LASTEXITCODE -ne 0) { throw "iOS build failed" }
                Write-Output "[OK] iOS built"
                Build-MacOS; Package-MacOS $currentVersion
            }
            "0" {
                Write-Output "Exited"
                exit 0
            }
            "all" {
                Build-Android; Package-Android $currentVersion
                if ($isWindows) { Build-Windows; Package-Windows $currentVersion }
                elseif ($isLinux) { Build-Linux; Package-Linux $currentVersion }
                elseif ($isMacOS) { Build-MacOS; Package-MacOS $currentVersion }
            }
            "android" {
                Build-Android; Package-Android $currentVersion
            }
            "desktop" {
                if ($isWindows) { Build-Windows; Package-Windows $currentVersion }
                elseif ($isLinux) { Build-Linux; Package-Linux $currentVersion }
                elseif ($isMacOS) { Build-MacOS; Package-MacOS $currentVersion }
            }
            default {
                throw "Unknown option: $choice"
            }
        }

        $newVersion = Bump-Patch $currentVersion
        Update-VersionFile $newVersion
        Write-Output ""
        Write-Output "=========================================="
        Write-Output "  Done! v$currentVersion -> v$newVersion (next)"
        Write-Output "=========================================="
    } catch {
        Write-Output "[FAIL] $_"
        exit 1
    }
}

Main