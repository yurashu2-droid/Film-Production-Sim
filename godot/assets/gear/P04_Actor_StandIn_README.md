# P04 等身大・代役パネル

元ファイル：`小物/撮影機材/等身大パネル/P04_Actor_StandIn_Package.zip` の `delivery/P04_Actor_StandIn.glb`（変更なし）。
付属の説明書は同じ ZIP の `delivery/README_JA.txt`。権利：俳優の絵2種・木目・ラベルは、この成果物用のオリジナル（説明書の「権利」）。

## このゲームでの利用

- 形・比率はそのまま、等倍（幅0.83m × 奥行0.82m × 高さ1.91m）で使う。スクリプトは `godot/scripts/standin_panel.gd`。
- 前面の紙（材質 `P04_FRONT_IMAGE`、0.768m × 1.8m、比率 32:75）の画像だけを、ゲーム内ペイントの絵（512×1200）へ差し替える。
  板・木組み・クリップは元のモデルのまま。
- ペイントはカンペと同じ仕組み（`paint_board.gd`・`cue_cards.gd`・`cue_card_editor.gd`）。絵の具14色、下塗り、白紙に戻す。
- 付属の見本 `Actor_A_BaseColor.png`・`Actor_B_BaseColor.png` は `godot/assets/gear/standin/` に置き、ペイント画面の「見本を貼る」で貼れる。
- 見立てでは「ジョーカー」：何か描いてあれば、どの役でも「それっぽい」。コンボを1つ完成させる（`production_cast.gd` の joker）。
- 当たり判定は、立っている板・床の足2本・後ろの横木・斜めの支え2本（`godot/scripts/prop_shapes.gd` の表）。足の間は空いている。重心は低くしてある。
