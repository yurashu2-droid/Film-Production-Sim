extends RefCounted
## 荷台のロープ：フック・掛ける・ほどく・切る・押さえの計算・道中。
## cargo_kit.gd（運ぶ道具の入口）が作って持つ。外からは game.cargo_kit.〜 で呼ぶ（cargo_kit.gd が、ここへ渡す）。
##   ・ロープ：束を持って、荷台のフックを見て F で端を結ぶ。そのまま別のフックを見て F で、もう片方も結ぶ。
##     ロープは物理のひも（fuse_cord.gd。爆弾の導火線と同じ束・同じ計算）で、荷物の形に沿って垂れる・張る。
##     効き目は掛け方で決まる：荷物の上をきちんと通り、張っているロープは、その荷物を押さえる（道中で動かない）。
##     たるんでいる・上を通っていない・端にしか掛かっていないロープは、押さえが弱い（道中でずれる・落ちる）。
##     本数の上限は無い。束の長さ（爆弾の導火線に使う分と同じ。cargo_coils.gd）で決まる。
##     掛けたロープを見て F でほどく（束に巻き戻る）。はさみで切れる（切れたら、もう押さえない）。
##     現場に着いても掛かったまま。自分でほどく
## 決めるのはホストだけ。掛けたロープ（どのフックからどのフックへ・長さ・道すじの間引き）は、
## cargo_kit.gd が "kit" の合図で全員へ配る。ロープの節の位置は、各自の画面で計算する（毎コマは送らない）。
## 押さえの強さは、ホストだけが計算する（画面には出さない。見た目で判断する）
const Prop := preload("res://scripts/prop.gd")
const FilmCamera := preload("res://scripts/film_camera.gd")
const Cord := preload("res://scripts/fuse_cord.gd")

const END_FREE := -1                          # ロープの端：どこにも結んでいない（切れた・外れた）
const END_COIL := -2                          # ロープの端：束につながっている（掛けている途中）
const HOOK_AIM := 0.2                         # フック：視線からの離れが、これ以内なら狙える
const ROPE_AIM := 0.07                        # 掛けたロープ：ほどくときの狙い（荷物を狙うのと、まぎれないよう細く）
const CUT_AIM := 0.16                         # はさみ：切るときの狙い（bomb_kit.gd と同じ）
const MIN_PIECE := 0.12                       # これより短い切れ端は、残さない
const KNOT_LOOSE := 0.02                      # 結び目に残る、ゆるみの上限（m）
const THROW_LOOSE := 0.08                     # 遠くから投げて結ぶと、1mあたりこれだけまで、ゆるみが増える
const BUMP_LOOSE := 0.04                      # 段差1回で、結び目がこれだけまで、ゆるむ
const LIFT := 0.035                           # 張ったロープの道すじを測るとき、物の面からこれだけ浮かせる（ロープの太さと、角を回る分）
const SLACK_OK := 0.08                        # たるみがここまでなら、しっかり張っている
const SLACK_BAD := 0.28                       # たるみがここまで来たら、何も押さえない
const FIRM_ON := 0.55                         # 押さえがこれ以上で、荷台に留まる
const FIRM_OFF := 0.4                         # これを下回ると、留まらなくなる
const WEAK_GRIP := 0.22                       # 弱い押さえ：1コマに、荷台とのずれの速さをこの割合（×押さえ）まで消す

var kit: Node                                 # cargo_kit.gd（入口）
var game: Node:
	get:
		return kit.game
var flow: Node:
	get:
		return kit.flow
var rng: RandomNumberGenerator:               # 結び目のゆるみ（cargo_kit.gd が持つ。確認では、種を決めて同じ結果にできる）
	get:
		return kit.rng
var boxes: RefCounted:                        # 段ボール箱（cargo_boxes.gd）
	get:
		return kit.boxes
var reels: RefCounted:                        # ひもの束（cargo_coils.gd）
	get:
		return kit.reels
var lashes: Dictionary = {}                   # 掛けたロープ：番号 → {id, a, b（フックの番号。END_FREE・END_COIL）, cord, slack, coil（出どころの束。0＝会社のロープ）}
var holds: Dictionary = {}                    # ホスト：ロープが押さえている物（物のID → {press 押さえの強さ 0〜1, firm, anchor}）
var _next_lash := 1
# 軽トラは、毎コマの最初に「次の位置」へ動かされる（production_flow.gd）が、物理の世界の軽トラ（当たり判定）と荷物は、
# そのコマの物理の計算が終わるまで前の位置のまま。ロープは、前の位置（_truck_xf）で計算してから、次の位置へ運ぶ。
# フックの場所も、前の位置に置いた印（_frame）から取る。こうしないと、走っている間、ロープが荷物から1コマぶんずれる
var _truck_xf := Transform3D.IDENTITY
var _frame: Node3D
var _truck_seen := false
var _truck_vel := Vector3.ZERO
var _eval_in := 0
var _lash_dirty := false
var _lash_send := 0.0
var _bed_sig := 0
var _bed_check := 0
var _bumps_seen := 0
var _phase_seen := -1
var _vehicle_seen := ""
var _coil_shown := -1.0
var _hook_marks: Array = []
var _aim_mark: MeshInstance3D


# ---- ロープ（荷台のフックからフックへ掛ける） ----


func hook_at(index: int) -> Vector3:
	return game.truck.global_transform * (game.truck.hooks[index] as Vector3)


# 掛けている途中のロープ（片方をフックに結び、もう片方が、その束につながっている）。無ければ {}
func open_lash(coil: int = 0) -> Dictionary:
	for lash: Dictionary in lashes.values():
		if int(lash["b"]) == END_COIL and int(lash.get("coil", 0)) == coil:
			return lash
	return {}


# 両方の端をフックに結んだロープの数
func lash_count() -> int:
	var count := 0
	for lash: Dictionary in lashes.values():
		if int(lash["a"]) >= 0 and int(lash["b"]) >= 0:
			count += 1
	return count


# その物を、ロープがどれだけ押さえているか（0〜1。ホストだけが知っている。画面には出さない）
func grip_of(pid: int) -> float:
	return float((holds.get(pid, {}) as Dictionary).get("press", 0.0))


# ロープが、その物を荷台に留めているか（持ち上げられない）
func pinned(pid: int) -> bool:
	return bool((holds.get(pid, {}) as Dictionary).get("firm", false))


func _make_lash(id: int, coil: int = 0) -> Dictionary:
	var cord: Node3D = Cord.new()
	cord.id = id
	cord.name = "Lash%d" % id
	# 荷物を押さえるロープは、張って使う。自分の重さで伸びて垂れないよう、長さをそろえる計算を多めにする
	cord.iterations = 32
	kit.add_child(cord)
	if reels.coils.has(coil):
		_tint_cord(cord, reels.coils[coil]["color"])
	var lash := {"id": id, "a": END_FREE, "b": END_FREE, "cord": cord, "slack": 0.0, "coil": coil if reels.coils.has(coil) or coil == reels.SCRAP else 0}
	lashes[id] = lash
	return lash


# ひもの色を替える（足した束から出たひも）
func _tint_cord(cord: Node3D, color: Color) -> void:
	for part: MultiMeshInstance3D in cord.find_children("*", "MultiMeshInstance3D", true, false):
		var mat := part.multimesh.mesh.surface_get_material(0) as StandardMaterial3D
		if mat != null:
			mat = mat.duplicate() as StandardMaterial3D
			mat.albedo_color = color
			mat.emission = color
			part.material_override = mat


