@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-NanaZipCustom.ps1"
if errorlevel 1 (
  echo.
  echo A instalacao nao foi concluida.
  pause
)

