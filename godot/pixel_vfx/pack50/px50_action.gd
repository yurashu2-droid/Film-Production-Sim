extends "res://pixel_vfx/px_base.gd"
# Pixel×Real/action: original procedural choreography; px_portal supplies the
# five-tone/HDR/depth reference, px_meteor the delayed material-history reference.
# Pressure → advancing shoulder → delayed neck/tail → material-specific exit.
# All geometry/material clocks use _step's 12fps age, never TIME or Tween.
# Fire: torn tongues rise after supply ends. Electricity: root->tip consumption.
# Water: shoulder curls over, old belly falls, wet ground sectors drain separately.
# Ice/soil/shield: real solid fragments rotate, fall and settle into the floor.
# The 14 variants have separate path topology, timing and branch plans below.
# No lifetime-dependent noise hole deletion (0 layers).

const SPECS := {
 "inferno_bloom": [6.2,"fire",8,1.55,.66],
 "comet_crash": [5.8,"fire",7,1.5,.58],
 "storm_crown": [5.8,"arcane",9,1.45,.47],
 "frost_cataclysm": [6.2,"ice",7,1.6,.62],
 "gravity_collapse": [6.2,"arcane",8,1.75,.65],
 "earth_rift": [6.2,"earth",7,1.75,.67],
 "plasma_breaker": [5.8,"plasma",7,1.4,.53],
 "tidal_slam": [6.2,"water",8,1.65,.64],
 "fire_lance": [5.0,"fire",4,.9,.45],
 "ice_shot": [5.0,"ice",4,1.0,.4],
 "chain_arc": [5.2,"arcane",6,1.15,.38],
 "cross_cut": [5.2,"silver",4,1.05,.48],
 "shield_break": [5.6,"gold",5,1.35,.46],
 "sonic_punch": [5.6,"silver",6,1.2,.50],
}
const OWN_PALETTES := {
 "fire": [Vector3(.075,.009,.003),Vector3(.45,.047,.008),Vector3(1.55,.3,.023),Vector3(3.4,1.2,.12),Vector3(5.4,4.9,3.3)],
 "ice": [Vector3(.018,.05,.16),Vector3(.045,.24,.64),Vector3(.17,.8,1.5),Vector3(.7,1.8,2.9),Vector3(3.8,4.8,5.2)],
 "arcane": [Vector3(.036,.009,.14),Vector3(.16,.05,.48),Vector3(.58,.26,1.4),Vector3(1.1,1.2,2.7),Vector3(4.0,4.7,5.8)],
 "earth": [Vector3(.06,.034,.02),Vector3(.20,.105,.042),Vector3(.44,.25,.08),Vector3(.78,.53,.20),Vector3(1.35,1.04,.58)],
 "plasma": [Vector3(.01,.10,.15),Vector3(.018,.36,.51),Vector3(.05,1.1,1.5),Vector3(.53,2.5,2.7),Vector3(4.5,5.0,5.3)],
 "water": [Vector3(.013,.06,.11),Vector3(.025,.24,.41),Vector3(.055,.59,.75),Vector3(.29,1.28,1.5),Vector3(2.2,3.2,3.4)],
 "silver": [Vector3(.035,.07,.10),Vector3(.12,.29,.4),Vector3(.37,.71,.85),Vector3(1.1,1.8,2.1),Vector3(3.8,4.3,4.6)],
 "gold": [Vector3(.095,.034,.003),Vector3(.33,.15,.02),Vector3(.9,.53,.08),Vector3(2.2,1.5,.24),Vector3(4.7,4.1,2.1)],
}
var _variant := "inferno_bloom"
var _size := 1.0
var _colors: Array=[]
var _flows: Array=[]
var _ground: Array=[]
var _membrane: Array=[]
var _solids: MultiMesh
var _light: OmniLight3D
var _count := 0
var _supply := 1.5
var _radius := .6

static func spawn(parent: Node,pos: Vector3,size: float=1.0,variant: String="inferno_bloom") -> Node3D:
 var fx: Node3D=new()
 parent.add_child(fx)
 fx.global_position=pos
 fx.start(size,variant)
 return fx

