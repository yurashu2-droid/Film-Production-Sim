# 残金0から無料廃材で一本撮る

2026-10-08、画面を描画する実行で、会社の残金を0にした倉庫依頼を確認した。バルコニー・効果機・台車・固定用品を一切借りず、無料の足場・廃板2枚・爆炎書割・月と会社のカメラ/ライト/カチンコだけを軽トラで運ぶ。

設営位置と合図は診断fixture。固定は本体のh_fixを使い、カメラ・ライト2台・廃板1枚の4か所だけ。残りの廃板・足場・書割・月は自由なRigidBodyのまま撮影を行った。上限を迂回して全部固定するfixtureにはしない。

輸送、到着位置、実4か所制限、告白、無料書割の背後爆発、再会、1350コインの納品、残金を持って帰社の8項目が成功。FREE_ROUND_OK、終了0。実カメラのsetup/blast/result画像を確認した。無料足場と廃板で、買い物できなくなった会社も本編を成立させられる。

診断はignored `godot/tests/shots/production_review/free_round.gd`、ログ `tools/diagnostics/production-free-round.log`、画像 `free_{setup,blast,result}.png`。人の初見プレイの実績とは区別する。
