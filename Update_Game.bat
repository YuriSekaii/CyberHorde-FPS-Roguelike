@echo off
title Updating CyberHorde: Rogue Protocol...
cd /d "%~dp0"
echo ===================================================
echo  CyberHorde: Rogue Protocol - Updater (git pull)
echo ===================================================
echo Fetching and pulling latest updates from GitHub...
git pull origin main
echo.
if %ERRORLEVEL% equ 0 (
    echo [SUCCESS] Game updated to latest version!
    set "GODOT_EXE="
    for %%i in ("%~dp0*godot*console*.exe" "%~dp0*godot*.exe" "%~dp0godot.exe") do (
        if exist "%%~i" if not defined GODOT_EXE set "GODOT_EXE=%%~i"
    )
    if defined GODOT_EXE (
        echo Re-importing assets...
        "%GODOT_EXE%" --headless --editor --quit >nul 2>&1
    )
) else (
    echo [ERROR] Update encountered an error. Please check your network or git status.
)
echo.
pause
