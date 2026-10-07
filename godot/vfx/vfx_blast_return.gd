extends "res://vfx/vfx_base.gd"
# Reference: supplied premium explosion / footage; cooling tongues return to their root,
# ground fire hands off to advected soot. Zero noise-hole layers.
const Ribbon := preload("res://vfx/vfx_ribbon.gd")
var _u:=1.0
var _frame:=-1
var _cap:MeshInstance3D
var _stem:MeshInstance3D
var _puffs:MultiMesh
var _smoke:MultiMesh
var _tongues:Array=[]
var _sparks:Array=[]
var _wisps:Array=[]
var _wave:MeshInstance3D
var _flash:MeshInstance3D
static func spawn(parent:Node,ground:Vector3,size:float=1.0)->Node3D:
 var fx:Node3D=new()
 fx.top_level=true
 parent.add_child(fx)
 fx.global_position=ground
 fx.start(size)
 return fx
func _mat(name:String)->ShaderMaterial:
 var m:=ShaderMaterial.new()
 m.shader=load("res://vfx/shaders/blast_return_"+name+".gdshader")
 return m
func _surface(stem:bool)->MeshInstance3D:
 var n:=MeshInstance3D.new()
 n.mesh=_revolve(stem)
 n.material_override=_mat("surface")
 param(n,"stem",stem)
 n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(n)
 return n
func _cloud(count:int)->MultiMesh:
 var mm:=MultiMesh.new()
 mm.transform_format=MultiMesh.TRANSFORM_3D
 mm.use_colors=true
 mm.mesh=Lib.cloud_mesh(1)
 mm.instance_count=count
 var n:=MultiMeshInstance3D.new()
 n.multimesh=mm
 n.material_override=_mat("smoke")
 n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 n.custom_aabb=AABB(Vector3(-9,0,-9)*_u,Vector3(18,15,18)*_u)
 add_child(n)
 return mm
func start(size:float)->void:
 _u=maxf(size,0.05)
 life=3.8
 _cap=_surface(false)
 _stem=_surface(true)
 _puffs=_cloud(16)
 _smoke=_cloud(14)
 for i in 18:
  var r:=Ribbon.new()
  r.material_override=_mat("stroke")
  add_child(r)
  _tongues.append(r)
 for i in 24:
  var r:=Ribbon.new()
  r.material_override=_mat("stroke")
  add_child(r)
  _sparks.append(r)
 for i in 3:
  var r:=Ribbon.new()
  r.material_override=_mat("stroke")
  add_child(r)
  _wisps.append(r)
 _wave=MeshInstance3D.new()
 var torus:=TorusMesh.new()
 torus.inner_radius=0.94
 torus.outer_radius=1.06
 torus.rings=64
 torus.ring_segments=12
 _wave.mesh=torus
 _wave.material_override=_mat("surface")
 add_child(_wave)
 _flash=sprite(2,Color(10,7,2),_u)
 _flash.position.y=0.7*_u
 param(_flash,"toward_camera",_u*1.5)
 _pose(0)
func _tick(_delta:float)->void:
 var f:=int(age*15)
 if f!=_frame:
  _frame=f
  _pose(float(f)/15)
func _hot(k:float)->Color:
 if k<0.25:return Color(8,6,2).lerp(Color(5,2.1,0.09),k*4)
 if k<0.65:return Color(5,2.1,0.09).lerp(Color(2.6,0.35,0.02),(k-0.25)/0.4)
 return Color(2.6,0.35,0.02).lerp(Color(0.5,0.04,0.01),(k-0.65)/0.35)
