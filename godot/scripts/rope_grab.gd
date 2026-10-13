extends Node
## ロープを手でつかむ。手ぶらで、ロープの好きな所を見て左クリック（物を持つのと同じ操作）。
##   ・つかんだ所（節）が手について来る。ロープの残りは、ひもの計算（fuse_cord.gd）が引いて動かす。伸びない。
##     もう一度左クリックで離す。離すと、その場に落ちて止まる
##   ・対象：爆弾につないだロープ（導火線）・床の切れ端・束から出ている途中のロープ（bomb_kit.gd の cords）と、
##     荷台のフックに結んだロープ（cargo_kit.gd の lashes。たるんだ所・垂れた端）
##   ・両端がつながっているロープは、たるみの分だけ動く。張っていて手元まで来ないロープは、少しして手から抜ける
##   ・燃えている先のそばは、つかめない。つかんでいる所まで火が来たら、手を離す
##   ・どこにも結んでいない端をつかんで、爆弾を見て F＝口金につなぐ（その長さの導火線になる）／
##     フックを見て F＝結ぶ（切れ端が、フックから垂れたロープになる。もう片方の端も結べば、荷物に掛かる）
## 決めるのはホスト。送るのは「だれが・どのロープの・根元から何mの所をつかんでいるか」だけ（"ropegrab" の合図）。
## 手の場所は、その人のキャラの右手（位置・体の向き・構えは、もともと送っている）。全員の画面で、ほぼ同じ所になる。節の位置は送らない。
## 形のずれは、つかんでいる間ときどき・離したあとに、ホストの道すじ（間引き）で直す（bomb_kit.gd・cargo_kit.gd の全部の知らせ）
const Cord := preload("res://scripts/fuse_cord.gd")

const CREW_LAYER := 1 << 11                   # 制作班にだけ見える表示（film_camera.gd と同じ番号）
const CORD := 0                               # ロープの種類：爆弾の道具の線（導火線・切れ端）
const LASH := 1                               # ロープの種類：荷台のフックに結んだロープ
const AIM := 0.07                             # 狙い：視線からロープまでの離れ（掛けたロープをほどく狙いと同じ細さ）
const END_NEAR := 0.25                        # 端からこの長さまでをつかんだら、端をつかんだことにする
const HOT := 0.35                             # 燃えている先から、この長さまではつかめない
const PULL_IN := 7.0                          # つかんだ所が、手元へ寄ってくる速さ（m/秒）
const NEAR := 0.5                             # 手とつかんだ所が、これより離れたままだと、手から抜ける
const SLIP_SEC := 0.3                         # 手元まで来ていたロープが、張って離れてから抜けるまで
const STUCK_SEC := 1.2                        # 手元まで来ないロープ（張っている）を、あきらめるまで
const RESYNC_SEC := 1.5                       # つかんでいる間、形のずれを直す知らせの間隔

var game: Node
var grabs: Dictionary = {}                    # つかんでいる人 → {kind, id, s（根元からの道のり）, at（つかんだ所のいまの場所）, set, near, t}

var _marked: Array = []                       # 前のコマで、手を入れたロープ
var _mark: MeshInstance3D
var _resync := 0.0


func _ready() -> void:
	# ロープの計算（cargo_kit.gd＝20、bomb_kit.gd＝30）より先に、手の場所を入れる
	process_physics_priority = 10


func setup() -> void:
	_mark = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.05
	ring.outer_radius = 0.068
	ring.rings = 12
	ring.ring_segments = 6
	_mark.mesh = ring
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.6)
	mat.no_depth_test = true
	_mark.material_override = mat
	_mark.layers = CREW_LAYER
	_mark.visible = false
	add_child(_mark)


# ---- 調べる ----

func _bk() -> Node:
	return game.get("bomb_kit")


func _ck() -> Node:
	return game.get("cargo_kit")


func cord_of(kind: int, id: int) -> Node3D:
	if kind == CORD:
		var bk := _bk()
		return bk.cords.get(id) if bk != null else null
	var ck := _ck()
	if ck == null or not ck.lashes.has(id):
		return null
	return ck.lashes[id]["cord"]


# その人が、ロープをつかんでいるか（player.gd が、構えと体の向きに使う）
func holding(who: int) -> bool:
	return grabs.has(who)


# そのロープを、だれかがつかんでいるか
func held_cord(kind: int, id: int) -> bool:
	for g: Dictionary in grabs.values():
		if int(g["kind"]) == kind and int(g["id"]) == id:
			return true
	return false


