@echo off
rem Abre o jogo usando o Godot portatil instalado em %USERPROFILE%\Tools\Godot
start "" "%USERPROFILE%\Tools\Godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0."
