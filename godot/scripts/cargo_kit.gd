extends Node
## 運ぶ道具の入口：段ボール箱と、荷台にしばるロープ。仕組みは、3つのファイルに分けてある。
##   cargo_boxes.gd  段ボール箱（置き場・箱を取る・詰める・出す・こぼれる・中身の札）
##   cargo_lash.gd   荷台のロープ（フック・掛ける・ほどく・切る・押さえの計算・道中）
##   cargo_coils.gd  ひもの束（会社のロープと、足した束。残りの長さ）
## このファイルにあるのは、3つをつなぐ所だけ：
##   ・物を作る順番（物のIDを全員でそろえる）と、毎コマの順番
##   ・"kit" の合図：箱の中身と並び方、掛けたロープ（どのフックからどのフックへ・長さ・道すじの間引き）を、
##     まとめて全員へ配る・受け取る・見返しの記録に残す。決めるのはホストだけ
##   ・F の振り分け（何を持って、何を見ているかで、箱かロープかを決める）と、画面の案内
##   ・通信の入口（h_〜）。場所と名前を変えないために、ここに置いて、中身は各ファイルへ渡す
##   ・外から呼ばれている名前の受け渡し（game.cargo_kit.〜 は、分ける前と同じに使える）
## 箱の仕組みを直すなら cargo_boxes.gd、ロープなら cargo_lash.gd だけを開けばよい
const Boxes := preload("res://scripts/cargo_boxes.gd")
const Lash := preload("res://scripts/cargo_lash.gd")
const Coils := preload("res://scripts/cargo_coils.gd")

# 数値は、各ファイルが持っている（ここは、今までの名前で読めるようにしてあるだけ）
const CARTON_COUNT := Boxes.CARTON_COUNT
const SHOWN := Boxes.SHOWN
const YARD := Boxes.YARD
const SLOTS := Boxes.SLOTS
const PILE_AT := Boxes.PILE_AT
const ROPE_AT := Boxes.ROPE_AT
const SPILL_CHANCE := Boxes.SPILL_CHANCE
const DROP_EVERY := Boxes.DROP_EVERY
const DROP_REST := Boxes.DROP_REST
const GEAR := Boxes.GEAR
const OWN_F := Boxes.OWN_F
const REACH_MORE := Boxes.REACH_MORE
const ROPE_COLOR := Coils.ROPE_COLOR
const END_FREE := Lash.END_FREE
const END_COIL := Lash.END_COIL
const SCRAP := Coils.SCRAP
const HOOK_AIM := Lash.HOOK_AIM
const ROPE_AIM := Lash.ROPE_AIM
const CUT_AIM := Lash.CUT_AIM
const MIN_PIECE := Lash.MIN_PIECE
const KNOT_LOOSE := Lash.KNOT_LOOSE
const THROW_LOOSE := Lash.THROW_LOOSE
const BUMP_LOOSE := Lash.BUMP_LOOSE
const LIFT := Lash.LIFT
const SLACK_OK := Lash.SLACK_OK
const SLACK_BAD := Lash.SLACK_BAD
const FIRM_ON := Lash.FIRM_ON
const FIRM_OFF := Lash.FIRM_OFF
const WEAK_GRIP := Lash.WEAK_GRIP

var game: Node
var flow: Node
var boxes: Boxes = Boxes.new()                # 段ボール箱
var ropes: Lash = Lash.new()                  # 荷台のロープ
var reels: Coils = Coils.new()                # ひもの束
var rng := RandomNumberGenerator.new()        # 結び目のゆるみ・こぼれるかどうか（確認では、種を決めて同じ結果にできる）

var _before_replay := {}                      # 見返しの前の中身（見返しが終わったら戻す）
var _playback := false
var _before_take := {}                        # テイクを始める前の中身（撮り直しで戻す）


func _init() -> void:
	boxes.kit = self
	ropes.kit = self
	reels.kit = self


