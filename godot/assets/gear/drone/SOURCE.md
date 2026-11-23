# 講師のドローンのモデル

- 作った人：ユーザー（Blender。2026-11-12）
- もとのファイル：`C:\Programer___Amano\遊び場\drone_bot\out\drone_pop.blend`（作るスクリプトは同じフォルダの `drone_pop.py`）
- ゲーム用の書き出し：`godot/assets/gear/drone/export_glb.py`

```bash
"C:/Program Files (x86)/Steam/steamapps/common/Blender/blender.exe" -b "C:/Programer___Amano/遊び場/drone_bot/out/drone_pop.blend" -P godot/assets/gear/drone/export_glb.py -- godot/assets/gear/drone/guide_drone.glb
```

書き出しでやっている事：

- 照明・カメラ・背景・下向きの光の筒は外す（光の筒は `scripts/holo_drone.gd` が描く）
- 手続きの材質は glb に入らないので、色・ざらつきの値だけにする（細かい汚れ・でこぼこは入らない）
- 面を減らす（32 万 → 9 万）。羽根 4 つ（`blades_0`〜`3`）は回すので別の物、ほかは `body` 1 つ
- 前（カメラの目）が +Z、上が +Y。幅は 72cm ほど