# 手の場所：そのキャラの右手（片手で物を持つ構えの手。cast_visual.gd の grip_pos）。
# 体の向きと構えは、もともと全員の画面で合わせてあるので、どの画面でも、ほぼ同じ所になる
func hand_point(pl: Node3D) -> Vector3:
	var vis: Node3D = pl.get("vis")
	if vis != null and vis.get("skel") != null and vis.skel.find_bone("HAND.R") >= 0:
		return vis.grip_pos(true)
	# 手の骨が無いキャラ：胸の前、少し右
	var yaw: float = pl.aim_yaw
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	return pl.global_position + Vector3(0, 1.1 + float(pl.neck), 0) + right * 0.3 + pl.flat_forward() * 0.45


func _chest(pl: Node3D) -> Vector3:
	return pl.global_position + Vector3(0, 1.0 + float(pl.neck), 0)


# つかんだ所が、どの端か。1＝先 / 0＝根元 / -1＝端ではない（結んである端は、端に数えない）
func end_of(cord: Node3D, s: float) -> int:
	var free_a: bool = cord.a_body == null
	var free_b: bool = cord.b_body == null
	var da: float = s
	var db: float = float(cord.length) - s
	if free_b and db <= END_NEAR and (not free_a or db <= da):
		return 1
	if free_a and da <= END_NEAR:
		return 0
	return -1


# 先が束につながっていて、引けば束から出てくるか
func _feeds(kind: int, id: int, cord: Node3D) -> bool:
	if kind == CORD:
		var bk := _bk()
		return bk != null and cord.b_body == bk.coil and float(bk.stock) > 0.001
	var ck := _ck()
	if ck == null or not ck.lashes.has(id):
		return false
	var lash: Dictionary = ck.lashes[id]
	return int(lash["b"]) == ck.END_COIL and float(ck.stock(int(lash.get("coil", 0)))) > 0.001


func _ok() -> bool:
	var flow: Node = game.get("production")
	return Net.is_host() and flow != null and not game.replaying and game.state in [game.S.PREP, game.S.TAKE] and flow.phase in [0, 2, 4]


func _say(who: int, text: String, bad: bool) -> void:
	game.ev.rpc_id(who, "toast", [text, 1 if bad else 0])


# ---- ホスト：つかむ・離す・つなぐ・結ぶ ----

# 手ぶらで、ロープを見て左クリック：根元から s（m）の所をつかむ
@rpc("any_peer", "call_local", "reliable")
func h_grab(kind: int, id: int, s: float) -> void:
	if not _ok() or not is_finite(s):
		return
	var who := Net.sender()
	var pl: Node3D = game.players.get(who)
	if pl == null or grabs.has(who) or game._held_by(who) != null or pl.operating != 0:
		return
	var cord := cord_of(kind, id)
	if cord == null or not cord.visible:
		return
	s = clampf(s, 0.0, float(cord.length))
	if cord.burning and float(cord.length) - s < HOT:
		_say(who, "あつっ！ 火のそばは、つかめない", true)
		game.ev.rpc_id(who, "sfx", ["ui_fail", null])
		return
	var k: int = cord.node_at(s)
	if k < 0:
		return
	if (cord.pts[k] as Vector3).distance_to(_chest(pl)) > game.Player.REACH + 1.5:
		_say(who, "ロープに手が届かない", true)
		return
	s = cord.s_of(k)
	for other: Dictionary in grabs.values():
		if int(other["kind"]) == kind and int(other["id"]) == id and absf(float(other["s"]) - s) < 0.15:
			_say(who, "そこは、ほかの人がつかんでいる", false)
			return
	grabs[who] = {"kind": kind, "id": id, "s": s, "at": cord.pts[k], "set": true, "near": false, "t": 0.0}
	game.host_ev("sfx", ["pickup", cord.pts[k]])
	_broadcast()


@rpc("any_peer", "call_local", "reliable")
func h_release() -> void:
	if Net.is_host():
		host_release(Net.sender())


# その人の手から、ロープを離す（ホスト）。text＝その人に出す文
func host_release(who: int, text: String = "") -> void:
	if not Net.is_host() or not grabs.has(who):
		return
	grabs.erase(who)
	if text != "":
		_say(who, text, true)
	_resync = minf(_resync, 1.0) if _resync > 0.0 else 1.0
	_broadcast()


