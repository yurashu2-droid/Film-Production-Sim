extends CanvasLayer
# 取り込み済みの演技と舞台効果を、本編の制作班が呼び出す操作盤。
const UI := preload("res://scripts/ui/ui_theme.gd")
const SkillPanel := preload("res://scripts/crew_skills_panel.gd")
const Reactions := preload("res://scripts/crew_reactions.gd")
const EFFECTS := {
	"fireball": ["火の弾", "res://vfx/vfx_projectile.gd"],
	"magicball": ["魔法の弾", "res://vfx/vfx_projectile.gd"],
	"petals": ["花びら", "res://pixel_vfx/px_petals.gd"],
	"fire": ["炎", "res://vfx/vfx_fire.gd"],
	"smoke": ["煙幕", "res://vfx/vfx_smoke.gd"],
	"explosion": ["撮影用の爆炎", "res://vfx/vfx_explosion.gd"],
	"lightning": ["落雷", "res://vfx/vfx_lightning.gd"],
	"aura": ["気合のオーラ", "res://vfx/vfx_aura.gd"],
	"brawl": ["乱闘の煙", "res://vfx/vfx_brawl.gd"],
	"slam": ["地面への衝撃", "res://vfx/vfx_slam.gd"],
	"tornado": ["竜巻", "res://vfx/vfx_tornado.gd"],
	"ink_splash": ["インク飛沫", "res://vfx/vfx_ink.gd"],
	"ink_dragon": ["墨の竜", "res://vfx/vfx_ink_dragon.gd"],
	"water_wave": ["大波", "res://vfx/vfx_water_wave.gd"],
	"black_flash": ["黒い打撃", "res://vfx/vfx_black_flash.gd"],
}
const ACTION_NAMES := {
	"ACTION":"決めポーズ", "POSE":"決めポーズ", "GREETING":"あいさつ", "NOTES":"手帳の演技", "ON_DUTY":"警官の演技", "ORDER":"王様の演技",
	"slate":"合図する", "flinch":"のけぞる", "draw":"取り出す", "stow":"しまう", "periscope":"見渡す", "wave":"手を振る", "hide":"隠れる",
	"hat":"帽子を使う", "memo":"メモする", "curtsy":"おじぎ", "rose":"花を差し出す", "halt":"止まれ！", "ticket":"切符を切る",
	"gavel":"裁きを下す", "shake":"振り回す", "clap":"拍手", "spin":"回転", "drift_in":"滑り込む",
	"skill_double_flinch":"二度びっくり", "skill_slow_flinch":"大げさなのけぞり",
}
const FACES := {"happy":"うれしい", "angry":"怒る", "sad":"悲しい", "surprised":"びっくり", "shock":"衝撃", "neutral":"ふつう"}
const FX_COOLDOWN := 1.5
const MAX_FX_PER_PLAYER := 2

var game: Node
var opened := false
var actions: Array[String] = []
var selected_animation := ""
var selected_effect := "fireball"
var fx_root: Node3D
var _last_fx: Dictionary = {}
var _last_act: Dictionary = {}
var _tag := ""
var _root: Control
var _sheet: Control
var _hint: Label
var _acting: OptionButton
var _effects: OptionButton
var _tabs: TabContainer
var skill_panel: VBoxContainer
var _restore_mouse_mode := Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	layer = 4
	fx_root = Node3D.new()
	fx_root.name = "StageEffects"
	game.add_child(fx_root)
	_build_ui()
	refresh_actions()

