# Pixel×Real53 / Action14 + original medium

ユーザー未評価。通常速度の再生品質は評価していない。最終15種の全体・動き・終わりを連続静止画で見た。inferno/storm/chain/echoの4代表はX方向とZ方向も見た。炎の中盤は角度によって対の房として重なり、土の噴流と衝突扇は房・薄板の読みが残る。放電は太い湾曲したゲーム表現で、chainのX方向は枝が重なり小さく見える。echoの縫い目は局所的で、X方向では主弧の横幅が奥行きに圧縮される。この制約を好評や全面的な見た目合格へ読み替えない。

## 呼び出し

```gdscript
preload("res://pixel_vfx/pack50/px50_action.gd").spawn(self, Vector3.ZERO, 1.0, "storm_crown")
preload("res://pixel_vfx/pack50/px50_echo_stitch.gd").spawn(self, Vector3.ZERO, 1.0, "echo_stitch")
```

両ソースはpx_baseを継承し、parent/pos/size/variantの共通spawn APIを持つ。形・材質・ライトはage由来の12fps時計で進み、SceneTree pauseへ従う。Tween、シェーダーTIME、外部テクスチャを使わない。寿命のノイズ穴消去は0層。technicalな3殻は1系統の体積表現であり、演出量の3系統に数えない。

## 今回の観察と修正

修正前42シートをartifacts/pixel_real_53/before_actionへコピー保存。stormは上から下まで満たされた9本の棒、chainは対のC弧、infernoは対の葉形として長く残ることを前版のflowで観察した。

1周目：storm/chainの材料を短い伝播窓へ変更し、下りる頭と根元から消費する後端を分けた。遅れて外れる分岐と時間で変わる中心線を加えた。infernoは反対向きの捻り・左右の剪断・分散した肩へ変更。電気・炎・衝突・障壁・冷気の共通地面輪を局所の接触/焦痕へ変えた。4種のr1全体を閲覧。

2周目：r1の放電が細かな独立片に見え、接続が読めなかったため、供給窓と体積を戻した。先端に固定された丸い肩を持たせず、局所幅を材料位置と拍で変える。chainの後発枝は主枝の途中から外れる。r2の連続8コマを閲覧。

3周目以降：inferno中盤に対の葉形が残ったため、4枝の開始時刻・上昇速度・基準角度をずらし、強い肩を複数の炎舌へ分散。chainは短すぎる接続を延長し、主枝の供給窓を.95秒、支枝を.42秒へ変え、上下のC対から非対称の接続/分岐へ。最終録画を当該2種だけ更新した。地面痕の供給はstorm1.35秒・chain.9秒から始め、供給元から先へぬぐう。

重力の地表反発・音圧の床反響は現象に対応する圧痕として保持。水/斬撃/弾は曲がった線形の排水/斬線/着弾痕。14種全部へ見た目に関係のない微修正は強制していない。

## 新作「反響の縫合」3修正

原型r1：三拍の反響主弧、低い尾、交互の受け皿、小紋を描画。受け皿が球状に見え、主弧と尾が離れた二本に見えた。

1回目/r2：受け皿を半弧から開く形へ、主弧の供給を.78秒へ変更。反響の到着を受ける位置を広げ、小紋を各到着の近くへ移した。1.2〜1.9秒を再描画・閲覧。

2回目/r3：主弧と低い尾を結ぶ局所縫い目を追加し、受け皿を横に開く弧へ変更。主弧から吊り下がる歯のような縫い目を観察した。

3回目/r4：縫い目の下端を実際の後続弧の中心線へ接続し、両流路の共存区間で追従。受け皿の密度を下げ、床照明を主弧の頭と到着点へ追従させた。全体/flow/endとX/Z両角度を閲覧。出口は前進方向の消費、受け皿の開きと下への流出、局所紋の根元から先への解け。

主役1＋低い尾/交互の受け皿/局所縫い目・紋の3補助装飾で中。幅約6m・頂点高さ約3.5m、dist9の同じ構図で大小originalと比較する。物理占有範囲は演出量の分類へ使わない。

## 演出量の分類

旧size_classは互換用の寸法ラベルとして維持。complexity_classは小9/中5、今回の新作は中1。大の数量ノルマへ合わせず、実際に独立した補助系統を数えた。二拍・複数枝・三殻を別系統として水増ししない。各行のcomposition/tier_reasonが根拠。