func _drop_lash(id: int) -> void:
	var lash: Dictionary = lashes.get(id, {})
	lashes.erase(id)
	if not lash.is_empty():
		(lash["cord"] as Node).queue_free()


# 結んだ先（フック・束）を、ロープの端に反映する
func _pin(lash: Dictionary) -> void:
	var truck: RigidBody3D = game.truck
	var cord: Node3D = lash["cord"]
	var a: int = lash["a"]
	var b: int = lash["b"]
	cord.a_body = null
	if a >= 0 and a < truck.hooks.size():
		cord.a_body = _frame
		cord.a_local = truck.hooks[a]
	# 束につながっている間は、束には当てない（線の出口が束の中にある）。フックに結んだら、軽トラの壁や荷台に当てる
	cord.hit_tip = b != END_COIL
	cord.b_body = null
	if b == END_COIL:
		cord.b_body = reels.coil_prop(int(lash.get("coil", 0)))
		cord.b_local = reels._coil_exit(int(lash.get("coil", 0)))
	elif b >= 0 and b < truck.hooks.size():
		cord.b_body = _frame
		cord.b_local = truck.hooks[b]


func _length_of(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total


# 点の並び（横の道のり xs・高さ ys）の、上側の包み（ぴんと張ったひもが通る点）。並びの番号を返す
func _upper_hull(xs: PackedFloat32Array, ys: PackedFloat32Array) -> PackedInt32Array:
	var hull := PackedInt32Array()
	for i in xs.size():
		while hull.size() >= 2:
			var a := hull[hull.size() - 2]
			var b := hull[hull.size() - 1]
			# b が、a から i への線より下（線の上も含む）なら、ひもは b に触れない
			if (xs[b] - xs[a]) * (ys[i] - ys[a]) - (ys[b] - ys[a]) * (xs[i] - xs[a]) >= 0.0:
				hull.remove_at(hull.size() - 1)
			else:
				break
		hull.append(i)
	return hull


# フックの真上まで張り出している物（荷台より幅の広い板など）があるとき、ロープがその端を回る点を返す。
# 無ければ、at をそのまま返す。away＝ロープが向かう先（その反対の、外側へ探す）
func _edge_out(at: Vector3, away: Vector3, lift: float, roof: float) -> Vector3:
	var out := Vector3(at.x - away.x, 0.0, at.z - away.z)
	if out.length() < 0.05:
		return at
	out = out.normalized()
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var skip: Array[RID] = reels._coil_rids()
	var top := 0.0
	for k in 70:
		var x: float = at.x + out.x * 0.025 * float(k)
		var z: float = at.z + out.z * 0.025 * float(k)
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, roof, z), Vector3(x, at.y + 0.06, z), Cord.HITS)
		q.exclude = skip
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			return at if k == 0 else Vector3(x + out.x * 0.02, top + lift, z + out.z * 0.02)
		top = (hit["position"] as Vector3).y
	return at


# from から to へ、まっすぐ上から見た線に沿って、間にある物（荷物・側板）の高さを調べる。
# ぴんと張ったひもは、その高さの並びの「上側の包み」を通る。
#   xs・ys：横の道のりと高さ（両端を含む） / pos：その場所 / bodies：そこにある物（両端は null） /
#   hull：包みの点（xs の番号） / length：包みの長さ（＝張ったときのひもの長さ）
func _profile(from: Vector3, to: Vector3, lift: float) -> Dictionary:
	var truck: RigidBody3D = game.truck
	var low := minf(from.y, to.y) - 0.5
	var roof: float = maxf((truck.global_transform * Vector3(0, truck.rope_ceiling, 0)).y, low + 1.0)
	# 端の真上に物が張り出していたら、その端を回る（a・b が、回る点）
	var a := _edge_out(from, to, lift, roof)
	var b := _edge_out(to, from, lift, roof)
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var pos := PackedVector3Array()
	var bodies: Array = []
	if not a.is_equal_approx(from):
		xs.append(-maxf(Vector2(a.x - from.x, a.z - from.z).length(), 0.001))
		ys.append(from.y)
		pos.append(from)
		bodies.append(null)
	xs.append(0.0)
	ys.append(a.y)
	pos.append(a)
	bodies.append(null)
	var dist := Vector2(b.x - a.x, b.z - a.z).length()
	if dist > 0.25:
		var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
		# 箱の壁のような薄い板も見落とさない細かさで調べる
		var n := ceili(dist / 0.025)
		var skip: Array[RID] = reels._coil_rids()
		for i in range(1, n):
			var w := float(i) / float(n)
			var x := lerpf(a.x, b.x, w)
			var z := lerpf(a.z, b.z, w)
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, roof, z), Vector3(x, low, z), Cord.HITS)
			q.exclude = skip
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				var top: float = (hit["position"] as Vector3).y + lift
				xs.append(w * dist)
				ys.append(top)
				pos.append(Vector3(x, top, z))
				bodies.append(hit["collider"])
	dist = maxf(dist, 0.001)
	xs.append(dist)
	ys.append(b.y)
	pos.append(b)
	bodies.append(null)
	if not b.is_equal_approx(to):
		xs.append(dist + maxf(Vector2(b.x - to.x, b.z - to.z).length(), 0.001))
		ys.append(to.y)
		pos.append(to)
		bodies.append(null)
	var hull := _upper_hull(xs, ys)
	var length := 0.0
	for k in hull.size() - 1:
		length += Vector2(xs[hull[k + 1]] - xs[hull[k]], ys[hull[k + 1]] - ys[hull[k]]).length()
	return {"xs": xs, "ys": ys, "pos": pos, "bodies": bodies, "hull": hull, "length": length}


# from から to へ、間にある物の上を越えて渡す道すじ（ロープを投げて渡したとき・張って結んだときの形）
func _over_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var prof := _profile(from, to, LIFT)
	var pos: PackedVector3Array = prof["pos"]
	var out := PackedVector3Array()
	for index: int in prof["hull"]:
		out.append(pos[index])
	return out


# 束を持って、フックを見て F：端を結ぶ／掛けている途中なら、もう片方を結ぶ／結んだばかりのフックなら、ほどく
@rpc("any_peer", "call_local", "reliable")
func h_hook(index: int) -> void:
	if not kit._host_ok():
		return
	var truck: RigidBody3D = game.truck
	if index < 0 or index >= truck.hooks.size():
		return
	var who := Net.sender()
	var pl: Node3D = game.players.get(who)
	var held: Node = game._held_by(who)
	if pl == null or not reels.is_coil(held) or held.absent:
		return
	if pl.global_position.distance_to(hook_at(index)) > game.Player.REACH + 1.5:
		kit._say(who, "フックに近づく", true)
		return
	var coil: int = reels.coil_id(held)
	var open := open_lash(coil)
	if open.is_empty():
		_start(index, who, coil)
	elif int(open["a"]) == index:
		_undo(int(open["id"]))
		game.host_ev("sfx", ["unfix", hook_at(index)])
	else:
		_close(open, index, who)


