extends "res://pixel_vfx/px_base.gd"
# 素材: pixel space membranes, depth cohorts drawn from a dark aperture.
# Leading edge: angular ignition / scanning side; five depth layers follow at 0.08s.
# Shape: 0.2s first sector, 0.9s assembled lip, 1.6s opposing shear / handoff.
# Exit: external cohorts travel apart, sectors wipe in separate directions;
# rear void is consumed by a side scan; floor marks sweep last. No shrink exit.

const FIELD := preload("res://pixel_vfx/pack50/shaders/portals_field.gdshader")
const GROUND := preload("res://pixel_vfx/pack50/shaders/portals_ground.gdshader")
# [shape, palette, diameter, life, exit, horizontal, tempo]
const PRESETS := {
 "astral_gate": [0,"arcane",4.5,6.0,0,false,0.8],
 "eclipse_gate": [1,"gold",4.6,6.0,1,false,0.65],
 "tidal_gate": [2,"ice",4.5,6.2,1,false,1.2],
 "fractured_gate": [3,"arcane",4.7,6.1,3,false,0.9],
 "summon_well": [0,"toxic",3.5,5.8,0,true,1.1],
 "hex_door": [4,"gold",3.3,5.7,3,false,0.9],
 "phase_window": [5,"ice",3.6,5.8,2,false,1.3],
 "twin_gate": [0,"arcane",2.25,6.2,0,false,1.0],
 "rune_gate": [6,"toxic",3.7,5.9,5,false,0.55],
 "blink_rift": [7,"arcane",2.2,3.5,1,false,2.4],
 "return_mark": [8,"ice",2.3,4.6,2,true,1.0],
 "loot_aperture": [9,"gold",1.85,4.9,2,false,0.7],
}
var variant := "astral_gate"
var seed := 0
var _size := 1.0
var _cfg: Array = []
var _colors: Array = []
var _parts: Array[Dictionary] = []
var _bits: MultiMesh
var _lamps: Array[OmniLight3D] = []
var _ground: Array[MeshInstance3D] = []
var _centers: Array[Vector3] = []
var _membrane_mesh: ArrayMesh
var _bit_count := 32

func _surface(mat: Material, dia: float) -> MeshInstance3D:
 if _membrane_mesh == null:
  var vertices := PackedVector3Array()
  var uv := PackedVector2Array()
  var indices := PackedInt32Array()
  var steps := 24
  for y in range(steps+1):
   for x in range(steps+1):
    var point := Vector2(float(x)/steps,float(y)/steps)
    vertices.append(Vector3((point.x-.5)*dia,(.5-point.y)*dia,0))
    uv.append(point)
  for y in steps:
   for x in steps:
    var a := y*(steps+1)+x
    indices.append_array(PackedInt32Array([a,a+steps+1,a+1,a+1,a+steps+1,a+steps+2]))
  var arrays := []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices
  arrays[Mesh.ARRAY_TEX_UV]=uv
  arrays[Mesh.ARRAY_INDEX]=indices
  _membrane_mesh=ArrayMesh.new()
  _membrane_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var node := MeshInstance3D.new()
 node.mesh=_membrane_mesh
 node.material_override=mat
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 node.extra_cull_margin=4.0*_size
 add_child(node)
 return node

static func spawn(parent: Node, pos: Vector3, size: float = 1.0, selected: String = "astral_gate") -> Node3D:
 var fx: Node3D = new()
 parent.add_child(fx)
 fx.global_position = pos
 fx.start(size, selected)
 return fx

func _mat(layer_index: float, params: Dictionary) -> ShaderMaterial:
 var m := ShaderMaterial.new()
 m.shader = FIELD
 var strength := 0.10 + pow(layer_index / 4.0,1.5) * 0.60
 for i in 5:
  m.set_shader_parameter("pal_%d" % i, _colors[i] * strength * (0.52 if layer_index<1.5 and i>2 else 1.0))
 m.set_shader_parameter("layer", layer_index)
 m.set_shader_parameter("seed", float(seed % 1000) * 0.01 + layer_index * 3.71)
 for key: String in params:
  m.set_shader_parameter(key, params[key])
 return m

