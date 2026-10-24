extends RefCounted
## 廃材置き場を「となりの区の粗大ごみ置き場（収集所）」に見せる飾り。制作班は、ここから勝手に拾ってきて撮影に使っている。
##   ・本当の入口（区の門）は、南の区道の側（会社の反対側）。門は閉まったまま、扉の合わせ目に鎖と南京錠。
##     門の脇に区の看板と、柱に取り付けた防犯カメラ（production_yard.gd が門の扉をここへ移す）
##   ・会社の側（東。ローカル +Z）には入口が無い。金網をペンチで切った穴があり、制作班はそこから入る。
##     依頼を受けている間は、切った網をめくって開けておき、それ以外は元に戻して針金で留めておく（set_hole）
##   ・文字の看板は置かない。札は板と色の帯と絵記号（Look.picto）だけ
##   ・外のフェンス際：ゴミ集積所（袋とカラス除けネット）と、処理券を貼った粗大ごみ
##   ・拾ってきた廃材には、黄色い「粗大ごみ処理券」が貼ったままになっている（sticker_on）
## 位置はヤードのローカル座標（x：横 −15 〜 15、z：奥 −12 〜 会社の側 +12。+z が会社の側、−x が南の区道の側）
const Look := preload("res://scripts/production_look.gd")
const Office := preload("res://scripts/production_office.gd")

const TICKET := Color("f2d23c")          # 処理券の黄色
const TICKET_RED := Color("c8352b")
const GREEN := Color("2f7d4f")           # 区の看板の緑

const FRONT_Z := 12.0                    # 会社の側の金網の面
const HOLE := Vector2(0.15, 2.85)        # ペンチで切った穴の横の範囲（x）。右端（x=2.85）を軸に、網をめくる
const HOLE_TOP := 1.95                   # 穴の上の端（その上は網が残る）
const FENCE_TOP := 2.06
const FLAP_OPEN := 2.45                  # めくった網の開き（ラジアン。外＝会社の側へ）
const FLAP_TIP := 0.85                   # めくった網の先の、反り返った部分の幅

static var _net_mat: ShaderMaterial
static var _crow_mat: ShaderMaterial


# 会社の側の門の場所（モデルの門）を、南の区道の側へ移す変換。
# 門の面 z=12（x −3..3、外が +z）→ 南の面 x=−15（z −9..−3、外が −x）
static func south_gate() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(-3.0, 0.0, -6.0))


# ヤードの部品のうち、外す物（店の看板・通路の白線・コンテナの置き場の印・前の看板の柱）
static func hidden_part(nm: String) -> bool:
	for key: String in ["zone title", "zone subtitle", "zone bolt", "materials title", "materials subtitle", "materials bolt",
			"second take salvage title", "second take salvage subtitle", "second take salvage bolt", "fabric rack label",
			"crosswalk edge", "faded aisle boundary", "aisle 5_5m clear", "aisle 3m clear", "pad stencil",
			"container bay side marking", "container optional pad", "twistlock corner landing marker", "entry public apron",
			"main sign timber upright"]:
		if nm.contains(key):
			return true
	return false


# 南の金網のうち、門にする2区画（z −9..−3）の網・桟・留め具・真ん中の柱
static func south_opening(nm: String, box: AABB) -> bool:
	if not nm.begins_with("side fence bay"):
		return false
	var c := box.get_center()
	return c.x < 0.0 and c.z > -8.95 and c.z < -3.05


static func build(root: Node3D, xf: Transform3D) -> void:
	var b := Look.Batch.new()
	b.xf = xf
	_bay_signs(b)
	_collection_point(b, root, xf, Vector3(-11.4, 0, 12.95), 9)
	_collection_point(b, root, xf, Vector3(10.6, 0, 12.95), 6)
	_junk(b)
	_front_notice(b, root, xf)
	b.build(root, "DumpDressing")
	_south_entrance(root, xf)
	_front_fence(root, xf)


# ---- 本当の入口（南の区道の側）：門の鎖と南京錠、区の看板、防犯カメラ ----

