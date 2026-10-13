extends "res://scripts/prop.gd"
# 撮影用の爆弾。鉄の玉と、火薬を注ぐ口（口金）。
#   火薬　：powder＝中に入っている量（袋1つ分で 1.0。口いっぱいで CAP）。火薬の袋（powder_sack.gd）から口へ注ぐ。
#           入れた量だけ爆発が大きくなる（blast_of）。爆発すると空になる。
#   導火線：別の物（fuse_cord.gd）。束から口金へつなぎ、伸ばして、はさみで切り、先に火を付ける（bomb_kit.gd）。
#           つないでいなければ、点火した瞬間に爆発する（FUSE_SEC のひと溜めだけ）。
# 量も長さも、数字では出さない。玉のふくらみ・口からのぞく粉・袋のしぼみ・線の実際の長さで見分ける。
# 離れた所から合図で鳴らす道（main.gd の h_cue）は、撮影だけモードと自動確認のために残してある。
#   そのモードでは道具（bomb_kit.gd）が無いので、量り済みの火薬（charges 回分）が最初から入っている。
# 種類の名前は、前の「効果機」のまま "fx"（注文の id・通信・自動確認を変えないため）。

const Explosion := preload("res://vfx/vfx_explosion.gd")
const PropShapes := preload("res://scripts/prop_shapes.gd")
const CAP := 1.0                            # 口いっぱいまで入る量（袋1つ分）。これより多く注ぐと、あふれて床にこぼれる
const STANDARD := 0.35                      # 撮影だけモードで、最初から入っている量（ふつうの爆発）
const EMPTY := 0.02                         # これより少なければ「入っていない」
const FUSE_SEC := 0.8                       # 導火線が無いとき（と、合図で鳴らすとき）の、爆発までのひと溜め
const BURST_UP := 1.3                       # 爆炎の中心の高さ
const WICK_PARTS := 3                       # 導火線をつないでいないときに見える、口金から出た短い芯
const EMPTY_MASS := 9.0
const POWDER_MASS := 12.0                   # 口いっぱいの火薬の重さ（入れるほど、持って運びにくくなる）
const BIG := 0.5                            # これ以上入れると「大爆発」
const HUGE := 0.85                          # これ以上入れると「超・大爆発」（袋をほぼ全部）

var charges := 0             # 撮影だけモードの、量り済みの火薬の残り回数（道具で注ぐ制作モードでは 0 のまま）
var powder := 0.0
var has_cord := false        # 導火線がつながっているか（bomb_kit.gd が決める。つながっていれば、短い芯を隠す）
var fuse := -1.0             # じかに点火してからの残り秒数（ホスト。-1＝点いていない）
var fuse_total := 0.0

var _body: Node3D
var _level: MeshInstance3D
var _heap: MeshInstance3D
var _wick: Array[MeshInstance3D] = []
var _wick_pts: PackedVector3Array = PackedVector3Array()
var _spark: Node3D
var _spark_light: OmniLight3D
var _burn_total := 0.0       # 全員の画面での、最後のひと溜め
var _burn_left := 0.0
var _final := false
var _crackle := 0.0
var _shown_sig := ""


# 入っている量から、爆風の強さと広さの倍率（少し＝小さな爆発 / 袋1つ全部＝セットごと吹き飛ぶ大爆発）
static func blast_of(amount: float) -> float:
	return 0.5 + 1.5 * clampf(amount, 0.0, CAP)


# 採点に使う段階：0＝入っていない / 1＝ふつうの爆発 / 2＝大爆発 / 3＝超・大爆発
static func stage_of(amount: float) -> int:
	if amount < EMPTY:
		return 0
	return 3 if amount >= HUGE else (2 if amount >= BIG else 1)


