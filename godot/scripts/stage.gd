extends Node3D
# 撮影現場（倉庫）と、そこに置く物の生成。
# 物は決まった順番で作るので、どの参加者の画面でも同じIDになる。

const Carton := preload("res://scripts/carton.gd")
const Prop := preload("res://scripts/prop.gd")
const FilmCamera := preload("res://scripts/film_camera.gd")
const SpotRig := preload("res://scripts/spot_rig.gd")
const FxBox := preload("res://scripts/fx_box.gd")
const Actor := preload("res://scripts/actor.gd")
const Clapper := preload("res://scripts/clapper.gd")
const Truck := preload("res://scripts/truck.gd")
const BoomFlat := preload("res://scripts/boom_flat.gd")

const ROOM := Vector2(34.0, 24.0)
const WALL_H := 6.0

# 素材から作る物。shapes を省くと全体を囲む箱ひとつ。
const DEFS := {
	"balcony": {"file": "S016_balcony_module", "label": "バルコニー", "mass": 40.0, "tags": ["castle"],
		"shapes": [[Vector3(0, 0.76, 0), Vector3(2.6, 0.18, 1.4), false],
			[Vector3(-1.0, 0.34, 0), Vector3(0.15, 0.67, 1.3), false], [Vector3(1.0, 0.34, 0), Vector3(0.15, 0.67, 1.3), false],
			[Vector3(0, 1.38, 0.62), Vector3(2.6, 1.0, 0.08), true],
			[Vector3(-1.22, 1.38, 0), Vector3(0.08, 1.0, 1.4), true], [Vector3(1.22, 1.38, 0), Vector3(0.08, 1.0, 1.4), true]]},
	"window": {"file": "S007_arched_window", "label": "アーチ窓の壁", "mass": 30.0, "tags": ["castle"], "one_sided": true},
	"ruin": {"file": "S073_ruined_stone_wall", "label": "遺跡の壁", "mass": 26.0, "tags": ["castle"], "one_sided": true},
	"flat": {"file": "scenic_flat", "label": "書割（城の胸壁）", "mass": 6.0, "tags": ["castle"], "one_sided": true},
	"rock": {"file": "foam_rock", "label": "発泡スチロールの岩", "mass": 3.0},
	"applebox": {"file": "P069_apple_box", "label": "箱馬", "mass": 5.0},
	"sandbag": {"file": "P068_sandbag", "label": "サンドバッグ", "mass": 12.0},
	"basket": {"file": "P070_prop_basket", "label": "小道具かご", "mass": 2.0},
	"rose": {"file": "promise_rose", "label": "約束のバラ", "mass": 0.4},
	"letter": {"file": "P001_love_letter", "label": "恋文", "mass": 0.2},
	"crown": {"file": "P027_paper_crown", "label": "紙の王冠", "mass": 0.3},
	"fish": {"file": "P039_rubber_fish", "label": "ゴムの魚", "mass": 0.5},
	"filmcan": {"file": "P057_film_can", "label": "フィルム缶", "mass": 0.8},
	"tape": {"file": "P067_gaffer_tape", "label": "養生テープ", "mass": 0.3},
	# 実物寄りの機材（小物フォルダ）
	"partition": {"dir": "gear", "file": "P03_Folding_Partition", "label": "折りたたみパーテーション", "mass": 12.0},
	"greenscreen": {"dir": "gear", "file": "GS06_Portable_Greenscreen", "label": "グリーンバック", "mass": 10.0,
		"shapes": [[Vector3(0, 1.05, 0), Vector3(2.8, 2.0, 0.06), false],
			[Vector3(-1.32, 0.05, 0.12), Vector3(0.9, 0.1, 0.78), false], [Vector3(1.32, 0.05, 0.12), Vector3(0.9, 0.1, 0.78), false]]},
	"dolly": {"dir": "gear", "file": "D04_Compact_Floor_Dolly", "label": "台車", "mass": 20.0, "rolls": true, "scale": 2.0,
		"shapes": [[Vector3(0, 0.16, 0), Vector3(0.92, 0.32, 1.2), false]]},
	"boom": {"dir": "gear", "file": "B05_Boom_Microphone_Kit", "label": "ガンマイク", "mass": 2.0, "extra": "B05_Optional_Windjammer"},
	"recorder": {"dir": "gear", "file": "AR04_Field_Recorder", "label": "録音機", "mass": 1.0},
	"carton": {"dir": "gear", "file": "carton", "label": "段ボール箱", "mass": 1.5, "scale": 2.0},
}

