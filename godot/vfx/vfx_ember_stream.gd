extends "res://vfx/vfx_base.gd"
# User video + existing projectile: pressure releases hot material in short bursts.
# Each vertex follows material emitted at its own time, not a sphere's old positions.
# Supply ends -> the belly shears/branches -> older material burns out ahead of the tail.
var _unit := 1.0
var _delay := 0.0
var _origin := Vector3.ZERO
var _spread := 0.0
var _drag := 2.2
var _gravity := 2.8
var _rise := 0.48
var _streams: Array[Dictionary] = []
var _bands: Array[MeshInstance3D] = []

static func spawn(parent: Node, ground: Vector3, size: float = 1.0, opts: Dictionary = {}) -> Node3D:
	var fx: Node3D = new()
	fx.top_level = true
	parent.add_child(fx)
	fx.global_position = ground
	fx.start(size, opts)
	return fx

static func _hash(i: int) -> float:
	return fposmod(sin(float(i)*127.1+31.7)*43758.5453, 1.0)

func start(size: float, opts: Dictionary) -> void:
	_unit = maxf(size, 0.05)
	_delay = float(opts.get("delay", 0.0))
	_origin = opts.get("origin", Vector3.ZERO)
	_spread = float(opts.get("origin_spread", 0.0))
	_drag = float(opts.get("drag", 2.2))
	_gravity = float(opts.get("gravity", 2.8))
	_rise = float(opts.get("upward_scale", 0.48))
	life = _delay+2.0
	for i in 9:
		var branch := i >= 6
		var kind := i%3
		var born := 0.025+float(kind)*0.075+_hash(i+12)*0.065
		var supply: float = [0.045, 0.09, 0.12][kind]
		var burn := 0.48+float(kind)*0.18+_hash(i+7)*0.12
		var width: float = [0.20, 0.32, 0.46][kind]
		if branch:
			born = float(_streams[(i-6)*2]["birth"])+0.25+_hash(i+31)*0.12
			supply = 0.065
			burn = 0.43+_hash(i)*0.15
			width = 0.17
		_streams.append({"birth":born,"supply":supply,"burn":burn,"width":width,
			"angle":float(i)*2.39996,"speed":8.0+_hash(i)*5.0,
			"seed":float(i)*1.73,"parent":(i-6)*2 if branch else -1})
		var band := MeshInstance3D.new()
		band.top_level = true
		band.mesh = ImmediateMesh.new()
		band.material_override = Lib.material("ember_stream", {"width":width*_unit,"seed":float(i)*1.73,"fuel_stop":supply})
		band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		band.extra_cull_margin = 2.0*_unit
		add_child(band)
		_bands.append(band)
	_tick(0)

# Emission direction and speed evolve during the burst. A strip joins simultaneously
# living parcels, with the oldest/fastest material at its front.
func _parcel(i: int, elapsed: float, emitted: float) -> Vector3:
	var stream := _streams[i]
	var dt := maxf(0, elapsed-emitted)
	var fraction := emitted/float(stream["supply"])
	var a := float(stream["angle"])+0.20*sin(fraction*2.7+float(stream["seed"]))
	var d := Vector3(cos(a), 0, sin(a))
	var side := Vector3(-sin(a), 0, cos(a))
	var v := float(stream["speed"])*(1.0-0.10*fraction+0.09*sin(fraction*PI))
	var travel := v*(1.0-exp(-_drag*dt))/_drag
	var up := (3.7+_hash(i+7)*2.9)*_rise*(1.0-exp(-1.4*dt))/1.4
	var fold := smoothstep(0.10,0.55,dt)
	var curling := 0.30*(sin(dt*5.0+fraction*1.4)-sin(fraction*1.4))*fold
	var root_pos := _origin+Vector3.UP*((_hash(i+42)-0.5)*_spread+0.25)
	var parent_id := int(stream["parent"])
	if parent_id >= 0:
		var release := float(stream["birth"])-float(_streams[parent_id]["birth"])
		root_pos = _parcel(parent_id,release,0.035)
		travel *= 0.55
		up *= 0.7
	return root_pos+d*travel+side*curling+Vector3.UP*(up-0.5*_gravity*dt*dt+0.16*sin(fraction*PI)*fold)

func _tick(_delta: float) -> void:
	var t := age-_delay
	for i in _streams.size():
		var stream := _streams[i]
		var dt := t-float(stream["birth"])
		var supply := float(stream["supply"])
		var burn := float(stream["burn"])
		var first := maxf(0,dt-burn)
		var last := minf(supply,dt)
		var band := _bands[i]
		band.visible = dt>0.0 and last-first>0.001
		if not band.visible:
			continue
		var points := PackedVector3Array()
		var colors := PackedColorArray()
		for j in 25:
			var q := float(j)/24.0
			var emitted := lerpf(first,last,q)
			var material_age := dt-emitted
			points.append(global_position+_parcel(i,dt,emitted)*_unit)
			# Red: cooling per parcel. Green: absolute material label, retained after cutoff.
			colors.append(Color(clampf(material_age/burn,0,1),emitted/supply,0,1))
		param(band,"phase",dt)
		param(band,"surviving",clampf((last-first)/supply,0,1))
		_draw(band,points,colors)

func _draw(band: MeshInstance3D, points: PackedVector3Array, colors: PackedColorArray) -> void:
	var mesh_band := band.mesh as ImmediateMesh
	mesh_band.clear_surfaces()
	mesh_band.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for j in points.size():
		var tangent := (points[mini(j+1,points.size()-1)]-points[maxi(j-1,0)]).normalized()
		for side in 2:
			mesh_band.surface_set_normal(tangent)
			mesh_band.surface_set_color(colors[j])
			mesh_band.surface_set_uv(Vector2(float(j)/24.0,side))
			mesh_band.surface_add_vertex(points[j])
	mesh_band.surface_end()
