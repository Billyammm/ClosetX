@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-latest-app.ps1" %*
exit /b %ERRORLEVEL%
