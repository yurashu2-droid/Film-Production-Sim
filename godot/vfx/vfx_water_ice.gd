extends "res://vfx/vfx_base.gd"
# 冷気の水（凍る水の魔法）。足元に霜の模様が広がり、青灰の冷気の霧が地面の三か所から昇る。
# 霧は煙玉（vfx_toon_puffs.gd）の連番で作り、上でまとまって傘のように広がり、降りながら地面の霧になって消える。
# 霧の中には、水の筋（wisp 三層の細い筒）を二本だけ添え、3.8〜4.2秒に cut を上げて霧より先に消す。
# 固体の氷は使わない（依頼：固体感なし）。
#
# 素材：青灰の冷気の霧（煙玉の連番）＋水の筋（wisp 三層の細い筒を二本）
# どこから来る：地面の霜の陣の縁、三か所から（時刻をずらして昇る）
# 先に動く部分：昇る煙玉の先頭（0.2〜1.5秒）
# 遅れて追う部分：水の筋（霧の中を遅れて昇る）
# 形の変化（時刻）：
#   0.2〜1.5秒   三か所から煙玉が昇り、中心へ寄る
#   1.1〜2.6秒   中心でまとまり、水の筋が捻れながら一つになる
#   2.5〜3.6秒   頭が外へ広がる（傘）
#   3.5〜4.5秒   傘の縁が降り、地面の霧になって欠けて消える
# 終わり（層ごとに行き先を変える）：
#   煙玉：降りながら連番で欠けて消える（3.3〜5.2秒）
#   水の筋：cut を上げて霧より先に消す（3.8〜4.2秒）
#   霜の模様：A は外から閉じ（3.8〜4.6秒）、B は扇形にぬぐう（4.0〜4.8秒）
# 周1の修正：煙玉を青灰に塗り直した（白い綿に見えたため）。水の筋を細く短くし、炎に見えない青白い色へ寄せた。
#   霜は明るさを落とした（白い光の円盤に見えたため）。

const Puffs := preload("res://vfx/vfx_toon_puffs.gd")

const FPS := 30.0
const STRANDS := 2
const STRAND_R := 0.22         # 水の筋の外の半径。布に見えないよう細くして、霧の中に隠れる筋にする
const STRAND_H := 1.8          # 水の筋の高さ（m）
const SPOTS := 3               # 霧が昇る地面の三か所
const SPOT_R := 1.6            # 三か所の中心からの距離（m）
const MERGE_END := 2.6
const FLARE_END := 3.6
const FALL_END := 4.6
# 水の筋の三層。[暗い色, 明るい色, 初めの cut, inner, 半径の割合]。白を減らし、青灰寄りにして炎に見せない
const LAYERS := [
	[Vector3(0.25, 0.45, 0.75), Vector3(0.45, 0.75, 1.1), 0.80, 0.50, 1.0],
	[Vector3(0.35, 0.6, 0.95), Vector3(0.8, 1.1, 1.5), 0.72, 0.30, 0.65],
	[Vector3(0.6, 0.85, 1.1), Vector3(0.8, 1.0, 1.2), 0.62, 0.14, 0.3],
]
# 煙玉の色。青灰の影を主にして、白い綿に見せない
const MIST_LIGHT := Vector3(0.75, 0.9, 1.05)
const MIST_SHADE := Vector3(0.36, 0.52, 0.72)
const MIST_INK := Vector3(0.14, 0.24, 0.40)

var _size := 1.0
var _frame := -1
var _cols: Array = []          # [{"base": 根元, "phase": 揺れの位相, "delay": 立つ遅れ, "tubes": [三層]}]
var _frost_a: MeshInstance3D
var _frost_b: MeshInstance3D
var _light: OmniLight3D


static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx


