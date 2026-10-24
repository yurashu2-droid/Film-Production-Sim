extends Node
## 会社の看板（1日目の最初の手順。docs/production/tutorial-cm.md）：
##   ・事務所の入口の上に、看板を掛ける金具（壁から出た鉄のフック2つ）がある。はじめは空
##   ・スプレーで描いた段ボール板（spray_sign.gd）を持って、金具の下で F：その板と、接着剤でつないだ板（adhesive.gd の
##     つながり）が、まとめて1枚の看板として掛かって止まる。持っていた板がフックに掛かり、ほかの板はつないだ所を支点に、
##     板の面だけそろえる（ずれ・傾き・重なりは、つないだときのまま。きれいに並べ直さない）
##   ・掛かった看板を左クリックすると、外して持てる（掛け直せる）
##   ・掛けた看板を、正面から正射影のカメラで撮って（看板の板だけを映す。背景は透明）、会社の名前にする
##     （ui/company_logo.gd。会社が呼ばれる文の「{会社}」が、この絵になる）。描き直したり掛け直したりしたら、撮り直す。
##     絵は各自の画面で撮る（板の絵と置き場所は、ほかの物と同じに全員へ届く）
##   ・倒産して新しい会社になったら、看板は外れて、金具は空になる（名前も無くなる）
## 決めるのはホスト（掛ける・外す）。金具・撮る・吊り紐は、全員の画面
const Logo := preload("res://scripts/ui/company_logo.gd")
const Office := preload("res://scripts/production_office.gd")
const Sheet := preload("res://scripts/cardboard_sheet.gd")
const HOOKS_AT := [Vector3(71.5, 4.42, 4.08), Vector3(72.5, 4.42, 4.08)]   # フックの根元（書割の壁の表）
const HOOK_OUT := 0.17               # 壁からフックの先まで
const HANG_Z := 4.27                 # 掛けた板の面（壁から少し前）
const HANG_DROP := 0.2               # フックの先から、板の上の縁まで（吊り紐の長さ）
const REACH := 3.6                   # 金具からこの距離（水平）まで近づけば、F で掛けられる
const SIGN_LAYER := 1 << 18          # 看板を撮るカメラだけが見る層（掛けている板の見た目に足す）
const SHOT_W := 512                  # 撮る絵の長い辺（ピクセル）
const SETTLE := 0.35                 # 描き足し・掛け直しが落ち着いてから撮るまでの秒数

var game: Node
var members: Array = []              # いま掛かっている板（物のID）。先頭がフックに掛かっている板
var layout := {}                     # ホスト：掛けた板の置き場所（物のID → Transform3D）。帰社のあと、掛け直す
var glue: Array = []                 # ホスト：看板の板どうしの接着（adhesive.gd の pairs の写し）。依頼を受けると接着剤の点は
                                     # 片づけられる（main.gd の _apply_order）が、看板は会社の物なので、外したときに付け直す
var shots := 0                       # この画面で撮った回数（確認用）
var _hooks: Node3D
var _cords: Array[MeshInstance3D] = []
var _vp: SubViewport
var _cam: Camera3D
var _sig := ""
var _due := -1.0
var _busy := false
var _layers := {}                    # 物のID → [見た目, 元の layers] の一覧


func setup() -> void:
	_build_hooks()
	_build_camera()
	_hide_old_sign()


func _sheets() -> Array:
	var kit: Node = game.hooks.feature("spray_sign")
	return kit.sheets if kit != null else []


func is_sheet(p: Node) -> bool:
	return p != null and p in _sheets()


func hung() -> bool:
	return not members.is_empty()


# 金具の真ん中（フックの先の間）
static func hang_point() -> Vector3:
	return (HOOKS_AT[0] + HOOKS_AT[1]) * 0.5 + Vector3(0, 0, HOOK_OUT)


func near_hooks(me: Node) -> bool:
	if me == null:
		return false
	var d: Vector3 = (me as Node3D).global_position - hang_point()
	return (me as Node3D).global_position.z > 3.9 and Vector2(d.x, d.z).length() < REACH


# ---- 金具（全員の画面） ----

