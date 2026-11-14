extends Node3D
# Star-sea ground choreography. The six systems are semantically different:
# source marks -> inward supply -> orientation -> writing -> response -> spent vapor.
# Marks drain along their strokes, paths finish travelling, dial sectors sweep away,
# writing sinks in reading order, echoes escape outwards, vapor rises and dilutes.
# All geometry is evaluated from the caller's age. No autonomous clock or Tween.
const INK := preload("res://pixel_vfx/ultimate/shaders/floor_ink.gdshader")
const TEAL := Color(.10,.60,.67,.75)
const GOLD := Color(.73,.52,.22,.72)
const BLUE := Color(.15,.27,.55,.58)
const VIOLET := Color(.37,.22,.60,.60)
const GLYPHS := [0b010111101101010,0b111010111010010,0b101101010010111,0b010101111101101,0b110100111001011,0b111001010100111,0b101010111010101,0b011100110100011]
var _size := 1.0
var _nodes: Array[MeshInstance3D] = []
var _v := PackedVector3Array()
var _c := PackedColorArray()
var _uv := PackedVector2Array()
var _ix := PackedInt32Array()

func setup(size: float) -> void:
 _size = size
 for k in 6:
  var n := MeshInstance3D.new()
  var m := ShaderMaterial.new()
  m.shader = INK
  m.set_shader_parameter("vapor",1.0 if k == 5 else 0.0)
  n.material_override = m
  n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  n.extra_cull_margin = 8.0 * size
  add_child(n)
  _nodes.append(n)
 update(0.0)

func _begin() -> void:
 _v = PackedVector3Array(); _c = PackedColorArray()
 _uv = PackedVector2Array(); _ix = PackedInt32Array()

func _finish(k: int) -> void:
 _nodes[k].visible = not _v.is_empty()
 if _v.is_empty(): return
 var a := []
 a.resize(Mesh.ARRAY_MAX)
 a[Mesh.ARRAY_VERTEX] = _v; a[Mesh.ARRAY_COLOR] = _c
 a[Mesh.ARRAY_TEX_UV] = _uv; a[Mesh.ARRAY_INDEX] = _ix
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
 _nodes[k].mesh = mesh

func _quad(a: Vector3,b: Vector3,c: Vector3,d: Vector3,col: Color,u: float = 0.0) -> void:
 if col.a <= .002: return
 var q := _v.size()
 for p in [a,b,c,d]:
  var snapped := Vector3(snappedf(p.x,.035),p.y,snappedf(p.z,.035))
  _v.append(snapped * _size); _c.append(col)
 _uv.append_array(PackedVector2Array([Vector2(u,0),Vector2(u,1),Vector2(u+.05,0),Vector2(u+.05,1)]))
 _ix.append_array(PackedInt32Array([q,q+1,q+2,q+2,q+1,q+3]))

func _line(a: Vector3,b: Vector3,w: float,col: Color,u: float = 0.0) -> void:
 var side := (b-a).cross(Vector3.UP).normalized()*w
 _quad(a-side,a+side,b-side,b+side,col,u)

func _polar(r: float,a: float,y: float = .05) -> Vector3:
 return Vector3(cos(a)*r,y,sin(a)*r)

func _origin(k: int) -> Vector3:
 return [Vector3(-3.45,.05,2.30),Vector3(3.45,.05,2.30),Vector3(-3.8,.05,.2),Vector3(3.8,.05,.2),Vector3(-2.8,.05,-2.5),Vector3(2.8,.05,-2.5)][k]

func _tint(c: Color,a: float) -> Color:
 return Color(c.r,c.g,c.b,c.a*clampf(a,0,1))

func _window(t: float,a: float,b: float,ramp: float = .5) -> float:
 return smoothstep(a,a+ramp,t)*(1.0-smoothstep(b-ramp,b,t))

func update(t: float) -> void:
 if _nodes.is_empty(): return
 if t >= 21.5:
  for n in _nodes: n.visible = false
  return
 _marks(t); _supply(t); _dial(t); _writing(t); _echoes(t); _vapor(t)

