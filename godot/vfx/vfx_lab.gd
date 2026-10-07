extends Node3D
# VFXを単体で眺めるスタジオ。現場（倉庫）と撮影カメラ、両方の明るさで確かめられる。
# `-- --shots` を付けて起動すると、各エフェクトのコマ並べ画像を tests/shots/vfx_review に書き出して終わる。
const Lib := preload("res://vfx/vfx_lib.gd")
const Explosion := preload("res://vfx/vfx_explosion.gd")
const Fire := preload("res://vfx/vfx_fire.gd")
const Smoke := preload("res://vfx/vfx_smoke.gd")
const Projectile := preload("res://vfx/vfx_projectile.gd")
const Lightning := preload("res://vfx/vfx_lightning.gd")
const Brawl := preload("res://vfx/vfx_brawl.gd")
const Mushroom := preload("res://vfx/vfx_mushroom.gd")
const Slam := preload("res://vfx/vfx_slam.gd")
const FirePillar := preload("res://vfx/vfx_fire_pillar.gd")
const Aura := preload("res://vfx/vfx_aura.gd")
const Ink := preload("res://vfx/vfx_ink.gd")
const Cursed := preload("res://vfx/vfx_cursed.gd")
const Tornado := preload("res://vfx/vfx_tornado.gd")
const FireTornado := preload("res://vfx/vfx_fire_tornado.gd")
const BlackFlash := preload("res://vfx/vfx_black_flash.gd")
const BlackBolt := preload("res://vfx/vfx_black_bolt.gd")
const Water := preload("res://vfx/vfx_water.gd")
const PxFlame := preload("res://pixel_vfx/px_flame.gd")
const PxBurst := preload("res://pixel_vfx/px_burst.gd")
const PxPortal := preload("res://pixel_vfx/px_portal.gd")
const PxTeleport := preload("res://pixel_vfx/px_teleport.gd")
const MotifSolar := preload("res://vfx/vfx_motif_solar.gd")
const MotifGeyser := preload("res://vfx/vfx_motif_geyser.gd")
const MotifJelly := preload("res://vfx/vfx_motif_jelly.gd")
const MotifFerro := preload("res://vfx/vfx_motif_ferro.gd")
const MotifSeed := preload("res://vfx/vfx_motif_seed.gd")

