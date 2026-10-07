@echo off
title Launch KK platform with Pluto multiplayer environment
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0launch-kk.ps1" %*
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" pause
exit /b %EXITCODE%
