extends "res://scripts/prop.gd"
# 搬入口に停まっている軽トラ。荷台に機材を積んで届く。動かせない。
# 車の段階が上がると「ロケバン」に替わる（set_vehicle）。荷台の数値と当たり判定も一緒に替わる。

# 道路とキャラクターに対して存在感を出す。見た目・荷台・当たり判定を同じ倍率に揃える。
const VEHICLE_SCALE := 1.55
var _travel_state := -1
var _cargo_panels: Array = []

const KEI_GLB := "res://assets/stage/kei_truck.glb"
const VAN_GLB := "res://assets/stage/location_van.glb"
# バンの元モデルは全長5.41m×幅2.26m×高さ2.29m。駐車枠（x76..84, z13..23）と現場の駐車位置に収めるため0.9倍にする
# → 全長およそ4.87m、幅2.04m（ミラー込み）、高さ2.06m
const VAN_SCALE := 0.9
const VAN_HATCH_DEG := 95.0   # 後ろのハッチを開ける角度（元モデルの全開）

var vehicle := "kei"          # "kei" | "van"
var _installed := ""          # 実際に組み上がっている車種（空=まだ何も組んでいない）
var _shapes: Array = []
# ロープを掛けるフック（車体から見た位置。実寸）。荷物の上にロープを渡して、端をここに結ぶ（cargo_kit.gd）
var hooks: Array[Vector3] = []
var rope_ceiling := 3.0       # ロープを投げて渡すとき、これより上は越えない（車体から見た高さ）


func build() -> void:
	kind = "truck"
	mass = 800.0
	immovable = true
	hold_min = 3.0
	_install("kei")


# 軽トラ/ロケバンを切り替える。誰が・いつ呼んでも安全で、同じ車種なら何もしない。
# すでに荷台に載っている物は、荷台の高さの差だけ上下にずらす（はみ出す物は荷台の中へ寄せる）
func set_vehicle(which: String) -> void:
	if which != "kei" and which != "van":
		return
	if which == _installed:
		return
	_install(which)


func _install(which: String) -> void:
	_travel_state = -1
	var old_top: float = deck_top if _installed != "" else -1.0
	var old_c := deck_c
	var old_half := deck_half
	_installed = which
	vehicle = which
	if visual != null:
		remove_child(visual)
		visual.queue_free()
		visual = null
	if which == "van":
		_setup_van()
	else:
		_setup_kei()
	_scale_vehicle()
	add_child(visual)
	_build_hooks()
	# 当たり判定は物理の処理中に触れないので、木に入っているときは後回しにする
	if is_inside_tree():
		_rebuild_shapes.call_deferred()
	else:
		_rebuild_shapes()
	if old_top >= 0.0:
		_reseat_riders(old_top, old_c, old_half)


func _setup_kei() -> void:
	label = "軽トラ"
	center = Vector3(0, 0.9, 0)
	half = Vector3(0.9, 0.9, 1.73)
	deck_top = 0.67
	deck_half = Vector2(0.66, 0.92)
	deck_c = Vector2(0, -0.72)
	visual = (load(KEI_GLB) as PackedScene).instantiate()
	# 後ろのあおりを倒して、荷下ろしできる状態にしておく
	var tail: Node3D = visual.find_child("TAILGATE_HINGE_X", true, false)
	if tail:
		tail.rotate_object_local(Vector3.RIGHT, -PI * 0.5)


