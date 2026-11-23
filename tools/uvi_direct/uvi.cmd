@echo off
setlocal
set "UVI_PYTHON=%USERPROFILE%\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if not exist "%UVI_PYTHON%" set "UVI_PYTHON=python"
"%UVI_PYTHON%" "%~dp0uvi_direct.py" %*
exit /b %errorlevel%