# 1つ目のフックに端を結ぶ。ロープは、フックから手元の束まで（間に荷物があれば、その上を越えて）出る
func _start(index: int, who: int, coil: int = 0) -> void:
	var truck: RigidBody3D = game.truck
	var path := _over_path(hook_at(index), reels.coil_prop(coil).global_transform * reels._coil_exit(coil))
	var need := _length_of(path) + 0.03
	if reels.stock(coil) < maxf(0.3, need):
		kit._say(who, "束のロープが足りない" if coil == 0 else "毛が足りない", true)
		game.ev.rpc_id(who, "sfx", ["ui_fail", null])
		return
	# 束から爆弾へ出ていた線は、束から外れる（爆弾につながったまま、床に残る）
	var bk: Node = kit._bk()
	if bk != null and coil == 0:
		bk.host_release_coil()
	var lash := _make_lash(_next_lash, coil)
	_next_lash += 1
	lash["a"] = index
	lash["b"] = END_COIL
	_pin(lash)
	(lash["cord"] as Node3D).lay(path, need)
	reels._use(need, coil)
	game.host_ev("sfx", ["fix", truck.global_transform * (truck.hooks[index] as Vector3)])
	kit._broadcast()


# 2つ目のフックに結ぶ。ロープを手繰って、2つのフックの間に張る（間にある荷物・側板の上を越えて渡る）。
# 手繰った分は束に戻り、足りない分は束から出る。結び目には、少しゆるみが残る。
# 遠くから投げて結ぶほど、雑になる（フックのそばまで行って結ぶと、よく張れる）
func _close(lash: Dictionary, index: int, who: int) -> void:
	var cord: Node3D = lash["cord"]
	var to := hook_at(index)
	var over := _over_path(cord.root(), to)
	var thrown: float = cord.tip().distance_to(to)
	var loose: float = rng.randf_range(0.0, KNOT_LOOSE) + thrown * rng.randf_range(0.0, THROW_LOOSE)
	var total: float = float(_profile(cord.root(), to, LIFT)["length"]) + loose
	var coil: int = int(lash.get("coil", 0))
	if total - cord.length > reels.stock(coil):
		kit._say(who, "束のロープが足りない。フックまで届かない" if coil == 0 else "毛が足りない。フックまで届かない", true)
		game.ev.rpc_id(who, "sfx", ["ui_fail", null])
		return
	reels._use(total - cord.length, coil)
	lash["b"] = index
	_pin(lash)
	# 張った長さで渡してから、結び目のゆるみを足す（ゆるみは、宙に渡っている所に垂れて見える）
	cord.lay(over, total - loose)
	_slacken(cord, loose)
	_eval_in = 0
	game.host_ev("sfx", ["fix", to])
	kit._broadcast()


# ほどいて、束に巻き戻す（ホスト）
func _undo(id: int) -> void:
	var lash: Dictionary = lashes.get(id, {})
	if lash.is_empty():
		return
	if int(lash.get("coil", 0)) == reels.SCRAP:
		# 切れ端を結んだロープ：ほどくと、その場に落ちて、床の切れ端に戻る
		var bk: Node = kit._bk()
		if bk != null:
			bk.host_add_scrap((lash["cord"] as Node3D).pts.duplicate(), float((lash["cord"] as Node3D).length))
	else:
		reels._use(-float((lash["cord"] as Node3D).length), int(lash.get("coil", 0)))
	_drop_lash(id)
	_eval_in = 0
	kit._broadcast()


# 掛けたロープを見て F（手ぶら、または束を持って）：ほどく
@rpc("any_peer", "call_local", "reliable")
func h_untie(id: int) -> void:
	if not kit._host_ok() or not lashes.has(id):
		return
	var who := Net.sender()
	var pl: Node3D = game.players.get(who)
	var held: Node = game._held_by(who)
	if pl == null or (held != null and not reels.is_coil(held)):
		return
	var cord: Node3D = lashes[id]["cord"]
	var near := INF
	for point: Vector3 in cord.pts:
		near = minf(near, pl.global_position.distance_to(point))
	if near > game.Player.REACH + 1.5:
		kit._say(who, "ロープに手が届かない", true)
		return
	var at: Vector3 = cord.root()
	_undo(id)
	game.host_ev("sfx", ["unfix", at])


# はさみを持って、掛けたロープを見て F：根元から s（m）の所で切る。切れた先は、それぞれのフックから垂れ下がる
@rpc("any_peer", "call_local", "reliable")
func h_cut_lash(id: int, s: float) -> void:
	if not kit._host_ok() or not lashes.has(id) or not is_finite(s):
		return
	var who := Net.sender()
	var pl: Node3D = game.players.get(who)
	var bk: Node = kit._bk()
	if pl == null or bk == null or bk.scissors.holder != who:
		return
	var lash: Dictionary = lashes[id]
	var cord: Node3D = lash["cord"]
	s = clampf(s, 0.0, cord.length)
	var at: Vector3 = cord.point_at(s)
	if pl.global_position.distance_to(at) > game.Player.REACH + 1.5:
		kit._say(who, "はさみが届かない", true)
		return
	var pts: PackedVector3Array = cord.pts
	var k := clampi(int(s / Cord.SEG), 0, pts.size() - 2)
	var near := PackedVector3Array()
	for i in k + 1:
		near.append(pts[i])
	near.append(at)
	var far := PackedVector3Array([at])
	for i in range(k + 1, pts.size()):
		far.append(pts[i])
	var whole: float = cord.length
	var b: int = lash["b"]
	var far_kind := 1
	var far_id := 0
	if whole - s >= MIN_PIECE:
		if b >= 0:
			# 向こうのフックに結んだ側：そのフックから垂れ下がる
			far.reverse()
			var other := _make_lash(_next_lash, int(lash.get("coil", 0)))
			far_id = _next_lash
			_next_lash += 1
			other["a"] = b
			_pin(other)
			(other["cord"] as Node3D).lay(far, whole - s)
		else:
			# 束の側・結んでいない側：床に落ちる切れ端になる（導火線の切れ端と同じ扱い。bomb_kit.gd）
			far_kind = 0
			far_id = bk.host_add_scrap(far, whole - s)
	lash["b"] = END_FREE
	if s >= MIN_PIECE:
		_pin(lash)
		cord.lay(near, s)
	else:
		_drop_lash(id)
	_eval_in = 0
	game.host_ev("sfx", ["unfix", at])
	kit._broadcast()
	# 切った所より先を手でつかんでいた人は、切れた先を、そのままつかんでいる（rope_grab.gd）
	var rg: Node = game.get("rope_grab")
	if rg != null:
		rg.host_split(1, id, s, s >= MIN_PIECE, far_kind, far_id, b >= 0, whole)


# 床の切れ端を、フックに結ぶ（ホスト。rope_grab.gd）。path＝結ぶ端から先への道すじ。
# フックから垂れたロープになる。作ったロープの番号を返す（だめなら 0）
func host_hang(path: PackedVector3Array, length: float, index: int, who: int) -> int:
	var truck: RigidBody3D = game.truck
	var pl: Node3D = game.players.get(who)
	if not kit._host_ok() or pl == null or index < 0 or index >= truck.hooks.size() or path.size() < 2 or length < MIN_PIECE:
		return 0
	if pl.global_position.distance_to(hook_at(index)) > game.Player.REACH + 1.5:
		kit._say(who, "フックに近づく", true)
		return 0
	var lash := _make_lash(_next_lash, reels.SCRAP)
	_next_lash += 1
	lash["a"] = index
	_pin(lash)
	# 手元にあった端を、フックへ持っていく（残りは、ひもの計算が引いて付いて来る）
	(lash["cord"] as Node3D).lay(path, length)
	(lash["cord"] as Node3D).reroot(hook_at(index))
	_eval_in = 0
	game.host_ev("sfx", ["fix", hook_at(index)])
	kit._broadcast()
	return int(lash["id"])


