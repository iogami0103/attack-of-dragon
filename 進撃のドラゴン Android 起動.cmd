@echo off
setlocal

set "SOURCE_DIR=D:\shingeki_dragon"
set "PROJECT_DIR=D:\shingeki_dragon_release"
set "RTK=C:\Users\iogam\bin\rtk.exe"
set "PACKAGE_NAME=com.example.shingeki_dragon"
set "USB_SERIAL=2A271FDH300GLX"
set "DEVICE_IP=192.168.1.6"
set "ADB_PORT=5555"
set "NETWORK_SERIAL=%DEVICE_IP%:%ADB_PORT%"
set "TARGET_SERIAL="

if not exist "%RTK%" (
  echo rtk.exe was not found:
  echo   %RTK%
  pause
  exit /b 1
)

if not exist "%SOURCE_DIR%\pubspec.yaml" (
  echo Flutter project was not found:
  echo   %SOURCE_DIR%
  pause
  exit /b 1
)

"%RTK%" flutter --version >nul 2>nul
if errorlevel 1 (
  echo Flutter could not be started through rtk.exe.
  pause
  exit /b 1
)

"%RTK%" adb version >nul 2>nul
if errorlevel 1 (
  echo adb could not be started through rtk.exe.
  pause
  exit /b 1
)

"%RTK%" adb start-server >nul 2>nul

for /f "skip=1 tokens=1,2" %%A in ('"%RTK%" adb devices') do (
  if "%%A"=="%USB_SERIAL%" if "%%B"=="device" (
    "%RTK%" adb -s %USB_SERIAL% tcpip %ADB_PORT% >nul 2>nul
  )
)

"%RTK%" adb connect %NETWORK_SERIAL% >nul 2>nul

for /f "skip=1 tokens=1,2" %%A in ('"%RTK%" adb devices') do (
  if "%%A"=="%NETWORK_SERIAL%" if "%%B"=="device" set "TARGET_SERIAL=%NETWORK_SERIAL%"
)

if not defined TARGET_SERIAL (
  for /f "skip=1 tokens=1,2" %%A in ('"%RTK%" adb devices') do (
    if "%%A"=="%USB_SERIAL%" if "%%B"=="device" set "TARGET_SERIAL=%USB_SERIAL%"
  )
)

if not defined TARGET_SERIAL (
  for /f "skip=1 tokens=1,2" %%A in ('"%RTK%" adb devices') do (
    if "%%B"=="device" if not defined TARGET_SERIAL set "TARGET_SERIAL=%%A"
  )
)

if not defined TARGET_SERIAL (
  echo Could not find the Android device.
  echo.
  echo Current adb devices:
  "%RTK%" adb devices
  echo.
  echo Make sure the phone is on the same Wi-Fi network.
  echo If the phone was restarted or changed networks, reconnect USB once and run this file again.
  pause
  exit /b 1
)

if not exist "%PROJECT_DIR%" mkdir "%PROJECT_DIR%"
echo Syncing source files...
robocopy "%SOURCE_DIR%" "%PROJECT_DIR%" /E /XD .dart_tool build .git .idea artifacts /XF *.iml >nul
if errorlevel 8 (
  echo Source sync failed.
  pause
  exit /b 1
)

cd /d "%PROJECT_DIR%"
echo Installing Shingeki Dragon on %TARGET_SERIAL%...
"%RTK%" flutter pub get
if errorlevel 1 (
  echo flutter pub get failed.
  pause
  exit /b 1
)

"%RTK%" flutter build apk --release
if errorlevel 1 (
  echo flutter build apk failed.
  pause
  exit /b 1
)

"%RTK%" adb -s %TARGET_SERIAL% install -r "build\app\outputs\flutter-apk\app-release.apk"
if errorlevel 1 (
  echo adb install failed.
  pause
  exit /b 1
)

echo Starting Shingeki Dragon...
"%RTK%" adb -s %TARGET_SERIAL% shell monkey -p %PACKAGE_NAME% -c android.intent.category.LAUNCHER 1
if errorlevel 1 (
  echo App was installed, but launch failed.
  pause
  exit /b 1
)

echo Done.
if not defined NO_PAUSE pause

endlocal