func _build_hooks() -> void:
	_hooks = Node3D.new()
	_hooks.name = "CompanySignHooks"
	game.add_child(_hooks)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("2b2d30")
	iron.metallic = 0.6
	iron.roughness = 0.45
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color("b9a27a")         # 麻ひも
	cord.roughness = 1.0
	for at: Vector3 in HOOKS_AT:
		# 壁に留めた座金とねじ・壁から出る腕・先の上向きの爪
		_piece(_box(Vector3(0.07, 0.09, 0.012)), iron, Transform3D(Basis.IDENTITY, at + Vector3(0, 0, 0.006)))
		for dy: float in [-0.028, 0.028]:
			_piece(_cyl(0.008, 0.008), iron, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, dy, 0.014)))
		_piece(_cyl(0.011, HOOK_OUT), iron, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), at + Vector3(0, 0, HOOK_OUT * 0.5 + 0.01)))
		_piece(_cyl(0.01, 0.06), iron, Transform3D(Basis(Vector3.BACK, 0.0), at + Vector3(0, 0.03, HOOK_OUT + 0.005)))
		# 吊り紐（看板を掛けたときだけ。フックの先から、板の上の縁まで）
		var c := _piece(_cyl(0.006, 1.0), cord, Transform3D.IDENTITY)
		c.visible = false
		_cords.append(c)


