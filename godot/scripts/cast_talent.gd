extends Node
## キャラごとの特技（K キー）。表と決まりは cast_talents.gd。
## ここは、状態（誰が何を頭にしまっているか・ランプ・手帳）と、ホストの判断と、全員の画面の見た目。
##
## 通信
##   h_use / h_take ：押した人 → ホスト
##   "stow" / "lamp" / "shawl" / "halt" / "neck" / "hair"：ホスト → 全員（game.ev の合図。本番中は録画され、見返しでも流れる）
##   "note"         ：手帳の人が、台本の写しを開いた・閉じた（録画しない）
##   "talent_sync"  ：いまの状態をまとめて送る（あとから入った人・中身がこぼれたとき・撮り直し）
##   "talent_take"  ：テイクを始めたときの状態（録画の先頭に入れる。見返しの最初に使う）
## しまった物は prop.set_stored(−参加者のID) で「現場に無い物」と同じ扱いになる（段ボール箱の中身と同じ土台）。
##
## あとから足した4人。残りは、数字では出さない。キャラや物の見た目で分かるようにする（見た目の部品は cast_talent_looks.gd）
##   ドレスの人「ショールをかける」：物にかけると、見立ての「むりやり」が「それっぽい」になる（production_cast.gd の fit）。
##     1つの依頼で2枚。残りは、肩に掛かっている枚数。風や爆風でずれ、ずれきると飛ぶ（となりの物に引っかかるか、無くなる）
##   カエルの警官「止まれ！」：前方の扇形にある固定していない物を、2秒止める（速さを消し、重力を切る。終わったら戻す）。
##     次に使えるまで8秒。背中の赤い札が、使うと倒れて、ゆっくり起き上がる
##   モップの王様「毛ひも」：毛の束を手に出す。荷台に掛けるロープ（cargo_kit.gd）の、もう1つの束として働く。
##     長さは1つの依頼で6m。残りは、頭の房の量。ほどけば頭に戻る
##   ベレー帽の人「びよーん首」：伸ばしている間、視点と手の届く基準が 0.5m 上がり、離れた確認用モニターものぞける。走れない
## 役（Y）は、しまっても残る。頭の中の物は映らない。
## autoload（Net・Sfx）は名前で呼ばない（単体のテストから読み込めるように）。音と知らせは game.ev で出す。

const Talents := preload("res://scripts/cast_talents.gd")
const Looks := preload("res://scripts/cast_talent_looks.gd")
const Roles := preload("res://scripts/production_cast.gd")
const Prop := preload("res://scripts/prop.gd")
const NeckStretch := preload("res://scripts/neck_stretch.gd")
const EVENTS := ["stow", "lamp", "note", "shawl", "halt", "neck", "hair", "talent_sync", "talent_take"]
const BOX_HEAD := "09"
const ROBOT := "M02"
const NOTEBOOK := "03"
const SHAWL := "01"
const HALT := "02"
const HAIR := "06"
const NECK := "04"
const HAIR_STORED := -(1 << 30)      # しまってある毛の束の stored_in（どの参加者の体でもない、負の値）
# 頭の上に並べる場所（キャラの素材の大きさで）と、傾け方。本人の画面（後ろから見る）で、左から入れた順になる
const SLOT_AT := [Vector3(0.46, 0.0, 0.04), Vector3(-0.02, 0.0, -0.14), Vector3(-0.48, 0.0, 0.06)]
const SLOT_LEAN := [-0.26, 0.05, 0.24]
const SLOT_TURN := [-0.5, 0.2, 0.6]

var game: Node
var stowed := {}          # 参加者のID → しまってある物のID（古い順。最後が、次に出る物）
var lamps := {}           # 参加者のID → true（ランプを点けているロボット）
var notes := {}           # 参加者のID → true（台本の写しを開いている手帳の人）
var shawls := {}          # 物のID → [かけた人のID, ずれ（0〜1。1 で飛ぶ）, ずれる向き（物から見た Vector2）]
var shawl_lost := {}      # 参加者のID → 風や爆風で飛んで、無くなったショールの枚数
var necks := {}           # 参加者のID → true（首を伸ばしているベレー帽の人）
var hair := {}            # 毛の束の物のID → [持ち主のID（0＝まだ誰の物でもない）, 手に出しているか, 残りの長さ m]
var hair_coils: Array = []           # 毛の束（物）。参加者の数だけ、最初に作っておく
var halt_wait := {}       # 参加者のID → 「止まれ！」を次に使えるまでの残り秒（背中の札の起き上がり具合）
var rng := RandomNumberGenerator.new()      # 布のずれ方（確認では、種を決めて同じ結果にできる）

var _halted := {}         # ホスト：止めている物（物のID → 残り秒）
var _halt_view := {}      # 見返し中だけ使う：録画のときの「止まれ！」の残り秒
var _shawl_nodes := {}    # 物のID → [布の見た目, 作ったときの形の控え]
var _gusting := false     # ホスト：風が吹いている最中か（吹き始めを1回だけ拾う）
var _hair_dirty := false
var _hair_send := 0.0

var _view := {}           # 見返し中だけ使う：録画のときの状態（snapshot() と同じ形）
var _layout := {}         # テイクを始める前の状態（撮り直しで戻す。ホストだけ）
var _state := -1          # 直前の game.state
var _was_replaying := false
var _last_at := {}        # 物をしまっている人が、最後にいた場所（抜けた人の中身をこぼす所。ホストだけ）


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


# ---- 読み取り ----

# いま特技を使えるか：会社での準備中と、現場（準備・カウントダウン・本番）
func usable() -> bool:
	var flow: Node = game.production
	return flow != null and flow.phase in [2, 4] and game.state in [game.S.PREP, game.S.COUNTDOWN, game.S.TAKE] and not game.replaying


# 名簿に載っている、いまのキャラ。見返し中は見た目が録画のときのキャラに替わるので、見た目では決めない
func cast_of(who: int) -> String:
	for member: Array in game._roster:
		if member[0] == who:
			return game.PLAYER_CASTS[member[1]]
	return ""


func crew_name(who: int) -> String:
	for member: Array in game._roster:
		if member[0] == who:
			return game.PLAYER_NAMES[member[1]]
	return "制作班"


func stowed_of(who: int) -> Array:
	return stowed.get(who, [])


func lamp_on(who: int) -> bool:
	return lamps.has(who)


# 手帳の人が、台本の写しを開いているか（開いている本人の画面に、台本のページが出る）
func note_open(who: int) -> bool:
	return notes.has(who)


# 画面に出す中身。見返し中は、録画のときの中身
func shown_stowed(who: int) -> Array:
	if game.replaying:
		return (_view.get("stowed", {}) as Dictionary).get(who, [])
	return stowed.get(who, [])


func shown_lamp(who: int) -> bool:
	if game.replaying:
		return who in (_view.get("lamps", []) as Array)
	return lamps.has(who)


func short_name(prop: Node) -> String:
	return str(prop.label).get_slice("（", 0)


# 見返し中は、録画のときの状態（_view）を見せる
func _shown(key: String, live: Variant) -> Variant:
	return _view.get(key, live) if game.replaying else live


# ---- ドレスの人「ショールをかける」 ----

# その物に、ショールがかかっているか（production_flow.gd の cast_tags が見る）
func shawled(pid: int) -> bool:
	return shawls.has(pid)


func shown_shawls() -> Dictionary:
	return _shown("shawls", shawls)


# その人の肩に残っているショールの枚数（かけた分と、飛んで無くなった分を引く）
func _shawls_left(who: int, rows: Dictionary, lost: Dictionary) -> int:
	var used: int = int(lost.get(who, 0))
	for row: Array in rows.values():
		if int(row[0]) == who:
			used += 1
	return maxi(0, Talents.SHAWL_COUNT - used)


func shawls_left(who: int) -> int:
	return _shawls_left(who, shawls, shawl_lost)


func shown_shawls_left(who: int) -> int:
	return _shawls_left(who, shown_shawls(), _shown("lost", shawl_lost))


# その人が、その物にショールをかけられない理由（""＝かけられる）
func shawl_refusal(who: int, prop: Node) -> String:
	if prop == null or prop.absent or prop.stored_in != 0:
		return "かけられる物が無い"
	if not Roles.castable(prop.kind):
		return "役を付けられない物には、かけられない"
	if prop.holder != 0:
		return "だれかが持っている物には、かけられない"
	if shawls.has(prop.pid):
		return "もう、かかっている"
	if shawls_left(who) <= 0:
		return "肩のショールは、もう無い（かけた物を見て K で外す）"
	return ""


