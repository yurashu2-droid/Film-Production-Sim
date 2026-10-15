extends RefCounted
## 廃材置き場を「となりの区の粗大ごみ置き場」に見せる飾り。制作班は、ここから勝手に拾ってきて撮影に使っている。
##   ・遊びの仕組み（廃材の置き場所・数・門が開く時）は変えない。見た目と物語だけを変える
##   ・ユーザー作成のヤード（L01）の店の看板と通路の白線は外し（hidden_part）、区の看板と分別の札に差し替える
##   ・門：閉まっている間は鎖と南京錠。開くと、切られた鎖が地面に落ち、ボルトクリッパーが転がっている
##   ・外のフェンス際：ゴミ集積所（袋とカラス除けネット）と、処理券を貼った粗大ごみ
##   ・拾ってきた廃材には、黄色い「粗大ごみ処理券」が貼ったままになっている（sticker_on）
## 位置はヤードのローカル座標（x：横、z：奥 −12 〜 門 +12。+z が門の外＝会社の側）
const Look := preload("res://scripts/production_look.gd")
const Office := preload("res://scripts/production_office.gd")

const WARD := "みどり区"
const TICKET := Color("f2d23c")          # 処理券の黄色
const TICKET_RED := Color("c8352b")
const GREEN := Color("2f7d4f")           # 区の看板の緑

static var _net_mat: StandardMaterial3D


# ヤードの部品のうち、外す物（店の看板・通路の白線・コンテナの置き場の印）
static func hidden_part(nm: String) -> bool:
	for key: String in ["zone title", "zone subtitle", "zone bolt", "materials title", "materials subtitle", "materials bolt",
			"second take salvage title", "second take salvage subtitle", "second take salvage bolt", "fabric rack label",
			"crosswalk edge", "faded aisle boundary", "aisle 5_5m clear", "aisle 3m clear", "pad stencil",
			"container bay side marking", "container optional pad", "twistlock corner landing marker", "entry public apron"]:
		if nm.contains(key):
			return true
	return false


static func build(root: Node3D, xf: Transform3D) -> void:
	var font := Look.font()
	var b := Look.Batch.new()
	b.xf = xf
	_main_sign(b, root, xf, font)
	_bay_signs(b, root, xf, font)
	_collection_point(b, root, xf, font, Vector3(-11.4, 0, 12.95), 9)
	_collection_point(b, root, xf, font, Vector3(10.6, 0, 12.95), 6)
	_junk(b, root, xf, font)
	_notices(b, root, xf, font)
	b.build(root, "DumpDressing")
	# 門の鎖（閉まっている間）と、切られた鎖（開いたあと）。production_yard.set_gate が切り替える
	var shut := Look.Batch.new()
	shut.xf = xf
	_lock_shut(shut)
	var shut_node := shut.build(root, "DumpLockShut")
	var cut := Look.Batch.new()
	cut.xf = xf
	_lock_cut(cut)
	var cut_node := cut.build(root, "DumpLockCut")
	cut_node.visible = false
	shut_node.visible = true


# 門の開き（0..1）に合わせて、鎖を切り替える
static func set_lock(root: Node3D, open: float) -> void:
	var shut := root.get_node_or_null("DumpLockShut") as Node3D
	var cut := root.get_node_or_null("DumpLockCut") as Node3D
	if shut:
		shut.visible = open < 0.05
	if cut:
		cut.visible = open >= 0.05


# ---- 看板 ----

# 門の横の大きな看板（店の看板の板と柱に、区の看板を打ち付けた）
static func _main_sign(b: Look.Batch, root: Node3D, xf: Transform3D, font: Font) -> void:
	var c := Vector3(-6.3, 2.5, 12.1)
	b.boxp(Look.plain(Color("f4f2ea"), 0.6), c, Vector3(3.9, 1.45, 0.04), Look.Batch.ALL)
	b.boxp(Look.plain(GREEN, 0.6), c + Vector3(0, 0.56, 0.022), Vector3(3.9, 0.33, 0.01), Look.Batch.ALL)
	b.boxp(Look.plain(TICKET_RED, 0.6), c + Vector3(0, -0.56, 0.022), Vector3(3.9, 0.3, 0.01), Look.Batch.ALL)
	for x: float in [-1.8, 1.8]:
		for y: float in [0.6, -0.6]:
			b.boxp(Look.plain(Color("9aa0a2"), 0.4, 0.6), c + Vector3(x, y, 0.03), Vector3(0.05, 0.05, 0.02), Look.Batch.ALL)
	var z := c.z + 0.032
	_text(root, xf, Vector3(c.x, c.y + 0.56, z), WARD + "　清掃課", 0.0042, Color.WHITE, font)
	_text(root, xf, Vector3(c.x, c.y + 0.13, z), "粗大ごみ　一時置き場", 0.0054, Color("1f2a24"), font)
	_text(root, xf, Vector3(c.x, c.y - 0.2, z), "関係者以外　立入禁止", 0.0038, Color("1f2a24"), font)
	_text(root, xf, Vector3(c.x, c.y - 0.56, z), "持ち去りは禁止です（見つけたら通報します）", 0.0025, Color.WHITE, font)


