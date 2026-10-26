$ErrorActionPreference = 'Stop'
$ttsPython = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (-not (Test-Path -LiteralPath $ttsPython)) { $ttsPython = 'python' }
$ttsDependencies = Join-Path $env:USERPROFILE '.cache\codex-audio\capcut-deps'
& $ttsPython -m pip install --upgrade --target $ttsDependencies -r (Join-Path $PSScriptRoot 'requirements.txt') --disable-pip-version-check
if ($LASTEXITCODE -ne 0) { throw 'CapCut TTS dependency installation failed.' }
Write-Host "Ready. Run $(Join-Path $PSScriptRoot 'tts.cmd') voices"
