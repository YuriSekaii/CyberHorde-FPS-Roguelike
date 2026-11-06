@echo off
title CyberHorde: Rogue Protocol - Launching Game...
cd /d "%~dp0"

set "GODOT_EXE="

:: 1. Check current directory for already extracted Godot executable
for %%i in ("%~dp0*godot*console*.exe" "%~dp0*godot*.exe" "%~dp0godot.exe") do (
    if exist "%%~i" if not defined GODOT_EXE set "GODOT_EXE=%%~i"
)

:: 2. If not found, check if bundled engine.zip exists and auto-extract it (one-time setup)
if not defined GODOT_EXE if exist "%~dp0engine.zip" (
    echo ========================================================
    echo  First-Time Setup: Unpacking bundled Godot Engine...
    echo ========================================================
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory('%~dp0engine.zip', '%~dp0')"
    for %%i in ("%~dp0*godot*console*.exe" "%~dp0*godot*.exe" "%~dp0godot.exe") do (
        if exist "%%~i" if not defined GODOT_EXE set "GODOT_EXE=%%~i"
    )
)

:: 3. Check system PATH
if not defined GODOT_EXE (
    for /f "tokens=*" %%i in ('where godot 2^>nul') do (
        if not defined GODOT_EXE set "GODOT_EXE=%%~i"
    )
)

:: 4. Check fallback default install location
if not defined GODOT_EXE (
    if exist "D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" (
        set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
    ) else if exist "D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" (
        set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
    )
)

if not defined GODOT_EXE (
    echo [ERROR] Could not find Godot executable.
    echo Please make sure engine.zip is present or verify Godot installation.
    pause
    exit /b
)

:: Set Godot import binary (prefer console executable for clean headless background execution)
set "GODOT_IMPORT_EXE=%GODOT_EXE%"
for %%i in ("%~dp0*godot*console*.exe") do (
    if exist "%%~i" set "GODOT_IMPORT_EXE=%%~i"
)

:: 5. Ensure assets are imported and rendered into .godot/ before launching
set "NEED_IMPORT=0"
if not exist "%~dp0.godot\imported\" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\global_script_class_cache.cfg" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\imported\*.ctex" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\imported\icon.svg-*.ctex" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\imported\medic_restore.svg-*.ctex" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\imported\rogue_dash.svg-*.ctex" set "NEED_IMPORT=1"
if not exist "%~dp0.godot\imported\gunner_berserk.svg-*.ctex" set "NEED_IMPORT=1"
if not exist "%~dp0icon.svg.import" set "NEED_IMPORT=1"
if not exist "%~dp0assets\icons\skills\medic_restore.svg.import" set "NEED_IMPORT=1"
if not exist "%~dp0assets\icons\skills\rogue_dash.svg.import" set "NEED_IMPORT=1"
if not exist "%~dp0assets\icons\skills\gunner_berserk.svg.import" set "NEED_IMPORT=1"

for /f %%c in ('git -C "%~dp0." rev-parse HEAD 2^>nul') do set "CUR_COMMIT=%%c"
if exist "%~dp0.godot\last_import_commit.txt" set /p LAST_COMMIT=<"%~dp0.godot\last_import_commit.txt"
if defined CUR_COMMIT if not "%CUR_COMMIT%"=="%LAST_COMMIT%" set "NEED_IMPORT=1"

if "%NEED_IMPORT%"=="1" (
    echo ========================================================
    echo  Importing / Rendering game assets...
    echo ========================================================
    "%GODOT_IMPORT_EXE%" --headless --path "%~dp0." --import
    echo  Asset import completed!
    echo ========================================================
    if defined CUR_COMMIT if exist "%~dp0.godot\" >"%~dp0.godot\last_import_commit.txt" echo %CUR_COMMIT%
)

echo Starting CyberHorde: Rogue Protocol using: "%GODOT_EXE%"...
"%GODOT_EXE%"
if %ERRORLEVEL% neq 0 (
    echo.
    echo Game exited with error code %ERRORLEVEL%.
    pause
)