# 分別の札（店の「01 / TIMBER」などの代わり。板と金具はそのまま使う）
static func _bay_signs(b: Look.Batch, root: Node3D, xf: Transform3D, font: Font) -> void:
	for s: Array in [[Vector3(-10.0, 2.95, 5.2), "木くず（角材・板）", Color("8a5a32")],
			[Vector3(-10.0, 2.95, -6.1), "金属くず", Color("3b6ea5")],
			[Vector3(0.75, 3.0, -6.85), "粗大ごみ（建具・家具）", Color("d0782e")],
			[Vector3(9.5, 2.8, 8.5), "発泡スチロール・軽い物", Color("4e9a8a")],
			[Vector3(-5.5, 2.88, 0.95), "古布・ふとん", Color("8a5a8f")]]:
		var c: Vector3 = s[0]
		b.boxp(Look.plain(Color("f4f2ea"), 0.6), c, Vector3(2.5, 0.62, 0.03), Look.Batch.ALL)
		b.boxp(Look.plain(s[2], 0.6), c + Vector3(0, 0.22, 0.017), Vector3(2.5, 0.18, 0.01), Look.Batch.ALL)
		_text(root, xf, c + Vector3(0, 0.22, 0.024), WARD + "　分別置き場", 0.0026, Color.WHITE, font)
		_text(root, xf, c + Vector3(0, -0.06, 0.024), s[1], 0.0034, Color("1f2a24"), font)


# フェンスの貼り紙：不法投棄・収集日・防犯カメラ（作動していないかもしれない）
static func _notices(b: Look.Batch, root: Node3D, xf: Transform3D, font: Font) -> void:
	var z := 12.18
	# 不法投棄は犯罪です（赤字）
	var p := Vector3(4.3, 1.45, z)
	b.boxp(Look.plain(Color("f4f2ea"), 0.6), Vector3(p.x, p.y, z), Vector3(0.9, 0.6, 0.02), Look.Batch.ALL)
	_text(root, xf, Vector3(p.x, p.y + 0.12, z + 0.012), "不法投棄は犯罪です", 0.0022, TICKET_RED, font)
	_text(root, xf, Vector3(p.x, p.y - 0.1, z + 0.012), "5年以下の懲役　" + WARD, 0.0015, Color("1f2a24"), font)
	# 防犯カメラ作動中（柱の上にカメラ。たぶん電源は入っていない）
	var cam := Vector3(-3.6, 2.6, 12.25)
	b.boxp(Look.plain(Color("e8e8e2"), 0.5, 0.2), cam, Vector3(0.18, 0.16, 0.34), Look.Batch.ALL)
	b.boxp(Look.plain(Color("26282a"), 0.3), cam + Vector3(0, -0.01, 0.175), Vector3(0.11, 0.1, 0.02), Look.Batch.ALL)
	b.bar(Look.plain(Color("9aa0a2"), 0.4, 0.6), cam + Vector3(0, 0.08, -0.12), cam + Vector3(0, 0.3, -0.2), 0.04)
	b.boxp(Look.plain(Color("f2d23c"), 0.6), Vector3(-3.6, 1.7, z), Vector3(0.5, 0.36, 0.02), Look.Batch.ALL)
	_text(root, xf, Vector3(-3.6, 1.74, z + 0.012), "防犯カメラ", 0.0018, Color("1f2a24"), font)
	_text(root, xf, Vector3(-3.6, 1.6, z + 0.012), "作動中", 0.0018, TICKET_RED, font)


# ---- ゴミ集積所（フェンスの外。袋の山とカラス除けネット、収集日の札） ----

