@echo off
rem Lance le jeu directement depuis le projet (toujours la derniere version du code)
cd /d "%~dp0"
set GODOT=%~dp0..\..\godot\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT%" (
  echo Godot introuvable : %GODOT%
  pause
  exit /b
)
echo Preparation des fichiers...
"%GODOT%" --headless --path "%~dp0." --import >nul 2>&1
start "" "%GODOT%" --path "%~dp0."
