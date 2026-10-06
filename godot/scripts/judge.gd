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
	re_acc = 0.0
	re_at = -1.0
	re_window = 0.0
	why = [{}, {}, {}]


func passed() -> Array:
	return [conf_at >= 0.0, boom_at >= 0.0, re_at >= 0.0]


# ---- いまの画面の見え方 ----

func look() -> Dictionary:
	var film: Node3D = game.film
	var cam: Camera3D = film.view_cam
	var vs := Vector2(film.view.size)
	var space := film.get_world_3d().direct_space_state
	var cam_pos: Vector3 = cam.global_position
	var fwd: Vector3 = -cam.global_basis.z
	var out := {"actors": [], "castle": false, "castle_back": false, "height": false, "close": false,
		"fx_in": false, "fx_behind": false, "moon": false}

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
		}
		d["shown"] = d["in"] and d["seen"] and d["size"]          # 明るさを問わず映っている
		d["vis"] = d["shown"] and d["lit"]
		(out["actors"] as Array).append(d)

	for p: Node3D in game.props.values():
		if p.absent:
			continue
		if "castle" in p.tags:
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
		elif "moon" in p.tags:
			if _in_frame(cam, vs, p.center_global()):
				out["moon"] = true

	var a0: CharacterBody3D = game.actors[0]
	var a1: CharacterBody3D = game.actors[1]
	var dv := a0.global_position - a1.global_position
	out["height"] = absf(dv.y) >= MIN_HEIGHT_DIFF
	out["close"] = Vector2(dv.x, dv.z).length() < 1.45 and absf(dv.y) < 0.6

	var recent: bool = boom_t0 >= 0.0 and t - boom_t0 <= BOOM_WINDOW
	var bp: Variant = boom_pos if recent else game.boom_point()
	out["fx_none"] = bp == null
	if bp != null:
		var fx_pos: Vector3 = bp
		out["fx_in"] = _in_frame(cam, vs, fx_pos)
		var fx_depth := (fx_pos - cam_pos).dot(fwd)
		var acts: Array = out["actors"]
		out["fx_behind"] = fx_depth > maxf(acts[0]["depth"], acts[1]["depth"]) + 0.2
	return out


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
	return sum


# いまの画面で、告白を撮るのに足りないこと
func problems(f: Dictionary, need_light: bool = true) -> Array:
	var out: Array = []
	var acts: Array = f["actors"]
	for i in 2:
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


func setup_problems(f: Dictionary) -> Array:
	var out := problems(f)
	if not f["castle"]:
		out.append("城の裏面が映っている（塗った面をカメラへ）" if f["castle_back"] else "城のセットが画面に映っていない")
	if not f["height"]:
		out.append("高低差が足りない（片方を高い所へ）")
	if f.get("fx_none", false):
		out.append("爆発の手段がない（効果機か、爆炎の書割を置く）")
	elif not f["fx_in"]:
		out.append("爆発（効果機か書割）が画面に入っていない")
	elif not f["fx_behind"]:
		out.append("爆発が二人より手前にある（奥へ置く）")
	return out


func _note(i: int, reasons: Array, dt: float) -> void:
	for r: String in reasons:
		why[i][r] = float(why[i].get(r, 0.0)) + dt


# ---- 本番中の集計 ----

func tick(dt: float) -> void:
	frame = look()
	var acts: Array = frame["actors"]
	var both: bool = acts[0]["vis"] and acts[1]["vis"]
	var both_shown: bool = acts[0]["shown"] and acts[1]["shown"]

	if conf_at < 0.0 and game.actors[0].is_confessing() and game.actors[1].is_confessing():
		conf_window += dt
		var r := problems(frame)
		if not frame["castle"]:
			r.append("城の裏面が映っていた" if frame["castle_back"] else "城のセットが映っていなかった")
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
		if r3.is_empty() and both:
			re_acc += dt
			if re_acc >= NEED_REUNION:
				re_at = t
				game.host_condition_met(2)
		elif t - boom_at > 1.5:
			_note(2, r3, dt)
	t += dt


# 効果機が鳴った。告白が撮れる前なら、順序違いで数えない
func on_burst(pos: Vector3) -> bool:
	boom_count += 1
	if conf_at < 0.0:
		boom_early = true
		return false
	if boom_at < 0.0:
		boom_t0 = t
		boom_acc = 0.0
		boom_pos = pos
	return true


func _top_reason(i: int) -> String:
	var best := ""
	var best_t := 0.0
	for k: String in why[i]:
		if float(why[i][k]) > best_t:
			best_t = why[i][k]
			best = k
	return best


func results() -> Array:
	var out: Array = []
	# 告白
	var d0 := ""
	if conf_at >= 0.0:
		d0 = "%.1f秒で成立" % conf_at
	elif conf_window <= 0.0:
		d0 = "告白の合図（1）が出されなかった"
	else:
		d0 = _top_reason(0)
	out.append({"ok": conf_at >= 0.0, "title": TITLES[0], "detail": d0, "at": conf_at})
	# 爆発
	var d1 := ""
	if boom_at >= 0.0:
		d1 = "%.1f秒で成立" % boom_at
	elif boom_count == 0:
		d1 = "爆発の合図（2）が出されなかった"
	elif boom_t0 < 0.0:
		d1 = "告白が撮れる前に爆発した（順序が違う）"
	else:
		d1 = _top_reason(1)
		if d1 == "":
			d1 = "爆発と二人が同時に映る時間が足りなかった"
	out.append({"ok": boom_at >= 0.0, "title": TITLES[1], "detail": d1, "at": boom_at})
	# 再会
	var d2 := ""
	if re_at >= 0.0:
		d2 = "%.1f秒で成立" % re_at
	elif boom_at < 0.0:
		d2 = "爆発が成立していない（順序）"
	else:
		d2 = _top_reason(2)
		if d2 == "":
			d2 = "再会の合図（3）が出されなかった" if not game.reunion_cued else "再会が映る時間が足りなかった"
	out.append({"ok": re_at >= 0.0, "title": TITLES[2], "detail": d2, "at": re_at})
	return out
