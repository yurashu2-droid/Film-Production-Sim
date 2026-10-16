# Steam 版（持ち運び版）を、このフォルダの今の中身で作り直し、友達に渡す zip も作る。
#   リポジトリ直下の update_steam_build.bat から動かす（ダブルクリック）。
# 出力：artifacts\FilmProductionCrew-steam（自分で遊ぶ版。前の版に上書き）
#       artifacts\FilmProductionCrew-Steam-Windows-<日時>.zip（友達に渡す。前の zip は消さない）
# 作る中身は build_portable.ps1 と同じ。コミットしていない変更も入る（このフォルダの今のファイルから作るため）
$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$out = Join-Path $repo 'artifacts\FilmProductionCrew-steam'

if (Get-Process -Name 'FilmProductionCrew' -ErrorAction SilentlyContinue) {
    throw '持ち運び版のゲームが起動したままです。閉じてから、もう一度実行してください。'
}

$commit = '（不明）'
$dirty = $false
try {
    $commit = (& git -C $repo log -1 --format='%h %ad' --date=format:'%Y-%m-%d %H:%M') -join ''
    $dirty = [bool](& git -C $repo status --porcelain --untracked-files=no)
} catch {
    Write-Host 'git が見つからないので、コミットの記録は省きます。'
}

Write-Host "Steam 版を、今の中身で作り直します（最後のコミット：$commit）"
Write-Host 'ゲームのデータを書き出しています（数分かかります）…'
& (Join-Path $PSScriptRoot 'build_portable.ps1') -OutputDirectory $out

$made = Get-Date
# 版の印（ゲームが読んで、会社の版として使う。印が違う版どうしは同じ会社に入れない。scripts/steam_session.gd）
Set-Content -LiteralPath (Join-Path $out 'build_stamp.txt') -Value $made.ToString('yyyyMMdd-HHmm') -Encoding ascii
$lines = @(
    "作った日時：$($made.ToString('yyyy-MM-dd HH:mm'))",
    "最後のコミット：$commit"
)
if ($dirty) { $lines += '（コミットしていない変更も入っています）' }
$lines += ''
$lines += '一緒に遊ぶ人は、全員この版にそろえてください。版が違うと「相手と同じゲームの版を使ってください」と出て、会社に入れません。'
Set-Content -LiteralPath (Join-Path $out '版.txt') -Value $lines -Encoding utf8

$zip = Join-Path $repo ("artifacts\FilmProductionCrew-Steam-Windows-{0}.zip" -f $made.ToString('yyyyMMdd-HHmm'))
Write-Host '友達に渡す zip を作っています（1〜2分）…'
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip -Force

Write-Host ''
Write-Host "できました：$out"
Write-Host "友達に渡す zip：$zip"
Write-Output "STEAM_BUILD_OK $zip"
if (-not $env:STEAM_BUILD_QUIET) {
    Start-Process explorer.exe -ArgumentList "/select,`"$zip`""
}
