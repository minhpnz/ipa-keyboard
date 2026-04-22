# Register/unregister the IPA Keyboard IME DLL as a COM server.
#
# Usage:
#   .\register.ps1              # Register (requires admin for HKLM, or uses HKCU)
#   .\register.ps1 -Unregister  # Unregister
#
# The DLL supports self-registration via regsvr32, so this script is a
# convenience wrapper. For MSI-based installs, use regsvr32 directly.

param(
    [switch]$Unregister
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DllName = "ipa_ime_windows.dll"

# Look for the DLL in common build output locations
$SearchPaths = @(
    (Join-Path $ScriptDir "..\..\target\release\$DllName"),
    (Join-Path $ScriptDir "..\..\target\debug\$DllName"),
    (Join-Path $ScriptDir "$DllName")
)

$DllPath = $null
foreach ($p in $SearchPaths) {
    $resolved = [System.IO.Path]::GetFullPath($p)
    if (Test-Path $resolved) {
        $DllPath = $resolved
        break
    }
}

if (-not $DllPath) {
    Write-Error "Could not find $DllName. Build the project first with: cargo build --release -p ipa-ime-windows"
    exit 1
}

Write-Host "DLL: $DllPath"

if ($Unregister) {
    Write-Host "Unregistering..."
    $result = & regsvr32 /u /s "$DllPath" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "regsvr32 /u returned exit code $LASTEXITCODE"
        Write-Host $result
    } else {
        Write-Host "Unregistered successfully."
    }
} else {
    Write-Host "Registering..."
    $result = & regsvr32 /s "$DllPath" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "regsvr32 returned exit code $LASTEXITCODE"
        Write-Host $result
        Write-Host ""
        Write-Host "If you get access denied, try running as Administrator."
    } else {
        Write-Host "Registered successfully."
        Write-Host ""
        Write-Host "The IPA Keyboard input method should now appear in:"
        Write-Host "  Settings > Time & Language > Language & Region > Keyboard"
        Write-Host ""
        Write-Host "You may need to log out and back in for it to appear."
    }
}
