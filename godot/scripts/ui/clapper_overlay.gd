extends Control
## 本番の合図のカチンコ（画面の上に重ねる3D。2026-10-20 ユーザーの希望で、平らな絵から作り直した）：
##   ・ready（カウントダウン）：画面の左下から、拍子木を開きながら斜めに入ってきて、まっすぐ大きく止まる。数字が減る間ためる
##   ・clap（本番）：拍子木が「カチン」と閉じて揺れ、下へ落ちて消える
##   ・cut（カット）：短く入ってきて、すぐ閉じる
## 形は画面に合わせた横長（板 1.9 × 1.12）。ゲームの世界とは別の小さな3Dの場（own_world_3d）で描く。
## 使い方は前の2Dの版と同じ（hud.gd の slate.start(mode, take)・slate.mode）
const UI := preload("res://scripts/ui/ui_theme.gd")
const BOARD := Vector2(1.9, 1.12)
const STICK_H := 0.17
const OPEN := 0.27                # 拍子木の開き（ラジアン）
const ENTER := 0.5                # 入ってくる時間

var game: Node
var mode := ""
var take := 1
var t := 0.0
var _placed := false              # ready で入ってきて、止まっている
var _shake := 0.0
var _view: SubViewport
var _box: SubViewportContainer
var _rig: Node3D
var _stick: Node3D
var _labels := {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = SubViewportContainer.new()
	_box.stretch = true
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	add_child(_box)
	_view = SubViewport.new()
	_view.transparent_bg = true
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_box.add_child(_view)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 4.0)
	cam.fov = 32.0
	_view.add_child(cam)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.55
	_view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.5, -0.45, 0)
	sun.light_energy = 1.1
	_view.add_child(sun)
	_build()