# フックから垂れたロープの、手でつかんだ端を、もう1つのフックに結ぶ（ホスト。rope_grab.gd）。
# 束が無いので、長さは足せない：届かなければ結べない。手繰って張り、余った分は、結び目の先に垂れる。
# 結び目には、少しゆるみが残る（フックから離れて結ぶほど、雑になる）
func host_tie_end(id: int, index: int, who: int) -> bool:
	var truck: RigidBody3D = game.truck
	var pl: Node3D = game.players.get(who)
	if not kit._host_ok() or pl == null or not lashes.has(id) or index < 0 or index >= truck.hooks.size():
		return false
	var lash: Dictionary = lashes[id]
	if int(lash["b"]) != END_FREE or int(lash["a"]) < 0 or int(lash["a"]) == index:
		return false
	var to := hook_at(index)
	if pl.global_position.distance_to(to) > game.Player.REACH + 1.5:
		kit._say(who, "フックに近づく", true)
		return false
	var cord: Node3D = lash["cord"]
	var whole: float = cord.length
	var hand: Vector3 = cord.tip()
	var over := _over_path(cord.root(), to)
	var taut: float = float(_profile(cord.root(), to, LIFT)["length"])
	var loose: float = rng.randf_range(0.0, KNOT_LOOSE) + maxf(0.0, pl.global_position.distance_to(to) - 1.5) * rng.randf_range(0.0, THROW_LOOSE)
	if whole < taut - 0.03:
		kit._say(who, "ロープが短くて、フックまで届かない", true)
		game.ev.rpc_id(who, "sfx", ["ui_fail", null])
		return false
	loose = minf(loose, maxf(0.0, whole - taut))
	var left: float = whole - taut - loose
	lash["b"] = index
	_pin(lash)
	cord.lay(over, taut)
	if left >= MIN_PIECE:
		# 余った分：結び目の先に垂れる（同じフックから垂れた、別のロープ）
		_slacken(cord, loose)
		var rest := _make_lash(_next_lash, int(lash.get("coil", 0)))
		_next_lash += 1
		rest["a"] = index
		_pin(rest)
		var away: Vector3 = hand if hand.distance_to(to) > 0.05 else to + Vector3(0, -0.1, 0)
		(rest["cord"] as Node3D).lay(PackedVector3Array([to, away]), left)
	else:
		_slacken(cord, loose + maxf(left, 0.0))
	_eval_in = 0
	game.host_ev("sfx", ["fix", to])
	kit._broadcast()
	return true


# 束が、ほかの使い道（爆弾の口につなぐ）に回った（ホスト）：掛けている途中のロープは、束から外れて垂れ下がる
func host_coil_taken() -> void:
	var open := open_lash()
	if open.is_empty():
		return
	open["b"] = END_FREE
	_pin(open)
	(open["cord"] as Node3D).wake()
	kit._broadcast()


# 掛けたロープを全部外す（ホスト）。refund＝束に巻き戻す
func host_clear_lashes(refund: bool = true) -> void:
	if not Net.is_host():
		return
	for id: int in lashes.keys():
		if refund:
			reels._use(-float((lashes[id]["cord"] as Node3D).length), int(lashes[id].get("coil", 0)))
		_drop_lash(id)
	holds = {}


# 確認用：そのロープを、決めた長さだけゆるめる（ホスト）。遊びの中では、結び目・投げ方・段差・荷物の動きでゆるむ
func host_loosen(id: int, by: float) -> void:
	if not Net.is_host() or not lashes.has(id):
		return
	_slacken(lashes[id]["cord"], by)
	_eval_in = 0
	kit._broadcast()


# ロープをゆるめる：足した長さは、宙に渡っている所（何にも載っていない区間）に、区間の長さに合わせて分けて出す。
# そこが垂れ下がるので、ゆるんだことが見て分かる（物の上に載っている所に足しても、節が寄るだけで見えない）
func _slacken(cord: Node3D, by: float) -> void:
	var extra := int(floor(by / Cord.SEG + 0.001))
	var n: int = cord.pts.size()
	var runs: Array = []          # 宙に渡っている区間 [始まりの節, 節の数, 足す数]
	if extra > 0 and n >= 4:
		var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
		var run_from := -1
		for i in range(1, n):
			var free := false
			if i < n - 1:
				var q := PhysicsRayQueryParameters3D.create(cord.pts[i] + Vector3(0, 0.03, 0), cord.pts[i] - Vector3(0, 0.14, 0), Cord.HITS)
				free = space.intersect_ray(q).is_empty()
			if free and run_from < 0:
				run_from = i
			elif not free and run_from >= 0:
				if i - run_from >= 2:
					runs.append([run_from, i - run_from, 0])
				run_from = -1
	if not runs.is_empty():
		for k in extra:
			var pick: Array = runs[0]
			for run: Array in runs:
				if float(run[2]) / float(run[1]) < float(pick[2]) / float(pick[1]):
					pick = run
			pick[2] = int(pick[2]) + 1
		# 後ろの区間から足す（前の区間の節の番号が、ずれないように）。区間の真ん中に、少し下げて置く。あとは、ひもの計算が垂らす
		runs.reverse()
		for run: Array in runs:
			var at: int = int(run[0]) + int(run[1]) / 2
			var a: Vector3 = cord.pts[at - 1]
			var b: Vector3 = cord.pts[at]
			for k in int(run[2]):
				var mid: Vector3 = a.lerp(b, float(k + 1) / float(int(run[2]) + 1)) - Vector3(0, 0.02, 0)
				cord.pts.insert(at + k, mid)
				cord.old.insert(at + k, mid)
				cord.grip.insert(at + k, 0)
		cord.length += Cord.SEG * float(extra)
		by -= Cord.SEG * float(extra)
	# 端数（と、宙に渡っている所が無いときの全部）は、先の側に足す
	cord.set_length(cord.length + maxf(by, 0.0))
	cord.wake()


# ---- ロープの毎コマの計算 ----


# 軽トラが動いた分だけ、掛けたロープを軽トラごと運ぶ（全員の画面で。そのコマの計算が終わったあとに）
func _carry_lashes() -> void:
	var now: Transform3D = game.truck.global_transform
	if _truck_seen and not now.is_equal_approx(_truck_xf):
		var shift: Transform3D = now * _truck_xf.affine_inverse()
		for lash: Dictionary in lashes.values():
			(lash["cord"] as Node3D).carry(shift)
	_truck_xf = now
	_truck_seen = true
	_frame.global_transform = now


