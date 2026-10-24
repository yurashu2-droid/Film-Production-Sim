extends Node
## バミリ（撮影現場で、役者の立ち位置に床へ貼る、色つきのテープの×印）。
##   ・役者（雇った役者・新人。AI で動く役者）を見て F → 「ここに立って」と床を指して左クリック：
##     役者はそこへ歩き、その立ち位置として覚える（production_beats.gd の host_teach）。足元に、役者の色のテープの×が貼られる。
##     床を指している間に、もう一度 F で次の立ち位置（①→②→③）、右クリックか Esc でやめる。
##   ・どの立ち位置を教えるか（production_beats.gd の teach_step）：
##     カット割りの本番でフィルムを止めている間（場転）は、次に撮る場面で役者が向かう立ち位置。
##     それ以外（準備中）は、まだ教えていない、いちばん若い立ち位置。全部教えてあれば、最後に教えた立ち位置の次（教え直し）。
##   ・同じ立ち位置をもう一度教えると、テープは貼り替わる。テープを見て右クリックで、はがす（そこは決まった場所に戻る）。
##   ・役に入っている人（自分で演じる）は、M で足元に自分の役の色のテープを貼れる。歩かされはしない（ただの目印）。
##     そのときの立ち位置は、テープの所になる（教えていなければ、止まった所が立ち位置。actor.gd の free）。
##   ・テープは床に平らに貼るだけの飾り（持てない・蹴飛ばせない・当たらない）。場面の番号は、端のテープの切れ端にマーカーで書いた数字。
##   ・教えていない役者は、決まった場所（MARK_HOME）に、テープなしで立つ・歩く。採点は、テープを見ない。
## 決めるのはホスト（h_teach・h_peel）。立ち位置は "spots" の合図で全員へ届き、各自の画面でテープを貼り直す
const COLORS := [Color("e8768f"), Color("4f8fd1"), Color("6fca7f"), Color("f2a64a")]     # 役の色（features/stand_ins.gd のたすきと同じ）
const CREW_LAYER := 1 << 11
const LOOK_REACH := 7.0       # 役者を見て F を押せる距離（m）
const LOOK_RADIUS := 0.38     # 視線が、役者の体からこの距離までを通っていれば「見ている」
const POINT_REACH := 14.0     # 床を指せる距離（m）
const TEACH_REACH := 18.0     # 役者・指した所が、教える人からこの距離まで（ホストの確かめ）
const FLAT := 0.7             # 指した面の上向き（これより平らな所にだけ貼れる）
const PEEL_NEAR := 0.3        # テープの真ん中から、この距離（横）を見て右クリックで、はがす
const TAPE_LEN := 0.42
const TAPE_W := 0.06
const LIFT := 0.004           # 床から浮かせる高さ（ちらつかないように）

static var _told := false     # 初めて役者が出たときの、ひとこと（この起動のあいだに一度だけ）

var game: Node
var root: Node3D              # 床に貼ったテープ（物の上に貼った分は、その物の子）
var _tapes := {}              # "役:立ち位置" → テープ
var _rev := -1
var _aim_aid := -1            # 床を指している最中の役者（-1＝指していない）
var _aim_step := 0
var _ghost: Node3D            # 指している所の、うすい影（制作班にだけ見える）
var _tex := {}                # "役:立ち位置" → 番号を書いた切れ端の絵


func setup() -> void:
	root = Node3D.new()
	root.name = "Bamiri"
	game.add_child(root)


func _beats() -> Node:
	return game.get("beats")


# いま教えられないときの理由（"" ＝教えられる）。全員の画面で同じ答え（ホストも確かめに使う）
func blocked() -> String:
	var flow: Node = game.production
	var beats := _beats()
	if flow == null or beats == null or int(flow.phase) not in [2, 4]:
		return "立ち位置は、撮影の準備のあいだに教える"
	var S: Dictionary = game.S
	if game.state == S.PREP:
		return ""
	if game.state == S.TAKE and bool(beats.holding):
		return ""
	if game.state == S.TAKE:
		return "カメラが回っている間は、立ち位置を教えられない（カットして、場転のあいだに）"
	return "立ち位置は、撮影の準備のあいだに教える"


