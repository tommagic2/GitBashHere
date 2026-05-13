# ============================================================================
#  Git Bash Here - Install Script
#  
#  Run as Administrator:
#    powershell -ExecutionPolicy Bypass -File install.ps1
#
#  What this does:
#    1. Copies the DLL and sparse package to a permanent install location
#    2. Installs the self-signed certificate to Trusted Root
#    3. Registers the DLL as a COM server
#    4. Registers the sparse MSIX package for app identity
#    5. Restarts Explorer to pick up the changes
# ============================================================================

#Requires -RunAsAdministrator

param(
    [string]$InstallDir = "$env:ProgramFiles\GitBashHere",
    [string]$BuildDir   = "$PSScriptRoot\Release"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host " Git Bash Here - Install" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Verify build output exists
$requiredFiles = @("GitBashHere.dll", "GitBashHere.appx", "Key.cer")
foreach ($file in $requiredFiles) {
    if (-not (Test-Path "$BuildDir\$file")) {
        Write-Host "ERROR: $BuildDir\$file not found. Run build.cmd first." -ForegroundColor Red
        exit 1
    }
}

# Verify Git is installed
if (-not (Test-Path "C:\Program Files\Git\git-bash.exe")) {
    Write-Host "WARNING: Git for Windows not found at the default path." -ForegroundColor Yellow
    Write-Host "If Git is installed elsewhere, edit the paths in handler\dllmain.cpp" -ForegroundColor Yellow
    Write-Host "and rebuild before installing." -ForegroundColor Yellow
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne "y") { exit 0 }
}

# Step 1: Create install directory and copy files
Write-Host "[1/5] Copying files to $InstallDir ..."
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}
Copy-Item "$BuildDir\GitBashHere.dll"  "$InstallDir\" -Force
Copy-Item "$BuildDir\GitBashHere.appx" "$InstallDir\" -Force
Copy-Item "$BuildDir\Key.cer"          "$InstallDir\" -Force

# Step 2: Install the self-signed certificate
Write-Host "[2/5] Installing certificate to Trusted Root ..."
$cert = Import-Certificate -FilePath "$InstallDir\Key.cer" -CertStoreLocation "Cert:\LocalMachine\Root"
Write-Host "       Installed certificate: $($cert.Thumbprint)"

# Step 3: Register the COM DLL
Write-Host "[3/5] Registering COM server ..."
$clsid = "{7B4F26A1-3C9D-4E8B-A5F2-1D6E8C0B9A3F}"
$regPath = "HKLM:\SOFTWARE\Classes\CLSID\$clsid\InProcServer32"

if (Test-Path $regPath) {
    Remove-Item -Path "HKLM:\SOFTWARE\Classes\CLSID\$clsid" -Recurse -Force
}

New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "(Default)" -Value "$InstallDir\GitBashHere.dll"
Set-ItemProperty -Path $regPath -Name "ThreadingModel" -Value "Apartment"

Write-Host "       Registered CLSID: $clsid"

# Step 4: Register the sparse package
Write-Host "[4/5] Registering sparse package ..."

# Remove any previous registration
$existingPkg = Get-AppxPackage -Name "GitBashHere" -ErrorAction SilentlyContinue
if ($existingPkg) {
    Write-Host "       Removing previous registration ..."
    Remove-AppxPackage -Package $existingPkg.PackageFullName
}

# Add the sparse package with external location pointing to our install dir
Add-AppxPackage -Path "$InstallDir\GitBashHere.appx" -ExternalLocation "$InstallDir" -AllowUnsigned

Write-Host "       Sparse package registered."

# Step 5: Restart Explorer
Write-Host "[5/5] Restarting Explorer ..."
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe

Write-Host ""
Write-Host "====================================" -ForegroundColor Green
Write-Host " Installation Complete!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""
Write-Host "Right-click on a folder or in empty space inside a folder."
Write-Host "'Git Bash Here' should now appear in the top-level context menu."
Write-Host ""
Write-Host "To uninstall later, run:" -ForegroundColor Yellow
Write-Host "  powershell -ExecutionPolicy Bypass -File uninstall.ps1" -ForegroundColor Yellow
Write-Host ""