static func _south_entrance(root: Node3D, xf: Transform3D) -> void:
	# 門の扉の合わせ目に鎖を巻き、南京錠をかける（門の場所の座標で作って、南へ移す）。
	# モデルの扉は少し斜めで、閉じると先の縦枠が x≈0、z≈12.25（外寄り）で合わさる。鎖はその2本の縦枠を抱く
	var lock := Look.Batch.new()
	lock.xf = xf * south_gate()
	var steel := Look.plain(Color("a9afb2"), 0.35, 0.8)
	for y: float in [1.05, 1.2]:
		var loop := [Vector3(-0.17, y, 12.12), Vector3(0.17, y + 0.03, 12.12), Vector3(0.17, y - 0.03, 12.38), Vector3(-0.17, y, 12.38)]
		for k in 4:
			_chain(lock, steel, loop[k], loop[(k + 1) % 4], 1.6)
	_chain(lock, steel, Vector3(0.0, 1.05, 12.38), Vector3(0.03, 0.78, 12.42), 1.6)
	_padlock(lock, Vector3(0.03, 0.68, 12.43), 0.0, 1.6)
	lock.build(root, "DumpLockShut")
	var b := Look.Batch.new()
	b.xf = xf
	var wood := Look.mat("wood", Color("7a5a3c"))
	var pole := Look.plain(Color("9aa3a6"), 0.45, 0.6)
	var x := -15.4                            # 金網の外（区道の側）
	# 区の看板：門の西どなり。木の柱と、カメラの鉄の柱に渡して留める
	var sc := Vector3(x - 0.07, 2.1, -10.75)
	b.boxp(wood, Vector3(x, 1.4, -11.75), Vector3(0.12, 2.8, 0.12), Look.Batch.GROUND)
	b.solidp(Vector3(x, 1.4, -11.75), Vector3(0.12, 2.8, 0.12))
	b.boxp(Look.plain(Color("f4f2ea"), 0.6), sc, Vector3(0.03, 1.15, 2.3), Look.Batch.ALL)
	b.solidp(sc, Vector3(0.05, 1.15, 2.3))
	b.boxp(Look.plain(GREEN, 0.6), sc + Vector3(-0.018, 0.44, 0), Vector3(0.008, 0.27, 2.3), Look.Batch.ALL)
	b.boxp(Look.plain(TICKET_RED, 0.6), sc + Vector3(-0.018, -0.46, 0), Vector3(0.008, 0.23, 2.3), Look.Batch.ALL)
	for z: float in [-1.05, 1.05]:
		for y: float in [0.44, -0.44]:
			b.boxp(Look.plain(Color("9aa0a2"), 0.4, 0.6), sc + Vector3(-0.02, y, z), Vector3(0.02, 0.05, 0.05), Look.Batch.ALL)
	Look.picto(root, xf * Transform3D(Basis(Vector3.UP, -PI * 0.5), sc + Vector3(-0.0165, -0.02, 0.0)), "no_entry", Vector2(0.62, 0.62))
	# 防犯カメラの鉄の柱（門の西の柱の外）。腕木の先に、門と区道の入口をにらむカメラ
	var pz := -9.45
	b.boxp(pole, Vector3(x, 1.65, pz), Vector3(0.1, 3.3, 0.1), Look.Batch.GROUND)
	b.solidp(Vector3(x, 1.65, pz), Vector3(0.1, 3.3, 0.1))
	b.boxp(Look.mat("concrete", Color("a8a59a")), Vector3(x, 0.06, pz), Vector3(0.3, 0.12, 0.3), Look.Batch.GROUND)
	b.boxp(pole, Vector3(x, 3.31, pz), Vector3(0.12, 0.02, 0.12), Look.Batch.ALL)
	# 看板を柱へ留める金具（帯で柱を抱く）
	for y: float in [2.5, 1.7]:
		b.boxp(pole, Vector3(x, y, pz), Vector3(0.13, 0.04, 0.13), Look.Batch.ALL)
		b.boxp(pole, Vector3(x - 0.06, y, (pz + sc.z + 1.15) * 0.5), Vector3(0.03, 0.05, absf(pz - (sc.z + 1.15)) + 0.1), Look.Batch.ALL)
	_camera(b, Vector3(x, 3.05, pz), xf)
	# 柱の札：黄色地に防犯カメラの絵（帯金で柱に巻いて留める）
	var tag := Vector3(x - 0.057, 1.15, pz)
	b.boxp(Look.plain(TICKET, 0.6), tag, Vector3(0.012, 0.42, 0.34), Look.Batch.ALL)
	for y: float in [0.16, -0.16]:
		b.boxp(pole, Vector3(x, tag.y + y, pz), Vector3(0.13, 0.025, 0.13), Look.Batch.ALL)
	Look.picto(root, xf * Transform3D(Basis(Vector3.UP, -PI * 0.5), tag + Vector3(-0.0068, 0.0, 0.0)), "camera", Vector2(0.3, 0.3))
	b.build(root, "DumpEntrance")


# 防犯カメラ：柱の頭から腕木を出し、先の取付け板にカメラを吊る。カメラは門（+z）と区道（−x）を見下ろす
static func _camera(b: Look.Batch, top: Vector3, xf: Transform3D) -> void:
	var white := Look.plain(Color("e8e8e2"), 0.5, 0.2)
	var dark := Look.plain(Color("26282a"), 0.3)
	var metal := Look.plain(Color("9aa3a6"), 0.45, 0.6)
	var arm_end := top + Vector3(-0.12, 0.0, 0.42)
	# 腕木（柱の側面に取付け板。斜めの控えつき）
	b.boxp(metal, top + Vector3(0, 0, 0.06), Vector3(0.14, 0.18, 0.02), Look.Batch.ALL)
	b.bar(metal, top + Vector3(0, 0.02, 0.06), arm_end, 0.045)
	b.bar(metal, top + Vector3(0, -0.2, 0.06), arm_end + Vector3(0, -0.02, -0.12), 0.025)
	# 吊り金具と首振りの台
	b.boxp(metal, arm_end + Vector3(0, -0.05, 0), Vector3(0.08, 0.08, 0.08), Look.Batch.ALL)
	var aim := (Vector3(-17.5, 0.0, -6.0) - (arm_end + Vector3(0, -0.2, 0))).normalized()
	var basis := Basis.looking_at(aim, Vector3.UP)
	var body_at := arm_end + Vector3(0, -0.2, 0) + basis * Vector3(0, 0, -0.08)
	b.bar(metal, arm_end + Vector3(0, -0.08, 0), body_at + basis * Vector3(0, 0.08, 0.06), 0.035)
	b.box(white, Transform3D(basis, body_at), Vector3(0.15, 0.14, 0.34), Look.Batch.ALL)
	b.box(white, Transform3D(basis, body_at + basis * Vector3(0, 0.085, -0.03)), Vector3(0.19, 0.016, 0.42), Look.Batch.ALL)
	b.box(dark, Transform3D(basis, body_at + basis * Vector3(0, -0.005, -0.172)), Vector3(0.11, 0.1, 0.012), Look.Batch.ALL)
	b.box(Look.plain(Color("5a7d9a"), 0.15, 0.3), Transform3D(basis, body_at + basis * Vector3(0, -0.005, -0.18)), Vector3(0.06, 0.06, 0.006), Look.Batch.ALL)
	# 配線：カメラの後ろから腕木に沿って、柱の中へ
	var cable := Look.plain(Color("1e2022"), 0.6)
	var back := body_at + basis * Vector3(0, -0.02, 0.17)
	b.bar(cable, back, back + Vector3(0, 0.0, -0.06), 0.012)
	b.bar(cable, back + Vector3(0, 0.0, -0.06), top + Vector3(-0.055, -0.08, 0.06), 0.012)
	b.bar(cable, top + Vector3(-0.055, -0.08, 0.06), top + Vector3(-0.055, -0.5, 0.0), 0.012)