# [表示名, id, 繰り返しの間隔（秒）, コマ並べで撮る時刻]
const ITEMS := [
	["爆発（本番）", "explosion", 5.0, [0.6, 0.83, 0.9, 1.02, 1.2, 1.5, 2.1, 3.0]],
	["爆発（テスト発火）", "explosion_small", 3.0, [0.03, 0.1, 0.22, 0.4, 0.7, 1.1, 1.5, 2.0]],
	["旧・爆発（比較用）", "old_explosion", 3.0, [0.03, 0.1, 0.22, 0.4, 0.7, 1.1, 1.7, 2.2]],
	["炎", "fire", 0.0, [0.1, 0.4, 0.8, 1.2, 1.6, 2.0, 2.4, 2.8]],
	["煙（アニメ調）", "smoke", 0.0, [0.2, 0.5, 0.9, 1.3, 1.7, 2.1, 2.5, 2.9]],
	["煙（フラット）", "smoke_flat", 0.0, [0.2, 0.5, 0.9, 1.3, 1.7, 2.1, 2.5, 2.9]],
	["飛び道具・炎（直線）", "shot_fire", 2.4, [0.2, 0.42, 0.5, 0.65, 0.8, 0.98, 1.08, 1.3]],
	["飛び道具・秘術（曲線・加速）", "shot_arcane", 2.8, [0.3, 0.55, 0.8, 1.0, 1.2, 1.36, 1.46, 1.7]],
	["飛び道具・毒（溜めなし・外れ）", "shot_venom", 2.0, [0.03, 0.1, 0.2, 0.35, 0.5, 0.62, 0.72, 0.9]],
	["落雷", "lightning", 2.6, [0.08, 0.18, 0.22, 0.3, 0.36, 0.45, 0.6, 1.0]],
	["どたばた乱闘雲", "brawl", 4.0, [0.18, 0.42, 0.7, 1.1, 1.5, 1.84, 2.13, 3.3]],
	["参考動画・白熱火球と炎輪", "mushroom", 5.0, [0.10, 0.30, 0.50, 0.85, 1.4, 1.95, 2.25, 4.55]],
	["参考画像・土砂爆発", "soil", 3.3, [0.03, 0.13, 0.27, 0.47, 0.8, 1.3, 2.1, 2.8]],
	["参考画像・小爆発", "mini", 3.0, [0.03, 0.13, 0.27, 0.47, 0.8, 1.3, 2.1, 2.8]],
	["ドカン着地", "slam", 3.4, [0.03, 0.1, 0.2, 0.4, 0.7, 1.1, 2.2, 2.6]],
	["火柱", "pillar", 4.6, [0.3, 0.47, 0.6, 1.2, 2.2, 2.6, 2.85, 3.2]],
	["気合のオーラ", "aura", 4.6, [0.1, 0.3, 0.6, 1.5, 2.6, 3.0, 3.25, 3.6]],
	["インク着弾", "ink_splash", 3.2, [0.04, 0.12, 0.25, 0.5, 0.9, 1.5, 2.0, 2.4]],
	["インクボム", "ink_bomb", 4.4, [0.2, 0.6, 0.7, 0.85, 1.1, 1.6, 2.6, 3.3]],
	["インクの竜巻", "ink_tornado", 5.0, [0.2, 0.5, 1.0, 1.8, 2.5, 2.8, 3.2, 4.0]],
	["黒閃", "black_flash", 2.4, [0.0, 0.07, 0.14, 0.27, 0.47, 0.67, 0.8, 1.2]],
	["蒼", "jjk_blue", 4.0, [0.15, 0.4, 1.0, 1.8, 2.4, 2.47, 2.55, 2.9]],
	["茈", "jjk_purple", 4.2, [0.3, 0.7, 0.95, 1.0, 1.3, 1.67, 1.87, 2.6]],
	["竜巻（重ねた層）", "tornado", 5.2, [0.15, 0.4, 1.0, 2.0, 3.2, 3.5, 3.8, 4.2]],
	["炎の竜巻（巻き上がる薄い層）", "fire_tornado", 5.2, [0.15, 0.5, 0.9, 1.5, 2.4, 3.0, 3.7, 4.55]],
	["水柱（水の竜：薄い殻の柱・螺旋のしぶき・放物線の水滴）", "water", 5.0, [0.2, 0.5, 1.0, 1.8, 2.5, 2.9, 3.3, 3.9]],
	["黒い稲妻（層の筒を折れ線に並べた試作）", "black_bolt", 2.4, [0.0, 0.07, 0.14, 0.27, 0.47, 0.67, 0.8, 1.0]],
	["Pixel×Real：炎", "px_flame", 5.0, [0.1, 0.4, 1.2, 2.0, 2.7, 3.0, 3.4, 3.9]],
	["Pixel×Real：ボクセル爆発", "px_burst", 3.0, [0.04, 0.17, 0.33, 0.5, 0.75, 1.0, 1.4, 1.9]],
	["Pixel×Real：ポータル", "px_portal", 5.4, [0.17, 0.42, 1.0, 2.5, 3.8, 4.0, 4.3, 4.67]],
	["Pixel×Real：転送", "px_teleport", 3.6, [0.25, 0.6, 1.0, 1.4, 1.58, 1.85, 2.2, 2.6]],
	["太陽・磁力線の組み替え", "motif_solar", 5.0, [0.15, 0.5, 0.9, 1.25, 1.55, 2.1, 3.1, 4.55]],
	["水圧・間欠泉", "motif_geyser", 5.0, [0.15, 0.5, 0.9, 1.25, 1.65, 2.2, 3.1, 4.55]],
	["クシクラゲ・虹の伝播", "motif_jelly", 5.0, [0.15, 0.5, 0.9, 1.3, 1.8, 2.4, 3.1, 4.55]],
	["磁性流体・移動する棘", "motif_ferro", 5.0, [0.15, 0.5, 0.9, 1.3, 1.8, 2.4, 3.1, 4.55]],
	["種さや・弾性の反動", "motif_seed", 5.0, [0.15, 0.5, 0.75, 0.95, 1.3, 1.9, 2.8, 4.55]],
]

var current := 0
var loop_enabled := true
var _since := 0.0
var _yaw := 0.5
var _pitch := 0.16
var _dist := 13.0
var _drag := false
var _camera: Camera3D
var _env: Environment
var _hud: CanvasLayer
var _picker: OptionButton
var _old_tweens: Array[Tween] = []
var _pending: SceneTreeTimer


func _ready() -> void:
	Lib.warm()
	_build_studio()
	_build_panel()
	if "--shots" in OS.get_cmdline_user_args():
		_shoot.call_deferred()
	else:
		var first := 0
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--only="):
				for i in ITEMS.size():
					if ITEMS[i][1] == arg.trim_prefix("--only="):
						first = i
		play(first)


