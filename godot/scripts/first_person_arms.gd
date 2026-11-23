extends RefCounted
# 一人称で見える「自分の手と腕」。
# キャラの体は1枚のメッシュなので、その中から左腕・右腕の三角形だけを抜き出した写しを2つ作り、
# 本体と同じ骨（Skeleton3D）で動かす。骨が同じなので、歩く・持つ・ロープをつかむ腕の動きは本体とぴったり同じ。
# 写しは自分の視点カメラにだけ映る層（LAYER）に置く。撮影カメラや他人の画面には、今までどおり本体だけが映る。
#
# 置き場所だけは、視点に合わせて腕ごとにずらす（骨は動かさないので、本体の見た目は変わらない）：
#   手ぶら　　　：肩を目の少し下に置き、腕を前へ起こす（手が画面の下に少し見える。よくある一人称の手）
#   物を持つ　　：持つ構えの手を、持っている物のそばへ寄せる（物は視線の先に浮かせて持つ作りなので、手の側を合わせる）
#   ロープの右手：本体と同じ所のまま（ロープの端が本体の右手に来るので）

const LAYER := 1 << 13          # 自分の視点にだけ映す層（撮影カメラ・カメラ操作の視点は、この層を映さない）
const NODE_NAME := "FirstPersonArms"
const SIDES := ["L", "R"]
# 腕の付け根の骨。この骨と、その先につながる骨（手・指・はさみ・手に持つ飾り）を「腕」とする
const ARM_ROOT := "UPPER_ARM."

# 手ぶらのときの見せ方：肩を目より DROP だけ下に置き、腕を前へ起こして、手首が視線の水平から DIP だけ下に来るようにする。
# 腕の長さ・ぶら下げ方・肩幅はキャラごとに違うので、起こす角度と左右の寄せは、立ち姿から測る
const DROP := 0.36              # 肩の高さ（目から下へ。m）
const DIP := 0.64               # 手首が来る角度（水平から下へ。約37度＝まっすぐ前を見て、画面の下の端あたり）
const AHEAD := 0.10             # 前へ出す長さ（m）
const SIDE := 0.24              # 手首の左右の位置（まん中から。m）
const SHOULDER := 0.46          # 肩の左右の位置（まん中から。m）。手首より外に置いて、腕を「ハ」の字に開く（体のまん中から生えて見えないように）
const SWING := 0.25             # 腕の振り（前後・左右）を、どれだけ見せるか（1＝そのまま。そのままだと、振った腕が顔の前を横切る）
const LOOK := 0.6               # 見上げ・見下ろしに、腕がどれだけついて来るか（1＝画面に貼りつく / 0＝ついて来ない）
const FOLLOW := 6.0             # 見せ方を切り替える速さ（毎秒）
# 小物の手持ち（G。prop.gd の hand_held）の間は、腕を出さない（"none"）。両手で顔の前の小物へ伸ばすと、太い腕が画面の手前をふさぐ

static var _cache: Dictionary = {}       # キャラ・部品・左右 → 腕だけのメッシュ（素材ごとに一度だけ作る）


# 毎コマ：写しの置き場所を決める
static func place(arms: Node3D, pl: Node3D, delta: float) -> void:
	var source := arms.get_node_or_null(arms.get_meta("source") as NodePath) as MeshInstance3D
	if source == null:
		return
	for arm: MeshInstance3D in arms.get_children():
		# 見せ方（手ぶら・物へ寄せる・本体のまま）が変わったときだけ、前の見せ方から滑らかに移る。
		# 同じ見せ方の間は、毎コマの計算をそのまま使う（遅らせると、腕の振りを打ち消す分が遅れて、腕が暴れる）
		var mode := _mode(str(arm.name), pl)
		if mode != str(arm.get_meta("mode", mode)):
			arm.set_meta("from", arm.get_meta("mode"))
			arm.set_meta("blend", 0.0)
		arm.set_meta("mode", mode)
		arm.visible = mode != "none"
		if mode == "none":
			continue
		var shift: Transform3D = _shift(arm, pl, mode)
		var blend: float = minf(1.0, float(arm.get_meta("blend", 1.0)) + delta * FOLLOW)
		arm.set_meta("blend", blend)
		if blend < 1.0:
			shift = _shift(arm, pl, str(arm.get_meta("from"))).interpolate_with(shift, smoothstep(0.0, 1.0, blend))
		arm.global_transform = shift * source.global_transform


