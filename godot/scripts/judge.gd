extends RefCounted
# 「カメラに映ったこと」で注文を確かめる。ホストだけが計算する。
# いまは当たり判定への光線と計算上の明るさで見ている（実映像の画素は読んでいない）。

const NEED_CONFESS := 2.5     # 告白が条件つきで映っている必要秒数
const NEED_BOOM := 0.5
const NEED_REUNION := 1.5
const BOOM_WINDOW := 1.6
const MIN_SIZE := 0.10        # 画面の高さに対する役者の大きさ
const MIN_LIGHT := 0.30
const MIN_HEIGHT_DIFF := 0.55
const MARGIN := 0.03

const TITLES := ["バルコニー越しの告白", "二人の背後で大爆発", "爆発のあとの再会"]
# 脚本ごとの3場面。castle=月下の城、kaiju=怪獣映画（遠近法で小さな怪獣を巨大に見せる）
const SCRIPT_TITLES := {
	"castle": ["バルコニー越しの告白", "二人の背後で大爆発", "爆発のあとの再会"],
	"kaiju": ["怪獣が街より大きく映る", "逃げる二人の背後で大爆発", "倒れた怪獣の前で勝利"],
}
const MONSTER_KINDS := ["tomato_monster", "dragon_skull"]
const CITY_KINDS := ["carton", "applebox"]
const MIN_MONSTER := 0.35     # 画面の高さに対する怪獣の大きさ
const MIN_CITY := 2           # 映っている「街」の数

var story := "castle"
# 場面の列を持つ依頼（production_beats.gd）のときは、3条件の代わりに、そちらが場面ごとに数える。
# 画面の見え方（look・problems・kaiju_problems）は、どちらも同じ物を使う。無ければ、今までの3条件
var beats: Variant = null

var game: Node
var t := 0.0
var frame: Dictionary = {}

var conf_acc := 0.0
var conf_at := -1.0
var conf_window := 0.0
var boom_acc := 0.0
var boom_at := -1.0
var boom_t0 := -1.0
var boom_pos := Vector3.ZERO
var boom_early := false
var boom_count := 0
var boom_src := 0                 # 数えた爆発を出した物（爆弾・書割・爆発役の物）
var boom_power := 0               # 数えた爆発が爆弾なら、入っていた火薬の量の段階（1〜3。fx_box.gd の stage_of）
var re_acc := 0.0
var re_at := -1.0
var re_window := 0.0
var why: Array = [{}, {}, {}]     # 条件ごとの「足りなかった理由」と秒数


func reset() -> void:
	t = 0.0
	conf_acc = 0.0
	conf_at = -1.0
	conf_window = 0.0
	boom_acc = 0.0
	boom_at = -1.0
	boom_t0 = -1.0
	boom_early = false
	boom_count = 0
	boom_src = 0
	boom_power = 0
	re_acc = 0.0
	re_at = -1.0
	re_window = 0.0
	why = [{}, {}, {}]
	if beats != null:
		beats.judge_reset()


func passed() -> Array:
	if beats != null:
		return beats.passed()
	return [conf_at >= 0.0, boom_at >= 0.0, re_at >= 0.0]


# その物が、いまの台本で何の役か（""＝役なし）。
# 制作モードでは自分たちで決めた見立て（production_flow.casting）を優先する。撮影だけモードは物の印で決まる
func role_of(p: Node) -> String:
	var flow: Variant = game.get("production")
	if flow != null:
		# 会社に置いてきた物は、現場では数えない
		return flow.role_of(p) if flow.on_set(p) else ""
	if "castle" in p.tags:
		return "castle"
	if "moon" in p.tags:
		return "moon"
	if "monster" in p.tags or p.kind in MONSTER_KINDS:
		return "monster"
	if "city" in p.tags or p.kind in CITY_KINDS:
		return "city"
	if "boom" in p.tags:
		return "boom"
	return ""