func start(size: float,variant: String) -> void:
 _variant=variant if SPECS.has(variant) else "inferno_bloom"
 _size=maxf(.01,size)
 var spec: Array=SPECS[_variant]
 life=spec[0]
 _colors=OWN_PALETTES[spec[1]]
 _count=spec[2]
 _supply=spec[3]
 _radius=spec[4]
 for j in _count:
  var row: Array=[]
  for k in 3:
   var mi:=MeshInstance3D.new()
   mi.material_override=_mat("action_flow",{"shell":float(k),"seed":j*.73+k*.41,"material_kind":1.0 if _variant in ["storm_crown","chain_arc"] else 2.0 if _variant=="inferno_bloom" else 0.0})
   mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   mi.extra_cull_margin=12.0
   add_child(mi)
   row.append(mi)
  _flows.append(row)
 if _variant=="shield_break":
  for k in 3:
   var membrane:=MeshInstance3D.new()
   membrane.material_override=_mat("action_flow",{"shell":float(k),"seed":k*.47,"is_barrier":1.0})
   membrane.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   add_child(membrane)
   _membrane.append(membrane)
 for k in 3:
  var mode:=1.0 if _variant=="earth_rift" else 3.0 if _variant in ["storm_crown","chain_arc","inferno_bloom","comet_crash","plasma_breaker","frost_cataclysm","shield_break"] else 2.0 if _variant in ["tidal_slam","cross_cut","fire_lance","ice_shot"] else 0.0
  var mi:=quad(_mat("action_ground",{"seed":k*1.7,"mode":mode}),Vector2.ONE*(7.4 if _count>6 else 5.5)*_size)
  mi.rotation.x=-PI/2.0
  mi.rotation.y=k*.55
  mi.position.y=(.024+k*.007)*_size
  if _variant in ["fire_lance","ice_shot"]:
   mi.position.x=1.9*_size
   mi.scale=Vector3(.42,1.0,.70)
  elif _variant=="comet_crash":mi.position.x=.6*_size
  elif _variant=="cross_cut":mi.rotation.y=(-.50 if k%2==0 else .50)
  elif _variant=="storm_crown":
   mi.position.x=cos(k*2.4)*2.1*_size
   mi.position.z=sin(k*2.4)*2.1*_size
   mi.scale=Vector3(.28,1,.28)
  elif _variant=="chain_arc":
   mi.position.x=(-.8+k*1.6)*_size
   mi.scale=Vector3(.16,1,.16)
  elif mode==3.0:mi.scale=Vector3(.48,1,.48)
  _ground.append(mi)
 _solids=voxels(18,14.0*_size)
 _solids.mesh=_panel_mesh() if _variant=="shield_break" else _shard_mesh()
 _light=lamp(_colors[3],11.0*_size)
 _light.position.y=1.2*_size
 _step(0.0)

func _mat(name: String,params: Dictionary) -> ShaderMaterial:
 var m:=ShaderMaterial.new()
 m.shader=load("res://pixel_vfx/pack50/shaders/%s.gdshader"%name)
 for i in 5:m.set_shader_parameter("pal_%d"%i,_colors[i])
 for key: String in params:m.set_shader_parameter(key,params[key])
 return m

func _start(j: int) -> float:
 match _variant:
  "inferno_bloom":return .18+[0.0,.12,.37,.51][j%4]+(1.12 if j>=4 else 0.0)
  "comet_crash":return .16 if j==0 else 1.36+float(j-1)*.08
  "storm_crown":return .24+float(j)*.25
  "frost_cataclysm":return .28+float(j)*.13
  "gravity_collapse":return .14+float(j%4)*.08+(1.85 if j>=4 else 0.0)
  "earth_rift":return .20+float(j)*.18
  "plasma_breaker":return .16 if j<2 else 1.24+float(j-2)*.09
  "tidal_slam":return .16+float(j)*.105
  "chain_arc":return .20+float(j/2)*.63+float(j%2)*.27
  "cross_cut":return .20+float(j%2)*.65+float(j/2)*.14
  "shield_break":return .2+float(j)*.16
  "sonic_punch":return [.2,.2,.76,.76,1.65,1.65][j]
 return .20+float(j)*.12

func _travel(j: int) -> float:
 match _variant:
  "inferno_bloom":return 2.10+float(j%4)*.17
  "comet_crash":return 1.35 if j==0 else 2.35
  "storm_crown":return 1.28+float(j%3)*.14
  "gravity_collapse":return 1.65 if j<4 else 2.4
  "plasma_breaker":return 1.3 if j<2 else 2.15
  "sonic_punch":return [.82,.82,1.13,1.13,1.65,1.65][j]
  "cross_cut":return 1.45
  "chain_arc":return .90 if j%2==0 else .72
  "fire_lance","ice_shot":return 1.85
 return 2.65

