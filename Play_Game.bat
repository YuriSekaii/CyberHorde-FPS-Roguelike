@echo off
title CyberHorde: Rogue Protocol - Launching Game...
cd /d "%~dp0"

set "GODOT_EXE="

:: 1. Check current directory for Godot executable
for %%i in ("%~dp0*godot*console*.exe" "%~dp0*godot*.exe" "%~dp0godot.exe") do (
    if exist "%%~i" if not defined GODOT_EXE set "GODOT_EXE=%%~i"
)

:: 2. Check system PATH
if not defined GODOT_EXE (
    for /f "tokens=*" %%i in ('where godot 2^>nul') do (
        if not defined GODOT_EXE set "GODOT_EXE=%%~i"
    )
)

:: 3. Check fallback / default locations
if not defined GODOT_EXE (
    if exist "D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" (
        set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
    ) else if exist "D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" (
        set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
    )
)

if not defined GODOT_EXE (
    echo [ERROR] Could not find Godot executable in current folder, PATH, or default path.
    echo Please place a Godot executable in this folder or verify Godot path.
    pause
    exit /b
)

echo Starting CyberHorde: Rogue Protocol using: "%GODOT_EXE%"...
"%GODOT_EXE%"
if %ERRORLEVEL% neq 0 (
    echo.
    echo Game exited with error code %ERRORLEVEL%.
    pause
)
