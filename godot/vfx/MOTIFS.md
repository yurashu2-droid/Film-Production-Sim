# 自然現象から作ったVFX 5案

ゲーム向けに誇張した試作。提示後にユーザーから過去の指摘を反映していないと指摘され、制作側も、物質の流れを満たしていない形の動きを「完成」とした判断を認めた。**成功の見本ではない。** 以下は実装構成の記録であり、要求を満たした品質の証明ではない。

`play_vfx.bat --only=motif_solar` で起動。Labの選択欄・左右キーで他の案へ切り替えられる。Pで停止、スロー再生、カメラ回転、撮影露出切り替えにも対応。

| 名前 / Lab ID | 力 → 形の変化 | 余韻・出口 | 主な実装 |
|---|---|---|---|
| 太陽 / `motif_solar` | 磁場で曲がる熱流が接近し、接合部から噴き出す | 流れが足元へ戻り、熱色が落ちる | 曲線に沿う立体断面・局所幅と温度の伝播 |
| 間欠泉 / `motif_geyser` | 地表の溜めから水柱が出て、水膜が外へ巻き返す | 縁が落水し、地表の波へ引き継ぐ | 水柱・水膜の頂点変形、落下と排水 |
| クシクラゲ / `motif_jelly` | 膜の圧力波と櫛列の虹が先行し、触手が遅れて追う | 膜が内側へ畳まれ上昇、触手は巻き取られる | 膜の変形・虹の行波・接続点の遅延履歴 |
| 磁性流体 / `motif_ferro` | 移動する磁場に液面の棘が追従し、冠状の波が走る | 棘が液面へ戻り、液面が中心へ排液 | 連続heightfield・移動する場・反射材質 |
| 種さや / `motif_seed` | 殻に溜まる張力から、先端→根元へ裂け目が走り、反る殻が種を放つ | 殻はさらに巻いて落ち、種は落下・小さく跳ねて地面へ戻る | 弧長で積分する殻の中心線・局所の反りと幅・種の弾道 |

5案はそれぞれ別のシェーダー。ノイズによる穴消しは使用していない。固体の種のみ独立した小物として飛ばし、液体・膜・熱流は主形状が連続的に変わる。`age` をシェーダーへ渡し、`TIME` に依存しない。

## 調べた資料と採用した要素

- [NASA: Parker Solar Probe / 磁場の組み替え](https://www.nasa.gov/science-research/heliophysics/switchbacks-science-explaining-parker-solar-probes-magnetic-puzzle/)。磁場の接続が変わり、プラズマの放出へつながる説明を、二つの流路と短い放出のモチーフにした。
- [NPS: How a Geyser Works](https://www.nps.gov/features/yell/tours/fountainpaint/geyser_works.htm)。水・熱・狭い流路での圧力を、溜め→噴出→落水という拍へ翻訳した。
- [MBARI: Biodiversity and Biooptics](https://www.mbari.org/news/biodiversity-and-biooptics-2020-expedition-log-1/)、[MBARI: Comb Jelly Bioluminescence](https://www.mbari.org/news/glow-your-own-comb-jellies-make-their-own-glowing-compounds-instead-of-getting-them-from-food/)。櫛列の虹は光の回折であり、生物発光とは異なる。創作では両方を参照し、透明膜と移動する色の波として誇張した。
- [NASA: Ferrofluid](https://www.nasa.gov/history/novel-rocket-fuel-spawned-ferrofluid-industry/)。磁場で液面が尖る現象から、独立コーンではなく連続した液面の隆起を作った。
- [Smithsonian: Explosive Fruit](https://naturalhistory.si.edu/research/botany/news/plant-press/explosive-fossil-fruit-found-buried-beneath-ancient-indian-lava-flows)。殻の繊維方向が異なることで張力・ねじりが生じ、種を飛ばす説明から、殻が反る反動を主役にした。

## 検証

- 通常露出と撮影露出で実描画。発生・最大形・崩壊と最後の0.5秒を確認。
- 既存 `tests/vfxtest.gd` に5案の生成・停止追従・自動片付けを追加。
- 全体の `bash run_tests.sh` は既存の `LAB_CHECK dust geometry expires FAIL` で停止。今回のVFXテストは個別実行で通過。

## プレビュー

- [5案を同時再生](../tests/shots/vfx_review/motifs_five.mp4)
- [太陽](../tests/shots/vfx_review/motif_solar.mp4) / [間欠泉](../tests/shots/vfx_review/motif_geyser.mp4) / [クシクラゲ](../tests/shots/vfx_review/motif_jelly.mp4) / [磁性流体](../tests/shots/vfx_review/motif_ferro.mp4) / [種さや](../tests/shots/vfx_review/motif_seed.mp4)

プレビューはローカルの制作資料でGit対象外。録画用スクリプトは `tests/shots/record_motif.gd`（`-- --id=solar`、`--film`、`--side`）、144フレーム・30fps。
