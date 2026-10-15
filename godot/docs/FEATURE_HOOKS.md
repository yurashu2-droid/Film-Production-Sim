# 新しい仕組みの足し方（登録の土台）

爆弾の道具・箱とロープ・特技…のような「仕組み」は、**決まった名前の関数**を持っておくと、中心のファイル
（`main.gd`・`production_main.gd`・`production_hud.gd`・`production_flow.gd`）が順に呼ぶ。
新しい仕組みを足すときに、中心のファイルを開かなくてよい（並行で作業しても、ぶつからない）。

- 土台：`scripts/feature_hooks.gd`（関数の名前の一覧 `HOOKS`、呼ぶ順番 `ORDER`・`ORDERS`）。ゲームからは `game.hooks`
- 確認：`bash tools/run_some.sh feature_hooks_test`（仕組みや中心のファイルを直したら、この1本を流す）

## 足し方

1. `scripts/features/<名前>.gd` を作る（`extends Node`、`var game: Node`）。**置くだけで**、全員の画面で、名前の順に作られて登録される
   （仕組みの名前＝ファイルの名前。物を作るなら `setup()` の中で。ほかの物が全部できたあとに呼ばれる）。
   ほかの仕組みからは `game.hooks.feature("<名前>")` で呼べる。
2. 下の関数のうち、要る物だけを書く。持っていない関数は、呼ばれないだけ。
3. 順番で結果が変わるとき（F をほかの仕組みより先に受けたい、など）だけ、`feature_hooks.gd` の `ORDERS` に名前を足す。
   足さなければ、今ある仕組みのあとに呼ばれる。
4. 確認を流す。

## 持てる関数

| 関数 | いつ呼ばれるか |
| --- | --- |
| `hook_events() -> Array` と `hook_event(n, a)` | 自分の合図（`game.host_ev("名前", [...])` で全員へ流した知らせ）の名前と、届いたときの処理。名前は、ほかの仕組みと重ねない |
| `hook_rec_events() -> Array` | 自分の合図のうち、見返し（録画）にも同じに流す物 |
| `hook_core_event(n, a)` | 中心の合図（`absent`＝借りた物が変わった・`burst`＝爆発・`state`＝段階が変わった など）のあと |
| `hook_sync(who)` | あとから入った人へ、今の状態を送る（ホスト） |
| `hook_f(me) -> bool` | F が押された。使ったら `true`（ほかへは回らない） |
| `hook_click(me) -> bool` | 手ぶらの左クリック。使ったら `true` |
| `hook_key(event, me) -> bool` | 自分のキー（歩いている間）。使ったら `true` |
| `hook_input(event) -> bool` | 自分の画面を開いている間の操作（どのキーよりも先）。使ったら `true` |
| `hook_hud(me, label, keys) -> Dictionary` | 画面の案内。`label`（狙った物の名前を替える。`keys_all` と組で）・`tail`（名前の横に足す）・`drop`（名前の横から消す文の一覧）・`keys`（操作の案内の先頭に足す）・`keys_all`（操作の案内を差し替える）。出す物が無ければ `{}` |
| `hook_grab_block(prop) -> String` | その物を持てない理由（`""`＝持てる） |
| `hook_new_job()` / `hook_return_office()` / `hook_office_ready()` | 依頼を受けた／帰社（置き場所を戻す前の後始末）／帰社のあと（ホスト） |
| `hook_production_applied()` | 会社の状態（依頼・注文・持ち物）が届いた |
| `hook_take_ready()` / `hook_take_start()` / `hook_take_cut()` | テイクを始める直前（撮り直しで戻す物を覚える）／本番が始まった／カット（ホスト） |
| `hook_retake()` / `hook_retake_done()` | 撮り直し：物の置き場所を戻す前／戻したあと（ホスト） |
| `hook_playback(on)` | 見返しの始まりと終わり（ホスト） |
| `hook_deliver(index) -> bool` | 画面（ボタン・Enter）から納品を頼まれた（ホスト）。`true` なら、その仕組みが先に何かを流し、終わったら自分で `game.h_deliver` を呼ぶ（試写会） |

名前を書きまちがえた `hook_〜` は、確認が「決まった名前に無い」と知らせる。

## 例：見て F で鳴らせる鐘（`scripts/features/bell.gd`）

```gdscript
extends Node
var game: Node
var bell: RigidBody3D

func setup() -> void:                      # 全員の画面で同じ順に呼ばれる（物のIDがそろう）
	bell = game.stage.spawn("bell", Vector3(60, 0.1, 20))

func hook_events() -> Array:               # 自分の合図
	return ["bell_ring"]

func hook_event(_n: String, a: Array) -> void:      # 全員の画面で鳴る
	Sfx.play("ui_ok", a[0])

func hook_rec_events() -> Array:           # 見返しでも鳴らす
	return ["bell_ring"]

func hook_f(me: Node) -> bool:             # 鐘を見て F
	if me.held != 0 or me.target != bell:
		return false                       # 使わない：ほかの仕組みへ回る
	h_ring.rpc_id(1)
	return true

@rpc("any_peer", "call_local", "reliable")
func h_ring() -> void:                     # 決めるのはホスト
	if Net.is_host():
		game.host_ev("bell_ring", [bell.global_position])

func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	return {"tail": "　[F] 鳴らす", "keys": "F 鐘を鳴らす"} if me.held == 0 and me.target == bell else {}
```

## 今ある仕組みと、まだ中心に残っている物

登録してある仕組み：`adhesive`（接着剤）・`cue_cards`（カンペ・等身大パネル）・`cargo_kit`（箱とロープ）・`bomb_kit`（爆弾の道具）・
`beats`（5場面の台本）・`rope_grab`（ロープをつかむ）・`talent`（特技）・`director`（監督の机）。
これらは `production_main.gd` の `_ready()` で作っている（物を作る順番が決まっているため）。
`scripts/features/` に置いてある仕組み：`online_room`・`premiere`（試写会）・`psychic_hold`。

まだ中心のファイルに直接書いてある物（動きは同じ。移すときは、順番が変わらないことを確かめる）：
接着剤・カンペ・特技の「あとから入った人への送り直し」（送る時が、ほかより早い）、特技と接着剤と机の画面の案内、
特技の片づけ（依頼を受ける前・帰社の最初）、爆弾の注文まわり（袋の数・届け方・爆発）、
場面の台本の合図キー（1・2）と時計、接着剤の記録（置き場所と一緒に覚える）、箱のふたが閉まるかどうか（`main.gd` が箱の仕組みに聞く）。
