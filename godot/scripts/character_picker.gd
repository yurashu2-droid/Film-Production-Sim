extends Control
## キャラクター選び＝タンスに吊るした7人（2026-11-23 作り替え。ユーザーの見本の絵と「絵ではなく 3D モデルを吊るして、カーソルで揺らす」）。
##   ・画面いっぱいに 3D のタンス（ui/wardrobe_3d.gd）。棒に、キャラの数だけハンガー。ゲームのモデルから生身（肌・顔・髪）を抜いた
##     服と持ち物が、紐で吊ってある（ui/hanging_cast.gd・ui/cast_strip.gd）
##   ・マウスを乗せると、その人が揺れて、手前に出て、光が当たる（＝選んでいる）。押すと決まる。閉じるのは「戻る」・Esc・右クリック
##   ・下に、名前と特技を書いた白い紙
## 前の形（〜2026-11-23）：暗い衣装部屋の壁に 2D のハンガーラック。衣装は多角形 → 生成したフェルトの絵（a761563）。姿見に 3D の姿。
## 3D の中身は、初めて開いた時に作る（7人ぶんの絵を抜く計算があるので、起動の時にはやらない）。
## production_hud.gd が、この画面の直下の PanelContainer を紙（テープ留め）に塗り替えるので、直下には PanelContainer を置かない
const UI := preload("res://scripts/ui/ui_theme.gd")
const Talents := preload("res://scripts/cast_talents.gd")
const Hanging := preload("res://scripts/ui/hanging_cast.gd")
const Wardrobe := preload("res://scripts/ui/wardrobe_3d.gd")

const STAGE_SIZE := Vector2(1600, 900)
const INK := Color("1d1a14")
const INNER_W := 7.4                  # タンスの中の幅（m）
const INNER_H := 2.7
const SPREAD := 3.0                   # いちばん左・右のハンガーの位置（まん中から）
const SEEN_W := 9.1                   # 画面の横に収める幅（戸の開きまで）
const CAM_Y := -0.55                  # カメラの高さ（タンスを画面の上へ寄せて、下に紙を置く）
const BACKDROP := Color("7b9886")

var game: Node
var selected := 0
var view: SubViewport
var camera: Camera3D
var hangers: Array[Node3D] = []
# 選んでいるキャラの特技（名前・準備中の札・説明）
var _talent_name: Label
var _talent_wait: Control
var _talent_desc: Label
var _talent_parts: Array[Control] = []     # 特技まわりの部品。特技の無いモード（撮影だけモード）では隠す
var _stage: Control
var _name: Label
var _world: Node3D
var _spot: SpotLight3D
var _holder: SubViewportContainer


func build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_holder = SubViewportContainer.new()
	_holder.stretch = true
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_holder)
	view = SubViewport.new()
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.msaa_3d = Viewport.MSAA_2X
	_holder.add_child(view)
	_stage = Control.new()
	_stage.size = STAGE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_build_card()
	_build_controls()
	resized.connect(_fit)
	_fit()
	set_process(false)
	hide()


# タンスと7人（初めて開いた時に1回だけ）
func _build_world() -> void:
	_world = Node3D.new()
	view.add_child(_world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = BACKDROP
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.96, 0.88)
	e.ambient_light_energy = 0.62
	env.environment = e
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, 18, 0)
	sun.light_energy = 0.62
	sun.light_color = Color(1.0, 0.95, 0.84)
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	_world.add_child(sun)
	var wardrobe := Wardrobe.new()
	_world.add_child(wardrobe)
	wardrobe.build(INNER_W, INNER_H)
	var count: int = game.PLAYER_CASTS.size()
	for i in count:
		var h := Hanging.new()
		_world.add_child(h)
		var x := 0.0 if count <= 1 else lerpf(-SPREAD, SPREAD, float(i) / float(count - 1))
		h.position = Vector3(x, wardrobe.rail_y, 0)
		h.setup(game.PLAYER_CASTS[i], i)
		hangers.append(h)
	_spot = SpotLight3D.new()
	_spot.position = Vector3(0, 1.9, 3.0)
	_spot.rotation_degrees = Vector3(-36, 0, 0)
	_spot.spot_angle = 13
	_spot.spot_angle_attenuation = 2.0
	_spot.light_color = Color(1.0, 0.9, 0.66)
	_spot.light_energy = 2.6
	_spot.spot_range = 7.0
	_world.add_child(_spot)
	camera = Camera3D.new()
	camera.fov = 34
	_world.add_child(camera)
	camera.current = true
	_aim()


