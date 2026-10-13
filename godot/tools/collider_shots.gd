extends SceneTree
# 持てる物の「見た目」と「当たり判定」を重ねて撮り、一覧の画像にまとめる。数値の報告も書き出す。
# 当たり判定の表（scripts/prop_shapes.gd）を直したら、これで撮って見比べる（表はそのままゲームの物に使われる）。
#   画像つき（窓は画面の外へ出す）：
#     godot --path godot --position -32000,-32000 --audio-driver Dummy --script res://tools/collider_shots.gd -- --name=before
#   数値だけ（速い）：
#     godot --headless --path godot --script res://tools/collider_shots.gd -- --name=before
#   物を絞る： -- --only=rock,scrap_arch　　部品ごとの外形も書き出す： -- --parts
#   ひとつのメッシュにまとまった部品を、つながりごとに分けて書き出す： -- --parts=deep（--partmin=0.05 より小さい物は省く）
#   床に置いて放し、動かず・倒れず・震えないことも見る： -- --settle（--fixed-fps 60 を付けると速い）
#   大きく撮る： -- --tile=384 --cols=2 --rows=1
#   段ボール箱を、ふたを閉じた姿で撮る： -- --closed
# 出力：res://tests/shots/colliders/<name>_NN.png（1枚に6種類）、<name>_report.txt、<name>_parts.txt
#
# 画像の見方（1種類につき4コマ）：左上＝前から（右が+X）／右上＝横から（右が-Z）／左下＝上から（上が-Z）／右下＝斜め
#   緑〜青緑＝物にも人にも当たる形　赤紫＝人だけが当たる薄い物（手すり）　黄＝いまは無効の形（開いた箱のふた）
#   水色の線＝center と half の箱（照準や画面での大きさに使う）　白い線＝物の原点の高さ（床）
const Audit := preload("res://tools/collider_audit.gd")
const OUT := "res://tests/shots/colliders/"
var TILE := 256
var COLS := 3
var ROWS := 2
const LABEL_H := 44
const SPACING := 40.0

var _font: Font
var _deep := false
var _part_min := 0.0


func _initialize() -> void:
	run.call_deferred()


func _arg(name: String, fallback: String = "") -> String:
	for a: String in OS.get_cmdline_user_args():
		if a == "--" + name:
			return "1"
		if a.begins_with("--" + name + "="):
			return a.substr(name.length() + 3)
	return fallback