# ---- カエルの警官「止まれ！」 ----

# その物が、いま止められているか（production_flow.gd の突風が見る）
func halted(pid: int) -> bool:
	return _halted.has(pid)


# その物を、止められるか
func halt_ok(prop: Node) -> bool:
	if prop.absent or prop.stored_in != 0 or prop.holder != 0 or prop.fixed or prop.immovable or prop.freeze:
		return false
	if prop.kind in Talents.HALT_NEVER or prop.kind == Talents.HAIR_KIND:
		return false
	return not ("operator" in prop and prop.operator != 0)


# 背中の札の起き上がり具合（1＝使える 〜 0＝使ったばかり）
func halt_ready(who: int) -> float:
	var left: float = float((_halt_view if game.replaying else halt_wait).get(who, 0.0))
	return 1.0 - clampf(left / Talents.HALT_WAIT, 0.0, 1.0)


# ---- モップの王様「毛ひも」 ----

# その人の毛の束（無ければ null）
func hair_coil_of(who: int) -> RigidBody3D:
	for coil: RigidBody3D in hair_coils:
		if int(hair[coil.pid][0]) == who:
			return coil
	return null


func hair_out(who: int) -> bool:
	var coil := hair_coil_of(who)
	return coil != null and bool(hair[coil.pid][1])


# その人の毛の残り（m）。まだ使っていなければ、いっぱい
func _hair_left(who: int, rows: Dictionary) -> float:
	for row: Array in rows.values():
		if int(row[0]) == who:
			return float(row[2])
	return Talents.HAIR_M


func hair_left(who: int) -> float:
	return _hair_left(who, hair)


func shown_hair_left(who: int) -> float:
	return _hair_left(who, _shown("hair", hair))


# 荷台に掛けるロープの仕組み（cargo_kit.gd）から呼ばれる：その束に残っている長さ
func coil_stock(pid: int) -> float:
	return float(hair[pid][2]) if hair.has(pid) else 0.0


# 束から出す（負なら、巻き戻す）。知らせは、少し間を空けてまとめて送る
func coil_use(pid: int, amount: float) -> void:
	if not hair.has(pid):
		return
	hair[pid][2] = clampf(float(hair[pid][2]) - amount, 0.0, Talents.HAIR_M)
	_hair_dirty = true


# ---- ベレー帽の人「びよーん首」 ----

# その人が、首を伸ばしているか（production_flow.gd の near_monitor が見る）
func neck_out(who: int) -> bool:
	return necks.has(who)


func shown_neck(who: int) -> bool:
	return who in (_shown("necks", necks.keys()) as Array)


# その人が、その物を頭にしまえない理由（""＝しまえる）。断っても失格にはしない。手で持つのは今までどおり
func stow_refusal(who: int, prop: Node) -> String:
	if prop == null or prop.absent or prop.stored_in != 0:
		return "しまえる物が無い"
	var why: String = Talents.stow_refusal(prop.kind, prop.half, prop.mass)
	if why != "":
		return why
	if prop.immovable or prop.fixed:
		return "固定してある物はしまえない"
	if prop.holder != 0 and prop.holder != who:
		return "ほかの人が持っている"
	if game.adhesive != null and game.adhesive.connected_ids(prop.pid).size() > 1:
		return "接着した物はしまえない"
	for other: Node in game.props.values():
		if other.stored_in == prop.pid:
			return "中に物が入っている"
	if stowed_of(who).size() >= Talents.STOW_SLOTS:
		return "頭の道具箱がいっぱい（%dつまで）。Shift+K で出す" % Talents.STOW_SLOTS
	return ""


# 頭のてっぺんの場所（しゃがむ・のけぞる動きにも付いていく）
func head_top(pl: Node) -> Vector3:
	var vis: Node3D = pl.vis
	var bone: int = vis.skel.find_bone("HEAD")
	if bone < 0:
		return pl.global_position + Vector3(0, vis.height + 0.3, 0)
	var rise: float = _head_top_y(vis) - vis.skel.get_bone_global_rest(bone).origin.y
	return vis.skel.global_transform * (vis.skel.get_bone_global_pose(bone).origin + Vector3(0, rise, 0))


# 頭のてっぺんの高さ（キャラの素材の大きさで。体のメッシュのいちばん上）
func _head_top_y(vis: Node3D) -> float:
	if vis.has_meta("talent_top"):
		return float(vis.get_meta("talent_top"))
	var top := 0.0
	for mesh: MeshInstance3D in vis.skel.find_children("*", "MeshInstance3D", true, false):
		top = maxf(top, mesh.get_aabb().end.y)
	vis.set_meta("talent_top", top)
	return top


func lamp_origin(pl: Node) -> Vector3:
	return (pl.vis as Node3D).global_transform * Talents.LAMP_AT


func lamp_dir(pl: Node) -> Vector3:
	return ((pl.vis as Node3D).global_basis * Vector3(0, sin(Talents.LAMP_TILT), cos(Talents.LAMP_TILT))).normalized()


# 採点に足す明るさ（judge.gd の brightness から呼ぶ）：ランプを点けたロボットが、向いた先だけを弱く照らす
func lamp_light(space: PhysicsDirectSpaceState3D, point: Vector3) -> float:
	var sum := 0.0
	for who: int in lamps:
		var pl: Node = game.players.get(who)
		if pl == null or pl.vis.tag != ROBOT:
			continue
		var from: Vector3 = lamp_origin(pl)
		var to: Vector3 = point - from
		var distance: float = to.length()
		if distance < 0.01 or distance >= Talents.LAMP_RANGE:
			continue
		var power: float = Talents.lamp_falloff(rad_to_deg(lamp_dir(pl).angle_to(to)), distance)
		if power <= 0.0 or game.judge._blocked(space, from, point, [pl.get_rid()]):
			continue
		sum += Talents.LAMP_FACTOR * power
	return sum


func snapshot() -> Dictionary:
	return {"stowed": stowed.duplicate(true), "lamps": lamps.keys(), "notes": notes.keys(),
		"shawls": shawls.duplicate(true), "lost": shawl_lost.duplicate(), "necks": necks.keys(),
		"hair": hair.duplicate(true), "halts": halt_wait.duplicate()}


# 物を作る（毛の束）。全員の画面で同じ順に呼ぶ（物のIDがそろう）。cargo_kit.gd を作ったあとに呼ぶ
func setup() -> void:
	rng.randomize()
	var kit: Variant = game.get("cargo_kit")
	for i in Talents.HAIR_COILS:
		var coil: RigidBody3D = Prop.new()
		coil.kind = Talents.HAIR_KIND
		coil.label = "毛ひも"
		coil.mass = 0.5
		coil.center = Vector3(0, 0.07, 0)
		coil.half = Vector3(0.16, 0.07, 0.16)
		coil.hold_min = 1.1
		coil.visual = Looks.hair_bundle()
		coil.add_child(coil.visual)
		var solid := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = coil.half * 2.0
		solid.shape = box
		solid.position = coil.center
		coil.add_child(solid)
		game.stage._register(coil, Vector3(float(game.props.size() + 1) * 3.0, -60.0, 38.0), 0.0)
		coil.set_stored(HAIR_STORED)
		hair_coils.append(coil)
		hair[coil.pid] = [0, false, Talents.HAIR_M]
		if kit != null:
			kit.add_coil(coil, self, Talents.HAIR_CORD_COLOR)


# ---- 押した人の側 ----

# K を押した。手ぶらで物を見ていれば、その物も伝える。alt（Shift+K）は、頭の道具箱から出す
func act_use(alt: bool = false) -> void:
	var me: Node = game.local_player()
	if me == null:
		return
	# ショールは、物を持ったままでも、見ている物にかけられる
	var target: int = me.target.pid if me.target != null and (me.held == 0 or cast_of(me.peer_id) == SHAWL) else 0
	h_use.rpc_id(1, target, alt)


# 仲間の頭を見て F を押した。取り出せる相手がいなければ false（F のほかの使い道に回す）
func act_take() -> bool:
	var who: int = crew_aimed(game.local_player())
	if who == 0:
		return false
	h_take.rpc_id(1, who)
	return true


