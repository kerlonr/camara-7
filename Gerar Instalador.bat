@echo off
rem Gera o .msi em dist\ (rode "Gerar EXE.bat" antes) e copia para a area de trabalho
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\build_msi.ps1"
copy /Y "%~dp0dist\Camara7-*.msi" "%USERPROFILE%\Desktop\" >nul
echo.
pause