func _build_studio() -> void:
	var holder := WorldEnvironment.new()
	_env = Environment.new()
	holder.environment = _env
	add_child(holder)
	set_film_look(false)
	# 倉庫と同じ作業灯
	var work := DirectionalLight3D.new()
	work.rotation_degrees = Vector3(-58, 32, 0)
	work.light_energy = 1.2
	work.light_color = Color(1.0, 0.96, 0.9)
	work.shadow_enabled = true
	add_child(work)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, -140, 0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.75, 0.85, 1.0)
	add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.31, 0.33)
	floor_mat.roughness = 1.0
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	var grid := ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-15, 16):
		grid.surface_add_vertex(Vector3(i, 0.006, -15))
		grid.surface_add_vertex(Vector3(i, 0.006, 15))
		grid.surface_add_vertex(Vector3(-15, 0.006, i))
		grid.surface_add_vertex(Vector3(15, 0.006, i))
	grid.surface_end()
	var lines := MeshInstance3D.new()
	lines.mesh = grid
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(0.4, 0.42, 0.45)
	lines.material_override = line_mat
	add_child(lines)
	# 大きさの目安：身長1.7mの人型と、効果機くらいの箱
	var person := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.7
	person.mesh = capsule
	person.position = Vector3(-4.5, 0.85, 0.5)
	add_child(person)
	var crate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.66, 0.5, 0.36)
	crate.mesh = box
	crate.position = Vector3(0, 0.25, 0)
	add_child(crate)
	_camera = Camera3D.new()
	_camera.fov = 50.0
	add_child(_camera)
	_aim_camera()


# 撮影カメラと同じ露出・グローに切り替える（film_camera.gd と同じ値）
func set_film_look(on: bool) -> void:
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	if on:
		_env.background_color = Color(0.012, 0.016, 0.04)
		_env.ambient_light_color = Color(0.35, 0.45, 0.8)
		_env.ambient_light_energy = 0.5
		_env.tonemap_exposure = 0.28
		_env.tonemap_white = 3.0
		_env.glow_intensity = 0.9
		_env.glow_hdr_threshold = 2.2
		_env.glow_bloom = 0.15
	else:
		_env.background_color = Color(0.03, 0.035, 0.045)
		_env.ambient_light_color = Color(0.72, 0.78, 0.92)
		_env.ambient_light_energy = 0.48
		_env.tonemap_exposure = 1.0
		_env.tonemap_white = 6.0
		_env.glow_intensity = 0.25
		_env.glow_hdr_threshold = 1.6
		_env.glow_bloom = 0.0


func _build_panel() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var panel := PanelContainer.new()
	panel.position = Vector2(28, 28)
	panel.size = Vector2(360, 0)
	var theme := Theme.new()
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Yu Gothic UI", "Meiryo", "sans-serif"])
	theme.default_font = sf
	theme.default_font_size = 18
	panel.theme = theme
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102230")
	style.set_corner_radius_all(16)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	_hud.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var title := Label.new()
	title.text = "VFX LAB"
	title.add_theme_font_size_override("font_size", 30)
	col.add_child(title)
	_picker = OptionButton.new()
	for item: Array in ITEMS:
		_picker.add_item(item[0])
	_picker.focus_mode = Control.FOCUS_NONE
	_picker.item_selected.connect(play)
	col.add_child(_picker)
	var again := Button.new()
	again.text = "▶ もう一度  [Enter]"
	again.custom_minimum_size.y = 42
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func() -> void: play(current))
	col.add_child(again)
	var loop := CheckBox.new()
	loop.text = "繰り返し再生"
	loop.button_pressed = true
	loop.focus_mode = Control.FOCUS_NONE
	loop.toggled.connect(func(on: bool) -> void: loop_enabled = on)
	col.add_child(loop)
	var slow := CheckBox.new()
	slow.text = "スロー再生（0.25倍）"
	slow.focus_mode = Control.FOCUS_NONE
	slow.toggled.connect(func(on: bool) -> void: Engine.time_scale = 0.25 if on else 1.0)
	col.add_child(slow)
	var film := CheckBox.new()
	film.text = "撮影カメラの明るさで見る"
	film.focus_mode = Control.FOCUS_NONE
	film.toggled.connect(set_film_look)
	col.add_child(film)
	var help := Label.new()
	help.text = "←→ で切り替え　P で一時停止\nドラッグで回転　ホイールで拡大"
	help.add_theme_font_size_override("font_size", 14)
	col.add_child(help)