# 役を自分たちで決められるとき（制作モード）だけ、案内に操作を添える
func _cast_tip() -> String:
	return "（物を見て Y で役を決める）" if game.get("production") != null else ""


# ---- いまの画面の見え方 ----

func look() -> Dictionary:
	var film: Node3D = game.program_camera()
	var cam: Camera3D = film.view_cam
	var vs := Vector2(film.view.size)
	var space := film.get_world_3d().direct_space_state
	var cam_pos: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_basis.z
	var out := {"actors": [], "castle": false, "castle_back": false, "castle_any": false, "height": false, "close": false,
		"fx_in": false, "fx_behind": false, "moon": false, "city_pids": [], "monster_peek": false,
		"monster": {"exists": false, "in": false, "seen": false, "up": false, "size": 0.0, "pid": 0},
		"monster_down": false, "city_n": 0, "city_max": 0.0, "roles_in": {}, "present": []}

	for a: CharacterBody3D in game.actors:
		var head: Vector3 = a.head_pos()
		var pts: Array = [head, a.chest_pos(), a.global_position + Vector3(0, 0.35, 0)]
		var n_in := 0
		var n_seen := 0
		for p: Vector3 in pts:
			if _in_frame(cam, vs, p):
				n_in += 1
				if not _blocked(space, cam_pos, p, [film.get_rid()]):
					n_seen += 1
		var top := cam.unproject_position(head + Vector3(0, 0.2, 0))
		var bottom := cam.unproject_position(a.global_position)
		var size := absf(bottom.y - top.y) / vs.y
		var light := brightness(space, head)
		var d := {
			"in": n_in >= 2,
			"seen": n_seen >= 2,
			"size": size >= MIN_SIZE,
			"lit": light >= MIN_LIGHT,
			"depth": (a.chest_pos() - cam_pos).dot(fwd),
			# 画面の高さに対する、身長の大きさ（寄りの見分けに使う。動きで頭が上下しても変わらない）
			"h": absf(bottom.y - cam.unproject_position(a.global_position + Vector3(0, a.vis.height, 0)).y) / vs.y,
		}
		d["shown"] = d["in"] and d["seen"] and d["size"]          # 明るさを問わず映っている
		d["vis"] = d["shown"] and d["lit"]
		(out["actors"] as Array).append(d)
		# 出ている役者：この台本の人数の中で、誰かが演じている役（数えるのは、この役者たちだけ）
		if (a in beats.present()) if beats != null else (int(a.aid) < 2 and a.present()):
			(out["present"] as Array).append(int(a.aid))

	for p: Node3D in game.props.values():
		if p.absent:
			continue
		var role := role_of(p)
		if role == "":
			continue
		if story == "kaiju":
			_look_kaiju(out, p, role, cam, vs, space, cam_pos)
		# どの役の物が映っているか（場面の列の「show」の role で見る。真ん中か上のほうが画面に入り、さえぎられていない）
		var mid: Vector3 = p.center_global()
		var high: Vector3 = p.global_transform * (p.center + Vector3(0, p.half.y * 0.7, 0))
		for look: Vector3 in [mid, high]:
			if _in_frame(cam, vs, look) and not _blocked(space, cam_pos, look, [film.get_rid(), p.get_rid()]):
				out["roles_in"][role] = true
				break
		if role == "castle":
			out["castle_any"] = true
			var c: Vector3 = p.center_global()
			var top_p: Vector3 = p.global_transform * (p.center + Vector3(0, p.half.y * 0.7, 0))
			if not (_in_frame(cam, vs, c) or _in_frame(cam, vs, top_p)):
				continue
			if _blocked(space, cam_pos, c, [film.get_rid(), p.get_rid()]) and _blocked(space, cam_pos, top_p, [film.get_rid(), p.get_rid()]):
				continue
			if p.global_basis.y.dot(Vector3.UP) < 0.6:
				continue        # 倒れている
			if p.one_sided and p.global_basis.z.dot(cam_pos - c) <= 0.0:
				out["castle_back"] = true
				continue
			out["castle"] = true
		elif role == "moon":
			if _in_frame(cam, vs, p.center_global()):
				out["moon"] = true

	# 高低差：出ている役者のいちばん高い人と低い人。寄り集まる：どの役者も、いちばん近い相手が 1.45m より近く、高さもそろう
	var here: Array = (out["present"] as Array).map(func(k: int) -> Node3D: return game.actors[k])
	var ys: Array = here.map(func(a: Node3D) -> float: return a.global_position.y)
	out["height"] = ys.size() >= 2 and float(ys.max()) - float(ys.min()) >= MIN_HEIGHT_DIFF
	var close := here.size() >= 2
	for a: Node3D in here:
		var near := INF
		for b: Node3D in here:
			if b != a:
				near = minf(near, Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length())
		close = close and near < 1.45
	out["close"] = close and (ys.is_empty() or float(ys.max()) - float(ys.min()) < 0.6)

	var recent: bool = boom_t0 >= 0.0 and t - boom_t0 <= BOOM_WINDOW
	var bp: Variant = boom_pos if recent else game.boom_point()
	out["fx_none"] = bp == null
	if bp != null:
		var fx_pos: Vector3 = bp
		out["fx_in"] = _in_frame(cam, vs, fx_pos)
		var fx_depth := (fx_pos - cam_pos).dot(fwd)
		var acts: Array = out["actors"]
		var deepest := -INF
		for k: int in out["present"]:
			deepest = maxf(deepest, float(acts[k]["depth"]))
		out["fx_behind"] = fx_depth > deepest + 0.2
	return out


