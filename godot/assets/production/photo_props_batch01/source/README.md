# 写真参考による置き換え：送風機・猫脚浴槽・電話ボックス

ユーザーが承認した日本型自販機・ティーポット・旅行鞄を品質の目安にした3点。画像検索で実物の構造を調べ、ブラウザーで写真を目視してから形状を制作。今回は画像生成を使わない。既存モデルの画像をデザインの資料には使わず、旧版との比較にだけ用いる。

## 写真の出典と採用した特徴

| 対象 | 出典 | 作った特徴 |
|---|---|---|
| 大型送風機 | [Something Different Party Rentals: Industrial Floor Fan](https://www.somethingdifferentparty.com/product/fan-orange) | オレンジの開いた円筒カバー、前後の同心円ガードと放射状の桟、金属製の羽根、中央のモーター、傾斜する黒いパイプスタンド、ゴム足 |
| 猫脚バスタブ | [ライフアップ H5201](https://lifeup-2.com/?pid=171839686) | 滑らかな白い槽、厚みのある巻いた縁、内側と底、クロームの独立した猫脚、排水口 |
| 電話ボックス | [まいぷれ：新居浜市内の公衆電話 その2](https://niihama.mypl.net/article/publicphone_niihama/24459) | 日本の緑屋根とアルミ枠、透明な壁、扉の取っ手と蝶番、緑の公衆電話、受話器・巻きコード・キー・投入口、記入台 |

画像は閲覧して形状を参考にしただけで、ゲームへの画像同梱やテクスチャへの転用はしない。特定の会社名や商品ロゴは付けていない。見えない部分はゲーム用として補完。送風機のガード本数・浴槽の脚の装飾・電話機の細かな印刷は、ゲームで読める程度へ簡略化している。

ガラスは薄い色とアルファで表したゲーム用の透明材質。物理的な屈折は扱わず、中の電話機や反対側の枠が見えることを優先した。4枚のパネルは別の面として作り、枠を立体で付ける。羽根・扉は静止形状で、今回アニメーションは追加していない。

## ゲームへの反映

`production_scrap.gd` の3項目のGLB参照だけを `_photo` に変更。種類名・配置・タグ・正規化する寸法・重さを維持。送風機は1.2m／7kg、浴槽1.3m／9kg、電話ボックス1.6m／8kg。旧GLBも比較用に残す。カタログ写真を3個更新する。

送風機と浴槽の `prop_shapes.gd` の複合当たり判定は既存のまま。送風機の中心・半径・底の広さ、浴槽の幅・槽の高さ・脚位置をそれに合わせている。電話ボックスは従来と同じ外形の箱の当たり判定。処理券は中央キャップ／浴槽の広い外面／ボックスの土台へ付ける。

## 再生成・確認

```powershell
& 'C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python godot/assets/production/photo_props_batch01/source/build_assets.py
```

Blender 5.2.2 LTSの独立したプロセスで実行する。`fresh_props` と `refined_props` の形状・GLB出力ヘルパーを再利用。GLBは `../../scrap/`、編集可能なblendと正面・背面のPNGは `artifacts/photo-props-batch01-20261017/`。実測メッシュ数・面数は `build_manifest.json`。材質単位でまとめ、外部テクスチャは使わない。

`res://tools/refined_props_review.tscn` の `show_photo_prop("scrap_fan")` などで対象の写真、trueを第2引数に渡すと背面、`show_photo_lineup()` で3個を並べる。`audit_props` と `save_catalog` に `["scrap_fan","scrap_tub","scrap_phone"]` を渡して、寸法・重さ・当たり判定の種類／個数・処理券・有限頂点と発注写真を確認する。複合形状の監査は既存表との個数照合、箱は外寸とのサイズ照合。ガラスの透過と各モデルの前後をGodotで目視する。

確認結果：3個の実行時監査にエラーなし。既存の `bash tools/run_some.sh collider_fit_test` も通過（外形・床・空隙・接地後の挙動など）。
