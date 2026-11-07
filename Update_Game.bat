@echo off
title Updating CyberHorde: Rogue Protocol...
cd /d "%~dp0"
call "%~dp0toolsensure_git.bat"
echo ===================================================
echo  CyberHorde: Rogue Protocol - Updater (git pull)
echo ===================================================
echo Fetching and pulling latest updates from GitHub...
git pull origin main
echo.
if %ERRORLEVEL% equ 0 (
    echo [SUCCESS] Game updated to latest version!
    set "GODOT_IMPORT_EXE="
    for %%i in ("%~dp0*godot*console*.exe" "%~dp0*godot*.exe" "%~dp0godot.exe") do (
        if exist "%%~i" if not defined GODOT_IMPORT_EXE set "GODOT_IMPORT_EXE=%%~i"
    )
    if defined GODOT_IMPORT_EXE (
        echo Re-importing assets in background...
        echo "%GODOT_IMPORT_EXE%" | findstr /i "console" >nul
        if %ERRORLEVEL% equ 0 (
            "%GODOT_IMPORT_EXE%" --headless --editor --quit --path "%~dp0." >nul 2>&1
        ) else (
            start /wait "" "%GODOT_IMPORT_EXE%" --headless --editor --quit --path "%~dp0." >nul 2>&1
        )
        echo [DONE] Asset import completed!
    )
) else (
    echo [ERROR] Update encountered an error. Please check your network or git status.
)
echo.
pause