# ---- 会社の側：ペンチで切った金網の穴（入口は無い） ----

# 門のあった所（x −3..3）を、モデルと同じ溶接金網でふさぐ。右半分は、ペンチで切った穴
static func _front_fence(root: Node3D, xf: Transform3D) -> void:
	var b := Look.Batch.new()
	b.xf = xf
	var steel := Look.plain(Color("9aa3a6"), 0.45, 0.6)
	var net := Look.Tint.new(grid_mat(), Color("aab3b5"))
	var cut := Look.plain(Color("b9c0c2"), 0.35, 0.8)
	var z := FRONT_Z
	var h := FENCE_TOP
	for x: float in [-2.95, 0.0, 2.95]:
		b.boxp(steel, Vector3(x, h * 0.5, z), Vector3(0.07, h, 0.07), Look.Batch.GROUND)
		b.solidp(Vector3(x, h * 0.5, z), Vector3(0.07, h, 0.07))
		b.boxp(Look.mat("concrete", Color("a8a59a")), Vector3(x, 0.05, z), Vector3(0.24, 0.1, 0.24), Look.Batch.GROUND)
	b.boxp(steel, Vector3(0.0, h, z), Vector3(5.97, 0.05, 0.05), Look.Batch.ALL)
	b.boxp(steel, Vector3(-1.475, 0.1, z), Vector3(2.88, 0.04, 0.04), Look.Batch.ALL)
	# 左半分：切られていない網
	b.boxp(net, Vector3(-1.475, (0.1 + h) * 0.5, z), Vector3(2.88, h - 0.1, 0.012), Look.Batch.ALL)
	b.solidp(Vector3(-1.475, h * 0.5, z), Vector3(2.9, h, 0.1))
	# 右半分：穴のまわりに残った網（上の帯と、柱ぎわの細い帯）
	b.boxp(net, Vector3(1.475, (HOLE_TOP + h) * 0.5, z), Vector3(2.88, h - HOLE_TOP, 0.012), Look.Batch.ALL)
	b.solidp(Vector3(1.475, (HOLE_TOP + h) * 0.5, z), Vector3(2.9, h - HOLE_TOP + 0.05, 0.1))
	b.boxp(net, Vector3((0.035 + HOLE.x) * 0.5, (0.1 + HOLE_TOP) * 0.5, z), Vector3(HOLE.x - 0.035, HOLE_TOP - 0.1, 0.012), Look.Batch.ALL)
	b.solidp(Vector3((0.035 + HOLE.x) * 0.5, HOLE_TOP * 0.5, z), Vector3(HOLE.x - 0.035, HOLE_TOP, 0.1))
	# 切り口：針金の端が、穴の縁から短く飛び出す（横の針金 0.2m ごと、縦の針金 0.05m ごと）
	var y := 0.2
	while y < HOLE_TOP - 0.05:
		b.bar(cut, Vector3(HOLE.x, y, z), Vector3(HOLE.x + 0.035 + fmod(y * 7.3, 0.03), y - 0.01, z + 0.006), 0.006)
		y += 0.2
	var cx := HOLE.x + 0.05
	while cx < HOLE.y - 0.02:
		b.bar(cut, Vector3(cx, HOLE_TOP, z), Vector3(cx + 0.006, HOLE_TOP - 0.03 - fmod(cx * 5.1, 0.03), z + 0.008 * (fmod(cx * 20.0, 2.0) - 1.0)), 0.006)
		cx += 0.05
	b.build(root, "DumpFrontFence")
	# めくる網（右端の柱ぎわを軸に、外へ開く。先は反り返る）
	var hinge := Node3D.new()
	hinge.name = "HoleFlap"
	hinge.set_meta("base", xf * Transform3D(Basis.IDENTITY, Vector3(HOLE.y, 0.0, z)))
	root.add_child(hinge)
	var w := HOLE.y - HOLE.x
	var fb := Look.Batch.new()
	_flap_part(fb, net, cut, -w + FLAP_TIP, 0.0, false)
	fb.build(hinge, "Mesh")
	var tip := Node3D.new()
	tip.name = "Tip"
	tip.position = Vector3(-w + FLAP_TIP, 0.0, 0.0)
	tip.set_meta("base", Transform3D(Basis.IDENTITY, tip.position))
	hinge.add_child(tip)
	var tb := Look.Batch.new()
	_flap_part(tb, net, cut, -FLAP_TIP, 0.0, true)
	tb.build(tip, "Mesh")
	# 閉じている間：網を戻して、針金で留めてある（ねじった針金の輪）
	var ties := Look.Batch.new()
	ties.xf = xf
	var tie := Look.plain(Color("c9cfd1"), 0.35, 0.8)
	for p: Vector3 in [Vector3(HOLE.x, 0.45, z), Vector3(HOLE.x, 1.05, z), Vector3(HOLE.x, 1.6, z), Vector3(0.9, HOLE_TOP, z), Vector3(1.9, HOLE_TOP, z)]:
		var along := Vector3(0, 0.03, 0) if p.y < HOLE_TOP - 0.01 else Vector3(0.03, 0, 0)
		var across := Vector3(0.04, 0, 0) if p.y < HOLE_TOP - 0.01 else Vector3(0, 0.04, 0)
		ties.bar(tie, p - across + Vector3(0, 0, 0.012), p + across + Vector3(0, 0, 0.012), 0.008)
		ties.bar(tie, p - across + along + Vector3(0, 0, -0.012), p + across + along + Vector3(0, 0, -0.012), 0.008)
		ties.bar(tie, p + across + Vector3(0, 0, 0.012), p + across + along * 1.6 + Vector3(0.01, 0.01, 0.03), 0.008)
	ties.build(root, "HoleTies")
	# 開いている間：外の地面に、ペンチと、切り落とした針金のくず
	var lay := Look.Batch.new()
	lay.xf = xf
	_pliers(lay, Transform3D(Basis(Vector3.UP, 0.7), Vector3(0.85, 0.02, 12.75)))
	for k in 5:
		var p := Vector3(0.4 + k * 0.33, 0.012, 12.35 + fmod(k * 0.37, 0.5))
		lay.bar(cut, p, p + Vector3(0.06 + k * 0.012, 0.0, 0.03 - k * 0.015), 0.006)
	lay.build(root, "HolePliers")
	set_hole(root, 0.0)