# 教えられる役者か（雇った役者・新人。役に入った人と、誰も演じない役は、教えられない）
func teachable(a: Node) -> bool:
	var beats := _beats()
	return a != null and beats != null and a.stand_in == null and str(a.grade) in ["pro", "rookie"] and int(a.aid) < int(beats.cast_count())


func _cam(me: Node) -> Camera3D:
	return me.cam if me != null and me.get("cam") is Camera3D else null


# 見ている役者（いなければ null）。手前に物があれば、そちらが先
func looked_actor(me: Node) -> Node:
	var cam := _cam(me)
	if cam == null or int(me.operating) != 0:
		return null
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var best: Node = null
	var best_t := INF
	var far := LOOK_REACH + from.distance_to((me as Node3D).global_position) + 1.0     # 後ろからの視点は、カメラが体より遠い
	for a: Node in game.actors:
		if not teachable(a) or not (a.vis as Node3D).visible:
			continue
		var feet: Vector3 = a.global_position
		for k in 7:
			var q: Vector3 = feet + Vector3(0, 0.2 + 0.23 * float(k), 0)
			var t: float = (q - from).dot(dir)
			if t <= 0.0 or t > far or t >= best_t:
				continue
			if (from + dir * t).distance_to(q) < LOOK_RADIUS and me.global_position.distance_to(feet) < LOOK_REACH:
				best = a
				best_t = t
	if best == null:
		return null
	# あいだに壁・物があれば、見えていない
	var space := (me as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * maxf(best_t - 0.35, 0.05), 1 | 2)
	q.exclude = [(me as CollisionObject3D).get_rid()]
	if not space.intersect_ray(q).is_empty():
		return null
	return best


