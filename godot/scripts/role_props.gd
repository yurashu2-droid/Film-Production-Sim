extends RefCounted
## 役に入った人に付ける、役ごとの安い作り物（features/stand_ins.gd が使う）。紙・段ボール・ガムテープで作った物に見せる。
##   ・前は、役の色のたすきを掛けていた。何か分からない変な物がくっついたように見えた（2026-11-11 ユーザー
##     「たすきより、役ごとの特有の小物とか帽子とかがいい」）
##   ・台本の役の名前（production_script.gd の "cast"）で決める。名前の無い役（A・B など）は、役の色の紙の帽子
##       社長＝段ボールのシルクハットと赤いネクタイ ／ 社員＝首から下げた社員証 ／ 新郎＝蝶ネクタイ ／ 新婦＝紙のベール
##       友人＝しまの三角帽 ／ ゾンビ＝額の三角の布（幽霊の天冠）
##   ・帽子（hat）は頭のてっぺんに、胸の物（chest）は胸の前に置く。どちらも映画に映る衣装
## 作るだけ。置き場所と動きは stand_ins.gd

const PAPER := Color("f2efe6")
const KRAFT := Color("b98a57")
const INK := Color("1d1d20")
const RED := Color("c8312b")
const TAPE := Color("d9cfa8")


# 役の名前と色から、帽子と胸の物を作る。{"hat": Node3D か null, "chest": Node3D か null, "brow": Node3D か null}
static func make(role_name: String, color: Color) -> Dictionary:
	match role_name:
		"社長":
			return {"hat": _top_hat(), "chest": _necktie(), "brow": null}
		"社員":
			return {"hat": null, "chest": _badge(color), "brow": null}
		"新郎":
			return {"hat": null, "chest": _bow_tie(), "brow": null}
		"新婦":
			return {"hat": _veil(), "chest": null, "brow": null}
		"友人":
			return {"hat": _party_hat(color), "chest": null, "brow": null}
		"ゾンビ":
			return {"hat": null, "chest": null, "brow": _ghost_band()}
	return {"hat": _paper_hat(color), "chest": null, "brow": null}