func _ready() -> void:
	# 軽トラが動いたあとで、ロープと、ロープが押さえた物を付いて行かせる
	process_physics_priority = 20
	rng.randomize()
	ropes.make_frame()


# 物を作る。全員の画面で同じ順に呼ぶ（物のIDがそろう）：箱 → ロープの束 → 段ボールの山
func setup() -> void:
	flow = game.production
	boxes.collect_cartons()
	reels.rope = game.stage.spawn("rope", boxes._at(ROPE_AT, 0.06), 0.6)
	reels._tint_rope(reels.rope.visual)
	boxes._build_pile()
	boxes._build_yard()
	boxes.marker = game._marker("段ボール置き場（箱・ロープ）", Vector3(YARD.get_center().x, 3.4, YARD.get_center().y))
	if Net.is_host():
		flow._home_layout[reels.rope.pid] = reels.rope.get_state()
		host_reset()
		host_refill()


func _process(_delta: float) -> void:
	if boxes.marker == null or flow == null:
		return
	var me: Node3D = game.local_player()
	ropes._show_marks(me)
	boxes._show_note(me)
	boxes.show_marker(me)


# 毎コマ：ロープ（全員の画面）→ 箱（ホストだけ）の順
func _physics_process(delta: float) -> void:
	if flow == null:
		return
	if ropes.physics(delta):
		boxes.host_physics(delta)


# ---- 3つのファイルが共通で使う物 ----

func _bk() -> Node:
	return game.get("bomb_kit")


func _host_ok() -> bool:
	return Net.is_host() and flow != null and not game.replaying and game.state in [game.S.PREP, game.S.TAKE] and flow.phase in [0, 2, 4]


func _say(who: int, text: String, bad: bool) -> void:
	game.ev.rpc_id(who, "toast", [text, 1 if bad else 0])


func _view(me: Node) -> Array:
	var cam: Camera3D = me.cam
	if cam == null:
		return []
	return [cam.global_position, -cam.global_basis.z]


# ---- 同期と記録（"kit" の合図） ----

func snapshot() -> Dictionary:
	return {"boxes": boxes.contents.duplicate(true), "lay": boxes.lay.duplicate(true), "lashes": ropes._lash_rows(true), "next": ropes._next_lash}


# 中身と掛けたロープの一覧を、全員へ配る（ホスト）。本番中の変化は、見返しのために記録にも残す
func _broadcast() -> void:
	var data := snapshot()
	if game.state == game.S.TAKE and not game.replaying:
		game._rec_events.append([game.take_t, "kit", [data]])
	game.ev.rpc("kit", [data])


# 一覧を受け取って、画面に反映する（全員）
func apply(data: Dictionary) -> void:
	var lite: bool = data.get("lite", false)
	if not Net.is_host() or _playback:
		ropes._apply_lashes(data, not lite)
	if lite:
		return
	boxes.apply(data)


func sync_to(who: int) -> void:
	if Net.is_host() and who != Net.my_id():
		game.ev.rpc_id(who, "kit", [snapshot()])


# 見返しの始まりと終わり（ホスト）。見返しの間は記録どおりに見せ、終わったら今の中身へ戻す
func playback_changed(on: bool) -> void:
	if not Net.is_host():
		return
	if on:
		_before_replay = snapshot()
		_playback = true
	elif not _before_replay.is_empty():
		_playback = false
		boxes.contents = (_before_replay["boxes"] as Dictionary).duplicate(true)
		boxes.lay = (_before_replay.get("lay", {}) as Dictionary).duplicate(true)
		# 見返しで掛け替わったロープは、いったん全部外してから、今の道すじで作り直す
		ropes.rebuild(_before_replay)
		_before_replay = {}
		game.ev.rpc("kit", [snapshot()])
	else:
		_playback = false


# ---- 操作（F）と画面の案内 ----

