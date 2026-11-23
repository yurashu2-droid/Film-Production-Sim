extends "res://vfx/vfx_base.gd"
## 素材は風の筋と乾いた砂。白い筋が空き地を横切り、遅れて草木と砂が風下へ流れる。
## 0.1秒で筋の頭が描かれ、0.4秒で弧が伸び、0.8秒から尾が追いついて抜ける。
## 筋が流れ去ったあと、砂は低いまま散り、草と幹は反動で揺れて戻る。
## composition: 中。筋で風向き、砂と草木で地表に伝わる力を見せる。

const Ribbon := preload("res://vfx/vfx_ribbon.gd")
const DUST_SHADER := preload("res://vfx/shaders/site_gust_dust.gdshader")
const DUST_SHEET := preload("res://assets/vfx/original_tex/lib/flipbook/toon_puffs_16x16.png")
const SAMPLE_POINTS := 12

var _wind := Vector3.RIGHT
var _crosswind := Vector3.BACK
var _strength := 1.0
var _grass: Array[ShaderMaterial] = []
var _trees: Array[Node3D] = []
var _strokes: Array[Dictionary] = []
var _dust: MultiMesh
var _grains: Array[Dictionary] = []


func start(wind: Vector3, location: Node3D) -> void:
	_strength = clampf(wind.length(), 0.0, 1.5)
	_wind = Vector3(wind.x, 0, wind.z).normalized()
	if _wind.is_zero_approx():
		queue_free()
		return
	_crosswind = Vector3.UP.cross(_wind)
	life = 1.85
	for node: Node3D in get_tree().get_nodes_in_group("location_wind_grass"):
		if location.is_ancestor_of(node):
			var grass: MeshInstance3D = node.get_node("Mesh")
			_grass.append(grass.mesh.surface_get_material(0) as ShaderMaterial)
	for node: Node3D in get_tree().get_nodes_in_group("location_wind_tree"):
		if location.is_ancestor_of(node):
			_trees.append(node)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(wind)
	for i in 12:
		var stroke := Ribbon.new()
		var width := rng.randf_range(0.030, 0.071)
		stroke.material_override = Lib.material("stroke", {
			"width": width, "color": Color(1.16, 1.16, 1.13, 0.64 if i < 7 else 0.36)})
		add_child(stroke)
		var origin := _wind * rng.randf_range(-9.5, -4.5)
		origin += _crosswind * lerpf(-9.5, 9.5, (i + 0.5) / 12.0)
		origin.y = rng.randf_range(0.58, 2.25) if i < 7 else rng.randf_range(0.21, 0.68)
		_strokes.append({"mesh": stroke, "at": origin, "delay": rng.randf_range(0.015, 0.43),
			"duration": rng.randf_range(0.65, 0.91), "reach": rng.randf_range(11.0, 17.0),
			"bend": rng.randf_range(-0.7, 0.7)})
	_make_dust(rng)


func _make_dust(rng: RandomNumberGenerator) -> void:
	var shapes := [2, 3, 7, 10, 11, 15]
	for i in 5:
		var across := lerpf(-8.0, 8.0, i / 4.0)
		var origin := _wind * rng.randf_range(-5.4, -2.5) + _crosswind * across
		for j in 6:
			_grains.append({"at": origin + _crosswind * rng.randf_range(-1.0, 1.0),
				"drift": _wind * rng.randf_range(2.5, 7.6) + _crosswind * rng.randf_range(-0.8, 0.8),
				"delay": 0.12 + i * 0.052 + j * 0.045, "life": rng.randf_range(0.55, 0.92),
				"size": rng.randf_range(0.65, 1.55), "height": rng.randf_range(0.12, 0.29),
				"shape": shapes[rng.randi_range(0, shapes.size() - 1)]})
	_dust = MultiMesh.new()
	_dust.transform_format = MultiMesh.TRANSFORM_3D
	_dust.use_custom_data = true
	_dust.mesh = Lib.quad()
	_dust.instance_count = _grains.size()
	var mesh := MultiMeshInstance3D.new()
	mesh.multimesh = _dust
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.custom_aabb = AABB(Vector3(-19, 0, -19), Vector3(38, 2, 38))
	var material := ShaderMaterial.new()
	material.shader = DUST_SHADER
	material.set_shader_parameter("sheet", DUST_SHEET)
	mesh.material_override = material
	add_child(mesh)
	_pose_dust()


# 物を押す風と同じ物理時計で進める。
func _process(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	super._process(delta)


func _tick(_delta: float) -> void:
	for stroke in _strokes:
		var k: float = (age - stroke.delay) / stroke.duration
		var ribbon: MeshInstance3D = stroke.mesh
		if k <= 0.0 or k >= 1.0:
			ribbon.draw(PackedVector3Array())
			continue
		# 頭と尾がともに風下へ進む。尾が遅れて追いつき、最後は短い筋だけが抜ける。
		var front := clampf(k * 1.42, 0.0, 1.0)
		var back := smoothstep(0.13, 1.0, k)
		var points := PackedVector3Array()
		for i in SAMPLE_POINTS:
			var t := lerpf(front, back, float(i) / (SAMPLE_POINTS - 1))
			var point: Vector3 = stroke.at + _wind * (t * stroke.reach + k * 4.0)
			point += _crosswind * sin(t * 5.5 - k * 2.4) * float(stroke.bend)
			point.y += sin(t * 6.1 - k * 3.2) * (0.13 + 0.19 * k)
			points.append(point)
		ribbon.draw(points)
		param(ribbon, "fade", smoothstep(0.0, 0.08, k) * (1.0 - smoothstep(0.72, 1.0, k)))
	var push := smoothstep(0.02, 0.24, age) * (1.0 - smoothstep(0.56, 1.10, age))
	var rebound := sin(maxf(age - 0.75, 0.0) * 15.0) * (1.0 - smoothstep(0.75, 1.65, age))
	_pose_plants((push - rebound * 0.24) * _strength)
	_pose_dust()


func _pose_dust() -> void:
	for i in _grains.size():
		var grain := _grains[i]
		var k: float = (age - grain.delay) / grain.life
		if k <= 0.0 or k >= 1.0:
			_dust.set_instance_custom_data(i, Color(0, 0, 0, 0))
			continue
		# 先に足元を滑って伸び、細かく散りながら地面へ落ちる。
		var p: Vector3 = grain.at + (grain.drift as Vector3) * (1.0 - pow(1.0 - k, 1.45))
		p.y = 0.075 + sin(k * PI) * float(grain.height)
		var spread: float = grain.size * lerpf(0.68, 1.52, k)
		_dust.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(spread, spread * 0.41, 1)), p))
		var density := smoothstep(0.0, 0.15, k) * (1.0 - smoothstep(0.35, 1.0, k))
		_dust.set_instance_custom_data(i, Color(k, float(grain.shape), density, 0))


func _pose_plants(amount: float) -> void:
	for grass in _grass:
		grass.set_shader_parameter("wind", _wind * amount * 0.27)
		grass.set_shader_parameter("gust_time", age)
	for i in _trees.size():
		if is_instance_valid(_trees[i]):
			var branch_sway := 0.82 + 0.18 * sin(age * 14.0 + i * 1.6)
			_trees[i].basis = Basis(_crosswind, amount * branch_sway * 0.105)


func _exit_tree() -> void:
	_pose_plants(0.0)