static func _collection_point(b: Look.Batch, root: Node3D, xf: Transform3D, font: Font, at: Vector3, bags: int) -> void:
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
	b.lump(Look.Tint.new(_net(), Color("2f6fd0")), at + Vector3(-0.35 + (w - 1.0) * 0.2, 0.05, 0.1), Vector3(w, 0.66, 0.7), at, rng, 0.0, 6, 14, 0.08)
	# 収集日の札（フェンスに結び付けた）
	var s := Vector3(at.x + 0.1, 1.35, 12.06)
	b.boxp(Look.plain(Color("f4f2ea"), 0.6), s, Vector3(0.95, 0.62, 0.02), Look.Batch.ALL)
	b.boxp(Look.plain(GREEN, 0.6), s + Vector3(0, 0.23, 0.012), Vector3(0.95, 0.16, 0.01), Look.Batch.ALL)
	_text(root, xf, s + Vector3(0, 0.23, 0.02), "ごみ集積所", 0.0022, Color.WHITE, font)
	_text(root, xf, s + Vector3(0, 0.03, 0.02), "燃やすごみ　月・木", 0.0015, Color("1f2a24"), font)
	_text(root, xf, s + Vector3(0, -0.15, 0.02), "朝8時までに出してください", 0.001, Color("1f2a24"), font)


# ゴミ袋：ふくらんだ袋と、上の結び目
static func _bag(b: Look.Batch, p: Vector3, rng: RandomNumberGenerator, c: Color) -> void:
	# 中身で角ばった、地面でつぶれた袋。上をしぼって結んである
	var r := rng.randf_range(0.27, 0.35)
	var bag := Look.plain(c.darkened(rng.randf_range(0.0, 0.08)), 0.22)
	var c0 := p + Vector3(0, r * 0.72, 0)
	b.lump(bag, c0, Vector3(r * 1.08, r * 0.78, r * 0.98), c0 - Vector3(0, r * 0.5, 0), rng, 0.3, 6, 10, 0.32)
	var neck := c0 + Vector3(rng.randf_range(-0.05, 0.05), r * 0.72, rng.randf_range(-0.04, 0.04))
	b.lump(bag, neck, Vector3(0.09, 0.11, 0.09), neck - Vector3(0, 0.1, 0), rng, 0.15, 4, 6, 0.15)
	var top := neck + Vector3(0, 0.1, 0)
	b.lump(bag, top, Vector3(0.05, 0.045, 0.05), top, rng, 0.1, 4, 6, 0.1)
	for s: float in [-1.0, 1.0]:
		b.box(bag, Transform3D(Basis(Vector3.BACK, s * 0.9 + rng.randf_range(-0.25, 0.25)), top + Vector3(s * 0.08, 0.05, 0)), Vector3(0.15, 0.025, 0.06), Look.Batch.ALL)


# 網のマテリアル（細い格子で抜く。両面）
static func _net() -> StandardMaterial3D:
	if _net_mat != null:
		return _net_mat
	var sz := 64
	var im := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	im.fill(Color(1, 1, 1, 0))
	for i in sz:
		for w in 3:
			im.set_pixel(i, w, Color.WHITE)
			im.set_pixel(w, i, Color.WHITE)
	im.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(im)
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(26, 9, 1)
	m.roughness = 0.8
	_net_mat = m
	return m


# ---- 粗大ごみ（処理券つき）：テレビ・洗濯機・マットレス・ソファ・自転車 ----

