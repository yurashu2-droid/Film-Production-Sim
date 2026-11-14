extends VBoxContainer
const UI := preload("res://scripts/ui/ui_theme.gd")
const Profile := preload("res://scripts/crew_profile.gd")
const Workshop := preload("res://scripts/crew_workshop.gd")

var game: Node
var labels := {}
var bars := {}
var running: OptionButton
var recipes: OptionButton
var craft_button: Button
var memo_buttons: Array[Button] = []
var status: Label
var _tick := 0.0

func build(owner_game: Node) -> void:
	game = owner_game
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	for role: String in Profile.ROLES:
		var label := UI.label("", 17, UI.CLAP_WHITE, "bold")
		labels[role] = label
		add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size.y = 8
		bar.show_percentage = false
		bars[role] = bar
		add_child(bar)
	add_child(UI.hairline())
	add_child(UI.label("走りの演出　演者Lv2で5種類を解放", 17, UI.CLAP_WHITE, "bold"))
	running = OptionButton.new()
	running.custom_minimum_size.y = 38
	for id: String in Profile.RUN_STYLES:
		running.add_item(Profile.RUN_STYLES[id])
		running.set_item_metadata(running.item_count - 1, id)
	running.item_selected.connect(func(index: int): game.crew_skills.choose_run_style.rpc_id(1, running.get_item_metadata(index)))
	add_child(running)
	add_child(UI.label("選んだ演出は走り出し・走行中に出ます。仲間と撮影映像にも反映。", 14, UI.MUTED))
	add_child(UI.hairline())
	add_child(UI.label("構図メモ　撮影Lv2・カメラ操作中に使う", 17, UI.CLAP_WHITE, "bold"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for slot in 2:
		for restore: bool in [false, true]:
			var button := _button("%dを%s" % [slot + 1, "戻す" if restore else "記憶"])
			button.pressed.connect(func(): game.crew_skills.camera_memo.rpc_id(1, slot, restore))
			row.add_child(button)
			memo_buttons.append(button)
	add_child(UI.label("カメラの向きとズームを記憶。位置は自分で合わせます。", 14, UI.MUTED))
	add_child(UI.hairline())
	add_child(UI.label("段ボール工作　裏方Lv2・準備中に段ボールを持つ", 17, UI.CLAP_WHITE, "bold"))
	var craft_row := HBoxContainer.new()
	craft_row.add_theme_constant_override("separation", 8)
	add_child(craft_row)
	recipes = OptionButton.new()
	recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id: String in Workshop.RECIPES:
		recipes.add_item(Workshop.RECIPES[id])
		recipes.set_item_metadata(recipes.item_count - 1, id)
	craft_row.add_child(recipes)
	craft_button = _button("絵柄を貼る")
	craft_button.pressed.connect(func(): game.crew_skills.craft.rpc_id(1, recipes.get_item_metadata(recipes.selected)))
	craft_row.add_child(craft_button)
	add_child(UI.label("窓の絵は街の模型に。工作した段ボールは仲間も運んで使えます。", 14, UI.MUTED))
	status = UI.label("", 14, UI.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	refresh()

func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_button(button, "slate", 16, 36)
	return button

func refresh() -> void:
	if game == null or game.crew_skills == null: return
	var skills: Node = game.crew_skills
	for role: String in Profile.ROLES:
		var total: int = skills.profile.xp[role]
		var level := Profile.level_for(total)
		var next: int = Profile.THRESHOLDS[level] if level < 5 else total
		labels[role].text = "%s  Lv%d  %d%s XP　%s" % [Profile.NAMES[role], level, total, " / %d" % next if level < 5 else "", "Lv2解放済み" if level >= 2 else "Lv2まであと%d" % (60 - total)]
		bars[role].max_value = maxi(1, next - Profile.THRESHOLDS[level - 1])
		bars[role].value = total - Profile.THRESHOLDS[level - 1] if level < 5 else bars[role].max_value
	for index in running.item_count:
		var id: String = running.get_item_metadata(index)
		var unlocked := Profile.allowed_style(id, skills.profile.xp.actor)
		running.set_item_disabled(index, not unlocked)
		running.set_item_text(index, Profile.RUN_STYLES[id] + ("" if unlocked else "（演者Lv2）"))
		if id == skills.run_style(Net.my_id()): running.select(index)
	var me: Node = game.local_player()
	var camera: Node = game.props.get(me.operating) if me != null else null
	var camera_ok: bool = skills.profile.level("camera") >= 2 and camera != null and camera.kind == "camera" and game.production.phase in [2,4]
	for index in memo_buttons.size():
		memo_buttons[index].disabled = not camera_ok or (index % 2 == 1 and skills.camera_memos[index / 2].is_empty())
	var prop: Node = game.props.get(me.held) if me != null else null
	craft_button.disabled = skills.profile.level("backstage") < 2 or prop == null or prop.kind != "carton" or game.state != game.S.PREP or game.production.phase not in [2,4]
	status.text = "各仕事は一本につき一度だけ加算。NGも経験になり、納品時に保存します。"
	if not skills.save_error.is_empty(): status.text = skills.save_error

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.25 and is_visible_in_tree():
		_tick = 0.0
		refresh()
