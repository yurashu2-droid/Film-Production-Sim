extends Node3D
## 講師バズ山の見た目：サングラスのモアイ（assets/cast/castBZ_game.glb）と、縄を引く小石たち（castBZP_game.glb）。
##   ・足が無い。頭に巻いた縄を、左右の小石が交互に引いて、体を左右に揺らしながら歩かせる（モアイを縄で歩かせた、という説が元）
##   ・呼び方は cast_visual.gd に合わせてある（setup・play・set_face）。講師を出す側は、どちらの見た目でも同じ書き方で使える
##   ・動きは全部ここで付ける（モデルに入っているのは、腕を前に出した構え 1 つだけ）
##       moving（0〜1）を外から入れると、歩く揺れになる。play("ORDER") で、売り込みの身ぶりを 1 回
## 作り方：リポジトリ直下の build_castBZ_claude.py・build_castBZP_claude.py（docs/art/image_prompts.md）

const MODEL := "res://assets/cast/castBZ_game.glb"
const PEBBLE := "res://assets/cast/castBZP_game.glb"
const HOLO_FIGURE := preload("res://shaders/hologram_figure.gdshader")
const SCALE := 0.66                  # モデルの大きさ（cast_visual.gd は 0.62。少しだけ大きく見せる）
const HALF_BASE := 0.79              # 底の半分の幅（モデルの単位）。揺れる時、こっちの角を軸にする
const ROPE_OUT := 0.42               # 縄が外へ開く角度（rad）。小石が持つ所まで
const ROPE_END := Vector3(1.52, 0.10, 0.30)   # 縄の先（モデルの中の場所。左。右は x が逆）
const ARMS := ["UPPER_ARM", "FOREARM", "HAND", "FINGERS", "THUMB"]

var tag := "BZ"
var height := 1.5
var moving := 0.0                    # 0＝立っている 〜 1＝歩いている（外から入れる）
var skel: Skeleton3D

var _model: Node3D
var _pebbles: Array[Node3D] = []     # 左 2 つ、右 2 つ
var _arm := {}                       # 骨の番号 → 構えの向き
var _rope := {}                      # "L" / "R" → 骨の番号 3 つ
var _rest := {}                      # 骨の番号 → 止まっている時の、骨組みの中での向き
var _t := 0.0
var _walk := 0.0                     # moving を、なめらかにした値
var _order := 0.0                    # 売り込みの身ぶりの残り（1 → 0）


func setup(_cast_tag: String, _model_path := "") -> void:
	_model = (load(MODEL) as PackedScene).instantiate() as Node3D
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	skel = _model.find_children("*", "Skeleton3D", true, false)[0]
	height = 3.6 * SCALE
	# モデルに入っている構え（腕を前に出す）を 1 回だけ読んで、あとは自分で骨を動かす
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var ap: AnimationPlayer = players[0]
		if ap.has_animation("BZ_ACTION"):
			ap.play("BZ_ACTION")
			ap.seek(ap.get_animation("BZ_ACTION").length, true)
			for i in skel.get_bone_count():
				var bone := skel.get_bone_name(i)
				for part: String in ARMS:
					if bone.begins_with(part):
						_arm[i] = skel.get_bone_pose_rotation(i)
		ap.stop()
		ap.active = false
	skel.reset_bone_poses()
	for i: int in _arm:
		skel.set_bone_pose_rotation(i, _arm[i])
	for side: String in ["L", "R"]:
		var chain: Array[int] = []
		for n in 3:
			var idx := skel.find_bone("ROPE%d.%s" % [n + 1, side])
			if idx >= 0:
				chain.append(idx)
				_rest[idx] = skel.get_bone_global_rest(idx).basis
		_rope[side] = chain
	# 小石：縄の先に、左右 2 つずつ
	for i in 4:
		var p := (load(PEBBLE) as PackedScene).instantiate() as Node3D
		p.scale = Vector3.ONE * SCALE
		add_child(p)
		for ap: AnimationPlayer in p.find_children("*", "AnimationPlayer", true, false):
			ap.active = false
		_pebbles.append(p)
	_pose(0.0)


# cast_visual.gd と同じ呼び方。体の動きは "ORDER"（売り込みの身ぶり）だけを受ける
func play(a: String, _blend: float = 0.18, _restart: bool = false) -> void:
	if a == "ORDER":
		_order = 1.0


func has(a: String) -> bool:
	return a == "ORDER" or a == "idle"


func length(_a: String) -> float:
	return 0.9