func start(size: float) -> void:
	_size = size
	life = 5.8
	# 三か所から霧が昇る（煙玉）
	for s in SPOTS:
		var a := TAU * float(s) / SPOTS + 0.4
		var base := Vector3(cos(a), 0.0, sin(a)) * SPOT_R * size
		_rise_puffs(base, s)
	# 水の筋は、三か所のうち二か所から立つ
	for i in STRANDS:
		var a := TAU * float(i) / SPOTS + 0.4
		var tubes: Array = []
		for L in LAYERS.size():
			var layer: Array = LAYERS[L]
			var mi := Lib.wisp_layer(ArrayMesh.new(), L, LAYERS.size(), layer[0], layer[1], {
				"cut": layer[2], "inner": layer[3], "tip": 0.0, "sway": 0.0, "ripple": 0.05,
				"seed": float(i) * 0.7 + float(L) * 0.2,
			})
			mi.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 6, 8))
			add_child(mi)
			tubes.append(mi)
		_cols.append({
			"base": Vector3(cos(a), 0.0, sin(a)) * SPOT_R * size,
			"phase": float(i) * 2.1,
			"delay": float(i) * 0.1,
			"tubes": tubes,
		})
	_gather_puffs()
	_spread_puffs()
	_fall_puffs()
	_frost_a = _frost(Color(0.55, 0.75, 0.95), 0.45)
	_frost_b = _frost(Color(0.6, 0.8, 1.0), 0.5)
	_frost_b.rotation.y = 1.1
	_light = lamp(Color(0.6, 0.85, 1.0), 6.0 * size)
	_light.position.y = 1.0 * size
	_pose(0.0)


# 地面の一か所から、煙玉を時刻をずらして上へ流す（霧の根元）
func _rise_puffs(base: Vector3, s: int) -> void:
	var plan: Array = []
	var inward := -base.normalized() * 0.35
	for j in 8:
		var delay := 0.15 + float(j) * 0.16 + float(s) * 0.25
		var dist := 1.0 + 0.2 * float(j % 3)
		var puff_size := 0.5 + 0.1 * float(j % 3)
		plan.append([delay, inward * 1.7 + Vector3(0.0, 1.0, 0.0), dist, puff_size, 1.5])
	_puffs(base, plan, 1.1)


# 中央の上で煙玉がまとまり、頭になる
func _gather_puffs() -> void:
	var plan: Array = []
	for j in 12:
		var b := float(j) * 2.4
		var dir := Vector3(cos(b) * 0.3, 1.0, sin(b) * 0.3)
		plan.append([1.1 + float(j) * 0.1, dir, 1.8 + 0.3 * float(j % 2), 0.7 + 0.1 * float(j % 3), 1.5])
	_puffs(Vector3.ZERO, plan, 0.8)


# 頭が外へ広がる（傘）
func _spread_puffs() -> void:
	var plan: Array = []
	for j in 12:
		var b := float(j) * 0.52
		var dir := Vector3(cos(b) * 0.9, -0.2, sin(b) * 0.9)
		plan.append([2.4 + float(j) * 0.07, dir, 1.2 + 0.2 * float(j % 3), 0.75 + 0.1 * float(j % 3), 0.6])
	_puffs(Vector3(0.0, 1.8 * _size, 0.0), plan, 0.0)


# 傘の縁が上から降り、地面の霧になって欠けて消える（寿命は 0.6 秒。4.4 秒までに全部消える）
func _fall_puffs() -> void:
	for i in 3:
		var b0 := TAU * float(i) / 3.0 + 0.7
		var plan: Array = []
		# 煙玉は、置いたノードの高さより 0.4m 以上は下がらない（床の判定がノード基準）。
		# だから降りる煙玉はノードを地面に置き、傘の縁の真下から地面を外へ這わせる。
		for j in 5:
			var b := b0 + float(j) * 0.45
			var dir := Vector3(cos(b) * 0.8, 0.05, sin(b) * 0.8)
			plan.append([3.0 + float(i) * 0.1 + float(j) * 0.15, dir, 1.2 + 0.2 * float(j % 2), 0.6 + 0.08 * float(j % 3), 0.6])
		_puffs(Vector3(cos(b0) * 0.9, 0.0, sin(b0) * 0.9) * _size, plan, 0.0)


# 煙玉の連番を一つの位置に置き、青灰に塗る（tint は掛け算なので recolor が要る）
func _puffs(at: Vector3, plan: Array, rise: float) -> void:
	var p: Node3D = Puffs.new()
	p.rise = rise
	add_child(p)
	p.position = at
	p.start(plan, _size, Color.WHITE)
	p.recolor(MIST_LIGHT, MIST_SHADE, MIST_INK)