# めくる網の一枚（x0..x0+幅、高さは穴の下から上まで）。tip：先の反り返る部分（自由な縁に切り口を付ける）
static func _flap_part(b: Look.Batch, net: Look.Tint, cut: Look.Tint, x0: float, z: float, tip: bool) -> void:
	var w := FLAP_TIP if tip else (HOLE.y - HOLE.x) - FLAP_TIP
	var y0 := 0.1
	var y1 := HOLE_TOP - 0.012
	b.boxp(net, Vector3(x0 + w * 0.5, (y0 + y1) * 0.5, z), Vector3(w, y1 - y0, 0.012), Look.Batch.ALL)
	# 上の縁（切り口）
	var x := x0 + 0.03
	while x < x0 + w - 0.01:
		b.bar(cut, Vector3(x, y1, z), Vector3(x - 0.004, y1 + 0.028 + fmod(absf(x) * 5.1, 0.025), z - 0.006), 0.006)
		x += 0.05
	# 下の縁（いちばん下の横の針金ごと切ってある）
	b.bar(cut, Vector3(x0, y0, z), Vector3(x0 + w, y0, z), 0.007)
	if tip:
		var y := 0.2
		while y < y1 - 0.05:
			b.bar(cut, Vector3(x0, y, z), Vector3(x0 - 0.03 - fmod(y * 7.3, 0.025), y + 0.01, z - 0.006), 0.006)
			y += 0.2


# ペンチ（赤い握りの、大きめの針金切り）。at の +Z が握りの向き
static func _pliers(b: Look.Batch, at: Transform3D) -> void:
	var steel := Look.plain(Color("6a7074"), 0.4, 0.8)
	var red := Look.plain(Color("c8352b"), 0.5)
	for s: float in [-1.0, 1.0]:
		b.box(steel, at * Transform3D(Basis(Vector3.UP, s * 0.05), Vector3(s * 0.012, 0.0, -0.06)), Vector3(0.016, 0.014, 0.1), Look.Batch.ALL)
		b.box(steel, at * Transform3D(Basis(Vector3.UP, s * 0.16), Vector3(s * 0.03, 0.0, 0.05)), Vector3(0.012, 0.012, 0.12), Look.Batch.ALL)
		b.box(red, at * Transform3D(Basis(Vector3.UP, s * 0.16), Vector3(s * 0.05, 0.0, 0.16)), Vector3(0.024, 0.02, 0.15), Look.Batch.ALL)
	b.cyl(steel, at * Transform3D(Basis.IDENTITY, Vector3(0, -0.01, -0.01)), 0.016, 0.02, 8)


# 穴の開き（0..1）。0：網を戻して針金で留めてある。1：網をめくって外へ開き、ペンチが転がっている
static func set_hole(root: Node3D, open: float) -> void:
	var hinge := root.get_node_or_null("HoleFlap") as Node3D
	if hinge:
		hinge.transform = (hinge.get_meta("base") as Transform3D) * Transform3D(Basis(Vector3.UP, FLAP_OPEN * open), Vector3.ZERO)
		var tip := hinge.get_node_or_null("Tip") as Node3D
		if tip:
			tip.transform = (tip.get_meta("base") as Transform3D) * Transform3D(Basis(Vector3.UP, -0.55 * open), Vector3.ZERO)
	var ties := root.get_node_or_null("HoleTies") as Node3D
	if ties:
		ties.visible = open < 0.05
	var pliers := root.get_node_or_null("HolePliers") as Node3D
	if pliers:
		pliers.visible = open >= 0.05


# ---- 札（文字なし。板と色の帯と絵記号） ----

# 分別の札（店の「01 / TIMBER」などの代わり。板と金具はそのまま使う）。色の帯で分ける
static func _bay_signs(b: Look.Batch) -> void:
	for s: Array in [[Vector3(-10.0, 2.95, 5.2), Color("8a5a32")],
			[Vector3(-10.0, 2.95, -6.1), Color("3b6ea5")],
			[Vector3(0.75, 3.0, -6.85), Color("d0782e")],
			[Vector3(9.5, 2.8, 8.5), Color("4e9a8a")],
			[Vector3(-5.5, 2.88, 0.95), Color("8a5a8f")]]:
		var c: Vector3 = s[0]
		b.boxp(Look.plain(Color("f4f2ea"), 0.6), c, Vector3(2.5, 0.62, 0.03), Look.Batch.ALL)
		b.boxp(Look.plain(s[1], 0.6), c + Vector3(0, 0.0, 0.017), Vector3(2.5, 0.3, 0.01), Look.Batch.ALL)
		b.boxp(Look.plain(GREEN, 0.6), c + Vector3(0, 0.25, 0.017), Vector3(2.5, 0.08, 0.01), Look.Batch.ALL)


