@echo off
rem Roda os testes automatizados (ciclo completo do jogo)
"C:\Users\mitok\Tools\Godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path "%~dp0." res://tests/smoke_test.tscn
pause