# いまの見せ方："bare"＝手ぶら（腕を前へ起こす）/ "reach"＝持っている物へ寄せる / "true"＝本体の腕と同じ所
static func _mode(side: String, pl: Node3D) -> String:
	var vis: Node3D = pl.vis
	var game: Node = pl.game
	if pl.cam == null or pl.vehicle_riding() or pl.operating != 0:
		return "true"
	# ロープの端は本体の右手に来る（rope_grab.gd）ので、右手は本体と同じ所のまま
	if game.get("rope_grab") != null and game.rope_grab.holding(pl.peer_id):
		return "true" if side == "R" else "bare"
	var prop: Node3D = game.props.get(pl.held) if pl.held != 0 else null
	if prop != null and is_instance_valid(prop):
		if bool(prop.get("hand_held")):
			return "none"          # 手持ち（G）の間は、腕を出さない（持っている小物だけが、画面の右下に見える）
		return "bare" if side == "L" and prop.kind in vis.ONE_HAND_PROPS else "reach"
	var motion: String = vis.current
	if motion.begins_with("carry_") or motion.begins_with("onehand_"):
		return "true"
	return "bare"


# その見せ方での、ずらし方（世界の座標での変換。何もしない＝本体の腕と同じ所）
static func _shift(arm: MeshInstance3D, pl: Node3D, mode: String) -> Transform3D:
	if mode == "bare":
		return _bare(arm, pl)
	if mode == "reach":
		var prop: Node3D = pl.game.props.get(pl.held) if pl.held != 0 else null
		if prop != null and is_instance_valid(prop):
			return _point_at(pl, str(arm.name), _reach(pl, prop, str(arm.name), prop.kind in pl.vis.ONE_HAND_PROPS))
	return Transform3D.IDENTITY


# 視線の向きは、マウスの値（aim_yaw / aim_pitch）ではなく、実際のカメラの向きから取る。
# カメラが向きを変えるのは物理のコマごとで、マウスの値は描画のコマごとに変わる。マウスの値で腕を置くと、
# 視点を振ったときに、腕だけが先に動いてカメラとずれ、がくがくして見える
static func _view_yaw(pl: Node3D) -> float:
	var ahead: Vector3 = -pl.cam.global_basis.z
	return atan2(-ahead.x, -ahead.z)


static func _view_pitch(pl: Node3D) -> float:
	return asin(clampf((-pl.cam.global_basis.z).y, -1.0, 1.0))


# 一人称での肩の場所（世界の座標）。視点に対して決まった所に留める（手ぶらのときと同じ場所）
static func _shoulder_at(pl: Node3D, side: String) -> Vector3:
	var eye_y: float = pl.cam.global_position.y - pl.global_position.y
	var frame := Transform3D(Basis(Vector3.UP, _view_yaw(pl) + PI), pl.global_position)
	var eye := Vector3(0.0, eye_y, 0.0)
	var look := Transform3D(Basis.IDENTITY, eye) * Transform3D(Basis(Vector3.RIGHT, -_view_pitch(pl) * LOOK), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -eye)
	return frame * look * Vector3(-SHOULDER if side == "R" else SHOULDER, eye_y - DROP, AHEAD)


# 肩を留めたまま、腕を肩のまわりに回して、手首を target のほうへ向ける
static func _point_at(pl: Node3D, side: String, target: Vector3) -> Transform3D:
	var skel: Skeleton3D = pl.vis.skel
	var b_arm := skel.find_bone(ARM_ROOT + side)
	var b_hand := skel.find_bone("HAND." + side)
	if b_arm < 0 or b_hand < 0:
		return Transform3D.IDENTITY
	var root: Vector3 = skel.global_transform * skel.get_bone_global_pose(b_arm).origin
	var wrist: Vector3 = skel.global_transform * skel.get_bone_global_pose(b_hand).origin
	var held: Vector3 = _shoulder_at(pl, side)
	var from: Vector3 = wrist - root
	var to: Vector3 = target - held
	if from.length() < 0.01 or to.length() < 0.01:
		return Transform3D(Basis.IDENTITY, held - root)
	var turn := Basis(Quaternion(from.normalized(), to.normalized()))
	return Transform3D(Basis.IDENTITY, held) * Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -root)


# 物を持っているとき：手首を持っていきたい場所（物の手前の下。世界の座標）
static func _reach(pl: Node3D, prop: Node3D, side: String, one: bool) -> Vector3:
	var skel: Skeleton3D = pl.vis.skel
	var bone := skel.find_bone("HAND." + side)
	if bone < 0:
		return Vector3.ZERO
	var wrist: Vector3 = skel.global_transform * skel.get_bone_global_pose(bone).origin
	var eye: Vector3 = pl.cam.global_position
	var center: Vector3 = prop.center_global()
	var toward: Vector3 = eye - center
	if toward.length() < 0.01:
		return Vector3.ZERO
	toward = toward.normalized()
	var fwd: Vector3 = pl.flat_forward()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var turn: Basis = prop.global_basis.orthonormalized().inverse()
	var half: Vector3 = prop.half
	var depth: float = (turn * toward).abs().dot(half)      # 物の、視線の向きの厚み（半分）
	var tall: float = (turn * Vector3.UP).abs().dot(half)   # 物の高さ（半分）
	var wide: float = (turn * right).abs().dot(half)        # 物の幅（半分）
	var target: Vector3
	if one:
		# 片手：手首を、物の手前・少し下へ（指が物に届く）
		target = center + toward * (minf(depth, 0.15) + 0.1) - Vector3.UP * minf(tall * 0.5, 0.1)
	else:
		# 両手：物の手前の面の下のあたりを、左右から挟む
		target = center + toward * minf(depth, 0.35) - Vector3.UP * minf(tall, 0.35) * 0.7
		target += right * minf(wide + 0.03, 0.32) * (1.0 if side == "R" else -1.0)
	return target