# 会社の側の金網の札：進入禁止の絵（穴の左の、切られていない網に、針金で四隅を留める）
static func _front_notice(b: Look.Batch, root: Node3D, xf: Transform3D) -> void:
	var p := Vector3(-1.5, 1.35, FRONT_Z + 0.022)
	b.boxp(Look.plain(Color("f4f2ea"), 0.6), p, Vector3(0.5, 0.5, 0.012), Look.Batch.ALL)
	b.boxp(Look.plain(GREEN, 0.6), p + Vector3(0, 0.2, 0.007), Vector3(0.5, 0.1, 0.004), Look.Batch.ALL)
	for cx: float in [-0.22, 0.22]:
		for cy: float in [-0.22, 0.22]:
			b.bar(Look.plain(Color("c9cfd1"), 0.35, 0.8), p + Vector3(cx, cy, 0.008), p + Vector3(cx, cy, -0.03), 0.006)
	Look.picto(root, xf * Transform3D(Basis.IDENTITY, p + Vector3(0, -0.04, 0.0068)), "no_entry", Vector2(0.32, 0.32))


# ---- ゴミ集積所（フェンスの外。袋の山とカラス除けネット、収集日の札） ----

# 区道に面したゴミ集積所（ワールド座標。札は塀の面 wall_z に、南向きに貼る）
static func street_point(b: Look.Batch, root: Node3D, at: Vector3, wall_z: float) -> void:
	_collection_point(b, root, Transform3D.IDENTITY, at, 8, wall_z)


# 金網フェンスの網（ひし形。遠くでも透けて消えない）
static func net_mat() -> ShaderMaterial:
	if _net_mat == null:
		_net_mat = Look.chain_link(Vector2(0.06, 0.06), 0.0055, true)
	return _net_mat


# 溶接金網（縦長の格子。ヤードのモデルの金網に合わせる）
static func grid_mat() -> ShaderMaterial:
	return Look.chain_link(Vector2(0.05, 0.2), 0.005, false)


static func _crow_net() -> ShaderMaterial:
	if _crow_mat == null:
		_crow_mat = Look.chain_link(Vector2(0.008, 0.022), 0.0012, false)   # 袋の山にかぶせる網の UV は 0..1（Batch.lump）
	return _crow_mat


static func _collection_point(b: Look.Batch, root: Node3D, xf: Transform3D, at: Vector3, bags: int, sign_z := 12.06) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(at.x * 10.0), roundi(at.z * 10.0)))
	var spots: Array = []
	for k in bags:
		var row := k % 3
		var col := k / 3
		var p := at + Vector3(-1.1 + col * 0.72 + rng.randf_range(-0.12, 0.12), 0.0, -0.35 + row * 0.42 + rng.randf_range(-0.08, 0.08))
		if k >= bags - 2:
			p.y = 0.42             # 上に積んだ袋
			p.x -= 0.3
		spots.append(p)
	for k in spots.size():
		_bag(b, spots[k], rng, [Color("e6eef2"), Color("f0dc84"), Color("d9e4ea")][k % 3])
	# カラス除けネット（青い網を、袋の山にかぶせる）
	var w := 1.0 + float(bags) / 3.0 * 0.36
	b.lump(Look.Tint.new(_crow_net(), Color("2f6fd0")), at + Vector3(-0.35 + (w - 1.0) * 0.2, 0.05, 0.1), Vector3(w, 0.66, 0.7), at, rng, 0.0, 6, 14, 0.08)
	# 収集日の札（フェンスに結び付けた）。緑の帯と、ごみ袋の絵
	var s := Vector3(at.x + 0.1, 1.35, sign_z)
	b.boxp(Look.plain(Color("f4f2ea"), 0.6), s, Vector3(0.95, 0.62, 0.02), Look.Batch.ALL)
	b.boxp(Look.plain(GREEN, 0.6), s + Vector3(0, 0.23, 0.012), Vector3(0.95, 0.16, 0.01), Look.Batch.ALL)
	Look.picto(root, xf * Transform3D(Basis.IDENTITY, s + Vector3(0, -0.06, 0.0105)), "bag", Vector2(0.36, 0.36))


# ゴミ袋：ふくらんだ袋と、上の結び目
static func _bag(b: Look.Batch, p: Vector3, rng: RandomNumberGenerator, c: Color) -> void:
	# 中身で角ばった、地面でつぶれた袋。上をしぼって結んである
	var r := rng.randf_range(0.27, 0.35)
	var bag := Look.plain(c.darkened(rng.randf_range(0.0, 0.08)), 0.22)
	var c0 := p + Vector3(0, r * 0.72, 0)
	b.lump(bag, c0, Vector3(r * 1.08, r * 0.78, r * 0.98), c0 - Vector3(0, r * 0.5, 0), rng, 0.3, 6, 10, 0.32)
	# 袋のふくらみごとに当てる。山全体やネットの下の隙間は埋めない。
	b.solidp(c0, Vector3(r * 1.72, r * 1.45, r * 1.6))
	var neck := c0 + Vector3(rng.randf_range(-0.05, 0.05), r * 0.72, rng.randf_range(-0.04, 0.04))
	b.lump(bag, neck, Vector3(0.09, 0.11, 0.09), neck - Vector3(0, 0.1, 0), rng, 0.15, 4, 6, 0.15)
	var top := neck + Vector3(0, 0.1, 0)
	b.lump(bag, top, Vector3(0.05, 0.045, 0.05), top, rng, 0.1, 4, 6, 0.1)
	for s: float in [-1.0, 1.0]:
		b.box(bag, Transform3D(Basis(Vector3.BACK, s * 0.9 + rng.randf_range(-0.25, 0.25)), top + Vector3(s * 0.08, 0.05, 0)), Vector3(0.15, 0.025, 0.06), Look.Batch.ALL)


