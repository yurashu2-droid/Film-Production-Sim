extends Control
# Independent buyer-facing demo. No game autoloads or vfx/ resources.
const Pack := preload("res://pixel_vfx/pack50/px50.gd")
const Catalog := preload("res://pixel_vfx/pack50/px50_catalog.gd")
var _world: Node3D
var _camera: Camera3D
var _effect: Node3D
var _category: OptionButton
var _presets: OptionButton
var _size: SpinBox
var _speed: HSlider
var _speed_label: Label
var _loop: CheckButton
var _description: Label
var _exit: Label
var _state: Label
var _progress: ProgressBar
var _visible_rows: Array[Dictionary] = []
var _selected_id := "px50_astral_gate"
var _running := false

func _ready() -> void:
 var theme_pack := Theme.new()
 theme_pack.default_font_size = 16
 theme = theme_pack
 var back := ColorRect.new()
 back.color = Color("101923")
 back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(back)
 var margin := MarginContainer.new()
 margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for side in ["left","top","right","bottom"]:
  margin.add_theme_constant_override("margin_"+side,20)
 add_child(margin)
 var layout := HBoxContainer.new()
 layout.add_theme_constant_override("separation",22)
 margin.add_child(layout)
 var panel := VBoxContainer.new()
 panel.custom_minimum_size.x = 315
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 panel.add_theme_constant_override("separation",12)
 var sidebar := ScrollContainer.new()
 sidebar.custom_minimum_size.x = 350
 sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
 sidebar.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 layout.add_child(sidebar)
 sidebar.add_child(panel)
 _label(panel,"PIXEL × REAL",27,Color("78d6e4"))
 _label(panel,"53 VFX / GODOT 4",15,Color("a8b9c8"))
 _label(panel,"演出・装飾の量",16)
 _category = OptionButton.new()
 for title in ["すべて / 53","大 / 多","中 / 標準","小 / 簡潔","ポータル系統","アクション","エレメント","接触・補助","追加オリジナル / 3"]:
  _category.add_item(title)
 panel.add_child(_category)
 _category.select(4)
 _category.item_selected.connect(_filter)
 _label(panel,"プリセット",16)
 _presets = OptionButton.new()
 _presets.custom_minimum_size.y = 40
 panel.add_child(_presets)
 _presets.item_selected.connect(_choose)
 var size_row := HBoxContainer.new()
 panel.add_child(size_row)
 _label(size_row,"表示倍率",16).size_flags_horizontal = Control.SIZE_EXPAND_FILL
 _size = SpinBox.new()
 _size.min_value = 0.25
 _size.max_value = 3.0
 _size.step = 0.05
 _size.value = 1.0
 _size.custom_minimum_size.x = 130
 size_row.add_child(_size)
 _size.value_changed.connect(_resize_effect)
 _speed_label = _label(panel,"速度 1.00×",16)
 _speed = HSlider.new()
 _speed.min_value = 0.0
 _speed.max_value = 2.0
 _speed.step = 0.05
 _speed.value = 1.0
 _speed.custom_minimum_size.y = 26
 panel.add_child(_speed)
 _speed.value_changed.connect(_change_speed)
 _loop = CheckButton.new()
 _loop.text = "ループ再生"
 _loop.button_pressed = true
 panel.add_child(_loop)
 _loop.toggled.connect(_change_loop)
 var buttons := HBoxContainer.new()
 panel.add_child(buttons)
 for title in ["再生 / やり直す","停止"]:
  var button := Button.new()
  button.text = title
  button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  button.custom_minimum_size.y = 42
  buttons.add_child(button)
  button.pressed.connect(_play if title.begins_with("再生") else _stop)
 _progress = ProgressBar.new()
 _progress.show_percentage = false
 _progress.max_value = 1.0
 _progress.custom_minimum_size.y = 7
 panel.add_child(_progress)
 _state = _label(panel,"",14,Color("a8b9c8"))
 _description = _label(panel,"",15)
 _description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 _exit = _label(panel,"",14,Color("a8b9c8"))
 _exit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var spacer := Control.new()
 spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
 panel.add_child(spacer)
 var footer := _label(panel,"速度0 = 一時停止\n白い人形 = 1.7m / 格子 = 1m\n左ドラッグ = 回転 / ホイール = 距離",13,Color("7f96a9"))
 footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 var stage := SubViewportContainer.new()
 stage.stretch = true
 stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
 layout.add_child(stage)
 var viewport := SubViewport.new()
 viewport.size = Vector2i(900,680)
 viewport.own_world_3d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
 stage.add_child(viewport)
 stage.gui_input.connect(_orbit)
 _world = Node3D.new()
 viewport.add_child(_world)
 _studio()
 _filter(4)

func _label(parent: Node, words: String, font_size: int, color: Color = Color("e4edf5")) -> Label:
 var label := Label.new()
 label.text = words
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",color)
 parent.add_child(label)
 return label

