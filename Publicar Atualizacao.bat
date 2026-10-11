@echo off
rem Publica uma atualizacao no GitHub: os jogos instalados baixam sozinhos ao abrir.
rem Uso avancado: powershell -File tools\publish_update.ps1 -Version 0.7.0 -Notes "texto" [-Installer]
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\publish_update.ps1"
pause
