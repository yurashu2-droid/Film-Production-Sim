# 通常速度で一周を見る動画

2026-10-08の確認用自動プレイを1600×900、30fps、約62秒のMP4にした。動画は `artifacts/production_preview/production-loop-20261008.mp4`（約6.5MB、生成物のためGit対象外）。音声は含めない。

事務所 → 野外の依頼 → 540コインの道具選び → 廃材と小道具を積載 → 走り出し → 8秒の軽トラ移動 → 荷下ろし・設営 → カチンコで本番 → 三つの合図 → 見返し → 1350コイン納品 → 帰社を記録した。撮影条件・財布・移動・アニメーション・爆発は本体の処理を使う。配置と合図はfixtureで自動化しており、人の操作での初見プレイの証拠ではない。動画にも「動作確認用の自動プレイ」と表示した。

画面の文字・走りの接地・積載・爆発・見返し・精算の代表フレームを実見した。固定60Hzのシミュレーションを2コマごとに保存し、30fpsで結合する。スローの動画ではない。

## 再生成

```powershell
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --path godot --fixed-fps 60 --script res://tests/productionpreview.gd
```

`PREVIEW_OK frames=1871 duration=62.366...` と撮影3条件・1350コインのassert成功を確認する。連番JPEGは `godot/tests/shots/production_preview/frames/` に保存する。新しい撮影でコマ数が減った場合は、旧連番を別フォルダに退避してから再生成する。

ffmpegがある環境で:

```text
ffmpeg -framerate 30 -i godot/tests/shots/production_preview/frames/%05d.jpg -c:v libx264 -preset fast -crf 22 -pix_fmt yuv420p -movflags +faststart production-loop.mp4
```

このcaptureはGPUから画像を読み戻すため、速度計測には使わない。通常入力の合間に物理fixtureを置き直す時は `physics_frame` に揃える。描画完了直後の物理状態書き換えを試験の配置に使わない。