# 指している床（{} ＝平らな所を指していない）：{"pid", "local", "world"}
func _pointed(me: Node) -> Dictionary:
	var cam := _cam(me)
	if cam == null:
		return {}
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * POINT_REACH, 1 | 2 | 4)
	var skip: Array[RID] = [(me as CollisionObject3D).get_rid()]
	if int(me.held) != 0 and game.props.has(int(me.held)):
		skip.append((game.props[int(me.held)] as CollisionObject3D).get_rid())
	q.exclude = skip
	var hit := (me as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < FLAT:
		return {}
	return _surface(hit)


# 足元の床（{} ＝足の下に何も無い）
func _underfoot(me: Node) -> Dictionary:
	var at: Vector3 = (me as Node3D).global_position
	var q := PhysicsRayQueryParameters3D.create(at + Vector3(0, 0.4, 0), at + Vector3(0, -0.6, 0), 1 | 2)
	q.exclude = [(me as CollisionObject3D).get_rid()]
	var hit := (me as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {"pid": 0, "local": Vector3.ZERO, "world": at}
	return _surface(hit)


# 当たった面：物の上なら、その物と物の中の場所（物を動かすと、立ち位置もついて行く）
func _surface(hit: Dictionary) -> Dictionary:
	var at: Vector3 = hit["position"]
	var c: Object = hit["collider"]
	if c is RigidBody3D and "pid" in c and game.props.has(int(c.pid)):
		return {"pid": int(c.pid), "local": (c as Node3D).to_local(at), "world": at}
	return {"pid": 0, "local": Vector3.ZERO, "world": at}


# 見ているテープ（[役, 立ち位置]。無ければ []）
func aimed_tape(me: Node) -> Array:
	var cam := _cam(me)
	var beats := _beats()
	if cam == null or beats == null:
		return []
	var from := cam.global_position
	var q := PhysicsRayQueryParameters3D.create(from, from - cam.global_basis.z * POINT_REACH, 1 | 2 | 4)
	q.exclude = [(me as CollisionObject3D).get_rid()]
	var hit := (me as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return []
	var at: Vector3 = hit["position"]
	var best: Array = []
	var best_d := PEEL_NEAR
	for aid in 4:
		for step in 3:
			if not beats.taught(aid, step):
				continue
			var p: Vector3 = beats.spot(aid, step)
			var d := Vector2(p.x - at.x, p.z - at.z).length()
			if d < best_d and absf(p.y - at.y) < 0.35:
				best_d = d
				best = [aid, step]
	return best


# 役に入っている人の役（-1＝入っていない）
func _my_role(me: Node) -> int:
	var stand: Node = game.hooks.feature("stand_ins")
	return int(stand.role_of("player", int(me.peer_id))) if stand != null and me != null else -1


func _name(aid: int) -> String:
	var beats := _beats()
	var name: String = str(beats.role_name(aid)) if beats != null and beats.active() else ""
	return name if name.length() > 1 else "役者%s" % ["A", "B", "C", "D"][aid]


# ---- 操作（自分の画面） ----

func hook_f(me: Node) -> bool:
	var beats := _beats()
	if beats == null:
		return false
	if _aim_aid >= 0:
		# 床を指している間の F：次の立ち位置へ
		_aim_step = (_aim_step + 1) % int(beats.step_count())
		Sfx.play("ui_select", null, -6.0)
		return true
	if int(me.held) != 0 or int(me.operating) != 0:
		return false
	var a := looked_actor(me)
	if a == null:
		return false
	var why := blocked()
	if why != "":
		game.hud.show_toast(why, game.hud.YELLOW)
		return true
	_aim_aid = int(a.aid)
	_aim_step = int(beats.teach_step(_aim_aid))
	Sfx.play("ui_select", null, -6.0)
	return true


func hook_click(me: Node) -> bool:
	if _aim_aid < 0:
		return false
	var at := _pointed(me)
	if at.is_empty():
		game.hud.show_toast("床か、物の平らな上を指して、左クリック", game.hud.YELLOW)
		return true
	h_teach.rpc_id(1, _aim_aid, _aim_step, int(at["pid"]), at["local"] as Vector3, at["world"] as Vector3, false)
	_aim_aid = -1
	return true


func hook_right_click(me: Node) -> bool:
	if _aim_aid >= 0:
		_aim_aid = -1
		Sfx.play("menu_close", null, -8.0)
		return true
	if int(me.held) != 0 or int(me.operating) != 0 or blocked() != "":
		return false
	var tape := aimed_tape(me)
	if tape.is_empty():
		return false
	h_peel.rpc_id(1, int(tape[0]), int(tape[1]))
	return true


func hook_input(event: InputEvent) -> bool:
	if _aim_aid >= 0 and event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		_aim_aid = -1
		Sfx.play("menu_close", null, -8.0)
		return true
	return false


func hook_key(event: InputEvent, me: Node) -> bool:
	if not Keybinds.pressed(event, "self_mark") or _beats() == null:
		return false
	var role := _my_role(me)
	if role < 0:
		game.hud.show_toast("足元のバミリは、自分で役を演じるときに貼る（Y で役者になる）", game.hud.YELLOW)
		return true
	var why := blocked()
	if why != "":
		game.hud.show_toast(why, game.hud.YELLOW)
		return true
	var at := _underfoot(me)
	h_teach.rpc_id(1, role, -1, int(at["pid"]), at["local"] as Vector3, at["world"] as Vector3, true)
	return true


func hook_hud(me: Node, _label: String, keys: String) -> Dictionary:
	var beats := _beats()
	if beats == null or me == null:
		return {}
	if _aim_aid >= 0:
		return {"label": "%s：立ち位置%d（床を指す）" % [_name(_aim_aid), _aim_step + 1],
			"keys_all": "左クリック ここに立って ／ F 次の立ち位置 ／ 右クリック やめる"}
	if blocked() != "" or int(me.operating) != 0:
		return {}
	if int(me.held) == 0:
		var a := looked_actor(me)
		if a != null:
			return {"label": _name(int(a.aid)), "keys_all": "F 立ち位置を教える（立ち位置%d）" % (int(beats.teach_step(int(a.aid))) + 1)}
		var tape := aimed_tape(me)
		if not tape.is_empty() and me.target == null:
			return {"label": "%sのバミリ（立ち位置%d）" % [_name(int(tape[0])), int(tape[1]) + 1], "keys_all": "右クリック はがす"}
	var role := _my_role(me)
	if role >= 0:
		return {"keys_all": "M 足元にバミリ（立ち位置%d） ／ %s" % [int(beats.teach_step(role)) + 1, keys]}
	return {}


# ---- 決める（ホスト） ----

@rpc("any_peer", "call_local", "reliable")
func h_teach(aid: int, step: int, pid: int, local: Vector3, world: Vector3, self_mark: bool) -> void:
	var beats := _beats()
	if not Net.is_host() or beats == null or aid < 0 or aid >= (game.actors as Array).size() or not world.is_finite() or not local.is_finite():
		return
	var who: int = Net.sender()
	var me: Node3D = game.players.get(who)
	if me == null:
		return
	var why := blocked()
	if why != "":
		_tell(who, why)
		return
	var a: Node = game.actors[aid]
	if self_mark:
		if _my_role(me) != aid:
			return
	elif not teachable(a) or me.global_position.distance_to(a.global_position) > TEACH_REACH:
		return
	if me.global_position.distance_to(world) > TEACH_REACH:
		return
	var n := int(beats.step_count())
	if step < 0 or step >= n:
		step = int(beats.teach_step(aid))
	if pid != 0 and not game.props.has(pid):
		pid = 0
	beats.host_teach(aid, step, pid, local, world, not self_mark)
	game.host_ev("sfx", ["fix", world])
	_tell(who, "%sの立ち位置%dを、床に貼った" % [_name(aid), step + 1] if self_mark else "%s：立ち位置%dは、ここ（床にバミリ）" % [_name(aid), step + 1], false)


@rpc("any_peer", "call_local", "reliable")
func h_peel(aid: int, step: int) -> void:
	var beats := _beats()
	if not Net.is_host() or beats == null or not beats.taught(aid, step) or blocked() != "":
		return
	var at: Vector3 = beats.spot(aid, step)
	beats.host_unteach(aid, step)
	game.host_ev("sfx", ["unfix", at])
	_tell(Net.sender(), "%sの立ち位置%dのバミリを、はがした（決まった場所に戻る）" % [_name(aid), step + 1], false)


func _tell(who: int, text: String, bad: bool = true) -> void:
	if who != multiplayer.get_unique_id() and who not in multiplayer.get_peers():
		return
	game.ev.rpc_id(who, "toast", [text, 1 if bad else 0])


# ---- テープ（全員の画面） ----

func _process(_delta: float) -> void:
	var beats := _beats()
	if beats == null:
		return
	if int(beats.spots_rev) != _rev:
		_rev = int(beats.spots_rev)
		_rebuild()
	var me: Node = game.local_player()
	if _aim_aid >= 0 and (me == null or int(me.held) != 0 or blocked() != "" or not teachable(game.actors[_aim_aid])):
		_aim_aid = -1
	_show_ghost(me)
	_first_tip()


# 初めて役者が出た（雇った役者が現場に立った）ときに、一度だけ、ひとこと
func _first_tip() -> void:
	if _told:
		return
	var flow: Node = game.production
	if flow == null or not bool(flow.daily) or int(flow.phase) not in [2, 4] or game.get("hud") == null:
		return
	for a: Node in game.actors:
		if teachable(a):
			_told = true
			game.hud.show_toast("役者を見て F → 床を左クリックで、そこが立ち位置になる（足元にバミリが貼られる）", game.hud.GREEN, 5.0)
			return


func _rebuild() -> void:
	for t: Variant in _tapes.values():
		if is_instance_valid(t):
			(t as Node).queue_free()
	_tapes = {}
	var beats := _beats()
	for aid in 4:
		for step in 3:
			if beats.taught(aid, step):
				_tapes["%d:%d" % [aid, step]] = _stick(aid, step)


# テープを1枚貼る：役の色の×と、番号を書いた切れ端
func _stick(aid: int, step: int) -> Node3D:
	var beats := _beats()
	var e: Array = beats.spots[aid][step]
	var tape := _tape_mesh(aid, step, false)
	tape.name = "Bami%s%d" % [["A", "B", "C", "D"][aid], step + 1]
	var prop: Node3D = game.props.get(int(e[0])) if int(e[0]) != 0 else null
	var holder: Node3D = prop if prop != null and is_instance_valid(prop) else root
	holder.add_child(tape)
	# 手で貼ったように、少しだけ斜め（全員の画面で同じ角度）
	var yaw := (float((aid * 7 + step * 3) % 5) - 2.0) * 0.09
	tape.global_transform = Transform3D(Basis(Vector3.UP, yaw), beats.spot(aid, step) + Vector3(0, LIFT, 0))
	return tape


func _tape_mesh(aid: int, step: int, ghost: bool) -> Node3D:
	var node := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLORS[aid]
	mat.roughness = 0.55
	if ghost:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.45
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side in [-1.0, 1.0]:
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(TAPE_LEN, 0.002, TAPE_W)
		strip.mesh = box
		strip.material_override = mat
		strip.rotation.y = side * PI * 0.25
		strip.position.y = 0.001 if side > 0 else 0.0
		node.add_child(strip)
	# 番号を書いた切れ端（×の手前。カメラの側から読める向き）
	var tab := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.11, 0.085)
	tab.mesh = plane
	tab.position = Vector3(0, 0.0025, 0.2)
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = _number(aid, step)
	tm.roughness = 0.6
	if ghost:
		tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tm.albedo_color = Color(1, 1, 1, 0.45)
		tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tab.material_override = tm
	node.add_child(tab)
	for m: Node in node.get_children():
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if ghost:
			(m as VisualInstance3D).layers = CREW_LAYER
	return node


# テープの切れ端に、黒いマーカーで書いた数字（1・2・3）。字は線で描く（浮いた文字は使わない）
const DIGITS := {
	1: [[Vector2(0.36, 0.28), Vector2(0.54, 0.12), Vector2(0.54, 0.88)], [Vector2(0.34, 0.88), Vector2(0.74, 0.88)]],
	2: [[Vector2(0.26, 0.3), Vector2(0.36, 0.15), Vector2(0.55, 0.1), Vector2(0.72, 0.2), Vector2(0.74, 0.38), Vector2(0.6, 0.55), Vector2(0.26, 0.88), Vector2(0.78, 0.88)]],
	3: [[Vector2(0.26, 0.18), Vector2(0.5, 0.1), Vector2(0.72, 0.2), Vector2(0.7, 0.4), Vector2(0.47, 0.5), Vector2(0.72, 0.6), Vector2(0.75, 0.78), Vector2(0.5, 0.9), Vector2(0.25, 0.82)]],
}


func _number(aid: int, step: int) -> ImageTexture:
	var key := "%d:%d" % [aid, step]
	if _tex.has(key):
		return _tex[key]
	var w := 68
	var h := 52
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c: Color = COLORS[aid]
	img.fill(c.lightened(0.08))
	# 切れ端の、ちぎった縁（左右の端を、少し暗く）
	for y in h:
		for x in [0, 1, w - 2, w - 1]:
			img.set_pixel(x, y, c.darkened(0.15))
	var ink := Color("1b1c20")
	var box := Rect2(Vector2(w * 0.5 - h * 0.42, h * 0.08), Vector2(h * 0.84, h * 0.84))
	for line: Array in DIGITS[step + 1]:
		for k in line.size() - 1:
			var a: Vector2 = box.position + (line[k] as Vector2) * box.size
			var b: Vector2 = box.position + (line[k + 1] as Vector2) * box.size
			var n := int(ceil(a.distance_to(b))) + 1
			for i in n + 1:
				_dot(img, a.lerp(b, float(i) / float(n)), 3.0, ink)
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


func _dot(img: Image, at: Vector2, r: float, col: Color) -> void:
	for y in range(int(at.y - r), int(at.y + r) + 1):
		for x in range(int(at.x - r), int(at.x + r) + 1):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and Vector2(x, y).distance_to(at) <= r:
				img.set_pixel(x, y, col)


# 床を指している間：指した所に、うすいテープの影（制作班にだけ見える）
func _show_ghost(me: Node) -> void:
	var at: Dictionary = _pointed(me) if _aim_aid >= 0 and me != null else {}
	if at.is_empty():
		if _ghost != null:
			_ghost.visible = false
		return
	var key := "%d:%d" % [_aim_aid, _aim_step]
	if _ghost == null or _ghost.get_meta("key", "") != key:
		if _ghost != null:
			_ghost.queue_free()
		_ghost = _tape_mesh(_aim_aid, _aim_step, true)
		_ghost.set_meta("key", key)
		root.add_child(_ghost)
	_ghost.visible = true
	_ghost.global_position = (at["world"] as Vector3) + Vector3(0, LIFT * 2.0, 0)
