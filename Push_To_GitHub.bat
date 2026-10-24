@echo off
title Pushing CyberHorde to GitHub...
cd /d "%~dp0"
echo Pushing branch 'main' to GitHub origin...
git push -u origin main
echo.
pause
