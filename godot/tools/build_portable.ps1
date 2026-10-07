param([string]$OutputDirectory = "")
$ErrorActionPreference = 'Stop'
$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repositoryDirectory = [System.IO.Path]::GetFullPath((Join-Path $projectDirectory '..'))
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $repositoryDirectory 'artifacts/FilmProductionCrew-portable'
}
$packageDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$engineDirectory = Join-Path $repositoryDirectory 'tools/godot'
$engineConsole = Join-Path $engineDirectory 'Godot_v4.7.2-stable_win64_console.exe'
$engineWindow = Join-Path $engineDirectory 'Godot_v4.7.2-stable_win64.exe'
if (-not (Test-Path -LiteralPath $engineConsole) -or -not (Test-Path -LiteralPath $engineWindow)) {
    throw 'tools/godot にGodot 4.7.2のWindows本体が必要です。'
}
New-Item -ItemType Directory -Force -Path $packageDirectory | Out-Null
$packPath = Join-Path $packageDirectory 'FilmProductionCrew.pck'
& $engineConsole --headless --path $projectDirectory --export-pack 'Windows portable data' $packPath
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $packPath)) {
    throw "ゲーム資源の書き出しに失敗しました（終了 $LASTEXITCODE）。"
}
Copy-Item -LiteralPath $engineWindow -Destination (Join-Path $packageDirectory 'FilmProductionCrew.exe')
# 本編と同じPCKに入っている試作室も、ソースなしで開ける。
$labLaunchers = @{
    'MotionLab.bat' = 'res://motion_lab.tscn'
    'VFXLab.bat' = 'res://vfx_lab.tscn -- %*'
    'FilmOnly.bat' = '-- --legacy'
}
foreach ($launcherName in $labLaunchers.Keys) {
    $launcherText = '@echo off' + "`r`n" + 'start "" "%~dp0FilmProductionCrew.exe" --path "%~dp0." ' + $labLaunchers[$launcherName] + "`r`n"
    Set-Content -LiteralPath (Join-Path $packageDirectory $launcherName) -Value $launcherText -Encoding ascii
}
$noticesDirectory = Join-Path $packageDirectory 'Notices'
New-Item -ItemType Directory -Force -Path $noticesDirectory | Out-Null
Get-ChildItem -LiteralPath (Join-Path $projectDirectory 'licenses') -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $noticesDirectory
}
$assetsDirectory = Join-Path $projectDirectory 'assets'
Get-ChildItem -LiteralPath $assetsDirectory -Recurse -File | Where-Object {
    $_.Name -match 'license|source|copyright|notice'
} | ForEach-Object {
    $relativeName = $_.FullName.Substring($assetsDirectory.Length + 1)
    $destination = Join-Path (Join-Path $noticesDirectory 'Assets') $relativeName
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $destination
}
$instructions = @'
格安アクション映画制作班 ― Windows持ち運び版

フォルダを展開して FilmProductionCrew.exe を起動してください。
exeとpckは同じフォルダに置きます。Godotの別インストールは不要です。

ひとり：起動画面で「ひとりで遊ぶ」。
友達と：一人が「友達を招く」。事務所のIPを同じネットワークの友達へ伝え、
参加側は起動画面でIPを入力します（UDP 24680、最大4人）。

事務所 → 依頼 → 道具購入・無料廃材 → 軽トラ積載 → 現場 → 映画 → 納品。
現場を借りられるのは10分。詳しい操作はTabで確認できます。
カチンコを持ってFで本番。1 告白、2 爆発、3 再会、T カット。
V/中クリックで友達へ「ここ！」を伝えられます。
Rで見返す、Enterで納品。Pで見返しの8コマを画像として保存。
保存後はOで映画画像のフォルダを開けます。
会社の財布は現在のセッション内で持ち越し、会社を閉じると終了します。

これはGodot 4.7.2の既存Windows本体とゲーム資源を組み合わせた試作版です。
エンジン・同梱素材の出典やライセンス文書はNoticesにあります。

MotionLab.bat：7人の走り・足の補正・土ぼこりを見比べる試作室。
VFXLab.bat：爆発・炎・走りの演出などを、止めたりスローにして見る試作室。
FilmOnly.bat：従来の撮影だけモード。F9の見本セットも使えます。
'@
Set-Content -LiteralPath (Join-Path $packageDirectory 'はじめに.txt') -Value $instructions -Encoding utf8
Copy-Item -LiteralPath (Join-Path $projectDirectory 'docs/production/first-game.md') -Destination (Join-Path $packageDirectory '最初の一本.txt')
Write-Output "PORTABLE_OK $packageDirectory"
