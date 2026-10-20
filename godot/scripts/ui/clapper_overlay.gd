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
const RECOIL_UP := 0.2            # カチンの反動で跳ねる高さ（m）
const RECOIL_SEC := 0.14          # 跳ね上がる時間
const GRAVITY := 9.0              # 落ちる速さ（m/秒²。画面の上の大きさに合わせた値）
const LINE_Y := 0.33              # 板の上の端から、横の罫線まで
const FILM_PX := 120              # 題名の字の大きさ（長い題名は、板の幅に入るように小さくする）
const PX := 0.0012                # 字の1ピクセルの大きさ（m）
# 本番中の上下の黒い帯（映画の横長の画面）。カチンコが落ち始めたら閉じてきて、カットで開く。
# 太さは、上のカメラの枠の帯と、下の操作の札が、ちょうど中に収まる太さ
const BARS := 0.11                # 画面の高さに対する、帯1本の太さ
const BARS_DELAY := 0.19          # 本番になってから閉じ始めるまで（カチンの反動のぶん）
const BARS_IN := 0.35
const BARS_OUT := 0.3

var game: Node
var mode := ""
var take := 1
var t := 0.0
var _placed := false              # ready で入ってきて、止まっている
var _view: SubViewport
var _box: SubViewportContainer
var _rig: Node3D
var _stick: Node3D
var _labels := {}
var _rolling_t := 0.0             # 本番になってからの秒（帯の出し入れ）
var _bars := 0.0                  # 0＝帯なし、1＝閉じきった


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
	_box_mesh(_rig, Vector3(BOARD.x - 0.08, 0.008, 0.002), Vector3(0, top - LINE_Y, 0.031), chalk)
	_box_mesh(_rig, Vector3(0.008, BOARD.y - LINE_Y - 0.04, 0.002), Vector3(0, top - LINE_Y - (BOARD.y - LINE_Y - 0.04) * 0.5, 0.031), chalk)
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
	_labels["company"] = _text("格安アクション映画制作班", Vector3(x0, top - 0.05, 0.034), 60, Color(0.85, 0.85, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	_labels["film"] = _text("", Vector3(x0, top - 0.135, 0.034), FILM_PX, Color(0.97, 0.97, 0.93), HORIZONTAL_ALIGNMENT_LEFT)
	_labels["take_cap"] = _text("TAKE", Vector3(x0, top - LINE_Y - 0.035, 0.034), 58, Color(0.85, 0.85, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	_labels["take"] = _text("1", Vector3(-BOARD.x * 0.25, top - LINE_Y - 0.1, 0.034), 380, Color(0.97, 0.97, 0.93), HORIZONTAL_ALIGNMENT_CENTER)
	_labels["right_cap"] = _text("", Vector3(0.09, top - LINE_Y - 0.035, 0.034), 58, Color(0.85, 0.85, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT)
	_labels["right"] = _text("", Vector3(BOARD.x * 0.25, top - LINE_Y - 0.12, 0.034), 300, UI.TAPE, HORIZONTAL_ALIGNMENT_CENTER)


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
	l.pixel_size = PX
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
	var film: String = str(game.film_title()) if game != null and game.has_method("film_title") else "月下の城と大爆発"
	_labels["film"].text = film
	_labels["film"].font_size = mini(FILM_PX, int((BOARD.x - 0.2) / PX / maxf(1.0, float(film.length()))))
	_labels["take"].text = str(take)
	_box.visible = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _process(delta: float) -> void:
	_update_bars(delta)
	if mode == "":
		return
	t += delta
	var vp := get_viewport_rect().size
	var aspect := vp.x / maxf(1.0, vp.y)
	var off := Vector3.ZERO           # 止まる場所からのずれ
	var rot := Vector3.ZERO           # x＝前後に倒れる・y＝左右に振れる（奥行きの回転）・z＝画面の中での傾き
	var angle := OPEN
	var done := false
	match mode:
		"ready":
			var k := clampf(t / ENTER, 0.0, 1.0)
			var pose := _enter_pose(k, aspect)
			off = pose[0]
			rot = pose[1]
			angle = lerpf(0.0, OPEN, _ease_out(k))
			if k >= 1.0:
				_placed = true
				# ため：数字が減るほど、拍子木を少しずつ高く上げる。板はゆっくり奥行きの方向に揺れる（3D の板だと分かるように）
				var left := float(game.countdown_t) if game != null and "countdown_t" in game else 1.0
				angle = OPEN + 0.07 * (1.0 - clampf(left / 3.0, 0.0, 1.0)) + 0.015 * sin(t * 9.0)
				rot += Vector3(0.025 * sin(t * 2.3), 0.04 * sin(t * 1.7), 0.0)
			_set_right("本番まで", str(int(ceil(float(game.countdown_t)))) if game != null and "countdown_t" in game else "", UI.TAPE)
		"clap", "cut_clap", "cut":
			var lead := 0.0 if mode == "clap" else 0.32
			if lead > 0.0:
				var k2 := clampf(t / lead, 0.0, 1.0)
				var pose2 := _enter_pose(k2, aspect)
				off = pose2[0]
				rot = pose2[1]
				angle = lerpf(0.0, OPEN, _ease_out(k2))
			var shut := lead + (0.12 if mode != "clap" else 0.0)
			if t >= shut:
				var s := clampf((t - shut) / 0.05, 0.0, 1.0)
				angle = lerpf(OPEN + 0.07, 0.0, s * s)
			# カチンの反動：閉じた勢いで、板が少し上へ跳ねる（上の端が奥へ倒れる）。跳ね切ったら、そこから自由落下
			var hit := shut + 0.05
			if t >= hit:
				var k3 := clampf((t - hit) / RECOIL_SEC, 0.0, 1.0)
				off.y += RECOIL_UP * _ease_out(k3)
				rot.x += -0.2 * sin(k3 * PI * 0.5)
				if k3 >= 1.0:
					var ft := t - hit - RECOIL_SEC          # 落ち始めてからの秒。頂点なので、はじめの速さは 0
					off.y -= 0.5 * GRAVITY * ft * ft
					off.x += 0.3 * ft
					rot += Vector3(1.5 * ft, 0.8 * ft, -0.4 * ft)   # 落ちながら、前へ倒れて回る
					done = off.y < -2.9
			if mode == "cut":
				_set_right("", "カット", UI.TAPE)
			else:
				_set_right("", "本番", UI.STAMP_RED)
	_rig.position = Vector3(0, -0.17, 0) + off
	_rig.scale = Vector3.ONE * 0.92          # 拍子木を開いても、上の帯にかからない大きさ
	_rig.rotation = rot
	_stick.rotation.z = angle
	if done:
		mode = ""
		_placed = false
		_box.visible = false
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED


# 入ってくるときの位置と向き（k：0＝画面の左下の外、1＝止まる所）。奥へ寝た板が、起き上がりながら手前へ回ってくる
func _enter_pose(k: float, aspect: float) -> Array:
	var e := _ease_out_back(k)
	var from := Vector3(-2.3 * aspect / 1.78, -2.1, 0.3)
	return [from.lerp(Vector3.ZERO, e), Vector3(lerpf(-0.75, 0.0, e), lerpf(0.95, 0.0, e), lerpf(0.55, 0.0, e))]


func _update_bars(delta: float) -> void:
	var rolling: bool = game != null and "state" in game and game.state == game.S.TAKE and not game.replaying
	var before := _bars
	if rolling:
		_rolling_t += delta
		_bars = minf(1.0, maxf(_bars, (_rolling_t - BARS_DELAY) / BARS_IN)) if _rolling_t > BARS_DELAY else _bars
	else:
		_rolling_t = 0.0
		_bars = maxf(0.0, _bars - delta / BARS_OUT)
	if _bars != before:
		queue_redraw()


# 帯はカチンコ（子の3D）より奥に描かれる。上の帯の中にカメラの枠の帯、下の帯の中に操作の札が来る
func _draw() -> void:
	if _bars <= 0.0:
		return
	var e := _bars * _bars * (3.0 - 2.0 * _bars)
	var h := size.y * BARS * e
	draw_rect(Rect2(0, 0, size.x, h), Color.BLACK)
	draw_rect(Rect2(0, size.y - h, size.x, h), Color.BLACK)


func _set_right(caption: String, big: String, col: Color) -> void:
	var cap: Label3D = _labels["right_cap"]
	var r: Label3D = _labels["right"]
	if cap.text != caption:
		cap.text = caption
	if r.text != big:
		r.text = big
		r.font_size = 300 if big.length() <= 1 else (230 if big.length() == 2 else 190)
	r.modulate = col


static func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


# 少し行き過ぎて戻る（止まるときの「どん」）
static func _ease_out_back(k: float) -> float:
	var c := 1.4
	var x := k - 1.0
	return 1.0 + (c + 1.0) * x * x * x + c * x * x