static func _junk(b: Look.Batch, root: Node3D, xf: Transform3D, font: Font) -> void:
	var dark := Look.plain(Color("3a3d40"), 0.5)
	# ブラウン管テレビ（集積所の横、少し斜め）
	var tv := Transform3D(Basis(Vector3.UP, 0.25), Vector3(-8.9, 0.0, 13.15))
	b.box(Look.plain(Color("6b5a48"), 0.6), tv * Transform3D(Basis.IDENTITY, Vector3(0, 0.28, 0)), Vector3(0.64, 0.56, 0.44), Look.Batch.ALL)
	b.box(dark, tv * Transform3D(Basis.IDENTITY, Vector3(0, 0.27, -0.33)), Vector3(0.44, 0.38, 0.24), Look.Batch.ALL)
	b.box(Look.plain(Color("b9b4a8"), 0.5), tv * Transform3D(Basis.IDENTITY, Vector3(0, 0.31, 0.222)), Vector3(0.56, 0.44, 0.01), Look.Batch.ALL)
	b.box(Look.plain(Color("26302f"), 0.12, 0.3), tv * Transform3D(Basis.IDENTITY, Vector3(0, 0.33, 0.228)), Vector3(0.46, 0.34, 0.01), Look.Batch.ALL)
	for k in 3:
		b.box(dark, tv * Transform3D(Basis.IDENTITY, Vector3(-0.16 + k * 0.08, 0.09, 0.224)), Vector3(0.05, 0.03, 0.015), Look.Batch.ALL)
	# 室内アンテナ（V字の2本の棒）
	var ant := tv * Vector3(0.05, 0.57, -0.05)
	b.box(dark, tv * Transform3D(Basis.IDENTITY, Vector3(0.05, 0.585, -0.05)), Vector3(0.12, 0.03, 0.08), Look.Batch.ALL)
	for s: float in [-1.0, 1.0]:
		b.bar(Look.plain(Color("c8ccce"), 0.3, 0.8), ant, tv * Vector3(0.05 + s * 0.28, 0.98, -0.12), 0.012)
	_ticket(b, root, xf, font, tv * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-0.17, 0.562, 0.08)))
	# 縦型の洗濯機（フタが半開き）
	var wm := Transform3D(Basis(Vector3.UP, -0.15), Vector3(8.4, 0.0, 13.1))
	b.box(Look.plain(Color("e9ebea"), 0.4), wm * Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), Vector3(0.58, 0.9, 0.58), Look.Batch.ALL)
	b.box(Look.plain(Color("c9ced0"), 0.4), wm * Transform3D(Basis.IDENTITY, Vector3(0, 0.95, -0.22)), Vector3(0.58, 0.12, 0.14), Look.Batch.ALL)
	b.box(Look.plain(Color("dfe3e3"), 0.3), wm * Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.98, 0.04)), Vector3(0.5, 0.02, 0.44), Look.Batch.ALL)
	_ticket(b, root, xf, font, wm * Transform3D(Basis.IDENTITY, Vector3(-0.14, 0.62, 0.292)))
	# マットレス（フェンスに立てかけた。縞の布）
	var mt := Transform3D(Basis(Vector3.RIGHT, -0.18), Vector3(5.6, 0.92, 12.42))
	b.box(Look.plain(Color("e8e1cf"), 0.95), mt, Vector3(1.0, 1.85, 0.2), Look.Batch.ALL)
	for k in 6:
		b.box(Look.plain(Color("9fb4c4"), 0.95), mt * Transform3D(Basis.IDENTITY, Vector3(-0.375 + k * 0.15, 0, 0.101)), Vector3(0.05, 1.85, 0.005), Look.Batch.ALL)
	b.box(Look.plain(Color("c9b48a"), 0.95), mt * Transform3D(Basis.IDENTITY, Vector3(0.18, -0.3, 0.104)), Vector3(0.36, 0.28, 0.003), Look.Batch.ALL)
	_ticket(b, root, xf, font, mt * Transform3D(Basis.IDENTITY, Vector3(-0.25, 0.55, 0.106)))
	# 二人がけのソファ（座面のクッションが1つ無い）
	var sf := Transform3D(Basis(Vector3.UP, 0.1), Vector3(12.3, 0.0, 12.85))
	var cloth := Look.plain(Color("6f8a6a"), 0.95)
	b.box(cloth, sf * Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)), Vector3(1.5, 0.3, 0.8), Look.Batch.ALL)
	b.box(cloth, sf * Transform3D(Basis.IDENTITY, Vector3(0, 0.55, -0.32)), Vector3(1.5, 0.66, 0.18), Look.Batch.ALL)
	for s: float in [-1.0, 1.0]:
		b.box(cloth, sf * Transform3D(Basis.IDENTITY, Vector3(s * 0.68, 0.45, 0.02)), Vector3(0.16, 0.5, 0.8), Look.Batch.ALL)
	b.box(Look.plain(Color("7d977a"), 0.95), sf * Transform3D(Basis(Vector3.BACK, 0.05), Vector3(-0.32, 0.44, 0.05)), Vector3(0.58, 0.14, 0.62), Look.Batch.ALL)
	b.box(dark, sf * Transform3D(Basis.IDENTITY, Vector3(0.32, 0.38, 0.05)), Vector3(0.56, 0.02, 0.6), Look.Batch.ALL)
	_ticket(b, root, xf, font, sf * Transform3D(Basis.IDENTITY, Vector3(-0.4, 0.62, -0.225)))
	# さびた自転車（タイヤの空気が抜けている）
	var bike := Transform3D(Basis(Vector3.UP, 0.12), Vector3(14.2, 0.0, 12.75))
	Office._bike(b, bike.origin, 0.12, Color("8a6a4a"))
	_ticket(b, root, xf, font, bike * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(-0.5, 0.575, 0.0)))