# 手ぶらのとき：体の向きではなく視線の向きに合わせ、腕を前へ起こして、手が画面の下に少し見えるようにする。
# 歩く・走る・身ぶりの腕の振りは、そのまま出る
static func _bare(arm: MeshInstance3D, pl: Node3D) -> Transform3D:
	var vis: Node3D = pl.vis
	var skel: Skeleton3D = vis.skel
	var side := str(arm.name)
	var b_arm := skel.find_bone(ARM_ROOT + side)
	var b_hand := skel.find_bone("HAND." + side)
	if b_arm < 0 or b_hand < 0:
		return Transform3D.IDENTITY
	# 体の正面は +Z。右手は -X の側にある
	var body := Transform3D(Basis(Vector3.UP, vis.global_rotation.y), pl.global_position)
	var frame := Transform3D(Basis(Vector3.UP, _view_yaw(pl) + PI), pl.global_position)
	var to_body: Transform3D = body.affine_inverse() * skel.global_transform
	var shoulder: Vector3 = to_body * skel.get_bone_global_pose(b_arm).origin
	var eye_y: float = pl.cam.global_position.y - pl.global_position.y
	var hand: Vector3 = to_body * skel.get_bone_global_pose(b_hand).origin
	var reach := Vector2(hand.z - shoulder.z, shoulder.y - hand.y)        # 肩から手首へ（前・下）
	var hang: float = reach.angle()                                       # 腕の傾き（水平から下へ。真下で90度）
	# 立っているときの腕（傾き・長さ・手首の左右）を覚える。歩く・走る・身ぶりは、そこからの振れとして見せる
	if vis.current == "idle" or not arm.has_meta("rest"):
		var rest_now := Vector3(hand.x, hang, maxf(reach.length(), 0.1))
		arm.set_meta("rest", (arm.get_meta("rest", rest_now) as Vector3).lerp(rest_now, 0.1))
	var rest: Vector3 = arm.get_meta("rest")
	# 見せたい傾き＝画面の下に手が来る傾き＋腕の振り（控えめに）。そこまで、肩のまわりに起こす
	var tilt: float = hang - (_slope(rest.z) + (hang - rest.y) * SWING)
	# 肩のまわりに起こしてから、上から見て「ハ」の字に開く（右手は -X の側。肩を外へ、手首を内へ）
	# 腕の長さや太さはキャラごとに違うので、角度ではなく「肩は SHOULDER、手首は SIDE」になる向きを求める
	var lifted: Vector3 = Basis(Vector3.RIGHT, -tilt) * (hand - shoulder)
	var flat := maxf(Vector2(lifted.x, lifted.z).length(), 0.05)
	# 肩は動かさない。腕の左右の振りは、手の側だけに出す
	var open: float = (SHOULDER - SIDE if side == "R" else SIDE - SHOULDER) + (hand.x - rest.x) * SWING      # 肩から手首への、左右の向き（内へ）
	var splay: float = asin(clampf(open / flat, -0.85, 0.85)) - atan2(lifted.x, lifted.z)
	var turn := Basis(Vector3.UP, splay) * Basis(Vector3.RIGHT, -tilt)
	var raise := Transform3D(Basis.IDENTITY, Vector3(-SHOULDER if side == "R" else SHOULDER, eye_y - DROP, AHEAD)) * Transform3D(turn, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -shoulder)
	var eye := Vector3(0.0, eye_y, 0.0)
	var look := Transform3D(Basis.IDENTITY, eye) * Transform3D(Basis(Vector3.RIGHT, -_view_pitch(pl) * LOOK), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -eye)
	return frame * look * raise * body.affine_inverse()


# 長さ length の腕を、肩（目から DROP 下・AHEAD 前）から伸ばしたとき、手首が DIP の角度に見える腕の傾き（水平から下へ）
static func _slope(length: float) -> float:
	var low := -0.3
	var high := PI * 0.5
	for i in 16:
		var mid := (low + high) * 0.5
		if DROP + length * sin(mid) > tan(DIP) * (AHEAD + length * cos(mid)):
			high = mid
		else:
			low = mid
	return (low + high) * 0.5