func _marks(t: float) -> void:
 _begin()
 # Six offset, open source knots. Each is drawn stroke-by-stroke, not scaled.
 var knot := [Vector2(-.30,-.15),Vector2(0,-.46),Vector2(.30,-.15),Vector2(.10,.02),Vector2(.27,.31),Vector2(0,.17),Vector2(-.26,.34),Vector2(-.09,.01),Vector2(-.30,-.15)]
 for k in 6:
  var origin := _origin(k)
  var a := atan2(origin.z,origin.x)
  var birth := .25 + float(k)*.31
  var draw := (t-birth)*5.3
  var drain := (t-16.0-float(k)*.25)*4.0
  for j in knot.size()-1:
   var head := clampf(draw-float(j),0,1)
   var tail := clampf(drain-float(j),0,1)
   if head <= tail: continue
   var aa: Vector2 = knot[j].lerp(knot[j+1],tail)*1.62
   var bb: Vector2 = knot[j].lerp(knot[j+1],head)*1.62
   var p := origin+Vector3(aa.x*cos(a)-aa.y*sin(a),0,aa.x*sin(a)+aa.y*cos(a))
   var q := origin+Vector3(bb.x*cos(a)-bb.y*sin(a),0,bb.x*sin(a)+bb.y*cos(a))
   var energy := .73 + .19*sin((t-birth)*1.9+float(j)*.4)
   _line(p,q,.105 if j%3 == 0 else .06,_tint(TEAL,energy))
  # Broad inner strokes make each source a legible glyph, not a wire ornament.
  var branches := [[Vector2(-.30,.04),Vector2(.29,.04)],[Vector2(0,-.29),Vector2(0,.27)],[Vector2(-.22,-.24),Vector2(.19,.20)]]
  for j in 3:
   var head := clampf((t-birth-.85-float(j)*.16)*3.5,0,1)
   var tail := clampf((t-16.2-float(k)*.25-float(j)*.12)*2.5,0,1)
   if head <= tail: continue
   var aa: Vector2 = branches[j][0].lerp(branches[j][1],tail)
   var bb: Vector2 = branches[j][0].lerp(branches[j][1],head)
   var p := origin+Vector3(aa.x*cos(a)-aa.y*sin(a),.02,aa.x*sin(a)+aa.y*cos(a))
   var q := origin+Vector3(bb.x*cos(a)-bb.y*sin(a),.02,bb.x*sin(a)+bb.y*cos(a))
   _line(p,q,.105,_tint(GOLD if j == 0 else TEAL,.88))
  # Small square reticles punctuate arrivals without filling the symbol.
  for j in 3:
   var arrive := 4.4+float(k)*.15+float(j)*3.7
   var strength := _window(t,arrive,arrive+.95,.22)
   var p := origin + _polar(.77,a+float(j)*TAU/3.0,.015)
   _line(p-Vector3(.19,0,0),p+Vector3(.19,0,0),.055,_tint(GOLD,strength))
 _finish(0)

func _path(k: int,q: float) -> Vector3:
 var origin := _origin(k)
 var a := atan2(origin.z,origin.x)
 var turn := .24*sin(q*PI)+.065*sin(q*PI*3.0+float(k))
 var r := lerpf(Vector2(origin.x,origin.z).length(),.46,q)
 return _polar(r,a+turn,.075+.10*sin(q*PI))

func _supply(t: float) -> void:
 _begin()
 for k in 6:
  for pulse in 7:
   var birth := 2.35+float(k)*.18+float(pulse)*1.82
   if birth > 15.4: continue
   var age := t-birth
   var head := age/1.65
   var tail := (age-.55)/1.65
   for j in 34:
    var q := float(j)/34.0
    if q < tail or q > head or age < 0: continue
    var u := clampf((q-tail)/(head-tail),0,1)
    var width := .035+.085*pow(sin(u*PI),.65)
    var col := _tint(TEAL,.32+.56*sin(u*PI))
    _line(_path(k,q),_path(k,minf(q+1.0/34.0,1.0)),width,col,q)
    if u > .68 and u < .86:
     _line(_path(k,q)+Vector3(0,.016,0),_path(k,minf(q+1.0/34.0,1.0))+Vector3(0,.016,0),.014,_tint(GOLD,.52),q)
 _finish(1)