# ---- 粗大ごみ（処理券つき）：テレビ・洗濯機・マットレス・ソファ・自転車 ----

static func _junk(b: Look.Batch) -> void:
	var dark := Look.plain(Color("3a3d40"), 0.5)
	# ブラウン管テレビ（集積所の横、少し斜め）
	var tv := Transform3D(Basis(Vector3.UP, 0.25), Vector3(-8.9, 0.0, 13.15))
	# 古い木目調キャビネットは角を落とし、画面より奥に厚いブラウン管を持たせる。
	b.extrude(Look.mat("wood", Color("6b5a48")), tv, [Vector2(-0.3, 0.0), Vector2(0.3, 0.0), Vector2(0.32, 0.035), Vector2(0.32, 0.52), Vector2(0.28, 0.56), Vector2(-0.28, 0.56), Vector2(-0.32, 0.52), Vector2(-0.32, 0.035)], 0.44)
	b.solid(tv * Transform3D(Basis.IDENTITY, Vector3(0, 0.28, 0)), Vector3(0.64, 0.56, 0.44))
	b.solid(tv * Transform3D(Basis.IDENTITY, Vector3(0, 0.27, -0.33)), Vector3(0.44, 0.38, 0.24))
	b.box(dark, tv * Transform3D(Basis.IDENTITY, Vector3(0, 0.27, -0.33)), Vector3(0.44, 0.38, 0.24), Look.Batch.ALL)
	b.box(Look.plain(Color("b9b4a8"), 0.5), tv * Transform3D(Basis.IDENTITY, Vector3(0, 0.31, 0.222)), Vector3(0.56, 0.44, 0.01), Look.Batch.ALL)
	b.box(Look.plain(Color("26302f"), 0.12, 0.3), tv * Transform3D(Basis.IDENTITY, Vector3(0, 0.33, 0.228)), Vector3(0.46, 0.34, 0.025), Look.Batch.ALL)
	# 縁に囲まれたガラス、右端の選局つまみとスピーカーのスリット。
	for k in 5:
		b.box(dark, tv * Transform3D(Basis.IDENTITY, Vector3(0.255, 0.23 + k * 0.034, 0.232)), Vector3(0.025, 0.01, 0.012), Look.Batch.ALL)
	b.cyl(dark, tv * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.255, 0.445, 0.25)), 0.032, 0.025, 10, -1.0, true, true)
	for k in 3:
		b.box(dark, tv * Transform3D(Basis.IDENTITY, Vector3(-0.16 + k * 0.08, 0.09, 0.224)), Vector3(0.05, 0.03, 0.015), Look.Batch.ALL)
	# 室内アンテナ（V字の2本の棒）
	var ant := tv * Vector3(0.05, 0.57, -0.05)
	b.box(dark, tv * Transform3D(Basis.IDENTITY, Vector3(0.05, 0.585, -0.05)), Vector3(0.12, 0.03, 0.08), Look.Batch.ALL)
	for s: float in [-1.0, 1.0]:
		b.bar(Look.plain(Color("c8ccce"), 0.3, 0.8), ant, tv * Vector3(0.05 + s * 0.28, 0.98, -0.12), 0.012)
	_ticket(b, tv * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-0.17, 0.562, 0.08)))
	# 縦型の洗濯機（フタが半開き）
	var wm := Transform3D(Basis(Vector3.UP, -0.15), Vector3(8.4, 0.0, 13.1))
	var enamel := Look.plain(Color("e9ebea"), 0.42)
	var trim := Look.plain(Color("c3cccb"), 0.48)
	# 空洞のある上部と、薄い鉄板を折った箱。フタの下に洗濯槽が見える。
	for side: float in [-1.0, 1.0]:
		var side_at := wm * Transform3D(Basis.IDENTITY, Vector3(side * 0.265, 0.45, 0))
		b.box(enamel, side_at, Vector3(0.05, 0.8, 0.58), Look.Batch.ALL)
		b.solid(side_at, Vector3(0.05, 0.8, 0.58))
	for side: float in [-1.0, 1.0]:
		var face_at := wm * Transform3D(Basis.IDENTITY, Vector3(0, 0.45, side * 0.265))
		b.box(enamel, face_at, Vector3(0.48, 0.8, 0.05), Look.Batch.ALL)
		b.solid(face_at, Vector3(0.48, 0.8, 0.05))
	b.box(trim, wm * Transform3D(Basis.IDENTITY, Vector3(0, 0.09, 0)), Vector3(0.53, 0.14, 0.53), Look.Batch.ALL)
	b.solid(wm * Transform3D(Basis.IDENTITY, Vector3(0, 0.09, 0)), Vector3(0.53, 0.14, 0.53))
	b.cyl(dark, wm * Transform3D(Basis.IDENTITY, Vector3(0, 0.72, 0)), 0.235, 0.12, 16)
	for k in 16:
		var angle := TAU * k / 16.0
		var ring := wm * Transform3D(Basis(Vector3.UP, angle), Vector3(sin(angle) * 0.235, 0.87, cos(angle) * 0.235))
		b.box(trim, ring, Vector3(0.1, 0.06, 0.035), Look.Batch.ALL)
	b.box(trim, wm * Transform3D(Basis.IDENTITY, Vector3(0, 0.95, -0.22)), Vector3(0.58, 0.12, 0.14), Look.Batch.ALL)
	b.solid(wm * Transform3D(Basis.IDENTITY, Vector3(0, 0.95, -0.22)), Vector3(0.58, 0.12, 0.14))
	b.box(dark, wm * Transform3D(Basis.IDENTITY, Vector3(-0.12, 1.015, -0.22)), Vector3(0.16, 0.015, 0.06), Look.Batch.ALL)
	for x: float in [0.08, 0.17]:
		b.cyl(Look.plain(Color("5a797d"), 0.42), wm * Transform3D(Basis.IDENTITY, Vector3(x, 1.015, -0.22)), 0.025, 0.012, 10)
	var lid := wm * Transform3D(Basis(Vector3.RIGHT, -0.65), Vector3(0, 1.105, 0.007))
	b.box(enamel, lid, Vector3(0.5, 0.035, 0.44), Look.Batch.ALL)
	b.solid(lid, Vector3(0.5, 0.035, 0.44))
	b.box(trim, lid * Transform3D(Basis.IDENTITY, Vector3(0, 0.022, 0.16)), Vector3(0.19, 0.015, 0.035), Look.Batch.ALL)
	for x: float in [-0.22, 0.22]:
		for zz: float in [-0.22, 0.22]:
			b.box(dark, wm * Transform3D(Basis.IDENTITY, Vector3(x, 0.025, zz)), Vector3(0.07, 0.05, 0.07), Look.Batch.ALL)
	_ticket(b, wm * Transform3D(Basis.IDENTITY, Vector3(-0.14, 0.62, 0.292)))
	# マットレス（フェンスに立てかけた。縞の布）
	var mt := Transform3D(Basis(Vector3.RIGHT, -0.18), Vector3(5.6, 0.92, 12.42))
	b.box(Look.plain(Color("e8e1cf"), 0.95), mt, Vector3(1.0, 1.85, 0.2), Look.Batch.ALL)
	b.solid(mt, Vector3(1.0, 1.85, 0.2))
	for k in 6:
		b.box(Look.plain(Color("9fb4c4"), 0.95), mt * Transform3D(Basis.IDENTITY, Vector3(-0.375 + k * 0.15, 0, 0.101)), Vector3(0.05, 1.85, 0.005), Look.Batch.ALL)
	b.box(Look.plain(Color("c9b48a"), 0.95), mt * Transform3D(Basis.IDENTITY, Vector3(0.18, -0.3, 0.104)), Vector3(0.36, 0.28, 0.003), Look.Batch.ALL)
	_ticket(b, mt * Transform3D(Basis.IDENTITY, Vector3(-0.25, 0.55, 0.106)))
	# 二人がけのソファ（座面のクッションが1つ無い）
	var sf := Transform3D(Basis(Vector3.UP, 0.1), Vector3(12.3, 0.0, 12.85))
	var cloth := Look.plain(Color("6f8a6a"), 0.95)
	b.box(cloth, sf * Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)), Vector3(1.5, 0.3, 0.8), Look.Batch.ALL)
	b.solid(sf * Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)), Vector3(1.5, 0.3, 0.8))
	b.solid(sf * Transform3D(Basis.IDENTITY, Vector3(0, 0.55, -0.32)), Vector3(1.5, 0.66, 0.18))
	# 台輪と短い木脚で床へ接続。無くなったクッションの下には座枠が残る。
	var wood := Look.mat("wood", Color("534335"))
	for x: float in [-0.58, 0.58]:
		for zz: float in [-0.27, 0.27]:
			b.box(wood, sf * Transform3D(Basis.IDENTITY, Vector3(x, 0.055, zz)), Vector3(0.09, 0.11, 0.09), Look.Batch.ALL)
	for k in 4:
		b.box(wood, sf * Transform3D(Basis.IDENTITY, Vector3(0.13 + k * 0.12, 0.385, 0.05)), Vector3(0.045, 0.045, 0.56), Look.Batch.ALL)
	b.box(cloth, sf * Transform3D(Basis.IDENTITY, Vector3(0, 0.55, -0.32)), Vector3(1.5, 0.66, 0.18), Look.Batch.ALL)
	for s: float in [-1.0, 1.0]:
		var arm := sf * Transform3D(Basis.IDENTITY, Vector3(s * 0.68, 0.45, 0.02))
		b.extrude(cloth, arm, [Vector2(-0.08, -0.25), Vector2(0.08, -0.25), Vector2(0.08, 0.19), Vector2(0.045, 0.25), Vector2(-0.045, 0.25), Vector2(-0.08, 0.19)], 0.8)
		b.solid(arm, Vector3(0.16, 0.5, 0.8))
		b.bar(Look.plain(Color("82977d"), 0.95), sf * Vector3(s * 0.68, 0.7, -0.31), sf * Vector3(s * 0.68, 0.7, 0.35), 0.012)
	b.box(Look.plain(Color("7d977a"), 0.95), sf * Transform3D(Basis(Vector3.BACK, 0.05), Vector3(-0.32, 0.44, 0.05)), Vector3(0.58, 0.14, 0.62), Look.Batch.ALL)
	b.solid(sf * Transform3D(Basis(Vector3.BACK, 0.05), Vector3(-0.32, 0.44, 0.05)), Vector3(0.58, 0.14, 0.62))
	# 座面の縁の縫い目と、背クッションの分割。布の色差は面単位に絞る。
	for zz: float in [-0.25, 0.35]:
		b.bar(Look.plain(Color("92a28a"), 0.95), sf * Vector3(-0.6, 0.5, zz), sf * Vector3(-0.04, 0.5, zz), 0.012)
	for x: float in [-0.32, 0.32]:
		b.box(Look.plain(Color("7d9375"), 0.95), sf * Transform3D(Basis(Vector3.RIGHT, -0.08), Vector3(x, 0.66, -0.209)), Vector3(0.58, 0.37, 0.06), Look.Batch.ALL)
	_ticket(b, sf * Transform3D(Basis.IDENTITY, Vector3(-0.4, 0.62, -0.225)))
	# さびた自転車（タイヤの空気が抜けている）
	var bike := Transform3D(Basis(Vector3.UP, 0.12), Vector3(14.2, 0.0, 12.75))
	Office._bike(b, bike.origin, 0.12, Color("8a6a4a"))
	_ticket(b, bike * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-0.5, 0.575, 0.0)))