func build() -> void:
	kind = "fx"
	label = "爆弾"
	mass = EMPTY_MASS
	center = Vector3(0, 0.3, 0)
	half = Vector3(0.3, 0.32, 0.3)
	hold_min = 1.2
	visual = Node3D.new()
	add_child(visual)
	var wood := _mat(Color("b98a55"), 0.9)
	var iron := _mat(Color("16171b"), 0.36)
	iron.metallic = 0.35
	var brass := _mat(Color("c9a03c"), 0.4)
	brass.metallic = 0.6
	# 木の台（転がらないように）
	for z: float in [-0.15, 0.15]:
		_box(visual, Vector3(0.54, 0.07, 0.09), Vector3(0, 0.035, z), wood)
	for x: float in [-0.2, 0.2]:
		_box(visual, Vector3(0.09, 0.06, 0.4), Vector3(x, 0.1, 0), wood)
	# 本体：黒い鉄の玉と、火薬を注ぐ口（導火線もここへつなぐ）
	_body = Node3D.new()
	_body.position = Vector3(0, 0.37, 0)
	visual.add_child(_body)
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sphere.radial_segments = 28
	sphere.rings = 14
	ball.mesh = sphere
	ball.material_override = iron
	_body.add_child(ball)
	var cap := MeshInstance3D.new()
	var neck := CylinderMesh.new()
	neck.top_radius = 0.088
	neck.bottom_radius = 0.07
	neck.height = 0.1
	cap.mesh = neck
	cap.material_override = brass
	cap.position = Vector3(0, 0.27, 0)
	_body.add_child(cap)
	# 口の中：暗い穴と、入れた分だけ上がってくる粉。口いっぱいに近づくと、粉の山が口からのぞく
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.02, 0.02, 0.02)
	var hole := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.072
	disc.bottom_radius = 0.072
	disc.height = 0.004
	hole.mesh = disc
	hole.material_override = dark
	hole.position = Vector3(0, 0.321, 0)
	_body.add_child(hole)
	var dust := _mat(Color(0.2, 0.19, 0.2), 1.0)
	_level = MeshInstance3D.new()
	var top := CylinderMesh.new()
	top.top_radius = 0.07
	top.bottom_radius = 0.07
	top.height = 0.004
	_level.mesh = top
	_level.material_override = dust
	_body.add_child(_level)
	_heap = MeshInstance3D.new()
	var mound := SphereMesh.new()
	mound.radius = 0.083
	mound.height = 0.166
	mound.radial_segments = 16
	mound.rings = 8
	_heap.mesh = mound
	_heap.material_override = dust
	_body.add_child(_heap)
	# 導火線をつないでいないときの、短い芯
	var cord := _mat(Color("e4d6b0"), 0.9)
	# （玉といっしょに大きさが変わるよう、玉の子にする。位置は玉の中心から）
	_wick_pts = PackedVector3Array([Vector3(0.03, 0.31, 0), Vector3(0.06, 0.365, 0.01), Vector3(0.11, 0.395, 0.02), Vector3(0.17, 0.39, 0.03)])
	for i in WICK_PARTS:
		var part := MeshInstance3D.new()
		var tube := CylinderMesh.new()
		tube.top_radius = 0.014
		tube.bottom_radius = 0.014
		tube.height = 1.0
		tube.radial_segments = 6
		tube.rings = 1
		part.mesh = tube
		part.material_override = cord
		var a: Vector3 = _wick_pts[i]
		var b: Vector3 = _wick_pts[i + 1]
		part.position = (a + b) * 0.5
		part.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized())) * Basis.from_scale(Vector3(1.0, a.distance_to(b) + 0.006, 1.0))
		_body.add_child(part)
		_wick.append(part)
	_spark = Node3D.new()
	_spark.visible = false
	_body.add_child(_spark)
	var ember := MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.06
	dot.height = 0.12
	ember.mesh = dot
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.86, 0.45)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.7, 0.25)
	glow.emission_energy_multiplier = 4.0
	ember.material_override = glow
	_spark.add_child(ember)
	_spark_light = OmniLight3D.new()
	_spark_light.light_color = Color(1.0, 0.62, 0.25)
	_spark_light.omni_range = 3.6
	_spark_light.light_energy = 3.0
	_spark.add_child(_spark_light)
	# 当たり判定は表（prop_shapes.gd）：木の台・鉄の玉・口金。入れた火薬で玉の見た目が大きくなっても、形は変えない
	PropShapes.build(self, kind)
	_show_load()


func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


