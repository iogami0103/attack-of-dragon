@echo off
setlocal EnableExtensions

set "SOURCE_DIR=%~dp0"
set "SOURCE_DIR_SLASH=%SOURCE_DIR:\=/%"
set "RTK=C:\Users\iogam\bin\rtk.exe"
set "WINDOWS_BUILD_DIR=%SOURCE_DIR%build\windows"
set "WINDOWS_CACHE=%WINDOWS_BUILD_DIR%\x64\CMakeCache.txt"
set "EXE_PATH=%SOURCE_DIR%build\windows\x64\runner\Release\attack_of_the_dragon.exe"
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
  echo Skipping GitHub update and building the local working tree.
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

if exist "%WINDOWS_CACHE%" (
  findstr /i /c:"%SOURCE_DIR_SLASH%windows" "%WINDOWS_CACHE%" >nul 2>nul
  if errorlevel 1 (
    echo Removing stale Windows build cache from a previous project path...
    rmdir /s /q "%WINDOWS_BUILD_DIR%" >nul 2>nul
    if exist "%WINDOWS_BUILD_DIR%" (
      set "EXIT_CODE=1"
      echo Failed to remove stale Windows build cache:
      echo   %WINDOWS_BUILD_DIR%
      goto cleanup
    )
  )
)

"%RTK%" flutter pub get
if errorlevel 1 (
  set "EXIT_CODE=1"
  echo flutter pub get failed.
  goto cleanup
)

"%RTK%" flutter build windows --release
if errorlevel 1 (
  set "EXIT_CODE=1"
  echo flutter build windows failed.
  goto cleanup
)

if not exist "%EXE_PATH%" (
  set "EXIT_CODE=1"
  echo Windows executable was not found:
  echo   %EXE_PATH%
  goto cleanup
)

if defined NO_LAUNCH (
  echo Build completed. Skipping launch because NO_LAUNCH is set.
  goto cleanup
)

echo Starting Attack of the Dragon on Windows...
start "" /wait "%EXE_PATH%"
if errorlevel 1 (
  set "EXIT_CODE=1"
  echo Windows app exited with an error.
  goto cleanup
)

:cleanup
if not "%EXIT_CODE%"=="0" (
  pause
  exit /b %EXIT_CODE%
)

if not defined NO_PAUSE pause
exit /b 0