# 腕だけの写し（左・右）を作って、骨の下に置く。作れなかったら（腕の骨が無いなど）null
static func build(vis: Node3D) -> Node3D:
	var skel: Skeleton3D = vis.skel
	var source: MeshInstance3D = null
	var most := 0
	# 体のメッシュ（腕の三角形がいちばん多い物）を探す。ロボットは画面・ガラスが別の部品になっている
	for mesh: MeshInstance3D in skel.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null or mesh.mesh == null or mesh.get_parent().name == NODE_NAME:
			continue
		var count := 0
		for side: String in SIDES:
			var part: ArrayMesh = _arm_mesh(vis.tag, mesh, skel, side)
			if part != null:
				count += int(part.get_meta("triangles", 0))
		if count > most:
			most = count
			source = mesh
	if source == null:
		return null
	var arms := Node3D.new()
	arms.name = NODE_NAME
	arms.visible = false
	source.get_parent().add_child(arms)
	arms.set_meta("source", NodePath("../" + str(source.name)))
	var to_skel := NodePath("../" + str(source.skeleton))
	for side: String in SIDES:
		var cut: ArrayMesh = _arm_mesh(vis.tag, source, skel, side)
		if cut == null:
			continue
		var arm := MeshInstance3D.new()
		arm.name = side
		arm.mesh = cut
		arm.skin = source.skin
		arm.layers = LAYER
		# 影は本体が落とす（写しまで落とすと二重になる）
		arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arms.add_child(arm)
		arm.transform = source.transform
		arm.skeleton = to_skel
	match_look(arms)
	return arms


# 本体の材質の差し替え（色を変える演出など）を、写しにも合わせる
static func match_look(arms: Node3D) -> void:
	var source := arms.get_node_or_null(arms.get_meta("source") as NodePath) as MeshInstance3D
	if source == null:
		return
	for arm: MeshInstance3D in arms.get_children():
		arm.material_override = source.material_override
		arm.material_overlay = source.material_overlay
		for surface in mini(arm.get_surface_override_material_count(), source.get_surface_override_material_count()):
			arm.set_surface_override_material(surface, source.get_surface_override_material(surface))


# その骨が、その側の腕（付け根の骨か、その先）か
static func _is_arm(skel: Skeleton3D, bone: int, side: String) -> bool:
	while bone >= 0:
		if skel.get_bone_name(bone) == ARM_ROOT + side:
			return true
		bone = skel.get_bone_parent(bone)
	return false


# メッシュから、その側の腕の骨にいちばん強く付いている頂点だけでできた三角形を抜き出す。
# 頂点の並びは元のまま使い、三角形の番号の並びだけを作り直す（形・色・貼ってある絵は元と同じ）。
static func _arm_mesh(tag: String, mesh: MeshInstance3D, skel: Skeleton3D, side: String) -> ArrayMesh:
	var key := "%s/%s/%s" % [tag, mesh.name, side]
	if _cache.has(key):
		return _cache[key]
	var out := ArrayMesh.new()
	var total := 0
	var arm_bind := {}
	for bind in mesh.skin.get_bind_count():
		var bind_name := str(mesh.skin.get_bind_name(bind))
		var bone: int = skel.find_bone(bind_name) if bind_name != "" else mesh.skin.get_bind_bone(bind)
		arm_bind[bind] = _is_arm(skel, bone, side)
	for surface in mesh.mesh.get_surface_count():
		if mesh.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.mesh.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var per: int = bones.size() / maxi(1, vertices.size())
		var on_arm := PackedByteArray()
		on_arm.resize(vertices.size())
		for i in vertices.size():
			var arm_weight := 0.0
			var all_weight := 0.0
			for j in per:
				var w: float = weights[i * per + j]
				all_weight += w
				if arm_bind.get(bones[i * per + j], false):
					arm_weight += w
			on_arm[i] = 1 if arm_weight > all_weight * 0.5 else 0
		var index := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			index = arrays[Mesh.ARRAY_INDEX]
		else:
			index.resize(vertices.size())
			for i in vertices.size():
				index[i] = i
		var kept := PackedInt32Array()
		for t in range(0, index.size() - 2, 3):
			if on_arm[index[t]] == 1 and on_arm[index[t + 1]] == 1 and on_arm[index[t + 2]] == 1:
				kept.append(index[t])
				kept.append(index[t + 1])
				kept.append(index[t + 2])
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		out.surface_set_material(out.get_surface_count() - 1, mesh.mesh.surface_get_material(surface))
		total += kept.size() / 3
	if total == 0:
		out = null
	else:
		out.set_meta("triangles", total)
	_cache[key] = out
	return out
