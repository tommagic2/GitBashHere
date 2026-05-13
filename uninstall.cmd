@echo off
REM ============================================================================
REM  Git Bash Here - Uninstall (double-click friendly)
REM  
REM  This script self-elevates to Administrator and runs uninstall.ps1
REM ============================================================================

REM Check if already running as admin
net session >nul 2>&1
if %ERRORLEVEL% equ 0 goto :run_uninstall

REM Not admin - relaunch elevated
echo Requesting Administrator privileges...
powershell -Command "Start-Process cmd.exe -ArgumentList '/c cd /d \"%~dp0\" && powershell -ExecutionPolicy Bypass -File \"%~dp0uninstall.ps1\" && pause' -Verb RunAs"
goto :eof

:run_uninstall
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1"
pause
