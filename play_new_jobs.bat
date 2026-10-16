@echo off
rem Start from day 2: the job board shows every job except the company CM (the parody jobs too).
start "" "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0godot" -- --day2