func _piece(mesh: Mesh, mat: Material, at: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = at
	mi.layers = Office.FACADE_LAYER          # 書割の社屋と同じ層（事務所の中からは、書割と一緒に消える）
	_hooks.add_child(mi)
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 1
	return m


# 書割の社屋の、文字の社名（Label3D）は出さない。会社の名前は、掛けた段ボールの看板で見せる
func _hide_old_sign() -> void:
	var old: Label3D = game.find_child("CompanyNameSign", true, false) as Label3D
	if old != null:
		old.visible = false


func hook_production_applied() -> void:
	_hide_old_sign()


# ---- 掛ける・外す（ホストが決める） ----

func hook_f(me: Node) -> bool:
	if me == null or me.held == 0 or not near_hooks(me):
		return false
	var p: Node = game.props.get(me.held)
	if not is_sheet(p):
		return false
	h_hang.rpc_id(1, int(me.held))
	return true


func hook_click(me: Node) -> bool:
	if me == null or me.held != 0 or me.target == null or not (int(me.target.pid) in members) or not near_hooks(me):
		return false
	h_take_down.rpc_id(1, int(me.target.pid))
	return true


@rpc("any_peer", "call_local", "reliable")
func h_hang(pid: int) -> void:
	if not Net.is_host() or game.replaying:
		return
	var who := Net.sender()
	var me: Node3D = game.players.get(who)
	var p: RigidBody3D = game.props.get(pid)
	if me == null or p == null or p.holder != who or not is_sheet(p) or not near_hooks(me):
		return
	if hung():
		game.ev.rpc_id(who, "toast", ["金具には、もう看板が掛かっている（掛かっている看板を左クリックで外せる）", 1])
		return
	var group: Array = game.adhesive.connected_ids(pid) if game.get("adhesive") != null else [pid]
	for id: int in group:
		var q: RigidBody3D = game.props.get(id)
		if not is_sheet(q):
			game.ev.rpc_id(who, "toast", ["段ボール板のほかに、%s がくっついている。看板にできるのは、段ボール板だけ" % (q.label if q != null else "何か"), 1])
			return
		if q.holder != 0 and q.holder != who:
			return
	var placed := hang_layout(group, pid)
	game.host_release(p)
	layout = placed
	glue = []
	for pair: Dictionary in (game.adhesive.pairs if game.get("adhesive") != null else []):
		if bool(pair.get("joined", false)) and int(pair.a) in group and int(pair.b) in group:
			glue.append({"a": pair.a, "b": pair.b, "pa": pair.pa, "pb": pair.pb, "joined": true})
	members = [pid]
	for id: int in group:
		if id != pid:
			members.append(id)
	_place_all()
	game.host_ev("sfx", ["fix", hang_point()])
	game.host_ev("csign", [members, false])
	game.ev.rpc_id(who, "toast", ["看板を掛けた", 0])


@rpc("any_peer", "call_local", "reliable")
func h_take_down(pid: int) -> void:
	if not Net.is_host() or game.replaying or not (pid in members):
		return
	var who := Net.sender()
	var me: Node3D = game.players.get(who)
	if me == null or not near_hooks(me):
		return
	_reglue()
	_release_all()
	game.host_ev("csign", [members, false])
	game.h_grab(pid)          # 外した看板は、そのまま手に持つ（つないだ板もいっしょ）


# 看板の板どうしの接着が片づけられていたら、付け直す（ホスト）
func _reglue() -> void:
	var adh: Node = game.get("adhesive")
	if adh == null or glue.is_empty():
		return
	var added := false
	for g: Dictionary in glue:
		var found := false
		for pair: Dictionary in adh.pairs:
			if int(pair.a) == int(g.a) and int(pair.b) == int(g.b) and (pair.pa as Vector3).is_equal_approx(g.pa) and bool(pair.joined):
				found = true
				break
		if not found:
			adh.pairs.append(g.duplicate())
			added = true
	if added:
		adh.restore(adh.snapshot())


# 掛けた置き場所に、板を止める（ホスト）
func _place_all() -> void:
	for id: int in layout:
		var q: RigidBody3D = game.props.get(id)
		if q == null:
			continue
		var t: Transform3D = layout[id]
		q.restore([t.origin, t.basis.get_rotation_quaternion(), true])


# 看板を外す（ホスト）。板は、今の場所で止めるのをやめる
func _release_all() -> void:
	for id: int in members:
		var q: RigidBody3D = game.props.get(id)
		if q != null:
			q.restore([q.global_position, Quaternion(q.global_basis.orthonormalized()), false])
	members = []
	layout = {}


# 掛けたときの置き場所（物のID → Transform3D）。anchor の板をフックの下に、まっすぐ正面（+Z）へ向けて掛ける。
# ほかの板は、つないだ点を支点に、板の面が正面を向くまで回すだけ（面の中のずれ・傾き・重なりは、そのまま）
func hang_layout(group: Array, anchor: int) -> Dictionary:
	var a: Node3D = game.props[anchor]
	var to_anchor: Transform3D = a.global_transform.affine_inverse()
	var rel := {}
	for id: int in group:
		rel[id] = to_anchor * (game.props[id] as Node3D).global_transform
	rel[anchor] = Transform3D.IDENTITY
	# つないだ順にたどる（先に置いた板の、つないだ点のまわりで回す）
	var done := {anchor: true}
	var order: Array = [anchor]
	var pairs: Array = game.adhesive.pairs if game.get("adhesive") != null else []
	var k := 0
	while k < order.size():
		var u: int = order[k]
		k += 1
		for pair: Dictionary in pairs:
			if not bool(pair.get("joined", false)):
				continue
			var v := -1
			var on_u := Vector3.ZERO
			if int(pair.a) == u and not done.has(int(pair.b)) and int(pair.b) in group:
				v = int(pair.b)
				on_u = pair.pa
			elif int(pair.b) == u and not done.has(int(pair.a)) and int(pair.a) in group:
				v = int(pair.a)
				on_u = pair.pb
			if v < 0:
				continue
			done[v] = true
			order.append(v)
			var t: Transform3D = rel[v]
			var pivot: Vector3 = (rel[u] as Transform3D) * on_u
			var n := t.basis.z.normalized()
			var turn: Quaternion
			if n.dot(Vector3.BACK) < -0.999:
				turn = Quaternion(t.basis.y.normalized(), PI)       # 裏返しにつないだ板は、表を正面へ
			else:
				turn = Quaternion(n, Vector3.BACK)
			t = Transform3D(Basis(turn), pivot) * Transform3D(Basis.IDENTITY, -pivot) * t
			t.origin.z = 0.006 * float(order.size() - 1)            # 面をそろえる（重なった所が、ちらつかないように少しずつ手前へ）
			rel[v] = t
	for id: int in group:
		if not done.has(id):
			var t: Transform3D = rel[id]
			t.basis = Basis.IDENTITY
			t.origin.z = 0.006 * float(order.size())
			rel[id] = t
	var top: float = float(Sheet.SIZE.y)
	var frame := Transform3D(Basis.IDENTITY, Vector3(hang_point().x, HOOKS_AT[0].y - HANG_DROP - top, HANG_Z))
	var out := {}
	for id: int in group:
		out[id] = frame * (rel[id] as Transform3D)
	return out


# 帰社：掛けた看板は、片づけない（置き場所を戻す処理のあとで、掛け直す）。倒産して新しい会社になったら、外す
func hook_office_ready() -> void:
	var flow: Node = game.production
	if not hung():
		return
	if flow != null and int(flow.day) <= 1:
		var home: Dictionary = flow._home_layout
		var old := members.duplicate()
		_release_all()
		for id: int in old:
			var q: RigidBody3D = game.props.get(id)
			if q != null and home.has(id):
				q.restore(home[id])
		game.host_ev("csign", [[], true])
		return
	_place_all()


# 1日目の段取り（tutorial_day.gd）が板を出すとき、掛けてある板は使わない
func in_use(p: Node) -> bool:
	return p != null and int(p.pid) in members


func hook_events() -> Array:
	return ["csign"]


func hook_event(n: String, a: Array) -> void:
	if n != "csign":
		return
	_set_members(a[0])
	if bool(a[1]):
		Logo.set_logo(null)
		_sig = ""


func hook_sync(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "csign", [members, false])


# 掛かっている板が変わった（全員の画面）：見た目の層を替える（撮るカメラに映す・書割と一緒に消える）
func _set_members(list: Array) -> void:
	for id: int in _layers:
		for row: Array in _layers[id]:
			if is_instance_valid(row[0]):
				(row[0] as VisualInstance3D).layers = int(row[1])
	_layers = {}
	members = list.map(func(id: Variant) -> int: return int(id))
	for id: int in members:
		var q: Node = game.props.get(id)
		if q == null:
			continue
		var rows: Array = []
		var look: Node = q.get("visual") if q.get("visual") != null else q          # 板の見た目だけ（接着剤の点は映さない）
		for vi: VisualInstance3D in look.find_children("*", "VisualInstance3D", true, false):
			rows.append([vi, vi.layers])
			vi.layers = Office.FACADE_LAYER | SIGN_LAYER
		_layers[id] = rows
	_due = Time.get_ticks_msec() / 1000.0 + SETTLE
	_sig = ""


# ---- 撮る（各自の画面） ----

func _build_camera() -> void:
	_vp = SubViewport.new()
	_vp.name = "CompanySignShot"
	_vp.transparent_bg = true
	_vp.size = Vector2i(SHOT_W, SHOT_W / 2)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.cull_mask = SIGN_LAYER
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_cam.environment = env
	_vp.add_child(_cam)


func _process(_delta: float) -> void:
	_update_cords()
	if not hung():
		return
	var sig := _signature()
	var now := Time.get_ticks_msec() / 1000.0
	if sig != _sig:
		_sig = sig
		_due = now + SETTLE
	if _due > 0.0 and now >= _due and not _busy:
		_due = -1.0
		capture()


# 板の絵の版と置き場所。変わったら撮り直す
func _signature() -> String:
	var out := ""
	for id: int in members:
		var q: Node3D = game.props.get(id)
		if q == null:
			continue
		var at := q.global_position.snapped(Vector3.ONE * 0.01)
		out += "%d:%d:%s;" % [id, int(q.get("revision")), str(at)]
	return out


# 掛けた板の外形（世界の座標。正面から見た四角）
func bounds() -> AABB:
	var box := AABB()
	var first := true
	for id: int in members:
		var q: Node3D = game.props.get(id)
		if q == null:
			continue
		var c: Vector3 = q.center
		var h: Vector3 = q.half
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var p: Vector3 = q.global_transform * (c + Vector3(h.x * sx, h.y * sy, h.z * sz))
					if first:
						box = AABB(p, Vector3.ZERO)
						first = false
					else:
						box = box.expand(p)
	return box


# 看板を撮って、会社の名前の絵にする（この画面だけ）
func capture() -> void:
	if not hung():
		return
	_busy = true
	var box := bounds().grow(0.03)
	var w := maxf(box.size.x, 0.1)
	var h := maxf(box.size.y, 0.1)
	var size := Vector2i(SHOT_W, maxi(16, int(SHOT_W * h / w))) if w >= h else Vector2i(maxi(16, int(SHOT_W * w / h)), SHOT_W)
	var img: Image = null
	if DisplayServer.get_name() != "headless":
		_vp.size = size
		_cam.size = h
		_cam.global_transform = Transform3D(Basis.IDENTITY, Vector3(box.get_center().x, box.get_center().y, box.end.z + 2.0))
		_cam.near = 0.05
		_cam.far = 4.0 + box.size.z
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_instance_valid(_vp):
			return
		img = _vp.get_texture().get_image()
	if img == null or img.is_empty():
		img = _composite(box, size)      # 描けない画面（自動確認の headless）：板の絵を並べて作る
	_busy = false
	if not hung():
		return
	Logo.set_logo(ImageTexture.create_from_image(img))
	shots += 1


# 描けない画面のための代わり：各板の絵を、正面から見た場所に並べる（回りは見ない）
func _composite(box: AABB, size: Vector2i) -> Image:
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var scale := float(size.x) / box.size.x
	for id: int in members:
		var q: Node3D = game.props.get(id)
		if q == null or q.get("ink") == null:
			continue
		var ink: Image = (q.ink as Image).duplicate()
		ink.convert(Image.FORMAT_RGBA8)
		var pw := maxi(1, int(Sheet.SIZE.x * scale))
		var ph := maxi(1, int(Sheet.SIZE.y * scale))
		ink.resize(pw, ph)
		var c: Vector3 = q.global_transform * (q.center as Vector3)
		var x := int((c.x - box.position.x) * scale - pw * 0.5)
		var y := int((box.end.y - c.y) * scale - ph * 0.5)
		out.blend_rect(ink, Rect2i(Vector2i.ZERO, ink.get_size()), Vector2i(x, y))
	return out


# 吊り紐：フックの先から、フックに掛かっている板の上の縁まで
func _update_cords() -> void:
	var anchor: Node3D = game.props.get(members[0]) if hung() else null
	for i in _cords.size():
		var c := _cords[i]
		c.visible = anchor != null
		if anchor == null:
			continue
		var tip: Vector3 = HOOKS_AT[i] + Vector3(0, 0.02, HOOK_OUT)
		var local := anchor.to_local(Vector3(tip.x, tip.y, anchor.global_position.z))
		var to := anchor.global_transform * Vector3(clampf(local.x, -Sheet.SIZE.x * 0.45, Sheet.SIZE.x * 0.45), Sheet.SIZE.y - 0.02, 0.0)
		var d := to - tip
		var length := d.length()
		if length < 0.01:
			c.visible = false
			continue
		var up := d / length
		var side := up.cross(Vector3.BACK).normalized() if absf(up.z) < 0.95 else Vector3.RIGHT
		var fwd := side.cross(up)
		c.global_transform = Transform3D(Basis(side, up * length, fwd), tip + d * 0.5)


# ---- 画面の案内 ----

func hook_hud(me: Node, _label: String, keys: String) -> Dictionary:
	if me == null:
		return {}
	var p: Node = game.props.get(me.held) if me.held != 0 else null
	# 案内は keys_all で書く（何も狙っていないときは、keys が画面に出ないため）
	if is_sheet(p) and near_hooks(me) and not hung():
		return {"keys_all": "F 看板を金具に掛ける ／ " + keys}
	if me.held == 0 and in_use(me.target) and near_hooks(me):
		return {"tail": "　[左クリック] 金具から外す", "keys_all": "左クリック 看板を金具から外す"}
	var step := tutorial_step()
	var box: Node = game.hooks.feature("delivery_box")
	if step == "" and box != null and int(box.line) >= 0 and box.near(me) and not keys.contains("講師"):
		return {"keys_all": "F 講師の話を飛ばす ／ " + keys}
	if step == "":
		return {}
	var out := keys
	if step == "box":
		var open := "F 宅配の箱を開ける（代金引換）" if box.near(me) and me.held == 0 else "届いた宅配の箱を開けよう"
		out = out.replace("F 依頼を見る", open).replace("事務所の掲示板で、今日の依頼を選ぼう", open)
	else:
		if box != null and int(box.line) >= 0 and box.near(me) and not out.contains("講師"):
			out = "F 講師の話を飛ばす ／ " + out
		var say := "段ボールで会社の看板を作って、入口の上の金具に掛けよう"
		out = out.replace("F 依頼を見る", say + " ／ F 依頼を見る").replace("事務所の掲示板で、今日の依頼を選ぼう", say)
	return {} if out == keys else {"keys_all": out}


# 1日目の今の手順："box"＝宅配の箱を開ける・"sign"＝看板を作って掛ける・""＝掲示板（ふつうの案内）
func tutorial_step() -> String:
	var flow: Node = game.production
	if flow == null or not bool(flow.daily) or int(flow.day) > 1 or int(flow.phase) != 0:
		return ""
	var box: Node = game.hooks.feature("delivery_box")
	if box != null and bool(box.on) and not bool(box.opened):
		return "box"
	return "" if hung() else "sign"