# いま F を押すと起きること。{"do": 種類, "target": 物, "why": できない理由}。関係なければ {}
#   unpack のときは item（取り出す物のID）と point（その物の上）も入る
#   do：hook（フックに結ぶ）・unhook（結んだばかりのフックから外す）・untie（掛けたロープをほどく）・cut（はさみで切る）・
#       rope（ロープを持っているが何も狙っていない）/ pack（箱に入れる）/ unpack（取り出す）/ lid（開け閉め）/ take（山から1箱）
# 持っている物で振り分ける：束・はさみはロープ（cargo_lash.gd）、ほかの物は箱（cargo_boxes.gd）。
# 手ぶらなら、先にロープ（ほどく）、次に箱
func f_action(me: Node) -> Dictionary:
	if me == null or flow == null or me.operating != 0 or flow.phase not in [0, 2, 4] or game.state not in [game.S.PREP, game.S.TAKE]:
		return {}
	var target: Node3D = me.target
	var held: Node3D = game.props.get(me.held) if me.held != 0 else null
	var bk := _bk()
	if held != null and reels.is_coil(held):
		return ropes.act_with_coil(me, held)
	if held != null and bk != null and held == bk.scissors:
		return ropes.act_with_scissors(me)
	if held != null:
		return boxes.act_holding(held, target)
	var line: Dictionary = ropes.act_free(me, target)
	if not line.is_empty():
		return line
	return boxes.act_free(me, target)


# F が押された（自分の画面）。ここで受けたら true
func handle_f(me: Node) -> bool:
	var act := f_action(me)
	if act.is_empty():
		return false
	match str(act["do"]):
		"rope":
			# 束を持っているだけ：F はほかの使い道（荷台に積む）へ回す
			return false
		"hook", "unhook":
			h_hook.rpc_id(1, int(act["hook"]))
		"untie":
			h_untie.rpc_id(1, int(act["lash"]))
		"cut":
			h_cut_lash.rpc_id(1, int(act["lash"]), float(act["s"]))
		"pack":
			h_pack.rpc_id(1, int(me.held), int(act["target"].pid))
		"unpack":
			h_unpack.rpc_id(1, int(act["target"].pid), int(act["item"]))
		"lid":
			game.act_toggle_carton(int(act["target"].pid))
		"take":
			h_take_carton.rpc_id(1)
	return true


# 画面の案内。production_hud.gd が、狙っている物の名前の横と、下の操作の案内へ足す。
#   label：狙っている物の名前を、これに替える / drop：名前の横から消す文 / name・note：その名前の直後に足す文 /
#   tail：最後に足す文 / keys：操作の案内の先頭に足す文 / keys_all：操作の案内をまるごと差し替える文
# 文そのものは、ロープは cargo_lash.gd、箱は cargo_boxes.gd の hud_for() が決める
func hud_view(me: Node) -> Dictionary:
	if me == null or flow == null:
		return {}
	var out := {}
	var target: Node3D = me.target
	var held: Node3D = game.props.get(me.held) if me.held != 0 else null
	# 中身のある箱を持っているときは、中身も出す
	if held != null and held.kind == "carton" and not boxes.box_items(held).is_empty():
		out["tail"] = "　" + boxes.box_note(held)
	var act := f_action(me)
	if act.is_empty():
		return out
	if str(act["do"]) in ["rope", "hook", "unhook", "untie", "cut"]:
		var put: String = ("\n" + str(game.hold_hint())) if held != null else ""
		ropes.hud_for(act, put, out)
	else:
		boxes.hud_for(act, held, target, out)
	return out


# ---- 通信の入口（ホストへの頼み）。場所と名前は、分ける前と同じ。中身は各ファイル ----

# 山を見て F：手に1箱もらう
@rpc("any_peer", "call_local", "reliable")
func h_take_carton() -> void:
	boxes.h_take_carton()


