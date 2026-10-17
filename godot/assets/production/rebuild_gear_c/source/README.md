# 衣装小道具と舞台機構 20 点

新規の低ポリゴンメッシュ。実物写真から組み立て・支持・厚み・開口を読み取り、旧モデルは変換後の実頂点外形と接地位置の測定にだけ使った。素材や写真は同梱していない。

`build_assets.py` を Blender CLI で実行する。共通の書き出し、行列の焼き込み、外形合わせは `../../rebuild_gear_b/source/build_assets.py` を import する。GLB は `scrap/<original_file>_rebuilt.glb`、再編集用 `.blend` と前後レンダーは `artifacts/props-refresh-all/rebuild_gear_c/` に出力する。

## 写真資料と構造の選択

| 対象 | 写真資料 | 採用した構造 |
|---|---|---|
| 裁縫箱・ピンクッション・巻尺 | [Sewing kit suitcase](https://www.clothkits.co.uk/products/clothkits-mini-sewing-kit-suitcase)、[Sewing kit contents](https://www.walmart.com/ip/287964542) | 開いた厚い箱とヒンジ、糸巻きの上下フランジ、布クッションに刺さった太いピン、巻取りハウジングと目盛り・先端の曲がった爪 |
| スパナ・踏み台・救急箱・ちりとり | [Open spanner tool kit](https://spaldings.co.uk/products/sp-website/workshop-tools/workshop-hand-tools/spanners-wrenches/10-piece-harvest-tool-kit)、[Dulton garage utility equipment](https://www.dulton.jp/onlineshop/pages/for_car_life.aspx)、[Backstage repair kit](https://www.dancesupplies.com/products/covet-backstage-fix-it-kit) | 開いたスパナの顎、脚が開く平らな踏み面、留め具のある箱、三方の壁だけがある開いたトレー |
| ポップコーン | [Popcorn bucket photo](https://llamaramaparties.com/products/popcorn)、[Cinema popcorn photograph](https://www.lanacion.com.ar/economia/el-verdadero-protagonista-del-cine-nid1805395/) | 中空の紙容器、赤い縦帯、上面にだけ粗い粒の山 |
| 舞台の幕・背景巻き取り幕 | [ShowTex theatre curtain](https://www.showtex.com/en/projects/theatre/de-kom)、[Theatre construction illustration](https://domenicoscarlatti.wordpress.com/r-d/baroque-theatre/giacomo-torelli-chariot-and-pole-system-3/) | 足のある支持柱、吊りレール、吊り位置から降りる厚み付きの大きなひだ、ローラー・紙・錘・操作チェーン |
| 大道具台車 | [Scenery wagon construction](https://domenicoscarlatti.wordpress.com/r-d/baroque-theatre/giacomo-torelli-chariot-and-pole-system-3/)、[Mobile stage cart photo](https://www.showtex.com/en/projects/theatre/de-kom) | 厚い合板デッキ、下枠、キャスターのフォーク・車輪・軸、台に接続する押し手 |
| 雨装置 | [J.E.M. F/X rain equipment](https://www.jemfx.com/rain-effects)、[Practical rain shoot](https://www.awn.com/news/32ten-studios-produces-practical-effects-paramount-s-noah) | 二脚支持、水の分配管、下向きノズル、端の継手、接続された供給ホース |
| 煙突・原子炉・ボイラー | [Fulton vertical boiler](https://www.fulton.cn/en/index.php/product/detail/15.html)、[Been Jau boiler photo](https://www.beenjau.com.tw/en/product-detail/beenjau_BJB500_750/) | 開いた厚い管口、鋼板の継ぎ輪、受け脚、別の計器パネル・ゲージ・バルブ・蒸気管。原子炉は実物の圧力容器を舞台装置へ翻案したもので実在炉の再現ではない |
| 宇宙船操縦台 | [Practical starship bridge prop](https://ukm.propstoreauction.com/lot-details/index/catalog/299/lot/80482/Lot-276-PROMETHEUS-2012-Light-up-Starship-Prometheus-Bridge-Set)、[Practical shuttle cockpit mockup](https://www.wonderworksweb.com/ftpfolder/Photo/page33.html) | 二脚で支える筐体、囲み付き画面、大きな押しボタン、軸と握りのある操縦桿 |
| バルブ配管壁 | [Industrial boiler pipe and gauge construction](https://www.beenjau.com.tw/en/product-detail/beenjau_BJB500_750/) | 壁に接続する曲がり管、継手、輪とスポークを持つ開いたハンドル、圧力計 |
| ベルトコンベア | [Mini conveyor photo gallery](https://www.conveyor-manufacturers.co.uk/Gallery/small-conveyors-photos.html)、[Koyo flat conveyor](https://pr.www.ipros.com/kyc/product/detail/2000245809/) | 両端ローラーを周回する連続した厚いベルト、上下一対の走行面の間の空間、足と横桟、駆動モーター |
| 金庫の扉 | [Bank vault door photograph](https://www.lastingsafe.com/post/buying-a-vault-door)、[Round vault door product](https://www.lastingsafe.com/product-page/customizable-circular-bank-vault-door) | 外枠・扉厚・大きいヒンジ、開いた手輪、放射状のロック棒とガイド |
| 歯車の壁 | 同上の板金・軸・輪の構造と名前から新規設計 | 厚み付きの環状歯車、実際の中心穴、大きな鋳造歯、スポーク、軸、足と後ろの支え |

## 省略と保持

一般円柱 16 辺、大きな回転体 24 辺、小チューブ 6 辺、面取り 1 セグメント。ねじ・細かな縫い目・本文・密なノズル・細かい歯数を増やさず、支持・輪郭・開口・平らな足場に三角形を使った。幕は静止した厚み付きメッシュで、物理布の動作を示すものではない。

本体全体を旧モデルの変換後の実頂点外形に合わせる。20 点すべて `production_scrap.gd` の `bag` 対象で、個別の処分票は描画されない。票専用の台紙・タブ・スリーブ・`DisposalTicketAnchor` は含めない。実際の機器パネル、バルブ、計器、箱の留め具は保持する。

全パーツはワールド変換を頂点へ焼き込んでから GLB にする。元の size/mass/collider は変更していない。`build_manifest.json` に実外形・旧外形・三角形数・bag 対象とアンカー不在を保持する。前後レンダーと書き出した GLB の直接検証を実施。Godot への組み込みとテストは親担当。
