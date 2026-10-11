@echo off
rem Launcher de NBA Street V3 (port PC): elige tu ISO, prepara el juego (solo la primera vez) y juega.
start "" powershell -NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0Launcher.ps1"