# 物を持って、開いた箱を見て F：箱に入れる
@rpc("any_peer", "call_local", "reliable")
func h_pack(item_pid: int, box_pid: int) -> void:
	boxes.h_pack(item_pid, box_pid)


# 手ぶらで、中身のある開いた箱を見て F：見ている物（item_pid。0 や、もう無い物なら、いちばん上の物）を取り出して手に持つ
@rpc("any_peer", "call_local", "reliable")
func h_unpack(box_pid: int, item_pid: int = 0) -> void:
	boxes.h_unpack(box_pid, item_pid)


# 束を持って、フックを見て F：端を結ぶ／掛けている途中なら、もう片方を結ぶ／結んだばかりのフックなら、ほどく
@rpc("any_peer", "call_local", "reliable")
func h_hook(index: int) -> void:
	ropes.h_hook(index)


# 掛けたロープを見て F（手ぶら、または束を持って）：ほどく
@rpc("any_peer", "call_local", "reliable")
func h_untie(id: int) -> void:
	ropes.h_untie(id)


# はさみを持って、掛けたロープを見て F：根元から s（m）の所で切る。切れた先は、それぞれのフックから垂れ下がる
@rpc("any_peer", "call_local", "reliable")
func h_cut_lash(id: int, s: float) -> void:
	ropes.h_cut_lash(id, s)


# ---- 外から呼ばれている名前の受け渡し（中身は各ファイル） ----

var cartons: Array:
	get:
		return boxes.cartons
	set(value):
		boxes.cartons = value
var pile: RigidBody3D:
	get:
		return boxes.pile
	set(value):
		boxes.pile = value
var contents: Dictionary:
	get:
		return boxes.contents
	set(value):
		boxes.contents = value
var lay: Dictionary:
	get:
		return boxes.lay
	set(value):
		boxes.lay = value
var marker: Label3D:
	get:
		return boxes.marker
	set(value):
		boxes.marker = value
var spill_chance: float:
	get:
		return boxes.spill_chance
	set(value):
		boxes.spill_chance = value
var _note: Label3D:
	get:
		return boxes._note
	set(value):
		boxes._note = value
var lashes: Dictionary:
	get:
		return ropes.lashes
	set(value):
		ropes.lashes = value
var holds: Dictionary:
	get:
		return ropes.holds
	set(value):
		ropes.holds = value
var rope: RigidBody3D:
	get:
		return reels.rope
	set(value):
		reels.rope = value
var coils: Dictionary:
	get:
		return reels.coils
	set(value):
		reels.coils = value


# 段ボール箱（cargo_boxes.gd）
func reserve() -> Array:
	return boxes.reserve()


func host_refill() -> void:
	boxes.host_refill()


func host_reset() -> void:
	boxes.host_reset()


func box_items(box: Node) -> Array:
	return boxes.box_items(box)


func slot_of(box_pid: int, pid: int) -> Transform3D:
	return boxes.slot_of(box_pid, pid)


func blocks(box: Node) -> Array:
	return boxes.blocks(box)


func box_over(box: Node) -> float:
	return boxes.box_over(box)


func lid_blocked(box: Node) -> bool:
	return boxes.lid_blocked(box)


func slot_for(item: Node3D, box: Node) -> Dictionary:
	return boxes.slot_for(item, box)


func fits_alone(item: Node3D) -> bool:
	return boxes.fits_alone(item)


func top_item(box: Node) -> int:
	return boxes.top_item(box)


func aim_item(me: Node, box: Node) -> int:
	return boxes.aim_item(me, box)


func _short(prop: Node) -> String:
	return boxes._short(prop)


func box_note(box: Node) -> String:
	return boxes.box_note(box)


func pack_ban(item: Node3D) -> String:
	return boxes.pack_ban(item)


func pack_problem(item: Node3D, box: Node) -> String:
	return boxes.pack_problem(item, box)


func host_restore(data: Dictionary) -> void:
	boxes.host_restore(data)