var game: Node
var _next_id := 1


func build() -> void:
	_build_room()
	_spawn_equipment()
	_spawn_storage()
	_spawn_actors()


# ---- 倉庫 ----

func _build_room() -> void:
	# 倉庫の照明：天井からの作業灯（影つき）と、弱い環境光。
	# 撮影カメラ側は露出を下げて見るので、同じ光が「夜の薄明かり」に写る。
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.03, 0.035, 0.045)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.72, 0.78, 0.92)
	e.ambient_light_energy = 0.48
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_white = 6.0
	e.ssao_enabled = true
	e.ssao_radius = 0.9
	e.ssao_intensity = 2.4
	e.ssil_enabled = true
	e.glow_enabled = true
	e.glow_intensity = 0.25
	e.glow_hdr_threshold = 1.6
	env.environment = e
	add_child(env)
	var work := DirectionalLight3D.new()
	work.rotation_degrees = Vector3(-58, 32, 0)
	work.light_energy = 1.2
	work.light_color = Color(1.0, 0.96, 0.9)
	work.shadow_enabled = true
	work.light_angular_distance = 2.0
	work.shadow_blur = 1.6
	work.directional_shadow_max_distance = 48.0
	work.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(work)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, -140, 0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.75, 0.85, 1.0)
	fill.shadow_enabled = false
	add_child(fill)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.42, 0.42, 0.44)
	floor_mat.roughness = 0.92
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var nt := NoiseTexture2D.new()
	nt.noise = noise
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var grad := Gradient.new()
	grad.set_color(0, Color(0.72, 0.72, 0.72))
	grad.set_color(1, Color(1, 1, 1))
	nt.color_ramp = grad
	floor_mat.albedo_texture = nt
	floor_mat.uv1_scale = Vector3(8, 8, 8)
	_static_box(Vector3(0, -0.5, 0), Vector3(ROOM.x, 1.0, ROOM.y), floor_mat)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.3, 0.32, 0.36)
	wall_mat.roughness = 0.95
	var hx := ROOM.x * 0.5
	var hz := ROOM.y * 0.5
	_static_box(Vector3(0, WALL_H * 0.5, -hz - 0.25), Vector3(ROOM.x + 1, WALL_H, 0.5), wall_mat)
	_static_box(Vector3(0, WALL_H * 0.5, hz + 0.25), Vector3(ROOM.x + 1, WALL_H, 0.5), wall_mat)
	_static_box(Vector3(-hx - 0.25, WALL_H * 0.5, 0), Vector3(0.5, WALL_H, ROOM.y), wall_mat)
	# 東の壁には搬入口を開ける（軽トラが頭を外に出して停まる）
	_static_box(Vector3(hx + 0.25, WALL_H * 0.5, -3.7), Vector3(0.5, WALL_H, 16.6), wall_mat)
	_static_box(Vector3(hx + 0.25, WALL_H * 0.5, 10.2), Vector3(0.5, WALL_H, 3.6), wall_mat)
	_static_box(Vector3(hx + 0.25, 4.4, 6.5), Vector3(0.5, 3.2, 3.8), wall_mat)
	var outside := StandardMaterial3D.new()
	outside.albedo_color = Color(0.16, 0.17, 0.19)
	outside.roughness = 1.0
	_static_box(Vector3(hx + 5.0, -0.5, 6.5), Vector3(10.0, 1.0, 10.0), outside)
	_static_box(Vector3(hx + 10.25, 2.0, 6.5), Vector3(0.5, 5.0, 10.0), outside)
	_static_box(Vector3(hx + 5.0, 2.0, 1.25), Vector3(10.0, 5.0, 0.5), outside)
	_static_box(Vector3(hx + 5.0, 2.0, 11.75), Vector3(10.0, 5.0, 0.5), outside)

	# 撮影エリアの目印（床のテープ）
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(0.95, 0.78, 0.15)
	tape.roughness = 0.8
	for seg: Array in [[Vector3(0, 0.006, -8), Vector3(12, 0.01, 0.08)], [Vector3(0, 0.006, 3), Vector3(12, 0.01, 0.08)],
			[Vector3(-6, 0.006, -2.5), Vector3(0.08, 0.01, 11)], [Vector3(6, 0.006, -2.5), Vector3(0.08, 0.01, 11)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = seg[1]
		mi.mesh = bm
		mi.material_override = tape
		mi.position = seg[0]
		add_child(mi)
	_sign("廃材置き場", Vector3(-16.7, 3.4, 0), PI * 0.5, Color(1, 0.85, 0.4))
	_sign("搬入口", Vector3(16.7, 3.7, 6.5), -PI * 0.5, Color(0.7, 1.0, 0.8))


func _static_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = Prop.L_WORLD
	sb.collision_mask = 0
	sb.position = pos
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	sb.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	sb.add_child(mi)
	add_child(sb)


func _sign(text: String, pos: Vector3, yaw: float, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = game.font
	l.font_size = 160
	l.pixel_size = 0.006
	l.modulate = col
	l.outline_size = 24
	l.position = pos
	l.rotation.y = yaw
	add_child(l)


# ---- 物の生成 ----

func _register(p: RigidBody3D, pos: Vector3, yaw: float) -> RigidBody3D:
	p.game = game
	p.pid = _next_id
	_next_id += 1
	p.name = "Prop%02d_%s" % [p.pid, p.kind]
	p.position = pos
	p.rotation.y = yaw
	add_child(p)
	game.props[p.pid] = p
	return p


func spawn(kind: String, pos: Vector3, yaw: float = 0.0) -> RigidBody3D:
	var d: Dictionary = DEFS[kind]
	var p: RigidBody3D = Carton.new() if kind == "carton" else Prop.new()
	p.kind = kind
	p.label = d["label"]
	p.mass = d["mass"]
	p.tags = d.get("tags", [])
	p.one_sided = d.get("one_sided", false)
	p.visual = (load("res://assets/%s/%s.glb" % [d.get("dir", "props"), d["file"]]) as PackedScene).instantiate()
	p.add_child(p.visual)
	if d.has("extra"):
		p.visual.add_child((load("res://assets/%s/%s.glb" % [d.get("dir", "props"), d["extra"]]) as PackedScene).instantiate())
	var size_scale: float = d.get("scale", 1.0)
	var box := merged_aabb(p.visual)
	p.visual.scale *= size_scale
	box = AABB(box.position * size_scale, box.size * size_scale)
	p.center = box.get_center()
	p.half = box.size * 0.5
	p.hold_min = maxf(1.1, p.half.z + 0.95)
	if kind == "carton":
		p.configure()
	elif d.has("shapes"):
		for s: Array in d["shapes"]:
			_shape(p, s[0] * size_scale, s[1] * size_scale, s[2])
	else:
		_shape(p, box.get_center(), box.size * 0.97, false)
	if p.mass >= 20.0:
		p.angular_damp = 2.0
	if d.get("rolls", false):
		# 台車：倒れず、押す人のほうへ取っ手を向けて転がす
		p.rolls = true
		p.carry_yaw = PI
		p.hold_min = maxf(1.5, p.half.z + 0.65)
		p.axis_lock_angular_x = true
		p.axis_lock_angular_z = true
		p.angular_damp = 4.0
		p.linear_damp = 1.5
		p.deck_top = 0.32 * size_scale
		p.deck_half = Vector2(0.5, 0.66) * size_scale
	return _register(p, pos, yaw)


func _shape(p: RigidBody3D, c: Vector3, size: Vector3, thin: bool) -> void:
	if thin:
		# 手すり：体は通さないが、カメラや光は遮らない
		var sb := StaticBody3D.new()
		sb.collision_layer = Prop.L_THIN
		sb.collision_mask = 0
		var cs2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = size
		cs2.shape = b2
		sb.add_child(cs2)
		sb.position = c
		p.add_child(sb)
		return
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = c
	p.add_child(cs)


static func merged_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var t: Transform3D = it[1]
		if node is Node3D and node != root:
			t = t * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var b: AABB = t * (node as MeshInstance3D).mesh.get_aabb()
			out = b if first else out.merge(b)
			first = false
		for c in node.get_children():
			stack.push_back([c, t])
	return out


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _mat(col: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	return m


# 廃板：片面だけ城の石積みを塗ったベニヤ。軽くて倒れやすい
func spawn_plywood(pos: Vector3, yaw: float) -> RigidBody3D:
	var p: RigidBody3D = Prop.new()
	p.kind = "plywood"
	p.label = "廃板（片面だけ城）"
	p.mass = 7.0
	p.tags = ["castle"]
	p.one_sided = true
	var w := 1.5
	var h := 2.5
	p.center = Vector3(0, h * 0.5, -0.15)
	p.half = Vector3(w * 0.5, h * 0.5, 0.35)
	p.hold_min = 1.5
	p.visual = Node3D.new()
	p.add_child(p.visual)
	var front := StandardMaterial3D.new()
	front.albedo_texture = _brick_texture()
	front.roughness = 0.9
	var fm := BoxMesh.new()
	fm.size = Vector3(w, h, 0.02)
	_mesh(p.visual, fm, Vector3(0, h * 0.5, 0.012), front)
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, 0.02)
	_mesh(p.visual, bm, Vector3(0, h * 0.5, -0.008), _mat(Color(0.74, 0.6, 0.4)))
	var wood := _mat(Color(0.55, 0.42, 0.27))
	for sx: float in [-0.5, 0.5]:
		var foot := BoxMesh.new()
		foot.size = Vector3(0.07, 0.05, 0.7)
		_mesh(p.visual, foot, Vector3(sx, 0.025, -0.3), wood)
		var brace := BoxMesh.new()
		brace.size = Vector3(0.05, 1.25, 0.05)
		var bi := _mesh(p.visual, brace, Vector3(sx, 0.55, -0.3), wood)
		bi.rotation.x = -0.52
	var tape := BoxMesh.new()
	tape.size = Vector3(0.5, 0.09, 0.004)
	var ti := _mesh(p.visual, tape, Vector3(0.2, 1.6, -0.02), _mat(Color(0.75, 0.75, 0.7)))
	ti.rotation.z = 0.5
	_shape(p, Vector3(0, h * 0.5, 0), Vector3(w, h, 0.05), false)
	_shape(p, Vector3(0, 0.03, -0.3), Vector3(1.1, 0.06, 0.7), false)
	p.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	p.center_of_mass = Vector3(0, 0.7, -0.12)
	return _register(p, pos, yaw)


func _brick_texture() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	img.fill(Color(0.2, 0.2, 0.22))
	var rows := 10
	var bh := 256 / rows
	for r in rows:
		var off := 16 if r % 2 == 1 else 0
		var x := -off
		while x < 256:
			var bw := 44 + rng.randi_range(-6, 10)
			var c := Color.from_hsv(0.6 + rng.randf_range(-0.03, 0.03), 0.12, rng.randf_range(0.5, 0.72))
			img.fill_rect(Rect2i(maxi(x + 2, 0), r * bh + 2, mini(bw - 3, 255 - maxi(x + 2, 0)), bh - 3), c)
			x += bw
	return ImageTexture.create_from_image(img)


# 足場：無料で高さを作る箱
func spawn_riser(pos: Vector3, yaw: float) -> RigidBody3D:
	var p: RigidBody3D = Prop.new()
	p.kind = "riser"
	p.label = "足場（木箱）"
	p.mass = 24.0
	var size := Vector3(1.8, 0.9, 1.1)
	p.center = Vector3(0, size.y * 0.5, 0)
	p.half = size * 0.5
	p.hold_min = 1.6
	p.angular_damp = 2.0
	p.visual = Node3D.new()
	p.add_child(p.visual)
	var bm := BoxMesh.new()
	bm.size = size
	_mesh(p.visual, bm, p.center, _mat(Color(0.62, 0.48, 0.3)))
	var trim := BoxMesh.new()
	trim.size = Vector3(size.x + 0.02, 0.06, size.z + 0.02)
	_mesh(p.visual, trim, Vector3(0, size.y - 0.03, 0), _mat(Color(0.45, 0.33, 0.2)))
	_shape(p, p.center, size, false)
	return _register(p, pos, yaw)


# 月：丸いがらくたに黄色い布。少しだけ周りを照らす
func spawn_moon(pos: Vector3, yaw: float) -> RigidBody3D:
	var p: RigidBody3D = Prop.new()
	p.kind = "moon"
	p.label = "がらくたの月"
	p.mass = 6.0
	p.tags = ["moon"]
	p.center = Vector3(0, 3.0, 0)
	p.half = Vector3(0.55, 0.55, 0.2)
	p.hold_min = 1.5
	p.angular_damp = 3.0
	p.visual = Node3D.new()
	p.add_child(p.visual)
	var metal := _mat(Color(0.25, 0.25, 0.27), 0.5)
	var base := CylinderMesh.new()
	base.top_radius = 0.4
	base.bottom_radius = 0.45
	base.height = 0.08
	_mesh(p.visual, base, Vector3(0, 0.04, 0), metal)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.03
	pole.bottom_radius = 0.03
	pole.height = 2.5
	_mesh(p.visual, pole, Vector3(0, 1.3, 0), metal)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.95, 0.7)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.93, 0.62)
	glow.emission_energy_multiplier = 5.0
	var disc := SphereMesh.new()
	disc.radius = 0.55
	disc.height = 1.1
	var di := _mesh(p.visual, disc, Vector3(0, 3.0, 0), glow)
	di.scale = Vector3(1, 1, 0.25)
	var ol := OmniLight3D.new()
	ol.position = Vector3(0, 3.0, 0.4)
	ol.light_color = Color(0.8, 0.85, 1.0)
	ol.light_energy = 2.5
	ol.omni_range = 6.0
	p.add_child(ol)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.45
	cy.height = 0.3
	cs.shape = cy
	cs.position = Vector3(0, 0.15, 0)
	p.add_child(cs)
	_shape(p, Vector3(0, 1.4, 0), Vector3(0.1, 2.4, 0.1), false)
	_shape(p, Vector3(0, 3.0, 0), Vector3(1.0, 1.0, 0.25), false)
	p.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	p.center_of_mass = Vector3(0, 0.4, 0)
	game.moons.append(p)
	return _register(p, pos, yaw)


# 役者の立ち位置の印（バミリ）
func spawn_mark(index: int, pos: Vector3) -> RigidBody3D:
	var p: RigidBody3D = Prop.new()
	p.kind = "mark"
	p.label = "立ち位置の印 %s" % ["A", "B"][index]
	p.mass = 1.5
	p.center = Vector3(0, 0.03, 0)
	p.half = Vector3(0.3, 0.05, 0.3)
	p.hold_min = 1.2
	p.angular_damp = 6.0
	p.axis_lock_angular_x = true
	p.axis_lock_angular_z = true
	p.visual = Node3D.new()
	p.add_child(p.visual)
	var col: Color = [Color(1.0, 0.45, 0.6), Color(0.4, 0.7, 1.0)][index]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.5
	var disc := CylinderMesh.new()
	disc.top_radius = 0.3
	disc.bottom_radius = 0.3
	disc.height = 0.04
	_mesh(p.visual, disc, Vector3(0, 0.02, 0), m)
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = 0.3
	cy.height = 0.06
	cs.shape = cy
	cs.position = Vector3(0, 0.03, 0)
	p.add_child(cs)
	_register(p, pos, 0.0)
	p.collision_layer = Prop.L_MARK
	p.collision_mask = Prop.L_WORLD | Prop.L_PROP
	return p


func _spawn_equipment() -> void:
	var truck: RigidBody3D = Truck.new()
	truck.build()
	_register(truck, Vector3(16.3, 0, 6.5), PI * 0.5)
	game.truck = truck
	var cam: RigidBody3D = FilmCamera.new()
	cam.build()
	_register(cam, Vector3(0, 0, 7.0), 0.0)
	game.film = cam
	for x: float in [-4.5, 4.5]:
		var rig: RigidBody3D = SpotRig.new()
		rig.build()
		_register(rig, Vector3(x, 0, 5.5), PI)
		game.spots.append(rig)
	var clap: RigidBody3D = Clapper.new()
	clap.game = game
	clap.build()
	_register(clap, Vector3(1.3, 0.02, 8.8), 0.0)
	game.clapper = clap
	var fx: RigidBody3D = FxBox.new()
	fx.build()
	_register(fx, Vector3(3.0, 0, 8.5), 0.0)
	game.fx = fx


func _spawn_storage() -> void:
	var y := PI * 0.5     # 正面を部屋の中央へ向ける
	for at: Vector3 in [Vector3(-13.6, 0, 10.6), Vector3(-11.2, 0, -10.8)]:
		var bf: RigidBody3D = BoomFlat.new()
		bf.build()
		_register(bf, at, y)
		game.booms.append(bf)
	spawn("balcony", Vector3(-13.5, 0, -8.5), y)
	spawn("window", Vector3(-14.5, 0, -4.6), y)
	spawn("ruin", Vector3(-14.3, 0, -1.2), y)
	spawn_plywood(Vector3(-14.8, 0, 2.2), y)
	spawn_plywood(Vector3(-14.8, 0, 4.2), y)
	spawn_riser(Vector3(-14.0, 0, 7.2), y)
	spawn("flat", Vector3(-10.5, 0, -8.5), y)
	spawn("flat", Vector3(-10.5, 0, -6.0), y)
	spawn_moon(Vector3(-10.5, 0, -3.6), y)
	spawn("rock", Vector3(-10.5, 0, -1.6), y)
	spawn("rock", Vector3(-10.5, 0, 0.2), y)
	for i in 3:
		spawn("applebox", Vector3(-10.5, 0, 1.8 + i * 0.6), y)
	for i in 3:
		spawn("sandbag", Vector3(-10.5, 0, 4.0 + i * 0.5), y)
	# 実物寄りの機材は、見本のカメラ位置から映り込まない手前側に置く
	spawn("partition", Vector3(-8.6, 0, 3.4), y)
	spawn("greenscreen", Vector3(-8.6, 0, 7.6), y)
	spawn("dolly", Vector3(-6.6, 0, 10.4), y)
	spawn("recorder", Vector3(-5.4, 0, 10.6), y)
	spawn("boom", Vector3(-4.8, 0, 10.6), y)
	for i in 4:
		spawn("carton", Vector3(-6.8 - (i % 2) * 1.2, 0.02, 4.4 + (i / 2) * 1.3), y)
	var small := ["rose", "letter", "crown", "fish", "filmcan", "tape", "basket"]
	for i in small.size():
		spawn(small[i], Vector3(-10.2 - 0.0, 0.02, 6.2 + i * 0.6), y)


func _spawn_actors() -> void:
	var mark_a := spawn_mark(0, Vector3(-1.2, 0.0, -2.0))
	var mark_b := spawn_mark(1, Vector3(1.2, 0.0, 0.2))
	var specs := [["01", "役者A", ["curtsy", "rose"], mark_a], ["02", "役者B", ["ticket", "halt"], mark_b]]
	for i in 2:
		var a: CharacterBody3D = Actor.new()
		a.game = game
		a.aid = i
		a.label = specs[i][1]
		a.name = "Actor%d" % i
		a.setup(specs[i][0], specs[i][2])
		a.mark = specs[i][3]
		a.position = (specs[i][3] as Node3D).position
		add_child(a)
		game.actors.append(a)
	game.actors[0].partner = game.actors[1]
	game.actors[1].partner = game.actors[0]
