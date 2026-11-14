extends "res://vfx/vfx_base.gd"
# 素材: 極光の発光流。参考と拍の計画は AURORA_REFRAIN.md。
# 供給: 幕の両端から励起が伝播し、下端の光から遅れて上へ届く。
# 0.72左→右の先行、1.20右→左の小さな返し、2.18左右→中央の合流。
# 通過点ごとに奥行きの折り目・下端・高さが変わり、後部が遅れて追う。
# 出口: 白い芯の励起が中央へ集まる→緑の波が折り目を伝って両端へ抜ける
# →外側の淡い幕は下部を失いながら上へ引き伸ばされる。足元の光は残さない。
# 年齢によるノイズ穴消し0層。ノード全体のscaleを動かさない。
const MATERIAL := preload("res://vfx/shaders/aurora_refrain.gdshader")
const COLORS := [
	[Vector3(0.015,0.5,0.30), Vector3(0.12,1.2,0.8)],
	[Vector3(0.04,1.6,0.7), Vector3(0.6,4.2,2.0)],
	[Vector3(0.6,2.7,1.5), Vector3(3.5,5.6,4.0)],
]
var _sheets: Array[MeshInstance3D] = []

static func spawn(parent: Node, ground: Vector3, size: float=1.0) -> Node3D:
	var fx := new()
	fx.top_level=true
	parent.add_child(fx)
	fx.global_position=ground
	fx.life=5.8
	fx._build(size)
	return fx

func _build(size: float) -> void:
	var mesh := _grid(160,28)
	for i in 3:
		var sheet := Lib.wisp_layer(mesh,i,3,COLORS[i][0],COLORS[i][1])
		# Keep sparse layered construction; aurora needs soft optical edges, not solid wisp cuts.
		var mat := ShaderMaterial.new()
		mat.shader=MATERIAL
		mat.set_shader_parameter("layer",float(i))
		mat.set_shader_parameter("size",size)
		mat.set_shader_parameter("shade",COLORS[i][0])
		mat.set_shader_parameter("hot",COLORS[i][1])
		sheet.material_override=mat
		sheet.custom_aabb=AABB(Vector3(-5,-1,-4)*size,Vector3(10,8,8)*size)
		add_child(sheet)
		_sheets.append(sheet)
	_tick(0)

func _tick(_delta: float) -> void:
	for sheet in _sheets: param(sheet,"phase",age)

static func _grid(nx: int, ny: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for j in ny+1:
		for i in nx+1:
			var p := Vector2(float(i)/nx,float(j)/ny)
			vertices.append(Vector3(p.x,p.y,0))
			normals.append(Vector3.FORWARD)
			uv.append(p)
	for j in ny:
		for i in nx:
			var a:=j*(nx+1)+i
			indices.append_array(PackedInt32Array([a,a+1,a+nx+1,a+1,a+nx+2,a+nx+1]))
	var arrays:=[]
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
