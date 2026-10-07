# 移動中・本番中の途中参加を実ENetで確認

専用ポート24681でGodotを二つ起動し、通常の `h_hello` / production snapshot / `production_move` / world同期を通した。共有ゲームスクリプトは変更していない。別のメニュー接続試験で使う24680とは競合しない。

リポジトリルートからPowerShellで実行する:

```powershell
& godot/tests/run_productionlatejoin.ps1
```

helperはhostの移動開始を待ってclientを起動し、両方の終了コード・Godotエラーを確認して終了する。ログは `tools/diagnostics/production-latejoin-{host,client}.{log,err}`。`--host` / `--join` は渡さず、SceneTree bootstrapから専用ポートに接続してから同じ `/root/Game` を生成する。clientは接続成功後にGameを生成し、通常のhelloを一度送る。

## 確認した経路

1. hostが野外の仕事を受注して道具を購入。truck → lift → cameraを段積みして出発後、phase3中にclientが参加。
2. 元のcrewと途中参加したcrewが8秒移動を経てphase4へ到着。
3. clientが本番の操作RPCでカメラ操作とカチンコ所持を取得。接続を閉じ、旧Gameを完全にfreeする。
4. hostの退場処理がroster・held・operatorを掃除。通常の本番開始からCOUNTDOWNを経てTAKEへ移る。
5. 同じclientプロセスが新しい接続と新しいGameを作り、TAKE中に参加。既存hostを入口へ動かさず、入ったpeerだけ現場入口へ配置する。

会社資金・購入額・選択job・期限残量・expired、両peerのGameパスとlocal player一人、truck/lift/cameraの親子と実座標、実yardのshutterノード、旧倉庫壁のCollisionShape無効化、TAKE state・tally・film SubViewportのUPDATE_ALWAYSを検査した。職員の出現位置は入口から2m以内として、近くの物理小道具がカプセルを押し出す動きを許容する。world同期は全再送周期の1秒を越える1.3秒待ってから再参加後の実座標を比較する。

fixtureは道具選択・荷積み・本番開始に本番メソッドを使い、検証用RPCは状態の参照とhostの位置準備だけに用いた。会社状態・cargo・TAKE stateをclientへ直接コピーしていない。撮影判定や納品の完走は既存の一周試験に任せる。

## 結果

2026-10-08、Godot4.7.2 headlessの実二processで、host/clientとも `PRODUCTIONLATEJOIN_OK`、終了コード0。両stderrは空。途中参加のための本番コード修正は不要だった。

最初の試験では移動開始直後のhost座標を固定値として比較していたが、トラックとの物理衝突で乗員も道中を移動するため、現在のhost座標と新peerの出現位置を比較する形へ訂正した。また、旧Gameのfreeは接続を閉じた後に行い、破棄済みノードへ届く検証中のRPCを避けた。