| ID | 演出量 | 主役 | 補助・装飾 |
|---|---|---|---|
| px50_inferno_bloom | S | 二圧の裂けた噴炎 | 局所の燃焼痕 |
| px50_comet_crash | M | 斜行頭と衝突後の側方噴流 | 弾道の小石 / 局所の着弾焦痕 |
| px50_storm_crown | S | 冠から接地へ伝播する枝放電 | 離れた接地点の短い残光 |
| px50_frost_cataclysm | M | 地表を渡る冷気前線 | 結晶の成長と落下 / 局所の霜痕 |
| px50_gravity_collapse | S | 流入から反発へ転じる重力流 | 地表の反発圧痕 |
| px50_earth_rift | M | 曲がった地裂からの噴圧 | 回転落下する土片 / 地裂に沿った圧力痕 |
| px50_plasma_breaker | S | 螺旋頭から衝撃扇への受け渡し | 着弾地点の裂けた焦痕 |
| px50_tidal_slam | S | 肩を越え腹から落下する水流 | 落水後の排水流路 |
| px50_fire_lance | S | 頭を追う熱尾つきの炎槍 | 着弾先の燃焼痕 |
| px50_ice_shot | M | 結晶頭と冷気の弾 | 着弾時の結晶破片 / 局所の着弾霜痕 |
| px50_chain_arc | S | 三地点を受け渡す枝放電 | 各接地点の残光 |
| px50_cross_cut | S | 時差のある交差斬撃 | 斬線に沿った床の跡 |
| px50_shield_break | M | 下から切れる湾曲障壁 | 外へ抜ける圧力 / 回転落下する障壁片 / 破断点の接触痕 |
| px50_sonic_punch | S | 短中長の三拍の音圧 | 床へ届く反響圧痕 |
| px50_echo_stitch | M | 三拍で左右を渡る反響主弧 | 主弧を追う低い反響尾 / 左右交互に開く受け皿 / 主弧と尾の間の縫い目と接続点の局所小紋 |

## 最終撮影の実数

共有review_px50.gdで --fixed-fps60 --record --duration7.2。各15種×216PNG=3240枚、960×540、出力30fps、0〜7.166667秒。素材の更新は12fps。全体/動き/出口各8コマの45シートを、15枚の24コマtriptychとして全て閲覧。4代表×2方向の8シートも閲覧した。

旧14は元のdist(legacyL9/M7)を維持、新作dist9/focus1.8m。角度比較4種はdist9、1.2〜1.9秒の0.1秒刻み。出力はgodot/tests/shots/vfx_review/px50_<variant>_frames、_full/_flow/_end.png、_qa53.png、_flow53_front/_side.png。

各frames/review_times.jsonにカタログ要求時刻・採用フレーム番号・実際の30fps秒数を保存。半フレーム時刻は最近傍の上側へ丸める。action_capture_manifest.jsonに全15のカット時刻/分類/連番数/ソースSHA256を保存。最後に両owned scriptの--check-onlyが成功。最終描画にGDScript/shaderエラーなし。全体テストは統合担当が一度行う。

## 凍結ソースSHA256

- `px50_action.gd`: `dd764a1236d1428875c0dc56938c52c4bf9dd754641b889b7c0436578caf7707`
- `shaders/action_flow.gdshader`: `253eb8b63ce4973ed767d69fe81066da9898155dc7bb6e167bbbde31725b602c`
- `shaders/action_ground.gdshader`: `102f2bef3fa8c8ec2fc0bc2569ff43ec01947ac7c642410115e58f9cf0a448c4`
- `px50_echo_stitch.gd`: `c2e7f13381a3facfff0ee6ce6eddff0d159eed76fbc5426c3e352bac4f0772d2`
- `shaders/echo_stitch.gdshader`: `f918329890c231986a757d3a8419ead73e6c7748b466e95352542bc3f82c8cb5`
- `action_catalog.json`: `48900cb93b5f7defd31dce0a27a46a669853ff44170e748ce908bc84491ef626`
- `additions_action_catalog.json`: `1651573d505ff214d2390b38beaaef45db794b8907b55fd255735d25b473c6b2`
