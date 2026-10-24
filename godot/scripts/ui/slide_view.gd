extends CanvasLayer
## 会社のスマホの画面（依頼主から届いた参考写真）。見ている人の画面いっぱいに出て、まわりの世界を隠す。
## 黒い縁のスマホを横向きに持った画面に、写真が1枚だけ見える。左右に送ると、次の写真に替わる。
## 中身（どの種類の物を並べるか）は production_slides.gd がホストで決めた物。ここは、それを絵にするだけ。
##   1枚目   ：役ごとのおすすめの形。黒いシルエットだけ（名前・色・属性は出さない）。一緒に使うと良い2つは「＋」でつなぐ
##   2枚目   ：依頼主の好み。その属性を持つ物のシルエットに、ハートを添える（属性の名前は出さない）
##   3枚目〜 ：場面ごとの絵コンテ（storyboard.gd の鉛筆の絵）。1場面1枚
## 絵は BASE の大きさで並べて、画面に合わせて拡大縮小する。
const UI := preload("res://scripts/ui/ui_theme.gd")
const Catalog := preload("res://scripts/ui/order_catalog.gd")
const Cast := preload("res://scripts/production_cast.gd")
const Briefs := preload("res://scripts/production_briefs.gd")
const Storyboard := preload("res://scripts/ui/storyboard.gd")
const BASE := Vector2(1280, 720)
const LIT := Color("f3ebd5")           # 光の当たった絵の地
const INK := Color("17181b")           # シルエットと文字
const FADED := Color("6f6a5c")
const CELL := Color(1, 1, 1, 0.55)     # 物を1つ置く枠
const SILHOUETTE := "shader_type canvas_item;\nuniform vec4 ink : source_color = vec4(0.09, 0.094, 0.106, 1.0);\nvoid fragment() {\n\tCOLOR = vec4(ink.rgb, smoothstep(0.25, 0.65, texture(TEXTURE, UV).a) * ink.a);\n}\n"

var game: Node
var page := 0
var root: Control
var cover: ColorRect                   # 世界を隠す黒い面（画面いっぱい）
var frame: Panel                       # 光の当たった1枚の絵
var pages: Array = []                  # スライド（Control）。送る順
var _canvas: Control                   # BASE の大きさの面
var _glow: TextureRect
var _bezel: Panel                      # スマホの黒い縁
var _lens: Panel
var _hints: HBoxContainer
var _dots: HBoxContainer
var _sig := ""
var _tween: Tween
static var _ink: ShaderMaterial


func build(owner_game: Node) -> void:
	game = owner_game
	layer = 8
	visible = false
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.theme = UI.make_theme(20)
	add_child(root)
	cover = ColorRect.new()
	cover.color = Color(0.012, 0.012, 0.016, 1.0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cover)
	# 画面のまわりに、液晶の光が少しだけ漏れる
	_glow = TextureRect.new()
	_glow.texture = UI.radial_gradient(Color(0.85, 0.9, 1.0, 0.12), Color(0.85, 0.9, 1.0, 0.0), 0.5)
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.stretch_mode = TextureRect.STRETCH_SCALE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_glow)
	# スマホの黒い縁（横向き。右にカメラの穴）
	_bezel = Panel.new()
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color("141518")
	rim.set_corner_radius_all(44)
	rim.border_color = Color("2e3036")
	rim.set_border_width_all(3)
	_bezel.add_theme_stylebox_override("panel", rim)
	_bezel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bezel)
	_lens = Panel.new()
	var lens := StyleBoxFlat.new()
	lens.bg_color = Color("05060a")
	lens.set_corner_radius_all(10)
	_lens.add_theme_stylebox_override("panel", lens)
	_lens.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bezel.add_child(_lens)
	frame = Panel.new()
	frame.add_theme_stylebox_override("panel", _flat(LIT, 10))
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	_canvas = Control.new()
	_canvas.size = BASE
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_canvas)
	# 絵のふちは、少し暗く落ちる（箱の中のランプは、真ん中がいちばん明るい）
	var falloff := TextureRect.new()
	falloff.texture = _edge_shade()
	falloff.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	falloff.stretch_mode = TextureRect.STRETCH_SCALE
	falloff.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	falloff.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(falloff)
	# 下：送り方と、いま何枚目か（文字は最小限）
	_hints = HBoxContainer.new()
	_hints.add_theme_constant_override("separation", 18)
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hints)
	_hints.add_child(_dim(UI.key_item("A ◀", 15)))
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 8)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.add_child(_dots)
	_hints.add_child(_dim(UI.key_item("▶ D", 15)))
	var space := Control.new()
	space.custom_minimum_size.x = 28
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.add_child(space)
	_hints.add_child(_dim(UI.key_item("F やめる", 15)))
	root.resized.connect(_fit)
	_fit()


