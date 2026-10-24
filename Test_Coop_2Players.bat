@echo off
title CyberHorde: Rogue Protocol - 2-Player Co-op Test Launcher
cd /d "%~dp0"

set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT_EXE%" (
    set "GODOT_EXE=D:\Program File\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
)

if not exist "%GODOT_EXE%" (
    echo [ERROR] Could not find Godot executable at "%GODOT_EXE%".
    pause
    exit /b
)

echo ===================================================
echo  CyberHorde: Rogue Protocol - 2-Player Co-op Test
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
