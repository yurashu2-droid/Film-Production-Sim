extends Node3D
## ハンガーに吊るしたキャラ（キャラ選びのタンス用。2026-11-23 ユーザーの案：絵ではなく、ゲームのモデルを吊るして、カーソルで揺らす）。
##   ・この物の原点が、棒に掛かるフックの位置。ハンガー・紐・キャラは、その下にぶら下がる
##   ・全体は、フックを軸にした振り子（ばね）。腕・足・頭は、それぞれ別の振り子で、遅れてついて来る
##   ・体の動き（歩く・待つ）は止めて、力の抜けた姿勢を骨へ直接入れる。まばたきは残す
##   ・push(強さ) で揺らす。pull で手前に引き出す（0〜1）
const CastVisual := preload("res://scripts/cast_visual.gd")
const Strip := preload("res://scripts/ui/cast_strip.gd")
const WIDE := {"01": 0.74, "02": 0.8, "M02": 0.8, "09": 0.86}     # 横に大きいキャラは、となりに当たらないよう、もう少し縮める
const FIT_H := 1.55               # 吊るした時の、頭のてっぺんから足までの上限（m）。大きいキャラは縮める

const WOOD := Color("c98a45")
const CORD := Color("efe2c2")
const HANGER_W := 0.46            # ハンガーの幅
const HANGER_DROP := 0.16         # フックから、ハンガーの肩の先までの下がり
const CORD_LEN := 0.16            # ハンガーから頭のてっぺんまでの紐
# 振り子：[骨の名前の頭, 固さ, 止まりやすさ, つられやすさ, 休みの向きからの回し（度。左側の値。右は逆）]
const LIMBS := [
	["UPPER_ARM", 24.0, 1.7, 2.3, -66.0],
	["FOREARM", 18.0, 1.5, 3.1, -80.0],
	["HAND", 15.0, 1.4, 3.6, -86.0],
	["THIGH", 24.0, 1.9, 1.6, 6.0],
	["SHIN", 18.0, 1.6, 2.4, 2.0],
	["FOOT", 15.0, 1.5, 2.8, 0.0],
]

var tag := ""
var vis: Node3D
var skel: Skeleton3D
var swing := 0.0                  # 全体の揺れ（ラジアン。画面の中で左右）
var swing_v := 0.0
var nod := 0.0                    # 前後の揺れ（手前・奥）
var nod_v := 0.0
var pull := 0.0                   # 手前に引き出している割合
var _rig := Node3D.new()          # フックを軸に回る所
var _parts: Array = []            # [骨, 親, 休みの向き（骨格の中）, 角度, 速さ, 固さ, 止まり, つられ, 回し]
var _pivot := Node3D.new()        # 紐の先（頭のてっぺん）。体は、ここを軸に、ハンガーより遅れて揺れる
var _body_a := 0.0
var _body_v := 0.0
var _hot := false                 # カーソルが乗っているか
var _swing_before := 0.0
var _t := 0.0
var _seed := 0.0


func setup(cast_tag: String, index: int = 0) -> void:
	tag = cast_tag
	_seed = float(index) * 1.7
	add_child(_rig)
	_pivot.position = Vector3(0, -(HANGER_DROP + CORD_LEN), 0)
	_rig.add_child(_pivot)
	vis = CastVisual.new()
	_pivot.add_child(vis)
	vis.setup(tag)
	skel = vis.skel
	Strip.strip(vis, tag)             # 生身（肌・顔・髪）を抜いて、服と持ち物だけにする
	# 体の動きを止める（顔は残す）。足を床に合わせる・歩幅・持つ腕の直しも止める
	vis.air_enabled = false
	vis.grounding_enabled = false
	vis.stride_enabled = false
	if vis.hold_arms != null:
		vis.hold_arms.active = false
	vis.anim.stop()
	for i in skel.get_bone_count():
		var bone_name := skel.get_bone_name(i)
		if not _is_face(bone_name):
			skel.reset_bone_pose(i)
	for row: Array in LIMBS:
		for side: String in [".L", ".R"]:
			var b := skel.find_bone(str(row[0]) + side)
			if b < 0:
				continue
			var turn := deg_to_rad(float(row[4])) * (1.0 if side == ".L" else -1.0)
			_parts.append([b, skel.get_bone_parent(b), skel.get_bone_global_rest(b).basis, 0.0, 0.0, float(row[1]), float(row[2]), float(row[3]), turn])
	# 頭のてっぺんを、紐の先（ハンガーの下）に合わせる
	var top := _top_y()
	var k := minf(1.0, FIT_H / top) * float(WIDE.get(tag, 1.0))
	vis.scale = Vector3.ONE * k
	top *= k
	vis.position = Vector3(0, -top, 0)
	_build_hanger(top)
	# 頭の物（帽子）の下で途切れないよう、紐を胸の高さまで下ろす（体と一緒に揺れる）
	var cord := StandardMaterial3D.new()
	cord.albedo_color = CORD
	cord.roughness = 1.0
	var chest := -top * 0.42
	for side: float in [-1.0, 1.0]:
		_stick(Vector3(side * 0.03, -0.02, -0.02), Vector3(side * 0.1, chest, -0.02), 0.0035, cord, _pivot)
	_pose(0.0)


func _is_face(bone_name: String) -> bool:
	for key: String in CastVisual.FACE_BONES:
		if bone_name.begins_with(key):
			return true
	return false