func _span(j: int) -> float:
 if _variant=="comet_crash" and j==0:return .55
 if _variant=="plasma_breaker" and j<2:return .62
 if _variant=="gravity_collapse" and j<4:return .86
 if _variant=="gravity_collapse" and j>=4:return .84
 if _variant=="storm_crown":return .56+float(j%3)*.07
 if _variant=="chain_arc":return .95 if j%2==0 else .42
 if _variant=="cross_cut":return 1.55
 if _variant=="sonic_punch":return [.34,.34,.46,.46,.63,.63][j]
 return _supply*.62

func _step(t: float) -> void:
 for k in _membrane.size():
  var membrane: MeshInstance3D=_membrane[k]
  membrane.visible=t>.15+k*.06 and t<1.65+k*.06
  membrane.mesh=_shield_surface(t,k)
  param(membrane,"phase",t)
  param(membrane,"supplied",1.0-smoothstep(1.05+k*.06,1.65+k*.06,t))
 for j in _count:
  for k in 3:
   var mi: MeshInstance3D=_flows[j][k]
   var q:=t-_start(j)-k*.045
   var travel:=_travel(j)
   var head:=clampf(q/travel,0.0,1.0)
   var tail:=clampf((q-_span(j))/travel,0.0,1.0)
   mi.visible=q>0.0 and tail<.999 and head-tail>.008
   if not mi.visible:continue
   var points:=PackedVector3Array()
   var widths:=PackedFloat32Array()
   for i in 22:
    var u:=float(i)/21.0
    var s:=lerpf(tail,head,u)
    var p:=_point(s,q,j)
    p+=Vector3(sin(s*15.0+j+k)*.027,sin(s*9.0+j*.7+k)*.031,cos(s*17.0+j+k)*.026)
    points.append((p*_size).snapped(Vector3.ONE*.035*_size))
    # Moving shoulder + narrow delayed neck: visible material is not a rigid rod.
    var shoulder:=.29+.85*exp(-pow((u-.78)/.20,2.0))
    if _variant in ["storm_crown","chain_arc"]:shoulder=.23+.28*pow(maxf(sin(u*PI),0.0),.5)+.26*pow(maxf(sin(s*27.0-q*9.0+j),0.0),3.0)
    elif _variant=="inferno_bloom":shoulder=.33+.22*sin(u*PI)+.30*pow(maxf(sin(s*17.0-q*7.0+j),0.0),2.0)*sin(u*PI)
    elif _variant=="cross_cut":shoulder=.46+.50*sin(u*PI)
    elif _variant=="tidal_slam":shoulder=.38+.68*exp(-pow((u-.69)/.28,2.0))
    var neck:=1.0-.36*exp(-pow((s-.33-.11*sin(q*2.0+j))/.15,2.0))
    var end_taper:=pow(maxf(sin(u*PI),0.0),.42)
    # The final material shoulder becomes a fine departing tongue, rather than
    # maintaining a floating pear-shaped solid at its terminal point.
    var terminal:=pow(maxf(.0,1.0-tail),.65)
    widths.append(shoulder*neck*end_taper*terminal*(.65+.35*minf(1.0,(head-tail)*5.0)))
   var rad: float=_radius*[1.0,.64,.27][k]
   if _variant=="storm_crown":rad*=1.02+.12*float(j%3)
   if _variant=="chain_arc":rad*=1.15
   if _variant=="comet_crash" and j==0:rad*=1.55
   if _variant=="ice_shot":rad*=.7
   if _variant=="sonic_punch":rad*=[.62,.62,.87,.87,1.2,1.2][j]
   mi.mesh=_tube(points,rad*_size,widths,t,j,k)
   param(mi,"phase",t)
   param(mi,"cooling",smoothstep(travel*.8,travel+_span(j),q))
 var ground_start:=1.95 if _variant in ["fire_lance","ice_shot"] else 1.35 if _variant in ["comet_crash","plasma_breaker"] else 1.85 if _variant=="gravity_collapse" else 1.35 if _variant=="storm_crown" else .9 if _variant=="chain_arc" else .28
 for k in 3:
  var q:=t-ground_start-k*.14
  var ground_end:=4.0+k*.14 if _variant in ["storm_crown","chain_arc"] else life-.62-k*.07
  _ground[k].visible=q>0.0 and t<ground_end
  param(_ground[k],"phase",t)
  param(_ground[k],"front",minf(.94,.08+maxf(0.0,q)*(.26+k*.025)))
  param(_ground[k],"drain",smoothstep(ground_end-.9,ground_end,t))
 _pose_solids(t)
 var pulse:=0.0
 for j in _count:
  var q:=t-_start(j)
  pulse+=exp(-pow((q-_travel(j)*.58)/.55,2.0))
 _light.light_energy=minf(4.0,pulse)*_size*.82

