extends Control
## キャラクター選び＝衣装部屋のハンガーラック（2026-10-21 にユーザーが選んだ案「7-C」）。
##   ・暗い衣装部屋の壁に、横一本の金属のラック。キャラの数だけハンガーが掛かり、そのキャラの色の衣装と、マニラ紙の名札が下がる
##   ・選んでいる衣装は、少し手前に引き出されて（下がって大きく）、上から光が当たる。ほかの衣装はゆっくり揺れているだけ
##   ・衣装を押すと選べる（← → ↑ ↓ のキーでも）。左下の姿見に、選んだキャラの3Dの姿が映る
##   ・下に、名前と特技を書いた白い紙。右下の段ボールの看板「この衣装を着る」で決める
## 中の物は、1600x900 の舞台（_stage）に置いて、画面の大きさに合わせて縮める。
## production_hud.gd が、この画面の直下の PanelContainer を紙（テープ留め）に塗り替えるので、直下には PanelContainer を置かない
const Stage := preload("res://scripts/stage.gd")
const CastVisual := preload("res://scripts/cast_visual.gd")
const UI := preload("res://scripts/ui/ui_theme.gd")
const Talents := preload("res://scripts/cast_talents.gd")

const STAGE_SIZE := Vector2(1600, 900)
const RAIL_Y := 102.0                 # ラックの棒のまん中の高さ（舞台の上から）
const RAIL_X := Vector2(64, 1536)     # 棒の左右のはし
const HANGER_FIRST := 196.0           # いちばん左のハンガーのまん中
const HANGER_LAST := 1404.0
const PULL_DOWN := 20.0               # 選んだ衣装が下がる量
const PULL_GROW := 0.18               # 選んだ衣装が大きくなる割合
const INK := Color("1d1a14")
# 衣装：キャラの番号 → [生地の色, 仕立て]。色はゲームの模型（姿見に映る姿）に合わせる。仕立ては Hanger._cut() の形
const COSTUMES := {
	"M02": [Color("ece8df"), "suit"],       # ロボット：つなぎ（おなかに丸い窓）
	"04": [Color("26324a"), "smock"],       # ベレー帽の人：紺の上っ張りと白いえり巻き（フックに黒いベレー帽）
	"09": [Color("b98f55"), "box"],         # 段ボール頭：段ボールの着ぐるみ
	"03": [Color("3a3a40"), "jacket"],      # 手帳の人：黒いコートと赤いシャツ（胸ポケットに手帳）
	"01": [Color("d27f8f"), "dress"],       # ドレスの人：桃色のドレスと肩の白いショール
	"02": [Color("86cdbf"), "uniform"],     # カエルの警官：薄い青緑の制服（金のバッジ・肩掛けのベルト）
	"06": [Color("e3cf8a"), "robe"],        # モップの王様：モップの毛のガウンと黒いマント（フックに王冠）
}

var game: Node
var selected := 0
var view: SubViewport
var preview: Node3D
var camera: Camera3D
var avatar: Node3D
var buttons: Array[Button] = []      # ハンガー（1着ずつ押せる）
# 選んでいるキャラの特技（名前・準備中の札・説明）
var _talent_name: Label
var _talent_wait: Control
var _talent_desc: Label
var _talent_parts: Array[Control] = []     # 特技まわりの部品。特技の無いモード（撮影だけモード）では隠す
var _stage: Control
var _rack: Rack
var _name: Label
var _time := 0.0


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_stage = Control.new()
	_stage.size = STAGE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_rack = Rack.new()
	_rack.size = STAGE_SIZE
	_stage.add_child(_rack)
	# ハンガー
	var count: int = game.PLAYER_CASTS.size()
	for i in count:
		var tag: String = game.PLAYER_CASTS[i]
		var h := Hanger.new()
		var look: Array = COSTUMES.get(tag, [Color("8a8a8a"), "base"])
		h.cloth = look[0]
		h.cut = look[1]
		h.tag = tag
		h.title = game.PLAYER_NAMES[i]
		h.index = i
		var cx := HANGER_FIRST if count <= 1 else lerpf(HANGER_FIRST, HANGER_LAST, float(i) / float(count - 1))
		h.home = Vector2(cx - Hanger.W * 0.5, RAIL_Y - Hanger.HOOK_Y)
		h.position = h.home
		h.pressed.connect(choose.bind(i))
		_stage.add_child(h)
		buttons.append(h)
	_build_mirror()
	_build_card()
	_build_controls()
	resized.connect(_fit)
	_fit()
	set_process(false)
	hide()


