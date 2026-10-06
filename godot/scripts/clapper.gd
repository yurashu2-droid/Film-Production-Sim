extends "res://scripts/prop.gd"
# カチンコ。持って「使う」と本番開始・カットの合図になる。板にテイク番号が出る。

const SIZE := 1.6
const OPEN := 0.0
const SHUT := -0.32

var stick: Node3D
var take_label: Label3D
var _tween: Tween


func build() -> void:
	kind = "clapper"
	label = "カチンコ"
	mass = 0.8
	center = Vector3(0, 0.16, 0) * SIZE
	half = Vector3(0.16, 0.17, 0.03) * SIZE
	hold_min = 1.0
	visual = (load("res://assets/props/P051_clapperboard.glb") as PackedScene).instantiate()
	visual.scale = Vector3.ONE * SIZE
	add_child(visual)

	# 上の拍子木だけを蝶番で動かせるようにまとめ直す
	var root: Node3D = visual.get_child(0)
	stick = Node3D.new()
	stick.position = Vector3(-0.15, 0.235, 0)
	root.add_child(stick)
	for n: Node in root.get_children():
		var nm := String(n.name)
		var top := nm.contains("clapper_top")
		for odd: String in ["stripe_005", "stripe_007", "stripe_009", "stripe_011", "stripe_013"]:
			if nm.contains(odd):
				top = true
		if top and n is Node3D:
			var keep: Transform3D = (n as Node3D).transform
			n.owner = null
			root.remove_child(n)
			stick.add_child(n)
			(n as Node3D).transform = stick.transform.affine_inverse() * keep
		elif nm.contains("numbers"):
			(n as Node3D).visible = false

	take_label = Label3D.new()
	take_label.font = game.font
	take_label.font_size = 64
	take_label.pixel_size = 0.0008
	take_label.outline_size = 0
	take_label.modulate = Color(0.96, 0.96, 0.92)
	take_label.double_sided = false
	take_label.position = Vector3(0, 0.085, 0.024)
	root.add_child(take_label)
	set_take(1)

	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.32, 0.33, 0.06) * SIZE
	cs.shape = b
	cs.position = center
	add_child(cs)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.08, 0) * SIZE


func set_take(n: int) -> void:
	take_label.text = "TAKE %d" % n


# 拍子木を打つ
func clap() -> void:
	if _tween:
		_tween.kill()
	stick.rotation.z = OPEN
	_tween = create_tween()
	_tween.tween_property(stick, "rotation:z", SHUT, 0.06)
	_tween.tween_interval(0.7)
	_tween.tween_property(stick, "rotation:z", OPEN, 0.25)