func _point(s: float,q: float,j: int) -> Vector3:
 var a:=float(j)*2.39996+.32
 var d:=Vector3(cos(a),0.0,sin(a))
 match _variant:
  "inferno_bloom":
   # Two unequal pressure releases: low braid expands, then a taller shoulder splits.
   var b:float=[-1.4,.2,2.1,3.5][j%4]+(1.1 if j>=4 else 0.0)
   var spread:=s*(2.0 if j<4 else 1.55)
   var twist:=b+sin(s*PI)*(.9 if j<4 else -1.5)+q*.58
   spread*=.65+.4*sin(q*2.4+j*.7)+.25*s
   var shear:=sin(s*13.0-q*4.0+j)*s*.55
   return Vector3(cos(twist)*spread+shear,.12+(3.6+float(j%3)*.42)*s+sin(s*PI)*.55+sin(s*10.0-q*7.0+j)*s*.28+maxf(0.0,q-1.55)*.56,sin(twist)*spread+cos(s*9.0-q*3.0+j)*s*.25)
  "comet_crash":
   if j==0:return Vector3(-3.4+4.0*s,4.8*(1.0-s*s)+.12,-.8+.95*s)
   var r:=s*(3.0+.2*float(j%3))
   return Vector3(.6,0.0,.15)+d*r+Vector3.UP*(.12+sin(s*PI)*1.8+maxf(0.0,q-1.55)*s*.75)
  "storm_crown":
   var crown:=Vector3(cos(a)*1.35,4.6,sin(a)*1.35)
   var bend:=sin(s*11.0+j+floor(q*6.0)*.7)*sin(s*PI)*.43
   var fork:=maxf(0.0,s-.56)*(1.7 if j%3==2 else -.45)
   return crown+d*(s*1.25+bend+fork)+Vector3(-sin(a),0,cos(a))*sin(s*19.0+j+q*4.0)*.21+Vector3.DOWN*(4.45*s)
  "frost_cataclysm":
   # A cold front rolls low before its curling vapour rises; ice arrives separately.
   var x:=-2.9+5.8*s
   var z:=float(j-3)*.46+sin(s*6.0+j*.8)*.27
   return Vector3(x,.16+sin(s*PI)*(.6+.1*j)+s*s*1.2+maxf(0.0,q-2.0)*.58,z)
  "gravity_collapse":
   if j<4:
    var angle:=a+s*3.6
    var r:=3.7*pow(1.0-s,1.35)+.10
    return Vector3(cos(angle)*r,.2+sin(s*PI)*1.15+s*1.05,sin(angle)*r)
   var r:=s*(3.1+.2*float(j%2))
   var bend:=a+sin(s*PI)*.7
   return Vector3(cos(bend)*r,1.25+sin(s*PI)*2.2-s*1.08,sin(bend)*r)
  "earth_rift":
   var x:=-2.4+float(j)*.78+sin(s*PI)*cos(a)*.75
   var z:=sin(float(j)*.8)*.7+sin(s*6.0+j)*s*.35
   return Vector3(x,.05+2.50*s+sin(s*PI)*(.35+float(j%3)*.19)+maxf(0.0,q-1.9)*.38,z)
  "plasma_breaker":
   if j<2:
    var angle:=s*TAU*1.65+j*PI
    return Vector3(-3.1+4.0*s,1.6+sin(angle)*(.15+.35*sin(s*PI)),cos(angle)*(.15+.40*sin(s*PI)))
   var fan:=float(j-4)*.43
   return Vector3(.9+s*2.7,1.5+sin(s*PI)*(.7+absf(fan))-.9*s,fan*s*2.45+sin(s*9.0+j)*.16)
  "tidal_slam":
   # Rolling shoulder arches over. The old belly falls after its local crest passes.
   var x:=-2.55+5.05*s
   var y:=.13+sin(s*PI)*3.35-pow(maxf(0.0,s-.55),2.0)*4.5
   y=maxf(.06,y-maxf(0.0,q-2.20)*(.25+.7*s))
   return Vector3(x,y,float(j-3)*.40+sin(s*7.0+j)*.22)
  "fire_lance":
   return Vector3(-2.3+5.2*s,1.4+sin(s*PI)*.3+maxf(0.0,q-1.9)*.8, sin(s*9.0+j)*(.09+.18*sin(s*PI))+float(j-1)*.1)
  "ice_shot":
   return Vector3(-2.5+5.0*s,1.55+sin(s*PI)*.35+maxf(0.0,q-2.0)*.4,float(j-1)*.15+sin(s*7.0+j)*.15)
  "chain_arc":
   var segment:=float(j/2)
   var x:=-2.5+segment*1.65+s*2.10
   var y:=1.1+sin(segment*1.9)*.5+sin(s*PI)*(.25+.12*sin(q*5.0+j))+sin(s*10.0+floor(q*8.0)+j)*.06
   if j%2==1:
    x=-2.5+segment*1.65+.8+s*.95
    y+=s*(.85 if j%4==1 else -.72)
   return Vector3(x,y,sin(s*10.0+j+q*5.0)*.05+sin(s*PI)*.12+s*(.5 if j%2==1 else 0.0))
  "cross_cut":
   var odd:=j%2==1
   var x:=-2.45+4.9*s
   var y:=.35+2.6*(1.0-s if odd else s)+sin(s*PI)*.30
   return Vector3(x,y,(-.28 if odd else .28)+sin(s*PI)*.46+float(j/2)*.2)
  "shield_break":
   # Crown leaks across a convex shield, then escaping energy moves outward/down.
   var angle:=-1.25+float(j)*.61+s*.58
   var r:=1.1+s*.7
   return Vector3(cos(angle)*r,1.7+sin(angle)*r-maxf(0.0,q-1.55)*s*.95,.26+sin(s*PI)*.85+s*.65)
  "sonic_punch":
   var beat:=float(j/2)
   var angle:=(float(j%2)*PI)+s*PI*1.3+beat*.45
   var r:=.20+s*(.72+beat*.46)
   return Vector3(-1.65+s*(2.8+beat*.58),1.45+sin(angle)*r,cos(angle)*r)
 return Vector3.ZERO