func _setup_van() -> void:
	label = "ロケバン"
	center = Vector3(0, 1.03, 0)
	half = Vector3(0.95, 1.03, 2.44)
	# 荷室の床（ゴムの床）の上面は元モデルで高さ約0.6m。そこから後ろ～運転席の背もたれの手前まで空ける
	deck_top = 0.55
	deck_half = Vector2(0.74, 1.575)
	deck_c = Vector2(0, -0.725)
	var model := (load(VAN_GLB) as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * VAN_SCALE
	_adjust_van_wheel(model)
	visual = Node3D.new()
	visual.add_child(model)
	# 荷物が見えるように、後ろのハッチとスライドドアを開け、座席・棚（荷室の改装部分）は外す
	var conv: Node3D = model.find_child("CREW_CONVERSION_ROOT", true, false)
	if conv:
		conv.visible = false
	var hatch: Node3D = model.find_child("REAR_HATCH_PIVOT", true, false)
	if hatch:
		hatch.rotation_degrees.x = VAN_HATCH_DEG
	var slide: Node3D = model.find_child("SLIDING_DOOR_ROOT", true, false)
	if slide:
		slide.position += Vector3(0.13, 0.0, -1.45)
	_van_supports(model, hatch)


# ハッチのガスステーを、開いたハッチの取り付け点へ向け直す（見た目だけ）
func _adjust_van_wheel(model: Node3D) -> void:
	var part: MeshInstance3D = model.find_child("ASSEMBLY_LOCATION_VAN_ROOT",true,false)
	if part == null: return
	var source: ArrayMesh = part.mesh
	var mesh := ArrayMesh.new()
	var region := AABB(Vector3(-0.69,1.16,1.84),Vector3(0.41,0.34,0.32))
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var material: Material = source.surface_get_material(surface)
		if material.resource_name.begins_with("Polymer"):
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				if region.has_point(vertices[i]): vertices[i].z -= 0.30
			arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(surface,material)
	part.mesh = mesh

func _van_supports(model: Node3D, hatch: Node3D) -> void:
	if hatch == null:
		return
	for side in ["L", "R"]:
		var support: Node3D = model.find_child("HATCH_GAS_SUPPORT_" + side, true, false)
		var piston: Node3D = model.find_child("HATCH_GAS_PISTON_" + side, true, false)
		var end: Node3D = model.find_child("HATCH_SUPPORT_END_" + side, true, false)
		if support == null or piston == null or end == null:
			continue
		var to: Vector3 = hatch.transform * end.position - support.position
		var length := to.length()
		if length < 0.3:
			continue
		support.basis = Basis.looking_at(to.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
		piston.position.y = (0.25 + length) * 0.5
		piston.scale.y = maxf(0.02, length - 0.25)


func _rebuild_shapes() -> void:
	for s: Node in _shapes:
		if is_instance_valid(s):
			if s.get_parent() == self:
				remove_child(s)
			s.queue_free()
	_shapes.clear()
	if _installed == "van":
		# 荷室の床・車体の下
		_box(Vector3(0, 0.27, -0.01), Vector3(1.8, 0.54, 4.86))
		# 荷室の左右の壁。右（スライドドア側）は、ドアの開口部ぶん（z -0.53..0.79）を空けて、横からも荷物を狙える
		# 壁と屋根の高さは見た目どおり。後ろ側は壁も屋根も作らない（後ろから荷物を狙え、手を伸ばせる）
		_box(Vector3(-0.84, 1.245, -0.725), Vector3(0.12, 1.41, 3.15))
		_box(Vector3(0.84, 1.245, -1.415), Vector3(0.12, 1.41, 1.77))
		# 運転席とボンネット
		_box(Vector3(0, 0.975, 1.425), Vector3(1.8, 1.95, 1.15))
		_box(Vector3(0, 0.575, 2.21), Vector3(1.8, 1.15, 0.42))
	else:
		_box(Vector3(0, 0.88, 1.0), Vector3(1.7, 1.76, 1.45))
		_box(Vector3(0, 0.44, -0.72), Vector3(1.5, 0.44, 1.95))
	_build_cargo_walls()


func _scale_vehicle() -> void:
	visual.scale *= VEHICLE_SCALE
	center *= VEHICLE_SCALE
	half *= VEHICLE_SCALE
	deck_top *= VEHICLE_SCALE
	deck_half *= VEHICLE_SCALE
	deck_c *= VEHICLE_SCALE


func _box(c: Vector3, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size * VEHICLE_SCALE
	cs.shape = b
	cs.position = c * VEHICLE_SCALE
	add_child(cs)
	_shapes.append(cs)
	return cs


# 荷台の高さが変わった分だけ、載っている物をずらす（production_prop の昇降荷台と同じ）。
# 横の位置は、新しい荷台に収まるならそのまま、はみ出すなら中へ寄せる
func _reseat_riders(old_top: float, _old_c: Vector2, _old_half: Vector2) -> void:
	if game == null:
		return
	var dy := deck_top - old_top
	var mx := maxf(deck_half.x - 0.1, 0.05)
	var mz := maxf(deck_half.y - 0.16, 0.05)
	for r: RigidBody3D in game.props.values():
		if r == self or r.rider_of != pid:
			continue
		var o: Vector3 = r.ride_local.origin
		o.x = clampf(o.x, deck_c.x - mx, deck_c.x + mx)
		o.z = clampf(o.z, deck_c.y - mz, deck_c.y + mz)
		o.y += dy
		r.ride_local.origin = o
		if is_inside_tree() and r.is_inside_tree():
			r.global_transform = global_transform * r.ride_local


# 荷台の側板と可動パネル。モデルの比率を変えずに、当たり判定を揃える。
func _build_cargo_walls() -> void:
	_cargo_panels.clear()
	if "vehicle" in self and get("vehicle") == "van":
		_box(Vector3(0,2.015,-0.725),Vector3(1.8,0.09,3.15))
		_add_cargo_panel("REAR_HATCH_PIVOT",Vector3(0,-0.80,0),Vector3(1.70,1.58,0.09))
		_add_cargo_panel("SLIDING_DOOR_ROOT",Vector3(0,0.67,0.06),Vector3(0.09,1.77,1.46))
	else:
		for side in [-1.0,1.0]:
			_box(Vector3(side*0.713,0.807,-0.72),Vector3(0.085,0.29,1.91))
		_box(Vector3(0,0.807,0.22),Vector3(1.45,0.29,0.07))
		# 鳥居の空いている部分は塞がず、柱と上の桟だけを支える。
		for side in [-1.0,1.0]:
			_box(Vector3(side*0.665,1.35,0.22),Vector3(0.06,0.8,0.06))
		_box(Vector3(0,1.725,0.22),Vector3(1.39,0.06,0.06))
		_add_cargo_panel("TAILGATE_HINGE_X",Vector3(0,0.143,-0.006),Vector3(1.45,0.29,0.05))


func _panel_transform(panel: Node3D) -> Transform3D:
	var at := Transform3D.IDENTITY
	var node := panel
	while node != self:
		at = node.transform * at
		node = node.get_parent() as Node3D
	return at


func _add_cargo_panel(part: String, c: Vector3, size: Vector3) -> void:
	var panel: Node3D = visual.find_child(part,true,false)
	if panel == null: return
	var at := _panel_transform(panel)
	var shape := _box(Vector3.ZERO,size*at.basis.get_scale().abs()/VEHICLE_SCALE)
	shape.transform = Transform3D(at.basis.orthonormalized(),at*c)
	_cargo_panels.append([shape,panel,c])


func _update_cargo_panels() -> void:
	for panel: Array in _cargo_panels:
		# 車種切り替え中は、古いモデルを外してから衝突を作り直す。
		if not is_instance_valid(panel[1]) or not is_ancestor_of(panel[1]):
			continue
		var at := _panel_transform(panel[1])
		panel[0].transform = Transform3D(at.basis.orthonormalized(),at*(panel[2] as Vector3))


# ロープを掛けるフックの場所を決める（hooks）。
#   軽トラ：モデルに元からあるロープフック（左右のあおりの下に5つずつ並んだ、亜鉛めっきの金具）の位置に合わせる。
#           いちばん後ろの物が、荷台の後ろの角。前は、鳥居の柱に1つずつ足す（ここはモデルに金具が無いので、板と輪を付ける）
#   ロケバン：モデルに金具が無いので、荷室の中の左右の壁（床から少し上）に、板と輪を付ける。スライドドアの開く所には付けない
# どのフックにも、目印の黄色い輪を下げる（どこに結べるか、見て分かるように）。
# あおり（後ろの板）の真下には付けない：モデルにも金具が無く、停まっている間は板が倒れていて、走り出すと起きるので、
# ロープが板を通り抜けてしまう
func _build_hooks() -> void:
	var before := get_node_or_null("RopeHooks")
	if before != null:
		remove_child(before)
		before.queue_free()
	hooks.clear()
	var s := VEHICLE_SCALE
	var out_dirs: Array[Vector3] = []
	var plates: Array[bool] = []          # 板も付けるか（モデルに金具が無い所）
	if _installed == "van":
		rope_ceiling = 1.97 * s - 0.1
		for z: float in [-2.0, -1.1, -0.2, 0.6]:
			hooks.append(Vector3(-0.78 * s + 0.035, deck_top + 0.32, z * s))
			out_dirs.append(Vector3.RIGHT)
			plates.append(true)
		for z: float in [-2.0, -1.1]:
			hooks.append(Vector3(0.78 * s - 0.035, deck_top + 0.32, z * s))
			out_dirs.append(Vector3.LEFT)
			plates.append(true)
	else:
		rope_ceiling = deck_top + 2.6
		for side: float in [-1.0, 1.0]:
			for z: float in [-1.57, -1.21, -0.79, -0.37, 0.045]:
				hooks.append(Vector3(side * (0.78 * s + 0.02), 0.648 * s, z * s))
				out_dirs.append(Vector3(side, 0, 0))
				plates.append(false)
		for side: float in [-1.0, 1.0]:
			hooks.append(Vector3(side * 0.665 * s, 1.22 * s, 0.19 * s - 0.035))
			out_dirs.append(Vector3.FORWARD)
			plates.append(true)
	var root := Node3D.new()
	root.name = "RopeHooks"
	add_child(root)
	var zinc := StandardMaterial3D.new()
	zinc.albedo_color = Color(0.88, 0.74, 0.22)
	zinc.metallic = 0.55
	zinc.roughness = 0.45
	for i in hooks.size():
		var facing: Vector3 = out_dirs[i]
		var across: Vector3 = Vector3.UP.cross(facing).normalized()
		var hook := Node3D.new()
		hook.name = "Hook%d" % i
		# 輪の軸を、壁に沿った横向きにする（輪が壁から突き出して見える）
		hook.transform = Transform3D(Basis(facing, across, facing.cross(across)), hooks[i])
		root.add_child(hook)
		if plates[i]:
			var plate := MeshInstance3D.new()
			var slab := BoxMesh.new()
			slab.size = Vector3(0.014, 0.13, 0.11)
			plate.mesh = slab
			plate.material_override = zinc
			plate.position = Vector3(-0.03, 0, 0)
			hook.add_child(plate)
		var ring := MeshInstance3D.new()
		var loop := TorusMesh.new()
		loop.inner_radius = 0.028 if plates[i] else 0.022
		loop.outer_radius = 0.046 if plates[i] else 0.036
		loop.rings = 14
		loop.ring_segments = 8
		ring.mesh = loop
		ring.material_override = zinc
		if not plates[i]:
			# モデルの金具に下げた輪：金具の先から、少し下に垂れる
			ring.position = Vector3(0.0, 0.0, -0.03)
		hook.add_child(ring)


# 腰の支点とハンドルは車体ローカル座標。先頭の乗員が運転、次の乗員が助手席。
func seat(index: int) -> Dictionary:
	var van: bool = "vehicle" in self and get("vehicle") == "van"
	var base_scale := VEHICLE_SCALE * (0.9 if van else 1.0)
	var hip := Vector3(0.367,0.82,0.84)
	var wheel := Vector3(0.367,1.075,1.11)
	var radius := 0.169
	if van:
		hip = Vector3(-0.51,1.07,1.42)
		wheel = Vector3(-0.482,1.4325,1.75)
		radius = 0.195
	if index == 1:
		hip.x *= -1.0
	elif index >= 2:
		hip = Vector3(-0.40 if index % 2 == 0 else 0.40, 0.85 if van else 0.79, -0.75)
	return {"hip":hip*base_scale, "wheel":wheel*base_scale, "radius":radius*base_scale, "roof":(1.96 if van else 1.70)*base_scale if index < 2 else 10.0}

func set_traveling(value: bool) -> void:
	if _travel_state == int(value): return
	_travel_state = int(value)
	var tail: Node3D = visual.find_child("TAILGATE_HINGE_X",true,false)
	if tail: tail.rotation.x = 0.0 if value else -PI*0.5
	var hatch: Node3D = visual.find_child("REAR_HATCH_PIVOT",true,false)
	if hatch: hatch.rotation_degrees.x = 0.0 if value else 95.0
	var slide: Node3D = visual.find_child("SLIDING_DOOR_ROOT",true,false)
	if slide: slide.position = Vector3(0.927,0.625,0.08) + (Vector3.ZERO if value else Vector3(0.13,0,-1.45))
	_update_cargo_panels()
	if hatch and has_method("_van_supports"): call("_van_supports",hatch.get_parent(),hatch)

func drive_to(point: Vector3) -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	global_position = point

func _ready() -> void:
	super._ready()
	set_fixed(true)
