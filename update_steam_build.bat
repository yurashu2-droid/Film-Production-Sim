@echo off
rem Rebuild the Steam (portable) version from the current files and make a zip to send to friends.
rem Output: artifacts\FilmProductionCrew-steam and artifacts\FilmProductionCrew-Steam-Windows-<date>.zip
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0godot\tools\update_steam_build.ps1"
pause