func _build() -> void:
	_rig = Node3D.new()
	_view.add_child(_rig)
	var black := _mat(Color("17181a"), 0.85)
	var metal := _mat(Color("b9bdc2"), 0.35, 0.8)
	var chalk := StandardMaterial3D.new()
	chalk.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	chalk.albedo_color = Color(0.95, 0.95, 0.9, 0.8)
	chalk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var stripes := StandardMaterial3D.new()
	stripes.albedo_texture = _stripe_texture()
	stripes.roughness = 0.6
	# 板（上の端が y = BOARD.y * 0.5 - 0.1）
	var top := BOARD.y * 0.5 - 0.1
	_box_mesh(_rig, Vector3(BOARD.x, BOARD.y, 0.06), Vector3(0, -0.1, 0), black)
	# 板のチョークの罫線
	_box_mesh(_rig, Vector3(BOARD.x - 0.08, 0.008, 0.002), Vector3(0, top - 0.42, 0.031), chalk)
	_box_mesh(_rig, Vector3(0.008, BOARD.y - 0.46, 0.002), Vector3(0, top - 0.42 - (BOARD.y - 0.46) * 0.5, 0.031), chalk)
	# 下の拍子木（板に付いている）と、上の拍子木（左端の蝶番で開く）
	_box_mesh(_rig, Vector3(BOARD.x, STICK_H, 0.07), Vector3(0, top + STICK_H * 0.5, 0), stripes)
	_stick = Node3D.new()
	_stick.position = Vector3(-BOARD.x * 0.5, top + STICK_H, 0)
	_rig.add_child(_stick)
	_box_mesh(_stick, Vector3(BOARD.x, STICK_H, 0.07), Vector3(BOARD.x * 0.5, STICK_H * 0.5, 0), stripes)
	var hinge := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.045
	cyl.height = 0.1
	hinge.mesh = cyl
	hinge.material_override = metal
	hinge.rotation = Vector3(PI * 0.5, 0, 0)
	hinge.position = _stick.position + Vector3(0.05, 0, 0)
	_rig.add_child(hinge)
	# チョークの字
	var x0 := -BOARD.x * 0.5 + 0.09
	_labels["company"] = _text("格安アクション映画制作班", Vector3(x0, top - 0.1, 0.034), 30, Color(0.85, 0.85, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	_labels["film"] = _text("", Vector3(x0, top - 0.27, 0.034), 52, Color(0.97, 0.97, 0.93), HORIZONTAL_ALIGNMENT_LEFT)
	_labels["take_cap"] = _text("TAKE", Vector3(x0, top - 0.52, 0.034), 30, Color(0.85, 0.85, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	_labels["take"] = _text("1", Vector3(-BOARD.x * 0.25, top - 0.62, 0.034), 190, Color(0.97, 0.97, 0.93), HORIZONTAL_ALIGNMENT_CENTER)
	_labels["right_cap"] = _text("", Vector3(0.09, top - 0.52, 0.034), 30, Color(0.85, 0.85, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	_labels["right"] = _text("", Vector3(BOARD.x * 0.25, top - 0.64, 0.034), 150, UI.TAPE, HORIZONTAL_ALIGNMENT_CENTER)


func _mat(col: Color, rough: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metallic
	return m


func _box_mesh(parent: Node3D, s: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _text(s: String, at: Vector3, px: int, col: Color, align: int) -> Label3D:
	var l := Label3D.new()
	l.text = s
	l.font = FilmSet.font("marker")
	l.font_size = px
	l.pixel_size = 0.0012
	l.modulate = col
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.position = at
	_rig.add_child(l)
	return l


# 拍子木の斜めの白黒（板の幅に7本）
static func _stripe_texture() -> ImageTexture:
	var w := 512
	var h := 46
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var period := float(w) / 7.0
	for y in h:
		for x in w:
			var u := fmod(float(x) + float(h - y) * 0.9, period) / period
			img.set_pixel(x, y, Color("f2f0ea") if u < 0.5 else Color("141414"))
	return ImageTexture.create_from_image(img)


func start(m: String, n: int) -> void:
	if m == "clap" and not _placed:
		m = "cut_clap"            # 入ってくるところを見ていない（途中から入った人など）：入って、すぐ閉じる
	mode = m
	take = n
	t = 0.0
	if m == "ready":
		_placed = false
	_labels["film"].text = str(game.film_title()) if game != null and game.has_method("film_title") else "月下の城と大爆発"
	_labels["take"].text = str(take)
	_box.visible = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _process(delta: float) -> void:
	if mode == "":
		return
	t += delta
	var vp := get_viewport_rect().size
	var aspect := vp.x / maxf(1.0, vp.y)
	var off := Vector3.ZERO           # 止まる場所からのずれ
	var rz := 0.0
	var ry := 0.0
	var angle := OPEN
	var done := false
	var enter_from := Vector3(-2.3 * aspect / 1.78, -2.1, 0.3)
	match mode:
		"ready":
			var k := clampf(t / ENTER, 0.0, 1.0)
			var e := _ease_out_back(k)
			off = enter_from.lerp(Vector3.ZERO, e)
			rz = lerpf(0.55, 0.0, e)
			ry = lerpf(0.4, 0.0, e)
			angle = lerpf(0.0, OPEN, _ease_out(k))
			if k >= 1.0:
				_placed = true
				# ため：数字が減るほど、拍子木を少しずつ高く上げる
				var left := float(game.countdown_t) if game != null and "countdown_t" in game else 1.0
				angle = OPEN + 0.07 * (1.0 - clampf(left / 3.0, 0.0, 1.0)) + 0.015 * sin(t * 9.0)
			_set_right("本番まで", str(int(ceil(float(game.countdown_t)))) if game != null and "countdown_t" in game else "", UI.TAPE)
		"clap", "cut_clap", "cut":
			var lead := 0.0 if mode == "clap" else 0.32
			if lead > 0.0:
				var k2 := clampf(t / lead, 0.0, 1.0)
				var e2 := _ease_out_back(k2)
				off = enter_from.lerp(Vector3.ZERO, e2)
				rz = lerpf(0.55, 0.0, e2)
				ry = lerpf(0.4, 0.0, e2)
				angle = lerpf(0.0, OPEN, _ease_out(k2))
			var shut := lead + (0.12 if mode != "clap" else 0.0)
			if t >= shut:
				var s := clampf((t - shut) / 0.05, 0.0, 1.0)
				angle = lerpf(OPEN + 0.07, 0.0, s * s)
				if s >= 1.0 and _shake <= 0.0 and t < shut + 0.06:
					_shake = 1.0
			var leave := shut + 0.5
			if t > leave:
				var q := clampf((t - leave) / 0.32, 0.0, 1.0)
				off += Vector3(0.0, -2.6 * q * q, 0.0)
				rz += -0.25 * q * q
				done = q >= 1.0
			if mode == "cut":
				_set_right("", "カット", UI.TAPE)
			else:
				_set_right("", "本番", UI.STAMP_RED)
	# 閉じた瞬間の揺れ
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 4.5)
		off += Vector3(sin(t * 70.0) * 0.03, cos(t * 55.0) * 0.025, 0) * _shake
		rz += sin(t * 60.0) * 0.012 * _shake
	_rig.position = Vector3(0, -0.17, 0) + off
	_rig.scale = Vector3.ONE * 0.92          # 拍子木を開いても、上の帯にかからない大きさ
	_rig.rotation = Vector3(0, ry, rz)
	_stick.rotation.z = angle
	if done:
		mode = ""
		_placed = false
		_box.visible = false
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _set_right(caption: String, big: String, col: Color) -> void:
	var cap: Label3D = _labels["right_cap"]
	var r: Label3D = _labels["right"]
	if cap.text != caption:
		cap.text = caption
	if r.text != big:
		r.text = big
		r.font_size = 150 if big.length() <= 1 else 120
	r.modulate = col


static func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


# 少し行き過ぎて戻る（止まるときの「どん」）
static func _ease_out_back(k: float) -> float:
	var c := 1.4
	var x := k - 1.0
	return 1.0 + (c + 1.0) * x * x * x + c * x * x
