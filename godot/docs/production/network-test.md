# 制作フローの二人 ENet 検証

`godot/tests/productionnettest.gd` は制作モード専用。既存の `--nettest` は従来の撮影テストを実行する。

PowerShell の別プロセスでホストを起動し、2秒ほど待ってクライアントを起動する。

```powershell
./tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot -- --host --productionnettest
./tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path godot -- --join=127.0.0.1 --productionnettest
```

成功条件は `CLIENT PRODUCTIONNET_OK` と `HOST PRODUCTIONNET_OK`、両プロセス終了コード0。

検証範囲: 起動済みホストへの参加と事務所spawn、財布、参加者からの依頼選択と購入、遠いホストを待つ出発条件、トラックの積載関係、8秒の移動、到着時600秒の貸切時間、期限切れ時のテイク作成、参加者による納品と精算、帰社と財布の同期。

位置と期限だけテストNodeのRPC経由でホストに準備を要求する。依頼・購入・出発・納品・帰社はゲーム本体のRPCを参加者から送る。終了時も参加者の検証結果をホストへ送り、両側が成否を出力する。

実行記録（2026-10-08、Godot 4.7.2、実 ENet 二人）:

```text
PRODUCTION_NET office cash synchronized OK
PRODUCTION_NET late join spawns in office on both peers OK
PRODUCTION_NET client accepts studio job OK
PRODUCTION_NET client confirms purchase OK
PRODUCTION_NET purchase cash synchronized OK
PRODUCTION_NET departure waits for distant host OK
PRODUCTION_NET required truck riders synchronized OK
PRODUCTION_NET cargo synchronized OK
PRODUCTION_NET client departs with crew OK
PRODUCTION_NET travel progress and truck synchronized OK
PRODUCTION_NET arrival OK
PRODUCTION_NET journey lasts eight seconds OK
PRODUCTION_NET ten minute studio lease synchronized OK
PRODUCTION_NET cargo arrives attached OK
PRODUCTION_NET expiry creates deliverable take OK
PRODUCTION_NET client delivers after expiry OK
PRODUCTION_NET settlement cash synchronized OK
PRODUCTION_NET client returns to office OK
PRODUCTION_NET return spawn and cash synchronized OK
CLIENT PRODUCTIONNET_OK
HOST PRODUCTIONNET_OK
```

初回検証ではクライアントの積載関係が届いていなかった。世界同期に積載元と相対Transformを追加した後、積載・積み込み一覧・到着を含め全項目が成功した。

追加検証（同日、実 ENet 二人、21項目成功）:

```text
PRODUCTION_NET studio model and old wall colliders synchronized OK
PRODUCTION_NET free lift F up/down action and camera local height synchronized OK
CLIENT PRODUCTIONNET_OK
HOST PRODUCTIONNET_OK
HOST_EXIT=0 CLIENT_EXIT=0
```

室内スタジオ到着時、両側にJobLocationとstudioモデルが存在し、旧壁のCollisionShape3Dが無効になっていることをホストsnapshotと参加者で確認。無料昇降台にカメラを載せたfixtureを用意し、参加者のF入力から本体h_prop_action RPCを通して上昇・下降させた。途中と上下端でactive/action_time/deck_top、カメラの積載元と相対高さを照合し、上昇量と元の高さへの復帰も確認した。

この再実行ではホスト・参加者ともstderrは空。MTU超過警告も発生しなかった。昇降台への積載準備はホストfixtureで行うため、手操作でカメラを載せる入力経路自体はこのテストの対象外。
