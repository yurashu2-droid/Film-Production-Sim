# Pixel×Real 新作10種類

12コマ/秒のドットの形を、3Dの床・光・奥行きに置いた10種類。5色と固定セルの絵柄を共通にし、主役の形と出口はそれぞれ変えています。気体・液体の形は放出履歴と局所の流れから組み直し、固体の氷や花弁は割れ・曲がり・落下・風で運びます。

![10種類の一覧](../tests/shots/vfx_review/pixel_real_10_gallery.png)

[動画1：隕石〜段瀑](../tests/shots/vfx_review/pixel_real_10_part1.mp4) / [動画2：巻昇〜音圧](../tests/shots/vfx_review/pixel_real_10_part2.mp4)。各動画は960×540、30fps、5種類を番号と名前付きで順に収録。各エフェクトの主形更新は12fpsです。見本はこの作業で生成したローカルファイルです。

## 内容と呼び出し

| ID / ソース | 内容 | 出口 | 寿命 / 再生間隔 |
|---|---|---|---|
| [px_meteor](px_meteor.gd) 隕石 | 太い先頭が左上から降下し、細い首と火尾が遅れて追う | 地面の圧力帯、上へ抜ける火舌、落下する固体小石 | 4.8 / 5.2秒 |
| [px_lightning](px_lightning.gd) 三連放電 | 前兆から3回の違う分岐を下へ放電 | 上の供給から切れ、枝先・地表の導電路へ渡る | 4.4 / 4.8秒 |
| [px_fire_wave](px_fire_wave.gd) 三連火炎波 | 中央から左右へ3対。先肩と低い腹が違う放出年齢で進む | 供給が止まり、局所の舌が分かれて前・上へ抜ける | 5.1 / 5.5秒 |
| [px_plasma](px_plasma.gd) 圧縮プラズマ | 巻き込む圧縮から、短い頭と遅れ尾を右へ発射 | 着弾後も右へ流れ、短い肩が前・上へ消費される | 4.9 / 5.3秒 |
| [px_waterfall](px_waterfall.gd) 段瀑 | 3本の供給から水が落ち、地表の水舌へ変わる | 上から供給が空になり、最後の水が落ちて床へ抜ける | 5.0 / 5.5秒 |
| [px_vortex](px_vortex.gd) 巻昇 | 足元の3つの流路から、開いた巻き肩が上へ進む | 根元を切り、外・中・芯の末尾が違う時刻に昇る | 5.0 / 5.5秒 |
| [px_gravity](px_gravity.gd) 引力返し | 5方向の流入が中心で圧縮され、接線方向へ返る | 有限の供給の尾も中心を通り、外向きへ抜ける | 5.2 / 5.7秒 |
| [px_ice_break](px_ice_break.gd) 氷砕き | 氷面にひびが走り、時差で剥がれて落ちる | 着地した片が融水の膜へ変わり、縁から排出 | 5.0 / 5.5秒 |
| [px_petals](px_petals.gd) 花弁の風 | 8枚の花弁を不等間隔で放し、先端と腹を違う風で曲げる | 共通の突風が+X/-Zへ全弁を運ぶ | 5.0 / 5.5秒 |
| [px_sonic](px_sonic.gd) 音圧の三打 | 3打の開いた暖色の圧力膜。広い肩を遅い腹が追う | 下の供給から切れ、上の短い波頭が前方へ抜ける | 5.3 / 5.8秒 |

新作はすべて同じ呼び出しです。posは足元、サイズの初期値は1.0。ゲームの一時停止に従い、寿命で自身を片付けます。音圧を含め、これら10種に音声は付けていません。

```gdscript
const Effect := preload("res://pixel_vfx/px_meteor.gd")
Effect.spawn(self, feet_pos, 1.0)
```

`pixel_vfx/` 内のコードとシェーダーだけで動きます。`res://vfx/` への依存はありません。Forward+とHDRの3D照明で撮影しています。

## 最新の実描画確認

10種それぞれ198枚（6.6秒・30fps）を保存しました。撮影台の描画は固定60fps、距離9、960×540、左の基準人物は1.7m、中央箱は0.5m。既存3種の撮影済みデータと、現ソースから新たに撮影した7種を統合し、全10種の全体・流れ・終盤各8枚、合計30シートを実際に開いて確認しました。以下のリンクはその最新データです。

