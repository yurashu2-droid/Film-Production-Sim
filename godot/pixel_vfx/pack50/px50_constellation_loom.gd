extends "res://pixel_vfx/px_base.gd"
# 星図の織門: left supply opens the central loom; its outgoing shuttle wakes the right gate.
# Separate crown stitching, remote floor charts and orbit shuttles respond to those arrivals.
# Four-sector seals travel through depth cohorts; links drain, then charts erase toward the gates.
const FIELD := preload("res://pixel_vfx/pack50/shaders/constellation_loom.gdshader")
var variant := "constellation_loom"
var seed := 0
var _size := 1.0
var _layers: Array[Dictionary] = []
var _links: Array[MeshInstance3D] = []
var _charts: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _crown: MeshInstance3D
var _shuttles: MultiMesh
var _grid: ArrayMesh
var _colors: Array = []
var _centers := [Vector3(-2.0,1.25,.70),Vector3(0,1.65,-.35),Vector3(2.0,1.25,-.70)]

static func spawn(parent: Node, pos: Vector3, size: float=1.0, selected: String="constellation_loom") -> Node3D:
 var fx: Node3D = new()
 parent.add_child(fx)
 fx.global_position=pos
 fx.start(size,selected)
 return fx

func _mat(mode: int, layer_index: int=0, color_name: String="") -> ShaderMaterial:
 var m := ShaderMaterial.new()
 m.shader=FIELD
 m.set_shader_parameter("mode",mode)
 m.set_shader_parameter("layer",layer_index)
 m.set_shader_parameter("seed",float(seed%997))
 var strength := .19+layer_index*.095 if mode==0 else .35
 var colors: Array=palette(color_name) if not color_name.is_empty() else _colors
 for i in 5: m.set_shader_parameter("pal_%d"%i,colors[i]*strength)
 return m