# 荷台の物が動いたら、眠っているロープを起こす（全員の画面で）。走っている間は、いつも起きている
func _wake_lashes() -> void:
	if lashes.is_empty():
		return
	var stir: bool = flow.phase == 3
	_bed_check -= 1
	if not stir and _bed_check <= 0:
		_bed_check = 12
		var truck: RigidBody3D = game.truck
		var inv: Transform3D = truck.global_transform.affine_inverse()
		var sig := 0
		for prop: RigidBody3D in game.props.values():
			if prop.absent or prop == truck or prop == reels.rope or prop.holder != 0:
				continue
			var c: Vector3 = inv * prop.global_position
			if absf(c.x) < 2.2 and c.z > -3.6 and c.z < 1.2 and c.y > truck.deck_top - 0.4 and c.y < 5.0:
				sig = hash([sig, prop.pid, Vector3i(c * 25.0), Vector3i(prop.global_basis.y * 12.0)])
		stir = sig != _bed_sig
		_bed_sig = sig
	if stir:
		for lash: Dictionary in lashes.values():
			(lash["cord"] as Node3D).wake()


# 物の中に入ってしまった節を、その物の上へ出す（物が動いて、ロープの下へもぐり込んだとき）
func _unbury(cord: Node3D) -> void:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var probe := PhysicsPointQueryParameters3D.new()
	probe.collision_mask = Cord.HITS
	var skip: Array[RID] = reels._coil_rids()
	probe.exclude = skip
	var first := 1 if cord.a_body != null else 0
	var last: int = cord.pts.size() - (2 if cord.b_body != null else 1)
	for i in range(first, last + 1):
		var p: Vector3 = cord.pts[i]
		probe.position = p
		if space.intersect_point(probe, 1).is_empty():
			continue
		var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.2, 0), p, Cord.HITS)
		q.exclude = skip
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			continue
		var top: Vector3 = (hit["position"] as Vector3) + Vector3(0, Cord.THICK, 0)
		cord.pts[i] = top
		cord.old[i] = top
		cord.grip[i] = 0
	# 節と節の間に、薄い板（箱の壁・板のふち）がはさまっている：近いほうの節を、その板の上に載せる。
	# ひもの計算は節でしか当たりを見ないので、節の間隔より薄い板は、放っておくと両側へずり落ちて通り抜ける
	var count: int = cord.pts.size()
	for i in count - 1:
		var a: Vector3 = cord.pts[i]
		var b: Vector3 = cord.pts[i + 1]
		if a.distance_squared_to(b) < 0.0004:
			continue
		var cross := PhysicsRayQueryParameters3D.create(a, b, Cord.HITS)
		cross.exclude = skip
		var wall: Dictionary = space.intersect_ray(cross)
		if wall.is_empty():
			continue
		# 薄い板を突き抜けているときだけ直す（入る面と出る面が、背中合わせ）。
		# 厚い物の角をかすめているだけ（入る面と出る面が直角）なら、そのまま：直すと、角の所でいつまでも揺れる
		var back := PhysicsRayQueryParameters3D.create(b, a, Cord.HITS)
		back.exclude = skip
		var other: Dictionary = space.intersect_ray(back)
		if other.is_empty() or (other["normal"] as Vector3).dot(wall["normal"] as Vector3) > -0.7:
			continue
		var at: Vector3 = (wall["position"] as Vector3) + (b - a).normalized() * 0.012
		var down := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.8, 0), at - Vector3(0, 0.02, 0), Cord.HITS)
		down.exclude = skip
		var roof: Dictionary = space.intersect_ray(down)
		if roof.is_empty():
			continue
		var edge: Vector3 = roof["position"]
		# 角をかすめているだけ（3cm まで）なら、そのまま
		if edge.y - (wall["position"] as Vector3).y < 0.03:
			continue
		var k: int = i if a.distance_squared_to(at) < b.distance_squared_to(at) else i + 1
		if k < first or k > last:
			k = i + 1 if k == i else i
		if k < first or k > last:
			continue
		var seat: Vector3 = edge + Vector3(0, Cord.THICK, 0)
		cord.pts[k] = seat
		cord.old[k] = seat
		cord.grip[k] = 0


# 張っている区間を、まっすぐにする。ひもの計算は、ほんの少し伸びる（自分の重さで 1% ほど）。伸びは小さくても、
# 垂れは大きく見える（1m の区間が 1% 伸びると 6cm 垂れる）ので、張ったロープがゆるんで見えてしまう。
# 支えられた節（物に載って止まっている節・結んだ端）の間が、ロープの長さいっぱいに開いていて、間に何も無ければ、
# その間の節をまっすぐ並べる。長さに余りがある区間（ゆるんだロープ）は、そのまま垂らす。
# 余りが節1つ分より小さいうちは、張っているとみる（節は 10cm おきなので、物の角に合わせると、それだけの半端が出る）
func _straighten(cord: Node3D) -> void:
	var n: int = cord.pts.size()
	if n < 3 or cord.grip.size() != n:
		return
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var skip: Array[RID] = reels._coil_rids()
	var tail: float = maxf(cord._tail_rest(), 0.005)
	var start := 0 if cord.a_body != null else -1
	for i in range(1, n):
		if cord.grip[i] == 0 and not (i == n - 1 and cord.b_body != null):
			continue
		if start >= 0 and i - start >= 2:
			var p: Vector3 = cord.pts[start]
			var q: Vector3 = cord.pts[i]
			var rest: float = Cord.SEG * float(i - start) if i < n - 1 else Cord.SEG * float(i - start - 1) + tail
			var gap: float = p.distance_to(q)
			if gap >= rest - Cord.SEG * 0.7 and gap > 0.1:
				var ray := PhysicsRayQueryParameters3D.create(p.lerp(q, 0.04 / gap), q.lerp(p, 0.04 / gap), Cord.HITS)
				ray.exclude = skip
				if space.intersect_ray(ray).is_empty():
					for k in range(start + 1, i):
						var spot: Vector3 = p.lerp(q, float(k - start) / float(i - start))
						cord.pts[k] = spot
						cord.old[k] = spot
		start = i


# ホスト：掛けている途中のロープを束から出す・結ぶときに張る・段差でゆるむ・押さえを計算して効かせる
func _host_lashes(delta: float) -> void:
	var truck: RigidBody3D = game.truck
	# 車を買い替えた（フックの場所が変わる）：全部ほどいて、束に巻き戻す
	if _vehicle_seen != "" and _vehicle_seen != str(truck.vehicle) and not lashes.is_empty():
		host_clear_lashes(true)
		kit._broadcast()
	_vehicle_seen = str(truck.vehicle)
	if lashes.is_empty():
		holds = {}
		_bumps_seen = int(flow._bumped)
		_phase_seen = flow.phase
		return
	for lash: Dictionary in lashes.values():
		var cord: Node3D = lash["cord"]
		if int(lash["b"]) == END_COIL:
			var coil: int = int(lash.get("coil", 0))
			var bundle: RigidBody3D = reels.coil_prop(coil)
			if bundle.absent:
				lash["b"] = END_FREE
				_pin(lash)
				kit._broadcast()
				continue
			# 束から出ていく：引っぱられた分だけ（張りが抜けるところまで）。束に巻き戻りはしない。
			# 束を手に持って止まっている間は、垂れたロープの小さな揺れで出続けないよう、まっすぐの距離＋1.5m までにする
			# （物に引っかけて遠回りしたときは、はっきり伸びた分だけ出る）
			var path: float = cord.path_length()
			var reach: float = cord.root().distance_to(cord.tip()) + 1.5
			if (path > cord.length + 0.01 and cord.length < reach) or path > cord.length * 1.06 + 0.02:
				if reels.stock(coil) > 0.0:
					# 1コマに出る長さには限りがある（束が置き直されて、一瞬だけ大きく伸びたときに、出しすぎない）
					var add := minf(minf(path + 0.03 - cord.length, reels.stock(coil)), 0.2)
					reels._use(add, coil)
					cord.set_length(cord.length + add)
					_lash_dirty = true
				elif path > cord.length * 1.1 + 0.05:
					# 使い切った：先が束から外れて、フックから垂れ下がる
					lash["b"] = END_FREE
					_pin(lash)
					cord.wake()
					if bundle.holder != 0:
						kit._say(bundle.holder, "束のロープを使い切った。先が束から外れた" if coil == 0 else "毛を使い切った。先が手から外れた", true)
					kit._broadcast()
	# 段差を踏むたびに、結び目が少しゆるむ
	if int(flow._bumped) > _bumps_seen:
		for lash: Dictionary in lashes.values():
			if int(lash["a"]) >= 0 and int(lash["b"]) >= 0:
				_slacken(lash["cord"], rng.randf_range(0.0, BUMP_LOOSE))
		kit._broadcast()
	_bumps_seen = int(flow._bumped)
	# 出発・到着のたびに、道すじを配り直す（各自の画面の計算のずれを直す）
	if flow.phase != _phase_seen:
		_phase_seen = flow.phase
		kit._broadcast()
	_eval_in -= 1
	if _eval_in <= 0:
		_eval_in = 6
		_evaluate()
	_apply_holds(delta)
	_lash_send -= delta
	if _lash_dirty and _lash_send <= 0.0:
		_lash_dirty = false
		_lash_send = 0.18
		game.ev.rpc("kit", [{"lite": true, "lashes": _lash_rows(false)}])