# 自分が見ている、中身の入った段ボール頭の仲間（いなければ 0）。視線が、体から頭のてっぺんまでのそばを通るかで決める
func crew_aimed(me: Node) -> int:
	if me == null or me.cam == null or me.held != 0 or me.operating != 0 or not usable():
		return 0
	var from: Vector3 = me.cam.global_position
	var dir: Vector3 = -me.cam.global_basis.z
	var best := 0
	var best_far := INF
	# カメラは自分の後ろにあるので、自分より先にいる相手だけ（後ろに立っている仲間を、見ていることにしない）
	var own_far: float = (me.global_position + Vector3(0, 1.0, 0) - from).dot(dir)
	for who: int in stowed:
		var pl: Node = game.players.get(who)
		if who == me.peer_id or pl == null or (stowed[who] as Array).is_empty() or cast_of(who) != BOX_HEAD:
			continue
		if pl.global_position.distance_to(me.global_position) > me.REACH:
			continue
		var near: PackedVector3Array = Geometry3D.get_closest_points_between_segments(from, from + dir * 9.0, pl.global_position + Vector3(0, 0.3, 0), head_top(pl))
		var far: float = (near[0] - from).dot(dir)
		if near[0].distance_to(near[1]) <= 0.55 and far < best_far and far > own_far + 0.3:
			best = who
			best_far = far
	if best == 0:
		return 0
	# 手前に壁や物があれば、そちらを見ている
	var ray := PhysicsRayQueryParameters3D.create(from, from + dir * best_far, 1 | 2 | 4)
	var hit: Dictionary = me.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and from.distance_to(hit.position) < best_far - 0.5:
		return 0
	return best


# 画面に出す文。keys＝操作の案内の先頭に足す / label＝狙った物（持っている物）の名前の横に足す /
# target＝狙った相手の名前（仲間の頭を見ているとき）
func hint(me: Node) -> Dictionary:
	var out := {"keys": "", "label": "", "target": ""}
	if me == null or not usable():
		return out
	var who: int = me.peer_id
	var tag := cast_of(who)
	if tag == ROBOT:
		out["keys"] = "K おなかランプを消す" if lamp_on(who) else "K おなかランプを点ける"
	elif tag == NOTEBOOK:
		out["keys"] = "K 手帳を閉じる" if note_open(who) else "K 手帳で台本を読む"
	elif tag == BOX_HEAD and me.operating == 0:
		var list: Array = stowed_of(who)
		var subject: Node = game.props.get(me.held) if me.held != 0 else me.target
		if subject != null and stow_refusal(who, subject) == "":
			out["keys"] = "K 頭にしまう（%d / %d）" % [list.size(), Talents.STOW_SLOTS]
			out["label"] = "　K：頭にしまう"
		elif not list.is_empty() and game.props.has(list.back()):
			out["keys"] = ("K 頭から出す（%s）" if me.held == 0 else "Shift+K 頭から出す（%s）") % short_name(game.props[list.back()])
	# ここから下の4人は、動作だけを書く（残りの枚数・秒・長さは書かない。キャラの見た目で分かる）
	elif tag == SHAWL and me.operating == 0:
		var seen: Node = me.target
		if seen != null and shawls.has(seen.pid):
			out["keys"] = "K ショールを外す"
			out["label"] = "　K：ショールを外す"
		elif seen != null and shawl_refusal(who, seen) == "":
			out["keys"] = "K ショールをかける"
			out["label"] = "　K：ショールをかける"
	elif tag == HALT:
		out["keys"] = "K 止まれ！"
	elif tag == HAIR and me.operating == 0:
		out["keys"] = "K 毛ひもをしまう" if hair_out(who) else "K 毛ひもを出す"
	elif tag == NECK and me.operating == 0:
		out["keys"] = "K 首を戻す" if neck_out(who) else "K 首を伸ばす"
	var owner: int = crew_aimed(me)
	if owner != 0:
		var names: Array = []
		for pid: int in stowed_of(owner):
			if game.props.has(pid):
				names.append(short_name(game.props[pid]))
		if not names.is_empty():
			out["target"] = "%s の頭の道具箱（%s）" % [crew_name(owner), "・".join(names)]
			out["keys"] = "F 頭から取り出す（%s）" % names.back()
	return out


# 自分の頭の中身（画面の左下の枠に出す）。[{kind, label}, ...]。段ボール頭でなければ空
func slots(me: Node) -> Array:
	var out: Array = []
	if me == null:
		return out
	for pid: int in stowed_of(me.peer_id):
		var prop: Node = game.props.get(pid)
		if prop != null:
			out.append({"kind": prop.kind, "label": short_name(prop)})
	return out


# ---- ホスト：K ----

@rpc("any_peer", "call_local", "reliable")
func h_use(target: int = 0, alt: bool = false) -> void:
	if multiplayer.is_server():
		host_use(_sender(), target, alt)


@rpc("any_peer", "call_local", "reliable")
func h_take(owner: int) -> void:
	if multiplayer.is_server():
		host_take(_sender(), owner)


# その人が特技を使う。target＝手ぶらで見ている物のID（無ければ 0）
func host_use(who: int, target: int = 0, alt: bool = false) -> void:
	var pl: Node = game.players.get(who)
	if pl == null or not usable():
		return
	var tag := cast_of(who)
	if not Talents.ready(tag):
		if Talents.has(tag):
			_tell(who, "%s の特技「%s」は準備中" % [crew_name(who), Talents.title(tag)], false)
		return
	match tag:
		ROBOT:
			host_lamp(who, not lamp_on(who))
		NOTEBOOK:
			host_note(who, not note_open(who))
		BOX_HEAD:
			_use_box_head(who, pl, target, alt)
		SHAWL:
			_use_shawl(who, pl, target)
		HALT:
			host_halt(who)
		HAIR:
			_use_hair(who, pl)
		NECK:
			host_neck(who, not neck_out(who))


func host_lamp(who: int, on: bool) -> void:
	if on == lamp_on(who):
		return
	var pl: Node = game.players.get(who)
	game.host_ev("lamp", [who, on])
	game.host_ev("sfx", ["ui_select" if on else "ui_back", lamp_origin(pl) if pl != null else null])


# ---- ホスト：ドレスの人「ショールをかける」 ----

# 見ている物にショールをかける。かかっている物なら外す（肩に戻る。かけた人の肩へ）
func _use_shawl(who: int, pl: Node, target: int) -> void:
	var prop: Node = game.props.get(target)
	if prop == null or prop.absent or pl.global_position.distance_to(prop.center_global()) > pl.REACH + Talents.SHAWL_REACH:
		_tell(who, "物を見て K で、ショールをかける", false)
		return
	if shawls.has(prop.pid):
		host_shawl_off(prop.pid)
		game.host_ev("sfx", ["pickup", prop.center_global()])
		return
	var why := shawl_refusal(who, prop)
	if why != "":
		_tell(who, "%s：%s" % [short_name(prop), why], true)
		return
	game.host_ev("shawl", [prop.pid, who, 0.0, Vector2.ZERO, 0, null])
	game.host_ev("sfx", ["drop", prop.center_global()])


# ショールを外す（肩に戻る）
func host_shawl_off(pid: int) -> void:
	if shawls.has(pid):
		game.host_ev("shawl", [pid, 0, 0.0, Vector2.ZERO, 0, null])