func _pose_solids(t: float) -> void:
 var solid_kind:=_variant in ["frost_cataclysm","ice_shot","earth_rift","comet_crash","shield_break"]
 for i in 18:
  var q:=t-(.68+float(i%6)*.09 if _variant=="frost_cataclysm" else 1.95+float(i%6)*.04 if _variant=="ice_shot" else 1.30+float(i%6)*.04 if _variant in ["shield_break","comet_crash"] else .65+float(i%7)*.15)
  var active:=solid_kind and q>0.0 and q<life-1.5
  var a:=float(i)*2.4
  var p:=Vector3(cos(a)*.65,.25,sin(a)*.65)
  var dia:=.10+float(i%3)*.045
  if _variant=="frost_cataclysm":
   p=Vector3(-2.0+float(i%6)*.8,.05,float(i/6-1)*.65)
   p+=Vector3(cos(a)*.62,1.55+float(i%3)*.23,sin(a)*.64)*maxf(q-.40,0.0)+Vector3.DOWN*1.85*pow(maxf(q-.40,0.0),2.0)
   dia=.30+float(i%3)*.07
  elif _variant=="shield_break":
   var yy:=float(i%6)*.42+.4
   p=Vector3(float(i/6-1)*.55+(float(i%2)*.13),yy,.28+.19*pow(float(i/6-1),2.0))
   p+=Vector3(cos(a)*1.3,.52,sin(a)*.75+1.0)*maxf(q,0.0)+Vector3.DOWN*1.8*pow(maxf(q,0.0),2.0)
   dia=.43+float(i%3)*.035
   if t>.25 and q<=0.0:active=true
  elif _variant=="ice_shot":
   p=Vector3(2.25,1.5,0.0)+Vector3(cos(a)*1.3,sin(a)*.75+.45,sin(a)*1.1)*q+Vector3.DOWN*1.8*q*q
   dia=.18+float(i%3)*.06
   if t>.25 and t<2.08 and i<6:
    var head:=clampf((t-.20)/1.85,0.0,1.0)
    p=Vector3(-2.5+5.0*head-float(i%3)*.13,1.55+sin(head*PI)*.35+cos(a)*.16,sin(a)*.15)
    dia=.23+float(i%3)*.055
    active=true
  else:
   p+=Vector3(cos(a)*1.3,1.65+float(i%4)*.14,sin(a)*1.6)*q+Vector3.DOWN*2.2*q*q
  var landed:=p.y<.035
  p.y=maxf(.025,p.y)
  if landed and q>1.50:active=false # settled fragments sink below the floor, not float/fade
  put(_solids,i,p*_size,dia*_size if active else 0.0,_colors[1 if _variant in ["earth_rift","comet_crash"] else 2],.12 if _variant=="frost_cataclysm" else .04,.035*_size)
  if active:
   var trans:=_solids.get_instance_transform(i)
   var turn:=Vector3(q*(1.2+i*.11),a+q*.83,q*.6)
   if _variant=="shield_break" and q<0.0:turn=Vector3(0.0,float(i/6-1)*.17,PI if i%2==1 else 0.0)
   if _variant=="ice_shot" and t<2.08:turn=Vector3(0,0,-PI/2.0+a*.07)
   trans.basis=Basis.from_euler(turn)*Basis.from_scale(Vector3(dia*.55,dia*(1.65 if _variant in ["frost_cataclysm","ice_shot"] else 1.0),dia)*_size)
   _solids.set_instance_transform(i,trans)