func run() -> void:
	var tag := _arg("name", "shots")
	var only := _arg("only")
	var want_parts := _arg("parts") != ""
	_deep = _arg("parts") == "deep"
	_part_min = float(_arg("partmin", "0.0"))
	var want_settle := _arg("settle") != ""
	TILE = int(_arg("tile", str(TILE)))
	COLS = int(_arg("cols", str(COLS)))
	ROWS = int(_arg("rows", str(ROWS)))
	var headless := DisplayServer.get_name() == "headless"
	_font = load("res://assets/fonts/NotoSansJP-VF.ttf")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	var fixture := Audit.Fixture.new()
	root.add_child(fixture)
	var stage := Audit.new_stage(fixture)
	var kinds: Array[String] = Audit.kinds()
	if only != "":
		var keep: Array[String] = []
		for kind: String in only.split(","):
			if kind in kinds:
				keep.append(kind)
			else:
				print("COLLIDER_SHOTS 知らない種類：", kind)
		kinds = keep
	var bodies: Array = []
	for i in kinds.size():
		var body := Audit.make(stage, kinds[i], Vector3((i % 10) * SPACING, 0.0, (i / 10) * SPACING))
		body.set_fixed(true)
		_quiet(body)
		if kinds[i] == "carton" and _arg("closed") != "":
			body.set("opened", false)
			body.set("open_amount", 0.0)
			body.call("_apply_lids")
		bodies.append(body)
	for i in 4:
		await physics_frame
	await process_frame

	# ---- 数値の報告 ----
	var lines: PackedStringArray = []
	var parts: PackedStringArray = []
	var reports: Array = []
	for i in kinds.size():
		var began := Time.get_ticks_msec()
		var r := Audit.measure(bodies[i])
		r["kind"] = kinds[i]
		r["label"] = String(bodies[i].label)
		r["ms"] = Time.get_ticks_msec() - began
		reports.append(r)
		lines.append(_line(bodies[i], r))
		if want_parts:
			parts.append_array(_parts(bodies[i], kinds[i]))
	for line: String in lines:
		print(line)
	_save_text(OUT + tag + "_report.txt", lines)
	if want_parts:
		_save_text(OUT + tag + "_parts.txt", parts)
	if headless:
		if want_settle:
			await _settle(fixture, kinds, bodies, tag)
		print("COLLIDER_SHOTS_DONE 数値だけ ", kinds.size(), " 種類")
		quit()
		return

	# ---- 画像 ----
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a2c31")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d5dbe6")
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	fixture.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color("fff1dc")
	key.light_energy = 1.3
	key.rotation_degrees = Vector3(-42, 38, 0)
	fixture.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color("b9cdf0")
	fill.light_energy = 0.5
	fill.rotation_degrees = Vector3(-18, -120, 0)
	fixture.add_child(fill)

	var view := SubViewport.new()
	view.size = Vector2i(TILE, TILE)
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.cull_mask = 0xFFFFF & ~(1 << 11)
	view.add_child(cam)
	cam.make_current()

	var sheet := SubViewport.new()
	sheet.size = Vector2i(TILE * 2 * COLS, (TILE * 2 + LABEL_H) * ROWS)
	sheet.disable_3d = true
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)

	var per_page := COLS * ROWS
	var pages := int(ceil(float(kinds.size()) / per_page))
	for page in pages:
		var canvas := Control.new()
		sheet.add_child(canvas)
		var back := ColorRect.new()
		back.color = Color("101114")
		back.size = Vector2(sheet.size)
		canvas.add_child(back)
		for slot in per_page:
			var i := page * per_page + slot
			if i >= kinds.size():
				break
			var body: Node3D = bodies[i]
			var r: Dictionary = reports[i]
			var debug := _debug(body)
			var box: AABB = r["vis"]
			if (r["col"] as AABB).size != Vector3.ZERO:
				box = box.merge(r["col"])
			var c := body.global_position + box.get_center()
			var span := maxf(box.size.x, maxf(box.size.y, box.size.z)) * 1.16 + 0.04
			var far := span * 2.0 + 6.0
			var origin := Vector2((slot % COLS) * TILE * 2, (slot / COLS) * (TILE * 2 + LABEL_H))
			var shots := [
				[Vector3(0, 0, 1), Vector3.UP, span, "前"],
				[Vector3(1, 0, 0), Vector3.UP, span, "横"],
				[Vector3(0, 1, 0), Vector3(0, 0, -1), span, "上"],
				[Vector3(0.62, 0.45, 1.0).normalized(), Vector3.UP, span * 1.18, "斜め"],
			]
			for s in shots.size():
				var dir: Vector3 = shots[s][0]
				cam.size = float(shots[s][2])
				cam.near = 0.05
				cam.far = far * 2.0
				cam.look_at_from_position(c + dir * far, c, shots[s][1])
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var img := view.get_texture().get_image()
				var rect := TextureRect.new()
				rect.texture = ImageTexture.create_from_image(img)
				rect.position = origin + Vector2((s % 2) * TILE, LABEL_H + (s / 2) * TILE)
				canvas.add_child(rect)
				_text(canvas, String(shots[s][3]), rect.position + Vector2(5, 2), 13, Color(1, 1, 1, 0.75))
			debug.queue_free()
			var over: Dictionary = r.get("vox", {})
			var head := "%s  %s" % [kinds[i], r["label"]]
			var size_v: Vector3 = (r["vis"] as AABB).size
			var size_c: Vector3 = (r["col"] as AABB).size
			var sub := "形%d%s%s  余分%d%%(%.0fL) 不足%d%%(%.0fL)  見た目%.2f×%.2f×%.2f  当たり%.2f×%.2f×%.2f" % [
				r["count"], ("+薄%d" % r["thin"]) if int(r["thin"]) > 0 else "", ("+無効%d" % r["off"]) if int(r["off"]) > 0 else "",
				roundi(float(over.get("over", 0.0)) * 100.0), float(over.get("over_l", 0.0)), roundi(float(over.get("under", 0.0)) * 100.0), float(over.get("under_l", 0.0)),
				size_v.x, size_v.y, size_v.z, size_c.x, size_c.y, size_c.z]
			_text(canvas, head, origin + Vector2(6, 2), 17, Color("ffd24a"))
			_text(canvas, sub, origin + Vector2(6, 23), 12, Color("e8e8e8"))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s%s_%02d.png" % [OUT, tag, page + 1]
		sheet.get_texture().get_image().save_png(path)
		print("COLLIDER_SHOTS_SAVED ", path)
		canvas.queue_free()
		await process_frame
	if want_settle:
		await _settle(fixture, kinds, bodies, tag)
	print("COLLIDER_SHOTS_DONE ", kinds.size(), " 種類 ", pages, " 枚")
	quit()