func play(index: int) -> void:
	current = index
	_aim_camera()
	_since = 0.0
	_picker.select(index)
	if _pending:
		for c in _pending.timeout.get_connections():
			_pending.timeout.disconnect(c["callable"])
		_pending = null
	for tween in _old_tweens:
		tween.kill()
	_old_tweens.clear()
	for node in get_tree().get_nodes_in_group("vfx"):
		node.queue_free()
	var center := Vector3(0, 1.3, 0)
	match ITEMS[index][1] as String:
		"explosion":
			# 溜め（効果機の導火）→ 爆発。ゲームと同じ 0.8 秒
			Explosion.fuse(self, Vector3(0, 0.55, 0), 0.8)
			_pending = get_tree().create_timer(0.8, false)
			_pending.timeout.connect(func() -> void: Explosion.spawn(self, center, 3.2, 1.3, true))
		"explosion_small":
			Explosion.spawn(self, center, 0.9, 1.3, false)
		"old_explosion":
			_old_explosion(center)
		"fire":
			Fire.spawn(self, Vector3(0, 0.5, 0), 1.6)
		"smoke":
			Smoke.spawn(self, Vector3(0, 0.6, 0), 1.5)
		"smoke_flat":
			Smoke.spawn(self, Vector3(0, 0.6, 0), 1.5, -1.0, true)
		"shot_fire":
			Projectile.fire(self, Vector3(-4.5, 1.2, 0.5), Vector3(4.5, 1.2, 0.5), {"palette": "fire", "travel": 0.55})
		"shot_arcane":
			Projectile.fire(self, Vector3(-4.5, 1.2, 0.5), Vector3(4.5, 1.2, 0.5), {"palette": "arcane", "travel": 0.8, "buildup": 0.6, "ease": "in", "arc": Vector3(0, 2.5, -3.0)})
		"shot_venom":
			Projectile.fire(self, Vector3(-4.5, 1.2, 0.5), Vector3(4.5, 1.6, 0.5), {"palette": "venom", "travel": 0.6, "buildup": 0.0, "ease": "out", "size": 0.7, "hit": false})
		"lightning":
			Lightning.strike(self, Vector3(1.5, 0, 0))
		"brawl":
			Brawl.spawn(self, Vector3.ZERO, 1.6)
		"mushroom", "soil":
			Mushroom.spawn(self, Vector3.ZERO, 1.0, ITEMS[index][1])
		"mini":
			Mushroom.spawn(self, Vector3(0, 0.15, 0), 0.9, "mini")
		"slam":
			Slam.spawn(self, Vector3(1.5, 0, 0), 1.0)
		"pillar":
			FirePillar.spawn(self, Vector3(1.5, 0, 0), 1.0, 2.0)
		"aura":
			Aura.spawn(self, Vector3(-4.5, 0, 0.5), 1.0, 2.5)
		"ink_splash":
			Ink.spawn(self, Vector3(1.5, 0, 0), "splash", 1.0, "orange")
		"ink_bomb":
			Ink.spawn(self, Vector3(1.5, 0, 0), "bomb", 1.0, "pink")
		"ink_tornado":
			Ink.spawn(self, Vector3(1.5, 0, 0), "tornado", 1.0, "blue")
		"black_flash":
			BlackFlash.spawn(self, Vector3(1.5, 1.2, 0), 1.0)
		"jjk_blue":
			Cursed.spawn(self, Vector3(1.5, 2.2, 0), "blue", 1.0)
		"water":
			Water.spawn(self, Vector3(1.5, 0, 0), 1.0)
		"black_bolt":
			BlackBolt.spawn(self, Vector3(1.5, 1.2, 0), 1.0)
		"px_flame":
			PxFlame.spawn(self, Vector3(1.5, 0, 0), 1.6, 2.6)
		"px_burst":
			PxBurst.spawn(self, Vector3(1.5, 1.3, 0), 1.2, 1.3)
		"px_portal":
			PxPortal.spawn(self, Vector3(1.5, 2.0, 0), 1.2, 3.0)
		"px_teleport":
			PxTeleport.spawn(self, Vector3(1.5, 0, 0), 1.3)
		"tornado":
			Tornado.spawn(self, Vector3(1.5, 0, 0), 1.0, 2.5, "blue")
		"fire_tornado":
			FireTornado.spawn(self, Vector3.ZERO)
		"jjk_purple":
			Cursed.spawn(self, Vector3(-5.0, 1.8, 0.5), "purple", 0.8, Vector3.RIGHT)
		"motif_solar":
			MotifSolar.spawn(self, Vector3.ZERO)
		"motif_geyser":
			MotifGeyser.spawn(self, Vector3.ZERO)
		"motif_jelly":
			MotifJelly.spawn(self, Vector3.ZERO)
		"motif_ferro":
			MotifFerro.spawn(self, Vector3.ZERO)
		"motif_seed":
			MotifSeed.spawn(self, Vector3.ZERO)


