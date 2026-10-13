extends "res://scripts/prop.gd"
# Four independent hinges; lid state travels with the prop snapshot.
const CLOSED := [-2.96467, 0.06733, 0.12419, -0.06582]
const OPEN := [0.0, PI + 0.06733, -PI + 0.14919, -PI - 0.06582]
const BASE_SCALE := 2.0      # 下の当たり判定の寸法を決めたときの拡大率。stage.gd の scale を変えても、同じ比率で付いてくる
const Pack := preload("res://scripts/carton_pack.gd")
var opened := true
var open_amount := 1.0
var flaps: Array[Node3D] = []
var lid: CollisionShape3D
var room := AABB()           # 箱の内側（ローカル座標）。中身の見た目を置く範囲
var empty_mass := 2.0        # 空の箱の重さ（中身を入れると、その分だけ重くなる）
var _inside: Node3D          # 中身の見た目（入っている物の、実寸の写し）
var _inside_sig := ""
var _fills: Array = []       # 中身と同じ大きさの当たり（上に物を置ける・ロープが上を通る）

func configure() -> void:
	# 見た目の拡大率に合わせて、当たり判定も同じ比率で大きくする
	var k: float = visual.scale.x / BASE_SCALE
	empty_mass = mass
	for side: String in ["Front", "Right", "Back", "Left"]:
		flaps.append(visual.find_child("Flap" + side, true, false) as Node3D)
	# Keep the interior empty when open; closing adds a surface across the top.
	_box(Vector3(0, 0.014, 0) * k, Vector3(0.82, 0.028, 0.60) * k)
	for x in [-0.405, 0.405]:
		_box(Vector3(x, 0.28, 0) * k, Vector3(0.022, 0.56, 0.60) * k)
	for z in [-0.295, 0.295]:
		_box(Vector3(0, 0.28, z) * k, Vector3(0.82, 0.56, 0.022) * k)
	lid = _box(Vector3(0, 0.57, 0) * k, Vector3(0.82, 0.022, 0.60) * k)
	room = AABB(Vector3(-0.385, 0.03, -0.275) * k, Vector3(0.77, 0.52, 0.55) * k)
	_apply_lids()


# 閉じた箱の見た目だけ（当たり判定なし）。段ボール置き場の山に使う
static func closed_model(size_scale: float) -> Node3D:
	var model: Node3D = (load("res://assets/gear/carton.glb") as PackedScene).instantiate()
	model.scale = Vector3.ONE * size_scale
	var sides := ["Front", "Right", "Back", "Left"]
	for i in sides.size():
		var flap := model.find_child("Flap" + String(sides[i]), true, false) as Node3D
		if flap == null:
			continue
		if i in [0, 2]:
			flap.rotation.x = CLOSED[i]
		else:
			flap.rotation.z = CLOSED[i]
	return model


# 中身の見た目を作り直す。list：[[物, 箱から見た置き方（Transform3D）], ...]（入れた順）。
# 物そのものは現場に無い扱いで隠してあり、ここに置くのは、実寸の写しと、同じ大きさの当たり。
# 置き方（どこに・どの向きで積むか）は cargo_kit.gd が決める（carton_pack.gd の計算。底から積む）
func show_contents(list: Array) -> void:
	var sig := ""
	for entry: Array in list:
		sig += "%d:%s," % [int(entry[0].pid), str(entry[1])]
	if sig == _inside_sig:
		return
	_inside_sig = sig
	if _inside != null:
		remove_child(_inside)
		_inside.queue_free()
		_inside = null
	for old: Node in _fills:
		remove_child(old)
		old.queue_free()
	_fills.clear()
	if list.is_empty():
		return
	_inside = Node3D.new()
	_inside.name = "Inside"
	add_child(_inside)
	for entry: Array in list:
		var thing: Node3D = entry[0]
		var xf: Transform3D = entry[1]
		if thing.visual != null:
			var holder := Node3D.new()
			holder.name = "Item%d" % int(thing.pid)
			holder.transform = xf
			holder.add_child(thing.visual.duplicate(0))
			_inside.add_child(holder)
		var block: AABB = Pack.box_of(xf, thing.center, thing.half)
		var fill := _box(block.get_center(), (block.size - Vector3(Pack.SQUEEZE, 0.0, Pack.SQUEEZE)).max(Vector3.ONE * 0.02))
		fill.name = "Fill%d" % int(thing.pid)
		_fills.append(fill)

func _box(pos: Vector3, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	add_child(cs)
	return cs

func _follow_net(delta: float) -> void:
	super._follow_net(delta)
	if not game.replaying:
		_host_tick(delta)

func _host_tick(delta: float) -> void:
	open_amount = move_toward(open_amount, 1.0 if opened else 0.0, delta / 0.4)
	_apply_lids()

func _apply_lids() -> void:
	for i in flaps.size():
		# Side flaps fold first, then the two outer flaps overlap them.
		var t := clampf(open_amount * 1.25 - (0.0 if i in [0, 2] else 0.25), 0.0, 1.0)
		t = smoothstep(0.0, 1.0, t)
		var angle: float = lerpf(CLOSED[i], OPEN[i], t)
		if i in [0, 2]:
			flaps[i].rotation.x = angle
		else:
			flaps[i].rotation.z = angle
	lid.set_deferred("disabled", open_amount > 0.02)

func get_state() -> Array:
	var s := super.get_state()
	s.append(open_amount)
	s.append(opened)
	return s

func _apply_extra(s: Array) -> void:
	if s.size() >= 5 and (is_host() or playback or game.replaying):
		open_amount = float(s[3])
		opened = s[4]
		_apply_lids()