# 布をずらす（風・爆風）。push＝物から見た向き×強さ。1.0 までずれたら飛ぶ：
# 風下の近くに、見立てできる物があれば、そこへ引っかかる。無ければ、どこかへ飛んで無くなる（次の依頼で戻る）
func host_shawl_push(pid: int, push: Vector3) -> void:
	var prop: Node3D = game.props.get(pid)
	if prop == null or not shawls.has(pid) or push.length() < 0.01:
		return
	var row: Array = shawls[pid]
	var local: Vector3 = prop.global_basis.inverse() * push
	var dir := Vector2(local.x, local.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector2(1, 0)
	var slip: float = float(row[1]) + push.length()
	if slip < 1.0:
		game.host_ev("shawl", [pid, int(row[0]), slip, dir, 0, null])
		return
	var owner: int = int(row[0])
	var away: Vector3 = Vector3(push.x, 0.0, push.z).normalized()
	var landing: Node3D = null
	var best := 5.0
	for other: Node3D in game.props.values():
		if other == prop or shawls.has(other.pid) or other.absent or other.holder != 0 or not Roles.castable(other.kind):
			continue
		var to: Vector3 = other.center_global() - prop.center_global()
		to.y = 0.0
		if to.length() < best and to.length() > 0.2 and to.normalized().dot(away) > 0.35:
			best = to.length()
			landing = other
	if landing != null:
		# 飛んで、となりの物に引っかかった
		game.host_ev("shawl", [pid, 0, 0.0, Vector2.ZERO, 0, landing.center_global() + Vector3(0, landing.half.y, 0)])
		game.host_ev("shawl", [landing.pid, owner, rng.randf_range(0.1, 0.45), dir, 0, null])
	else:
		game.host_ev("shawl", [pid, 0, 0.0, Vector2.ZERO, owner, prop.center_global() + away * 9.0 + Vector3(0, 4.0, 0)])
	game.host_ev("sfx", ["wind", prop.center_global()])


# 爆発が起きた（production_main.gd から。全員の画面で呼ばれるが、決めるのはホストだけ）：近くの布がずれる・飛ぶ
func on_burst(pos: Vector3, power: float) -> void:
	if not multiplayer.is_server() or game.replaying or power <= 0.0:
		return
	for pid: int in shawls.keys():
		var prop: Node3D = game.props.get(pid)
		if prop == null:
			continue
		var to: Vector3 = prop.center_global() - pos
		if to.length() >= Talents.SHAWL_BLAST:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		flat = flat.normalized() if flat.length() > 0.05 else Vector3(1, 0, 0)
		host_shawl_push(pid, flat * (1.0 - to.length() / Talents.SHAWL_BLAST) * rng.randf_range(0.7, 1.7))


# ---- ホスト：カエルの警官「止まれ！」 ----

# 前方の扇形にある、固定していない物を止める。止まっている間は、速さを消して、重力も切る（終わったら戻す）
func host_halt(who: int) -> void:
	var pl: Node = game.players.get(who)
	if pl == null:
		return
	if float(halt_wait.get(who, 0.0)) > 0.0:
		# まだ使えない（背中の札が、起き上がりきっていない）
		game.ev.rpc_id(who, "sfx", ["ui_fail", null])
		return
	var from: Vector3 = pl.global_position + Vector3(0, 1.0, 0)
	var facing: Vector3 = pl.flat_forward()
	var hit: Array = []
	for prop: RigidBody3D in game.props.values():
		if not halt_ok(prop) or not Talents.in_halt_fan(from, facing, prop.center_global()):
			continue
		hit.append(prop.pid)
		_halted[prop.pid] = Talents.HALT_TIME
		_hold_still(prop)
	# 近い順に並べる（「ぴたっ」の札は、近い物から出す）
	hit.sort_custom(func(a: int, b: int) -> bool:
		return game.props[a].center_global().distance_squared_to(from) < game.props[b].center_global().distance_squared_to(from))
	game.host_ev("halt", [who, hit])
	game.host_ev("sfx", ["cue", from])
	if not hit.is_empty():
		game.host_ev("sfx", ["fix", from + facing * 2.0])


func _hold_still(prop: RigidBody3D) -> void:
	prop.sleeping = false
	prop.linear_velocity = Vector3.ZERO
	prop.angular_velocity = Vector3.ZERO
	prop.gravity_scale = 0.0


# 止めるのをやめる。重力を元に戻す（誰かが持っているなら、持つ仕組みに任せる）
func _let_move(pid: int) -> void:
	_halted.erase(pid)
	var prop: RigidBody3D = game.props.get(pid)
	if prop != null and prop.holder == 0:
		prop.gravity_scale = 1.0
		prop.sleeping = false


func _halt_tick(delta: float) -> void:
	for pid: int in _halted.keys():
		var prop: RigidBody3D = game.props.get(pid)
		_halted[pid] = float(_halted[pid]) - delta
		# 誰かが掴めば解ける。固定された・しまわれた物も、止めるのをやめる
		if prop == null or float(_halted[pid]) <= 0.0 or prop.holder != 0 or prop.fixed or prop.absent:
			_let_move(pid)
		else:
			_hold_still(prop)


# ---- ホスト：モップの王様「毛ひも」 ----

# 毛の束を手に出す・しまう
func _use_hair(who: int, pl: Node) -> void:
	var coil := hair_coil_of(who)
	if coil != null and bool(hair[coil.pid][1]):
		host_hair_away(coil)
		game.host_ev("sfx", ["ui_back", pl.global_position])
		return
	if pl.operating != 0 or game._held_by(who) != null:
		_tell(who, "手が空いていないと、毛ひもを出せない", true)
		return
	if coil == null:
		# まだ誰の物でもない束を、自分の束にする
		for spare: RigidBody3D in hair_coils:
			if int(hair[spare.pid][0]) == 0 and (coil == null or float(hair[spare.pid][2]) > float(hair[coil.pid][2])):
				coil = spare
	if coil == null:
		return
	if float(hair[coil.pid][2]) < 0.3:
		_tell(who, "もう、ひもにできる毛が無い（掛けた毛ひもを F でほどくと、頭に戻る）", true)
		return
	game.host_ev("hair", [coil.pid, who, true, float(hair[coil.pid][2])])
	# 頭のてっぺんから出て、手に収まる
	var facing := Basis(Vector3.UP, pl.aim_yaw)
	var state: Array = coil.get_state()
	state[0] = head_top(pl) + Vector3(0, 0.1, 0)
	state[1] = Quaternion(facing)
	state[2] = false
	coil.restore(state)
	_hand_over(who, coil)


# 毛の束をしまう。結びかけ（片方だけフックに結んだ）のひもは、巻き戻す
func host_hair_away(coil: RigidBody3D) -> void:
	var kit: Variant = game.get("cargo_kit")
	if kit != null:
		var open: Dictionary = kit.open_lash(coil.pid)
		if not open.is_empty():
			kit._undo(int(open["id"]))
	if coil.holder != 0:
		game.host_release(coil)
	game.host_ev("hair", [coil.pid, int(hair[coil.pid][0]), false, float(hair[coil.pid][2])])


func _hair_tick(delta: float) -> void:
	for coil: RigidBody3D in hair_coils:
		var row: Array = hair[coil.pid]
		var owner: int = int(row[0])
		if owner == 0:
			continue
		var gone: bool = not game.players.has(owner)
		# 手から離した・キャラを替えた・抜けた：束は、しまわれる
		if bool(row[1]) and (gone or coil.holder != owner or cast_of(owner) != HAIR):
			host_hair_away(coil)
		if gone:
			# 抜けた人の束は、ほかの人が使えるようにする（使った長さは、そのまま）
			game.host_ev("hair", [coil.pid, 0, false, float(row[2])])
	_hair_send -= delta
	if _hair_dirty and _hair_send <= 0.0:
		_hair_dirty = false
		_hair_send = 0.2
		for coil: RigidBody3D in hair_coils:
			var row: Array = hair[coil.pid]
			if int(row[0]) != 0:
				game.host_ev("hair", [coil.pid, int(row[0]), bool(row[1]), float(row[2])])


# ---- ホスト：ベレー帽の人「びよーん首」 ----

func host_neck(who: int, on: bool) -> void:
	if on == neck_out(who):
		return
	var pl: Node = game.players.get(who)
	if on and pl != null and (pl.operating != 0 or pl.vehicle_riding()):
		_tell(who, "いまは、首を伸ばせない", true)
		return
	game.host_ev("neck", [who, on])
	game.host_ev("sfx", ["ui_select" if on else "ui_back", pl.global_position if pl != null else null])


# 手帳の人：台本の写しを開く・閉じる。台本そのものは1冊のまま（持っている人は、今までどおり F で読む）
func host_note(who: int, on: bool) -> void:
	if on == note_open(who):
		return
	game.ev.rpc("note", [who, on])
	game.ev.rpc_id(who, "sfx", ["ui_open" if on else "ui_back", null])


# 段ボール頭：持っている（見ている）小物をしまう。しまう物が無ければ、最後に入れた物を出す
func _use_box_head(who: int, pl: Node, target: int, alt: bool) -> void:
	if alt:
		if not host_draw(who, who):
			_tell(who, "頭の道具箱は空っぽ", true)
		return
	var held: Node = game._held_by(who)
	var subject: Node = held
	if subject == null and target != 0:
		subject = game.props.get(target)
		if subject != null and pl.global_position.distance_to(subject.center_global()) > pl.REACH + 1.0:
			subject = null
	if subject != null:
		var why := stow_refusal(who, subject)
		if why == "":
			host_stow(who, subject)
			return
		# 持っている物が入らない・出す物も無いときは、理由を伝える（手で持つのは今までどおり）
		if held != null or stowed_of(who).is_empty():
			_tell(who, "%s：%s" % [short_name(subject), why], true)
			return
	if not host_draw(who, who):
		_tell(who, "頭の道具箱は空っぽ。小物を持って（見て）K でしまえる", false)


# 頭の道具箱へしまう。持っていれば手から離し、荷台や台車からも降ろす
func host_stow(who: int, prop: Node) -> void:
	var from_hand: bool = prop.holder != 0
	if from_hand:
		game.host_release(prop)
	if prop.rider_of != 0:
		game.host_unload(prop)
	game.host_ev("stow", [who, prop.pid, true])
	if not from_hand:
		var pl: Node = game.players.get(who)
		game.host_ev("sfx", ["load", head_top(pl) if pl != null else null])
	_tell(who, "%s を頭にしまった（%d / %d）" % [short_name(prop), stowed_of(who).size(), Talents.STOW_SLOTS], false)


# 頭の道具箱から、最後に入れた物を出す。taker の手が空いていれば手に持たせ、ふさがっていれば足元へ転がす
func host_draw(owner: int, taker: int) -> bool:
	var pl: Node = game.players.get(owner)
	var list: Array = stowed_of(owner)
	if pl == null or list.is_empty():
		return false
	var pid: int = list.back()
	var prop: Node = game.props.get(pid)
	var hands: Node = game.players.get(taker)
	var mine: bool = prop != null and prop.stored_in == -owner
	game.host_ev("stow", [owner, pid, false])
	if not mine:
		return true          # ほかの仕組み（箱など）に移っていた物。中身から外すだけ
	var free: bool = hands != null and hands.operating == 0 and game._held_by(taker) == null
	# 頭のてっぺんから「ぽん」と出る
	var facing := Basis(Vector3.UP, pl.aim_yaw)
	var state: Array = prop.get_state()
	state[0] = head_top(pl) + Vector3(0, prop.half.y + 0.08, 0) - facing * prop.center
	state[1] = Quaternion(facing)
	state[2] = false
	prop.restore(state)
	if free:
		_hand_over(taker, prop)
	else:
		# 手がふさがっている：受け取る人のほうへ、小さく跳ねて落ちる
		var toward: Vector3 = pl.flat_forward()
		if hands != null and taker != owner:
			toward = hands.global_position - pl.global_position
			toward.y = 0.0
			toward = toward.normalized() if toward.length() > 0.05 else pl.flat_forward()
		prop._launch = [toward * 1.7 + Vector3(0, 2.4, 0), Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2))]
		prop.sleeping = false
		game.host_ev("sfx", ["pickup", prop.global_position])
	var label := short_name(prop)
	if taker == owner:
		_tell(owner, "%s を出した（頭の中 %d / %d）%s" % [label, stowed_of(owner).size(), Talents.STOW_SLOTS, "" if free else "。手がふさがっているので足元へ"], false)
	else:
		_tell(taker, "%s の頭から %s を取り出した" % [crew_name(owner), label], false)
		_tell(owner, "%s に %s を取り出された！" % [crew_name(taker), label], false)
	return true