func _dim(c: Control) -> Control:
	c.modulate = Color(1, 1, 1, 0.62)
	return c


# 画面の大きさに合わせて、絵の大きさと置き場所を決める
func _fit() -> void:
	var vs: Vector2 = root.size
	if vs.x < 10.0 or vs.y < 10.0:
		vs = BASE
	var w: float = minf(vs.x * 0.78, (vs.y - 200.0) * BASE.x / BASE.y)
	var h: float = w * BASE.y / BASE.x
	frame.position = Vector2((vs.x - w) * 0.5, (vs.y - h) * 0.5 - 20.0).round()
	frame.size = Vector2(w, h)
	_canvas.scale = Vector2.ONE * (w / BASE.x)
	_bezel.position = frame.position - Vector2(46, 22)
	_bezel.size = Vector2(w, h) + Vector2(92, 44)
	_lens.position = Vector2(_bezel.size.x - 30.0, _bezel.size.y * 0.5 - 10.0)
	_lens.size = Vector2(20, 20)
	_glow.position = frame.position - Vector2(w, h) * 0.22
	_glow.size = Vector2(w, h) * 1.44
	_hints.position = Vector2(0, frame.position.y + h + 24.0)
	_hints.size = Vector2(vs.x, 30.0)


# ---- 開く・閉じる・送る ----

func open(deck: Dictionary, jobs: Array) -> void:
	page = 0
	visible = true
	_fit()
	sync(deck, jobs)
	_show(0)


func close() -> void:
	visible = false


# 中身が変わっていたら、スライドを作り直す（あとから届いたときにも合う）
func sync(deck: Dictionary, jobs: Array) -> void:
	var sig := str(deck)
	if sig == _sig:
		return
	_sig = sig
	_rebuild(deck, jobs)
	page = clampi(page, 0, maxi(pages.size() - 1, 0))
	_show(0)


func count() -> int:
	return pages.size()


# 左右に送る（端まで行ったら、反対の端へ回る）
func step(direction: int) -> void:
	if pages.size() <= 1 or direction == 0:
		return
	page = posmod(page + direction, pages.size())
	_show(signi(direction))
	Sfx.play("ui_select", null, -6.0)