# 粗大ごみ処理券（黄色い紙。at の +Z が表）
static func _ticket(b: Look.Batch, root: Node3D, xf: Transform3D, font: Font, at: Transform3D) -> void:
	b.box(Look.plain(TICKET, 0.8), at, Vector3(0.16, 0.1, 0.004), Look.Batch.ALL)
	b.box(Look.plain(TICKET_RED, 0.8), at * Transform3D(Basis.IDENTITY, Vector3(0, 0.032, 0.0025)), Vector3(0.16, 0.026, 0.001), Look.Batch.ALL)
	var l := Look.label(root, xf * at * Transform3D(Basis.IDENTITY, Vector3(0, -0.01, 0.004)), "粗大ごみ\n処理券", 0.0007, 32, TICKET_RED, font, false)
	l.line_spacing = -6.0


# ---- 門の鎖 ----

# 閉まっている門：2枚の扉の合わせ目に鎖を巻き、南京錠をかける
static func _lock_shut(b: Look.Batch) -> void:
	var steel := Look.plain(Color("a9afb2"), 0.35, 0.8)
	for y: float in [1.05, 1.2]:
		var loop := [Vector3(-0.2, y, 11.86), Vector3(0.2, y + 0.03, 11.86), Vector3(0.2, y - 0.03, 12.1), Vector3(-0.2, y, 12.1)]
		for k in 4:
			_chain(b, steel, loop[k], loop[(k + 1) % 4], 1.6)
	_chain(b, steel, Vector3(0.0, 1.05, 12.1), Vector3(0.03, 0.78, 12.14), 1.6)
	_padlock(b, Vector3(0.03, 0.68, 12.15), 0.0, 1.6)
	# 区の札（施錠中）
	b.boxp(Look.plain(Color("f4f2ea"), 0.6), Vector3(0.35, 1.38, 12.13), Vector3(0.3, 0.2, 0.01), Look.Batch.ALL)
	b.boxp(Look.plain(GREEN, 0.6), Vector3(0.35, 1.45, 12.137), Vector3(0.3, 0.05, 0.005), Look.Batch.ALL)


# 開いた門：切られた鎖が地面に落ち、南京錠とボルトクリッパーが転がっている
static func _lock_cut(b: Look.Batch) -> void:
	var steel := Look.plain(Color("5d6266"), 0.45, 0.7)
	var y := 0.02
	var path := [Vector3(1.2, y, 12.6), Vector3(1.5, y, 12.9), Vector3(1.35, y, 13.2), Vector3(1.7, y, 13.45), Vector3(2.05, y, 13.35)]
	for k in path.size() - 1:
		_chain(b, steel, path[k], path[k + 1])
	_padlock(b, Vector3(2.15, 0.05, 13.4), PI * 0.5)
	# ボルトクリッパー（赤い握り）
	var at := Transform3D(Basis(Vector3.UP, 0.6), Vector3(2.7, 0.03, 13.0))
	var red := Look.plain(Color("c8352b"), 0.5)
	for s: float in [-1.0, 1.0]:
		b.box(steel, at * Transform3D(Basis(Vector3.UP, s * 0.06), Vector3(s * 0.03, 0.0, 0.0)), Vector3(0.025, 0.025, 0.62), Look.Batch.ALL)
		b.box(red, at * Transform3D(Basis(Vector3.UP, s * 0.1), Vector3(s * 0.06, 0.0, 0.42)), Vector3(0.04, 0.04, 0.3), Look.Batch.ALL)
	b.box(steel, at * Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -0.36)), Vector3(0.07, 0.03, 0.12), Look.Batch.ALL)


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


static func _text(root: Node3D, xf: Transform3D, p: Vector3, words: String, pixel: float, c: Color, font: Font) -> Label3D:
	return Look.label(root, xf * Transform3D(Basis.IDENTITY, p), words, pixel, 64, c, font, false)


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
