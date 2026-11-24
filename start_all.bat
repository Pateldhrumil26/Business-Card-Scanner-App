@echo off
title Business Card Scanner Launcher
echo ========================================================
echo   Starting Business Card Scanner ^& Contact Manager
echo ========================================================
echo.

echo [1/2] Starting Backend Server (Port 8080)...
start "Backend Server (Port 8080)" cmd /k "cd /d ""%~dp0backend"" && npm run dev"

echo Waiting 3 seconds for backend to initialize...
timeout /t 3 /nobreak >nul

echo.
echo [2/2] Starting Flutter App...
start "Flutter Application" cmd /k "cd /d ""%~dp0frontend"" && run.bat"

echo.
echo ========================================================
echo   Both Backend and Frontend have been launched!
echo ========================================================
