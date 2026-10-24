@echo off
title CyberHorde: Rogue Protocol - Launching Game...
cd /d "%~dp0"

set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT_EXE%" (
    set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
)

if not exist "%GODOT_EXE%" (
    echo [ERROR] Could not find Godot executable at "%GODOT_EXE%".
    echo Please verify Godot path.
    pause
    exit /b
)

echo Starting CyberHorde: Rogue Protocol...
"%GODOT_EXE%"
if %ERRORLEVEL% neq 0 (
    echo.
    echo Game exited with error code %ERRORLEVEL%.
    pause
)