# 端をつかんで、爆弾を見て F（what＝"bomb"）／フックを見て F（what＝"hook"、index＝フックの番号）
@rpc("any_peer", "call_local", "reliable")
func h_use(what: String, index: int = -1) -> void:
	if not _ok():
		return
	var who := Net.sender()
	if not grabs.has(who):
		return
	var g: Dictionary = grabs[who]
	var kind: int = g["kind"]
	var id: int = g["id"]
	var cord := cord_of(kind, id)
	var bk := _bk()
	var ck := _ck()
	if cord == null or bk == null or ck == null:
		return
	var end := end_of(cord, float(g["s"]))
	if end < 0:
		_say(who, "ロープの端をつかんで、F", false)
		return
	if what == "bomb" and kind == CORD:
		# 口金につなぐ：その長さの導火線になる。先をつかんでいたなら、そちらが根元になる
		var whole: float = cord.length
		if bk.host_attach(id, end, who):
			grabs.erase(who)
			if end == 1:
				_mirror(kind, id, whole)
			_broadcast()
	elif what == "hook" and kind == CORD:
		# 切れ端をフックに結ぶ：フックから垂れたロープになる
		if cord.a_body != null or cord.b_body != null or cord.burning:
			_say(who, "どこにもつながっていない切れ端なら、フックに結べる", false)
			return
		var path: PackedVector3Array = cord.pts.duplicate()
		if end == 1:
			path.reverse()
		var whole: float = cord.length
		var made: int = ck.host_hang(path, whole, index, who)
		if made != 0:
			# ほかの人がつかんでいた所は、新しいロープの同じ所へ移す
			for other: int in grabs.keys():
				var o: Dictionary = grabs[other]
				if int(o["kind"]) != CORD or int(o["id"]) != id:
					continue
				if other == who:
					grabs.erase(other)
				else:
					o["kind"] = LASH
					o["id"] = made
					o["s"] = whole - float(o["s"]) if end == 1 else float(o["s"])
			bk.host_take(id)
			_broadcast()
	elif what == "hook" and kind == LASH:
		# フックから垂れたロープの端を、もう1つのフックに結ぶ
		if end != 1:
			return
		if ck.host_tie_end(id, index, who):
			for other: int in grabs.keys():
				if int(grabs[other]["kind"]) == LASH and int(grabs[other]["id"]) == id:
					grabs.erase(other)
			_broadcast()


# 先と根元が入れ替わった（ホスト。bomb_kit.gd：切れ端の根元の側に火が付いた・先の端を口金につないだ）
func host_flipped(kind: int, id: int) -> void:
	var cord := cord_of(kind, id)
	if cord != null and Net.is_host():
		if _mirror(kind, id, float(cord.length)):
			_broadcast()


func _mirror(kind: int, id: int, whole: float) -> bool:
	var changed := false
	for g: Dictionary in grabs.values():
		if int(g["kind"]) == kind and int(g["id"]) == id:
			g["s"] = clampf(whole - float(g["s"]), 0.0, whole)
			changed = true
	return changed


# はさみで切られた（ホスト。bomb_kit.gd・cargo_kit.gd）：根元から cut（m）の所。
#   near_ok＝根元の側が残ったか / far_kind・far_id＝先の側の、新しいロープ（残らなければ far_id＝0）/
#   far_flip＝先の側は、向きが逆になったか（向こうのフックから垂れる）/ whole＝切る前の長さ
# 切った所より先をつかんでいた人は、切れた先のロープを、そのままつかんでいる
func host_split(kind: int, id: int, cut: float, near_ok: bool, far_kind: int, far_id: int, far_flip: bool, whole: float) -> void:
	if not Net.is_host():
		return
	var changed := false
	for who: int in grabs.keys():
		var g: Dictionary = grabs[who]
		if int(g["kind"]) != kind or int(g["id"]) != id:
			continue
		changed = true
		var s: float = g["s"]
		if s <= cut:
			if not near_ok:
				grabs.erase(who)
		elif far_id == 0:
			grabs.erase(who)
		else:
			g["kind"] = far_kind
			g["id"] = far_id
			g["s"] = whole - s if far_flip else s - cut
	if changed:
		_broadcast()


# ---- 毎コマ（全員の画面）：つかんだ節を、手の場所へ ----

