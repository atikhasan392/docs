@echo off
title Windows Ultra Deep Cleaner
color 0B

:: Auto-request Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: Record Free Space Before Cleanup
for /f %%a in ('powershell -NoProfile -Command "[math]::Round((Get-PSDrive C).Free / 1GB, 2)"') do set "FREE_BEFORE=%%a"

echo ============================================================
echo   WINDOWS ULTRA DEEP CLEANER (Cache, Locks, Dumps & Logs)
echo ============================================================
echo   Free Space Before Cleanup: %FREE_BEFORE% GB
echo ============================================================
echo.

echo [1/9] Cleaning User & System Temp + Orphaned Lock/Broken Files...
for %%D in ("%TEMP%" "C:\Windows\Temp") do (
    del /s /f /q "%%~D\*.tmp" "%%~D\*.temp" "%%~D\*.lock" "%%~D\*.lck" "%%~D\*.bak" "%%~D\*.old" "%%~D\~*.*" >nul 2>&1
    del /s /f /q "%%~D\*.*" >nul 2>&1
    for /d %%p in ("%%~D\*.*") do rmdir "%%p" /s /q >nul 2>&1
)

echo [2/9] Cleaning Windows Update & Delivery Optimization Cache...
net stop wuauserv >nul 2>&1
net stop bits >nul 2>&1
net stop dosvc >nul 2>&1
del /s /f /q "C:\Windows\SoftwareDistribution\Download\*.*" >nul 2>&1
for /d %%p in ("C:\Windows\SoftwareDistribution\Download\*.*") do rmdir "%%p" /s /q >nul 2>&1
del /s /f /q "C:\Windows\SoftwareDistribution\DeliveryOptimization\*.*" >nul 2>&1
powershell -NoProfile -Command "Delete-DeliveryOptimizationCache -Force" >nul 2>&1
net start wuauserv >nul 2>&1
net start bits >nul 2>&1
net start dosvc >nul 2>&1

echo [3/9] Cleaning Crash Dumps & Windows Error Reporting (WER)...
del /s /f /q "C:\Windows\Minidump\*.*" >nul 2>&1
del /f /q "C:\Windows\MEMORY.DMP" >nul 2>&1
del /s /f /q "%LocalAppData%\CrashDumps\*.*" >nul 2>&1
del /s /f /q "C:\ProgramData\Microsoft\Windows\WER\ReportArchive\*.*" >nul 2>&1
del /s /f /q "C:\ProgramData\Microsoft\Windows\WER\ReportQueue\*.*" >nul 2>&1
del /s /f /q "%LocalAppData%\Microsoft\Windows\WER\*.*" >nul 2>&1

echo [4/9] Cleaning DirectX & GPU Shader Caches (NVIDIA/AMD/Intel)...
del /s /f /q "%LocalAppData%\D3DSCache\*.*" >nul 2>&1
del /s /f /q "%LocalAppData%\NVIDIA\DXCache\*.*" >nul 2>&1
del /s /f /q "%LocalAppData%\NVIDIA\GLCache\*.*" >nul 2>&1
del /s /f /q "%ProgramData%\NVIDIA Corporation\NV_Cache\*.*" >nul 2>&1
del /s /f /q "%LocalAppData%\AMD\DxCache\*.*" >nul 2>&1
del /s /f /q "%LocalAppData%\AMD\GLCache\*.*" >nul 2>&1
del /s /f /q "%LocalAppData%\Intel\ShaderCache\*.*" >nul 2>&1

echo [5/9] Cleaning Prefetch, Thumbnail, Icon & Font Caches...
del /s /f /q "C:\Windows\Prefetch\*.*" >nul 2>&1
del /f /s /q "%LocalAppData%\Microsoft\Windows\Explorer\thumbcache_*.db" >nul 2>&1
del /f /s /q "%LocalAppData%\Microsoft\Windows\Explorer\iconcache_*.db" >nul 2>&1
net stop FontCache >nul 2>&1
del /f /s /q "C:\Windows\ServiceProfiles\LocalService\AppData\Local\FontCache\*FontCache*" >nul 2>&1
net start FontCache >nul 2>&1

echo [6/9] Cleaning All System, Setup, Defender & Event Logs...
del /s /f /q "C:\Windows\Logs\*.*" >nul 2>&1
del /s /f /q "C:\Windows\System32\LogFiles\*.*" >nul 2>&1
del /s /f /q "C:\Windows\Panther\*.log" >nul 2>&1
del /f /q "C:\Windows\INF\setupapi.*.log" >nul 2>&1
del /f /q "C:\Windows\*.log" "C:\Windows\*.tmp" >nul 2>&1
del /s /f /q "C:\ProgramData\Microsoft\Windows Defender\Scans\History\Results\*.*" >nul 2>&1
for /F "tokens=*" %%G in ('wevtutil.exe el') do wevtutil.exe cl "%%G" >nul 2>&1

echo [7/9] Flushing Network, DNS & ARP Caches...
ipconfig /flushdns >nul 2>&1
netsh interface ip delete arpcache >nul 2>&1

echo [8/9] Deep Cleaning WinSxS Component Store (May take 1-2 mins)...
Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase >nul 2>&1

echo [9/9] Emptying Recycle Bin...
powershell -NoProfile -Command "Clear-RecycleBin -Force -ErrorAction SilentlyContinue" >nul 2>&1

:: Record Free Space After Cleanup
for /f %%a in ('powershell -NoProfile -Command "[math]::Round((Get-PSDrive C).Free / 1GB, 2)"') do set "FREE_AFTER=%%a"

echo.
echo ============================================================
echo   ULTRA DEEP CLEANUP COMPLETED!
echo   Free Space Before : %FREE_BEFORE% GB
echo   Free Space After  : %FREE_AFTER% GB
echo ============================================================
pause
exit
