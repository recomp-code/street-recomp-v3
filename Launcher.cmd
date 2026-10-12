@echo off
rem NBA Street V3 PC launcher: pick your ISO, prepare the game (first time only) and play.
start "" powershell -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Launcher.ps1"