# 床に置いて放し、動かず・倒れず・震えないことを数で見る
func _settle(fixture: Node3D, kinds: Array[String], bodies: Array, tag: String) -> void:
	Audit.add_floor(fixture)
	var rows: Array = await Audit.settle(self, bodies)
	var lines: PackedStringArray = []
	var bad := 0
	for j in bodies.size():
		var r: Dictionary = rows[j]
		if not r["ok"]:
			bad += 1
		lines.append("SETTLE %-18s 移動=%.3fm 高さ=%.3f 傾き=%.1f度 回り=%.1f度 速さ=%.3f 回転=%.3f 眠り=%s %s" % [
			kinds[j], r["moved"], r["height"], r["tilt"], r["turned"], r["speed"], r["spin"], "はい" if r["asleep"] else "いいえ", "OK" if r["ok"] else "NG"])
	for line: String in lines:
		print(line)
	print("SETTLE_SUMMARY 落ち着かない物=", bad, " / ", bodies.size())
	_save_text(OUT + tag + "_settle.txt", lines)


# 撮るのに邪魔な光や、重い描画を止める
func _quiet(body: Node3D) -> void:
	if "level" in body:
		body.level = 0
	for light: Light3D in body.find_children("*", "Light3D", true, false):
		light.visible = false
	for sub: SubViewport in body.find_children("*", "SubViewport", true, false):
		sub.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _text(parent: Control, text: String, at: Vector2, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)


