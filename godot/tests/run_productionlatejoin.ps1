$ErrorActionPreference = 'Stop'
$taskRepo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$taskGodot = Join-Path $taskRepo 'tools\godot\Godot_v4.7.2-stable_win64_console.exe'
$taskLogs = Join-Path $taskRepo 'tools\diagnostics'
New-Item -ItemType Directory -Force -Path $taskLogs | Out-Null
$taskHostOut = Join-Path $taskLogs 'production-latejoin-host.log'
$taskHostErr = Join-Path $taskLogs 'production-latejoin-host.err'
$taskClientOut = Join-Path $taskLogs 'production-latejoin-client.log'
$taskClientErr = Join-Path $taskLogs 'production-latejoin-client.err'
$taskCommon = @('--headless','--path','godot','--script','res://tests/productionlatejoin_boot.gd','--')
$taskHost = $null
$taskClient = $null
try {
    $taskHost = Start-Process -FilePath $taskGodot -ArgumentList ($taskCommon + '--productionlatejoin=host') -WorkingDirectory $taskRepo -WindowStyle Hidden -RedirectStandardOutput $taskHostOut -RedirectStandardError $taskHostErr -PassThru
    $taskDeadline = (Get-Date).AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 100
        $taskReady = (Test-Path $taskHostOut) -and ((Get-Content -LiteralPath $taskHostOut -Raw) -match 'PRODUCTION_LATEJOIN_TRAVEL_READY')
    } while (-not $taskReady -and -not $taskHost.HasExited -and (Get-Date) -lt $taskDeadline)
    if (-not $taskReady) { throw 'Host did not prepare travel.' }
    $taskClient = Start-Process -FilePath $taskGodot -ArgumentList ($taskCommon + '--productionlatejoin=client') -WorkingDirectory $taskRepo -WindowStyle Hidden -RedirectStandardOutput $taskClientOut -RedirectStandardError $taskClientErr -PassThru
    if (-not $taskClient.WaitForExit(45000)) { throw 'Client timed out.' }
    if (-not $taskHost.WaitForExit(10000)) { throw 'Host timed out.' }
    Get-Content -LiteralPath $taskHostOut
    Get-Content -LiteralPath $taskClientOut
    Get-Content -LiteralPath $taskHostErr
    Get-Content -LiteralPath $taskClientErr
    if ((Get-Content -LiteralPath $taskHostErr -Raw) -match 'ERROR:' -or (Get-Content -LiteralPath $taskClientErr -Raw) -match 'ERROR:') { throw 'Godot reported an error; see late join stderr logs.' }
    if ($taskHost.ExitCode -ne 0 -or $taskClient.ExitCode -ne 0) { throw 'Production late join failed; see tools/diagnostics/production-latejoin-* logs.' }
} finally {
    foreach ($taskProcess in @($taskClient,$taskHost)) {
        if ($null -ne $taskProcess -and -not $taskProcess.HasExited) { Stop-Process -Id $taskProcess.Id -ErrorAction SilentlyContinue }
    }
}
