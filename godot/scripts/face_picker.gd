extends Node3D
# 表情えらび（F3）。窓や一覧は出さず、自分のキャラの「頭のモデル」を表情ごとに目の前へ並べる。
# 押している間だけ並び、マウスの左右・ホイール・数字キーで選んで、離すと決まる（左クリックでも決まる）。
# 並ぶ頭は制作班にだけ見える層に置くので、撮影カメラには映らない。自分の視点カメラの子として付ける。

const CastVisual := preload("res://scripts/cast_visual.gd")
const ORDER := ["happy", "angry", "sad", "surprised", "shock", "neutral"]
const CREW_LAYER := 1 << 11      # film_camera.gd と同じ番号（映画には映らない層）
const DIST := 0.8                # 視点から頭の列までの距離
const ROW_Y := 0.2               # 照準より少し上に並べる（照準とキャラを隠さない）
const GAP := 0.2                 # となりの頭との間
const HEAD_SIZE := 0.13          # 並べる頭の大きさ（いちばん長い辺）
const PICK_SCALE := 1.55         # 選んでいる頭は大きく見せる
const MOUSE_STEP := 70.0         # マウスをこれだけ横へ動かすと、となりの頭へ移る

static var _mesh_cache: Dictionary = {}

var player: Node
var opened := false
var faces: Array[String] = []    # いま並んでいる表情（左から）
var index := 0                   # 選んでいる頭
var last_face := "happy"         # 前に選んだ表情（次に開いたとき、そこから始める）
var _tag := ""
var _slots: Array[Node3D] = []
var _cursor := 0.0
var _time := 0.0


func _ready() -> void:
	visible = false
	position = Vector3(0, ROW_Y, -DIST)
	# 暗い現場でも顔が見えるよう、頭だけを照らす明かり（ほかの物は照らさない）
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.15, 0.6)
	light.omni_range = 2.5
	light.light_energy = 1.2
	light.light_cull_mask = CREW_LAYER
	light.shadow_enabled = false
	add_child(light)


func _notification(what: int) -> void:
	# 押したまま別の窓へ移ると「離した」が届かないので、選ばずに閉じる
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and opened:
		close(false)


# いま表情を選べるか（演技の合図が使える場面で、機材や乗り物を使っていないとき）
func usable() -> bool:
	if player == null or player.game == null or player.vis == null or player.vis.face_anim == null:
		return false
	var game: Node = player.game
	var performance: Variant = game.get("performance")
	if performance == null or not performance.allowed() or game.ui_blocking():
		return false
	return player.operating == 0 and not player.vehicle_riding()


func open() -> bool:
	if opened or not usable():
		return false
	_build()
	if faces.is_empty():
		return false
	opened = true
	visible = true
	index = maxi(0, faces.find(last_face))
	_cursor = float(index)
	_layout(1.0)
	return true


# apply が真なら、選んでいる表情を全員へ送る（H の一覧で表情を選んだときと同じ道）
func close(apply: bool) -> void:
	if not opened:
		return
	opened = false
	visible = false
	if apply and index >= 0 and index < faces.size() and usable():
		last_face = faces[index]
		player.game.h_perform.rpc_id(1, "face:" + last_face)


func select(i: int) -> void:
	if faces.is_empty():
		return
	index = clampi(i, 0, faces.size() - 1)
	_cursor = float(index)


# 開いている間のマウス。視点を回す代わりに、頭を選ぶ
func handle_input(event: InputEvent) -> bool:
	if not opened:
		return false
	if event is InputEventMouseMotion:
		_cursor = clampf(_cursor + (event as InputEventMouseMotion).relative.x / MOUSE_STEP, -0.49, float(faces.size()) - 0.51)
		index = clampi(roundi(_cursor), 0, faces.size() - 1)
		return true
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return true
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select(index + 1)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			select(index - 1)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			close(true)
		return true
	return false


# 開いている間の数字キー（1 が左はし）
func handle_key(event: InputEvent) -> bool:
	if not opened or not event is InputEventKey or not event.pressed or event.echo:
		return false
	var n: int = (event as InputEventKey).physical_keycode - KEY_1
	if n < 0 or n >= faces.size():
		return false
	select(n)
	return true


func _process(delta: float) -> void:
	if not opened:
		return
	if not usable() or player.vis.tag != _tag:
		close(false)
		return
	_time += delta
	_layout(clampf(delta * 16.0, 0.0, 1.0))


func _layout(weight: float) -> void:
	for i in _slots.size():
		var slot := _slots[i]
		var picked := i == index
		var x := (float(i) - float(_slots.size() - 1) * 0.5) * GAP
		# 選んだ頭は大きく、少し手前へ出て、ゆっくり首を振る
		var goal := Vector3(x, 0.0, 0.07 if picked else 0.0)
		slot.position = slot.position.lerp(goal, weight)
		var size: float = float(slot.get_meta("unit")) * (PICK_SCALE if picked else 1.0)
		slot.scale = slot.scale.lerp(Vector3.ONE * size, weight)
		slot.rotation.y = lerp_angle(slot.rotation.y, sin(_time * 3.2) * 0.32 if picked else 0.0, weight)