# 仲間が、段ボール頭の頭から1つ取り出す（そばで頭を見て F）
func host_take(taker: int, owner: int) -> void:
	var me: Node = game.players.get(taker)
	var them: Node = game.players.get(owner)
	if me == null or them == null or taker == owner or not usable() or stowed_of(owner).is_empty():
		return
	if me.global_position.distance_to(them.global_position) > me.REACH + 0.8:
		_tell(taker, "遠すぎる。そばで頭を見て F", true)
		return
	host_draw(owner, taker)


# 出した物を、その人の手に持たせる。頭の上から手元へ寄ってくる（G で引き寄せたときと同じ持ち方）
func _hand_over(who: int, prop: Node) -> void:
	var pl: Node = game.players.get(who)
	prop.set_holder(who)
	prop.grab_time = Time.get_ticks_msec() / 1000.0
	game._reset_hold_controls(pl)
	pl.hold_revision += 1
	var carry: Array = game._carry_target(pl, prop)
	var basis := Basis.from_euler(Vector3(carry[3], carry[1], 0.0))
	var goal := Transform3D(basis, (carry[0] as Vector3) - basis * prop.center)
	goal.origin.y = maxf(goal.origin.y, pl.global_position.y + 0.03)
	prop.hold_transform = goal
	prop.hold_view_transform = game.hold_view_anchor(pl)
	prop.hold_player_position = pl.global_position
	game.host_ev("hold", [who, prop.pid, game._hold_snapshot(pl, prop)])
	game.host_ev("sfx", ["pickup", prop.global_position])


func _tell(who: int, text: String, bad: bool) -> void:
	if not game.players.has(who):
		return
	game.ev.rpc_id(who, "toast", [text, 1 if bad else 0])
	if bad:
		game.ev.rpc_id(who, "sfx", ["ui_fail", null])


# ---- ホスト：中身をこぼす・戻す ----

# その人の中身を、ぜんぶ外へ出す。at を渡さなければ、その人の足元。出した数を返す（全員への知らせは呼ぶ側が _broadcast で）
func host_spill(who: int, at: Variant = null) -> int:
	var list: Array = (stowed.get(who, []) as Array).duplicate()
	stowed.erase(who)
	_last_at.erase(who)
	var pl: Node = game.players.get(who)
	var origin: Vector3 = at if at is Vector3 else (pl.global_position if pl != null else game._recovery_point())
	var count := 0
	for pid: int in list:
		var prop: Node = game.props.get(pid)
		if prop == null or prop.stored_in != -who:
			continue
		prop.set_stored(0)
		var turn: float = TAU * float(count) / float(maxi(list.size(), 1)) + 0.6
		var state: Array = prop.get_state()
		state[0] = origin + Vector3(cos(turn) * 0.75, 0.5 + prop.half.y, sin(turn) * 0.75) - prop.global_basis * prop.center
		state[2] = false
		prop.restore(state)
		prop.sleeping = false
		count += 1
	return count


# 全員の中身を外へ出す（次の依頼を受けるとき・事務所へ戻るとき）。置き場所を戻す処理より先に呼ぶ
func host_clear_all() -> void:
	for who: int in stowed.keys():
		host_spill(who)
	lamps = {}
	notes = {}
	_layout = {}
	# ショールは肩へ、首は元へ、毛は頭へ戻る。止めていた物は動き出す
	shawls = {}
	shawl_lost = {}
	necks = {}
	halt_wait = {}
	for pid: int in _halted.keys():
		_let_move(pid)
	var kit: Variant = game.get("cargo_kit")
	for coil: RigidBody3D in hair_coils:
		if bool(hair[coil.pid][1]):
			host_hair_away(coil)
		# 荷台に掛けたままの毛ひもの分は、戻らない（ほどけば戻る）
		var left: float = Talents.HAIR_M
		if kit != null:
			for lash: Dictionary in kit.lashes.values():
				if int(lash.get("coil", 0)) == coil.pid:
					left -= float(lash["cord"].length)
		hair[coil.pid] = [0, false, maxf(left, 0.0)]
	_broadcast()


func _broadcast() -> void:
	game.ev.rpc("talent_sync", [snapshot()])


# あとから入った人へ、いまの状態を送る
func sync_to(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "talent_sync", [snapshot()])


func _physics_process(delta: float) -> void:
	# 「止まれ！」の待ち時間は、全員の画面で進める（背中の札の起き上がり）
	for wait: Dictionary in [halt_wait, _halt_view]:
		for who: int in wait.keys():
			wait[who] = float(wait[who]) - delta
			if float(wait[who]) <= 0.0:
				wait.erase(who)
	if not multiplayer.is_server() or game.replaying:
		return
	_halt_tick(delta)
	_hair_tick(delta)
	_shawl_tick()
	var changed := false
	for who: int in necks.keys():
		var tall: Node = game.players.get(who)
		# キャラを替えた・抜けた・撮影カメラを操作し始めた・車に乗った：首は元に戻る
		if tall == null or cast_of(who) != NECK or tall.operating != 0 or tall.vehicle_riding():
			necks.erase(who)
			changed = true
	for who: int in stowed.keys():
		var pl: Node = game.players.get(who)
		if pl == null:
			# 抜けた人の中身は、最後にいた場所にこぼれる
			host_spill(who, _last_at.get(who))
			changed = true
		elif cast_of(who) != BOX_HEAD:
			# キャラを替えたら、中身は足元にこぼれる
			if host_spill(who) > 0:
				_tell(who, "頭の道具箱の中身が、足元にこぼれた", false)
			changed = true
		else:
			_last_at[who] = pl.global_position
			changed = _prune(who) or changed
	for who: int in lamps.keys():
		if not game.players.has(who) or cast_of(who) != ROBOT:
			lamps.erase(who)
			changed = true
	for who: int in notes.keys():
		if not game.players.has(who) or cast_of(who) != NOTEBOOK:
			notes.erase(who)
			changed = true
	if changed:
		_broadcast()