func _show(slide_from: int) -> void:
	for i in pages.size():
		(pages[i] as Control).visible = i == page
	for i in _dots.get_child_count():
		(_dots.get_child(i) as UI.Dot).set_color(UI.CLAP_WHITE if i == page else Color(1, 1, 1, 0.22))
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if pages.is_empty():
		return
	var now: Control = pages[page]
	now.position = Vector2.ZERO
	now.modulate.a = 1.0
	if slide_from == 0:
		return
	# 次の絵が、横からすっと入る
	now.position.x = BASE.x * 0.18 * float(slide_from)
	now.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(now, "position:x", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(now, "modulate:a", 1.0, 0.12)


# そのスライドに書いてある文字（確認用：名前や属性が紛れ込んでいないかを見る）
func texts(index: int) -> Array:
	var out: Array = []
	if index < 0 or index >= pages.size():
		return out
	for label: Label in (pages[index] as Control).find_children("*", "Label", true, false):
		out.append(label.text)
	return out


# そのスライドに並んでいるシルエットの種類（確認用）
func shown_kinds(index: int) -> Array:
	var out: Array = []
	if index < 0 or index >= pages.size():
		return out
	for pic: TextureRect in (pages[index] as Control).find_children("*", "TextureRect", true, false):
		if pic.has_meta("kind"):
			out.append(str(pic.get_meta("kind")))
	return out


# ---- スライドを作る ----

func _rebuild(deck: Dictionary, jobs: Array) -> void:
	for old: Node in pages:
		_canvas.remove_child(old)
		old.queue_free()
	pages.clear()
	for dot: Node in _dots.get_children():
		_dots.remove_child(dot)
		dot.queue_free()
	var job: int = int(deck.get("job", -1))
	if deck.is_empty() or job < 0 or job >= jobs.size():
		return
	var info: Dictionary = jobs[job]
	var story: String = str(info["script"])
	pages.append(_roles_page(deck, story))
	if not (deck.get("likes", []) as Array).is_empty():
		pages.append(_likes_page(deck, job))
	# 絵コンテの組（5場面の完全版は、専用の5枚。無ければ、台本と同じ名前の3枚）
	var board: String = str(info.get("board", story))
	var needs: Array = Briefs.BOARDS.get(board, [])
	var scenes: Array = info.get("scenes", [])
	for i in scenes.size():
		pages.append(_board_page(board, i, str(scenes[i]).get_slice("（", 0), str(needs[i]) if i < needs.size() else ""))
	for i in pages.size():
		_dots.add_child(UI.Dot.new().setup(Color(1, 1, 1, 0.22), 7.0))


func _new_page() -> Control:
	var p := Control.new()
	p.size = BASE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = false
	_canvas.add_child(p)
	return p


# 役ごとのおすすめの形：左に役の名前、右にシルエット。組は、上下のあいだの「＋」でつなぐ
func _roles_page(deck: Dictionary, story: String) -> Control:
	var p := _new_page()
	var rows: Array = deck.get("rows", [])
	var cell := Vector2(288, 188)
	var gap := Vector2(24, 22)
	var left := 322.0
	var top: float = (BASE.y - (rows.size() * cell.y + maxi(rows.size() - 1, 0) * gap.y)) * 0.5
	for r in rows.size():
		var role: String = str(rows[r][0])
		var y: float = top + r * (cell.y + gap.y)
		var caption := _words(Cast.role_name(role, story) + ("に" if role == "boom" else "の役に"), 30, INK, "bold")
		_put(p, caption, Rect2(58, y, 250, cell.y))
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var kinds: Array = rows[r][1]
		for c in kinds.size():
			_cell(p, str(kinds[c]), Rect2(left + c * (cell.x + gap.x), y, cell.x, cell.y))
	for mark: Array in deck.get("plus", []):
		var badge := _Plus.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var at := Vector2(left + int(mark[1]) * (cell.x + gap.x) + cell.x * 0.5, top + (int(mark[0]) + 1) * (cell.y + gap.y) - gap.y * 0.5)
		_put(p, badge, Rect2(at - Vector2(27, 27), Vector2(54, 54)))
	return p


# 依頼主の好み：依頼主の顔とハート。右に、好きな属性ごとの物をシルエットで（何の属性かは、形から読み取る）
func _likes_page(deck: Dictionary, job: int) -> Control:
	var p := _new_page()
	var brief: Dictionary = Briefs.brief(job)
	var portrait := Panel.new()
	portrait.add_theme_stylebox_override("panel", _flat(CELL, 14))
	_put(p, portrait, Rect2(70, 156, 300, 350))
	var face := TextureRect.new()
	var face_path := "res://assets/ui/clients/%s.png" % str(brief.get("cast", ""))
	face.texture = load(face_path) if ResourceLoader.exists(face_path) else null
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(portrait, face, Rect2(16, 16, 268, 318))
	var big := _Heart.new()
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(p, big, Rect2(306, 108, 104, 96))
	var caption := _words("依頼主の好み", 26, INK, "bold")
	_put(p, caption, Rect2(70, 518, 300, 44))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var groups: Array = deck.get("likes", [])
	var cell := Vector2(216, 216)
	var gap := Vector2(20, 40)
	var left := 540.0
	var top: float = (BASE.y - (groups.size() * cell.y + maxi(groups.size() - 1, 0) * gap.y)) * 0.5
	for g in groups.size():
		var y: float = top + g * (cell.y + gap.y)
		var heart := _Heart.new()
		heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_put(p, heart, Rect2(452, y + cell.y * 0.5 - 30.0, 66, 60))
		var kinds: Array = groups[g]
		for c in kinds.size():
			_cell(p, str(kinds[c]), Rect2(left + c * (cell.x + gap.x), y, cell.x, cell.y))
	return p


# 絵コンテ：1場面1枚。下に、場面の番号と名前、どう映れば成立かの1行
func _board_page(story: String, index: int, title: String, need: String) -> Control:
	var p := _new_page()
	var pic := TextureRect.new()
	pic.texture = Storyboard.texture(story, index)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(p, pic, Rect2(176, 34, 928, 522))
	var number := _Number.new()
	number.text = str(index + 1)
	number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(p, number, Rect2(176, 584, 58, 58))
	var head := _words(title, 30, INK, "bold")
	_put(p, head, Rect2(252, 574, 860, 44))
	var sub := _words(need, 21, FADED, "body")
	_put(p, sub, Rect2(252, 620, 860, 34))
	return p


# 物を1つ置く枠と、その中の黒いシルエット（発注画面の写真から、形だけを抜く）
func _cell(parent: Control, kind: String, rect: Rect2) -> void:
	var back := Panel.new()
	back.add_theme_stylebox_override("panel", _flat(CELL, 14))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_put(parent, back, rect)
	if kind == "":
		return
	var pic := TextureRect.new()
	pic.texture = Catalog.thumb(kind)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.material = _silhouette()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_meta("kind", kind)
	var pad := Vector2(22, 16)
	_put(back, pic, Rect2(pad, rect.size - pad * 2.0))


func _put(parent: Control, child: Control, rect: Rect2) -> Control:
	parent.add_child(child)
	child.position = rect.position
	child.size = rect.size
	return child


func _words(text: String, px: int, color: Color, kind: String) -> Label:
	var l := UI.label(text, px, color, kind)
	l.clip_text = true
	return l


static func _flat(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.anti_aliasing = true
	return s


# 写真を、形だけの黒い影にする描き方（1つを使い回す）
static func _silhouette() -> ShaderMaterial:
	if _ink == null:
		var shader := Shader.new()
		shader.code = SILHOUETTE
		_ink = ShaderMaterial.new()
		_ink.shader = shader
		_ink.set_shader_parameter("ink", INK)
	return _ink


# 真ん中は明るく、ふちへ向かって少し暗くなる重ね
static func _edge_shade() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0.25, 0.16, 0.04, 0.0), Color(0.25, 0.16, 0.04, 0.0), Color(0.25, 0.16, 0.04, 0.34)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, -0.2)
	tex.width = 256
	tex.height = 256
	return tex


