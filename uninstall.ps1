# ============================================================================
#  Git Bash Here - Uninstall Script
#  
#  Run as Administrator:
#    powershell -ExecutionPolicy Bypass -File uninstall.ps1
# ============================================================================

#Requires -RunAsAdministrator

param(
    [string]$InstallDir = "$env:ProgramFiles\GitBashHere"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host " Git Bash Here - Uninstall" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Remove the sparse package
Write-Host "[1/4] Removing sparse package ..."
$existingPkg = Get-AppxPackage -Name "GitBashHere" -ErrorAction SilentlyContinue
if ($existingPkg) {
    Remove-AppxPackage -Package $existingPkg.PackageFullName
    Write-Host "       Removed."
} else {
    Write-Host "       Not found (already removed)."
}

# Step 2: Remove COM registration
Write-Host "[2/4] Removing COM registration ..."
$clsid = "{7B4F26A1-3C9D-4E8B-A5F2-1D6E8C0B9A3F}"
$regPath = "HKLM:\SOFTWARE\Classes\CLSID\$clsid"
if (Test-Path $regPath) {
    Remove-Item -Path $regPath -Recurse -Force
    Write-Host "       Removed CLSID: $clsid"
} else {
    Write-Host "       Not found (already removed)."
}

# Step 3: Remove the certificate
Write-Host "[3/4] Removing certificate ..."
$certs = Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object { $_.Subject -eq "CN=localhost" -and $_.NotAfter -gt (Get-Date) }
if ($certs) {
    foreach ($cert in $certs) {
        Remove-Item -Path "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -Force
        Write-Host "       Removed certificate: $($cert.Thumbprint)"
    }
} else {
    Write-Host "       No matching certificates found."
}

# Step 4: Remove install directory
Write-Host "[4/4] Removing files ..."
if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Host "       Removed $InstallDir"
} else {
    Write-Host "       Directory not found."
}

# Restart Explorer
Write-Host ""
Write-Host "Restarting Explorer ..."
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process explorer.exe

Write-Host ""
Write-Host "====================================" -ForegroundColor Green
Write-Host " Uninstall Complete!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""
