@echo off
setlocal EnableExtensions

set "SOURCE_DIR=%~dp0"
set "RTK=C:\Users\iogam\bin\rtk.exe"
if not defined PACKAGE_NAME set "PACKAGE_NAME=io.github.iogami0103.attackofthedragon"
set "USB_SERIAL=2A271FDH300GLX"
set "DEVICE_IP=192.168.1.6"
set "ADB_PORT=5555"
set "NETWORK_SERIAL=%DEVICE_IP%:%ADB_PORT%"
set "TARGET_SERIAL="
set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"
set "EXIT_CODE=0"
set "LOCAL_CHANGES="

if not exist "%RTK%" (
  echo rtk.exe was not found:
  echo   %RTK%
  pause
  exit /b 1
)

if not exist "%SOURCE_DIR%pubspec.yaml" (
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

cd /d "%SOURCE_DIR%"
if errorlevel 1 (
  echo Failed to enter project directory:
  echo   %SOURCE_DIR%
  pause
  exit /b 1
)

for /f "delims=" %%A in ('"%RTK%" git status --porcelain --untracked-files=all') do (
  set "LOCAL_CHANGES=1"
)

if defined LOCAL_CHANGES (
  echo Local changes were found.
  echo Skipping GitHub update and installing the local working tree.
) else (
  echo Updating from GitHub...
  "%RTK%" git fetch --prune origin
  if errorlevel 1 (
    set "EXIT_CODE=1"
    echo git fetch failed.
    goto cleanup
  )

  "%RTK%" git pull --ff-only
  if errorlevel 1 (
    set "EXIT_CODE=1"
    echo git pull failed. Resolve update conflicts, then run this file again.
    goto cleanup
  )
)

echo Installing Attack of the Dragon on %TARGET_SERIAL%...
"%RTK%" flutter pub get
if errorlevel 1 (
  set "EXIT_CODE=1"
  echo flutter pub get failed.
  goto cleanup
)

"%RTK%" flutter build apk --release
if errorlevel 1 (
  set "EXIT_CODE=1"
  echo flutter build apk failed.
  goto cleanup
)

if not exist "%APK_PATH%" (
  set "EXIT_CODE=1"
  echo Android APK was not found:
  echo   %SOURCE_DIR%%APK_PATH%
  goto cleanup
)

"%RTK%" adb -s %TARGET_SERIAL% install -r "%APK_PATH%"
if errorlevel 1 (
  set "EXIT_CODE=1"
  echo adb install failed.
  goto cleanup
)

echo Starting Attack of the Dragon...
rem monkey is not used here: it force-enables system auto-rotate on exit (thawRotation)
"%RTK%" adb -s %TARGET_SERIAL% shell am start -n %PACKAGE_NAME%/.MainActivity
if errorlevel 1 (
  set "EXIT_CODE=1"
  echo App was installed, but launch failed.
  goto cleanup
)

echo Done.
:cleanup
if not "%EXIT_CODE%"=="0" (
  pause
  exit /b %EXIT_CODE%
)

if not defined NO_PAUSE pause
exit /b 0
