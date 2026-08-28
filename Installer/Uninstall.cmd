@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall-NanaZip.ps1"
if errorlevel 1 (
  echo.
  echo A desinstalacao nao foi concluida.
  pause
)