# 左下の姿見。選んだキャラの3Dの姿が映る
func _build_mirror() -> void:
	var glass_bg := Color("2e3139")
	view = SubViewport.new()
	view.size = Vector2i(184, 284)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.msaa_3d = Viewport.MSAA_2X
	add_child(view)
	preview = Node3D.new()
	view.add_child(preview)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = glass_bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.94, 0.85)
	e.ambient_light_energy = 0.55
	env.environment = e
	preview.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -15, 0)
	light.light_energy = 1.6
	light.light_color = Color(1.0, 0.93, 0.8)
	preview.add_child(light)
	camera = Camera3D.new()
	camera.fov = 30
	preview.add_child(camera)
	camera.current = true
	var mirror := Mirror.new()
	mirror.position = Vector2(84, 552)
	mirror.size = Vector2(212, 330)
	_stage.add_child(mirror)
	var image := TextureRect.new()
	image.texture = view.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mirror.add_child(image)
	image.position = Vector2(Mirror.FRAME, Mirror.FRAME)
	image.size = mirror.size - Vector2(Mirror.FRAME * 2, Mirror.FRAME * 2 + Mirror.FEET)
	var sheen := Sheen.new()
	sheen.position = image.position
	sheen.size = image.size
	mirror.add_child(sheen)


# 下のまん中の白い紙：名前と特技
func _build_card() -> void:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = Vector2(352, 584)
	_stage.add_child(slot)
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.rotation = deg_to_rad(-0.6)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fbfaf5")
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(5, 9)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 20
	sb.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(760, 0)
	slot.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	_name = FilmSet.label("", 34, INK, "mincho")
	column.add_child(_name)
	var rule := ColorRect.new()
	rule.color = Color(0, 0, 0, 0.14)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var over := FilmSet.label("特技", 16, Color("6b6358"), "mincho")
	over.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(over)
	var key := FilmSet._key_of(Talents.KEY_NAME)
	head.add_child(FilmSet._chip(key if key != "" else Talents.KEY_NAME, 17))
	_talent_name = FilmSet.label("", 24, INK, "mincho")
	_talent_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_talent_name)
	_talent_wait = UI.Stamp.new().setup("準備中", 14, UI.STAMP_RED)
	_talent_wait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_talent_wait)
	_talent_desc = UI.label("", 16, Color("3d382f"), "body")
	_talent_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_talent_desc.custom_minimum_size = Vector2(700, 0)
	column.add_child(_talent_desc)
	_talent_parts.append(rule)
	_talent_parts.append(head)
	_talent_parts.append(_talent_desc)


# 右下：段ボールの看板（この衣装を着る・戻る）と、キーの案内
func _build_controls() -> void:
	var accept := Button.new()
	accept.text = "この衣装を着る"
	accept.focus_mode = Control.FOCUS_NONE
	FilmSet.style_sign_button(accept, "mustard", 28, 66)
	accept.custom_minimum_size.x = 300
	accept.pressed.connect(confirm)
	_place(accept, Vector2(1150, 620), -1.2)
	var cancel := Button.new()
	cancel.text = "戻る"
	cancel.focus_mode = Control.FOCUS_NONE
	FilmSet.style_sign_button(cancel, "cream", 20, 46)
	cancel.custom_minimum_size.x = 120
	cancel.pressed.connect(func(): game.set_character_menu(false))
	_place(cancel, Vector2(1330, 712), 1.5)
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", 8)
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair: Array in [["←→", "えらぶ"], ["Enter", "着る"], ["Esc", "戻る"]]:
		hints.add_child(FilmSet._chip(pair[0], 15))
		var t := FilmSet.label(pair[1], 16, Color("b9b2a4"), "marker")
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hints.add_child(t)
		var gap := Control.new()
		gap.custom_minimum_size.x = 8
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hints.add_child(gap)
	hints.position = Vector2(1156, 800)
	_stage.add_child(hints)


