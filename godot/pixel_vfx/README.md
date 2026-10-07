# Pixel × Real VFX（Godot 4.7 / Forward+）

ドット絵の絵柄を、3D の光と奥行きの中に置くエフェクト集。テクスチャ画像は使わず、絵はすべてシェーダーとコードで描く。
このフォルダだけで動く（`res://vfx/` には依存しない）。別プロジェクトへはフォルダごとコピーすればよい。

## 絵柄の決まり

- マス目：絵は決まった解像度のマスに丸める。立方体もマス目の位置にしか置かない
- 色：1エフェクトにつき 5 色（暗→明）。中間色は作らず、境目は市松のディザで混ぜる
- 動き：12 コマ/秒で止め絵を送る（位置も模様も同じコマで動く）
- リアル側：明るい色だけが光り、床を照らす。立方体は光と影を受ける
- 消え方：フェードしない。マスや区画が点滅して欠けていく

## 使い方

```gdscript
const PxFlame := preload("res://pixel_vfx/px_flame.gd")
const PxBurst := preload("res://pixel_vfx/px_burst.gd")
const PxPortal := preload("res://pixel_vfx/px_portal.gd")
const PxTeleport := preload("res://pixel_vfx/px_teleport.gd")

var flame := PxFlame.spawn(self, pos)                      # 燃え続ける。flame.extinguish() で消す
PxFlame.spawn(self, pos, 1.0, 3.0, "toxic")                # 大きさ, 秒数, 色
PxBurst.spawn(self, pos)                                   # ボクセル爆発。pos は中心
PxBurst.spawn(self, pos, 1.5, 1.0, "ice")                  # 大きさ, 床までの距離, 色
PxPortal.spawn(self, pos, 1.0, 3.0, "arcane")              # 大きさ, 開いている秒数, 色
var tp := PxTeleport.spawn(self, feet_pos, 1.0, 1.7, "ice") # 大きさ, 体の高さ, 色
tp.materialized.connect(func(): character.visible = true)  # 組み上がった瞬間
```

色は `fire` `ice` `toxic` `arcane` `gold`。増やすときは `px_base.gd` の `PALETTES` に 5 色を足す。
出したエフェクトは自分で消える（燃え続ける炎だけ `extinguish()` が要る）。ゲームを一時停止すると止まる。

## 中身

| ファイル | 役割 |
|---|---|
| `px_base.gd` | 時間の進行、12 コマ送り、色、板と立方体の部品 |
| `px_flame.gd` | 炎：奥・中・手前の 3 枚、床の光、火の粉の立方体、消えたあとの煙 |
| `px_burst.gd` | 爆発：光る殻の立方体、破片、煙、床の輪 |
| `px_portal.gd` | ポータル：奥行きをずらした 4 枚の輪、中の闇、回る立方体 |
| `px_teleport.gd` | 転送：魔法陣、光の柱、集まって体を組む立方体 |
| `shaders/px_common.gdshaderinc` | マス目・ディザ・色の段の共通関数 |
| `shaders/px_fire` `px_polar` `px_beam` `px_blob` `px_voxel` | 炎、輪と魔法陣、柱、丸い絵、立方体 |

## 確かめ方

```bash
./tools/godot/Godot_v4.7.2-stable_win64_console.exe --path godot --headless --script res://tests/pxtest.gd
```

見た目は `play_vfx.bat` の一覧にある「Pixel×Real」の 4 つ。

## アセットとして配る前に残っていること

- 動きは静止画のコマでしか確かめていない。実際に再生して目で見る確認がまだ
- Forward+ とグロー（HDR）前提。Mobile / Compatibility では光り方が変わる
- 見本シーン、色を選ぶ操作、英語の説明、ライセンス表記