func _pose(t:float)->void:
 var g:=ease_out(clampf((t-0.02)/0.32,0,1))*(1+minf(t,0.8)*0.19)
 var ret:=clampf((t-0.8)/1.15,0,1)
 _cap.visible=t>0.04 and ret<0.99
 _cap.position=Vector3(0.12*sin(t*2),(0.55+2.5*minf(g,1)+minf(t,0.8)*0.6-0.5*ret)*_u,0)
 _cap.scale=Vector3(2.25,4.6,2.1)*_u*maxf(g,0.04)
 _stem.visible=t>0.04 and t<1.55
 _stem.scale=Vector3(1.25,_cap.position.y/_u,1.15)*_u
 for n in [_cap,_stem]:
  param(n,"phase",t)
  param(n,"heat",1-ret)
  param(n,"return_amount",ret if n==_cap else clampf((t-0.75)/0.8,0,1))
 _flash.visible=t<0.14
 _flash.scale=Vector3.ONE*_u*(0.5+4.5*ease_out(clampf(t/0.14,0,1)))
 param(_flash,"color",Color(10,7,2,maxf(0,1-t/0.14)))
 _wave.visible=t>=0.3 and t<1.6
 var wa:=maxf(0,t-0.3)
 var wr:=1.8+4.2*ease_out(clampf(wa/1.65,0,1))
 var collapse:=clampf((t-0.75)/0.85,0,1)
 _wave.position.y=(2.3+wa)*_u
 _wave.scale=Vector3(wr,wr*0.55*pow(1-collapse,2)+0.003,wr)*_u
 param(_wave,"heat",1-collapse)
 param(_wave,"return_amount",0)
 for i in 16:
  var a:=i*2.39996
  var root:=Vector3(cos(a),0,sin(a))*(0.3+1.8*g+minf(t,0.8)*0.55)
  root.y=0.35+g*(0.15+_hash(i)*0.3)
  var k:=clampf((t-0.8-float(i%4)*0.11)/0.85,0,1)
  var s:=Vector3(2.3,1.65,2.2)*(0.6+_hash(i+8)*0.65)*maxf(g,0.01)
  root.x*=1-k*0.4
  root.z*=1-k*0.4
  s*=Vector3(pow(1-k,0.7),pow(1-k,1.5),pow(1-k,0.7))
  _puffs.set_instance_transform(i,Transform3D(Basis.from_scale(s*_u),root*_u))
  var c:=_hot(k)
  c.a=1.0 if k<0.99 else 0.0
  _puffs.set_instance_color(i,c)
 for i in 14:
  var born:=0.8+float(i%4)*0.11
  var dt:=maxf(0,t-born)
  var k:=clampf(dt/(2.0-float(i%3)*0.13),0,1)
  var a:=i*2.39996
  var p:=Vector3(cos(a),0,sin(a))*(1.2-0.7*k)
  p.x+=0.45*dt+0.18*sin(dt*2+i)
  p.y=0.7+float(i%3)*0.8+dt*1.35
  var grow:=ease_out(clampf(dt/0.3,0,1))
  var s:=Vector3(1.35*(1-0.8*k),0.8+1.3*k,1.1*(1-0.8*k))*grow
  _smoke.set_instance_transform(i,Transform3D(Basis.from_scale(s*_u),p*_u))
  _smoke.set_instance_color(i,Color(0.32,0.28,0.25,pow(1-k,1.4)*grow if t>=born else 0.0))
 for i in _tongues.size():
  var r:MeshInstance3D=_tongues[i]
  var delay:=float(i%3)*0.05
  var k:=clampf((t-0.8-delay)/0.85,0,1)
  r.visible=t>0.1+delay and k<0.99
  if not r.visible:continue
  var a:=i*2.39996
  var dir:=Vector3(cos(a),0,sin(a))
  var length:=(1.5+_hash(i)*1.5)*g*(1-k)
  var pts:=PackedVector3Array()
  for j in 10:
   var q:=float(j)/9
   var p:=dir*(0.5+q*length)
   p.y=2.5+0.45*g+sin(q*PI)*(0.8*(1-k))+q*(1-k)*(0.8+_hash(i+4))-k*0.3
   p+=Vector3(-sin(a),0,cos(a))*sin(q*PI)*sin(t*5+i)*0.3*(1-k)
   pts.append(global_position+p*_u)
  r.draw(pts)
  param(r,"width",_u*(0.35+_hash(i)*0.2)*(1-k))
  param(r,"heat",1-k)
 for i in _wisps.size():
  var r:MeshInstance3D=_wisps[i]
  var dt:=t-1.05-float(i)*0.09
  var k:=clampf(dt/0.85,0,1)
  r.visible=dt>0 and k<0.99
  if not r.visible:continue
  var pts:=PackedVector3Array()
  for j in 10:
   var q:=float(j)/9
   var p:=Vector3((i-1)*0.28+sin(q*4+dt*3+i)*0.16*sin(q*PI),2.0+dt*1.5+q*(0.9-0.65*k),0.1*cos(q*4+i))
   pts.append(global_position+p*_u)
  r.draw(pts)
  param(r,"width",_u*0.32*pow(1-k,1.4))
  param(r,"heat",(1-k)*0.55)
 for i in _sparks.size():
  var r:MeshInstance3D=_sparks[i]
  var born:=0.08+float(i%4)*0.04
  var dt:=t-born
  var duration:=0.8+_hash(i)*0.4
  r.visible=dt>0 and dt<duration
  if not r.visible:continue
  var a:=i*2.39996
  var v:=Vector3(cos(a)*(3+_hash(i)*3),4+_hash(i+4)*4,sin(a)*(3+_hash(i)*3))
  var pts:=PackedVector3Array()
  for j in 8:
   var past:=maxf(0,dt-float(j)/7*0.15)
   var p:=Vector3(0,0.5,0)+v*past+Vector3(0,-5.5*past*past,0)
   pts.append(global_position+p*_u)
  r.draw(pts)
  param(r,"width",_u*0.1*pow(1-dt/duration,0.7))
  param(r,"heat",1-dt/duration)



static func _revolve(stem: bool) -> ArrayMesh:
 var rings := 18
 var sides := 64
 var points := PackedVector3Array()
 var uv := PackedVector2Array()
 for j in range(rings + 1):
  var v := float(j) / rings
  for i in range(sides + 1):
   var u := float(i) / sides
   var a := u * TAU
   var r := 0.17 + 0.13 * sin(v * PI) + 0.35 * pow(v, 4) if stem else pow(sin(v * PI), 0.55)
   r = maxf(r, 0.008)
   var lobe := 1.0 + 0.065 * sin(a * 7.0 + v * 4.0) + 0.025 * sin(a * 13.0 - v * 7.0)
   var y := v if stem else (v - 0.5) * 0.9 + 0.035 * sin(a * 6.0) * sin(v * PI)
   points.append(Vector3(cos(a) * r * lobe + (0.08 * sin(v * 4) if stem else 0.0), y, sin(a) * r * lobe))
   uv.append(Vector2(u, v))
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for j in rings:
  for i in sides:
   var a := j * (sides + 1) + i
   var b := a + sides + 1
   for id in [a, a + 1, b, a + 1, b + 1, b]:
    st.set_uv(uv[id])
    st.add_vertex(points[id])
 st.generate_normals()
 return st.commit()

static func _hash(i: int) -> float:
 return fposmod(sin(float(i) * 127.1 + 31.7) * 43758.5453, 1.0)



