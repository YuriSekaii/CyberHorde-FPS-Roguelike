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
) else (
    echo [ERROR] Update encountered an error. Please check your network or git status.
)
echo.
pause