func _dial(t: float) -> void:
 _begin()
 for sector in 12:
  var a := float(sector)*TAU/12.0 + .006*t
  var birth := 5.4+float(sector%4)*.32
  var head := clampf((t-birth)/1.1,0,1)
  var tail := clampf((t-17.0-float(sector%4)*.33)/1.35,0,1)
  if head <= tail: continue
  for layer in 2:
   var radius := 4.25 + float(layer)*.25
   for j in 18:
    var u := float(j)/18.0
    if u < tail or u > head: continue
    var aa := a+.075+u*.32
    _line(_polar(radius,aa,.045),_polar(radius,aa+.32/18.0,.045),.043 if layer == 0 else .024,_tint(GOLD if sector%3 == 0 else BLUE,.78),u)
  # Radial combs are restricted to the rear half so the foreground stays open.
  if sin(a) < .2:
   for j in 4:
    var u := float(j)/4.0
    if u < tail or u > head: continue
    var aa := a+.12+u*.25
    _line(_polar(4.03,aa),_polar(4.16-float(j%2)*.06,aa),.024,_tint(TEAL,.45))
 _finish(2)

func _writing(t: float) -> void:
 _begin()
 # Six discontinuous inscription lines, with a central aisle left clear.
 for row in 6:
  var side := -1.0 if row%2 == 0 else 1.0
  var z_pos: float = [-.8,.65,3.35][row/2]
  var origin := Vector3(side*(2.25 if row >= 4 else 3.02),.055,z_pos)
  for ch in 4:
   var onset := 7.0+float(row)*.22+float(ch)*.115
   var finish := 17.3+float(row)*.21+float(ch)*.14
   var a := _window(t,onset,finish,.22)
   if a <= 0: continue
   var sink := smoothstep(finish-.65,finish,t)
   var bits: int = GLYPHS[(ch+row*3)%GLYPHS.size()]
   for y in 5:
    for x in 3:
     if (bits & (1 << (y*3+x))) == 0: continue
     var px := origin.x + side*(float(ch)*.40+float(x)*.105)
     var z := origin.z + float(y)*.105 + sink*.22
     var p := Vector3(px,.055-sink*.046,z)
     _quad(p,p+Vector3(.10,0,0),p+Vector3(0,0,.10),p+Vector3(.10,0,.10),_tint(GOLD if row == 2 else VIOLET,a*.92))
 _finish(3)

func _echoes(t: float) -> void:
 _begin()
 for pulse in 3:
  var age: float = t-[10.4,12.6,14.3][pulse]
  if age < 0 or age > 3.65: continue
  for petal in 6:
   var lag := float(petal%3)*.085
   var travel := (age-lag)/3.4
   if travel < 0 or travel > 1: continue
   var angle := float(petal)*TAU/6.0+.46+float(pulse)*.10
   var radius := .7+travel*4.4
   var intensity := sin(clampf(travel*2.4,0,1)*PI*.5)*(1.0-smoothstep(.70,1,travel))
   for j in 18:
    var u := float(j)/18.0
    var span := .47*(1.0-.25*travel)
    var aa := angle+(u-.5)*span
    var bb := angle+(u+1.0/18.0-.5)*span
    var bow := .23*sin(u*PI)
    var p := _polar(radius+bow,aa,.085+.11*sin(travel*PI)*sin(u*PI))
    var q := _polar(radius+.23*sin((u+1.0/18.0)*PI),bb,p.y)
    _line(p,q,.055+.36*pow(sin(u*PI),2.0)*(1.0-travel*.35),_tint(TEAL if pulse != 1 else GOLD,intensity*.75),u)
 _finish(4)

func _vapor(t: float) -> void:
 _begin()
 for k in 6:
  var birth := 16.1+float(k)*.26
  var age := t-birth
  if age < 0 or age > 3.5: continue
  var origin := _origin(k)
  var a := atan2(origin.z,origin.x)
  var base_radius := Vector2(origin.x,origin.z).length()
  var lo := maxf(0.0,(age-.95)/2.4)
  var hi := minf(1.0,age/2.4)
  for j in 22:
   var q := float(j)/22.0
   if q < lo or q > hi: continue
   var next := minf(1.0,q+1.0/22.0)
   var emit := age-q*2.4
   var shoulder := sin(clampf(emit/.95,0,1)*PI)
   var p := _polar(base_radius+q*.55,a+.23*q+.055*sin(q*9.0+float(k)),.10+q*q*.75)
   var r := _polar(base_radius+next*.55,a+.23*next+.055*sin(next*9.0+float(k)),.10+next*next*.75)
   var w := (.09+q*.42)*maxf(0.0,shoulder)
   var up := Vector3(0,w*(.6+q),0)
   var side := Vector3(cos(a),0,sin(a))*w*.45
   var col := _tint(Color(.13,.25,.34,.21),(1.0-q)*shoulder)
   _quad(p-up-side,p+up+side,r-up-side,r+up+side,col,q)
 _finish(5)