func _box(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh


func burst_point() -> Vector3:
	return global_position + Vector3(0, BURST_UP, 0)


# 口（火薬を注ぐ所・導火線をつなぐ所）の位置。物の原点から見た場所
func mouth_local() -> Vector3:
	return _body.position + Vector3(0, 0.335 * _body.scale.y, 0)


func mouth() -> Vector3:
	return global_transform * mouth_local()


# 玉の見た目（中心と半径）。導火線が、ふくらんだ玉の上を垂れるように（fuse_cord.gd の balls）
func ball() -> Array:
	return [global_transform * _body.position, 0.25 * _body.scale.x + 0.02]


func loaded() -> bool:
	return powder >= EMPTY


func blast() -> float:
	return blast_of(powder)


func stage() -> int:
	return stage_of(powder)


# ---- ホスト：じかに点火する（導火線なし）と、火を消す ----

# 火をつける。seconds 秒後に爆発する。空なら空撃ち
func ignite(seconds: float) -> bool:
	if fuse >= 0.0 or absent:
		return false
	fuse = seconds
	fuse_total = seconds
	game.host_ev("fuse", [pid, seconds])
	return true


# 借り直しなどで、燃えている火を消す
func douse() -> void:
	if fuse >= 0.0:
		game.host_ev("fuse", [pid, 0.0])
	fuse = -1.0


# 爆発した：入っていた火薬が無くなる。量り済みの火薬（撮影だけモード）が残っていれば、次の1回分を入れておく
func spend() -> void:
	charges = maxi(0, charges - 1)
	powder = STANDARD if charges > 0 else 0.0


func _host_tick(delta: float) -> void:
	if fuse >= 0.0:
		fuse -= delta
		if fuse < 0.0:
			fuse = -1.0
			game.host_burst(self)


# ---- 全員の画面：入っている量の見た目 ----

func _sig() -> String:
	return "%.3f|%s" % [powder, has_cord]


func _show_load() -> void:
	_shown_sig = _sig()
	var k := clampf(powder / CAP, 0.0, 1.0)
	# 入れるほど、玉がふくらむ・重くなる
	_body.scale = Vector3.ONE * lerpf(0.82, 1.3, k)
	mass = EMPTY_MASS + POWDER_MASS * k
	# 口の中の粉：少ないうちは奥に沈んでいて、増えると口まで上がってくる
	_level.visible = powder >= EMPTY
	_level.position = Vector3(0, lerpf(0.235, 0.323, clampf(k / 0.7, 0.0, 1.0)), 0)
	# 口いっぱいに近いと、粉の山が口の上に盛り上がる
	var over := clampf((k - 0.62) / 0.38, 0.0, 1.0)
	_heap.visible = over > 0.0
	# 丸い山の上半分だけが、口の上に見える
	_heap.scale = Vector3(1.0, 0.12 + 0.75 * over, 1.0)
	_heap.position = Vector3(0, 0.318, 0)
	_show_burn()


# 全員の画面で、最後のひと溜めを見せる（じかに点火したとき・導火線の火が口金に届く直前）。
# seconds が 0 以下なら火を消す。total：もとの長さ（途中から入った人には、残りの秒数と一緒に渡す）
func show_fuse(seconds: float = FUSE_SEC, total: float = -1.0) -> void:
	if seconds <= 0.0:
		_burn_left = 0.0
		_burn_total = 0.0
		visual.position = Vector3.ZERO
		_show_burn()
		return
	_burn_total = maxf(total, seconds)
	_burn_left = seconds
	_final = false
	_crackle = 0.0
	_hiss(-4.0)


# 導火線のパチパチ（音の素材が無い環境では鳴らさない）
func _hiss(volume_db: float) -> void:
	# 音の係（Sfx）は名前で直接呼ばない。このスクリプトは、Sfx が登録される前に読み込まれることがある（単体の自動確認）
	var sfx: Node = get_node_or_null("/root/Sfx")
	if sfx != null and sfx.has_sound("fuse"):
		sfx.play("fuse", global_position, volume_db)


func _show_burn() -> void:
	var burning := _burn_left > 0.0 and _burn_total > 0.0
	# 短い芯は、導火線をつないでいないときだけ見える。じかに点火すると、先から燃えて無くなる
	var head: float = _burn_left / _burn_total if burning else 1.0
	for i in WICK_PARTS:
		_wick[i].visible = not has_cord and float(i) / WICK_PARTS < head
	_spark.visible = burning and not has_cord
	if _spark.visible:
		var at := head * WICK_PARTS
		var i := clampi(int(at), 0, WICK_PARTS - 1)
		_spark.position = _wick_pts[i].lerp(_wick_pts[i + 1], clampf(at - float(i), 0.0, 1.0)) + Vector3(0, 0.02, 0)
		_spark.scale = Vector3.ONE * randf_range(0.8, 1.35)
		_spark_light.light_energy = randf_range(2.0, 4.0)


func _process(delta: float) -> void:
	if _shown_sig != _sig():
		_show_load()
	if _burn_left <= 0.0:
		visual.position = Vector3.ZERO
		return
	_burn_left = maxf(0.0, _burn_left - delta)
	# 燃えている間は、パチパチと鳴る
	_crackle -= delta
	if _crackle <= 0.0:
		_crackle = randf_range(0.16, 0.34) if _burn_left > 1.0 else 0.09
		_hiss(-9.0)
	# 最後のひと溜め：本体が震えて、火花が噴く
	if _burn_left <= FUSE_SEC and not _final and _burn_left > 0.05:
		_final = true
		Explosion.fuse(self, global_position + Vector3(0, 0.55, 0), _burn_left)
	if _final:
		var k := 1.0 - _burn_left / FUSE_SEC
		visual.position = Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)) * 0.03 * (0.3 + k)
	_show_burn()


func get_state() -> Array:
	return [global_position, Quaternion(global_basis.orthonormalized()), fixed, charges, powder]


func _apply_extra(s: Array) -> void:
	if s.size() < 4:
		return
	charges = int(s[3])
	if s.size() >= 5:
		powder = float(s[4])