func _physics_process(delta: float) -> void:
	for cord: Variant in _marked:
		if is_instance_valid(cord):
			(cord as Node3D).hands = {}
	_marked = []
	if game == null or game.get("production") == null:
		return
	var host: bool = Net.is_host() and not game.replaying
	if host and not grabs.is_empty() and not _ok():
		# 出発した・カットがかかった：全員の手から離れる
		for who: int in grabs.keys():
			host_release(who)
	for who: int in grabs.keys():
		var g: Dictionary = grabs[who]
		var pl: Node3D = game.players.get(who)
		var cord := cord_of(int(g["kind"]), int(g["id"]))
		var k: int = cord.node_at(float(g["s"])) if cord != null else -1
		if host:
			if pl == null or cord == null or k < 0 or not cord.visible or game._held_by(who) != null or pl.operating != 0:
				host_release(who)
				continue
			if cord.burning and float(cord.length) - float(g["s"]) < HOT * 0.6:
				host_release(who, "あつっ！ 火が手元まで来た")
				game.ev.rpc_id(who, "sfx", ["ui_fail", null])
				continue
		if pl == null or cord == null or k < 0:
			continue
		var hand := hand_point(pl)
		if not bool(g["set"]):
			g["at"] = cord.pts[k]
			g["set"] = true
		var at: Vector3 = (g["at"] as Vector3).move_toward(hand, PULL_IN * delta)
		at = _limit(cord, who, g, k, at)
		g["at"] = at
		cord.hands[k] = at
		if not cord in _marked:
			_marked.append(cord)
		if host:
			# 張っていて手元まで来ない・手元から引き離された：手から抜ける
			if at.distance_to(hand) <= NEAR:
				g["near"] = true
				g["t"] = 0.0
			else:
				g["t"] = float(g["t"]) + delta
				if bool(g["near"]) and float(g["t"]) > SLIP_SEC:
					host_release(who, "ロープが張って、手から抜けた")
				elif float(g["t"]) > STUCK_SEC:
					host_release(who, "ロープが張っていて、これ以上は動かない")
	if host and _resync > 0.0:
		# 形のずれを直す：ホストの道すじ（間引き）を配る。大きくずれている画面だけが、それに合わせる
		_resync -= delta
		if _resync <= 0.0:
			_resync = RESYNC_SEC if not grabs.is_empty() else 0.0
			var bk := _bk()
			var ck := _ck()
			if bk != null:
				bk._broadcast(true)
			if ck != null and not ck.lashes.is_empty():
				ck._broadcast()
	elif host and not grabs.is_empty():
		_resync = RESYNC_SEC


# つかんだ所を、手のほうへ動かす。結んである端（と、ほかの人の手）までのロープが張っていたら、それより先へは行かない：
#   ・その端からの、まっすぐの距離が、そこまでのロープの長さを超えない
#   ・そこまでの道のり（物に回り込んだ分も入る）に残っているたるみの分だけ、進める。張りすぎていたら、その分だけ戻る
func _limit(cord: Node3D, who: int, g: Dictionary, k: int, want: Vector3) -> Vector3:
	var n: int = cord.pts.size()
	var was: Vector3 = g["at"]
	var lo := -1
	var hi := -1
	var lo_at := Vector3.ZERO
	var hi_at := Vector3.ZERO
	if cord.a_body != null and is_instance_valid(cord.a_body):
		lo = 0
		lo_at = cord.pts[0]
	if cord.b_body != null and is_instance_valid(cord.b_body) and not _feeds(int(g["kind"]), int(g["id"]), cord):
		hi = n - 1
		hi_at = cord.pts[n - 1]
	for other: int in grabs:
		if other == who:
			continue
		var o: Dictionary = grabs[other]
		if int(o["kind"]) != int(g["kind"]) or int(o["id"]) != int(g["id"]) or not bool(o["set"]):
			continue
		var j: int = cord.node_at(float(o["s"]))
		if j < 0 or j == k:
			continue
		if j < k and j > lo:
			lo = j
			lo_at = o["at"]
		elif j > k and (hi < 0 or j < hi):
			hi = j
			hi_at = o["at"]
	if lo < 0 and hi < 0:
		return want
	var here: float = cord.s_of(k)
	# 残っているたるみ（いちばん少ない側）。負なら、張りすぎている
	var room := INF
	var back := Vector3.ZERO
	if lo >= 0 and k > lo:
		var slack: float = _room(cord, lo, k, here - float(cord.s_of(lo)))
		if slack < room:
			room = slack
			back = cord.pts[k - 1]
	if hi >= 0 and k < hi:
		var slack: float = _room(cord, k, hi, float(cord.s_of(hi)) - here)
		if slack < room:
			room = slack
			back = cord.pts[k + 1]
	var at := want
	if room < 0.0:
		at = was.move_toward(back, minf(-room, 0.25))
	elif was.distance_to(want) > room:
		at = was.move_toward(want, room)
	for pass_no in 3:
		if lo >= 0:
			var reach: float = here - float(cord.s_of(lo))
			var d := at - lo_at
			if d.length() > reach:
				at = lo_at + d.normalized() * reach
		if hi >= 0:
			var reach: float = float(cord.s_of(hi)) - here
			var d := at - hi_at
			if d.length() > reach:
				at = hi_at + d.normalized() * reach
	return at


