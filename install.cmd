@echo off
REM ============================================================================
REM  Git Bash Here - Install (double-click friendly)
REM  
REM  This script self-elevates to Administrator and runs install.ps1
REM ============================================================================

REM Check if already running as admin
net session >nul 2>&1
if %ERRORLEVEL% equ 0 goto :run_install

REM Not admin - relaunch elevated
echo Requesting Administrator privileges...
powershell -Command "Start-Process cmd.exe -ArgumentList '/c cd /d \"%~dp0\" && powershell -ExecutionPolicy Bypass -File \"%~dp0install.ps1\" && pause' -Verb RunAs"
goto :eof

:run_install
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