# タンスの横幅が画面に収まる距離へ、カメラを置く（画面の縦横の比が変わっても、戸まで入る）
func _aim() -> void:
	if camera == null or size.y <= 0.0:
		return
	var aspect := size.x / size.y
	var half := tan(deg_to_rad(camera.fov * 0.5)) * aspect
	camera.position = Vector3(0, CAM_Y, SEEN_W * 0.5 / half)


# 下のまん中の白い紙：名前と特技
func _build_card() -> void:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = Vector2(420, 690)
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
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
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


# 右下：戻る（決めるのは、吊るしたキャラを押す）
func _build_controls() -> void:
	var cancel := Button.new()
	cancel.text = "戻る"
	cancel.focus_mode = Control.FOCUS_NONE
	FilmSet.style_sign_button(cancel, "cream", 22, 50)
	cancel.custom_minimum_size.x = 130
	cancel.pressed.connect(func(): game.set_character_menu(false))
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.position = Vector2(1300, 790)
	_stage.add_child(slot)
	slot.add_child(cancel)
	cancel.reset_size()
	cancel.pivot_offset = cancel.size * 0.5
	cancel.rotation = deg_to_rad(1.5)


# 1600x900 の舞台（紙とボタン）を、画面に収まる大きさに縮めて、まん中に置く
func _fit() -> void:
	if _stage == null:
		return
	var s := minf(size.x / STAGE_SIZE.x, size.y / STAGE_SIZE.y)
	if s <= 0.0:
		return
	_stage.scale = Vector2(s, s)
	_stage.position = ((size - STAGE_SIZE * s) * 0.5).floor()
	_aim()


func _process(delta: float) -> void:
	var k := 1.0 - exp(-delta * 9.0)
	for i in hangers.size():
		hangers[i].pull = lerpf(hangers[i].pull, 1.0 if i == selected else 0.0, k)
	if _spot != null and selected < hangers.size():
		_spot.position.x = lerpf(_spot.position.x, hangers[selected].position.x, 1.0 - exp(-delta * 10.0))


func set_open(on: bool) -> void:
	if on and _world == null:
		_build_world()
	visible = on
	set_process(on)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if _world != null:
		_world.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if on:
		_fit()
		# 特技は制作モードだけ（game.talent がある）。無いモードでは欄ごと隠す
		for part: Control in _talent_parts:
			part.visible = game.get("talent") != null
		var me: Node = game.local_player()
		choose(game.PLAYER_CASTS.find(me.vis.tag))
		# 開いたときは、引き出しの途中から始めない
		for i in hangers.size():
			hangers[i].pull = 1.0 if i == selected else 0.0
		_spot.position.x = hangers[selected].position.x


func choose(index: int) -> void:
	selected = posmod(index, game.PLAYER_CASTS.size())
	var picked: String = game.PLAYER_CASTS[selected]
	_name.text = game.PLAYER_NAMES[selected]
	_talent_name.text = Talents.title(picked)
	_talent_wait.visible = not Talents.ready(picked)
	_talent_desc.text = Talents.describe(picked) + ("" if Talents.ready(picked) else "\n（準備中。まだ使えない）")


func confirm() -> void:
	game.h_select_cast.rpc_id(1, selected)
	game.set_character_menu(false)


# マウス：乗せた人が揺れて、選ばれる。押すと決まる。右クリックで閉じる
func _gui_input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventMouseMotion:
		var over := _hover(event.position, event.velocity)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over >= 0 else Control.CURSOR_ARROW
		if over >= 0 and over != selected:
			choose(over)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			game.set_character_menu(false)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var over := _hover(event.position, Vector2.ZERO)
			if over >= 0:
				choose(over)
				confirm()
		accept_event()


# カーソルの下のキャラの番号（いなければ -1）。乗った瞬間に、その人を揺らす
func _hover(at: Vector2, velocity: Vector2) -> int:
	var found := -1
	for i in hangers.size():
		if hangers[i].hover(camera, at, velocity) and found < 0:
			found = i
	return found


func handle_key(key: int) -> void:
	match key:
		KEY_UP, KEY_LEFT: _step(-1)
		KEY_DOWN, KEY_RIGHT: _step(1)
		KEY_ENTER, KEY_KP_ENTER: confirm()
		KEY_ESCAPE, KEY_C: game.set_character_menu(false)


func _step(dir: int) -> void:
	choose(selected + dir)
	if selected < hangers.size():
		hangers[selected].push(0.9 * float(dir))
