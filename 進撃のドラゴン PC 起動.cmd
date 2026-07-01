@echo off
setlocal

set "PROJECT_DIR=%~dp0"
set "RTK=C:\Users\iogam\bin\rtk.exe"

if not exist "%RTK%" (
  echo rtk.exe was not found:
  echo   %RTK%
  pause
  exit /b 1
)

if not exist "%PROJECT_DIR%pubspec.yaml" (
  echo Flutter project was not found:
  echo   %PROJECT_DIR%
  pause
  exit /b 1
)

cd /d "%PROJECT_DIR%"
echo Starting Shingeki Dragon on Windows...

"%RTK%" flutter pub get
if errorlevel 1 (
  echo flutter pub get failed.
  pause
  exit /b 1
)

"%RTK%" flutter run -d windows
if errorlevel 1 (
  echo flutter run -d windows failed.
  pause
  exit /b 1
)

pause