# 傾けて置く（箱に入れると傾きが消えるので、ただの置き場に入れて回す）
func _place(c: Control, at: Vector2, tilt_deg: float) -> void:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = at
	_stage.add_child(slot)
	slot.add_child(c)
	c.reset_size()
	c.pivot_offset = c.size * 0.5
	c.rotation = deg_to_rad(tilt_deg)


# 1600x900 の舞台を、画面に収まる大きさに縮めて、まん中に置く
func _fit() -> void:
	if _stage == null:
		return
	var s := minf(size.x / STAGE_SIZE.x, size.y / STAGE_SIZE.y)
	if s <= 0.0:
		return
	_stage.scale = Vector2(s, s)
	_stage.position = ((size - STAGE_SIZE * s) * 0.5).floor()
	queue_redraw()


# 衣装部屋の壁（舞台の外まで塗る）
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([Color("2c2d33"), Color("2c2d33"), Color("17181c"), Color("17181c")]))
	# 壁板の継ぎ目（間隔は少しずつ違う）
	var x := 0.0
	var k := 0
	while x < size.x:
		draw_rect(Rect2(x, 0, 2, size.y), Color(0, 0, 0, 0.16))
		draw_rect(Rect2(x + 2, 0, 1, size.y), Color(1, 1, 1, 0.025))
		x += 150.0 + float((k * 53) % 41)
		k += 1
	# 床と幅木
	var s := _stage.scale.x if _stage else 1.0
	var floor_y := (_stage.position.y if _stage else 0.0) + 868.0 * s
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), Color("121214"))
	draw_rect(Rect2(0, floor_y - 10.0 * s, size.x, 10.0 * s), Color("3a3330"))


func _process(delta: float) -> void:
	_time += delta
	for i in buttons.size():
		(buttons[i] as Hanger).step(delta, _time, i == selected)
	var target: float = (buttons[selected] as Hanger).home.x + Hanger.W * 0.5 if selected < buttons.size() else 0.0
	_rack.spot_x = lerpf(_rack.spot_x, target, 1.0 - exp(-delta * 10.0))
	_rack.queue_redraw()


func set_open(on: bool) -> void:
	visible = on
	set_process(on)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	preview.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if on:
		_fit()
		# 特技は制作モードだけ（game.talent がある）。無いモードでは欄ごと隠す
		for part: Control in _talent_parts:
			part.visible = game.get("talent") != null
		var me: Node = game.local_player()
		choose(game.PLAYER_CASTS.find(me.vis.tag))
		# 開いたときは、引き出しの途中から始めない
		for i in buttons.size():
			(buttons[i] as Hanger).snap(i == selected)
		_rack.spot_x = (buttons[selected] as Hanger).home.x + Hanger.W * 0.5


