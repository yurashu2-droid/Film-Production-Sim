extends Node
## 1日目の青いガイド（情報商材の投影機が、事務所の前に映す影。docs/production/tutorial-cm.md）
##   紹介動画の準備中と撮影中だけ、置く所に青い影が出る。合わせて置くと、影が緑に変わる：
##   ・カメラ：段ボール（箱馬）を2つ積んで、その上にカメラ（三脚があれば、床にカメラ）
##   ・城に見立てる物（城の役を決めた物か、書割）・爆炎の書割
##   影の形は、事務所の前に出してある本物の物の写し（features/tutorial_day.gd が出す物）。
## 映画には映らない（制作班にだけ見える層）。ふつうに遊ぶときだけ出す（確認では force を立てる）。
## 置き場所の計算は、各自の画面（物の位置は全員にそろって届く）
const HOLO := preload("res://shaders/hologram.gdshader")
const CREW_LAYER := 1 << 11
const BLUE := Color(0.15, 0.55, 1.0)
const GREEN := Color(0.35, 1.0, 0.45)
# 置く所（事務所の前の舞台の真ん中 production_flow.gd の HOME_SET から）。tests/pr_test.gd の置き方と同じ
const CAM_AT := Vector3(0.0, 0.0, 5.0)
const CASTLE_AT := Vector3(0.0, 0.0, -2.2)
const FLAT_AT := Vector3(1.9, 0.0, -2.3)
const NEAR := 0.6                    # この距離（横）まで寄せたら、合っている
const STACK := 2                     # カメラを載せる箱の数

var game: Node
var force := false                   # 自動確認でも出す
var root: Node3D
var guides: Array = []               # [{"name", "node", "mats", "ok"}, ...]
var _built := false
var _stack_top := 0.0
var _tripod := false


func active() -> bool:
	var flow: Node = game.production
	if flow == null or not (bool(flow.daily) or force):
		return false
	return int(flow.phase) in [2, 4] and bool(flow.job().get("debut", false)) and flow.shoots_home()


func _process(_delta: float) -> void:
	var on := active()
	if on and (not _built or _tripod != bool(game.film.get("tripod"))):
		_build()
	if root != null:
		root.visible = on
	if on:
		_check()


# 影を作る（はじめて出すとき・三脚の有り無しが変わったとき）
func _build() -> void:
	if root != null:
		root.queue_free()
	guides = []
	_built = true
	var flow: Node = game.production
	var o: Vector3 = flow.HOME_SET
	root = Node3D.new()
	root.name = "HoloGuides"
	game.add_child(root)
	var film: RigidBody3D = game.film
	_tripod = film.get("tripod") == null or bool(film.tripod)
	_stack_top = 0.0
	if not _tripod:
		var box: Node = _one("applebox")
		if box != null:
			for k in STACK:
				_add("box%d" % k, box.visual, o + CAM_AT + Vector3(0, _stack_top, 0), 0.0, "" if k > 0 else "段ボールを積む")
				_stack_top += float(box.half.y) * 2.0
	_add("camera", film.visual, o + CAM_AT + Vector3(0, _stack_top, 0), 0.0, "カメラ" if _tripod else "カメラを箱の上に")
	# 役者の立ち位置（印）は、1日目の案内に入れない（2026-10-24 ユーザー：分かりづらく、意味がない）
	var flat: Node = _one("flat")
	if flat != null:
		_add("castle", flat.visual, o + CASTLE_AT, 0.0, "城（Y で城の役に）")
	var boom: Node = _one("boomflat")
	if boom != null:
		_add("blast", boom.visual, o + FLAT_AT, 0.0, "爆炎の書割")


func _one(kind: String) -> Node:
	for p: Node in game.props.values():
		if p.kind == kind and p.visual != null:
			return p
	return null


func _material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = HOLO
	mat.set_shader_parameter("tint", BLUE)
	mat.set_shader_parameter("base_alpha", 0.45)
	mat.set_shader_parameter("flicker", 0.15)
	return mat


func _holo(node: Node3D, mat: ShaderMaterial) -> void:
	for mesh: Node in [node] + node.find_children("*", "", true, false):
		if mesh is GeometryInstance3D:
			(mesh as GeometryInstance3D).material_override = mat
			(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh is VisualInstance3D:
			(mesh as VisualInstance3D).layers = CREW_LAYER


# 本物の物の見た目を写して、影にする
func _add(gname: String, visual: Node3D, at: Vector3, yaw: float, tag: String) -> void:
	var holder := Node3D.new()
	holder.name = gname
	holder.position = at
	holder.rotation.y = yaw
	root.add_child(holder)
	var copy: Node3D = visual.duplicate(0)
	for s: Node in copy.find_children("*", "", true, false):
		# 写しには、形だけあればよい（動きの再生機・覗き窓のカメラ・明かり・音・当たりは要らない）
		if not (s is Node3D) or s is Camera3D or s is Light3D or s is CollisionObject3D or s is AudioStreamPlayer3D or s is GPUParticles3D:
			if is_instance_valid(s) and not s.is_queued_for_deletion():
				s.queue_free()
	holder.add_child(copy)
	var mat := _material()
	_holo(copy, mat)
	guides.append({"name": gname, "node": holder, "mats": [mat], "ok": false})


func _top(node: Node3D) -> float:
	var top := 0.0
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (node.get_parent() as Node3D).global_transform.affine_inverse() * mi.global_transform * mi.get_aabb() if node.is_inside_tree() else mi.get_aabb()
		top = maxf(top, b.end.y)
	return top


# 合っているかを見て、色を変える
func _check() -> void:
	var flow: Node = game.production
	var o: Vector3 = flow.HOME_SET
	var cam_spot: Vector3 = o + CAM_AT
	var boxes := 0
	for p: Node3D in game.props.values():
		if p.kind == "applebox" and not p.absent and _flat_dist(p.global_position, cam_spot) < NEAR + 0.2:
			boxes += 1
	var film: Node3D = game.film
	for g: Dictionary in guides:
		var ok := false
		var name: String = g["name"]
		if name.begins_with("box"):
			ok = boxes > int(name.trim_prefix("box"))
		elif name == "camera":
			ok = _flat_dist(film.global_position, cam_spot) < NEAR and film.global_position.y > cam_spot.y + _stack_top * 0.6
		elif name == "castle":
			ok = _near_any((g["node"] as Node3D).global_position, func(p: Node) -> bool: return flow.role_of(p) == "castle" or p.kind == "flat", 1.1)
		elif name == "blast":
			ok = _near_any((g["node"] as Node3D).global_position, func(p: Node) -> bool: return p.kind == "boomflat", 1.1)
		if ok != bool(g["ok"]):
			g["ok"] = ok
			for m: ShaderMaterial in g["mats"]:
				m.set_shader_parameter("tint", GREEN if ok else BLUE)
			if ok:
				Sfx.play("ui_select", (g["node"] as Node3D).global_position, -10.0)


# まだ影に合わせていない物の数（HUD の案内に使う）
func left() -> int:
	var n := 0
	for g: Dictionary in guides:
		if not bool(g.get("ok", false)):
			n += 1
	return n


func done(gname: String) -> bool:
	for g: Dictionary in guides:
		if g["name"] == gname:
			return bool(g["ok"])
	return false


func _near_any(at: Vector3, want: Callable, reach: float) -> bool:
	for p: Node3D in game.props.values():
		if not p.absent and want.call(p) and _flat_dist(p.global_position, at) < reach:
			return true
	return false


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