# 霜の模様を1枚作る（白黒の絵を型にして塗る板）。色は 1.0 より暗くし、光らせない
func _frost(color: Color, cut: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = Lib.quad()
	mi.material_override = Lib.material("stamp", {
		"shape": Lib.tex("cracks336.png"), "cut": cut, "core_cut": 2.0,
		"color": color, "core_color": color, "reveal": 0.0, "hide": 0.0,
	})
	mi.rotation.x = -PI / 2.0
	mi.position.y = 0.02
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


func _pose(t: float) -> void:
	# 水の筋：霧より先に、三層とも cut を上げて消す
	var strand_cut := smoothstep(3.8, 4.2, t)
	var fade := 1.0 - smoothstep(4.0, 4.4, t)
	for col: Dictionary in _cols:
		var rise := ease_out(clampf(t - 0.2 - float(col["delay"]), 0.0, 1.0))
		var h: float = STRAND_H * _size * rise * fade
		var grow := lerpf(0.5, 1.0, rise)
		for L in LAYERS.size():
			var mi: MeshInstance3D = col["tubes"][L]
			var layer: Array = LAYERS[L]
			param(mi, "cut", lerpf(float(layer[2]), 1.05, strand_cut))
			_set_tube(mi, col, t, h, STRAND_R * _size * grow * float(layer[4]), 0.4)
	# 霜の模様：霧より先に出して、霧が消える前に消す
	var spread := ease_out(clampf(t / 0.6, 0.0, 1.0))
	_frost_a.visible = t < 4.6
	_frost_a.scale = Vector3.ONE * _size * lerpf(0.5, 6.0, spread)
	param(_frost_a, "reveal", spread)
	param(_frost_a, "sweep", smoothstep(3.8, 4.6, t))
	var spread_b := ease_out(clampf((t - 0.2) / 0.7, 0.0, 1.0))
	_frost_b.visible = t < 4.8
	_frost_b.scale = Vector3.ONE * _size * lerpf(0.4, 5.0, spread_b)
	param(_frost_b, "reveal", spread_b)
	param(_frost_b, "spin", t * 0.2)
	param(_frost_b, "sweep", smoothstep(4.0, 4.8, t))
	_light.light_energy = 1.2 * _size * smoothstep(0.2, 1.2, t) * (1.0 - smoothstep(4.2, 4.9, t))


# 水の筋を作り直す。高さか太さが0になったら隠す（縮退した筒を描かない）
func _set_tube(mi: MeshInstance3D, col: Dictionary, t: float, height: float, radius: float, taper: float) -> void:
	var on := height > 0.06 and radius > 0.01
	mi.visible = on
	param(mi, "phase", t)
	if on:
		mi.mesh = Lib.path_tube(_path(col, t, height), radius, taper)


# 水の筋の中心線。根元は地面に立ち、先端へ向かって内へ寄り、捻れ、最後に外へ開く
func _path(col: Dictionary, t: float, height: float) -> PackedVector3Array:
	var merge := smoothstep(1.0, MERGE_END, t)
	var flare := smoothstep(MERGE_END, FLARE_END, t)
	var fall := smoothstep(FLARE_END, FALL_END, t)
	var base: Vector3 = col["base"]
	var phase: float = col["phase"]
	var ctrl := PackedVector3Array()
	var n := 6
	for k in n:
		var s := float(k) / (n - 1)
		var twist := merge * (s * 1.6 + maxf(t - 1.0, 0.0) * 0.9)
		var xz := Vector2(base.x, base.z).rotated(twist)
		var ring := lerpf(1.0, 0.1, merge * s * 0.9) + (flare * 0.9 + fall * 0.5) * s * s
		var wob := sin(t * 2.6 + phase + s * 2.2) * 0.07 * _size * s
		var y := height * s
		ctrl.append(Vector3(xz.x * ring + wob, maxf(y, 0.0) + 0.02, xz.y * ring + wob * 0.6))
	return Lib.smooth_path(ctrl, 4)