func choose(index: int) -> void:
	var before := selected
	selected = posmod(index, game.PLAYER_CASTS.size())
	for i in buttons.size():
		buttons[i].set_pressed_no_signal(i == selected)
	if before != selected and before < buttons.size():
		# 戻した衣装と、となりの衣装が、少し揺れる
		(buttons[before] as Hanger).swing += 0.05 * signf(float(selected - before))
		(buttons[selected] as Hanger).swing -= 0.035 * signf(float(selected - before))
		for n in [selected - 1, selected + 1]:
			if n >= 0 and n < buttons.size() and n != before:
				(buttons[n] as Hanger).swing += 0.02 * signf(float(n - selected))
	var picked: String = game.PLAYER_CASTS[selected]
	_name.text = game.PLAYER_NAMES[selected]
	_talent_name.text = Talents.title(picked)
	_talent_wait.visible = not Talents.ready(picked)
	_talent_desc.text = Talents.describe(picked) + ("" if Talents.ready(picked) else "\n（準備中。まだ使えない）")
	if avatar:
		preview.remove_child(avatar)
		avatar.queue_free()
	avatar = CastVisual.new()
	preview.add_child(avatar)
	avatar.setup(game.PLAYER_CASTS[selected])
	# 姿見の正面に、頭から足まで入るように
	var bounds := Stage.merged_aabb(avatar)
	var center := bounds.get_center()
	var aspect := float(view.size.x) / float(view.size.y)
	var half_v := tan(deg_to_rad(camera.fov * 0.5))
	var need := maxf(bounds.size.y * 0.5, bounds.size.x * 0.5 / aspect) * 1.04
	var distance := need / half_v + bounds.size.z * 0.5
	camera.position = center + Vector3(0.12, 0.05, 1).normalized() * distance
	camera.look_at(center)


func confirm() -> void:
	game.h_select_cast.rpc_id(1, selected)
	game.set_character_menu(false)


func handle_key(key: int) -> void:
	match key:
		KEY_UP, KEY_LEFT: choose(selected - 1)
		KEY_DOWN, KEY_RIGHT: choose(selected + 1)
		KEY_ENTER, KEY_KP_ENTER: confirm()
		KEY_ESCAPE, KEY_C: game.set_character_menu(false)


# ---- ラック：金属の棒と、壁の金具。選んだ衣装の上から当たる光 ----
class Rack extends Control:
	var spot_x := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var warm := Color(1.0, 0.9, 0.66)
		# 上の照明から下へ広がる光（棒の上で細く、下で広く）
		var top_w := 46.0
		var bottom_w := 210.0
		var bottom_y := 560.0
		draw_polygon(PackedVector2Array([Vector2(spot_x - top_w, -40), Vector2(spot_x + top_w, -40), Vector2(spot_x + bottom_w, bottom_y), Vector2(spot_x - bottom_w, bottom_y)]),
			PackedColorArray([Color(warm, 0.20), Color(warm, 0.20), Color(warm, 0.0), Color(warm, 0.0)]))
		# 衣装の後ろの壁に当たった、やわらかい丸い明るさ
		draw_set_transform(Vector2(spot_x, 300), 0.0, Vector2(1.0, 1.55))
		for k in 10:
			draw_circle(Vector2.ZERO, 190.0 - float(k) * 17.0, Color(warm, 0.022))
		draw_set_transform_matrix(Transform2D.IDENTITY)
		# 棒を壁に留める金具（左右）
		for x: float in [RAIL_X.x + 10.0, RAIL_X.y - 10.0]:
			draw_rect(Rect2(x - 9, 52, 18, 10), Color("6f767c"))
			draw_rect(Rect2(x - 3, 58, 6, RAIL_Y - 58), Color("8e969c"))
			draw_rect(Rect2(x - 3, 58, 2, RAIL_Y - 58), Color("c9ced2"))
		# 棒（上が光る金属の丸棒）と、壁に落ちる影
		var y0 := RAIL_Y - 6.5
		var x0 := RAIL_X.x
		var x1 := RAIL_X.y
		draw_rect(Rect2(x0, y0 + 14, x1 - x0, 6), Color(0, 0, 0, 0.28))
		draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y0 + 13), Vector2(x0, y0 + 13)]),
			PackedColorArray([Color("e3e7ea"), Color("e3e7ea"), Color("6f767c"), Color("6f767c")]))
		draw_rect(Rect2(x0, y0 + 2, x1 - x0, 2), Color(1, 1, 1, 0.55))
		# 光の当たっている所だけ、棒が明るい
		draw_rect(Rect2(spot_x - 60, y0, 120, 13), Color(warm, 0.18))