# 粗大ごみ処理券（黄色い紙。at の +Z が表）。文字は書かず、赤い帯だけ
static func _ticket(b: Look.Batch, at: Transform3D) -> void:
	b.box(Look.plain(TICKET, 0.8), at, Vector3(0.16, 0.1, 0.004), Look.Batch.ALL)
	b.box(Look.plain(TICKET_RED, 0.8), at * Transform3D(Basis.IDENTITY, Vector3(0, 0.032, 0.0025)), Vector3(0.16, 0.026, 0.001), Look.Batch.ALL)


# ---- 門の鎖 ----

# 鎖：a から b まで、向きを交互に変えた輪を並べる
static func _chain(b: Look.Batch, m: Look.Tint, a: Vector3, c: Vector3, k_size := 1.0) -> void:
	var d := c - a
	var n := maxi(int(d.length() / (0.055 * k_size)), 1)
	var fwd := d.normalized()
	var side := fwd.cross(Vector3.UP if absf(fwd.y) < 0.9 else Vector3.RIGHT).normalized()
	for k in n:
		var p := a + d * ((k + 0.5) / n)
		var up := fwd.cross(side) if k % 2 == 0 else side
		b.box(m, Transform3D(Basis(up.cross(fwd).normalized(), up.normalized(), fwd), p), Vector3(0.012, 0.035, 0.06) * k_size, Look.Batch.ALL)