func _show_note(me: Node3D) -> void:
	boxes._show_note(me)


# 荷台のロープ（cargo_lash.gd）
func hook_at(index: int) -> Vector3:
	return ropes.hook_at(index)


func open_lash(coil: int = 0) -> Dictionary:
	return ropes.open_lash(coil)


func lash_count() -> int:
	return ropes.lash_count()


func grip_of(pid: int) -> float:
	return ropes.grip_of(pid)


func pinned(pid: int) -> bool:
	return ropes.pinned(pid)


func _undo(id: int) -> void:
	ropes._undo(id)


func host_hang(path: PackedVector3Array, length: float, index: int, who: int) -> int:
	return ropes.host_hang(path, length, index, who)


func host_tie_end(id: int, index: int, who: int) -> bool:
	return ropes.host_tie_end(id, index, who)


func host_coil_taken() -> void:
	ropes.host_coil_taken()


func host_clear_lashes(refund: bool = true) -> void:
	ropes.host_clear_lashes(refund)


func host_loosen(id: int, by: float) -> void:
	ropes.host_loosen(id, by)


func aim_hook(me: Node) -> int:
	return ropes.aim_hook(me)


func aim_lash(me: Node, aim: float) -> Dictionary:
	return ropes.aim_lash(me, aim)


# ひもの束（cargo_coils.gd）
func add_coil(prop: RigidBody3D, bank: Object, color: Color) -> void:
	reels.add_coil(prop, bank, color)


func is_coil(prop: Node) -> bool:
	return reels.is_coil(prop)


func coil_id(prop: Node) -> int:
	return reels.coil_id(prop)


func coil_prop(coil: int) -> RigidBody3D:
	return reels.coil_prop(coil)


func stock(coil: int = 0) -> float:
	return reels.stock(coil)


func _coil_exit(coil: int = 0) -> Vector3:
	return reels._coil_exit(coil)


# ---- 登録（feature_hooks.gd）。決まった名前の関数を持っていると、中心の側が呼ぶ ----

func hook_events() -> Array:
	return ["kit"]


# "kit"：箱の中身と、荷台に掛けたロープ
func hook_event(_n: String, a: Array) -> void:
	apply(a[0])


func hook_sync(who: int) -> void:
	sync_to(who)


# F：段ボール箱（入れる・取り出す・開け閉め・山から1箱）と、ロープ（フックに結ぶ・ほどく・切る）
func hook_f(me: Node) -> bool:
	return handle_f(me)


# 画面の案内：狙った箱の中身・できる操作（入れる・取り出す・フックに結ぶ・ほどく）。文は hud_view() が決める
func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	if flow == null or flow.phase not in [0, 2, 4] or me.operating != 0 or game.state not in [game.S.PREP, game.S.TAKE]:
		return {}
	return hud_view(me)


# 準備中にテイクを始める直前：箱の中身と掛けたロープを覚える（撮り直しで戻す）
func hook_take_ready() -> void:
	_before_take = snapshot()


# 本番が始まった：見返しの最初に、撮り始めたときの箱の中身へ戻す
func hook_take_start() -> void:
	game._rec_events.append([0.0, "kit", [snapshot()]])


# 撮り直し：箱の中身を、テイクを始める前に戻す（物の置き場所は、このあと main.gd が戻す）
func hook_retake() -> void:
	host_restore(_before_take)


func hook_playback(on: bool) -> void:
	playback_changed(on)


# ロープがしっかり押さえている物は、引っぱっても抜けない
func hook_grab_block(prop: Node) -> String:
	return "ロープが押さえていて、抜けない（ロープを見て F でほどく）" if pinned(prop.pid) else ""


# 帰社：中身を全部出し、ロープをほどき、箱を置き場の奥へ戻す
func hook_return_office() -> void:
	host_reset()


# 帰社のあと：置き場に、箱を出し直す
func hook_office_ready() -> void:
	host_refill()
