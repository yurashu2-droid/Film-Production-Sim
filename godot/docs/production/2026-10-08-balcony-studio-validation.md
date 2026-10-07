# スタジオでバルコニーと無料爆炎書割を使う一周

2026-10-08、Godot4.7.2の実描画（Vulkan / RTX4060）で、通常productionの室内スタジオを検証した。共有ゲームコードは変更していない。F9 / h_sampleは使わず、見本配置の座標だけを参考にした。

バルコニー一式360コインと台車80コインを選択し、効果機は借りなかった。会社のカメラ・カチンコ・ライト2台に加え、借りたバルコニー・アーチ窓・台車、無料の爆炎書割・月を実際のtruck cargoに載せ、通常の8秒移動で現場へ運んだ。判定用の未輸送小道具は追加していない。到着後の配置と固定は既存 `film_round.gd` 同様のfixtureを使い、撮影進行・条件判定・納品・支払い・帰社は本番メソッドで通した。

## 結果

8チェックが成功し、終了コード0、stderrは空、`BALCONY_ROUND_OK`。

- 告白: 2.8秒で成立。
- 背後の爆発: 無料爆炎書割で4.6秒に成立。
- 再会: 10.0秒で成立。
- テイク13.03秒、スタッフ映り込み0秒、スタジオの追加注文も成立。
- 納品1350コイン（本編1200 + 追加150）。購入440、帰社時の財布1510。

実カメラ画像でも、バルコニー上の役者とアーチ窓、二人より奥で跳ね上がる爆炎書割を確認した。狭いstudioの壁や搬入空間で撮影・再会が止まる問題は出なかった。本番コードの修正は不要。

## 再実行と画像

リポジトリルートから、画面ありで実行:

```powershell
& tools/godot/Godot_v4.7.2-stable_win64_console.exe --path godot --fixed-fps 60 --script res://tests/shots/production_review/balcony_round.gd
```

fixtureは生成画像と同じignoredディレクトリにある。ログは `tools/diagnostics/balcony-studio.log` と `balcony-studio.err`。

代表画像:

- `godot/tests/shots/production_review/balcony_studio_confession_film.png`
- `godot/tests/shots/production_review/balcony_studio_board_film.png`
- `godot/tests/shots/production_review/balcony_studio_settled.png`

精算画像はカット直後のカチンコ演出が表示中。右の精算パネルと会社残金は読める。判定確認のためにフルテストや他現場の一周は繰り返していない。
