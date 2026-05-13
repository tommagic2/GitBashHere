@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM  Git Bash Here - Build Script (double-click friendly)
REM  
REM  Auto-detects Visual Studio and sets up the compiler environment.
REM  Just double-click this file to build.
REM ============================================================================

cd /d "%~dp0"

echo.
echo ====================================
echo  Git Bash Here - Build
echo ====================================
echo.

REM Check if cl.exe is already available (running from VS command prompt)
where cl.exe >nul 2>&1
if %ERRORLEVEL% equ 0 goto :compiler_ready

echo Searching for Visual Studio...

REM Try VS 2022 first, then 2019
set "VCVARS="

REM VS 2022 Community
if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" set "VCVARS=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat"

REM VS 2022 Professional
if "!VCVARS!"=="" if exist "C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvarsall.bat" set "VCVARS=C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvarsall.bat"

REM VS 2022 Enterprise
if "!VCVARS!"=="" if exist "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" set "VCVARS=C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"

REM VS 2022 BuildTools
if "!VCVARS!"=="" if exist "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" set "VCVARS=C:\Program Files\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"

REM VS 2019 Community
if "!VCVARS!"=="" if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat"

REM VS 2019 Professional
if "!VCVARS!"=="" if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvarsall.bat" set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\VC\Auxiliary\Build\vcvarsall.bat"

REM VS 2019 Enterprise
if "!VCVARS!"=="" if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvarsall.bat" set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\VC\Auxiliary\Build\vcvarsall.bat"

REM VS 2019 BuildTools
if "!VCVARS!"=="" if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" set "VCVARS=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat"

if "!VCVARS!"=="" goto :no_compiler

echo Found: !VCVARS!
echo Loading x64 compiler environment...
call "!VCVARS!" x64 >nul 2>&1

where cl.exe >nul 2>&1
if %ERRORLEVEL% neq 0 goto :no_compiler

:compiler_ready
echo Compiler ready.
echo.

REM Create output directories
if not exist "Release" mkdir Release
if not exist "Release\sparse-pkg" mkdir Release\sparse-pkg

echo [1/6] Compiling DLL...

cl.exe /c /Zi /nologo /W3 /WX- /sdl /O2 ^
    /D WIN32 /D NDEBUG /D _WINDOWS /D _USRDLL /D _WINDLL /D _UNICODE /D UNICODE ^
    /EHsc /MD /GS /Gy /Gd /TP ^
    /Fo"Release\\" /Fd"Release\GitBashHere.pdb" ^
    "handler\dllmain.cpp"

if %ERRORLEVEL% neq 0 goto :compile_failed

echo [2/6] Linking DLL...

link.exe /ERRORREPORT:QUEUE /OUT:"Release\GitBashHere.dll" ^
    /INCREMENTAL:NO /NOLOGO ^
    runtimeobject.lib kernel32.lib user32.lib gdi32.lib ^
    advapi32.lib shell32.lib ole32.lib oleaut32.lib ^
    uuid.lib shlwapi.lib ^
    /DEF:"handler\Source.def" ^
    /MANIFEST:NO ^
    /SUBSYSTEM:WINDOWS /OPT:REF /OPT:ICF ^
    /TLBID:1 /DYNAMICBASE /NXCOMPAT ^
    /IMPLIB:"Release\GitBashHere.lib" ^
    /MACHINE:X64 /DLL ^
    "Release\dllmain.obj"

if %ERRORLEVEL% neq 0 goto :link_failed

echo [3/6] Preparing sparse package...

copy /Y "sparse-pkg\AppxManifest.xml" "Release\sparse-pkg\AppxManifest.xml" >nul

if exist "C:\Program Files\Git\mingw64\share\git\git-for-windows.ico" goto :copy_icon
goto :make_placeholder

:copy_icon
copy /Y "C:\Program Files\Git\mingw64\share\git\git-for-windows.ico" "Release\sparse-pkg\git-bash.png" >nul
echo     Using Git icon from installation.
goto :do_appx

:make_placeholder
echo     Git icon not found at default path. Creating placeholder...
powershell -Command "Add-Type -AssemblyName System.Drawing; $bmp = New-Object System.Drawing.Bitmap 150,150; $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear([System.Drawing.Color]::FromArgb(240,81,51)); $g.Dispose(); $bmp.Save('Release\sparse-pkg\git-bash.png', [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()"
goto :do_appx

:do_appx
echo [4/6] Creating sparse MSIX package...

MakeAppx.exe pack /d "Release\sparse-pkg" /p "Release\GitBashHere.appx" /nv

if %ERRORLEVEL% neq 0 goto :appx_failed

echo [5/6] Creating self-signed certificate...

MakeCert.exe /n "CN=localhost" /r /h 0 /eku "1.3.6.1.5.5.7.3.3,1.3.6.1.4.1.311.10.3.13" /e "12/31/2099" /sv "Release\Key.pvk" "Release\Key.cer"

Pvk2Pfx.exe /pvk "Release\Key.pvk" /spc "Release\Key.cer" /pfx "Release\Key.pfx"

echo [6/6] Signing the sparse package...

SignTool.exe sign /fd SHA256 /a /f "Release\Key.pfx" "Release\GitBashHere.appx"

echo.
echo ====================================
echo  Build Complete!
echo ====================================
echo.
echo Output files in Release\:
echo   - GitBashHere.dll     (the context menu handler)
echo   - GitBashHere.appx    (sparse package for app identity)
echo   - Key.cer             (self-signed certificate)
echo.
echo Next step: Double-click install.cmd
echo.
pause
goto :eof

:no_compiler
echo.
echo ERROR: Visual Studio with C++ workload not found.
echo.
echo Please install one of the following:
echo   - Visual Studio 2022 Community (free) with "Desktop development with C++"
echo   - Visual Studio 2022 Build Tools with "C++ build tools"
echo.
echo Download: https://visualstudio.microsoft.com/downloads/
echo.
pause
exit /b 1

:compile_failed
echo ERROR: Compilation failed.
pause
exit /b 1

:link_failed
echo ERROR: Linking failed.
pause
exit /b 1

:appx_failed
echo ERROR: MakeAppx failed. Make sure the Windows SDK is installed.
pause
exit /b 1