# 「＋」の丸い印
class _Plus extends Control:
	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color("17181b"))
		draw_circle(c, r - 4.0, Color("ffcc00"))
		var arm := r * 0.46
		draw_line(c - Vector2(arm, 0), c + Vector2(arm, 0), Color("17181b"), 6.0)
		draw_line(c - Vector2(0, arm), c + Vector2(0, arm), Color("17181b"), 6.0)


# ハート
class _Heart extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var red := Color("e5392d")
		var r := w * 0.27
		draw_circle(Vector2(w * 0.27, h * 0.32), r, red)
		draw_circle(Vector2(w * 0.73, h * 0.32), r, red)
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.015, h * 0.43), Vector2(w * 0.5, h * 0.2), Vector2(w * 0.985, h * 0.43), Vector2(w * 0.5, h)]), red)


# 場面の番号（丸に数字）
class _Number extends Control:
	var text := ""

	func _draw() -> void:
		var ui: GDScript = load("res://scripts/ui/ui_theme.gd")
		var f: Font = ui.fnt("display")
		var c := size * 0.5
		draw_circle(c, minf(size.x, size.y) * 0.5, Color("17181b"))
		var px := 32
		var ts := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		draw_string(f, Vector2(0, (size.y - ts.y) * 0.5 + f.get_ascent(px)), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, px, Color("f3ebd5"))