# 青いホログラムにする時に、呼ぶ側が部品ごとに呼ぶ：絵の明暗が出る、人物用のシェーダーに替える
func holo_dress(mesh: GeometryInstance3D, mat: ShaderMaterial) -> void:
	var mi := mesh as MeshInstance3D
	if mi == null or mi.mesh == null or mi.mesh.get_surface_count() == 0:
		return
	var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
	if src == null or src.albedo_texture == null:
		return
	mat.shader = HOLO_FIGURE
	mat.set_shader_parameter("albedo_tex", src.albedo_texture)


func set_face(_f: String) -> void:
	pass                             # 目はサングラスの奥。顔は変えない


func head_pos() -> Vector3:
	return global_transform * Vector3(0, height * 0.72, 0)


func _process(delta: float) -> void:
	_t += delta
	_walk = lerpf(_walk, clampf(moving, 0.0, 1.0), 1.0 - exp(-6.0 * delta))
	_order = maxf(0.0, _order - delta / 0.9)
	_pose(delta)


func _pose(_delta: float) -> void:
	if _model == null:
		return
	# 体の揺れ：歩く時は大きく、立っている時は、ほんの少し。傾いた側の、底の角を軸にする
	var tilt := sin(_t * 5.2) * 0.17 * _walk + sin(_t * 1.3) * 0.018 * (1.0 - _walk)
	var px := -HALF_BASE * SCALE * signf(tilt)
	# 売り込みの身ぶり：ぐっと前へのめって、戻る
	var push := sin(clampf(1.0 - _order, 0.0, 1.0) * PI) if _order > 0.0 else 0.0
	_model.rotation = Vector3(-0.16 * push, 0.0, tilt)
	_model.position = Vector3(px * (1.0 - cos(tilt)), -px * sin(tilt), 0.0)
	# 腕：構えから、身ぶりの時だけ持ち上げる。歩く時は、つり合いを取って少し振る
	for i: int in _arm:
		var q: Quaternion = _arm[i]
		if skel.get_bone_name(i).begins_with("UPPER_ARM"):
			var side := 1.0 if skel.get_bone_name(i).ends_with(".L") else -1.0
			q = Quaternion(Vector3.RIGHT, -0.55 * push) * Quaternion(Vector3.FORWARD, side * tilt * 1.4) * q
		skel.set_bone_pose_rotation(i, q)
	# 縄：外へ開いて、小石の手元へ。体が傾いても、縄の下の端は床の近くに残す。引かれている側は張り、反対側はたるむ
	for side: String in ["L", "R"]:
		var chain: Array = _rope[side]
		if chain.size() < 3:
			continue
		var s := 1.0 if side == "L" else -1.0
		var pull := clampf(-s * tilt / 0.17, -1.0, 1.0) * _walk          # 体が向こうへ傾く時、こっちが引いている
		var open := s * (ROPE_OUT + 0.10 * pull) - tilt
		var angles := [open, open, -tilt]
		var before := 0.0
		for n in 3:
			var idx: int = chain[n]
			var parent := skel.get_bone_parent(idx)
			var parent_rest: Basis = skel.get_bone_global_rest(parent).basis if parent >= 0 else Basis.IDENTITY
			var b: Basis = parent_rest.inverse() * Basis(Vector3.BACK, float(angles[n]) - before) * (_rest[idx] as Basis)
			skel.set_bone_pose_rotation(idx, b.get_rotation_quaternion())
			before = float(angles[n])
		# 小石：縄の先の真下に立って、こっち（モアイ）を向く。引く時は後ろへ反り、歩く時は跳ねる
		var end_rest := Vector3(ROPE_END.x * s, ROPE_END.y, ROPE_END.z)
		var last: int = chain[2]
		var end_now: Vector3 = _model.transform * (skel.get_bone_global_pose(last) * (skel.get_bone_global_rest(last).affine_inverse() * end_rest))
		for k in 2:
			var p := _pebbles[(0 if side == "L" else 2) + k]
			var out := 0.10 + 0.50 * float(k)
			var hop := absf(sin(_t * 5.2 + float(k) * 0.9 + (0.0 if side == "L" else PI))) * 0.05 * _walk
			p.position = Vector3(end_now.x + s * out, hop, end_now.z + (0.0 if k == 0 else -0.28) - 0.12)
			p.rotation = Vector3(0.0, -s * PI * 0.5 + (0.0 if k == 0 else s * 0.35), 0.0)
			p.rotate_object_local(Vector3.RIGHT, -(0.10 + 0.22 * maxf(pull, 0.0)))
