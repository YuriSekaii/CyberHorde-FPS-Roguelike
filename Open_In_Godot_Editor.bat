@echo off
title Opening CyberHorde in Godot Editor...
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

echo Opening CyberHorde in Godot Editor using: "%GODOT_EXE%"...
"%GODOT_EXE%" -e
if %ERRORLEVEL% neq 0 (
    echo.
    echo Editor closed with error code %ERRORLEVEL%.
    pause
)
