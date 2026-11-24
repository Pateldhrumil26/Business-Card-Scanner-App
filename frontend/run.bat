@echo off
set "PATH=E:\flutter\bin;D:\Android\Sdk\platform-tools;%PATH%"
cd /d "%~dp0"
echo ========================================================
echo   Launching Business Card Scanner Flutter Application
echo ========================================================
flutter run --no-enable-impeller
pause
