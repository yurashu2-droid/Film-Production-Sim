extends Node3D
## 会社のアップグレード画面（事務所の奥の大きなディスプレイ）。
## 画面を見て、買いたい枠に照準を合わせて左クリックすると買える（メニューは開かない）。
## 中身は SubViewport に描いた普通の UI を、板に貼って見せている。
const UI := preload("res://scripts/ui/ui_theme.gd")
const SCREEN := Vector2(4.4, 2.475)          # 画面の大きさ（m）
const VIEW := Vector2i(800, 450)       # 小さく描いて大きく貼る（遠くからでも字が読めるように）
const REACH := 7.5                           # これより遠いと買えない

var game: Node
var hover := ""                              # いま照準が合っている枠（無ければ ""）
var _view: SubViewport
var _cards := {}                             # 枠の名前 → {box, now, name, desc, price}
var _wallet: Label
var _rent: Label
var _quad: MeshInstance3D
var _sig := ""


func build(owner_game: Node) -> void:
	game = owner_game
	# 台と枠
	_box(Vector3(0, 0.45, 0.1), Vector3(2.4, 0.9, 0.5), Color("3b3f47"))
	_box(Vector3(0, 2.2, -0.02), Vector3(SCREEN.x + 0.16, SCREEN.y + 0.16, 0.1), Color("1b1c20"))
	_view = SubViewport.new()
	_view.size = VIEW
	_view.disable_3d = true
	_view.transparent_bg = false
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	_build_ui()
	_quad = MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = SCREEN
	_quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _view.get_texture()
	_quad.material_override = mat
	_quad.position = Vector3(0, 2.2, 0.04)
	add_child(_quad)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.4, 0.9, 0.5)
	cs.shape = shape
	cs.position = Vector3(0, 0.45, 0.1)
	body.add_child(cs)
	add_child(body)


func _build_ui() -> void:
	var root := PanelContainer.new()
	root.add_theme_stylebox_override("panel", UI.box(UI.BOARD, Color(0, 0, 0, 0), 0, 0, 24, 18))
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.make_theme(22)
	_view.add_child(root)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	root.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var head_l := VBoxContainer.new()
	head_l.add_theme_constant_override("separation", 0)
	head_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_l)
	head_l.add_child(UI.label("会社を大きくする", 40, UI.CLAP_WHITE, "display"))
	# 家賃の支払いが近いのに買いすぎると倒産するので、ここにも出しておく
	_rent = UI.label("", 24, UI.MUTED, "bold")
	head_l.add_child(_rent)
	_wallet = UI.label("", 34, UI.CLAP_WHITE, "display")
	_wallet.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_wallet)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(row)
	for id: String in game.production.TRACKS:
		var track: Dictionary = game.production.TRACKS[id]
		var box := PanelContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(box)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 8)
		box.add_child(v)
		v.add_child(UI.label(str(track["title"]), 24, UI.MUTED, "bold"))
		v.add_child(UI.hairline())
		var name_label := UI.label("", 34, UI.CLAP_WHITE, "display")
		name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		name_label.custom_minimum_size.x = 140
		name_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(name_label)
		# 細かい説明は画面には出さない（照準を合わせると、手前の案内に出る）
		var desc := UI.label("", 16, UI.MUTED, "body")
		desc.visible = false
		v.add_child(desc)
		var now := UI.label("", 18, UI.MUTED, "body")
		now.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		now.custom_minimum_size.x = 140
		v.add_child(now)
		var price := UI.label("", 28, UI.CLAP_WHITE, "bold")
		v.add_child(price)
		_cards[id] = {"box": box, "now": now, "name": name_label, "desc": desc, "price": price}


func _process(_delta: float) -> void:
	if game == null or game.production == null:
		return
	var flow: Node = game.production
	hover = _aimed(flow)
	var sig := str(flow.levels) + str(flow.wallet) + hover + str(flow.day) + str(flow.rent_no)
	if sig == _sig:
		return
	_sig = sig
	_wallet.text = "貯金 %d コイン" % int(flow.wallet)
	_rent.text = "次の家賃 %d コイン（あと%d本）" % [flow.rent_amount(), flow.rent_in()] if flow.hazards else ""
	for id: String in _cards:
		var card: Dictionary = _cards[id]
		var levels: Array = flow.TRACKS[id]["levels"]
		var have: int = int(flow.levels.get(id, 0))
		var maxed: bool = have >= levels.size() - 1
		var aimed: bool = id == hover and not maxed
		(card["box"] as PanelContainer).add_theme_stylebox_override("panel",
			UI.box(Color(1, 1, 1, 0.1 if aimed else 0.04), UI.CLAP_WHITE if aimed else UI.LINE, 4 if aimed else 2, 6, 14, 12))
		(card["now"] as Label).text = "いま：%s" % str(levels[have]["name"])
		if maxed:
			(card["name"] as Label).text = str(levels[have]["name"])
			(card["desc"] as Label).text = str(levels[have]["desc"])
			(card["price"] as Label).text = "最高"
			UI.recolor(card["price"], UI.GREEN_LIGHT)
		else:
			var next: Dictionary = levels[have + 1]
			var short: bool = int(flow.wallet) < int(next["cost"])
			(card["name"] as Label).text = str(next["name"])
			(card["desc"] as Label).text = str(next["desc"])
			(card["price"] as Label).text = "%d コイン" % int(next["cost"])
			UI.recolor(card["price"], UI.STAMP_RED.lightened(0.25) if short else UI.CLAP_WHITE)


# 画面のどの枠に照準が合っているか。遠すぎる・画面の外・買えない段階なら ""
func _aimed(flow: Node) -> String:
	var cam := get_viewport().get_camera_3d()
	var me: Node3D = game.local_player()
	if cam == null or me == null or flow.phase not in [0, 2] or game.ui_blocking():
		return ""
	if me.global_position.distance_to(global_position) > REACH:
		return ""
	var to_local := _quad.global_transform.affine_inverse()
	var from: Vector3 = to_local * cam.global_position
	var dir: Vector3 = to_local.basis * (-cam.global_basis.z)
	if absf(dir.z) < 0.001 or from.z <= 0.0:
		return ""
	var t := -from.z / dir.z
	if t <= 0.0:
		return ""
	var hit := from + dir * t
	var px := Vector2((hit.x / SCREEN.x + 0.5) * VIEW.x, (0.5 - hit.y / SCREEN.y) * VIEW.y)
	for id: String in _cards:
		if ((_cards[id]["box"] as Control).get_global_rect()).has_point(px):
			return id
	return ""


# 照準の合っている枠の、次の段階（買えるものが無ければ空）
func aimed_offer() -> Dictionary:
	if game == null or hover == "" or game.production == null:
		return {}
	var flow: Node = game.production
	var levels: Array = flow.TRACKS[hover]["levels"]
	var have: int = int(flow.levels.get(hover, 0))
	if have >= levels.size() - 1:
		return {}
	return levels[have + 1]


func _box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