# 怪獣映画：怪獣と「街」の映り方を数える
func _look_kaiju(out: Dictionary, p: Node3D, role: String, cam: Camera3D, vs: Vector2, space: PhysicsDirectSpaceState3D, cam_pos: Vector3) -> void:
	var is_monster: bool = role == "monster"
	var is_city: bool = role == "city"
	if not (is_monster or is_city):
		return
	var pc: Vector3 = p.center_global()
	var shown: bool = _in_frame(cam, vs, pc)
	var clear: bool = shown and not _blocked(space, cam_pos, pc, [game.program_camera().get_rid(), p.get_rid()])
	var up_axis: Vector3 = p.global_basis.y.normalized()
	var psize := 0.0
	if not cam.is_position_behind(pc):
		psize = cam.unproject_position(pc + up_axis * p.half.y).distance_to(cam.unproject_position(pc - up_axis * p.half.y)) / vs.y
	if is_monster:
		# 少しでも見えているか（真ん中・上下・左右のどこかが、画面の中にあって隠れていない）。「まだ映さない」場面で使う
		var side: Vector3 = p.global_basis.x.normalized() * p.half.x * 0.7
		for at: Vector3 in [pc, pc + up_axis * p.half.y * 0.7, pc - up_axis * p.half.y * 0.7, pc + side, pc - side]:
			if _in_frame(cam, vs, at) and not _blocked(space, cam_pos, at, [game.program_camera().get_rid(), p.get_rid()]):
				out["monster_peek"] = true
		var m: Dictionary = out["monster"]
		var upright: bool = up_axis.y >= 0.6
		if not upright and clear:
			out["monster_down"] = true
		# いちばん大きく映っている、立っている怪獣を主役にする
		var better: bool = upright and clear and (not (m["up"] and m["seen"]) or psize > float(m["size"]))
		if not m["exists"] or better:
			out["monster"] = {"exists": true, "in": shown, "seen": clear, "up": upright, "size": psize, "pid": p.pid}
	elif clear:
		(out["city_pids"] as Array).append(p.pid)
		out["city_n"] = int(out["city_n"]) + 1
		out["city_max"] = maxf(out["city_max"], psize)