static func _mat(c: Color, rough: float = 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


static func _part(parent: Node3D, mesh: Mesh, c: Color, at: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(top: float, bottom: float, h: float, seg := 18) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


# 段ボールに黒い紙を巻いたシルクハット。ふちは段ボールの切り口、帯は赤いガムテープ（少しゆがめて、手作りに見せる）
static func _top_hat() -> Node3D:
	var root := Node3D.new()
	root.name = "TopHat"
	_part(root, _cyl(0.105, 0.11, 0.2), INK, Vector3(0, 0.11, 0))
	_part(root, _cyl(0.17, 0.165, 0.016, 22), INK, Vector3(0, 0.008, 0))
	_part(root, _cyl(0.172, 0.172, 0.006, 22), KRAFT, Vector3(0, -0.003, 0))       # ふちの段ボールの切り口
	_part(root, _cyl(0.112, 0.113, 0.035), RED, Vector3(0, 0.04, 0))                 # 赤いガムテープの帯
	root.rotation = Vector3(0.0, 0.0, 0.07)
	return root


# 赤いネクタイ（結び目と、先のとがった剣）
static func _necktie() -> Node3D:
	var root := Node3D.new()
	root.name = "Necktie"
	_part(root, _box(Vector3(0.055, 0.045, 0.03)), RED.darkened(0.15), Vector3(0, 0.0, 0))
	_part(root, _box(Vector3(0.07, 0.22, 0.012)), RED, Vector3(0, -0.13, 0))
	_part(root, _box(Vector3(0.05, 0.05, 0.012)), RED, Vector3(0, -0.24, 0), Vector3(0, 0, PI * 0.25))   # 先のとがり
	for k in 3:
		_part(root, _box(Vector3(0.072, 0.012, 0.013)), Color("7a1c18"), Vector3(0, -0.07 - 0.06 * k, 0.001), Vector3(0, 0, 0.5))
	return root


# 首から下げた社員証（白いカードに役の色の帯。ひもはガムテープの色）
static func _badge(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Badge"
	for side: float in [-1.0, 1.0]:
		_part(root, _box(Vector3(0.012, 0.2, 0.006)), TAPE, Vector3(side * 0.05, 0.02, -0.01), Vector3(0, 0, side * 0.32))
	_part(root, _box(Vector3(0.09, 0.12, 0.008)), PAPER, Vector3(0, -0.13, 0))
	_part(root, _box(Vector3(0.09, 0.03, 0.009)), color, Vector3(0, -0.085, 0.001))
	_part(root, _box(Vector3(0.03, 0.035, 0.009)), Color("8a8d93"), Vector3(-0.022, -0.14, 0.001))    # 顔写真の所
	return root


# 黒い紙の蝶ネクタイ
static func _bow_tie() -> Node3D:
	var root := Node3D.new()
	root.name = "BowTie"
	for side: float in [-1.0, 1.0]:
		var wing := PrismMesh.new()
		wing.size = Vector3(0.07, 0.08, 0.02)
		_part(root, wing, INK, Vector3(side * 0.045, 0, 0), Vector3(0, 0, side * PI * 0.5))
	_part(root, _box(Vector3(0.03, 0.035, 0.026)), INK.lightened(0.1), Vector3.ZERO)
	return root


# 紙のベール（頭から後ろへ垂れる、薄い白い紙）と、紙の花
static func _veil() -> Node3D:
	var root := Node3D.new()
	root.name = "Veil"
	var cloth := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.52)
	cloth.mesh = quad
	var m := _mat(Color(1, 1, 1, 0.72), 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.material_override = m
	cloth.position = Vector3(0, -0.2, -0.2)
	cloth.rotation = Vector3(0.5, 0, 0)
	root.add_child(cloth)
	var band := _part(root, _cyl(0.12, 0.125, 0.025), PAPER, Vector3(0, 0.0, 0))
	band.scale = Vector3(1.0, 1.0, 0.9)
	# 前から見て分かるように、金紙のティアラ（とがった三角を 5 つ）と、紙の花
	for k in 5:
		var spike := PrismMesh.new()
		var tall := 0.075 if k == 2 else (0.055 if k in [1, 3] else 0.04)
		spike.size = Vector3(0.045, tall, 0.01)
		var x := -0.09 + 0.045 * k
		_part(root, spike, Color("d6ad3c"), Vector3(x, 0.012 + tall * 0.5, 0.1 - absf(x) * 0.35), Vector3(0, x * 2.2, 0))
	for k in 2:
		var flower := SphereMesh.new()
		flower.radius = 0.04
		flower.height = 0.06
		_part(root, flower, Color("f6c7d3"), Vector3(-0.11 + 0.22 * k, 0.0, 0.05))
	return root


# しまの三角帽（パーティー）
static func _party_hat(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "PartyHat"
	_part(root, _cyl(0.0, 0.1, 0.26), color, Vector3(0, 0.13, 0))
	for k in 3:
		var r := 0.1 * (1.0 - (0.05 + 0.28 * k) / 1.0) + 0.002
		var y := 0.013 + 0.073 * k
		_part(root, _cyl(r - 0.018, r, 0.03), PAPER, Vector3(0, y + 0.015, 0))
	var ball := SphereMesh.new()
	ball.radius = 0.03
	ball.height = 0.06
	_part(root, ball, PAPER, Vector3(0, 0.265, 0))
	root.rotation = Vector3(0, 0, -0.12)
	return root


# 名前の無い役：役の色の紙の帽子（新聞紙で折ったような、低い三角の帽子）
static func _paper_hat(color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "PaperHat"
	var fold := PrismMesh.new()
	fold.size = Vector3(0.3, 0.16, 0.12)
	_part(root, fold, color, Vector3(0, 0.07, 0))
	_part(root, _box(Vector3(0.31, 0.03, 0.125)), color.darkened(0.2), Vector3(0, 0.0, 0))      # 折り返し
	_part(root, _box(Vector3(0.05, 0.035, 0.127)), TAPE, Vector3(0.09, 0.0, 0))                  # ガムテープで留めた所
	return root


# 額の三角の布（幽霊の天冠）と、頭に回したひも
static func _ghost_band() -> Node3D:
	var root := Node3D.new()
	root.name = "GhostBand"
	var tri := PrismMesh.new()
	tri.size = Vector3(0.16, 0.13, 0.01)
	_part(root, tri, PAPER, Vector3(0, 0.02, 0))
	_part(root, _box(Vector3(0.3, 0.018, 0.008)), PAPER.darkened(0.08), Vector3(0, -0.045, -0.003))
	return root