# 押さえの強さを決める（ホスト）。ロープの長さと、フックの間にある荷物の形だけで決まる：
#   ・たるみ：ロープの長さ − ぴんと張ったときの長さ（フックの間の、荷物・側板の上を越える道すじ）。少ないほど強い
#   ・その物の上を通っているか：張ったロープがその物の上面に触れていて、そこで折れ下がっている（上から押している）。
#     ロープより低い物（側板より低い荷物・となりの背の高い荷物に持ち上げられた下）には、触れない
#   ・どこを通っているか：上面の真ん中を通るほど強い。角や端にしか掛かっていないと弱い
# 押さえた物の下に積んである物も、いっしょに押さえる
func _evaluate() -> void:
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var truck: RigidBody3D = game.truck
	var press := {}
	for lash: Dictionary in lashes.values():
		if int(lash["a"]) < 0 or int(lash["b"]) < 0:
			continue
		var cord: Node3D = lash["cord"]
		var from: Vector3 = cord.root()
		var to: Vector3 = cord.tip()
		var prof := _profile(from, to, LIFT)
		var xs: PackedFloat32Array = prof["xs"]
		var ys: PackedFloat32Array = prof["ys"]
		var hull: PackedInt32Array = prof["hull"]
		var bodies: Array = prof["bodies"]
		var spots: PackedVector3Array = prof["pos"]
		var slack: float = maxf(0.0, cord.length - float(prof["length"]))
		lash["slack"] = slack
		var tight: float = 1.0 - smoothstep(SLACK_OK, SLACK_BAD, slack)
		if tight <= 0.0:
			continue
		# 張ったロープが触れる所（包みの高さにある点）を、物ごとに集める
		var touch := {}
		for j in range(1, xs.size() - 1):
			var body: Variant = bodies[j]
			if not (body is RigidBody3D) or body == truck or not ("pid" in body) or not game.props.has(body.pid):
				continue
			if ys[j] < _hull_height(xs, ys, hull, xs[j]) - 0.03:
				continue
			if not touch.has(body.pid):
				touch[body.pid] = []
			(touch[body.pid] as Array).append(j)
		for pid: int in touch:
			var prop: RigidBody3D = game.props[pid]
			var list: Array = touch[pid]
			if prop.absent or prop.holder != 0:
				continue
			# その物の上で、ロープが折れ下がっているか（両側へ 40cm 進む間に、どれだけ下がるか）
			var s_in: float = xs[int(list[0])]
			var s_out: float = xs[int(list[list.size() - 1])]
			var drop: float = (_hull_height(xs, ys, hull, s_in) - _hull_height(xs, ys, hull, s_in - 0.4)) + (_hull_height(xs, ys, hull, s_out) - _hull_height(xs, ys, hull, s_out + 0.4))
			var bend: float = clampf(drop / 0.24, 0.0, 1.0)
			# 上面のどこを通っているか（真ん中＝0、端＝1）
			var box: AABB = game.body_bounds(prop)
			var to_local: Transform3D = prop.global_transform.affine_inverse()
			var mean := Vector3.ZERO
			for j: int in list:
				mean += spots[j]
			mean /= float(list.size())
			# 実際のロープが、そこを通っているか（外れて落ちたロープは、押さえない）：
			# 張ったロープが触れるはずの所の半分より多くで、30cm 以内にロープの節がある
			var met := 0
			for j: int in list:
				for point: Vector3 in cord.pts:
					if point.distance_squared_to(spots[j]) < 0.09:
						met += 1
						break
			if met * 2 <= list.size():
				continue
			mean = to_local * mean - box.get_center()
			var edge: float = maxf(absf(mean.x) / maxf(box.size.x * 0.5, 0.02), absf(mean.z) / maxf(box.size.z * 0.5, 0.02))
			var centred: float = 1.0 - smoothstep(0.5, 0.95, edge)
			var span: float = (s_out - s_in) + 0.07
			var enough: float = clampf(span / minf(0.3, 0.6 * minf(box.size.x, box.size.z) + 0.05), 0.0, 1.0)
			var value: float = tight * bend * centred * enough
			press[pid] = 1.0 - (1.0 - float(press.get(pid, 0.0))) * (1.0 - value)
	# 下に積んである物も、いっしょに押さえる
	for pid: int in press.keys():
		var value: float = press[pid]
		var cur: RigidBody3D = game.props[pid]
		var skip: Array[RID] = [cur.get_rid()]
		for depth in 4:
			var q := PhysicsRayQueryParameters3D.create(cur.center_global(), cur.center_global() - Vector3(0, 2.5, 0), Prop.L_PROP)
			q.exclude = skip
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				break
			var below: Variant = hit["collider"]
			if not (below is RigidBody3D) or below == truck or not ("pid" in below) or not game.props.has(below.pid):
				break
			press[below.pid] = maxf(float(press.get(below.pid, 0.0)), value)
			cur = below
			skip.append(cur.get_rid())
	var here_inv: Transform3D = truck.global_transform.affine_inverse()
	for pid: int in press:
		var hold: Dictionary = holds.get(pid, {"firm": false})
		hold["press"] = press[pid]
		var body: RigidBody3D = game.props[pid]
		# 留めるのは、荷台の上で落ち着いている物だけ（はねている最中の物を、宙に留めない）
		if not bool(hold["firm"]) and float(press[pid]) >= FIRM_ON and (body.linear_velocity - _truck_vel).length() < 0.3:
			hold["firm"] = true
			hold["anchor"] = here_inv * body.global_transform
		elif bool(hold["firm"]) and float(press[pid]) < FIRM_OFF:
			hold["firm"] = false
		holds[pid] = hold
	for pid: int in holds.keys():
		if not press.has(pid):
			holds.erase(pid)