# 差し替える前の爆発（光る球 ＋ 球の粒）。見比べ用に残す。
func _old_explosion(pos: Vector3) -> void:
	var root := Node3D.new()
	root.add_to_group("vfx")
	add_child(root)
	root.global_position = pos
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.75, 0.25, 0.95)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.55, 0.12)
	m.emission_energy_multiplier = 9.0
	ball.material_override = m
	root.add_child(ball)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 60.0
	light.omni_range = 20.0
	root.add_child(light)
	var parts := CPUParticles3D.new()
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.amount = 90
	parts.lifetime = 1.8
	parts.direction = Vector3.UP
	parts.spread = 75.0
	parts.initial_velocity_min = 4.0
	parts.initial_velocity_max = 11.0
	parts.gravity = Vector3(0, -6, 0)
	parts.scale_amount_min = 0.25
	parts.scale_amount_max = 0.7
	var pm := SphereMesh.new()
	pm.radius = 0.25
	pm.height = 0.5
	parts.mesh = pm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(1.0, 0.5, 0.1)
	pmat.emission_enabled = true
	pmat.emission = Color(1.0, 0.4, 0.05)
	pmat.emission_energy_multiplier = 7.0
	parts.material_override = pmat
	root.add_child(parts)
	parts.emitting = true
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ball, "scale", Vector3.ONE * 7.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color", Color(0.9, 0.25, 0.05, 0.0), 1.5).set_delay(0.25)
	tw.tween_property(light, "light_energy", 0.0, 1.3)
	_old_tweens.append(tw)


func _process(delta: float) -> void:
	_since += delta
	var gap: float = ITEMS[current][2]
	if loop_enabled and gap > 0.0 and _since >= gap and _hud.visible:
		play(current)


func _aim_camera() -> void:
	var focus := Vector3(0, 4.2 if ITEMS[current][1] == "mushroom" else 2.2, 0)
	if ITEMS[current][1] == "fire_tornado": focus.y = 2.8
	if ITEMS[current][1] == "motif_ferro": focus.y = 1.1
	_camera.position = focus + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_camera.look_at(focus)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_drag = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist * 0.9, 3.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.1, 40.0)
		_aim_camera()
	elif event is InputEventMouseMotion and _drag:
		_yaw -= event.relative.x * 0.006
		_pitch = clampf(_pitch + event.relative.y * 0.006, 0.02, 1.4)
		_aim_camera()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ENTER:
				play(current)
			KEY_RIGHT:
				play((current + 1) % ITEMS.size())
			KEY_LEFT:
				play((current + ITEMS.size() - 1) % ITEMS.size())
			KEY_P:
				get_tree().paused = not get_tree().paused


# 各エフェクトを8コマずつ撮って、1枚に並べて保存する（見た目の確認用）
func _shoot() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hud.visible = false
	var dir := ProjectSettings.globalize_path("res://tests/shots/vfx_review")
	DirAccess.make_dir_recursive_absolute(dir)
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	for film: bool in [false, true]:
		set_film_look(film)
		for index in ITEMS.size():
			var id: String = ITEMS[index][1]
			if (only != "" and id != only) or (film and id not in ["explosion", "lightning", "brawl", "mushroom", "soil", "mini", "slam", "pillar", "aura", "black_flash", "jjk_blue", "jjk_purple", "tornado", "fire_tornado", "motif_solar", "motif_geyser", "motif_jelly", "motif_ferro", "motif_seed"]):
				continue
			play(index)
			var times: Array = ITEMS[index][3]
			var sheet := Image.create(640 * 4, 360 * 2, false, Image.FORMAT_RGB8)
			for i in times.size():
				while _since < times[i]:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var frame := get_viewport().get_texture().get_image()
				frame.convert(Image.FORMAT_RGB8)
				frame.resize(640, 360, Image.INTERPOLATE_BILINEAR)
				sheet.blit_rect(frame, Rect2i(0, 0, 640, 360), Vector2i((i % 4) * 640, (i / 4) * 360))
			sheet.save_png(dir.path_join(id + ("_film" if film else "") + ".png"))
			print("VFX_SHOT ", id, " film" if film else "")
	get_tree().quit()


func _exit_tree() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