func _mesh(vertices: PackedVector3Array, uv: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices
 arrays[Mesh.ARRAY_TEX_UV]=uv
 arrays[Mesh.ARRAY_INDEX]=indices
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 return mesh

func _surface() -> ArrayMesh:
 var vertices := PackedVector3Array()
 var uv := PackedVector2Array()
 var indices := PackedInt32Array()
 for y in 25:
  for x in 25:
   var p := Vector2(float(x)/24,float(y)/24)
   vertices.append(Vector3(p.x-.5,.5-p.y,0));uv.append(p)
 for y in 24:
  for x in 24:
   var a := y*25+x
   indices.append_array(PackedInt32Array([a,a+25,a+1,a+1,a+25,a+26]))
 return _mesh(vertices,uv,indices)

func _curve(a: Vector3,b: Vector3,u: float,up: float) -> Vector3:
 return a.lerp(b,u)+Vector3(0,sin(u*PI)*up,sin(u*PI)*.30)*_size

func _ribbon(a: Vector3,b: Vector3,up: float) -> MeshInstance3D:
 var vertices := PackedVector3Array()
 var uv := PackedVector2Array()
 var indices := PackedInt32Array()
 for i in 33:
  var u := float(i)/32
  var p := _curve(a,b,u,up)
  vertices.append(p+Vector3(0,.20*_size,0));vertices.append(p-Vector3(0,.20*_size,0))
  uv.append(Vector2(u,0));uv.append(Vector2(u,1))
 for i in 32:
  var q := i*2
  indices.append_array(PackedInt32Array([q,q+1,q+2,q+2,q+1,q+3]))
 var node := MeshInstance3D.new()
 node.mesh=_mesh(vertices,uv,indices);node.material_override=_mat(2,0,"gold")
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.extra_cull_margin=3.0*_size
 add_child(node)
 return node

func start(size: float, selected: String) -> void:
 variant=selected
 seed=variant.hash()
 life=6.4
 _size=maxf(size,.01)
 _colors=palette("arcane")
 _grid=_surface()
 for gate in 3:
  var dia := (2.85 if gate==1 else 1.45)*_size
  var light := lamp(_colors[3],3.7*_size)
  light.position=Vector3(_centers[gate].x,.55,.4)*_size
  _lights.append(light)
  for depth in 5:
   var node := MeshInstance3D.new()
   node.mesh=_grid;node.material_override=_mat(0,depth,"ice" if gate==0 else ("gold" if gate==2 else "arcane"))
   node.scale=Vector3.ONE*dia
   node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   node.extra_cull_margin=3.0*_size
   add_child(node)
   _layers.append({"node":node,"gate":gate,"depth":depth,"void":false})
  var void_node := quad(_mat(1),Vector2.ONE*dia)
  _layers.append({"node":void_node,"gate":gate,"depth":5,"void":true})
 _links.append(_ribbon(Vector3(-2,1.95,.70)*_size,Vector3(-.65,2.80,.45)*_size,.85))
 _links.append(_ribbon(Vector3(.65,2.80,.45)*_size,Vector3(2,1.95,-.70)*_size,.85))
 for side in 2:
  var chart := quad(_mat(3,0,"ice" if side==0 else "gold"),Vector2.ONE*1.85*_size)
  chart.rotation.x=-PI/2
  chart.position=Vector3(-1.8 if side==0 else 1.8,.025,-.65 if side==0 else 1.15)*_size
  _charts.append(chart)
 _crown=quad(_mat(4,1,"ice"),Vector2(2.80,.95)*_size)
 _crown.position=Vector3(0,3.25,-.35)*_size
 _crown.rotation.y=.22
 _shuttles=voxels(12,6.0*_size)
 _step(0)

func _step(t: float) -> void:
 if _colors.is_empty(): return
 var ignitions := [.12,1.10,2.05]
 var seals := [4.7,5.10,5.40]
 for part: Dictionary in _layers:
  var node: MeshInstance3D=part["node"]
  var g: int=part["gate"]
  var d: int=part["depth"]
  var rear: bool=part["void"]
  var opened := clampf((t-float(ignitions[g])-(4-mini(d,4))*.07)/.65,0,1)
  var closed := clampf((t-float(seals[g])-d*.065)/.40,0,1)
  if rear: closed=clampf((t-float(seals[g])-.17)/.40,0,1)
  param(node,"phase",t);param(node,"open",opened);param(node,"close",closed)
  param(node,"sector",g)
  node.visible=opened>0 and closed<1
  var yaw := .60 if g==0 else (-.60 if g==2 else 0.0)
  var offset := Vector3(sin(t*1.1-d*.7)*.035,cos(t*1.3-d)*.025,-d*.16)
  if not rear:
   offset.x+=closed*(d-2)*.13
   offset.y+=closed*(.12 if g==1 else -.20)
  node.position=(_centers[g]+Basis(Vector3.UP,yaw)*offset)*_size
  node.rotation=Vector3(0,yaw,sin(t*.8-d*.7)*.025)
 for i in 2:
  var begin := .48+i*.95
  var packet := fmod(maxf(t-begin,0),1.8)/.80
  param(_links[i],"phase",t);param(_links[i],"packet",packet)
  param(_links[i],"open",1.0);param(_links[i],"close",clampf((t-(4.6+i*.3))/.65,0,1))
  _links[i].visible=t>begin and t<5.2+i*.30 and packet<1.32
 for i in 2:
  var opening := clampf((t-(.18 if i==0 else 2.0))/.60,0,1)
  var closing := clampf((t-(5.45+i*.30))/.45,0,1)
  param(_charts[i],"phase",t);param(_charts[i],"open",opening);param(_charts[i],"close",closing)
  _charts[i].visible=opening>0 and closing<1
 param(_crown,"phase",t);param(_crown,"open",clampf((t-2.20)/.85,0,1))
 param(_crown,"close",clampf((t-5.05)/.65,0,1))
 _crown.visible=t>2.2 and t<5.7
 for i in 12:
  var cohort := i/4
  var trailing := i%4
  var u := fmod(maxf(t-1.45-cohort*.60-trailing*.045,0),1.8)/1.8
  var orbit := u*TAU
  var departure := clampf((t-4.85-cohort*.12)/.6,0,1)
  var pos := Vector3(cos(orbit)*1.60,1.65+sin(orbit)*.98,-.05+sin(orbit*2)*.58)
  pos+=Vector3(cos(orbit),sin(orbit),-.4)*departure*.60
  var active := t>1.45+cohort*.6+trailing*.045 and departure<1
  put(_shuttles,i,pos*_size,(.12 if trailing==0 else .07)*_size if active else 0,_colors[3 if trailing==0 else 2],.50,.045*_size)
 for i in 3:
  var arrived := clampf((t-float(ignitions[i]))/.5,0,1)
  var ending := 1-clampf((t-float(seals[i])-.1)/.60,0,1)
  _lights[i].light_energy=2.6*_size*arrived*ending*(.82+.18*sin(t*2.5+i*1.4))
