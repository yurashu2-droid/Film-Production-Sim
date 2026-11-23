$ErrorActionPreference = 'Stop'
$sharedTool = Join-Path $env:USERPROFILE 'Tools\capcut-tts'
$sharedSkill = Join-Path $sharedTool 'skill'
$skillLinks = @(
    (Join-Path $env:USERPROFILE '.claude\skills\capcut-tts'),
    (Join-Path $env:USERPROFILE '.agents\skills\capcut-tts')
)

# Never replace an unrelated existing personal skill.
foreach ($skillLink in $skillLinks) {
    if (Test-Path -LiteralPath $skillLink) {
        $linkInfo = Get-Item -LiteralPath $skillLink
        if ($linkInfo.LinkType -ne 'Junction' -or $linkInfo.Target -ne $sharedSkill) {
            throw "An existing skill needs to be preserved: $skillLink"
        }
    }
}
New-Item -ItemType Directory -Path $sharedTool -Force | Out-Null
New-Item -ItemType Directory -Path $sharedSkill -Force | Out-Null
if ([IO.Path]::GetFullPath($PSScriptRoot) -ne [IO.Path]::GetFullPath($sharedTool)) {
    foreach ($file in @('capcut_speech.py', 'tts.cmd', 'requirements.txt', 'setup.ps1', 'test_cli.py', 'README.md', 'install_shared.ps1')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $sharedTool $file) -Force
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'skill\SKILL.md') -Destination (Join-Path $sharedSkill 'SKILL.md') -Force
}
foreach ($skillLink in $skillLinks) {
    if (-not (Test-Path -LiteralPath $skillLink)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $skillLink) -Force | Out-Null
        New-Item -ItemType Junction -Path $skillLink -Target $sharedSkill | Out-Null
    }
}
Write-Host "Shared tool: $sharedTool"
Write-Host "Shared skill: $sharedSkill"
Write-Host 'Claude Code and Codex can use it from any project. Restart existing sessions to discover the personal skill.'