func start(size: float, selected: String) -> void:
 variant = selected if PRESETS.has(selected) else "astral_gate"
 seed = variant.hash()
 _size = maxf(size,0.01)
 _cfg = PRESETS[variant]
 _colors = palette(_cfg[1])
 life = float(_cfg[3])
 var dia := float(_cfg[2]) * _size
 var horizontal: bool = _cfg[5]
 _bit_count = 12 if variant=="summon_well" else (8 if variant in ["blink_rift","return_mark","loot_aperture"] else 24)
 _centers = [Vector3(0, dia*0.5 if not horizontal else 0.50*_size, 0)]
 if variant == "twin_gate":
  _centers = [Vector3(-1.28*_size,1.28*_size,0.14*_size), Vector3(1.28*_size,1.28*_size,-0.16*_size)]
 for gate in _centers.size():
  var light := lamp(_colors[3],dia*1.7)
  light.position = Vector3(_centers[gate].x,0.65*_size,0.35*_size)
  _lamps.append(light)
  for i in 5:
   var pieces := 6 if variant == "fractured_gate" else 1
   for piece in pieces:
    var mi := _surface(_mat(float(i),{"shape":int(_cfg[0]),"res":44.0+i*8.0,"inner":0.67-i*0.065,"outer":0.98-i*0.075,"spin":float(_cfg[6])*(1.0+i*0.3)*(1 if i%2==0 else -1),"exit_mode":int(_cfg[4]),"depth_curve":dia*0.12,"start_angle":fmod(i*0.173+gate*0.34,1.0),"slice_start":float(piece)/pieces,"slice_end":float(piece+1)/pieces}),dia)
    if pieces>1:
     param(mi,"slice_start",float(piece)/pieces+0.012)
     param(mi,"slice_end",float(piece+1)/pieces-0.012)
    _parts.append({"node":mi,"layer":i,"gate":gate,"piece":piece,"void":false})
  var void_exit := 1 if variant in ["eclipse_gate","tidal_gate","blink_rift","rune_gate"] else (0 if variant=="summon_well" else (6 if variant in ["fractured_gate","loot_aperture"] else (4 if variant=="hex_door" or gate==1 else 2)))
  var rear := quad(_mat(1.0,{"shape":int(_cfg[0]),"mode":1,"res":44.0,"outer":0.59,"exit_mode":void_exit}),Vector2.ONE*dia)
  _parts.append({"node":rear,"layer":5,"gate":gate,"piece":0,"void":true})
 var ground_count := 0 if variant in ["summon_well","blink_rift","return_mark","loot_aperture"] else (2 if variant=="twin_gate" else 1)
 var motifs := {"astral_gate":0,"eclipse_gate":1,"tidal_gate":2,"fractured_gate":3,"hex_door":4,"phase_window":5,"twin_gate":6,"rune_gate":7}
 for i in ground_count:
  var ground_mat := ShaderMaterial.new()
  ground_mat.shader=GROUND
  for color in 5: ground_mat.set_shader_parameter("pal_%d"%color,_colors[color]*.23)
  ground_mat.set_shader_parameter("motif",motifs.get(variant,0))
  ground_mat.set_shader_parameter("seed",i)
  var mark := quad(ground_mat,Vector2.ONE*dia*0.78)
  mark.rotation.x = -PI*0.5
  mark.position = Vector3(_centers[i].x if ground_count==2 else 0,0.025*_size+i*0.018*_size,0)
  _ground.append(mark)
 _bits = voxels(_bit_count,7.0*_size)
 _step(0.0)