static func _padlock(b: Look.Batch, p: Vector3, yaw: float, k := 1.0) -> void:
	var at := Transform3D(Basis(Vector3.UP, yaw), p)
	b.box(Look.plain(Color("c9a04a"), 0.35, 0.8), at, Vector3(0.08, 0.075, 0.03) * k, Look.Batch.ALL)
	b.box(Look.plain(Color("9aa0a2"), 0.3, 0.8), at * Transform3D(Basis.IDENTITY, Vector3(0, 0.06 * k, 0)), Vector3(0.06, 0.05, 0.012) * k, Look.Batch.ALL)


# ---- 拾ってきた廃材に、処理券を貼ったままにする ----
# 物の見た目のうち、正面（+Z）を向いた面の、右上寄りの点を探して貼る（頂点を見るだけなので軽い）
static func sticker_on(prop: Node3D, visual: Node3D) -> void:
	if String(prop.get("kind")) == "carton":
		return              # 段ボール箱は会社の段ボール置き場の物（ゴミ捨て場から拾った物ではない）
	var best := Vector3.ZERO
	var best_n := Vector3.ZERO
	var best_score := -INF
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var pts: Array = []
	var stack: Array = [[visual, visual.transform]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var t: Transform3D = it[1]
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var arr: Array = mesh.surface_get_arrays(s)
				var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
				if ns.size() != vs.size():
					continue
				var step := maxi(vs.size() / 1500, 1)
				for i in range(0, vs.size(), step):
					var v := t * vs[i]
					lo = lo.min(v)
					hi = hi.max(v)
					pts.append([v, (t.basis * ns[i]).normalized()])
		for c in node.get_children():
			if c is Node3D:
				stack.push_back([c, t * (c as Node3D).transform])
	if pts.is_empty():
		return
	var size := hi - lo
	var aim := Vector2(lo.x + size.x * 0.68, lo.y + size.y * 0.66)
	for pn: Array in pts:
		var v: Vector3 = pn[0]
		var n: Vector3 = pn[1]
		if n.z < 0.82:
			continue
		var score := (v.z - hi.z) * 2.0 - Vector2(v.x, v.y).distance_to(aim) / maxf(size.length(), 0.01)
		if score > best_score:
			best_score = score
			best = v
			best_n = n
	# 制作資料から作り直した物は、鍵穴や取っ手を隠さない位置をモデルに指定できる。
	# マーカーの +Z が貼る面の外向き。通常の廃材はこれまでどおり自動配置する。
	var anchor := visual.find_child("DisposalTicketAnchor", true, false) as Node3D
	if anchor != null:
		var authored := anchor.transform
		var parent := anchor.get_parent() as Node3D
		while parent != prop:
			authored = parent.transform * authored
			parent = parent.get_parent() as Node3D
		best = authored.origin
		best_n = authored.basis.z.normalized()
		best_score = 0.0
	if best_score == -INF:
		return
	var side := Vector3.UP.cross(best_n).normalized()
	if side.length() < 0.5:
		side = Vector3.RIGHT
	var up := best_n.cross(side).normalized()
	var at := Transform3D(Basis(side, up, best_n).rotated(best_n, -0.12), best + best_n * 0.004)
	var b := Look.Batch.new()
	b.box(Look.plain(TICKET, 0.8), Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(0.13, 0.085, 0.003), Look.Batch.ALL)
	b.box(Look.plain(TICKET_RED, 0.8), Transform3D(Basis.IDENTITY, Vector3(0, 0.028, 0.002)), Vector3(0.13, 0.022, 0.001), Look.Batch.ALL)
	b.no_shadow = true
	# 見た目（visual）の子にして、物が消える時はいっしょに消える。visual の縮尺は打ち消す
	var node := b.build(visual, "Ticket")
	node.transform = visual.transform.affine_inverse() * at
