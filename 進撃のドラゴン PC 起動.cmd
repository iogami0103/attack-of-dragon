@echo off
setlocal

set "PROJECT_DIR=%~dp0"
set "RTK=C:\Users\iogam\bin\rtk.exe"
set "LEADERBOARD_URL=https://iogami0103.github.io/attack-of-dragon/scores/leaderboard.json"
set "SCORE_SUBMIT_URL=https://attack-of-dragon-score-submit.i-ogami-0103.workers.dev"

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
echo Starting Attack of Dragon on Windows...

"%RTK%" flutter pub get
if errorlevel 1 (
  echo flutter pub get failed.
  pause
  exit /b 1
)

"%RTK%" flutter run -d windows --dart-define=LEADERBOARD_URL=%LEADERBOARD_URL% --dart-define=SCORE_SUBMIT_URL=%SCORE_SUBMIT_URL%
if errorlevel 1 (
  echo flutter run -d windows failed.
  pause
  exit /b 1
)

pause
