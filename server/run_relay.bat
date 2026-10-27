@echo off
:: Starts the CyberHorde online lobby relay hidden in the background (port 8095, Funnel path /cyberhorde).
:: -S skips site-packages .pth hooks so the relay doesn't load torch on this PC.
cd /d "%~dp0"
powershell -NoProfile -WindowStyle Hidden -Command "if (-not (Get-NetTCPConnection -LocalPort 8095 -State Listen -ErrorAction SilentlyContinue)) { Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = 'C:\Users\PhuNguyen\AppData\Local\Programs\Python\Python311\pythonw.exe -S \"%~dp0lobby_relay.py\"'; CurrentDirectory = '%~dp0'} | Out-Null }"