func _studio() -> void:
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color("17232d")
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color("b5c8da")
 env.ambient_light_energy = 0.35
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 env.tonemap_white = 6.0
 env.glow_enabled = true
 env.glow_intensity = 0.3
 env.glow_hdr_threshold = 1.6
 var atmosphere := WorldEnvironment.new()
 atmosphere.environment = env
 _world.add_child(atmosphere)
 var key := DirectionalLight3D.new()
 key.rotation_degrees = Vector3(-58,32,0)
 key.light_energy = 0.8
 _world.add_child(key)
 var floor_node := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(50,50)
 floor_node.mesh = plane
 var floor_mat := StandardMaterial3D.new()
 floor_mat.albedo_color = Color("454b50")
 floor_mat.roughness = 1.0
 floor_node.material_override = floor_mat
 _world.add_child(floor_node)
 var grid := ImmediateMesh.new()
 grid.surface_begin(Mesh.PRIMITIVE_LINES)
 for i in range(-12,13):
  grid.surface_add_vertex(Vector3(i,0.006,-12))
  grid.surface_add_vertex(Vector3(i,0.006,12))
  grid.surface_add_vertex(Vector3(-12,0.006,i))
  grid.surface_add_vertex(Vector3(12,0.006,i))
 grid.surface_end()
 var lines := MeshInstance3D.new()
 lines.mesh = grid
 var grid_mat := StandardMaterial3D.new()
 grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 grid_mat.albedo_color = Color("57616a")
 lines.material_override = grid_mat
 _world.add_child(lines)
 var person := MeshInstance3D.new()
 var capsule := CapsuleMesh.new()
 capsule.radius = 0.23
 capsule.height = 1.7
 person.mesh = capsule
 person.position = Vector3(-3.0,0.85,-0.5)
 _world.add_child(person)
 _camera = Camera3D.new()
 _camera.fov = 50
 _camera.current = true
 _world.add_child(_camera)

var _yaw := 0.5
var _pitch := 0.22
var _distance := 9.0
var _focus := Vector3(0,1.6,0)

func _frame_camera(row: Dictionary) -> void:
 _yaw = 0.5
 _pitch = 0.42 if row["variant"] in ["summon_well","return_mark"] else 0.22
 _distance = float(row.get("dist",7.0))*maxf(_size.value,0.65)
 _focus = Vector3(0,float(row["focus_height"])*_size.value,0)
 _pose_camera()

func _pose_camera() -> void:
 _camera.position = _focus+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*_distance
 _camera.look_at(_focus)

func _orbit(event: InputEvent) -> void:
 if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
  _yaw -= event.relative.x*0.008
  _pitch = clampf(_pitch+event.relative.y*0.006,-0.12,1.25)
  _pose_camera()
 elif event is InputEventMouseButton and event.pressed:
  if event.button_index == MOUSE_BUTTON_WHEEL_UP: _distance = maxf(_distance*0.90,1.2)
  elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _distance = minf(_distance*1.10,32.0)
  else: return
  _pose_camera()

func _filter(index: int) -> void:
 _visible_rows.clear()
 _presets.clear()
 var families := ["portals","action","elements","micro"]
 for raw: Dictionary in Catalog.ROWS:
  if index in [1,2,3] and raw["complexity_class"] != ["L","M","S"][index-1]: continue
  if index==4 and raw["family"] not in ["portals","constellation_loom"]: continue
  if index in [5,6,7] and raw["family"] != families[index-4]: continue
  if index==8 and int(raw["number"])<=50: continue
  _visible_rows.append(raw)
  _presets.add_item("%02d  %s" % [int(raw["number"]),raw["name"]])
 var selected := 0
 for i in _visible_rows.size():
  if _visible_rows[i]["id"] == _selected_id: selected = i
 _presets.select(selected)
 _choose(selected)

func _choose(index: int) -> void:
 var row := _visible_rows[index]
 _selected_id = row["id"]
 _description.text = row["description"]+"\n\n区分理由: "+row["tier_reason"]
 _exit.text = "終わり: "+row["exit"]
 _frame_camera(row)
 _play()

func _play() -> void:
 _stop()
 _effect = Pack.spawn(_world,Vector3.ZERO,_selected_id,{"size":_size.value,"speed":_speed.value,"loop":_loop.button_pressed})
 _effect.free_on_finish = false
 _running = true

func _stop() -> void:
 _running = false
 if is_instance_valid(_effect):
  _effect.stop()
  _effect.queue_free()
 _effect = null
 if is_instance_valid(_state): _state.text = "停止中"
 if is_instance_valid(_progress): _progress.value = 0.0

func _resize_effect(_value: float) -> void:
 if _visible_rows.is_empty(): return
 _frame_camera(_visible_rows[_presets.selected])
 if _running: _play()

func _change_speed(value: float) -> void:
 _speed_label.text = "速度 %.2f×" % value
 if is_instance_valid(_effect): _effect.playback_speed = value

func _change_loop(value: bool) -> void:
 if not is_instance_valid(_effect): return
 _effect.loop = value
 if value and _effect.age>=_effect.life: _play()

func _process(_delta: float) -> void:
 if not _running or not is_instance_valid(_effect): return
 var elapsed: float = _effect.age
 var span: float = _effect.life
 _progress.value = clampf(elapsed/maxf(span,0.01),0.0,1.0)
 if _effect.playback_speed<=0.0: _state.text = "一時停止 / %.2fs" % elapsed
 elif elapsed<span: _state.text = "%s / %.2f / %.2fs" % [_visible_rows[_presets.selected]["complexity_class"],elapsed,span]
 elif _effect.loop: _state.text = "次のループを待機"
 else: _state.text = "終了 / 再生でやり直す"
