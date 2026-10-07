extends Node3D
# Pixel x Real VFX の土台。このフォルダだけで動く（ほかのスクリプトに依存しない）。
# 時刻で予約して進め、12コマ/秒で _step を呼び、寿命が来たら自分で消える。ツリーの一時停止に従う。

const SHADERS := "res://pixel_vfx/shaders/"
const FPS := 12.0
# 色の組：暗 → 明の5色。1を超える色は、ドット絵のまま本物の光としてにじむ
const PALETTES := {
	"fire": [Vector3(1.2, 0.08, 0.02), Vector3(3.0, 0.45, 0.04), Vector3(5.0, 1.6, 0.1), Vector3(7.0, 4.2, 0.5), Vector3(9.0, 8.0, 5.0)],
	"ice": [Vector3(0.03, 0.12, 0.6), Vector3(0.1, 0.5, 1.8), Vector3(0.4, 1.8, 4.0), Vector3(2.0, 5.0, 8.0), Vector3(8.0, 10.0, 10.0)],
	"toxic": [Vector3(0.03, 0.3, 0.02), Vector3(0.2, 1.2, 0.05), Vector3(0.8, 3.5, 0.15), Vector3(3.0, 7.0, 0.6), Vector3(8.0, 10.0, 5.0)],
	"arcane": [Vector3(0.08, 0.01, 0.3), Vector3(0.4, 0.06, 1.4), Vector3(1.4, 0.3, 4.0), Vector3(2.0, 2.6, 7.5), Vector3(7.0, 9.0, 10.0)],
	"gold": [Vector3(0.4, 0.12, 0.01), Vector3(1.4, 0.6, 0.03), Vector3(3.5, 2.0, 0.1), Vector3(7.0, 5.0, 0.6), Vector3(10.0, 9.5, 6.0)],
}

var age := 0.0
var life := 1.0           # 0 以下なら消えない
var _frame := -1
var _cues: Array = []
var _spans: Array = []


func _init() -> void:
	add_to_group("vfx")
	add_to_group("pixel_vfx")


func at(time: float, what: Callable) -> void:
	_cues.append([time, what])


func over(start: float, length: float, what: Callable) -> void:
	_spans.append([start, length, what])


func _process(delta: float) -> void:
	age += delta
	var i := 0
	while i < _cues.size():
		if age >= _cues[i][0]:
			var cue: Callable = _cues[i][1]
			_cues.remove_at(i)
			cue.call()
		else:
			i += 1
	i = 0
	while i < _spans.size():
		var span: Array = _spans[i]
		if age < span[0]:
			i += 1
			continue
		var k := clampf((age - span[0]) / span[1], 0.0, 1.0)
		(span[2] as Callable).call(k)
		if k >= 1.0:
			_spans.remove_at(i)
		else:
			i += 1
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_step(frame / FPS)
	if life > 0.0 and age >= life:
		queue_free()


# 12コマ/秒で呼ばれる。形や位置はここで決める（なめらかに補間しない）
func _step(_t: float) -> void:
	pass


static func ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - k, 3.0)


static func palette(palette_name: String) -> Array:
	return PALETTES.get(palette_name, PALETTES["fire"])


static func material(shader_name: String, colors: Array = [], params: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADERS + shader_name + ".gdshader")
	for i in colors.size():
		m.set_shader_parameter("pal_%d" % i, colors[i])
	for key: String in params:
		m.set_shader_parameter(key, params[key])
	return m


# 板を1枚足す
func quad(mat: Material, size: Vector2, offset: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	mesh.center_offset = offset
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 4.0
	add_child(mi)
	return mi


static func param(node: GeometryInstance3D, key: String, value: Variant) -> void:
	(node.material_override as ShaderMaterial).set_shader_parameter(key, value)


# ボクセル（立方体）の粒をまとめて描く入れ物
func voxels(count: int, reach: float) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = count
	var holder := MultiMeshInstance3D.new()
	holder.multimesh = mm
	holder.material_override = material("px_voxel")
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.custom_aabb = AABB(Vector3.ONE * -reach, Vector3.ONE * reach * 2.0)
	add_child(holder)
	return mm


# 立方体を1つ置く。位置と大きさはマス目に揃える。glow は光る強さ
static func put(mm: MultiMesh, index: int, pos: Vector3, dia: float, color: Vector3, glow: float, grid: float) -> void:
	var size := maxf(snappedf(dia, grid * 0.5), 0.0)
	var at_grid := pos.snapped(Vector3.ONE * grid) if size > 0.0 else Vector3.ZERO
	mm.set_instance_transform(index, Transform3D(Basis.from_scale(Vector3.ONE * maxf(size, 0.0001)), at_grid))
	var peak := maxf(maxf(color.x, color.y), maxf(color.z, 1.0))
	mm.set_instance_color(index, Color(color.x / peak, color.y / peak, color.z / peak))
	mm.set_instance_custom_data(index, Color(glow * peak, 0, 0, 0))


func lamp(color: Vector3, reach: float) -> OmniLight3D:
	var peak := maxf(maxf(color.x, color.y), maxf(color.z, 0.001))
	var light := OmniLight3D.new()
	light.light_color = Color(color.x / peak, color.y / peak, color.z / peak)
	light.omni_range = reach
	light.light_energy = 0.0
	add_child(light)
	return light
