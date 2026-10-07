extends "res://vfx/vfx_base.gd"
# Reference: user's successful thin-layer tornado breakdown / existing vfx_tornado.
# LeLu flame silhouette is advected diagonally through sparse nested sheets.
# Separate low, thick root circulation and 3 ground components; no sphere sparks.
# Exit: supply stops at root -> last flames travel upwards; roots cool and retract;
# ground components wind down, wipe and drain at different times. No noise dissolve.
const SHEETS := [
	# radius, height, rotation, climb, coverage, shade, hot
	[1.76,4.75,0.31,0.24,0.27,Vector3(0.85,0.018,0.003),Vector3(2.1,0.12,0.009)],
	[1.43,5.05,0.43,0.31,0.25,Vector3(1.4,0.055,0.005),Vector3(3.0,0.31,0.018)],
	[1.14,5.30,0.57,0.38,0.25,Vector3(2.2,0.16,0.009),Vector3(4.0,0.70,0.04)],
	[0.87,5.55,0.71,0.45,0.26,Vector3(3.0,0.40,0.018),Vector3(5.4,1.25,0.09)],
	[0.59,5.73,0.88,0.51,0.27,Vector3(3.8,0.85,0.06),Vector3(6.8,2.3,0.30)],
	[0.31,5.90,1.02,0.58,0.29,Vector3(5.2,1.75,0.23),Vector3(8.5,3.8,1.0)],
]
const PROFILE := [[0.0,0.27],[0.15,0.35],[0.4,0.52],[0.7,0.76],[1.0,1.0]]
static var _flow_textures: Dictionary = {}
var _size := 1.0
var _hold := 2.1
var _sheets: Array[MeshInstance3D] = []
var _roots: Array[MeshInstance3D] = []
var _ground: Array[MeshInstance3D] = []
var _light: OmniLight3D

static func spawn(parent: Node, ground: Vector3, size: float=1.0, seconds: float=2.1) -> Node3D:
	var fx := new()
	fx.top_level=true
	parent.add_child(fx)
	fx.global_position=ground
	fx.start(size,seconds)
	return fx

func start(size: float, seconds: float) -> void:
	_size=size
	_hold=maxf(seconds,0.0)
	life=0.55+_hold+1.65
	var tube := Lib.tube_mesh(PROFILE,64,48)
	for i in SHEETS.size():
		var plan: Array=SHEETS[i]
		var sheet := _flame(tube,{
			"radius":plan[0]*size,"height":plan[1]*size,
			"rotation_speed":plan[2],"climb_speed":plan[3],"coverage":plan[4],
			"shade":plan[5],"hot":plan[6],"seed":float(i)*0.237,
			"born":0.13+float(5-i)*0.073,"stop_time":0.55+_hold+float(i)*0.067,
			"shear":-0.87-float(i)*0.14,
		})
		_sheets.append(sheet)
	var base := Lib.tube_mesh([[0.0,1.38],[0.15,1.27],[0.5,0.72],[1.0,0.29]],56,24)
	for i in 2:
		_roots.append(_flame(base,{
			"root_flow":true,"radius":size*(1.52-float(i)*0.31),"height":size*(1.65+float(i)*0.32),
			"rotation_speed":-0.21-float(i)*0.09,"climb_speed":0.32+float(i)*0.06,
			"coverage":0.18+float(i)*0.03,"shear":1.12,"seed":2.3+float(i)*0.6,
			"shade":Vector3(2.1,0.18,0.006),"hot":Vector3(5.0,1.0,0.08),
			"born":float(i)*0.15,"stop_time":0.45+_hold+float(i)*0.12,
		}))
	for i in 3:
		var mesh := MeshInstance3D.new()
		mesh.mesh=PlaneMesh.new()
		(mesh.mesh as PlaneMesh).size=Vector2(2,2)
		mesh.position.y=0.022+float(i)*0.016
		mesh.material_override=Lib.material("fire_vortex_ground",{
			"spiral":_filtered_tex("vfx_spiral07.jpg"),"flame":_filtered_tex("firepanningcyl45.png"),
			"radial_size":size*(3.4-float(i)*0.58),
			"arms":3.0+float(i),"speed":[0.55,-0.78,1.1][i],"seed":float(i),
			"born":float(i)*0.12,"stop_time":0.55+_hold+float(i)*0.22,"duration":0.9+float(i)*0.12,
			"shade":Vector3(0.55+float(i)*0.38,0.016+float(i)*0.04,0.002),
			"hot":Vector3(2.5+float(i)*0.65,0.22+float(i)*0.24,0.012+float(i)*0.013),
		})
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin=5.0*size
		add_child(mesh)
		_ground.append(mesh)
	_light=lamp(Color(1.0,0.28,0.06),10.0*size)
	_light.position.y=1.3*size
	_tick(0)

func _flame(mesh: Mesh, values: Dictionary) -> MeshInstance3D:
	var mi:=MeshInstance3D.new()
	mi.mesh=mesh
	values.merge({"flame":_filtered_tex("firepanningcyl45.png"),"warp_map":_filtered_tex("marblenoise_tiled.png")})
	mi.material_override=Lib.material("fire_vortex",values)
	mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb=AABB(Vector3(-4,-0.5,-4)*_size,Vector3(8,8,8)*_size)
	add_child(mi)
	return mi

static func _filtered_tex(file_name: String) -> Texture2D:
	# This effect needs mipmaps; leave source imports and other effects untouched.
	if not _flow_textures.has(file_name):
		var image: Image = Lib.tex(file_name).get_image()
		if image.is_compressed(): image.decompress()
		image.generate_mipmaps()
		_flow_textures[file_name]=ImageTexture.create_from_image(image)
	return _flow_textures[file_name]

func _tick(_delta: float) -> void:
	for mi in _sheets+_roots+_ground:
		param(mi,"phase",age)
	if _light:
		var ignite:=smoothstep(0.0,0.4,age)
		var out:=1.0-smoothstep(0.55+_hold,1.8+_hold,age)
		_light.light_energy=_size*1.8*ignite*out*(0.9+0.1*sin(age*8.2))
