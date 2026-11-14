# 名称だけから資料を生成した、新しい2点の品質試作

対象を街灯・時計・自販機から「丸いティーポット」「レトロな旅行鞄」へ変更。前のモデルや資料の画像を入力せず、配色・部品・形状もプロンプトで指定せず、名称から新規にデザインしてもらった。組み込み画像生成ツールを使用。全文は `prompts.json`、採用資料は `teapot_reference.png` と `suitcase_reference.png`。

資料の完成度は下げず、3D側で再現する範囲を絞る。簡略版より輪郭と構造を整え、精密版のような微細な傷・裏面機構までは作らない。許容できる品質かどうかはユーザー評価待ち。

| 対象 | 作った形・構造 | 省いた表面の細部 |
|---|---|---|
| ティーポット | 連続した丸い胴体と内壁、首、別の蓋と縁、つまみ、曲がった中空の注ぎ口、胴体へ接する連続した取っ手、素焼きの高台 | 陶土の斑点、釉薬の細かなムラ、汚れ |
| 旅行鞄 | 丸い角のケース両側、開閉の継ぎ目、縁のパイピング、巻いたベルト、開いたバックル、革の端、角当て、持ち手と取付金具、背面の蝶番 | 革のシボ・擦れ、個別の縫い目、傷 |

画像テクスチャなし。陶器・革・金属を色、粗さ、金属度と形状で区別。面数は実測 `build_manifest.json` を参照。材質単位でティーポット3、鞄5メッシュにまとめる。

ゲーム側は `production_scrap.gd` の既存2項目を `_fresh.glb` に変更。種類名・タグ・袋からの出現・寸法指定・重さを維持。長辺は0.6m／0.7m、重さ1kg／1.5kg。旧GLBも残す。袋から出る品物なので処理券は付かない。カタログ写真もこの2点だけ更新。

## 再生成・確認

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python godot/assets/production/fresh_props/source/build_assets.py
```

Blender 5.2.2 LTS。前の `refined_props` の形状・GLB出力ヘルパーを再利用。GLBは `../../scrap/`、編集用blendと確認画像は `artifacts/fresh-props-20261017/`。資料・生成コードは `.gdignore` でランタイムのインポートから除外する。

`res://tools/refined_props_review.tscn` の `show_fresh_pair("scrap_teapot")` などで左に旧版・右に新しい版、`show_fresh_lineup()` で2点並び。第2引数／第1引数をtrueにすると背面。`audit_props` と `save_catalog` へ `["scrap_teapot","scrap_travel_suitcase"]` を渡し、寸法・重さ・箱の当たり判定・有限頂点と発注写真を確認する。Godotで正面／背面を目視済み。袋出現の既存テストは `bash tools/run_some.sh junk_bags_test`。

中断した街灯・時計・自販機の改訂案はゲームへ採用せず、`artifacts/balanced-props-20261017/abandoned/` にローカル保存している。それらのゲーム参照は元の簡略版のまま。