# 上側の包みの、横の道のり s での高さ
func _hull_height(xs: PackedFloat32Array, ys: PackedFloat32Array, hull: PackedInt32Array, s: float) -> float:
	var last := hull.size() - 1
	if s <= xs[hull[0]]:
		return ys[hull[0]]
	if s >= xs[hull[last]]:
		return ys[hull[last]]
	for k in last:
		var a := hull[k]
		var b := hull[k + 1]
		if s <= xs[b]:
			var span: float = xs[b] - xs[a]
			return maxf(ys[a], ys[b]) if span < 0.0005 else lerpf(ys[a], ys[b], (s - xs[a]) / span)
	return ys[hull[last]]


# 押さえを効かせる（ホスト、毎コマ）。
#   しっかり押さえた物：荷台の同じ場所に留める（このコマで軽トラが進む先へ、ちょうど届く速さにする）。発進でも段差でも動かない
#   弱い押さえ：荷台とのずれの速さを、押さえの分だけ消す。足りなければ、ずれる・落ちる
func _apply_holds(delta: float) -> void:
	if holds.is_empty():
		return
	var here: Transform3D = game.truck.global_transform
	var moving := _truck_vel.length() > 0.01
	for pid: int in holds:
		var hold: Dictionary = holds[pid]
		var prop: RigidBody3D = game.props.get(pid)
		if prop == null or prop.absent or prop.holder != 0 or prop.fixed or prop.freeze:
			continue
		if "operator" in prop and prop.operator != 0:
			continue
		if bool(hold["firm"]):
			var want: Transform3D = here * (hold["anchor"] as Transform3D)
			var off: Vector3 = want.origin - prop.global_position
			if off.length() > 0.8 + _truck_vel.length() * delta:
				# 大きく動かされた（現場への置き直し・撮り直しなど）：留めるのをやめて、次の計算で決め直す
				hold["firm"] = false
				continue
			var turn := Quaternion((want.basis * prop.global_basis.inverse()).orthonormalized())
			var angle: float = turn.get_angle()
			if angle > PI:
				angle -= TAU
			if not moving and off.length() < 0.004 and absf(angle) < 0.01 and prop.linear_velocity.length() < 0.05:
				continue          # 止まっているなら触らない（眠れる）
			prop.sleeping = false
			prop.linear_velocity = (off / maxf(delta, 0.001)).limit_length(_truck_vel.length() + 3.0)
			prop.angular_velocity = turn.get_axis() * (angle / maxf(delta, 0.001) * 0.5) if absf(angle) > 0.0005 else Vector3.ZERO
		elif moving or not prop.sleeping:
			var keep: float = 1.0 - clampf(float(hold["press"]) * WEAK_GRIP, 0.0, 0.5)
			prop.linear_velocity = _truck_vel + (prop.linear_velocity - _truck_vel) * keep
			prop.angular_velocity *= keep


# ---- 同期と記録 ----


# 掛けたロープの一覧：[番号, 根元のフック, 先のフック（END_FREE・END_COIL）, 長さ, 道すじ（軽トラから見た位置の間引き。full のときだけ）, 出どころの束]
func _lash_rows(full: bool) -> Array:
	var rows: Array = []
	var inv: Transform3D = game.truck.global_transform.affine_inverse()
	for id: int in lashes:
		var lash: Dictionary = lashes[id]
		var cord: Node3D = lash["cord"]
		var path: Variant = null
		if full:
			var local := PackedVector3Array()
			for point: Vector3 in cord.samples():
				local.append(inv * point)
			path = local
		rows.append([id, int(lash["a"]), int(lash["b"]), cord.length, path, int(lash.get("coil", 0))])
	return rows


# 掛けたロープを、受け取った一覧に合わせる（参加者の画面。ホストは、見返しのときだけ）。
# full でなければ、長さだけの知らせ（手繰っている・束から出ている間）
func _apply_lashes(data: Dictionary, full: bool) -> void:
	var here: Transform3D = game.truck.global_transform
	var seen := {}
	for row: Array in data.get("lashes", []):
		var id: int = row[0]
		seen[id] = true
		var lash: Dictionary = lashes.get(id, {})
		var path := PackedVector3Array()
		if row[4] is PackedVector3Array:
			for point: Vector3 in row[4]:
				path.append(here * point)
		if lash.is_empty():
			if path.size() < 2:
				continue          # まだ知らないロープの、長さだけの知らせ（全部の知らせが別に届く）
			lash = _make_lash(id, int(row[5]) if row.size() > 5 else 0)
			(lash["cord"] as Node3D).lay(path, float(row[3]))
		elif path.size() >= 2 and (int(lash["a"]) != int(row[1]) or int(lash["b"]) != int(row[2]) or _off_shape(lash["cord"], path)):
			# 結び替わった・切れた・形が大きくずれた：ホストの道すじに合わせる
			(lash["cord"] as Node3D).lay(path, float(row[3]))
		lash["a"] = int(row[1])
		lash["b"] = int(row[2])
		_pin(lash)
		(lash["cord"] as Node3D).set_length(float(row[3]))
	if full:
		for id: int in lashes.keys():
			if not seen.has(id):
				_drop_lash(id)
		_next_lash = maxi(_next_lash, int(data.get("next", _next_lash)))


# 自分の画面のロープが、ホストの道すじから大きく離れているか
func _off_shape(cord: Node3D, path: PackedVector3Array) -> bool:
	for point: Vector3 in path:
		var near := INF
		for mine: Vector3 in cord.pts:
			near = minf(near, mine.distance_squared_to(point))
		if near > 0.16:
			return true
	return false


# ---- 見た目 ----


# フックの目印と、狙っている所の輪（制作班にだけ見える）。束を持っている間は、全部のフックに小さな輪が出る
func _show_marks(me: Node3D) -> void:
	var truck: RigidBody3D = game.truck
	var bk: Node = kit._bk()
	# 束の残りは、束の太さで分かる（使うほど細くなる）
	if bk != null and not is_equal_approx(float(bk.stock), _coil_shown):
		_coil_shown = float(bk.stock)
		bk._show_coil()
	var act: Dictionary = kit.f_action(me) if me != null and not game.ui_blocking() else {}
	var holding: bool = me != null and me.held != 0 and reels.is_coil(game.props.get(me.held)) and not act.is_empty()
	while _hook_marks.size() < truck.hooks.size():
		var dot := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.05
		ring.outer_radius = 0.07
		ring.rings = 12
		ring.ring_segments = 6
		dot.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1.0, 0.95, 0.6, 0.45)
		mat.no_depth_test = true
		dot.material_override = mat
		dot.layers = FilmCamera.CREW_LAYER
		dot.visible = false
		kit.add_child(dot)
		_hook_marks.append(dot)
	var cam: Camera3D = kit.get_viewport().get_camera_3d()
	for i in _hook_marks.size():
		var dot: MeshInstance3D = _hook_marks[i]
		dot.visible = holding and i < truck.hooks.size()
		if dot.visible:
			dot.global_position = hook_at(i)
			_face(dot, cam)
	if _aim_mark == null:
		_aim_mark = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.075
		ring.outer_radius = 0.1
		ring.rings = 14
		ring.ring_segments = 6
		_aim_mark.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.95, 0.6)
		mat.no_depth_test = true
		_aim_mark.material_override = mat
		_aim_mark.layers = FilmCamera.CREW_LAYER
		kit.add_child(_aim_mark)
	_aim_mark.visible = act.has("point")
	if _aim_mark.visible:
		_aim_mark.global_position = act["point"]
		_face(_aim_mark, cam)


