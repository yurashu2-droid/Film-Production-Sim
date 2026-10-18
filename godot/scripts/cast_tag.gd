extends Node3D
## 見立ての荷札：役を付けた物の、前の上の角からぶら下げた紙の札。表と裏に、役の名前とらしさ（★）を書く。
## 空中に浮いた文字の代わり（物に付いた札として見せる）。制作班にだけ見える（映画には映らない。film_camera.gd の CREW_LAYER）。
## 置き場所は production_main.gd の _sync_cast_tags が毎コマ決める（物の向きに合わせて、まっすぐ下へ垂れる）
const CREW_LAYER := 1 << 11
const CARD := Vector2(0.2, 0.11)        # 札の大きさ（m）
const STRING := 0.1                    # ひもの長さ（m）
const PAPER := Color(0.86, 0.76, 0.56)  # 荷札の紙（クラフト紙）
const INK := Color(0.16, 0.12, 0.1)

var text := "":
	set(value):
		text = value
		for l: Label3D in _labels:
			l.text = value
var _labels: Array[Label3D] = []


func build(font: Font) -> void:
	var paper := StandardMaterial3D.new()
	paper.albedo_color = PAPER
	paper.roughness = 0.95
	var card := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CARD.x, CARD.y, 0.004)
	card.mesh = box
	card.material_override = paper
	card.position = Vector3(0, -STRING - CARD.y * 0.5, 0)
	_crew(card)
	add_child(card)
	# ひも（白い糸）
	var cord := MeshInstance3D.new()
	var line := CylinderMesh.new()
	line.top_radius = 0.002
	line.bottom_radius = 0.002
	line.height = STRING
	cord.mesh = line
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.94, 0.9)
	cord.material_override = white
	cord.position = Vector3(0, -STRING * 0.5, 0)
	_crew(cord)
	add_child(cord)
	# 表と裏の字
	for face: float in [1.0, -1.0]:
		var l := Label3D.new()
		l.font = font
		l.font_size = 48
		l.pixel_size = 0.0006
		l.outline_size = 0
		l.modulate = INK
		l.position = card.position + Vector3(0, 0, 0.003 * face)
		l.rotation.y = 0.0 if face > 0.0 else PI
		l.layers = CREW_LAYER
		add_child(l)
		_labels.append(l)


func _crew(mesh: GeometryInstance3D) -> void:
	mesh.layers = CREW_LAYER
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
