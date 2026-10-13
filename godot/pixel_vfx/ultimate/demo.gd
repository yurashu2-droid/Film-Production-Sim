extends Node3D
const Effect=preload("res://pixel_vfx/ultimate/px_apotheosis.gd")
var effect:Node3D
var camera:Camera3D
var hud:CanvasLayer
var _timeline:HSlider
var _phase:Label
var _clock:Label
var _yaw:=.24
var _pitch:=.23
var _distance:=13.5
var _loop:=true
var _rest:=0.0
var _drag:=false
var _speed:=1.0

func _ready()->void:
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("080d19")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("667fa3")
	env.ambient_light_energy=.45
	env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.tonemap_white=5.0
	env.glow_enabled=true
	env.glow_intensity=.38
	env.glow_hdr_threshold=1.35
	var atmosphere=WorldEnvironment.new()
	atmosphere.environment=env
	add_child(atmosphere)
	var sun=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-50,-25,0)
	sun.light_color=Color("768cb1")
	sun.light_energy=.6
	add_child(sun)
	var ground=MeshInstance3D.new()
	var plane=PlaneMesh.new()
	plane.size=Vector2(150,150)
	ground.mesh=plane
	var mat=StandardMaterial3D.new()
	mat.albedo_color=Color("202b39")
	mat.roughness=.75
	ground.material_override=mat
	add_child(ground)
	var grid=ImmediateMesh.new()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)
	for n in range(-10,11):
		grid.surface_add_vertex(Vector3(n*2,.006,-20));grid.surface_add_vertex(Vector3(n*2,.006,20))
		grid.surface_add_vertex(Vector3(-20,.006,n*2));grid.surface_add_vertex(Vector3(20,.006,n*2))
	grid.surface_end()
	var grid_node=MeshInstance3D.new()
	grid_node.mesh=grid
	var gm=StandardMaterial3D.new()
	gm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color=Color("1e2a3b")
	grid_node.material_override=gm
	add_child(grid_node)
	var person=MeshInstance3D.new()
	var capsule=CapsuleMesh.new()
	capsule.height=1.7;capsule.radius=.22
	person.mesh=capsule
	person.position=Vector3(-6,.85,0)
	var pm=StandardMaterial3D.new()
	pm.albedo_color=Color("53647b")
	person.material_override=pm
	add_child(person)
	camera=Camera3D.new()
	camera.fov=42
	add_child(camera)
	aim()
	replay()
	_ui()

func aim()->void:
	var focus=Vector3(0,3.1,0)
	camera.position=focus+Vector3(sin(_yaw)*cos(_pitch),sin(_pitch),cos(_yaw)*cos(_pitch))*_distance
	camera.look_at(focus)

func replay()->void:
	if is_instance_valid(effect):effect.free()
	effect=Effect.spawn(self,Vector3.ZERO,1.0)
	effect.free_on_finish=false
	effect.playback_speed=_speed
	_rest=0

func _ui()->void:
	hud=CanvasLayer.new()
	add_child(hud)
	var top=VBoxContainer.new()
	top.position=Vector2(30,24)
	hud.add_child(top)
	var title=Label.new()
	title.text="星海の戴冠門"
	title.add_theme_font_size_override("font_size",30)
	title.add_theme_color_override("font_color",Color("e5d6ac"))
	top.add_child(title)
	_phase=Label.new()
	_phase.add_theme_font_size_override("font_size",16)
	_phase.add_theme_color_override("font_color",Color("8fafc3"))
	top.add_child(_phase)
	var panel=HBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top=-64;panel.offset_bottom=-24
	panel.offset_left=30;panel.offset_right=-30
	panel.add_theme_constant_override("separation",18)
	hud.add_child(panel)
	for caption in ["再生し直す","一時停止","視点を戻す"]:
		var button=Button.new();button.text=caption
		panel.add_child(button)
		if caption=="再生し直す":button.pressed.connect(replay)
		elif caption=="一時停止":button.pressed.connect(func():effect.playback_speed=1.0 if effect.playback_speed==0 else 0.0)
		else:button.pressed.connect(func():_yaw=.24;_pitch=.23;_distance=13.5;aim())
	_timeline=HSlider.new()
	_timeline.max_value=22;_timeline.step=.01
	_timeline.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	panel.add_child(_timeline)
	_timeline.value_changed.connect(func(t):effect.age=t;effect._done=false;effect.pose(t))
	_clock=Label.new()
	_clock.custom_minimum_size.x=110
	panel.add_child(_clock)

func _process(delta:float)->void:
	if not is_instance_valid(effect):return
	if is_instance_valid(_timeline):
		_timeline.set_value_no_signal(effect.age)
		_clock.text="%04.1f / 22.0s"%minf(effect.age,22)
		_phase.text="01 予兆" if effect.age<3 else ("02 供給" if effect.age<7 else ("03 解錠" if effect.age<12 else ("04 戴冠" if effect.age<16 else "05 回収と余韻")))
	if effect._done and _loop:
		_rest+=delta
		if _rest>1.2:replay()

func _unhandled_input(event:InputEvent)->void:
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:_drag=event.pressed
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP:_distance=maxf(5,_distance*.9);aim()
		if event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:_distance=minf(30,_distance*1.1);aim()
	if event is InputEventMouseMotion and _drag:
		_yaw-=event.relative.x*.008
		_pitch=clampf(_pitch+event.relative.y*.006,-.1,1.2)
		aim()