func _face(mark: MeshInstance3D, cam: Camera3D) -> void:
	if cam != null and cam.global_position.distance_to(mark.global_position) > 0.05:
		mark.look_at(cam.global_position, Vector3.UP)
		mark.rotate_object_local(Vector3.RIGHT, PI * 0.5)


# ---- 操作（F）と画面の案内 ----


# 視線の先のフック（番号）。無ければ -1
func aim_hook(me: Node) -> int:
	var view: Array = kit._view(me)
	if view.is_empty():
		return -1
	var from: Vector3 = view[0]
	var dir: Vector3 = view[1]
	var best := -1
	var best_off := INF
	for i in game.truck.hooks.size():
		var p := hook_at(i)
		var along := (p - from).dot(dir)
		if along < 0.2 or p.distance_to(me.global_position + Vector3(0, 1.0, 0)) > game.Player.REACH + 1.0:
			continue
		var off := (p - from - dir * along).length()
		if off <= HOOK_AIM + 0.03 * along and off < best_off:
			best = i
			best_off = off
	return best


# 視線の先の、掛けたロープの上の場所。{"lash": 番号, "s": 根元からの道のり, "point": その点, "off": 視線からの離れ}。無ければ {}
func aim_lash(me: Node, aim: float) -> Dictionary:
	var view: Array = kit._view(me)
	if view.is_empty():
		return {}
	var best := {}
	for id: int in lashes:
		var cord: Node3D = lashes[id]["cord"]
		var hit: Dictionary = cord.nearest_to_ray(view[0], view[1])
		if hit.is_empty() or float(hit["off"]) > aim + 0.02 * float(hit["along"]):
			continue
		if (hit["point"] as Vector3).distance_to(me.global_position + Vector3(0, 1.0, 0)) > game.Player.REACH + 0.6:
			continue
		if best.is_empty() or float(hit["off"]) < float(best["off"]):
			best = hit
			best["lash"] = id
	return best


# そのフックに結んであるロープ（いちばん新しい物の番号）。無ければ 0
func _lash_on_hook(index: int) -> int:
	var found := 0
	for id: int in lashes:
		if int(lashes[id]["a"]) == index or int(lashes[id]["b"]) == index:
			found = maxi(found, id)
	return found


# ---- cargo_kit.gd から呼ばれる入口 ----


# フックの場所の印（軽トラの「前の位置」に置く。上の _truck_xf の説明）
func make_frame() -> void:
	_frame = Node3D.new()
	_frame.name = "LashFrame"
	_frame.top_level = true
	kit.add_child(_frame)


# 毎コマ（全員の画面）。ホストで、見返しの最中でなければ true を返す（cargo_kit.gd が、続けて箱のホストの処理をする）
func physics(delta: float) -> bool:
	# このコマで軽トラが進む速さ（軽トラは、もう次の位置に置かれている）
	var now: Transform3D = game.truck.global_transform
	_truck_vel = Vector3.ZERO
	if _truck_seen and now.origin.distance_to(_truck_xf.origin) < 2.0:
		_truck_vel = (now.origin - _truck_xf.origin) / maxf(delta, 0.0001)
	# ロープの形は、全員がそれぞれの画面で計算する（物理の世界と同じ、前の位置のままで）
	_wake_lashes()
	for lash: Dictionary in lashes.values():
		var cord: Node3D = lash["cord"]
		if int(lash["b"]) == END_COIL:
			cord.b_local = reels._coil_exit(int(lash.get("coil", 0)))
		var awake: bool = not cord.asleep
		cord.step(delta)
		if awake:
			_unbury(cord)
			if int(lash["b"]) != END_COIL:
				_straighten(cord)
		# 張ったロープは、角の所で小さく揺れ続けることがある。停まっている間は、数秒たったら止める
		# （荷台の物が動く・切られる・ゆるむ、で、また動き出す）
		lash["awake"] = int(lash.get("awake", 0)) + 1 if awake else 0
		if int(lash["awake"]) > 240 and flow.phase != 3 and int(lash["b"]) != END_COIL and (cord.speed() < 1.5 or int(lash["awake"]) > 480):
			cord.asleep = true
			cord.old = cord.pts.duplicate()
	var host: bool = Net.is_host() and not game.replaying
	if host:
		_host_lashes(delta)
	_carry_lashes()
	return host


# 掛けたロープを、全部外してから、受け取った一覧で作り直す（見返しが終わったとき）
func rebuild(data: Dictionary) -> void:
	for id: int in lashes.keys():
		_drop_lash(id)
	_apply_lashes(data, true)
	_eval_in = 0


# F：束を持っている。フックを見ていれば結ぶ・外す、掛けたロープを見ていればほどく
func act_with_coil(me: Node, held: Node3D) -> Dictionary:
	var bk: Node = kit._bk()
	# 爆弾を見ている：口金につなぐ（導火線になる。bomb_kit.gd）
	if bk != null and bk.wants_rope(me):
		return {}
	var hook := aim_hook(me)
	if hook >= 0:
		var open := open_lash(reels.coil_id(held))
		if not open.is_empty() and int(open["a"]) == hook:
			return {"do": "unhook", "hook": hook, "point": hook_at(hook)}
		return {"do": "hook", "hook": hook, "point": hook_at(hook)}
	var line := aim_lash(me, ROPE_AIM)
	if not line.is_empty():
		line["do"] = "untie"
		return line
	return {"do": "rope", "own": reels.coil_id(held) != 0}


# F：はさみを持っている。掛けたロープを見ていれば、切る
func act_with_scissors(me: Node) -> Dictionary:
	var snip := aim_lash(me, CUT_AIM)
	if snip.is_empty():
		return {}
	snip["do"] = "cut"
	return snip


# F：手ぶら。掛けたロープ（または、ロープを結んだフック）を見ていれば、ほどく。見ていなければ {}
func act_free(me: Node, target: Node3D) -> Dictionary:
	if not lashes.is_empty():
		var line := aim_lash(me, ROPE_AIM)
		if not line.is_empty():
			line["do"] = "untie"
			return line
		var hook := aim_hook(me)
		if hook >= 0 and _lash_on_hook(hook) != 0 and (target == null or target.kind == "truck"):
			return {"do": "untie", "lash": _lash_on_hook(hook), "point": hook_at(hook)}
	return {}


# 画面の案内（ロープの側）。act＝cargo_kit.gd の f_action の結果、put＝手に持った物の置き方の案内。out に足す。
# ロープは、動作だけを書く（長さ・本数・押さえの強さは書かない。ゲームの中の見た目で判断する）
func hud_for(act: Dictionary, put: String, out: Dictionary) -> void:
	match str(act["do"]):
		"rope":
			out["keys_all"] = ("フックを見て F 結ぶ" if bool(act.get("own", false)) else "フックを見て F 結ぶ ／ 爆弾の口を見て F つなぐ") + put
		"hook":
			out["label"] = "フック"
			out["keys_all"] = "F フックに結ぶ" + put
		"unhook":
			out["label"] = "フック"
			out["keys_all"] = "F ほどく" + put
		"untie":
			out["label"] = "ロープ"
			out["keys_all"] = "F ほどく" + put
		"cut":
			out["label"] = "ロープ"
			out["keys_all"] = "F 切る" + put
