@echo off
title CyberHorde: Rogue Protocol - 2-Player Co-op Test Launcher
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
    echo [ERROR] Could not find Godot executable in current folder, PATH, or default path.
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

if "%NEED_IMPORT%"=="1" (
    echo ========================================================
    echo  First-Time Setup: Importing / Rendering game assets...
    echo ========================================================
    "%GODOT_IMPORT_EXE%" --headless --editor --quit --path "%~dp0."
    echo  Asset import completed!
    echo ========================================================
)

echo ===================================================
echo  CyberHorde: Rogue Protocol - 2-Player Co-op Test
echo  Using Godot: "%GODOT_EXE%"
echo ===================================================
echo Launching Instance 1 (Host / Player 1)...
start "CyberHorde Player 1" "%GODOT_EXE%" --resolution 960x540 --position 50,100

timeout /t 2 /nobreak >nul

echo Launching Instance 2 (Client / Player 2)...
start "CyberHorde Player 2" "%GODOT_EXE%" --resolution 960x540 --position 1050,100

echo.
echo ===================================================
echo  Both instances launched!
echo  1. In Window 1: Click "HOST CO-OP MISSION (SERVER)"
echo  2. In Window 2: Click "JOIN CO-OP MISSION (CLIENT)" -> "CONNECT TO SQUAD"
echo  3. In Window 1: Click "LAUNCH SQUAD MISSION (2 PLAYERS)"
echo ===================================================
timeout /t 5