# キャラのいちばん高い所（キャラの原点から）
func _top_y() -> float:
	var top := 0.0
	for mi: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
		# 木に入る前でも測れるように、親をたどって掛ける（global_transform は使わない）
		var xf := Transform3D.IDENTITY
		var node: Node = mi
		while node != vis and node != null:
			if node is Node3D:
				xf = (node as Node3D).transform * xf
			node = node.get_parent()
		var box: AABB = xf * mi.get_aabb()
		top = maxf(top, box.end.y)
	return top


func _build_hanger(_top: float) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD
	wood.roughness = 0.8
	var cord := StandardMaterial3D.new()
	cord.albedo_color = CORD
	cord.roughness = 1.0
	# フック（棒に掛かる輪）と首
	var hook := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.022
	torus.outer_radius = 0.034
	hook.mesh = torus
	hook.rotation.x = PI * 0.5
	hook.material_override = cord
	_rig.add_child(hook)
	_stick(Vector3(0, -0.03, 0), Vector3(0, -0.075, 0), 0.006, cord)
	# 肩（山の形に、棒を2本）と、下の横棒
	var mid := Vector3(0, -0.075, 0)
	var left := Vector3(-HANGER_W * 0.5, -HANGER_DROP, 0)
	var right := Vector3(HANGER_W * 0.5, -HANGER_DROP, 0)
	_stick(mid, left, 0.014, wood)
	_stick(mid, right, 0.014, wood)
	_stick(left, right, 0.009, wood)
	# 紐：ハンガーの左右から、頭のてっぺんへ
	var head_top := Vector3(0, -(HANGER_DROP + CORD_LEN) - 0.02, 0)
	_stick(Vector3(-HANGER_W * 0.3, -HANGER_DROP, 0), head_top, 0.004, cord)
	_stick(Vector3(HANGER_W * 0.3, -HANGER_DROP, 0), head_top, 0.004, cord)


func _stick(a: Vector3, b: Vector3, radius: float, mat: Material, into: Node = null) -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 10
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	var dir := (b - a).normalized()
	mi.basis = Basis(Quaternion(Vector3.UP, dir)) if absf(dir.dot(Vector3.UP)) < 0.999 else Basis.IDENTITY
	(into if into != null else _rig).add_child(mi)


# 揺らす（カーソルが乗った・となりが動いた）。正で右へ
func push(strength: float) -> void:
	swing_v += strength
	nod_v += absf(strength) * 0.35


func _process(delta: float) -> void:
	delta = minf(delta, 0.05)
	_t += delta
	# そよぐ程度の、いつもの小さな揺れ
	var breeze := sin(_t * 0.9 + _seed) * 0.05 + sin(_t * 2.3 + _seed * 2.0) * 0.02
	swing_v += (-swing * 20.0 - swing_v * 1.5 + breeze) * delta
	swing += swing_v * delta
	nod_v += (-nod * 24.0 - nod_v * 2.0) * delta
	nod += nod_v * delta
	var accel := (swing - _swing_before) / maxf(delta, 0.001)
	_swing_before = swing
	for p: Array in _parts:
		# 体が振られた分だけ、逆へ取り残される → ばねで真下へ戻る
		p[4] += (-p[3] * p[5] - p[4] * p[6]) * delta - ((swing_v + _body_v) * p[7]) * delta * 3.0
		p[3] = clampf(p[3] + p[4] * delta, -1.3, 1.3)
	_body_v += (-_body_a * 30.0 - _body_v * 2.2) * delta - swing_v * 1.6 * delta * 3.0
	_body_a = clampf(_body_a + _body_v * delta, -0.6, 0.6)
	_pose(accel)


func _pose(_accel: float) -> void:
	_rig.rotation = Vector3(nod * 0.5, 0, swing)
	position.z = pull * 0.35
	if skel == null:
		return
	_pivot.rotation.z = _body_a
	# 親から順に入っているので、親の今の向きを読んで、そこからの回りに直す
	for p: Array in _parts:
		var want: Basis = Basis(Vector3.BACK, float(p[8]) + float(p[3])) * (p[2] as Basis)
		var parent_now: Basis = skel.get_bone_global_pose(p[1]).basis.orthonormalized()
		skel.set_bone_pose_rotation(p[0], (parent_now.inverse() * want).get_rotation_quaternion())


# 画面の上で、このキャラが占める四角（カーソルの当たり）
func screen_rect(cam: Camera3D) -> Rect2:
	var top := cam.unproject_position(global_position)
	var low := cam.unproject_position(global_position + Vector3(0, -(HANGER_DROP + CORD_LEN) - vis.position.y * -1.0, 0))
	var half := absf(low.y - top.y) * 0.24
	return Rect2(top.x - half, top.y, half * 2.0, low.y - top.y)


# カーソルの位置と速さを渡す。乗った瞬間に、動いて来た向きへ揺れる。乗っているかを返す
func hover(cam: Camera3D, at: Vector2, velocity: Vector2) -> bool:
	var inside := screen_rect(cam).has_point(at)
	if inside and not _hot:
		var dir := signf(velocity.x) if absf(velocity.x) > 20.0 else 1.0
		push(dir * clampf(absf(velocity.x) / 500.0, 0.7, 2.4))
	_hot = inside
	return inside
