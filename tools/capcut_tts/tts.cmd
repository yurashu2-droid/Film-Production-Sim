@echo off
setlocal
set "CAPCUT_SHARED=%USERPROFILE%\Tools\capcut-tts\tts.cmd"
if /I "%~f0"=="%CAPCUT_SHARED%" goto run
if not exist "%CAPCUT_SHARED%" goto run
call "%CAPCUT_SHARED%" %*
exit /b %errorlevel%
:run
set "CAPCUT_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if not exist "%CAPCUT_PYTHON%" set "CAPCUT_PYTHON=python"
"%CAPCUT_PYTHON%" -X utf8 "%~dp0capcut_speech.py" %*
exit /b %errorlevel%