func allowed() -> bool:
	return game.production != null and game.production.phase in [0,2,4] and game.state in [game.S.PREP,game.S.COUNTDOWN,game.S.TAKE] and not game.replaying and not game.production.expired

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UI.make_theme(18)
	add_child(_root)
	_hint = UI.label("", 16, UI.CLAP_WHITE)
	_hint.position = Vector2(24, 300)
	_root.add_child(_hint)
	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_sheet)
	var dim := ColorRect.new()
	dim.color = Color(0,0,0,0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.add_child(center)
	var panel := UI.panel("slate", 0, true, 28, 24)
	panel.custom_minimum_size.x = 700
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	panel.add_child(rows)
	rows.add_child(UI.label("演技とスタッフスキル", 28, UI.CLAP_WHITE, "display"))
	rows.add_child(UI.label("撮影中も借り時間は進む。選んだら現場へ戻ろう。", 16, UI.MUTED))
	rows.add_child(UI.hairline())
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(640, 430)
	rows.add_child(_tabs)
	var acting_rows := VBoxContainer.new()
	acting_rows.name = "演技"
	acting_rows.add_theme_constant_override("separation", 16)
	_tabs.add_child(acting_rows)
	acting_rows.add_child(UI.label("演技・表情　Zで実行", 20, UI.CLAP_WHITE, "bold"))
	_acting = OptionButton.new()
	_acting.custom_minimum_size = Vector2(640,44)
	acting_rows.add_child(_acting)
	_acting.item_selected.connect(func(i: int): selected_animation = actions[i]; _update_hint())
	var act_button := _button("この演技で現場へ戻る [Z]", func(): set_open(false); request_act())
	acting_rows.add_child(act_button)
	acting_rows.add_child(UI.label("動くと演技を中断。表情は道具を持ったまま使える。", 16, UI.MUTED))
	acting_rows.add_child(UI.label("演者Lv2で追加リアクション。走りの演出はスタッフスキルから。", 16, UI.MUTED))
	var effects_rows := VBoxContainer.new()
	effects_rows.name = "舞台効果"
	effects_rows.add_theme_constant_override("separation", 16)
	_tabs.add_child(effects_rows)
	effects_rows.add_child(UI.label("舞台効果　Xで発動", 20, UI.CLAP_WHITE, "bold"))
	_effects = OptionButton.new()
	_effects.custom_minimum_size = Vector2(640,44)
	for id: String in EFFECTS:
		_effects.add_item(EFFECTS[id][0])
		_effects.set_item_metadata(_effects.item_count-1,id)
	_effects.item_selected.connect(func(i: int): selected_effect = _effects.get_item_metadata(i); _update_hint())
	effects_rows.add_child(_effects)
	effects_rows.add_child(_button("この効果で現場へ戻る [X]", func(): set_open(false); request_fx()))
	effects_rows.add_child(UI.label("照準先へ発生。オーラは足元。爆発の場面は合図2で撮る。", 16, UI.MUTED))
	var skill_scroll := ScrollContainer.new()
	skill_scroll.name = "スタッフスキル"
	skill_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(skill_scroll)
	skill_panel = SkillPanel.new()
	skill_scroll.add_child(skill_panel)
	skill_panel.build(game)
	rows.add_child(_button("現場へ戻る [H / Esc]", func(): set_open(false)))
	_sheet.visible = false

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	UI.style_button(button,"slate",18,40)
	button.pressed.connect(action)
	return button

func refresh_actions() -> void:
	var player: Node = game.local_player()
	if player == null:
		return
	_tag = player.vis.tag
	Reactions.ensure(player.vis)
	actions.clear()
	_acting.clear()
	for clip: String in player.vis.anim.get_animation_list():
		var id := clip.trim_prefix(_tag + "_")
		if not ACTION_NAMES.has(id):
			continue
		if Reactions.NAMES.has(id) and (game.crew_skills == null or game.crew_skills.level(Net.my_id(), "actor") < 2):
			continue
		actions.append(id)
		_acting.add_item(ACTION_NAMES[id])
	for face: String in FACES:
		if player.vis.face_anim and player.vis.face_anim.has_animation(face):
			actions.append("face:"+face)
			_acting.add_item("表情："+FACES[face])
	if selected_animation not in actions:
		selected_animation = actions[0] if not actions.is_empty() else ""
	_acting.select(actions.find(selected_animation))
	_update_hint()

func _update_hint() -> void:
	var act_name: String = FACES.get(selected_animation.trim_prefix("face:"), "") if selected_animation.begins_with("face:") else ACTION_NAMES.get(selected_animation,"")
	_hint.text = "Z 演技：%s\nX 効果：%s\nH 選ぶ ／ Ctrl しゃがむ" % [act_name,EFFECTS[selected_effect][0]]

func set_open(on: bool) -> void:
	if on == opened:
		return
	if on:
		if not allowed() or game.ui_blocking():
			return
		refresh_actions()
		_restore_mouse_mode = Input.mouse_mode
	opened = on
	_sheet.visible = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif allowed() and not game.ui_blocking():
		Input.mouse_mode = _restore_mouse_mode

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var code: int = event.physical_keycode
	if code == KEY_H or (opened and code == KEY_ESCAPE):
		set_open(not opened if code == KEY_H else false)
		get_viewport().set_input_as_handled()
		return
	if opened:
		if code in [KEY_Z,KEY_X]:
			set_open(false)
			if code == KEY_Z:
				request_act()
			else:
				request_fx()
		elif code in [KEY_C,KEY_TAB]:
			set_open(false)
			return
		get_viewport().set_input_as_handled()
		return
	if not allowed() or game.ui_blocking():
		return
	if code == KEY_Z:
		request_act()
		get_viewport().set_input_as_handled()
	elif code == KEY_X:
		request_fx()
		get_viewport().set_input_as_handled()

func request_act() -> void:
	game.h_perform.rpc_id(1,selected_animation)

func request_fx() -> void:
	var player: Node = game.local_player()
	if player == null:
		return
	var camera: Camera3D = game.film.view_cam if player.operating == game.film.pid else player.cam
	game.h_stage_fx.rpc_id(1,selected_effect,camera.global_position,-camera.global_basis.z)

func accept_act(who: int, clip: String) -> void:
	var player: Node = game.players.get(who)
	if not allowed() or player == null or (who == Net.my_id() and game.ui_blocking()):
		return
	if Reactions.NAMES.has(clip):
		if game.crew_skills == null or game.crew_skills.level(who, "actor") < 2: return
		Reactions.ensure(player.vis)
	var face := clip.begins_with("face:")
	if face:
		if not FACES.has(clip.trim_prefix("face:")):
			return
	elif not ACTION_NAMES.has(clip) or not player.vis.has(clip):
		return
	elif player.held != 0 or player.operating != 0:
		game.ev.rpc_id(who,"toast",["演技するときは道具を置いて、機材操作を終えよう",0])
		return
	var now := Time.get_ticks_msec()/1000.0
	if now - float(_last_act.get(who,-10.0)) < 0.3:
		return
	_last_act[who] = now
	game.host_ev("perform",[who,clip])

func accept_fx(who: int, id: String, ray_origin: Vector3, ray_direction: Vector3) -> void:
	var player: Node = game.players.get(who)
	if not allowed() or player == null or not EFFECTS.has(id) or (who == Net.my_id() and game.ui_blocking()):
		return
	var eye: Vector3 = game.film.lens.global_position if player.operating == game.film.pid else player.global_position+Vector3(0,1.85,0)
	# テストやホスト側からの直接呼び出しはプレイヤーの向きを使う。
	if ray_direction == Vector3.ZERO:
		ray_origin = eye
		ray_direction = player.aim_forward()
	if not ray_origin.is_finite() or not ray_direction.is_finite() or eye.distance_to(ray_origin) > 6.0 or ray_direction.length_squared() < 0.9 or ray_direction.length_squared() > 1.1:
		return
	var now := Time.get_ticks_msec()/1000.0
	if now - float(_last_fx.get(who,-10.0)) < FX_COOLDOWN:
		return
	var count := 0
	for effect in fx_root.get_children():
		if not effect.is_queued_for_deletion() and effect.get_meta("performer",0) == who:
			count += 1
	if count >= MAX_FX_PER_PLAYER:
		game.ev.rpc_id(who,"toast",["いまの効果が終わってから、次の演出を出そう",0])
		return
	_last_fx[who] = now
	var source: Vector3 = player.global_position + Vector3(0,1.1,0) + player.flat_forward()*0.6
	var target: Vector3 = ray_origin + ray_direction.normalized()*12.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin,target,1|2|4|16)
	if player.held != 0 and game.props.has(player.held):
		query.exclude = [game.props[player.held].get_rid()]
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = hit.position
	var ground: Vector3 = player.global_position + player.flat_forward()*3.0 if hit.is_empty() else target
	query = PhysicsRayQueryParameters3D.create(ground+Vector3.UP*3,ground-Vector3.UP*12,1)
	hit = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		ground = hit.position
	if id == "aura":
		ground = player.global_position
	game.host_ev("stage_fx",[who,id,source,target,ground,ray_direction.normalized()])

