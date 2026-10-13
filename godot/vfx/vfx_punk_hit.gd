extends "res://vfx/vfx_base.gd"
# 棘の衝撃（パンクなペン画の絵柄の試作）。光らせない。色は墨・骨・深紅の3つだけ。
# 素材：        紙に描いた絵（ペン線とべた塗り）
# どこから来る： 殴った点
# 先に動く部分： 骨色の棘（1コマ目に大きく弾け、すぐ少し戻る）
# 遅れて追う部分：赤いギザギザ（棘の外へ、ずれた時刻で描かれて走る）、ばんそうこうの×（少し遅れて貼られる）
# 終わり（絵なので、絵として消える）：
#   棘      塗りが斜めに掻き消され、輪郭がかすれて点線になって消える（0.7〜1.25秒）
#   ギザギザ 描きはじめ側から外へ走り去る（根元へ戻らない）
#   ×       最後まで残り、かすれて消える（1.0〜1.45秒）
# 12 コマ/秒。線はさらに 8 コマ/秒で描き直して震える。

const FPS := 12.0
const BONE := Vector3(0.91, 0.86, 0.85)
const INK := Vector3(0.03, 0.03, 0.035)
const RED := Vector3(0.55, 0.015, 0.045)   # 画面の明るさ処理でピンクに寄るので、深めに置く
# ギザギザ：[向き(度), 中心までの距離, 出る遅れ, 長さ]
const ZIGS := [[25.0, 1.9, 0.08, 1.9], [150.0, 2.0, 0.12, 1.6], [200.0, 1.7, 0.17, 2.1], [290.0, 1.8, 0.1, 1.5], [340.0, 2.1, 0.2, 1.7]]

var _size := 1.0
var _frame := -1
var _burst: MeshInstance3D
var _zigs: Array = []
var _cross: MeshInstance3D


static func spawn(parent: Node, pos: Vector3, size: float = 1.0) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size)
	return fx


func start(size: float) -> void:
	_size = size
	life = 1.7
	_burst = _board({"mode": 0, "fill": BONE, "ink": INK, "seed": randf() * 9.0, "spikes": 15.0})
	for z: Array in ZIGS:
		var a := deg_to_rad(float(z[0]))
		var m := _board({"mode": 1, "fill": RED, "ink": INK, "seed": randf() * 9.0, "outline": 0.0, "roll": a, "grow": 0.0})
		m.position = Vector3(cos(a), sin(a), 0.0) * float(z[1]) * size
		m.scale = Vector3.ONE * float(z[3]) * size
		_zigs.append(m)
	_cross = _board({"mode": 2, "fill": BONE, "ink": INK, "seed": 3.0, "roll": 0.2})
	_cross.position = Vector3(0.95, 0.75, 0.05) * size
	_pose(0.0)


func _board(params: Dictionary) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = Lib.quad()
	m.material_override = Lib.material("punk", params)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


func _pose(t: float) -> void:
	# 棘：1コマ目に大きく、2コマ目に行き過ぎ、3コマ目で落ち着く
	var pop: float = [0.55, 1.2, 1.0][mini(int(t * FPS), 2)]
	_burst.scale = Vector3.ONE * 3.4 * _size * pop
	_burst.visible = t < 1.3
	param(_burst, "phase", t)
	param(_burst, "wear", smoothstep(0.7, 1.25, t))
	# ギザギザ：外へ描かれ、描きはじめ側から走り去る
	for i in _zigs.size():
		var m: MeshInstance3D = _zigs[i]
		var since := t - float(ZIGS[i][2])
		m.visible = since >= 0.0 and since < 0.75
		param(m, "phase", t)
		param(m, "grow", clampf(since / 0.12, 0.0, 1.0))
		param(m, "wear", clampf((since - 0.38) / 0.3, 0.0, 1.0))
	# ×：少し遅れて貼られ、最後まで残る
	var stuck := t - 0.17
	_cross.visible = stuck >= 0.0 and t < 1.5
	_cross.scale = Vector3.ONE * 1.0 * _size * (1.25 if stuck < 1.0 / FPS else 1.0)
	param(_cross, "phase", t)
	param(_cross, "wear", smoothstep(1.0, 1.45, t))
