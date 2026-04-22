# Build script for the IPA Keyboard Windows IME + Companion App.
#
# Usage:
#   .\scripts\build-windows.ps1           # Build both
#   .\scripts\build-windows.ps1 -ImeOnly  # Build IME DLL only
#   .\scripts\build-windows.ps1 -AppOnly  # Build companion app only
#
# Requirements:
#   - Rust toolchain (rustup.rs)
#   - Node.js 18+ and npm
#   - For signing: WINDOWS_SIGNING_CERT_THUMBPRINT env var

param(
    [switch]$ImeOnly,
    [switch]$AppOnly
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$DllName = "ipa_ime_windows.dll"

Write-Host "=== Building IPA Keyboard for Windows ===" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Build IME DLL ---
if (-not $AppOnly) {
    Write-Host "--- Step 1: Building IME DLL ---" -ForegroundColor Yellow

    Push-Location $ProjectRoot
    try {
        cargo build --release -p ipa-ime-windows
        if ($LASTEXITCODE -ne 0) { throw "Cargo build failed" }

        $DllPath = Join-Path $ProjectRoot "target\release\$DllName"
        if (-not (Test-Path $DllPath)) {
            throw "DLL not found at $DllPath"
        }
        Write-Host "DLL: $DllPath"

        # Copy default config next to DLL for bundling
        $ConfigSrc = Join-Path $ProjectRoot "shared-config\default-mappings.json"
        $ConfigDst = Join-Path $ProjectRoot "target\release\default-mappings.json"
        Copy-Item $ConfigSrc $ConfigDst -Force
        Write-Host "Config copied to target\release\"
    }
    finally {
        Pop-Location
    }
    Write-Host ""
}

# --- Step 2: Build Companion App ---
if (-not $ImeOnly) {
    Write-Host "--- Step 2: Building Companion App ---" -ForegroundColor Yellow

    Push-Location (Join-Path $ProjectRoot "companion-app")
    try {
        npm install
        if ($LASTEXITCODE -ne 0) { throw "npm install failed" }

        npm run tauri build
        if ($LASTEXITCODE -ne 0) { throw "Tauri build failed" }
    }
    finally {
        Pop-Location
    }
    Write-Host ""
}

# --- Step 3: Code signing ---
Write-Host "--- Step 3: Code signing ---" -ForegroundColor Yellow

$Thumbprint = $env:WINDOWS_SIGNING_CERT_THUMBPRINT
$TimestampServer = "http://timestamp.digicert.com"

if ($Thumbprint) {
    Write-Host "Signing with certificate: $Thumbprint"

    if (-not $AppOnly) {
        # Sign the DLL
        $DllPath = Join-Path $ProjectRoot "target\release\$DllName"
        & signtool sign /sha1 $Thumbprint /fd SHA256 /tr $TimestampServer /td SHA256 "$DllPath"
        if ($LASTEXITCODE -ne 0) { Write-Warning "DLL signing failed" }
        else { Write-Host "DLL signed." }
    }

    if (-not $ImeOnly) {
        # Sign the MSI (find the latest one)
        $MsiDir = Join-Path $ProjectRoot "companion-app\src-tauri\target\release\bundle\msi"
        $Msi = Get-ChildItem $MsiDir -Filter "*.msi" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($Msi) {
            & signtool sign /sha1 $Thumbprint /fd SHA256 /tr $TimestampServer /td SHA256 "$($Msi.FullName)"
            if ($LASTEXITCODE -ne 0) { Write-Warning "MSI signing failed" }
            else { Write-Host "MSI signed: $($Msi.Name)" }
        }
    }
} else {
    Write-Host "No WINDOWS_SIGNING_CERT_THUMBPRINT set — skipping code signing."
    Write-Host "For production builds, set the env var to your EV cert thumbprint."
}

# --- Summary ---
Write-Host ""
Write-Host "=== Build complete ===" -ForegroundColor Green

if (-not $AppOnly) {
    Write-Host "  IME DLL: target\release\$DllName"
    Write-Host "  Register: .\ime-core\windows\register.ps1"
}
if (-not $ImeOnly) {
    $MsiDir = Join-Path $ProjectRoot "companion-app\src-tauri\target\release\bundle\msi"
    if (Test-Path $MsiDir) {
        $Msi = Get-ChildItem $MsiDir -Filter "*.msi" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($Msi) {
            Write-Host "  Installer: $($Msi.FullName)"
        }
    }
}