| 種類 | 全体8枚 | 流れ8枚（0.1秒刻み） | 終盤8枚（0.1秒刻み） |
|---|---|---|---|
| 隕石 | [全体](../tests/shots/vfx_review/px_meteor_root_whole.png) | [1.2〜1.9](../tests/shots/vfx_review/px_meteor_root_flow.png) | [3.6〜4.3](../tests/shots/vfx_review/px_meteor_root_end.png) |
| 三連放電 | [全体](../tests/shots/vfx_review/px_lightning_root_whole.png) | [.65〜1.35](../tests/shots/vfx_review/px_lightning_root_flow.png) | [3.2〜3.9](../tests/shots/vfx_review/px_lightning_root_end.png) |
| 三連火炎波 | [全体](../tests/shots/vfx_review/px_fire_wave_root_whole.png) | [1.8〜2.5](../tests/shots/vfx_review/px_fire_wave_root_flow.png) | [3.2〜3.9](../tests/shots/vfx_review/px_fire_wave_root_end.png) |
| 圧縮プラズマ | [全体](../tests/shots/vfx_review/px_plasma_root_whole.png) | [1.1〜1.8](../tests/shots/vfx_review/px_plasma_root_flow.png) | [3.7〜4.4](../tests/shots/vfx_review/px_plasma_root_end.png) |
| 段瀑 | [全体](../tests/shots/vfx_review/px_waterfall_root_whole.png) | [.7〜1.4](../tests/shots/vfx_review/px_waterfall_root_flow.png) | [3.8〜4.5](../tests/shots/vfx_review/px_waterfall_root_end.png) |
| 巻昇 | [全体](../tests/shots/vfx_review/px_vortex_root_whole.png) | [.6〜1.3](../tests/shots/vfx_review/px_vortex_root_flow.png) | [3.8〜4.5](../tests/shots/vfx_review/px_vortex_root_end.png) |
| 引力返し | [全体](../tests/shots/vfx_review/px_gravity_root_whole.png) | [.8〜1.5](../tests/shots/vfx_review/px_gravity_root_flow.png) | [4.0〜4.7](../tests/shots/vfx_review/px_gravity_root_end.png) |
| 氷砕き | [全体](../tests/shots/vfx_review/px_ice_break_root_whole.png) | [.7〜1.4](../tests/shots/vfx_review/px_ice_break_root_flow.png) | [3.8〜4.5](../tests/shots/vfx_review/px_ice_break_root_end.png) |
| 花弁の風 | [全体](../tests/shots/vfx_review/px_petals_root_whole.png) | [1.4〜2.1](../tests/shots/vfx_review/px_petals_root_flow.png) | [3.8〜4.5](../tests/shots/vfx_review/px_petals_root_end.png) |
| 音圧の三打 | [全体](../tests/shots/vfx_review/px_sonic_root_whole.png) | [1.25〜1.95](../tests/shots/vfx_review/px_sonic_root_flow.png) | [4.1〜4.8](../tests/shots/vfx_review/px_sonic_root_end.png) |

全体時刻と再生間隔のデータは [catalog_new10.json](catalog_new10.json)。放電の全体時刻を .1,.55,.95,1.70,2.48,2.70,3.25,3.9 に更新し、三回の主放電が読める時点を残しました。火炎波の終盤確認は3.2〜3.9に設定し、4.6秒（寿命0.5秒前）の空状態も全体シートで確認しています。

実見で目立った問題を修正しました。火炎波は直立した大きな布状の面を低い腹と局所の舌へ、プラズマは着弾後の輪を短い前方の出口へ変更しました。花弁は突風時に先端と腹の履歴差が広がりすぎたため、加速時の風の遅延窓を短くし、+X/-Zへ運ぶ出口に調整しました。修正対象は再撮影・再書き出しし、最新シートを再度開いています。

8つの確認観点は、素材の原因と進行方向、人物との規模、先行と遅れによる形の変化、暗外層/中層/短い明芯、空隙と奥行き、宙に止まる残骸、供給停止からの層別の退出、最終時刻の状態です。通常速度の動画を再生して目視したとはしていません。見た目に対するユーザー評価は未確認です。

Godot CLIの対象撮影はすべてexit0で、GDScript/shaderエラーなし。既存 `tests/pxtest.gd` は `PXTEST_OK` / exit0で、10種の生成・一時停止・寿命後の片付けを確認しました。全プロジェクトのテスト結果は、この範囲の確認とは別です。

## 見え方の限界

遠景では隕石・プラズマの細い奥層と花弁の床照明が弱くなります。放電は間隔と向きの違う薄い面のため真横では細く、氷面の分割はタイル状にも見えます。火炎波・音圧は角度によって弧や開いた布の輪郭に近づき、花弁の重なる視点では一束のリボンに見える余地があります。花弁の出口は風下への移動で、全方位から消える素材変化ではありません。

## 再生成

エディタは使わず、各IDを撮影してから書き出します。既存フレームを更新する場合も同じコマ数を指定します。

```powershell
./tools/godot/Godot_v4.7.2-stable_win64_console.exe --path godot --fixed-fps 60 --script res://tests/shots/review_pixel_pack.gd -- --fx=px_meteor --record --duration=6.6 --dist=9
python tools/export_pixel_real_10.py
```

撮影データはignored `godot/tests/shots/vfx_review/` にあります。書き出しは各IDの198枚を確認し、30シート・単体動画10本・連結動画2本・一覧画像を生成します。
