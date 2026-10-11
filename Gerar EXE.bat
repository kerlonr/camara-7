@echo off
rem Gera o jogo em dist\ : "Camara 7.exe" (motor) + "Camara 7.pck" (conteudo).
rem Para publicar uma atualizacao para os jogadores, use "Publicar Atualizacao.bat".
if not exist "%~dp0dist" mkdir "%~dp0dist"
"%USERPROFILE%\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." --export-release "Windows Desktop" "%~dp0dist\Camara 7.exe"
echo.
echo Pronto: %~dp0dist\Camara 7.exe  (+ Camara 7.pck ao lado)
pause