# ショール：現場から無くなった物の布は、肩に戻る。風が吹き始めたら、布がずれる
func _shawl_tick() -> void:
	for pid: int in shawls.keys():
		var prop: Node = game.props.get(pid)
		if prop == null or prop.absent or prop.stored_in != 0:
			host_shawl_off(pid)
	var flow: Node = game.production
	var blowing: bool = flow != null and float(flow.get("_gust_left")) > 0.0
	if blowing and not _gusting:
		var wind: Vector3 = flow.get("_gust_dir")
		for pid: int in shawls.keys():
			host_shawl_push(pid, wind * rng.randf_range(Talents.SHAWL_GUST.x, Talents.SHAWL_GUST.y))
	_gusting = blowing


# ほかの仕組み（段ボール箱・撮り直し）に移された物を、中身の一覧から外す。外したら true
func _prune(who: int) -> bool:
	var kept: Array = []
	for pid: int in stowed_of(who):
		var prop: Node = game.props.get(pid)
		if prop != null and prop.stored_in == -who:
			kept.append(pid)
	if kept.size() == stowed_of(who).size():
		return false
	if kept.is_empty():
		stowed.erase(who)
	else:
		stowed[who] = kept
	return true


# 撮り直し：テイクを始める前の中身に戻す（本番中に出した物は頭へ、本番中にしまった物は元の置き場所へ）
func _restore_layout() -> void:
	var want: Dictionary = _layout.get("stowed", {})
	var keeper := {}          # 物のID → テイク前の持ち主
	for who: int in want:
		if game.players.has(who) and cast_of(who) == BOX_HEAD:
			for pid: int in want[who]:
				keeper[pid] = who
	for who: int in stowed.keys():
		for pid: int in (stowed[who] as Array).duplicate():
			var prop: Node = game.props.get(pid)
			if int(keeper.get(pid, 0)) == who or prop == null or prop.stored_in != -who:
				continue          # 残す物・ほかの仕組み（箱など）が持っていった物
			prop.set_stored(0)
			if game._layout.has(pid):
				prop.restore(game._layout[pid])
			if game._layout_riders.has(pid) and game.props.has(game._layout_riders[pid][0]):
				game._set_rider(prop, game.props[game._layout_riders[pid][0]], game._layout_riders[pid][1])
	var fresh := {}
	var lost := 0
	for who: int in want:
		for pid: int in want[who]:
			var prop: Node = game.props.get(pid)
			if prop == null or (prop.absent and prop.stored_in == 0) or prop.stored_in > 0:
				continue
			if int(keeper.get(pid, 0)) == who:
				if prop.stored_in != -who:
					prop.set_stored(-who)
				if not fresh.has(who):
					fresh[who] = []
				(fresh[who] as Array).append(pid)
			elif prop.global_position.y < -40.0:
				# 持ち主がいなくなった物は、搬入口のそばに出す
				var state: Array = prop.get_state()
				state[0] = game._recovery_point() + Vector3(0.6 * float(lost), 0.2 + prop.half.y, 1.6) - prop.global_basis * prop.center
				state[2] = false
				prop.restore(state)
				lost += 1
	stowed = fresh
	# ショールも、テイクを始める前のかけ方に戻す（本番中に飛んだ布も戻る）
	if _layout.has("shawls"):
		shawls = (_layout["shawls"] as Dictionary).duplicate(true)
		shawl_lost = (_layout.get("lost", {}) as Dictionary).duplicate()
	_broadcast()


# ---- 全員：合図を受ける ----

func on_event(n: String, a: Array) -> void:
	match n:
		"stow":
			_on_stow(int(a[0]), int(a[1]), bool(a[2]))
		"lamp":
			_on_lamp(int(a[0]), bool(a[1]))
		"note":
			_on_note(int(a[0]), bool(a[1]))
		"shawl":
			_on_shawl(int(a[0]), int(a[1]), float(a[2]), a[3], int(a[4]), a[5])
		"halt":
			_on_halt(int(a[0]), a[1])
		"neck":
			_on_neck(int(a[0]), bool(a[1]))
		"hair":
			_on_hair(int(a[0]), int(a[1]), bool(a[2]), float(a[3]))
		"talent_sync":
			_apply_sync(a[0])
		"talent_take":
			if game.replaying:
				_view = (a[0] as Dictionary).duplicate(true)


func _on_stow(who: int, pid: int, on: bool) -> void:
	if game.replaying:
		# 見返し：頭の上の見た目だけを録画どおりにする。物そのものは、録画の位置どおりに動く
		var seen: Dictionary = _view.get("stowed", {})
		var shown: Array = (seen.get(who, []) as Array).duplicate()
		shown.erase(pid)
		if on:
			shown.append(pid)
		seen[who] = shown
		_view["stowed"] = seen
		return
	var list: Array = (stowed.get(who, []) as Array).duplicate()
	list.erase(pid)
	if on:
		list.append(pid)
	if list.is_empty():
		stowed.erase(who)
	else:
		stowed[who] = list
	var prop: Node3D = game.props.get(pid)
	var pl: Node = game.players.get(who)
	if prop == null:
		return
	if on and pl != null:
		_fly_in(prop, pl)
		# しまう動き（動くと中断）。芝居の経験値には数えないので、演技の合図（perform）には乗せない
		pl.start_performance("stow")
	if on:
		prop.set_stored(-who)
	elif prop.stored_in == -who:
		prop.set_stored(0)


func _on_lamp(who: int, on: bool) -> void:
	if game.replaying:
		var seen: Array = (_view.get("lamps", []) as Array).duplicate()
		seen.erase(who)
		if on:
			seen.append(who)
		_view["lamps"] = seen
	elif on:
		lamps[who] = true
	else:
		lamps.erase(who)


func _on_note(who: int, on: bool) -> void:
	if game.replaying:
		return
	if not on:
		notes.erase(who)
		return
	notes[who] = true
	# 手帳にメモする動き（動くと中断）。芝居の経験値には数えないので、演技の合図（perform）には乗せない
	var pl: Node = game.players.get(who)
	if pl != null:
		pl.start_performance("memo")


# ショールがかかった・ずれた・外れた（who が 0 なら外れた）。lost_by＝飛んで無くした人、fly_to＝飛んでいく先
func _on_shawl(pid: int, who: int, slip: float, dir: Vector2, lost_by: int, fly_to: Variant) -> void:
	var rows: Dictionary = shawls
	var lost: Dictionary = shawl_lost
	if game.replaying:
		rows = (_view.get("shawls", {}) as Dictionary).duplicate(true)
		lost = (_view.get("lost", {}) as Dictionary).duplicate()
	var fresh: bool = who != 0 and not rows.has(pid)
	if who == 0:
		rows.erase(pid)
	else:
		rows[pid] = [who, slip, dir]
	if lost_by != 0:
		lost[lost_by] = int(lost.get(lost_by, 0)) + 1
	if game.replaying:
		_view["shawls"] = rows
		_view["lost"] = lost
	var prop: Node3D = game.props.get(pid)
	if fly_to is Vector3 and prop != null and prop.is_inside_tree():
		_fly_cloth(prop, fly_to, lost_by != 0)
	if fresh and slip == 0.0 and game.players.has(who):
		# かけるときの、おじぎ（動くと中断）。芝居の経験値には数えないので、演技の合図（perform）には乗せない
		game.players[who].start_performance("curtsy")