func _in_frame(cam: Camera3D, vs: Vector2, p: Vector3) -> bool:
	if cam.is_position_behind(p):
		return false
	var s := cam.unproject_position(p) / vs
	return s.x > MARGIN and s.x < 1.0 - MARGIN and s.y > MARGIN and s.y < 1.0 - MARGIN


func _blocked(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	var ex: Array[RID] = []
	for r: RID in exclude:
		ex.append(r)
	q.exclude = ex
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and (hit.position as Vector3).distance_to(to) > 0.15


func brightness(space: PhysicsDirectSpaceState3D, p: Vector3) -> float:
	var sum := 0.05
	for rig: Node3D in game.spots:
		if rig.level <= 0:
			continue
		var o: Vector3 = rig.beam_origin()
		var to := p - o
		var d := to.length()
		if d > rig.RANGE or d < 0.01:
			continue
		var ang := rad_to_deg((rig.beam_dir() as Vector3).angle_to(to))
		var cone := 1.0 - smoothstep(rig.ANGLE * 0.8, rig.ANGLE, ang)
		if cone <= 0.0:
			continue
		if _blocked(space, o, p, [rig.get_rid()]):
			continue
		sum += float(rig.FACTOR[rig.level]) * cone / (1.0 + pow(d / 6.0, 2.0))
	for m: Node3D in game.moons:
		var dm: float = (m.center_global() as Vector3).distance_to(p)
		sum += 0.22 * clampf(1.0 - dm / 5.0, 0.0, 1.0)
	# キャラの特技：ランプを点けたロボットが、向いた先だけを弱く照らす（これだけでは基準に届かない）
	var talent: Variant = game.get("talent")
	if talent != null:
		sum += float(talent.lamp_light(space, p))
	return sum


# いまの画面で、告白を撮るのに足りないこと
func problems(f: Dictionary, need_light: bool = true) -> Array:
	var out: Array = []
	var acts: Array = f["actors"]
	for i: int in f.get("present", [0, 1]):
		var d: Dictionary = acts[i]
		var n: String = game.actors[i].label
		if not d["in"]:
			out.append("%sが画面に入っていない" % n)
		elif not d["seen"]:
			out.append("%sが物に隠れている" % n)
		elif not d["size"]:
			out.append("%sが小さすぎる（寄るかズーム）" % n)
		elif need_light and not d["lit"]:
			out.append("%sの顔が暗い（ライトを当てる）" % n)
	return out


# この台本の役者の人数（場面の列のある依頼は台本の "cast"。無ければ二人）
func cast_count() -> int:
	return int(beats.cast_count()) if beats != null else 2


# 出ている役者のうち、画面の中でいちばん小さく映っている人の大きさ（寄りの見分けに使う）
func min_h(f: Dictionary) -> float:
	var acts: Array = f["actors"]
	var out := INF
	for k: int in f.get("present", [0, 1]):
		out = minf(out, float(acts[k]["h"]))
	return out if out < INF else 0.0


# 怪獣映画：最初の場面に足りないこと
func kaiju_problems(f: Dictionary) -> Array:
	var out: Array = []
	var m: Dictionary = f["monster"]
	if not m["exists"]:
		out.append("怪獣役の物が無い" + _cast_tip())
	elif not m["in"]:
		out.append("怪獣が画面に入っていない")
	elif not m["seen"]:
		out.append("怪獣が物に隠れている")
	elif not m["up"]:
		out.append("怪獣が倒れている（まだ立たせておく）")
	elif float(m["size"]) < MIN_MONSTER:
		out.append("怪獣が小さい（カメラのすぐ手前へ置く）")
	if int(f["city_n"]) < MIN_CITY:
		out.append("街役の物が%dつ以上映っていない" % MIN_CITY)
	elif m["exists"] and m["up"] and float(m["size"]) >= MIN_MONSTER and float(m["size"]) <= float(f["city_max"]) * 1.2:
		out.append("怪獣が街より小さく見える（街を奥へ、怪獣を手前へ）")
	return out


func setup_problems(f: Dictionary) -> Array:
	if beats != null:
		return []          # 場面の列を持つ依頼では、準備中に答えを出さない（モニターの絵を見て、班が決める）
	var out := problems(f)
	if story == "kaiju":
		out.append_array(kaiju_problems(f))
		if f.get("fx_none", false):
			out.append(_no_boom())
		elif not f["fx_in"]:
			out.append("爆発（怪獣の技）が画面に入っていない")
		elif not f["fx_behind"]:
			out.append("爆発が二人より手前にある（奥へ置く）")
		return out
	if not f["castle"]:
		if f["castle_back"]:
			out.append("城の裏面が映っている（塗った面をカメラへ）")
		elif not f["castle_any"]:
			out.append("城役の物が無い" + _cast_tip())
		else:
			out.append("城役の物が画面に映っていない")
	if not f["height"]:
		out.append("高低差が足りない（片方を高い所へ）")
	if f.get("fx_none", false):
		out.append(_no_boom())
	elif not f["fx_in"]:
		out.append("爆発が画面に入っていない")
	elif not f["fx_behind"]:
		out.append("爆発が二人より手前にある（奥へ置く）")
	return out


func _no_boom() -> String:
	if game.get("production") != null:
		return "爆発の手段がない（火薬の入った爆弾・爆炎の書割・Y で爆発役にした物）"
	return "爆発の手段がない（爆弾か、爆炎の書割を置く）"


func _note(i: int, reasons: Array, dt: float) -> void:
	for r: String in reasons:
		why[i][r] = float(why[i].get(r, 0.0)) + dt


# ---- 本番中の集計 ----

func tick(dt: float) -> void:
	frame = look()
	if beats != null:
		beats.judge_tick(dt, frame)
		t += dt
		return
	var acts: Array = frame["actors"]
	var both: bool = acts[0]["vis"] and acts[1]["vis"]
	var both_shown: bool = acts[0]["shown"] and acts[1]["shown"]

	if conf_at < 0.0 and game.actors[0].is_confessing() and game.actors[1].is_confessing():
		conf_window += dt
		var r := problems(frame)
		if story == "kaiju":
			r.append_array(kaiju_problems(frame))
		else:
			if not frame["castle"]:
				r.append("城の裏面が映っていた" if frame["castle_back"] else "城役の物が映っていなかった")
			if not frame["height"]:
				r.append("二人の高低差が足りなかった")
		if r.is_empty():
			conf_acc += dt
			if conf_acc >= NEED_CONFESS:
				conf_at = t
				game.host_condition_met(0)
		else:
			_note(0, r, dt)

	if boom_at < 0.0 and boom_t0 >= 0.0 and t - boom_t0 <= BOOM_WINDOW:
		var r2 := problems(frame, false)
		if not frame["fx_in"]:
			r2.append("爆発が画面に入っていなかった")
		elif not frame["fx_behind"]:
			r2.append("爆発が二人より手前だった")
		if r2.is_empty() and both_shown:
			boom_acc += dt
			if boom_acc >= NEED_BOOM:
				boom_at = t
				game.host_condition_met(1)
		else:
			_note(1, r2, dt)

	if boom_at >= 0.0 and re_at < 0.0:
		re_window += dt
		var r3 := problems(frame)
		if not frame["close"]:
			r3.append("二人が近づいていなかった")
		if story == "kaiju" and not frame["monster_down"]:
			r3.append("倒れた怪獣が映っていなかった（爆発のあと、誰かが倒す）")
		if r3.is_empty() and both:
			re_acc += dt
			if re_acc >= NEED_REUNION:
				re_at = t
				game.host_condition_met(2)
		elif t - boom_at > 1.5:
			_note(2, r3, dt)
	t += dt


# 爆発が起きた。告白が撮れる前なら、順序違いで数えない
func on_burst(pos: Vector3, src: int = 0) -> bool:
	boom_count += 1
	if beats != null:
		return beats.on_burst(pos, src)
	if conf_at < 0.0:
		boom_early = true
		return false
	if boom_at < 0.0:
		boom_t0 = t
		boom_acc = 0.0
		boom_pos = pos
		boom_src = src
	return true


func _top_reason(i: int) -> String:
	var best := ""
	var best_t := 0.0
	for k: String in why[i]:
		if float(why[i][k]) > best_t:
			best_t = why[i][k]
			best = k
	return best


func titles() -> Array:
	return SCRIPT_TITLES.get(story, TITLES)


# 本番中の案内（次に何をすればいいか）
func take_hints(reunion_cued: bool) -> Array:
	if beats != null:
		return []
	var h: Array = []
	var ok: Array = passed()
	var kaiju: bool = story == "kaiju"
	if not ok[0]:
		h = problems(frame)
		if kaiju:
			h.append_array(kaiju_problems(frame))
		else:
			if not frame["castle"]:
				h.append("城役の物が映っていない")
			if not frame["height"]:
				h.append("高低差が足りない")
		if h.is_empty() and not game.actors[0].is_confessing():
			h.append("[1] で怪獣に驚く合図" if kaiju else "[1] で告白の合図")
	elif not ok[1]:
		h = problems(frame, false)
		if not frame["fx_in"]:
			h.append("爆発（爆弾・書割）が画面に入っていない")
		elif not frame["fx_behind"]:
			h.append("爆発が二人より手前にある")
		if h.is_empty():
			h.append("[2] で爆発の合図")
	elif not ok[2]:
		h = problems(frame)
		if kaiju and not frame["monster_down"]:
			h.append("怪獣を倒す（映らないようにこっそり）")
		if not reunion_cued:
			h.append("[3] で勝利の合図" if kaiju else "[3] で再会の合図")
	return h


func results() -> Array:
	if beats != null:
		return beats.results()
	var out: Array = []
	var tt: Array = titles()
	var kaiju: bool = story == "kaiju"
	# 告白
	var d0 := ""
	if conf_at >= 0.0:
		d0 = "%.1f秒で成立" % conf_at
	elif conf_window <= 0.0:
		d0 = "驚きの合図（1）が出されなかった" if kaiju else "告白の合図（1）が出されなかった"
	else:
		d0 = _top_reason(0)
	out.append({"ok": conf_at >= 0.0, "title": tt[0], "detail": d0, "at": conf_at})
	# 爆発
	var d1 := ""
	if boom_at >= 0.0:
		d1 = "%.1f秒で成立" % boom_at
	elif boom_count == 0:
		d1 = "爆発の合図（2）が出されなかった"
	elif boom_t0 < 0.0:
		d1 = "怪獣が映る前に爆発した（順序が違う）" if kaiju else "告白が撮れる前に爆発した（順序が違う）"
	else:
		d1 = _top_reason(1)
		if d1 == "":
			d1 = "爆発と二人が同時に映る時間が足りなかった"
	out.append({"ok": boom_at >= 0.0, "title": tt[1], "detail": d1, "at": boom_at})
	# 再会
	var d2 := ""
	if re_at >= 0.0:
		d2 = "%.1f秒で成立" % re_at
	elif boom_at < 0.0:
		d2 = "爆発が成立していない（順序）"
	else:
		d2 = _top_reason(2)
		if d2 == "":
			if kaiju:
				d2 = "勝利の合図（3）が出されなかった" if not game.reunion_cued else "勝利の場面が映る時間が足りなかった"
			else:
				d2 = "再会の合図（3）が出されなかった" if not game.reunion_cued else "再会が映る時間が足りなかった"
	out.append({"ok": re_at >= 0.0, "title": tt[2], "detail": d2, "at": re_at})
	return out
