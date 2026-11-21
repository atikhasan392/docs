@echo off
title Windows Deep Cleaner
color 0A

:: Auto-request Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ==================================================
echo   Windows Temporary Files, Cache & Logs Cleaner
echo ==================================================
echo.

echo [1/7] Cleaning User Temp files...
del /s /f /q "%TEMP%\*.*" >nul 2>&1
for /d %%p in ("%TEMP%\*.*") do rmdir "%%p" /s /q >nul 2>&1

echo [2/7] Cleaning Windows System Temp files...
del /s /f /q "C:\Windows\Temp\*.*" >nul 2>&1
for /d %%p in ("C:\Windows\Temp\*.*") do rmdir "%%p" /s /q >nul 2>&1

echo [3/7] Cleaning Prefetch files...
del /s /f /q "C:\Windows\Prefetch\*.*" >nul 2>&1

echo [4/7] Cleaning Windows Update Cache...
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
del /s /f /q "C:\Windows\SoftwareDistribution\Download\*.*" >nul 2>&1
for /d %%p in ("C:\Windows\SoftwareDistribution\Download\*.*") do rmdir "%%p" /s /q >nul 2>&1
net start wuauserv >nul 2>&1
net start bits >nul 2>&1

echo [5/7] Cleaning Windows Log & Temp files (.log / .tmp)...
del /s /f /q "C:\Windows\Logs\*.*" >nul 2>&1
del /s /f /q "C:\Windows\System32\LogFiles\*.*" >nul 2>&1
del /s /f /q "C:\Windows\*.log" >nul 2>&1
del /s /f /q "C:\Windows\*.tmp" >nul 2>&1

echo [6/7] Clearing all Windows Event Logs...
for /F "tokens=*" %%G in ('wevtutil.exe el') do (
    wevtutil.exe cl "%%G" >nul 2>&1
)

echo [7/7] Flushing DNS Cache, Thumbnails & Recycle Bin...
ipconfig /flushdns >nul 2>&1
del /f /s /q "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
powershell -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1

echo.
echo ==================================================
echo   Cleanup Completed Successfully!
echo ==================================================
timeout /t 3 >nul
exit