# 節 from から to までの道のりに残っている、たるみ（m）。arc＝その間のロープの長さ
func _room(cord: Node3D, from: int, to: int, arc: float) -> float:
	var path := 0.0
	for i in range(from, to):
		path += (cord.pts[i] as Vector3).distance_to(cord.pts[i + 1])
	return arc * 1.005 + 0.004 - path


# ---- 通信 ----

func rows() -> Dictionary:
	var out := {}
	for who: int in grabs:
		var g: Dictionary = grabs[who]
		out[who] = [int(g["kind"]), int(g["id"]), float(g["s"])]
	return out


func _broadcast() -> void:
	game.ev.rpc("ropegrab", [rows()])


func sync_to(who: int) -> void:
	if Net.is_host() and who != Net.my_id():
		game.ev.rpc_id(who, "ropegrab", [rows()])


# 合図を受け取った（参加者の画面。ホストは自分で決めているので、受け取らない）
func receive(data: Dictionary) -> void:
	if Net.is_host():
		return
	for who: int in grabs.keys():
		if not data.has(who):
			grabs.erase(who)
	for who: int in data:
		var row: Array = data[who]
		if grabs.has(who):
			# つかんだ所のいまの場所は、そのまま（切られて、切れた先のロープへ移ったときも）
			var g: Dictionary = grabs[who]
			g["kind"] = int(row[0])
			g["id"] = int(row[1])
			g["s"] = float(row[2])
		else:
			grabs[who] = {"kind": int(row[0]), "id": int(row[1]), "s": float(row[2]), "at": Vector3.ZERO, "set": false, "near": false, "t": 0.0}


# ---- 操作（左クリック・F）と画面の案内 ----

func _usable(me: Node) -> bool:
	var flow: Node = game.get("production")
	return me != null and flow != null and me.operating == 0 and flow.phase in [0, 2, 4] and game.state in [game.S.PREP, game.S.TAKE] and not game.replaying


# 視線の先の、つかめる所。{"kind", "id", "s", "point", "off", "hot"（燃えている先のそば）}。無ければ {}
func aim(me: Node) -> Dictionary:
	if not _usable(me) or me.held != 0 or grabs.has(me.peer_id):
		return {}
	var cam: Camera3D = me.cam
	if cam == null:
		return {}
	var from: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_basis.z
	# 手前に物があれば、その物を持つほうが先
	var wall := INF
	if me.target != null:
		wall = (me.target_hit - from).dot(dir) + 0.15
	var best := {}
	var lists: Array = []
	var bk := _bk()
	var ck := _ck()
	if bk != null:
		for id: int in bk.cords:
			lists.append([CORD, id, bk.cords[id]])
	if ck != null:
		for id: int in ck.lashes:
			lists.append([LASH, id, ck.lashes[id]["cord"]])
	for item: Array in lists:
		var cord: Node3D = item[2]
		if not cord.visible or cord.pts.size() < 2:
			continue
		var hit: Dictionary = cord.nearest_to_ray(from, dir)
		if hit.is_empty() or float(hit["off"]) > AIM + 0.02 * float(hit["along"]) or float(hit["along"]) > wall:
			continue
		if (hit["point"] as Vector3).distance_to(_chest(me)) > game.Player.REACH + 0.6:
			continue
		if best.is_empty() or float(hit["off"]) < float(best["off"]):
			best = hit
			best["kind"] = int(item[0])
			best["id"] = int(item[1])
	if best.is_empty():
		return {}
	var cord := cord_of(int(best["kind"]), int(best["id"]))
	var s: float = best["s"]
	best["hot"] = bool(cord.burning) and float(cord.length) - s < HOT
	var k: int = cord.node_at(s)
	if k < 0:
		return {}
	# 端のそばは、端をつかむ
	var end := end_of(cord, s)
	if end == 1:
		k = cord.pts.size() - 1
	elif end == 0:
		k = 0
	best["s"] = cord.s_of(k)
	if not bool(best["hot"]):
		best["point"] = cord.pts[k]
	return best