func _save_text(path: String, lines: PackedStringArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		print("COLLIDER_SHOTS 書き出せない：", path)
		return
	f.store_string("\n".join(lines) + "\n")
	f.close()


func _v(v: Vector3) -> String:
	return "%.3f,%.3f,%.3f" % [v.x, v.y, v.z]


# 報告の1行
func _line(body: Node3D, r: Dictionary) -> String:
	var vis: AABB = r["vis"]
	var col: AABB = r["col"]
	var lo: Vector3 = r["lo"]
	var hi: Vector3 = r["hi"]
	var vox: Dictionary = r.get("vox", {})
	var com := "auto"
	if (body as RigidBody3D).center_of_mass_mode == RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM:
		com = _v((body as RigidBody3D).center_of_mass)
	return "COLLIDER %-18s 形=%d 薄=%d 無効=%d 三角=%d | 見た目 大きさ(%s) 下(%s) 上(%s) | 当たり 大きさ(%s) 下(%s) 上(%s) | 出入り 下側(%s) 上側(%s) | 升目 %.3fm 余分=%.0f%%(%.1fL) 不足=%.0f%%(%.1fL) 見た目=%.1fL 当たり=%.1fL | center ずれ(%s) half ずれ(%s) | 重さ=%.1f 重心=%s | %dms" % [
		r["kind"], r["count"], r["thin"], r["off"], r["tris"],
		_v(vis.size), _v(vis.position), _v(vis.end), _v(col.size), _v(col.position), _v(col.end), _v(lo), _v(hi),
		float(vox.get("cell", 0.0)), float(vox.get("over", 0.0)) * 100.0, float(vox.get("over_l", 0.0)), float(vox.get("under", 0.0)) * 100.0, float(vox.get("under_l", 0.0)),
		float(vox.get("vis_l", 0.0)), float(vox.get("col_l", 0.0)),
		_v(r["center_off"]), _v(r["half_off"]), (body as RigidBody3D).mass, com, r["ms"]]


# 部品（メッシュ）ごとの外形。当たり判定の表を作るときの元になる
func _parts(body: Node3D, kind: String) -> PackedStringArray:
	var out: PackedStringArray = []
	out.append("== %s  center(%s) half(%s)" % [kind, _v(body.center), _v(body.half)])
	for item: Dictionary in Audit.visual_meshes(body):
		var mi: MeshInstance3D = item["node"]
		var xf: Transform3D = item["xf"]
		var faces: PackedVector3Array = mi.mesh.get_faces()
		var pts := PackedVector3Array()
		pts.resize(faces.size())
		for i in faces.size():
			pts[i] = xf * faces[i]
		var path := String(mi.name)
		var up: Node = mi.get_parent()
		var depth := 0
		while up != null and up != body and depth < 2:
			path = String(up.name) + "/" + path
			up = up.get_parent()
			depth += 1
		var groups: Array = _components(pts) if _deep else [pts]
		for g in groups.size():
			var part: PackedVector3Array = groups[g]
			var box := Audit.points_aabb(part)
			if maxf(box.size.x, maxf(box.size.y, box.size.z)) < _part_min:
				continue
			var line := "  %-60s 三角=%-6d 中心(%s) 大きさ(%s) 下(%s) 上(%s)" % [path if groups.size() == 1 else "%s#%d" % [path, g], part.size() / 3, _v(box.get_center()), _v(box.size), _v(box.position), _v(box.end)]
			var tilt := _tilted_box(part)
			if String(tilt["axis"]) != "":
				line += " 斜め[軸=%s 角=%.1f 中心(%s) 大きさ(%s) 割合=%.2f]" % [tilt["axis"], tilt["deg"], _v(tilt["center"]), _v(tilt["size"]), tilt["gain"]]
			out.append(line)
	for item: Dictionary in Audit.shapes(body):
		var shape: Shape3D = item["shape"]
		var xf: Transform3D = item["xf"]
		var box := Audit.shape_bounds(shape)
		out.append("  [当たり %s%s%s] 中心(%s) 大きさ(%s) 回転(%s)" % [Audit.shape_name(shape), " 薄" if item["thin"] else "", " 無効" if item["off"] else "",
			_v(xf.origin), _v(box.size), _v(xf.basis.get_euler())])
	return out


# 三角形の集まりを、頂点でつながった部分ごとに分ける（大きい順）
func _components(pts: PackedVector3Array) -> Array:
	var ids := {}
	var parent := PackedInt32Array()
	var vert := PackedInt32Array()
	vert.resize(pts.size())
	for i in pts.size():
		var key := Vector3i((pts[i] * 2000.0).round())
		if not ids.has(key):
			ids[key] = parent.size()
			parent.append(parent.size())
		vert[i] = ids[key]
	for t in pts.size() / 3:
		for k in [1, 2]:
			var a := vert[t * 3]
			var b := vert[t * 3 + k]
			while parent[a] != a:
				parent[a] = parent[parent[a]]
				a = parent[a]
			while parent[b] != b:
				parent[b] = parent[parent[b]]
				b = parent[b]
			if a != b:
				parent[b] = a
	var groups := {}
	for i in pts.size():
		var r := vert[i]
		while parent[r] != r:
			r = parent[r]
		# ふつうの配列に集める（Packed の配列は、辞書から取り出すと写しになって足せない）
		if not groups.has(r):
			groups[r] = []
		(groups[r] as Array).append(pts[i])
	var out: Array = []
	for list: Array in groups.values():
		out.append(PackedVector3Array(list))
	out.sort_custom(func(a: PackedVector3Array, b: PackedVector3Array) -> bool: return Audit.points_aabb(a).get_volume() > Audit.points_aabb(b).get_volume())
	return out


# 点の集まりを、1つの軸まわりに回した箱で囲む。軸に沿った箱よりずっと小さく囲めるとき（斜めの棒など）だけ、その軸と角度を返す
func _tilted_box(pts: PackedVector3Array) -> Dictionary:
	var box := Audit.points_aabb(pts)
	var out := {"axis": "", "deg": 0.0, "center": box.get_center(), "size": box.size, "gain": 1.0}
	if pts.size() < 3:
		return out
	var flat_volume := maxf(box.size.x, 0.01) * maxf(box.size.y, 0.01) * maxf(box.size.z, 0.01)
	var mean := Vector3.ZERO
	for q: Vector3 in pts:
		mean += q
	mean /= float(pts.size())
	var best := flat_volume * 0.72
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var suu := 0.0
		var svv := 0.0
		var suv := 0.0
		for q: Vector3 in pts:
			var d := q - mean
			suu += d[u] * d[u]
			svv += d[v] * d[v]
			suv += d[u] * d[v]
		var theta := 0.5 * atan2(2.0 * suv, suu - svv)
		var axis_vec := Vector3.ZERO
		axis_vec[axis] = 1.0
		for angle: float in [theta, -theta]:
			angle = wrapf(angle, -PI * 0.25, PI * 0.25)
			if absf(angle) < deg_to_rad(4.0):
				continue
			var turn := Basis(axis_vec, angle)
			var back := turn.inverse()
			var lo := back * pts[0]
			var hi := lo
			for q: Vector3 in pts:
				var r := back * q
				lo = lo.min(r)
				hi = hi.max(r)
			var size := hi - lo
			var volume := maxf(size.x, 0.01) * maxf(size.y, 0.01) * maxf(size.z, 0.01)
			if volume < best:
				best = volume
				out = {"axis": ["x", "y", "z"][axis], "deg": rad_to_deg(angle), "center": turn * ((lo + hi) * 0.5), "size": size, "gain": volume / flat_volume}
	return out


# 当たり判定を、色つきの半透明の形と線で見せる。center と half の箱、床の線も引く
func _debug(body: Node3D) -> Node3D:
	var holder := Node3D.new()
	holder.name = "ColliderDebug"
	body.add_child(holder)
	var list := Audit.shapes(body)
	var n := 0
	for item: Dictionary in list:
		var shape: Shape3D = item["shape"]
		var color := Color.from_hsv(0.26 + 0.055 * float(n % 5), 0.9, 1.0)
		if item["off"]:
			color = Color(1.0, 0.86, 0.15)
		elif item["thin"]:
			color = Color(1.0, 0.25, 0.9)
		else:
			n += 1
		var solid := MeshInstance3D.new()
		solid.mesh = _solid_mesh(shape)
		solid.transform = item["xf"]
		solid.material_override = _mat(Color(color.r, color.g, color.b, 0.16 if item["off"] else 0.3), 5)
		solid.set_meta("collider_debug", true)
		holder.add_child(solid)
		var wire := MeshInstance3D.new()
		wire.mesh = _wire_mesh(shape)
		wire.transform = item["xf"]
		wire.material_override = _mat(color.darkened(0.15), 6)
		wire.set_meta("collider_debug", true)
		holder.add_child(wire)
	# center と half の箱（水色の線）
	var frame := MeshInstance3D.new()
	var box := BoxShape3D.new()
	box.size = (body.half as Vector3) * 2.0
	frame.mesh = _wire_mesh(box)
	frame.position = body.center
	frame.material_override = _mat(Color(0.35, 0.85, 1.0, 0.9), 7)
	frame.set_meta("collider_debug", true)
	holder.add_child(frame)
	# 物の原点の高さ（白い線の四角）
	var floor_line := MeshInstance3D.new()
	var flat := BoxShape3D.new()
	var reach: Vector3 = (body.half as Vector3) * 2.6 + Vector3.ONE * 0.2
	flat.size = Vector3(reach.x, 0.0, reach.z)
	floor_line.mesh = _wire_mesh(flat)
	floor_line.position = Vector3(body.center.x, 0.0, body.center.z)
	floor_line.material_override = _mat(Color(1, 1, 1, 0.8), 7)
	floor_line.set_meta("collider_debug", true)
	holder.add_child(floor_line)
	return holder


func _solid_mesh(shape: Shape3D) -> Mesh:
	if shape is BoxShape3D:
		var box := BoxMesh.new()
		box.size = (shape as BoxShape3D).size
		return box
	if shape is CylinderShape3D:
		var cyl := CylinderMesh.new()
		cyl.top_radius = (shape as CylinderShape3D).radius
		cyl.bottom_radius = cyl.top_radius
		cyl.height = (shape as CylinderShape3D).height
		return cyl
	if shape is SphereShape3D:
		var ball := SphereMesh.new()
		ball.radius = (shape as SphereShape3D).radius
		ball.height = ball.radius * 2.0
		return ball
	if shape is CapsuleShape3D:
		var cap := CapsuleMesh.new()
		cap.radius = (shape as CapsuleShape3D).radius
		cap.height = (shape as CapsuleShape3D).height
		return cap
	return shape.get_debug_mesh()


# 形の輪郭を線で描くメッシュ
func _wire_mesh(shape: Shape3D) -> Mesh:
	var pts := PackedVector3Array()      # 2点ずつで1本の線
	if shape is BoxShape3D:
		var h: Vector3 = (shape as BoxShape3D).size * 0.5
		for a: float in [-1.0, 1.0]:
			for b: float in [-1.0, 1.0]:
				pts.append_array([Vector3(-h.x, a * h.y, b * h.z), Vector3(h.x, a * h.y, b * h.z)])
				pts.append_array([Vector3(a * h.x, -h.y, b * h.z), Vector3(a * h.x, h.y, b * h.z)])
				pts.append_array([Vector3(a * h.x, b * h.y, -h.z), Vector3(a * h.x, b * h.y, h.z)])
	elif shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		for y: float in [-0.5, 0.5]:
			_ring(pts, Vector3(0, y * cyl.height, 0), Vector3.RIGHT, Vector3.BACK, cyl.radius, 0.0, TAU)
		for i in 8:
			var a := TAU * float(i) / 8.0
			var side := Vector3(cos(a), 0, sin(a)) * cyl.radius
			pts.append_array([side - Vector3(0, cyl.height * 0.5, 0), side + Vector3(0, cyl.height * 0.5, 0)])
	elif shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		_ring(pts, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, r, 0.0, TAU)
		_ring(pts, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, r, 0.0, TAU)
		_ring(pts, Vector3.ZERO, Vector3.BACK, Vector3.UP, r, 0.0, TAU)
	elif shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		var straight := maxf(cap.height * 0.5 - cap.radius, 0.0)
		for y: float in [-1.0, 1.0]:
			var mid := Vector3(0, y * straight, 0)
			_ring(pts, mid, Vector3.RIGHT, Vector3.BACK, cap.radius, 0.0, TAU)
			_ring(pts, mid, Vector3.RIGHT, Vector3.UP * y, cap.radius, 0.0, PI)
			_ring(pts, mid, Vector3.BACK, Vector3.UP * y, cap.radius, 0.0, PI)
		for side: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			pts.append_array([side * cap.radius - Vector3(0, straight, 0), side * cap.radius + Vector3(0, straight, 0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


func _ring(pts: PackedVector3Array, mid: Vector3, u: Vector3, v: Vector3, radius: float, from: float, to: float) -> void:
	var steps := 32
	for i in steps:
		var a := lerpf(from, to, float(i) / steps)
		var b := lerpf(from, to, float(i + 1) / steps)
		pts.append(mid + (u * cos(a) + v * sin(a)) * radius)
		pts.append(mid + (u * cos(b) + v * sin(b)) * radius)


func _mat(color: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.no_depth_test = true
	m.render_priority = priority
	return m