# 飛んでいく布（見た目だけ）。gone なら、遠くへ消える。そうでなければ、行き先の物の上へ落ちる
func _fly_cloth(prop: Node3D, to: Vector3, gone: bool) -> void:
	var ghost := Node3D.new()
	game.add_child(ghost)
	ghost.global_position = prop.center_global() + Vector3(0, prop.half.y, 0)
	var piece := Looks.cloth(Vector3.ZERO, Vector3(0.1, 0.02, 0.1), 0.4)
	ghost.add_child(piece)
	var from: Vector3 = ghost.global_position
	var time: float = 1.6 if gone else 0.7
	var fly := ghost.create_tween().set_parallel(true)
	fly.tween_method(func(t: float) -> void:
		ghost.global_position = from.lerp(to, t) + Vector3(0, sin(t * PI) * (1.2 if gone else 0.9), 0), 0.0, 1.0, time)
	fly.tween_property(ghost, "rotation", Vector3(2.4, 5.0, 1.3) if gone else Vector3(0, TAU, 0), time)
	if gone:
		fly.tween_property(ghost, "scale", Vector3.ONE * 0.3, time)
	fly.chain().tween_callback(ghost.queue_free)


# 「止まれ！」：頭の上の吹き出しと、止まった物の「ぴたっ」（どちらも制作班にだけ見える）。背中の札が倒れる
func _on_halt(who: int, pids: Array) -> void:
	if game.replaying:
		_halt_view[who] = Talents.HALT_WAIT
	else:
		halt_wait[who] = Talents.HALT_WAIT
	var pl: Node = game.players.get(who)
	if pl == null:
		return
	pl.start_performance("halt")
	Looks.pop_word(game, game.font, "止まれ！", head_top(pl) + Vector3(0, 0.55, 0), 56, Color(1.0, 0.36, 0.3), 1.5)
	for i in mini(pids.size(), 8):
		var prop: Node3D = game.props.get(pids[i])
		if prop != null and not prop.absent:
			Looks.pop_word(game, game.font, "ぴたっ", prop.center_global() + Vector3(0, prop.half.y + 0.28, 0), 30, Color(1.0, 0.95, 0.75), Talents.HALT_TIME)


func _on_neck(who: int, on: bool) -> void:
	if game.replaying:
		var seen: Array = (_view.get("necks", []) as Array).duplicate()
		seen.erase(who)
		if on:
			seen.append(who)
		_view["necks"] = seen
	elif on:
		necks[who] = true
	else:
		necks.erase(who)


# 毛の束：持ち主・手に出しているか・残りの長さ
func _on_hair(pid: int, who: int, out: bool, left: float) -> void:
	if game.replaying:
		# 見返し：頭の毛の量だけを録画どおりにする。束そのものは、録画の位置どおりに動く
		var seen: Dictionary = (_view.get("hair", {}) as Dictionary).duplicate(true)
		seen[pid] = [who, out, left]
		_view["hair"] = seen
		return
	if not hair.has(pid):
		return
	# 長さは、ホストが持っている値が正しい（巻き戻しと行き違いにならないよう、ホストは上書きしない）
	hair[pid] = [who, out, float(hair[pid][2]) if multiplayer.is_server() else left]
	_stow_coil(pid)


# 毛の束を、出している・しまっているに合わせる
func _stow_coil(pid: int) -> void:
	var coil: RigidBody3D = game.props.get(pid)
	if coil == null or not hair.has(pid):
		return
	var want: int = 0 if bool(hair[pid][1]) else HAIR_STORED
	if coil.stored_in != want:
		coil.set_stored(want)


# いまの状態をまとめて受け取る。しまってある物・出ている物を、届いた中身に合わせる
func _apply_sync(data: Dictionary) -> void:
	var keeper := {}
	var fresh := {}
	var listed: Dictionary = data.get("stowed", {})
	for who: int in listed:
		var list: Array = (listed[who] as Array).duplicate()
		if list.is_empty():
			continue
		fresh[who] = list
		for pid: int in list:
			keeper[pid] = who
	stowed = fresh
	for pid: int in game.props:
		var prop: Node = game.props[pid]
		if prop.stored_in > 0 or prop.kind == Talents.HAIR_KIND:
			continue          # 箱の中の物と、毛の束は、ここでは触らない
		var want: int = -int(keeper.get(pid, 0))
		if prop.stored_in != want:
			prop.set_stored(want)
	lamps = {}
	for who: int in data.get("lamps", []):
		lamps[who] = true
	notes = {}
	for who: int in data.get("notes", []):
		notes[who] = true
	shawls = (data.get("shawls", {}) as Dictionary).duplicate(true)
	shawl_lost = (data.get("lost", {}) as Dictionary).duplicate()
	necks = {}
	for who: int in data.get("necks", []):
		necks[who] = true
	if not multiplayer.is_server():
		halt_wait = (data.get("halts", {}) as Dictionary).duplicate()
	var rows: Dictionary = data.get("hair", {})
	for pid: int in rows:
		if hair.has(pid):
			hair[pid] = (rows[pid] as Array).duplicate()
			_stow_coil(pid)
	_show_stored()


# 借りるのをやめた物は、頭の中からも消える（返した物を、あとから出せないように）。"absent" の合図のあとに呼ぶ
func absent_changed(kinds: Array) -> void:
	for who: int in stowed.keys():
		var list: Array = (stowed[who] as Array).duplicate()
		for pid: int in (stowed[who] as Array):
			var prop: Node = game.props.get(pid)
			if prop == null or prop.kind in kinds:
				list.erase(pid)
				if prop != null:
					prop.stored_in = 0          # 現場に無い物のまま
		if list.is_empty():
			stowed.erase(who)
		else:
			stowed[who] = list


# game.state が変わった（全員の画面で呼ぶ）
func state_changed() -> void:
	var before := _state
	_state = game.state
	if game.replaying != _was_replaying:
		_was_replaying = game.replaying
		_view = {}
		_halt_view = {}
		if not game.replaying:
			# 見返しの間に、録画のときの箱の中身として扱われた物（段ボール箱の記録）を、頭の中へ戻す
			for who: int in stowed:
				for pid: int in stowed[who]:
					var prop: Node = game.props.get(pid)
					if prop != null and prop.stored_in == 0:
						prop.set_stored(-who)
		_show_stored()
	if not multiplayer.is_server():
		return
	var S: Dictionary = game.S
	if _state == S.COUNTDOWN and before == S.PREP:
		_layout = snapshot()              # テイクを始める前の中身（撮り直しで戻す）
	elif _state == S.TAKE and before != S.TAKE:
		# 録画の先頭に、いまの状態を入れておく（見返しの最初に、頭の中身とランプを合わせる）
		game._rec_events.append([0.0, "talent_take", [snapshot()]])
	elif _state == S.PREP and before == S.RESULT:
		_restore_layout()


# 見返し中は、しまってある物も見えるようにしておく（録画のときは外にあったかもしれない。位置は録画どおりに動く）。
# 見返しが終わったら、また消して待機場所へ戻す
func _show_stored() -> void:
	for prop: Node3D in game.props.values():
		if prop.stored_in < 0:
			prop.set_absent(not game.replaying)
			if not game.replaying and multiplayer.is_server():
				prop.set_stored(prop.stored_in)


# ---- 全員：見た目 ----

func _process(delta: float) -> void:
	for who: int in game.players:
		var pl: Node = game.players[who]
		var vis: Node3D = pl.vis
		if vis == null or not is_instance_valid(vis) or vis.skel == null:
			continue
		_show_neck(pl, vis, vis.tag == NECK and shown_neck(who), delta)
		if vis.tag == BOX_HEAD:
			_show_stowed(vis, shown_stowed(who))
		elif vis.tag == ROBOT:
			_show_lamp(vis, shown_lamp(who))
		elif vis.tag == SHAWL and Talents.ready(SHAWL):
			# 肩に残っている枚数（数字では出さない）
			Looks.show_shoulders(vis, shown_shawls_left(who))
		elif vis.tag == HALT and Talents.ready(HALT):
			# 背中の赤い札：使える間は立っている。使うと倒れて、ゆっくり起き上がる
			Looks.show_paddle(vis, halt_ready(who))
		elif vis.tag == HAIR and Talents.ready(HAIR):
			# 頭の房：毛の残りの長さだけ生えている
			Looks.show_tufts(vis, Talents.hair_tufts(shown_hair_left(who)))
	_show_shawls()


