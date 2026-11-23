extends "res://pixel_vfx/px_base.gd"
# Echo energy: bowed stitch head -> delayed echo -> alternating cup -> unthreaded knot.
# .3/1.45/2.7 flights; cups unfold at contact, then open downward. No lifetime noise deletion.
# Main stitch / auxiliary cups+delayed return / local knot decoration. Native12fps.
var _size:=1.0
var _parts:Array=[]
var _light:OmniLight3D
const COLORS:=[Vector3(.012,.047,.065),Vector3(.03,.20,.26),Vector3(.12,.64,.68),Vector3(.63,1.65,1.3),Vector3(3.3,4.4,3.8)]
static func spawn(parent:Node,pos:Vector3,size:float=1.0,_variant:String="echo_stitch")->Node3D:
 var fx:Node3D=new()
 parent.add_child(fx)
 fx.global_position=pos
 fx.start(size)
 return fx
func start(size:float)->void:
 _size=maxf(size,.01)
 life=6.3
 for j in 17:
  var row:Array=[]
  for k in 3:
   var mi:=MeshInstance3D.new()
   var mat:=ShaderMaterial.new()
   mat.shader=load("res://pixel_vfx/pack50/shaders/echo_stitch.gdshader")
   for n in 5:mat.set_shader_parameter("pal_%d"%n,COLORS[n])
   mat.set_shader_parameter("shell",float(k))
   mat.set_shader_parameter("seed",float(j)*.71+k*.4)
   mi.material_override=mat
   mi.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   mi.extra_cull_margin=10
   add_child(mi)
   row.append(mi)
  _parts.append(row)
 _light=lamp(COLORS[3],11*_size)
 _light.position.y=1.3*_size
 _step(0)
func _step(t:float)->void:
 for j in 17:
  var start_time:=.30+float(j)*1.15 if j<3 else .55+float(j-3)*1.15 if j<6 else 1.40+float(j-6)*1.15 if j<9 else 1.35+float(j-9)*1.15
  if j>=11:start_time=.43+float((j-11)/2)*1.15+float(j%2)*.12
  var travel:=1.25 if j<3 or j>=11 else 1.4 if j<6 else .65 if j<9 else 1.5
  var span:=.78 if j<3 else .60 if j>=11 else .5 if j<6 else .74 if j<9 else .44
  for k in 3:
   var mi:MeshInstance3D=_parts[j][k]
   var q:=t-start_time-k*.055
   var h:=clampf(q/travel,0,1)
   var tail:=clampf((q-span)/travel,0,1)
   mi.visible=q>0 and tail<.999 and h-tail>.01
   if not mi.visible:continue
   var points:=PackedVector3Array()
   var widths:=PackedFloat32Array()
   for i in 27:
    var u:=float(i)/26
    var s:=lerpf(tail,h,u)
    points.append((_path(j,s,q)*_size).snapped(Vector3.ONE*.03*_size))
    var width:=.52+.31*sin(u*PI)+.16*sin(s*24-q*5+j)*sin(u*PI)
    widths.append(width*pow(maxf(sin(u*PI),0),.5)*pow(1-tail,.55))
   if j>=6 and j<9:
     for i in widths.size():widths[i]*=.78
   var radius:=.30 if j<3 else .13 if j>=11 else .18 if j<6 else .18 if j<9 else .14
   mi.mesh=_tube(points,radius*_size*[1.0,.62,.25][k],widths,t,j,k)
   param(mi,"phase",t)
   param(mi,"cooling",smoothstep(travel,travel+span,q))
 var active_beat:=clampi(int((t-.30)/1.15),0,2)
 _light.position=_path(active_beat,clampf((t-.30-active_beat*1.15)/1.25,0,1),t)*_size
 _light.light_energy=(exp(-pow((t-1.45)/.4,2))+exp(-pow((t-2.6)/.45,2))+exp(-pow((t-3.8)/.45,2)))*1.8
func _path(j:int,s:float,q:float)->Vector3:
 if j>=11:
  var beat:=int((j-11)/2)
  var anchor:=clampf(q/1.4-.12-float(j%2)*.10,0,1)
  var p:=_path(beat,anchor,q)
  var echo:=_path(beat+3,anchor,q+.12)
  return p.lerp(echo,s)+Vector3(sin(s*PI)*.10,0,sin(s*TAU)*.09)
 if j<6:
  var beat:=j if j<3 else j-3
  var sign_dir:=1.0 if beat%2==0 else -1.0
  var x:=sign_dir*(-2.7+5.4*s)
  var y:=1.0+sin(s*PI)*(2.45 if j<3 else 1.65)
  var z:=sin(s*TAU+beat*.7)*(.55 if j<3 else .8)
  y+=sin(s*17-q*4+beat)*sin(s*PI)*.13
  if j>=3:y-=maxf(q-1.1,0)*s*.28
  return Vector3(x,y,z)
 if j<9:
  var beat:=j-6
  var xx:=2.7 if beat%2==0 else -2.7
  var a:=(-.15+s*.95)*PI
  var r:=.70+s*.37+maxf(q-.5,0)*.24
  return Vector3(xx+(s-.5)*1.9*(1.0 if beat%2==0 else -1.0),.72+sin(s*PI)*(.8+maxf(q-.4,0)*.18)-maxf(q-.65,0)*s*.85,sin(s*PI)*.68)
 var xx:=2.7 if j==9 else -2.7
 var zig:=sin(s*PI*4)*.24
 return Vector3(xx+(s-.5)*.65,1.15+zig-maxf(q-1.2,0)*s*.75,.15+s*.65)
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

