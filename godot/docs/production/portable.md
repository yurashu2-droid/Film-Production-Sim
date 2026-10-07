# Windowsの持ち運び版

エクスポートテンプレートがない環境でも、既存のGodot4.7.2 Windows本体とPCKを同じフォルダへ組み合わせて起動できるようにした。これは専用のreleaseテンプレートで最適化した実行ファイルではなく、手元の既存エンジンで動く試作パッケージ。

```powershell
& godot/tools/build_portable.ps1
```

標準出力先 `artifacts/FilmProductionCrew-portable/` に `FilmProductionCrew.exe`、`FilmProductionCrew.pck`、`はじめに.txt`、初回プレイの案内 `最初の一本.txt`、エンジン/素材の出典・ライセンス文書 `Notices/` を作る。起動にソースのgodotフォルダやテスト生成物は要らない。exeとpckは同じフォルダへ置く。初回の素の容量はexe約181MB、PCK約142MB、全体約323MB。生成物はGit対象外。

`MotionLab.bat` は7人の走り・足の補正・煙を見比べる試作室、`VFXLab.bat` はエフェクトのスロー/停止確認、`FilmOnly.bat` は従来の撮影だけモードを起動する。本編と同じPCKを使い、ラボの設定は本編へ自動保存しない。配布フォルダだけを作業場所にして三つの起動先を実描画90フレーム確認し、各終了0・ERRORなし。

`export_presets.cfg` の対象はゲーム資源全体で、`tests/*` と `docs/*` はパックから除外。脚本・Lab・VFXは既存のゲーム資源として保持する。原本のDownloadsや動画連番、試験画像は配布フォルダへコピーしない。

初回実描画確認は、repo外のpackフォルダを作業場所にしてPCK内の起動画面・Gameをロードした。solo選択、トマト怪獣/目印/コマ保存ノード、室内依頼の到着モデル、期限切れ150納品、帰社、会社終了後のメニューを確認。`PORTABLE_SMOKE_OK`、終了0、GodotログにERRORなし。診断の外部helperは `tests/shots/production_review/portable_smoke.gd`（ignored）。ゲーム起動時には使わない。

友達と遊ぶ時は、一人が起動画面でホストになり、同じネットワークの参加者へ事務所のIPを伝える。UDP24680、最大4人。インターネット越しの自動マッチングは含まない。

通常起動も外部scriptなしで確認した。portableフォルダだけを作業場所にし、`--write-movie` と `--quit-after 120` で起動画面を実描画記録した。退出0、ERRORなし、1600×900のmenu画像を確認。四processの通信・到着座標・退出復帰は `2026-10-08-portable-four-validation.md` に記録している。

エンジンの文書は使用バイナリのコミット `ed1daf0bf` の [LICENSE.txt](https://github.com/godotengine/godot/blob/ed1daf0bf/LICENSE.txt) と [COPYRIGHT.txt](https://github.com/godotengine/godot/blob/ed1daf0bf/COPYRIGHT.txt) をそのまま保存している。

## 2026-10-08の配布ZIP

`artifacts/FilmProductionCrew-Windows-20261008.zip` は228,319,070バイト。四人検証済みのゲームにTab案内の表示修正を加えたPCKを含む17エントリで、ZIPの全CRCと同梱PCKのSHA256一致を確認した。展開後の `FilmProductionCrew-portable` 内でexeを起動する。

```text
ZIP SHA256: 5CF1A766F4CEC87C2BDC5A4771D532187E25854F7966B67E3AD437C49E76B758
PCK SHA256: F34CD39049EAD7E002C049B5E7247ED0B0F6ACFCFEE8C0EB456832DA3AAC8EF0
```
