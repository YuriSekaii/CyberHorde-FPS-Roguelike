@echo off
title CyberHorde: Rogue Protocol - Launching Game...
cd /d "%~dp0"
set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"

if not exist "%GODOT_EXE%" (
    echo [ERROR] Could not find Godot executable at "%GODOT_EXE%".
    echo Please verify Godot path.
    pause
    exit /b
)

echo Starting CyberHorde: Rogue Protocol...
start "" "%GODOT_EXE%"
