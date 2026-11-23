# 撮影用の手持ち機材 20 点

Blender CLI で名前と実物写真の構造を読み取り、新規メッシュを作成した。旧モデルは **変換後の頂点外形と接地だけ** を測定し、形状の作成元や画像参照には使っていない。外部のメッシュ・写真・テクスチャは同梱していない。

`build_assets.py` を Blender の `--background --factory-startup --python-exit-code 1 --python` で実行すると、`scrap/<original_file>_rebuilt.glb`、このフォルダの対応表・数値表、および `artifacts/props-refresh-all/rebuild_gear_b/` の `.blend` が更新される。C 組のビルダーはこのビルダーの共通関数を利用する。

## 実物写真の資料

写真の製品仕様を再現するのではなく、開口部・部品の接続・素材の作り方を参考にした。

| 対象 | 写真資料 | 採用した構造 |
|---|---|---|
| バッテリー・充電器 | [GVM dual V mount kit](https://shop.gvmled.com/products/gvm-micro-series-bv-95-li-ion-v-mount-2-battery-with-dual-charger-kit-1)、[SWIT charger](https://www.swit.cc/index.php?c=article&id=483) | 分割ケース、接点、ガイド付きの充電スロット |
| 延長リール | [Solight cable reel](https://www.tsbohemia.cz/solight-prodluzovaci-privod-na-bubnu-4-zasuvky-15m-oranzovy-kabel-3x-1-5mm2_d473375) | 巻き胴、側板、独立したソケット穴、鋼管スタンド |
| 台本・クリップボード・絵コンテ・キューカード | [Production binder](https://propstore.com/product/superman-iv-the-quest-for-peace-1987/production-binder-containing-script-storyboards-and-assorted-paperwork/)、[Production paperwork](https://ukm.propstoreauction.com/lot-details/index/catalog/299/lot/81038/Lot-832-RETURN-TO-OZ-1985-Philip-Kohler-Collection-Scripts-Call-Sheets-Storyboards-and-Production-Paperwork)、[Clipboard photo](https://depositphotos.com/photos/rehearse-your-script.html) | 表紙と紙束の厚み、開いたバインダー金具、クリップ、リング綴じ |
| カラーチャート・ピントチャート | [ColorChecker video](https://www.pictureline.com/products/x-rite-colorchecker-passport-video)、[Calibration card](https://www.backscatter.com/Keldan-Color-Checker-and-Gray-Card) | 24 色の大きいパッチ、放射状のコントラスト、硬い薄板の背面 |
| レフ板・遮光板・クランプ・関節アーム | [SmallRig camera rig assembly](https://cvp.com/product/smallrig-basic-cage-kit-for-c400-sr4946)、[K&F articulated arm](https://www.kentfaith.co.uk/KF31.132_11-quot-magic-arm-with-super-clamp-magic-arm-clamp-kit-with-1-4-quot-3-8-quot-thread-screw) | 周囲の枠、フレームに接続する握り、開いたクランプの顎、軸で繋がるロック関節 |
| インタビューマイク・小型スピーカー・タイムコード表示 | [Production audio equipment](https://deitymic.com/recorders/) | マイクのスポンジ・軸・レポーター用角形フラッグ、スピーカーのコーンと筐体、7 セグメント表示 |
| メイクケース・ブラシ・くし・ハンガー | [Makeup case](https://www.walmart.com/ip/5014864939)、[Costume repair kit](https://www.clothkits.co.uk/products/clothkits-mini-sewing-kit-suitcase) | 留め具・ケース継ぎ目・太い金口・独立したくしの歯・開いたフックと肩の支持 |

## 省略とゲーム用の調整

- 一般の円柱は 16 辺、大きい回転体は 24 辺、小さなチューブは 6 辺。面取りは 1 セグメント。
- 微細なねじ、縫い目、金口の彫刻、文字、密なグリル、紙面本文、ブラシ一本ごとの毛を省いた。紙面の枠、色見本、LED は識別のための大きい形だけ。
- メッシュ座標に行列を焼き込み、ノードの変換は単位行列。Z-up/-Y 正面で作成し、GLB は Y-up/+Z 正面に変換。
- 本体全体を旧モデルの変換後の実頂点外形へ合わせ、旧 collider/size/mass は変更しない。
- 20 点すべて `production_scrap.gd` の `bag` 対象。個別の処分票は描画されないため、票専用の台紙・タブ・スリーブ・`DisposalTicketAnchor` を作らない。マイクのレポーター用フラッグ、ブラシの丸い金口、ケースの留め具、実際の機器パネルだけを残す。

## 確認

`build_manifest.json` は三角形数、有限頂点、実外形、旧外形、bag 対象とアンカー不在を記録。`artifacts/props-refresh-all/gear_geometry_audit.json` は書き出した GLB を直接読み、有限頂点・退化三角形・変換焼き込み・接地・不要アンカー不在を検査する。前後の低解像度レンダーは同 artifacts 内。Godot への組み込みとテストは親担当。旧 `gear_ticket_audit.json` は修正前の履歴で、最終モデルの確認には使わない。
