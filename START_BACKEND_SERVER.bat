@echo off
title CardScanner Backend Server ^& USB Bridge
color 0A
echo ========================================================
echo   Starting Business Card Scanner Backend Server
echo ========================================================
echo.

echo [1/2] Connecting to Mobile Phone over USB on Port 8080...
"D:\Android\Sdk\platform-tools\adb.exe" reverse tcp:8080 tcp:8080
if %ERRORLEVEL% equ 0 (
    echo [SUCCESS] Phone USB port 8080 forwarded to PC!
) else (
    echo [NOTE] USB check finished.
)

echo.
echo [2/2] Starting Node.js / TypeScript Server on Port 8080...
echo ========================================================
echo   DO NOT CLOSE THIS WINDOW WHILE USING THE APP!
echo ========================================================
echo.
cd /d "%~dp0backend"
npm run dev

pause
