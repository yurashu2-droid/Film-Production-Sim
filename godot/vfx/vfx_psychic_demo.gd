extends "res://vfx/vfx_base.gd"
# ラボ用の台：念力（vfx_psychic.gd）を、動く小道具で見る。ゲームでは使わない。
# 小道具を「つかむ → 持ち上げる → 速く振る → 止める → 回しながら寄せる → 止める → 離す（落ちる）」の順に動かす。

const Psychic := preload("res://vfx/vfx_psychic.gd")
const MODELS := {
	"box": "res://assets/props/P069_apple_box.glb",
	"basket": "res://assets/props/P070_prop_basket.glb",
	"fish": "res://assets/props/P039_rubber_fish.glb",
	"flat": "res://assets/props/scenic_flat.glb",
}
const GRAB := 0.25
const DROP := 4.3
# [時刻, 場所, 向き（度）]。間は、ゆっくり出てゆっくり止まる
const PATH := [
	[0.0, Vector3(-1.4, 0.0, 0.9), Vector3(0, 20, 0)],
	[0.45, Vector3(-1.4, 0.0, 0.9), Vector3(0, 20, 0)],
	[1.1, Vector3(-1.2, 1.4, 0.7), Vector3(8, 40, -6)],
	[1.75, Vector3(1.9, 2.0, -0.5), Vector3(-10, 150, 14)],
	[3.0, Vector3(1.9, 2.05, -0.5), Vector3(-6, 160, 10)],
	[3.7, Vector3(-0.3, 1.2, 1.1), Vector3(20, 320, -12)],
	[4.3, Vector3(-0.3, 1.25, 1.1), Vector3(16, 330, -8)],
]

var _prop: Node3D
var _fx: Node3D
var _hands := PackedVector3Array()
var _grip_local := Vector3.ZERO
var _tint := Psychic.TINT
var _style := "mix"
var _fall := 0.0
var _rest_y := 0.0


# wall が真なら、物を止める場所のすぐ後ろに壁を立てる（壁や床にくっつけた時の見え方を確かめる）
static func spawn(parent: Node, hand: Vector3, model: String = "box", tint: Color = Psychic.TINT, style: String = "mix", wall: bool = false) -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.start(hand, model, tint, style)
	if wall:
		fx.add_wall()
	return fx


func start(hand: Vector3, model: String, tint: Color, style: String) -> void:
	life = 5.6
	_tint = tint
	_style = style
	_hands = PackedVector3Array([hand + Vector3(0, 0, 0.2), hand + Vector3(0, 0, -0.2)])
	_prop = (load(MODELS.get(model, MODELS["box"])) as PackedScene).instantiate()
	add_child(_prop)
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in _prop.find_children("*", "MeshInstance3D", true, false):
		var part: AABB = (_prop.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	_rest_y = -box.position.y
	# つかむ点：手の側の面の、少し上
	_grip_local = box.get_center() + Vector3(-box.size.x * 0.5, box.size.y * 0.2, 0)
	_pose(0.0)


func add_wall() -> void:
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4.5, 3.6, 0.2)
	wall.mesh = box
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.55, 0.6, 0.62)
	wall.material_override = paint
	add_child(wall)
	# 止める場所（PATH の 1.75〜3.0 秒）の物の後ろの面に、ほぼ触れる所
	wall.position = Vector3(1.6, 1.8, -0.5 - 0.3)


func _tick(delta: float) -> void:
	if age < DROP:
		_pose(age)
	else:
		# 離した後：その場から落ちて、床で止まる
		_fall += 16.0 * delta
		_prop.position.y = maxf(_rest_y, _prop.position.y - _fall * delta)
	if _fx == null and age >= GRAB and age < DROP:
		_fx = Psychic.attach(self, _prop, {"tint": _tint, "style": _style})
	if is_instance_valid(_fx):
		_fx.hold(_hands, _prop.global_transform * _grip_local)
		if age >= DROP and _fx.holding():
			_fx.release()


func _pose(t: float) -> void:
	var i := 0
	while i < PATH.size() - 2 and t >= float(PATH[i + 1][0]):
		i += 1
	var a: Array = PATH[i]
	var b: Array = PATH[i + 1]
	var k := smoothstep(0.0, 1.0, clampf((t - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))
	var turn: Vector3 = (a[2] as Vector3).lerp(b[2], k) * (PI / 180.0)
	# 止めている間も、ほんの少し浮き沈みする
	var bob := Vector3(0, sin(t * 2.6) * 0.03, 0) if t > 1.1 else Vector3.ZERO
	_prop.transform = Transform3D(Basis.from_euler(turn), (a[1] as Vector3).lerp(b[1], k) + Vector3(0, _rest_y, 0) + bob)