# ---- ハンガー1本：フック・木の肩・衣装・名札。押すとそのキャラを選ぶ ----
class Hanger extends Button:
	const W := 152.0
	const H := 372.0
	const HOOK_Y := 12.0          # フックの丸のまん中（＝棒のまん中）
	const BAR_Y := 40.0           # 木の肩の高さ
	const COS_TOP := 40.0
	const COS_W := 128.0
	const COS_H := 272.0
	const TILTS := [-3.0, 2.5, -2.0, 3.0, -1.5, 2.0, -3.5]
	var cloth := Color.GRAY
	var cut := "base"
	var tag := ""
	var title := ""
	var index := 0
	var home := Vector2.ZERO
	var pull := 0.0               # 0＝ラックに掛かったまま、1＝手前に引き出した
	var swing := 0.0              # 揺れ（ばねで戻る）
	var swing_v := 0.0

	func _init() -> void:
		size = Vector2(W, H)
		custom_minimum_size = Vector2(W, H)
		pivot_offset = Vector2(W * 0.5, HOOK_Y)
		focus_mode = Control.FOCUS_NONE
		toggle_mode = true
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var empty := StyleBoxEmpty.new()
		for s: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			add_theme_stylebox_override(s, empty)

	func snap(on: bool) -> void:
		pull = 1.0 if on else 0.0
		swing = 0.0
		swing_v = 0.0
		_apply(0.0, on)

	func step(delta: float, t: float, on: bool) -> void:
		pull = lerpf(pull, 1.0 if on else 0.0, 1.0 - exp(-delta * 9.0))
		# ばね：揺らされた分が、ゆっくり戻る
		swing_v += (-swing * 26.0 - swing_v * 3.2) * delta
		swing += swing_v * delta
		_apply(t, on)

	func _apply(t: float, on: bool) -> void:
		var idle := sin(t * 0.9 + float(index) * 1.7) * 0.014 + sin(t * 2.1 + float(index)) * 0.004
		rotation = idle * (1.0 - pull * 0.8) + swing
		scale = Vector2.ONE * (1.0 + PULL_GROW * pull)
		position = home + Vector2(0, PULL_DOWN * pull)
		z_index = 2 if on else 0
		# 光の当たっていない衣装は暗い。マウスを乗せると少し明るく
		var lit := 0.6 + (0.12 if is_hovered() else 0.0)
		var v := lerpf(lit, 1.0, pull)
		modulate = Color(v, v, v * 1.03)

	func _draw() -> void:
		var cx := W * 0.5
		var metal := Color("c9ced2")
		var metal_dark := Color("7d858b")
		# フック（棒に引っかける丸）と首
		var hc := Vector2(cx + 8.0, HOOK_Y)
		draw_arc(hc, 8.0, PI, PI * 2.25, 14, metal_dark, 4.0, true)
		draw_arc(hc, 8.0, PI, PI * 2.25, 14, metal, 2.0, true)
		draw_line(Vector2(cx, HOOK_Y), Vector2(cx, BAR_Y - 6.0), metal_dark, 4.0, true)
		draw_line(Vector2(cx, HOOK_Y), Vector2(cx, BAR_Y - 6.0), metal, 2.0, true)
		_hook_extra(hc)
		# 衣装
		var pts := _cut()
		var cols := PackedColorArray()
		for p in pts:
			var k := clampf((p.y - COS_TOP) / COS_H, 0.0, 1.0)
			cols.append(cloth.lightened(0.10).lerp(cloth.darkened(0.32), k))
		draw_polygon(pts, cols)
		_folds()
		_extras()
		var ring := pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, cloth.darkened(0.55), 2.0, true)
		# 木の肩（衣装の上に、少し見える）
		var bar := PackedVector2Array([Vector2(cx - 60, BAR_Y + 15), Vector2(cx, BAR_Y - 4), Vector2(cx + 60, BAR_Y + 15),
			Vector2(cx + 60, BAR_Y + 21), Vector2(cx, BAR_Y + 3), Vector2(cx - 60, BAR_Y + 21)])
		draw_colored_polygon(bar, Color("8a6a4a"))
		draw_polyline(PackedVector2Array([Vector2(cx - 60, BAR_Y + 15), Vector2(cx, BAR_Y - 4), Vector2(cx + 60, BAR_Y + 15)]), Color("b08a62"), 1.5, true)
		_tag(pts)

	# 衣装の形（衣装の箱の中の割合。上が肩、下が裾）
	func _cut() -> PackedVector2Array:
		var f: Array
		match cut:
			"suit":
				f = [[.24, 0], [.76, 0], [1, .16], [.95, .44], [.84, .43], [.84, 1], [.55, 1], [.5, .6], [.45, 1], [.16, 1], [.16, .43], [.05, .44], [0, .16]]
			"smock":
				f = [[.24, 0], [.76, 0], [1, .2], [.95, .5], [.84, .48], [.97, .84], [.03, .84], [.16, .48], [.05, .5], [0, .2]]
			"box":
				f = [[.06, .06], [.94, .06], [.94, .72], [.06, .72]]
			"jacket":
				f = [[.22, 0], [.78, 0], [1, .18], [.97, .62], [.86, .62], [.88, .86], [.12, .86], [.14, .62], [.03, .62], [0, .18]]
			"dress":
				f = [[.28, 0], [.72, 0], [.84, .1], [.78, .17], [.68, .15], [.66, .36], [1, 1], [0, 1], [.34, .36], [.32, .15], [.22, .17], [.16, .1]]
			"uniform":
				f = [[.22, 0], [.78, 0], [1, .18], [.97, .6], [.86, .6], [.86, .9], [.14, .9], [.14, .6], [.03, .6], [0, .18]]
			"robe":
				f = [[.24, 0], [.76, 0], [.96, .2], [1, .52], [.86, .52], [.96, 1], [.04, 1], [.14, .52], [0, .52], [.04, .2]]
			_:
				f = [[.22, 0], [.78, 0], [1, .18], [.92, .3], [.84, .26], [.9, 1], [.1, 1], [.16, .26], [.08, .3], [0, .18]]
		var out := PackedVector2Array()
		for p: Array in f:
			out.append(_at(float(p[0]), float(p[1])))
		return out

	func _at(fx: float, fy: float) -> Vector2:
		return Vector2(W * 0.5 - COS_W * 0.5 + fx * COS_W, COS_TOP + fy * COS_H)

	# 布のしわ（縦の、うすい影）
	func _folds() -> void:
		if cut == "box":
			return
		var shade := Color(0, 0, 0, 0.13)
		var bottom := 0.82 if cut in ["smock", "jacket"] else (0.86 if cut == "uniform" else 0.96)
		for fx: float in [0.36, 0.62]:
			draw_line(_at(fx, 0.34), _at(fx + (fx - 0.5) * 0.25, bottom), shade, 3.0, true)

	# 仕立てごとの印（見て、誰の衣装か分かるように）
	func _extras() -> void:
		var dark := cloth.darkened(0.5)
		match cut:
			"suit":
				# おなかの丸い窓
				draw_circle(_at(0.5, 0.36), 15.0, Color("5b5e63"))
				draw_circle(_at(0.5, 0.36), 11.0, Color("ffd36b"))
				draw_circle(_at(0.46, 0.33), 4.0, Color(1, 1, 1, 0.6))
				draw_line(_at(0.5, 0.06), _at(0.5, 0.26), dark, 2.0, true)
			"smock":
				# 白いえり巻き（片はしが前に垂れる）と、前の合わせ
				draw_line(_at(0.5, 0.04), _at(0.5, 0.84), dark, 1.5, true)
				draw_colored_polygon(PackedVector2Array([_at(0.24, 0.0), _at(0.76, 0.0), _at(0.7, 0.09), _at(0.3, 0.09)]), Color("eee6d4"))
				draw_colored_polygon(PackedVector2Array([_at(0.56, 0.06), _at(0.68, 0.06), _at(0.66, 0.36), _at(0.56, 0.34)]), Color("e3dac6"))
			"box":
				# 段ボールのふた（上に開いた2枚）・腕の穴・テープの継ぎ目
				draw_colored_polygon(PackedVector2Array([_at(0.06, 0.06), _at(0.48, 0.06), _at(0.40, -0.02), _at(0.0, -0.02)]), cloth.darkened(0.12))
				draw_colored_polygon(PackedVector2Array([_at(0.52, 0.06), _at(0.94, 0.06), _at(1.0, -0.02), _at(0.60, -0.02)]), cloth.darkened(0.18))
				draw_circle(_at(0.16, 0.26), 9.0, Color(0.12, 0.08, 0.04))
				draw_circle(_at(0.84, 0.26), 9.0, Color(0.12, 0.08, 0.04))
				draw_line(_at(0.5, 0.06), _at(0.5, 0.72), cloth.darkened(0.25), 2.0, true)
				draw_line(_at(0.06, 0.66), _at(0.94, 0.66), Color(0, 0, 0, 0.12), 2.0, true)
			"jacket":
				# 襟と、胸ポケットの手帳
				draw_polyline(PackedVector2Array([_at(0.36, 0.0), _at(0.5, 0.3), _at(0.64, 0.0)]), dark, 2.5, true)
				draw_colored_polygon(PackedVector2Array([_at(0.5, 0.3), _at(0.44, 0.02), _at(0.56, 0.02)]), Color("b8402f"))
				draw_rect(Rect2(_at(0.62, 0.17), Vector2(18, 24)), Color("5a5c62"))
				draw_rect(Rect2(_at(0.6, 0.24), Vector2(26, 3)), dark)
				for fy: float in [0.42, 0.56]:
					draw_circle(_at(0.47, fy), 2.5, dark)
			"dress":
				# 肩のショール
				draw_colored_polygon(PackedVector2Array([_at(0.18, 0.08), _at(0.82, 0.08), _at(0.74, 0.26), _at(0.5, 0.34), _at(0.26, 0.26)]), Color("f6f0e4"))
				draw_line(_at(0.26, 0.26), _at(0.24, 0.42), Color("f6f0e4"), 4.0, true)
				draw_line(_at(0.74, 0.26), _at(0.77, 0.4), Color("f6f0e4"), 4.0, true)
			"uniform":
				# 毛皮のえり・肩掛けのベルト・金のバッジ・ボタン
				draw_colored_polygon(PackedVector2Array([_at(0.2, 0.0), _at(0.8, 0.0), _at(0.74, 0.1), _at(0.26, 0.1)]), Color("f1ead8"))
				draw_line(_at(0.22, 0.12), _at(0.84, 0.6), Color("3d5a55"), 5.0, true)
				_star(_at(0.32, 0.26), 9.0, Color("e5b23a"))
				for fy: float in [0.2, 0.33, 0.46]:
					draw_circle(_at(0.5, fy), 2.5, Color("c9a24a"))
			"robe":
				# モップの毛（縦の筋・ばらばらの裾）と、肩の黒いマント
				for k in 11:
					var fx := 0.1 + float(k) * 0.08
					draw_line(_at(fx, 0.32 + float(k % 3) * 0.05), _at(fx + (fx - 0.5) * 0.08, 0.97), cloth.darkened(0.22), 2.0, true)
				draw_colored_polygon(PackedVector2Array([_at(0.04, 0.2), _at(0.24, 0.0), _at(0.76, 0.0), _at(0.96, 0.2), _at(0.82, 0.34), _at(0.5, 0.3), _at(0.18, 0.34)]), Color("2b2930"))
				draw_circle(_at(0.5, 0.08), 4.0, Color("e5b23a"))

	# フックに掛けた小物（ベレー帽・王冠）
	func _hook_extra(hc: Vector2) -> void:
		match cut:
			"smock":
				var c := hc + Vector2(-6, 10)
				draw_set_transform(c, -0.25, Vector2(1.0, 0.45))
				draw_circle(Vector2.ZERO, 17.0, Color("1f1f24"))
				draw_set_transform_matrix(Transform2D.IDENTITY)
				draw_line(c + Vector2(-2, -7), c + Vector2(0, -12), Color("1f1f24"), 3.0, true)
			"robe":
				var b := hc + Vector2(-26, 12)
				var crown := PackedVector2Array([b, b + Vector2(4, -14), b + Vector2(10, -6), b + Vector2(15, -16), b + Vector2(20, -6), b + Vector2(26, -14), b + Vector2(30, 0)])
				draw_colored_polygon(crown, Color("e5b23a"))
				draw_circle(b + Vector2(15, -5), 2.5, Color("d75a42"))

	func _star(c: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var ang := -PI * 0.5 + float(i) * PI / 5.0
			pts.append(c + Vector2(cos(ang), sin(ang)) * (r if i % 2 == 0 else r * 0.45))
		draw_colored_polygon(pts, col)

	# マニラ紙の名札（裾から糸で下がる）
	func _tag(pts: PackedVector2Array) -> void:
		var bottom := 0.0
		for p in pts:
			bottom = maxf(bottom, p.y)
		var f := FilmSet.font("marker")
		var px := 17
		var ts := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
		var tw := ts.x + 30.0
		var th := 32.0
		var tilt := deg_to_rad(TILTS[index % TILTS.size()])
		# 名札の左はしの穴に糸を通して、裾から下げる
		var at := Vector2(W * 0.5, bottom + 10.0)
		var hole := Vector2(-tw * 0.5 + 10.0, th * 0.5).rotated(tilt) + at
		draw_line(Vector2(hole.x + 6.0, bottom - 8.0), hole, Color("d8cfb8", 0.8), 1.2, true)
		draw_set_transform(at, tilt, Vector2.ONE)
		var r := Rect2(Vector2(-tw * 0.5, 0), Vector2(tw, th))
		draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
		draw_rect(r, Color("d9b97a"))
		draw_rect(Rect2(r.position, Vector2(tw, 2)), Color(1, 1, 1, 0.18))
		draw_circle(Vector2(-tw * 0.5 + 10.0, th * 0.5), 3.2, Color("6b5130"))
		draw_circle(Vector2(-tw * 0.5 + 10.0, th * 0.5), 1.7, Color("2a1a0c"))
		var base := (th + f.get_ascent(px) - f.get_descent(px)) * 0.5
		draw_string(f, Vector2(-tw * 0.5 + 20.0, base), title, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color("2a1a0c"))
		draw_set_transform_matrix(Transform2D.IDENTITY)


# ---- 姿見：木の枠・小さな脚。ガラスに3Dの姿を映す ----
class Mirror extends Control:
	const FRAME := 14.0
	const FEET := 18.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var body := Rect2(Vector2.ZERO, size - Vector2(0, FEET))
		# 脚
		for x: float in [24.0, size.x - 40.0]:
			draw_rect(Rect2(x, body.end.y - 4.0, 16, FEET + 4.0), Color("4a3220"))
		draw_rect(Rect2(10, size.y - 4.0, size.x - 20, 6), Color(0, 0, 0, 0.35))
		# 影と枠
		draw_rect(Rect2(body.position + Vector2(6, 8), body.size), Color(0, 0, 0, 0.4))
		draw_rect(body, Color("6b4a2e"))
		draw_rect(body.grow(-4.0), Color("8a6440"))
		draw_rect(body.grow(-FRAME + 2.0), Color("4a3220"))
		draw_rect(Rect2(body.position, Vector2(body.size.x, 3)), Color(1, 1, 1, 0.12))


# 鏡の上の、斜めのうすい光
class Sheen extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.55, 0), Vector2(w * 0.8, 0), Vector2(w * 0.2, h), Vector2(0, h), Vector2(0, h * 0.86)]), Color(1, 1, 1, 0.05))
		draw_colored_polygon(PackedVector2Array([Vector2(w * 0.86, 0), Vector2(w * 0.92, 0), Vector2(w * 0.34, h), Vector2(w * 0.28, h)]), Color(1, 1, 1, 0.04))
