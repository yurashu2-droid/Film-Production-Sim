@echo off
set /p ADDR=Host IP (Enter = this PC): 
if "%ADDR%"=="" set ADDR=127.0.0.1
start "" "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0godot" -- --join=%ADDR%
