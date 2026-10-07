# portable PCKで四人の一周・切断復帰を確認

2026-10-08、`artifacts/FilmProductionCrew-portable/FilmProductionCrew.exe` をhost一人・client三人の実四processで起動した。全processは同じ `FilmProductionCrew.pck` を読み、作業ディレクトリもportableフォルダとした。そこに `project.godot` と元の `godot/` が無いこと、PCKに開発用testスクリプトが含まれないことも各processから確認した。既に実描画solo/studio試験済みのpackageを、通信に絞ってheadlessで使用した。console.exeやGodotの別インストールは使っていない。

検証対象PCKのSHA256（実行前後で一致）:

```text
473C7866EF35FAFE6865259C03417154D49F34B90CF12FEFBAA4D53457EC3219
```

## 確認した経路

起動画面を全peerで生成してから接続し、同じ `/root/StartMenu/Game` を一度だけ生成した。専用ポート24683への接続・出発前の集合位置・lease短縮をfixtureとし、menu接続成功処理・hello・roster・Gameの進行/RPC・cargo同期は本番経路を使った。

- 四人のrosterと各peer一人だけのlocal playerが一致。hostのremote peersは三人。四人接続中の追加ENet probeは2秒以内にCONNECTEDとならず、remote peers三人のままだった。
- 会社資金600からstudioのバルコニー360と台車80を購入。全peerで残金160、購入額440、選択job・期限・expiredが一致。
- 四人目が遠い間は出発不可。全員がトラック付近に集まった後だけ出発し、八秒後に到着。
- truck → lift → cameraの段積み親子が全peerで一致。借りたバルコニー・窓・台車も荷台に載せて輸送した。到着したカメラ実座標とtruck位置を比較した。
- 全peerで実studioノードが存在し、元の倉庫壁のCollisionShapeが無効となる。到着直後24 tickにわたり、全画面で四人が入口付近に留まる。
- leaseだけを検証fixtureで0.01秒へ短縮。全peerが期限切れRESULTと失敗テイク一つを受信し、client1から納品。
- 三clientの重複納品RPCでも支払いは150一回。共有財布310となり、client2から帰社すると四人とも会社へ戻る。
- 帰社後、client3がカメラを操作しカチンコを所持して退出。hostのroster・holder・operatorが片付く。同じclientが起動画面から再参加し、財布310の四人会社へ戻る。
- hostが会社を閉じて終了すると、三clientすべてがhost終了メッセージを表示した起動画面へ戻る。旧Gameが消え、OfflineMultiplayerPeerとなり、solo/host/joinボタンとIP欄が再操作可能となる。

## 結果と再実行

荷台ワープ時の物理速度修正・制作モードの移動epoch同期を含む上記PCKで、到着後24 physics tickの継続観測を実行した。入力を与えず、各画面の四人全員について、peer IDを昇順にしたindex `i` の `SPAWN + Vector3(0.8*i,0,0)` から水平2m以内、y >= 0を各tickで確認した。観測中の位置を補正するfixtureや、観測開始までの待機猶予は入れていない。

途中参加の出現位置重複対策を含む最終PCKでも、既存helperを変更せず一回実行し、181項目すべて成功（host20、client1/2各51、client3は59）。四processすべて `PORTABLE_FOUR_OK`・終了コード0で、runnerの終了コードも0だった。ログにSCRIPT ERROR / ERROR / WARNINGは無い。診断担当は外部helperとこの記録だけを変更し、共有ゲームスクリプトとパッケージの修正・再出力は親が担当した。PNG書き出し経路は今回の試験では使用していない。

### 到着後の観測値

全16観測（四画面×四人）でsamples=24、最大水平距離0m、最低y >= 0.00039062649012mだった。localだけでなくremote表示も安定した。各自が操作するlocal playerの値:

| 観測processのlocal player | 最大水平距離 m | 最低y m | samples |
| --- | ---: | ---: | ---: |
| host | 0.000000 | 0.000391 | 24 |
| client1 | 0.000000 | 0.000391 | 24 |
| client2 | 0.000000 | 0.000391 | 24 |
| client3 | 0.000000 | 0.000391 | 24 |

これらの値は各ログの `PORTABLE_ARRIVAL_STABILITY` 行に記録している。物理的な吹き飛びと、到着前の座標によるremote表示の逆戻りは、修正後の今回の四人試験ではどちらも再発しなかった。

### 修正前の失敗と診断helperの修正

先行PCK `5B3DAF839AD2C1B25211F4006CDF892B27CC57D1C6C2562FAD23FA1215BE86A6` では178項目中169成功、到着直後のremote距離9項目が失敗した。local四人は安定したが、host上でclient表示が最大56.154m、client上で他client表示が最大47.133mへ一時逆戻りした。ワープ後も世代のない座標RPCを採用する経路を親へ報告し、制作モードに移動epochを付けて古い座標を拒否する修正・配置順の統一が行われた。

epoch修正時PCK `72FCEB811234B9C720FAAFB931EC5510C124E98B5F381682601E6353E1754FB7` の初回実行は、到着継続観測すべてが成功した。一件だけ現場のlease比較が失敗したが、診断helperが最後の現場replyを送った直後に期限を0.01秒へ短縮し、clientがそのreplyを比較する前に期限切れ同期を受け得る競合だった。helperに三clientの現場比較完了ackを加え、その後だけ期限fixtureを適用した。同じPCKで再実行して181項目がすべて成功した。到着条件・位置補正・許容距離は緩和していない。初回epoch実行のログは `tools/diagnostics/portable-four-epoch-first-{host,client1,client2,client3}.log` に保存した。

リポジトリルートからPowerShell:

```powershell
& tools/diagnostics/run_portable_four.ps1
```

外部診断helperは `tools/diagnostics/portable_four_boot.gd` と `portable_four_peer.gd`。PCKに含めず、portable exeへ絶対パスの `--script` を指定する。GUI exeの `--log-file` を使って `tools/diagnostics/portable-four-{host,client1,client2,client3}.log` に証拠を残す。通常menuを維持するため役割引数は `crew-role=...` とし、GameをCLIモードへ切り替える `--host` / `--join` は渡さない。

runnerは起動した四processだけを管理し、終了コード・各ログ・実行前後のPCK hashを検査する。run_tests.shへ長い試験を追加していない。
