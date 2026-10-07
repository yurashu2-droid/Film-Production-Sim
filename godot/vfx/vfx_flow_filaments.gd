extends "res://vfx/vfx_base.gd"
# Reference: vfx_explosion velocity-aligned sparks: impulsive launch, drag, gravity, cooling.
# Material runs along a moving curved path. Supply stops before the advancing head.
const Ribbon := preload("res://vfx/vfx_ribbon.gd")
var u := 1.0
var flames: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var heads: Array[Node3D] = []
var cores: Array[MeshInstance3D] = []
var auras: Array[MeshInstance3D] = []
var _burst_delay := 0.0
var _origin := Vector3.ZERO
var _origin_spread := 0.0
var _duration_scale := 1.0
var _drag := 2.8
var _gravity := 10.2
var _upward_scale := 1.0
var _flames_enabled := true
# angle, birth, radial reach, rise, roll time, supply duration, width.
# Two leading streams, their delayed peel-off branches, then a lower trailing stream.
const JETS := [
	[-0.35,0.03,4.5,2.3,0.17,0.22,0.92],
	[2.5,0.08,3.3,4.2,0.28,0.27,0.72],
	[4.2,0.14,2.4,1.7,0.33,0.15,0.38],
	[-0.35,0.03,4.5,2.3,0.17,0.22,0.33],
	[2.5,0.08,3.3,4.2,0.28,0.27,0.27],
	[0.95,0.27,3.5,1.5,0.25,0.12,0.42],
	[5.2,0.34,2.1,2.8,0.22,0.13,0.30],
]
static func spawn(parent: Node, ground: Vector3, size: float = 1.0, opts: Dictionary = {}) -> Node3D:
	var fx: Node3D = new()
	fx.top_level = true
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size, opts)
	return fx
func make_band(width: float, spark: bool) -> MeshInstance3D:
	var n: MeshInstance3D = Ribbon.new()
	n.material_override = Lib.material("flow_filament", {"width":width*u,"spark":spark})
	add_child(n)
	return n
func start(size: float, opts: Dictionary = {}) -> void:
	u = maxf(size,0.05)
	_burst_delay = opts.get("delay", 0.0)
	_origin = opts.get("origin", Vector3.ZERO)
	_origin_spread = opts.get("origin_spread", 0.0)
	_duration_scale = opts.get("duration_scale", 1.0)
	_drag = opts.get("drag", 2.8)
	_gravity = opts.get("gravity", 10.2)
	_upward_scale = opts.get("upward_scale", 1.0)
	_flames_enabled = opts.get("flames", true)
	life = maxf(3.6, _burst_delay + 2.0)
	if _flames_enabled:
		for jet in JETS:
			flames.append(make_band(jet[6],false))
	for i in 7:
		sparks.append(make_band(0.23+float(i%3)*0.04,true))
		var head := Node3D.new()
		add_child(head)
		heads.append(head)
		var ball := SphereMesh.new()
		ball.radius = 0.5
		ball.height = 1.0
		ball.radial_segments = 16
		ball.rings = 8
		var core := MeshInstance3D.new()
		core.mesh = ball
		core.material_override = Lib.material("flow_ember_head", {"core":true})
		core.scale = Vector3.ONE * 0.18 * u
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(core)
		cores.append(core)
		var aura := MeshInstance3D.new()
		aura.mesh = ball
		aura.material_override = Lib.material("flow_ember_head", {"noise_texture":Lib.flow_noise()})
		aura.scale = Vector3(0.36,0.36,0.64) * u
		aura.position.z = 0.10 * u
		aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head.add_child(aura)
		auras.append(aura)
	_tick(0)
static func hashf(i: int) -> float:
	return fposmod(sin(float(i)*127.1+31.7)*43758.5453,1.0)
func spark_path(i: int, dt: float) -> Vector3:
	var a := float(i)*2.39996
	var velocity := 6.0+hashf(i)*4.0
	var travel := velocity*(1.0-exp(-_drag*dt))/_drag
	var rise := (3.7+hashf(i+7)*2.9)*_upward_scale*(1-exp(-1.4*dt))/1.4-_gravity*0.5*dt*dt
	return _origin+Vector3(cos(a)*travel,0.25+rise+(hashf(i+42)-0.5)*_origin_spread,sin(a)*travel)
func flame_path(i: int, dt: float, material_time: float) -> Vector3:
	var jet: Array = JETS[i]
	var a: float = jet[0]
	var d := Vector3(cos(a),0,sin(a))
	var side := Vector3(-sin(a),0,cos(a))
	# Fast outward impulse arrests, folds upwards, then carries detached material.
	var travel: float = jet[2]*(1-exp(-9.5*dt))
	var fold: float = smoothstep(jet[4],jet[4]+0.48,dt)
	var radial := travel-1.65*fold
	var y: float = 0.12+jet[3]*(1-exp(-dt*3.2))+0.6*fold+1.6*maxf(0,dt-0.6)
	var bend := -0.7*fold*fold
	if i == 3 or i == 4:
		# Branch shares the leading stream before peeling off at a moving neck.
		var peel := smoothstep(0.22,0.65,dt)
		bend += (1.3 if i == 3 else -1.2)*peel
		radial -= 0.55*peel
		y += 0.6*peel
	return d*radial+side*bend+Vector3.UP*(y+material_time*0.45)
func _tick(_delta: float) -> void:
	var t := age-_burst_delay
	for i in sparks.size():
		var n := sparks[i]
		var born := 0.08+hashf(i+21)*0.10
		var dt := t-born
		var duration := (0.65+hashf(i+12)*0.40)*_duration_scale
		n.visible = dt > 0 and dt < duration and spark_path(i,maxf(0,dt)).y > 0.06
		heads[i].visible = n.visible
		if not n.visible: continue
		var position3 := spark_path(i,dt)
		var tangent := (spark_path(i,dt+0.005)-position3).normalized()
		heads[i].position = position3 * u
		heads[i].basis = Basis.looking_at(tangent,Vector3.UP)
		var cooling := clampf(dt/duration,0,1)
		for part in [cores[i],auras[i]]:
			param(part,"phase",dt)
			param(part,"cool",cooling)
		var points := PackedVector3Array()
		var tail_span := minf(dt,0.12+0.035*exp(-dt*3))
		for j in 9:
			var q := float(j)/8
			points.append(global_position+spark_path(i,maxf(0,dt-q*tail_span))*u)
		n.draw(points)
		param(n,"phase",dt)
		param(n,"cool",clampf(dt/duration,0,1))
	for i in flames.size():
		var n := flames[i]
		var born: float = JETS[i][1]
		var dt := t-born
		# Emission exists for 0.23 seconds. The tail catches the head after shutoff.
		var front := dt
		var rear: float = maxf(0,dt-JETS[i][5])
		n.visible = dt > 0 and rear < front and dt < 1.18
		if not n.visible: continue
		var points := PackedVector3Array()
		for j in 25:
			var q := float(j)/24
			var particle_age := lerpf(front,rear,q)
			points.append(global_position+flame_path(i,particle_age,dt-particle_age)*u)
		n.draw(points)
		param(n,"phase",dt)
		param(n,"cool",clampf((dt-0.24)/0.84,0,1))
		param(n,"supply",clampf(1.0-maxf(0,dt-0.65)/0.49,0,1))