# 首を伸ばす・戻す：視点と手の高さ（player.gd の neck）と、頭の骨の持ち上げ
func _show_neck(pl: Node, vis: Node3D, on: bool, delta: float) -> void:
	var goal: float = Talents.NECK_RISE if on else 0.0
	if not is_equal_approx(pl.neck, goal):
		pl.set_neck(move_toward(pl.neck, goal, delta * Talents.NECK_SPEED))
	var lift: SkeletonModifier3D = vis.skel.get_node_or_null("TalentNeck")
	if lift == null:
		if pl.neck <= 0.0 or vis.tag != NECK:
			return
		lift = NeckStretch.new()
		lift.name = "TalentNeck"
		lift.bone = vis.skel.find_bone("HEAD")
		vis.skel.add_child(lift)
	lift.rise = pl.neck / vis.SCALE


# 物にかぶせたショール（全員の画面と、撮影カメラに映る。当たり判定は無い）。かかり方が変わったときだけ作り直す
func _show_shawls() -> void:
	var rows: Dictionary = shown_shawls()
	for pid: int in rows:
		var prop: Node3D = game.props.get(pid)
		if prop == null:
			continue
		var row: Array = rows[pid]
		var shape := [snappedf(float(row[1]), 0.02), row[2]]
		if _shawl_nodes.has(pid) and (_shawl_nodes[pid] as Array)[1] == shape:
			continue
		_drop_shawl(pid)
		var piece := Looks.prop_shawl(prop.center, prop.half, float(row[1]), row[2])
		prop.add_child(piece)
		_shawl_nodes[pid] = [piece, shape]
	for pid: int in _shawl_nodes.keys():
		if not rows.has(pid):
			_drop_shawl(pid)


func _drop_shawl(pid: int) -> void:
	if not _shawl_nodes.has(pid):
		return
	var piece: Node = (_shawl_nodes[pid] as Array)[0]
	_shawl_nodes.erase(pid)
	if is_instance_valid(piece):
		if piece.get_parent() != null:
			piece.get_parent().remove_child(piece)
		piece.queue_free()


# 頭のてっぺんに、しまった物の縮めた見た目を並べる（中身が変わったときだけ作り直す）
func _show_stowed(vis: Node3D, list: Array) -> void:
	if list == vis.get_meta("talent_stowed", []):
		return
	var before: Array = vis.get_meta("talent_stowed", [])
	vis.set_meta("talent_stowed", list.duplicate())
	var rack: BoneAttachment3D = vis.skel.get_node_or_null("TalentStow")
	if rack == null:
		rack = BoneAttachment3D.new()
		rack.name = "TalentStow"
		rack.bone_name = "HEAD"
		vis.skel.add_child(rack)
	for old in rack.get_children():
		rack.remove_child(old)
		old.queue_free()
	var rest: Transform3D = vis.skel.get_bone_global_rest(vis.skel.find_bone("HEAD"))
	var unit: float = 1.0 / vis.SCALE          # キャラの素材は縮めて使っているので、その分を戻す
	for i in mini(list.size(), SLOT_AT.size()):
		var prop: Node3D = game.props.get(list[i])
		if prop == null or prop.visual == null:
			continue
		var longest: float = maxf(prop.half.x, maxf(prop.half.y, prop.half.z)) * 2.0
		var rate: float = Talents.stow_show_size(prop.half) / maxf(longest, 0.01)
		var tall: float = prop.half.y * 2.0 * rate
		# 下の3分の1くらいを頭に沈めて、顔を出しているように見せる
		var at: Vector3 = SLOT_AT[i] + Vector3(0, _head_top_y(vis) + (tall * 0.5 - minf(tall * 0.3, 0.11)) * unit, 0)
		var slot := Node3D.new()
		slot.transform = rest.affine_inverse() * Transform3D((Basis(Vector3.UP, SLOT_TURN[i]) * Basis(Vector3.BACK, SLOT_LEAN[i])).scaled(Vector3.ONE * unit), at)
		rack.add_child(slot)
		var shrink := Node3D.new()
		shrink.scale = Vector3.ONE * rate
		slot.add_child(shrink)
		var copy: Node3D = prop.visual.duplicate()
		copy.transform = Transform3D(prop.visual.transform.basis, prop.visual.transform.origin - prop.center)
		shrink.add_child(copy)
		if list[i] not in before:
			# 入れたばかりの物は、ぽこっと顔を出す
			shrink.scale = Vector3.ONE * rate * 0.05
			var pop := shrink.create_tween()
			pop.tween_interval(0.16)
			pop.tween_property(shrink, "scale", Vector3.ONE * rate, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# しまう物が、頭のてっぺんへ吸い込まれる（見た目だけ）
func _fly_in(prop: Node3D, pl: Node) -> void:
	if prop.visual == null or not prop.is_inside_tree():
		return
	var ghost := Node3D.new()
	game.add_child(ghost)
	ghost.global_transform = prop.global_transform
	ghost.add_child(prop.visual.duplicate())
	var goal: Vector3 = head_top(pl) - ghost.global_basis * prop.center * 0.3
	var fly := ghost.create_tween().set_parallel(true)
	fly.tween_property(ghost, "global_position", goal, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly.tween_property(ghost, "scale", Vector3.ONE * 0.3, 0.2)
	fly.chain().tween_callback(ghost.queue_free)


# ロボットのおなかの窓を光らせて、向いた先を照らす
func _show_lamp(vis: Node3D, on: bool) -> void:
	if on == bool(vis.get_meta("talent_lamp", false)):
		return
	vis.set_meta("talent_lamp", on)
	var light: SpotLight3D = vis.get_node_or_null("TalentLamp")
	if light == null and on:
		light = SpotLight3D.new()
		light.name = "TalentLamp"
		light.position = Talents.LAMP_AT
		light.rotation = Vector3(Talents.LAMP_TILT, PI, 0)      # 素材の正面は +Z。少し上向き
		light.spot_range = Talents.LAMP_RANGE + 1.5
		light.spot_angle = Talents.LAMP_ANGLE + 8.0      # 見た目は少し広げて、足元の先の床にも届かせる
		light.spot_angle_attenuation = 0.6
		light.spot_attenuation = 1.0
		light.light_color = Color(1.0, 0.86, 0.58)
		light.light_energy = 2.6
		light.shadow_enabled = true
		light.shadow_bias = 0.06
		vis.add_child(light)
		# 少し前の床に落ちる弱い光。後ろから見ている本人にも、点いていると分かる（光の向きは −Z）
		var glow_light := OmniLight3D.new()
		glow_light.name = "TalentGlow"
		glow_light.position = Vector3(0, -0.45, -0.7)
		glow_light.omni_range = 2.6
		glow_light.omni_attenuation = 1.4
		glow_light.light_color = Color(1.0, 0.84, 0.52)
		glow_light.light_energy = 1.4
		light.add_child(glow_light)
	if light != null:
		light.visible = on
	var glass := vis.find_child("castM02_game_glass", true, false) as MeshInstance3D
	if glass == null:
		return
	if not on:
		glass.material_override = null
		return
	var glow := StandardMaterial3D.new()
	var base := glass.get_active_material(0) as StandardMaterial3D
	if base != null:
		glow = base.duplicate() as StandardMaterial3D
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.82, 0.48)
	glow.emission_energy_multiplier = 3.0
	glass.material_override = glow


# ---- 登録（feature_hooks.gd）。決まった名前の関数を持っていると、中心の側が呼ぶ ----

func hook_events() -> Array:
	return EVENTS


func hook_event(n: String, a: Array) -> void:
	on_event(n, a)


# 見返しでも同じに見せる物（手帳の中身と、あとから入った人への知らせは、載せない）
func hook_rec_events() -> Array:
	return ["stow", "lamp", "shawl", "halt", "neck", "hair"]


func hook_core_event(n: String, a: Array) -> void:
	if n == "absent":
		absent_changed(a[0])
	elif n == "burst":
		on_burst(a[0], float(a[1]))      # 爆風で、ショールがずれる・飛ぶ
	elif n == "state":
		state_changed()


# K：キャラの特技。ロボットはランプ、段ボール頭は小物を頭にしまう・出す（Shift+K は出すだけ）、
# ドレスの人はショール、カエルの警官は「止まれ！」、モップの王様は毛ひも、ベレー帽の人は首
func hook_key(event: InputEvent, _me: Node) -> bool:
	if not event.is_action_pressed("talent") or game.production == null or game.production.phase not in [2, 4]:
		return false
	act_use(event.shift_pressed)
	return true


# 段ボール頭の仲間の頭を見て F：頭の道具箱から1つ取り出す
func hook_f(_me: Node) -> bool:
	return act_take()
