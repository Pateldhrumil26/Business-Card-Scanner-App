@echo off
setlocal
echo ========================================================
echo   CardScanner Pro - 1-Click Phone Installer & Connector
echo ========================================================

set "ADB=C:\Users\patel\AppData\Local\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" (
    set "ADB=D:\Android\Sdk\platform-tools\adb.exe"
)

echo [1/3] Checking connected Android devices...
"%ADB%" devices
echo.

echo [2/3] Setting up USB reverse port forwarding (8080 & 5050)...
"%ADB%" reverse tcp:8080 tcp:8080
"%ADB%" reverse tcp:5050 tcp:5050
echo Ports 8080 and 5050 forwarded!
echo.

echo [3/3] Installing latest APK to your phone...
"%ADB%" install -r "%~dp0frontend\build\app\outputs\flutter-apk\app-debug.apk"

echo.
echo Launching CardScanner Pro...
"%ADB%" shell monkey -p com.businesscard.scanner.frontend -c android.intent.category.LAUNCHER 1

echo.
echo ========================================================
echo   SUCCESS! CardScanner Pro is now active on your phone.
echo ========================================================
pause