func _tube(points: PackedVector3Array,radius: float,widths: PackedFloat32Array,t: float,j: int,k: int) -> ArrayMesh:
 var st:=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rows: Array=[]
 for i in points.size():
  var tangent: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
  var across:=tangent.cross(Vector3.BACK).normalized()
  if across.length_squared()<.1:across=Vector3.RIGHT
  var depth:=tangent.cross(across).normalized()
  var row:=PackedVector3Array()
  for n in 9:
   var a:=float(n)/8.0*TAU
   var lump:=1.0+.20*sin(a*3.0-float(i)*.43-t*3.0+j+k*.7)
   row.append(points[i]+(across*cos(a)+depth*sin(a))*radius*widths[i]*lump)
  rows.append(row)
 for i in points.size()-1:
  for n in 8:
   for c: Array in [[i,n],[i+1,n],[i,n+1],[i,n+1],[i+1,n],[i+1,n+1]]:
    st.set_uv(Vector2(float(c[1])/8.0,float(c[0])/float(points.size()-1)))
    st.add_vertex(rows[c[0]][c[1]])
 st.generate_normals()
 return st.commit()

func _shield_surface(t: float,k: int) -> ArrayMesh:
 var st:=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for y in 9:
  for x in 8:
   for c: Vector2 in [Vector2(x,y),Vector2(x+1,y),Vector2(x,y+1),Vector2(x,y+1),Vector2(x+1,y),Vector2(x+1,y+1)]:
    var u:=c.x/8.0
    var v:=c.y/9.0
    var xx:=(u-.5)*2.15
    var yy:=.16+v*2.8
    var z:=.28+k*.12+.34*sin(u*PI)+sin(v*PI)*.13*sin(t*5.0-v*7.0+k)
    st.set_uv(Vector2(u,v))
    st.add_vertex(Vector3(xx,yy,z)*_size)
 st.generate_normals()
 return st.commit()

func _panel_mesh() -> ArrayMesh:
 var st:=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var p: Array=[Vector3(-.6,-.55,0),Vector3(.6,-.55,0),Vector3(0,.65,0),Vector3(0,-.1,-.12)]
 for f: Array in [[0,1,2],[0,3,1],[1,3,2],[2,3,0]]:
  for v: int in f:st.add_vertex(p[v])
 st.generate_normals()
 return st.commit()

func _shard_mesh() -> ArrayMesh:
 var st:=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var p: Array=[Vector3(0,1,0),Vector3(0,-.6,0),Vector3(.65,0,0),Vector3(0,.05,.6),Vector3(-.6,0,0),Vector3(0,-.1,-.55)]
 for f: Array in [[0,2,3],[0,3,4],[0,4,5],[0,5,2],[1,3,2],[1,4,3],[1,5,4],[1,2,5]]:
  for v: int in f:st.add_vertex(p[v])
 st.generate_normals()
 return st.commit()