# 今のキャラの頭を、表情の数だけ作る（キャラを替えたら作り直す）
func _build() -> void:
	var vis: Node3D = player.vis
	if vis.tag == _tag and not _slots.is_empty():
		return
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
	faces.clear()
	_tag = vis.tag
	for face: String in ORDER:
		if vis.face_anim.has_animation(face):
			faces.append(face)
	for face: String in faces:
		var slot := Node3D.new()
		add_child(slot)
		var head: Node3D = CastVisual.new()
		slot.add_child(head)
		head.setup(_tag)
		head.grounding_enabled = false
		# 体は動かさず、顔だけ動かす
		head.anim.stop()
		head.skel.reset_bone_poses()
		head._model.position = Vector3.ZERO
		var box := AABB()
		var first := true
		for mesh: MeshInstance3D in head._model.find_children("*", "MeshInstance3D", true, false):
			var cut: Array = _head_mesh(_tag, mesh, head._model)
			if cut.is_empty():
				mesh.visible = false
				continue
			mesh.mesh = cut[0]
			mesh.layers = CREW_LAYER
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var to_head: Transform3D = _to_ancestor(mesh, head)
			var part: AABB = to_head * (cut[1] as AABB)
			box = part if first else box.merge(part)
			first = false
		head.set_face(face)
		head.position = -box.get_center()
		var longest := maxf(box.size.x, box.size.y)
		slot.set_meta("unit", HEAD_SIZE / longest if longest > 0.001 else 1.0)
		slot.scale = Vector3.ONE * float(slot.get_meta("unit"))
		_slots.append(slot)


static func _to_ancestor(node: Node3D, ancestor: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != ancestor:
		if at is Node3D:
			t = (at as Node3D).transform * t
		at = at.get_parent()
	return t


# 元のモデルから、頭の部分の三角形だけを抜き出した形を作る（骨の重みはそのまま。表情の動きも付いてくる）。
# 戻り値：[形, 頭の部分の大きさ]。頭に当たる所が無ければ空。
static func _head_mesh(tag: String, mesh: MeshInstance3D, model: Node3D) -> Array:
	var key := tag + "/" + mesh.name
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var skel: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var head_bone := skel.find_bone("HEAD")
	# 頭の骨と、その先の骨（顔・目・口など）
	var head_binds := {}
	if head_bone >= 0 and mesh.skin != null:
		for bind in mesh.skin.get_bind_count():
			var bind_name := mesh.skin.get_bind_name(bind)
			var bone: int = skel.find_bone(bind_name) if bind_name != "" else mesh.skin.get_bind_bone(bind)
			while bone >= 0:
				if bone == head_bone:
					head_binds[bind] = true
					break
				bone = skel.get_bone_parent(bone)
	# 頭の骨が無いキャラ（ロボット）は、顔の画面の高さから上・画面のまわりだけを頭とみなす
	var screen_box := AABB()
	if head_bone < 0:
		for other: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if str(other.name).ends_with("_screen"):
				screen_box = other.get_aabb()
	var out := ArrayMesh.new()
	var box := AABB()
	var first := true
	for surface in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var keep := PackedByteArray()
		keep.resize(vertices.size())
		if head_bone >= 0:
			if arrays[Mesh.ARRAY_BONES] == null or head_binds.is_empty():
				continue
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var influences := bones.size() / vertices.size()
			for i in vertices.size():
				var sum := 0.0
				for j in influences:
					if head_binds.has(bones[i * influences + j]):
						sum += weights[i * influences + j]
				keep[i] = 1 if sum >= 0.5 else 0
		else:
			var wide := screen_box.size.x * 0.5 + 0.34
			var mid := screen_box.get_center().x
			for i in vertices.size():
				keep[i] = 1 if vertices[i].y >= screen_box.position.y - 0.16 and absf(vertices[i].x - mid) <= wide else 0
		var source := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			source = arrays[Mesh.ARRAY_INDEX]
		else:
			source.resize(vertices.size())
			for i in vertices.size():
				source[i] = i
		var picked := PackedInt32Array()
		for i in range(0, source.size() - 2, 3):
			if keep[source[i]] == 1 and keep[source[i + 1]] == 1 and keep[source[i + 2]] == 1:
				picked.append(source[i])
				picked.append(source[i + 1])
				picked.append(source[i + 2])
				for corner in 3:
					var point := vertices[source[i + corner]]
					box = AABB(point, Vector3.ZERO) if first else box.expand(point)
					first = false
		if picked.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = picked
		var flags: int = mesh.mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, mesh.mesh.surface_get_material(surface))
	var result: Array = [] if out.get_surface_count() == 0 else [out, box]
	_mesh_cache[key] = result
	return result
