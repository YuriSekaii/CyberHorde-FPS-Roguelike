@echo off
title Opening CyberHorde in Godot Editor...
cd /d "%~dp0"
set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"

if not exist "%GODOT_EXE%" (
    echo [ERROR] Could not find Godot executable at "%GODOT_EXE%".
    echo Please verify Godot path.
    pause
    exit /b
)

echo Opening CyberHorde in Godot Editor...
start "" "%GODOT_EXE%" -e