# 手ぶらの左クリック（production_main.gd の world_click）。ここで受けたら true
func handle_click(me: Node) -> bool:
	if me == null or game.get("production") == null:
		return false
	if grabs.has(me.peer_id):
		h_release.rpc_id(1)
		return true
	var a := aim(me)
	if a.is_empty():
		return false
	if bool(a["hot"]) and me.get("vis") != null:
		# 熱そうな顔をする（断るのはホスト）
		me.vis.set_face("shock")
		me._face_t = 1.2
	h_grab.rpc_id(1, int(a["kind"]), int(a["id"]), float(a["s"]))
	return true


# いま F を押すと起きること。{"do": "bomb"（口金につなぐ）/ "hook"（フックに結ぶ）/ "end"（端をつかんでいるだけ）/ "mid"（途中をつかんでいる）}
func f_action(me: Node) -> Dictionary:
	if not _usable(me) or not grabs.has(me.peer_id):
		return {}
	var g: Dictionary = grabs[me.peer_id]
	var kind: int = g["kind"]
	var cord := cord_of(kind, int(g["id"]))
	var bk := _bk()
	var ck := _ck()
	if cord == null or bk == null or ck == null:
		return {}
	var end := end_of(cord, float(g["s"]))
	if end < 0:
		return {"do": "mid"}
	if kind == CORD and me.target == bk.bomb and not bk.bomb.absent and cord.a_body != bk.bomb and not (end == 1 and cord.burning):
		return {"do": "bomb"}
	var loose: bool = cord.a_body == null and cord.b_body == null and not cord.burning
	if (kind == CORD and loose) or (kind == LASH and end == 1):
		var hook: int = ck.aim_hook(me)
		if hook >= 0 and not (kind == LASH and int(ck.lashes[int(g["id"])]["a"]) == hook):
			return {"do": "hook", "hook": hook, "point": ck.hook_at(hook)}
		return {"do": "end", "bomb": kind == CORD}
	return {"do": "end", "bomb": kind == CORD, "hookless": true}


# F が押された（自分の画面）。ここで受けたら true
func handle_f(me: Node) -> bool:
	var act := f_action(me)
	match str(act.get("do", "")):
		"bomb":
			h_use.rpc_id(1, "bomb", -1)
			return true
		"hook":
			h_use.rpc_id(1, "hook", int(act["hook"]))
			return true
	return false


# 画面の案内（production_hud.gd）。動作だけを書く。label・keys＝いま出ている名前と操作の案内。
# 差し替えるなら {"label", "keys"}、そのままなら {}
func hud_view(me: Node, label: String, keys: String) -> Dictionary:
	if me == null:
		return {}
	if grabs.has(me.peer_id):
		var act := f_action(me)
		match str(act.get("do", "")):
			"bomb":
				return {"label": "爆弾", "keys": "F つなぐ\n左クリック ロープを離す"}
			"hook":
				return {"label": "フック", "keys": "F フックに結ぶ\n左クリック ロープを離す"}
			"end":
				if bool(act.get("hookless", false)):
					return {"label": "ロープ", "keys": "爆弾の口を見て F つなぐ\n左クリック 離す"}
				return {"label": "ロープ", "keys": ("爆弾の口を見て F つなぐ ／ フックを見て F 結ぶ" if bool(act.get("bomb", false)) else "フックを見て F 結ぶ") + "\n左クリック 離す"}
		return {"label": "ロープ", "keys": "左クリック 離す"}
	if aim(me).is_empty():
		return {}
	if label in ["ロープ", "ロープの先"]:
		# F の案内（点火・ほどく）が出ている：その下に足す
		return {"label": label, "keys": keys + "\n左クリック つかむ"}
	return {"label": "ロープ", "keys": "左クリック つかむ"}


func _process(_delta: float) -> void:
	if _mark == null or game == null:
		return
	var me: Node = game.local_player()
	var a: Dictionary = aim(me) if me != null and not game.ui_blocking() else {}
	_mark.visible = not a.is_empty() and not bool(a.get("hot", false))
	if _mark.visible:
		_mark.global_position = a["point"]
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null and cam.global_position.distance_to(_mark.global_position) > 0.05:
			_mark.look_at(cam.global_position, Vector3.UP)
			_mark.rotate_object_local(Vector3.RIGHT, PI * 0.5)
