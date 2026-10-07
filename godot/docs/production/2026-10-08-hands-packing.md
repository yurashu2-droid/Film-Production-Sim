# 移動・照準・クリック・Fで積む

撮影fixtureと別に、トマト怪獣の実入力経路を画面つきで確認した。起動画面でsoloを選び、倉庫依頼を購入0で受ける。プレイヤーの座標も小道具の座標も書き換えず、Wの移動入力で事務所から廃材置き場へ歩く。

第三者カメラの向きを調整し、Playerの物理raycastがトマト怪獣を指していることを確認。その後、InputEventMouseButtonの左クリックから実際に持ち上げ、W入力でトラックへ運び、InputEventKeyのFから本体の積載処理を実行した。

6項目全成功、PACK_HANDS_OK、終了0。最初の歩行100tick、廃材への移動347tick、抱えての移動363tick。画像 `hands_holding.png`、`hands_truck.png`、`hands_loaded.png` を確認した。持つ腕の姿勢、怪獣の大きさ、荷台への配置と積載一覧が見える。照準調整と移動先は自動化しているが、target/holder/riderの強制代入は行っていない。

診断helperはignored `godot/tests/shots/production_review/hands_packing.gd`、ログは `tools/diagnostics/production-hands-packing.log`。倉庫から現場への撮影成立は別の一周確認を使う。

06:50に同じ実入力経路を現場まで延長した。手ぶらのFで出発し、8秒移動した後、Wで荷台へ歩き、物理raycastと左クリックで怪獣を降ろす。再びWで荷台から離れ、左クリックで地面へ置き、2秒後も床に留まる。座標・holder・riderの強制代入は加えていない。全13項目PACK_HANDS_OK、終了0。helperのF入力オブジェクトを同一frameへ再送した箇所には診断警告一つが出たが、荷下ろしと以降の操作は成功した。本体の入力処理や物理を修正する必要はなかった。

延長用helperは `tests/shots/production_review/hands_unloading.gd`、ログは `tools/diagnostics/hands-unloading.log`。撮影用の自動配置とは別の運搬確認として残す。