func show_effect(data: Array) -> void:
	var id: String = data[1]
	if not EFFECTS.has(id):
		return
	var script: GDScript = load(EFFECTS[id][1])
	var effect: Node3D
	var ground: Vector3 = data[4]
	match id:
		"fireball", "magicball":
			effect = script.fire(fx_root,data[2],data[3],{"palette":"fire" if id == "fireball" else "arcane", "size":0.7})
		"fire": effect = script.spawn(fx_root,ground,1.0,2.0)
		"smoke": effect = script.spawn(fx_root,ground+Vector3.UP*0.3,1.0,1.5)
		"explosion": effect = script.spawn(fx_root,ground+Vector3.UP*0.6,1.6,1.25,false)
		"lightning": effect = script.strike(fx_root,ground,0.8,6.0)
		"aura": effect = script.spawn(fx_root,ground,0.8,2.0)
		"tornado": effect = script.spawn(fx_root,ground,0.7,2.0)
		"ink_splash": effect = script.spawn(fx_root,ground,"splash",0.8,"orange")
		"black_flash": effect = script.spawn(fx_root,ground+Vector3.UP,0.7,data[5],1.0)
		_: effect = script.spawn(fx_root,ground,0.8)
	effect.set_meta("performer",data[0])
	effect.set_meta("effect_id",id)
	if id in ["ink_dragon","water_wave"]:
		effect.rotation.y = atan2(-data[5].x,-data[5].z)

func clear_effects() -> void:
	for effect in fx_root.get_children():
		effect.queue_free()

func state_changed() -> void:
	clear_effects()
	if not allowed():
		set_open(false)
	for player: Node in game.players.values():
		player.cancel_performance()

func _process(_delta: float) -> void:
	_tabs.custom_minimum_size.y = clampf(get_viewport().get_visible_rect().size.y - 230.0, 220.0, 490.0)
	var player: Node = game.local_player()
	if player and player.vis.tag != _tag:
		refresh_actions()
	if opened and (not allowed() or game.character_open or game.help_open):
		set_open(false)
	_hint.visible = allowed() and not game.ui_blocking() and (game.production == null or game.production.phase == 4)