func _step(t: float) -> void:
 if _cfg.is_empty(): return
 var dia := float(_cfg[2])*_size
 var horizontal: bool = _cfg[5]
 var close_start := life-1.65
 var pulse := 0.86+0.14*sin(t*float(_cfg[6])*7.0)
 for part: Dictionary in _parts:
  var mi: MeshInstance3D = part["node"]
  var i: int = part["layer"]
  var gate: int = part["gate"]
  var piece: int = part["piece"]
  var is_void: bool = part["void"]
  var delay := (4-i)*0.075 if not is_void else 0.0
  if variant == "twin_gate": delay += gate*0.63
  var opening := clampf((t-delay)/0.7,0.0,1.0)
  if variant == "blink_rift": opening = clampf((t-delay)/0.26,0.0,1.0)
  var departing := clampf((t-close_start-i*0.11-piece*0.015)/0.54,0.0,1.0)
  if is_void: departing = clampf((t-close_start-0.38)/0.44,0.0,1.0)
  param(mi,"phase",t)
  param(mi,"open",opening)
  param(mi,"close",departing)
  mi.visible = opening>0.0 and departing<1.0
  var z := -i*(0.085 if horizontal else 0.19)*_size
  var local := Vector3(0,0,z)
  var turn := 0.0
  if not is_void:
   local.x += sin(t*1.3-i*0.52)*0.045*_size
   local.y += cos(t*1.1-i*0.57)*0.05*_size
   if variant == "astral_gate":
    local.z += sin(t*1.4-i*0.7)*0.09*_size
    turn = sin(t*0.7+i)*0.055
   elif variant == "eclipse_gate":
    local.x += (sin(t*0.85+i*0.4)*0.15+departing*(i-2)*0.16)*_size
    turn = -0.035*i*sin(t)
   elif variant == "tidal_gate":
    local.y += sin(t*2.2-i*0.8)*0.18*_size-departing*0.42*_size
    local.z += sin(t*1.7-i*0.5)*0.15*_size
   elif variant == "fractured_gate":
    var a := (piece+0.5)*TAU/6.0
    var detach := departing*0.42 + 0.13 + 0.12*sin(t*2.1-piece*0.8-i*0.4)
    local += Vector3(cos(a),sin(a),sin(a+i)*0.4)*detach*_size
    turn = departing*(0.12 if piece%2==0 else -0.12)
   elif variant == "hex_door":
    turn = snappedf(t*0.10,PI/18.0)*(1 if i%2==0 else -1)
    local.z += sin(t*3.0-i)*0.08*_size
   elif variant == "phase_window":
    local.x += sin(t*1.7-i)*0.15*_size+departing*(i-2)*0.16*_size
    local.y += sin(t*2.2-i*0.5)*0.07*_size
   elif variant == "twin_gate":
    var handoff := sin(clampf((t-1.1)/2.0,0.0,1.0)*PI)
    local.x += (1 if gate==0 else -1)*handoff*0.18*_size
    local.z += sin(t*2.0-i-gate*2.0)*0.09*_size
   elif variant == "rune_gate":
    turn = (sin(t*0.7)*0.08 if i%2==0 else -sin(t*0.7)*0.10)
    local.z += sin(t*2.5-i*0.8)*0.06*_size
   elif variant == "blink_rift":
    local.x += sin(t*4.0-i*0.6)*0.075*_size
    local.y += departing*0.26*_size
   elif variant == "return_mark":
    turn = PI*0.25*(1 if i%2==0 else -1)
    local.y += departing*(i-2)*0.09*_size
   elif variant == "loot_aperture":
    local.y += sin(t*1.8-i)*0.10*_size+departing*0.12*_size
    turn = 0.03*sin(t*2.0-i)
  if horizontal:
   mi.rotation = Vector3(-PI*0.5,turn,0)
   mi.position = _centers[gate]+Vector3(local.x,local.z,local.y)
  else:
   mi.rotation = Vector3(0,0,turn)
   mi.position = _centers[gate]+local
  # Size is constant after construction; the moving sectors supply growth/exit.
 for i in _ground.size():
  param(_ground[i],"phase",t)
  param(_ground[i],"open",clampf((t-i*0.12)/0.65,0.0,1.0))
  param(_ground[i],"close",clampf((t-close_start-0.50-i*0.10)/0.42,0.0,1.0))
  _ground[i].visible = t<life-0.6
 for i in _bit_count:
  var gate := i%_centers.size()
  var a := i*2.39996+t*(0.7 if i%2==0 else -0.5)
  var r := dia*(0.40+0.045*sin(t*2.0-i))
  var out := maxf(t-close_start-i%4*0.045,0.0)
  var pos := Vector3(cos(a)*r,sin(a)*r,sin(a*2.0+i)*0.18*_size)
  if variant == "blink_rift": pos.x *= 0.34
  if variant == "tidal_gate":
   pos.y = dia*.48-fmod(t*1.0+i*.14,dia*.9)
   pos.x = sin(i*2.1)*dia*.44
  elif variant == "hex_door":
   var corner := float(i%6)*TAU/6.0
   pos = Vector3(cos(corner)*r,sin(corner)*r,sin(t*2-i)*.15*_size)
  elif variant == "loot_aperture":
   pos = Vector3(sin(i*1.7)*.48*_size,fmod(t*.7+i*.12,1.35)*_size,-.10*_size)
  if horizontal: pos = Vector3(pos.x,0.15*_size+pos.z,-pos.y)
  pos += _centers[gate]
  if variant == "twin_gate" and i<8:
   var journey := fmod(maxf(t-0.9-i*0.07,0.0),1.7)/1.7
   pos = _centers[0].lerp(_centers[1],journey)+Vector3(0,sin(journey*PI)*0.38*_size,-0.25*_size)
  pos.y -= out*out*0.7*_size
  var alive := t>0.35+i%5*0.04 and out<0.42 and pos.y>0.025*_size
  put(_bits,i,pos,0.075*_size if alive else 0.0,_colors[3 if i%4 else 4],0.75,0.045*_size)
 for i in _lamps.size():
  var brightness := 1.0
  if variant == "twin_gate": brightness = 0.75+0.25*sin(t*3.5+i*PI)
  _lamps[i].light_energy = 3.8*_size*pulse*brightness*clampf(t/0.5,0.0,1.0)*(1.0-clampf((t-close_start-0.45)/0.85,0.0,1.0))
