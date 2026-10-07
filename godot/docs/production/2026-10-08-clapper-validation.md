# 二人のカチンコ奪取を通常productionで確認

2026-10-08、Godot4.7.2 headlessの実二process・ENet専用ポート24682で確認した。通常productionの仕事選択・荷積み完了・8秒移動を経て現場へ入り、clientの接続とGame生成は通常のhello経路を使った。共有ゲームスクリプトは変更していない。

## 結果

host/clientとも `CLAPPERNET_OK`、終了コード0。両stderrは空。以下が両peerの実状態で成立した。

- clientが持ったカチンコを、hostは最初の1秒以内には奪えず、その後は奪える。
- hostが持ったカチンコを、clientは最初の1秒以内には奪えず、その後は奪える。
- 奪取後は取得者だけの `Player.held` がカチンコpidとなり、前の持ち主は0となる。host側の両Playerと、client側の両Playerを比較した。
- host/clientのどちらも、奪取後に実際のFキーイベントを送るとCOUNTDOWNを開始し、TAKEへ進める。
- 両方向とも、取得後1秒を過ぎたCOUNTDOWN中に奪取を試みても持ち主は変わらない。
- 通常のカット処理で所持が解放される。再テイクは通常の `h_retake` でPREPへ戻した。
- カチンコを持ったclientがTAKE中に退出すると、hostはカチンコを解放し、退場Playerをrosterから除く。

カチンコの `holder` はhostの権威状態、client側の所持表示は本番のholdイベントによる `Player.held` を検査した。holderやheldをfixtureで直接代入していない。host操作は検証RPCのremote senderコンテキスト外で行い、本当にpeer1の操作として実行する。Fは `Input.parse_input_event` でKEY_Fの押下・解放を送り、ゲームの入力処理・`h_use` を通した。

## 再実行

リポジトリルートからPowerShellで実行:

```powershell
& godot/tests/shots/production_review/run_clapper_net.ps1
```

専用helperはignoredディレクトリ `godot/tests/shots/production_review/` にある (`clapper_net_boot.gd` / `clapper_net.gd` / `run_clapper_net.ps1`)。run_tests.shには長い試験を追加していない。ログは `tools/diagnostics/production-clapper-{host,client}.{log,err}`。

終了直前に接続とGameを片付け、その後0.25秒待ってからプロセスを終了する。初回の終了時警告2件は検証helperの後片付けを調整した後の再実行では出なかった。ゲーム機能の修正は不要だった。引っ張り合いの待機演出は今回追加していない。
