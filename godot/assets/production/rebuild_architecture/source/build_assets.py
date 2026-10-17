"""Photo-led low-poly scenic architecture. Factory-startup Blender CLI only.
Authoring Z-up/front -Y -> GLB Godot Y-up/front +Z. Original GLBs are used
solely by measure_originals.py to retain the transformed vertex envelope.
"""
from pathlib import Path
import importlib.util,json,math,sys
import bpy,bmesh
from mathutils import Vector,Matrix
SOURCE=Path(__file__).resolve().parent
ROOT=SOURCE.parents[4]
ARTIFACTS=ROOT/'artifacts/rebuild-architecture'
spec=importlib.util.spec_from_file_location('architecture_fresh_helpers',SOURCE.parents[1]/'fresh_props/source/build_assets.py')
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f);h=f.h
material=h.material

def finish(obj,mat,bevel=0,smooth=False):
 obj.data.materials.append(mat)
 bpy.context.view_layer.objects.active=obj
 if bevel:
  mod=obj.modifiers.new('Single segment edge ease','BEVEL');mod.width=bevel;mod.segments=1;mod.limit_method='ANGLE'
  bpy.ops.object.modifier_apply(modifier=mod.name)
 if smooth:
  for p in obj.data.polygons:p.use_smooth=True
  mod=obj.modifiers.new('Weighted planar normals','WEIGHTED_NORMAL');mod.keep_sharp=True
  bpy.ops.object.modifier_apply(modifier=mod.name)
 h.PARTS.append(obj);return obj
h.finish=finish
box=h.box

def mesh(name,vs,fs,mat,bevel=0):
 data=bpy.data.meshes.new(name);data.from_pydata(vs,[],fs);data.update()
 obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
 return finish(obj,mat,bevel)

def profile(name,pts,y,depth,mat,bevel=.004):
 return h.extruded_profile(name,pts,y,depth,mat,bevel)

def beam(name,a,b,w,d,mat,bevel=.004):
 a,b=Vector(a),Vector(b)
 obj=box(name,(a+b)/2,(w,d,(b-a).length),mat,bevel)
 obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return obj

def cyl(name,at,r,length,mat,direction=(0,0,1),sides=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=r,depth=length,location=at)
 o=bpy.context.object;o.name=name;o.rotation_euler=Vector(direction).to_track_quat('Z','Y').to_euler()
 return finish(o,mat,0,True)

def tube(name,pts,r,mat,sides=6,closed=False):
 # Explicit transported-frame tube: exactly six sides for small tubes.
 vs=[];n=len(pts)
 for i,p in enumerate(pts):
  t=Vector(pts[min(i+1,n-1)])-Vector(pts[max(i-1,0)])
  if closed:t=Vector(pts[(i+1)%n])-Vector(pts[(i-1)%n])
  t.normalize();axis=Vector((1,0,0)) if abs(t.x)<.9 else Vector((0,1,0))
  a=(axis-t*axis.dot(t)).normalized();b=t.cross(a).normalized()
  for j in range(sides):vs.append(Vector(p)+r*(a*math.cos(j*math.tau/sides)+b*math.sin(j*math.tau/sides)))
 fs=[]
 for i in range(n if closed else n-1):
  for j in range(sides):fs.append((i*sides+j,i*sides+(j+1)%sides,((i+1)%n)*sides+(j+1)%sides,((i+1)%n)*sides+j))
 if not closed:fs += [tuple(reversed(range(sides))),tuple((n-1)*sides+j for j in range(sides))]
 return mesh(name,vs,fs,mat)

def ring(name,c,outer,inner,depth,mat,n=16):
 x,y,z=c;vs=[]
 for yy in (y-depth/2,y+depth/2):
  for r in (outer,inner):
   vs += [(x+r*math.cos(i*math.tau/n),yy,z+r*math.sin(i*math.tau/n)) for i in range(n)]
 fs=[]
 for i in range(n):
  j=(i+1)%n;fs += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
 return mesh(name,vs,fs,mat)

def lathe(name,prof,mat,n=24):
 vs=[(r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for r,z in prof for i in range(n)]
 fs=[tuple(reversed(range(n))),tuple((len(prof)-1)*n+i for i in range(n))]
 for j in range(len(prof)-1):
  for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
 return mesh(name,vs,fs,mat)

def palette():
 return dict(wood=material('Scenic framing warm bare timber','AD8658',.74),darkwood=material('Dark stained structural timber','654B33',.7),cream=material('Warm matte scenic paint','D9CDB1',.83),stone=material('Limestone painted foam','B9B19D',.91),stone2=material('Cut stone alternate wash','C9C0AA',.9),brick=material('Brick red scenic coating','9D5544',.87),brick2=material('Brick alternate terracotta','B46B53',.86),mortar=material('Mortar warm gray','8B8274',.95),steel=material('Dark painted steel','38434A',.48),metal=material('Bare brushed hardware','929B9B',.38,1),brass=material('Aged brass hardware','A98A48',.39,1),blue=material('Muted teal scenic paint','597A7C',.71),paper=material('Shoji warm rice paper','E9DFC7',.94),black=material('Deep recess charcoal','252A29',.94),red=material('Barn faded red paint','8B4338',.82))

def ticket(x,y,z):h.ticket_anchor((x,y,z))

def flat_back(w,height,y,depth,m,posts=None):
 # Exposed rear framing and two feet/jacks. No mysterious floating wall.
 posts=posts or [-w/2+.07,w/2-.07]
 for x in posts:
  box('Rear vertical stud',(x,y+.095,height/2),(.075,.075,height-.06),m,.003)
 for z in (.09,height-.08):box('Rear horizontal framing',(0,y+.095,z),(w,.075,.075),m,.003)
 for x in (-w/2+.13,w/2-.13):
  box('Scenic flat floor foot',(x,0,.035),(.13,depth,.07),m,.004)
  beam('Scenic rear diagonal jack',(x,y+.14,height*.60),(x,depth/2-.07,.07),.065,.065,m)

def door_jamb(w,height,m,y=0):
 for x in (-w/2,w/2):box('Door frame upright',(x,y,height/2),(.13,.22,height),m,.005)
 box('Door head casing',(0,y,height-.075),(w+.18,.24,.15),m,.005)

def wall_opening(w,height,opening,bottom,top,m,y=0,t=.1):
 side=(w-opening)/2
 for x in (-1,1):box('Scenic wall side', (x*(opening/2+side/2),y,height/2),(side,t,height),m,.005)
 if bottom>0:box('Scenic wall below opening',(0,y,bottom/2),(opening,t,bottom),m,.004)
 if top<height:box('Scenic wall above opening',(0,y,(top+height)/2),(opening,t,height-top),m,.004)

def rect_frame(name,w,bottom,top,y,thick,depth,mat,cx=0):
 for x in (cx-w/2,cx+w/2):box(name+' stile',(x,y,(bottom+top)/2),(thick,depth,top-bottom+thick),mat,.003)
 for z in (bottom,top):box(name+' rail',(cx,y,z),(w+thick,depth,thick),mat,.003)

def stone_arch(broken=False,sewer=False):
 m=palette();radius=1.10 if not sewer else .83;spring=2.04 if not sewer else 1.30
 width=2.8 if not sewer else 2.3;depth=.7 if not sewer else 1.42
 # Stacked piers with broad masonry joints, square plinths and impost caps.
 for s in (-1,1):
  x=s*radius
  box('Stone pier lower plinth',(x,0,.12),(.60 if not sewer else .55,depth,.24),m['stone'],.012)
  for i in range(5 if not sewer else 4):
   count=5 if not sewer else 4;dz=(spring-.26)/count
   box('Stone pier ashlar course',(x,0,.25+dz*(i+.5)),(.32 if not sewer else .40,.46 if not sewer else .85,dz-.012),m['stone2' if i%2 else 'stone'],.009)
  box('Stone arch impost',(x,0,spring-.035),(.5 if not sewer else .56,.60 if not sewer else 1.05,.16),m['stone2'],.008)
 count=11 if not sewer else 10
 for i in range(count):
  if broken and i in (4,5,6):continue
  a0=i*math.pi/count+.007;a1=(i+1)*math.pi/count-.007
  ro=radius+.16;ri=radius-.16
  pts=[(ri*math.cos(a0),spring+ri*math.sin(a0)),(ro*math.cos(a0),spring+ro*math.sin(a0)),(ro*math.cos(a1),spring+ro*math.sin(a1)),(ri*math.cos(a1),spring+ri*math.sin(a1))]
  profile('Radial arch voussoir',pts,0,.42 if not sewer else .90,m['stone2' if i%2 else 'stone'],.008)
 if broken:
  # Purposeful fractured final blocks and a few large fallen pieces only.
  for s in (-1,1):
   pts=[(s*.65,2.86),(s*.47,2.95),(s*.40,3.12),(s*.63,3.23),(s*.85,3.08)]
   profile('Jagged broken arch end',pts,0,.45,m['stone'],.009)
   o=box('Fallen masonry block',(s*.87,-.40,.16),(.48,.40,.30),m['stone2'],.035);o.rotation_euler.z=s*.22
 if sewer:
  box('Waterway threshold',(0,0,.075),(2.10,1.40,.15),m['stone'],.012)
  # Gate sits behind the opening and shows a blackened iron structure, not a dark filled plane.
  for x in (-.62,-.31,0,.31,.62):
   top=spring+math.sqrt(max(0,(radius-.20)**2-x*x))
   cyl('Sewer iron gate bar',(x,.28,(top+.15)/2),.026,top-.15,m['steel'],sides=6)
  for z in (.40,1.03):box('Gate horizontal strap',(0,.29,z),(1.55,.055,.065),m['steel'],.004)
 ticket(-radius,-(.237 if not sewer else .434),.75)

def column():
 m=palette();box('Square column plinth',(0,0,.14),(.90,.90,.28),m['stone'],.015)
 # Real radial profile, gently tapered shaft and restrained Doric mouldings.
 profile_points=[(.36,.28),(.36,.34),(.31,.40),(.30,.48),(.29,.52),(.27,2.43),(.31,2.48),(.34,2.52),(.37,2.60),(.40,2.63),(.40,2.68)]
 lathe('Tapered Doric shaft and turned mouldings',profile_points,m['stone2'])
 box('Square capital abacus',(0,0,2.775),(.86,.86,.19),m['stone'],.013)
 # Eight broad inset flute strips are deliberately omitted: silhouette and mouldings carry identity.
 ticket(.08,-.455,.20)

def chimney():
 m=palette();box('Chimney broad stone footing',(-.055,0,.13),(.85,.80,.26),m['mortar'],.015)
 # Each course has three broad bricks on front/back and two return bricks.
 for row in range(7):
  z=.29+row*.215;cx=-.055+max(0,row-4)*.085
  for y in (-.255,.255):
   for j in range(2):
    x=cx+(j-.5)*.275+( .065 if row%2 else 0)
    box('Staggered chimney brick',(x,y,z),(.263,.10,.197),m['brick2' if (row+j)%3==0 else 'brick'],.007)
  for s in (-1,1):box('Chimney return brick',(cx+s*.29,0,z),(.10,.41,.197),m['brick'],.007)
 # A crooked upper throat bends the masonry; open mouth has a thick stone cap rim.
 cx=.115;z=1.90
 for y in (-.33,.33):box('Chimney open coping front back',(cx,y,z),(.93,.15,.18),m['stone'],.012)
 for x in (cx-.39,cx+.39):box('Chimney open coping sides',(x,0,z),(.15,.51,.18),m['stone'],.012)
 box('Deep soot in open chimney',(cx,0,1.61),(.45,.40,.025),m['black'],0)
 ticket(-.10,-.315,.77)

def hinged_door():
 m=palette();wall_opening(2.4,2.5,1.02,0,2.22,m['cream']);flat_back(2.4,2.5,0,.94,m['wood'])
 door_jamb(1.06,2.28,m['darkwood'],-.065)
 # Framed and panelled leaf, closed in the theatrical frame.
 box('Door leaf solid timber',(0,-.045,1.09),(.94,.085,2.16),m['blue'],.006)
 for x in (-.37,.37):box('Door raised stile',(x,-.105,1.10),(.11,.045,2.13),m['blue'],.004)
 for z in (.13,.97,2.06):box('Door raised rail',(0,-.105,z),(.80,.045,.12),m['blue'],.004)
 for z,hh in ((.55,.66),(1.52,.90)):
  rect_frame('Door panel moulding',.62,z-hh/2,z+hh/2,-.112,.035,.027,m['cream'])
 for z in (.42,1.75):
  box('Door hinge leaf',(-.48,-.12,z),(.075,.018,.13),m['metal'],.002)
  cyl('Door hinge barrel',(-.51,-.14,z),.018,.15,m['metal'],sides=8)
 box('Door lock escutcheon',(.32,-.14,1.06),(.07,.025,.20),m['brass'],.005)
 cyl('Door knob stem',(.32,-.17,1.1),.022,.07,m['brass'],(0,1,0),8)
 cyl('Door broad round knob',(.32,-.208,1.1),.046,.038,m['brass'],(0,1,0),12)
 for z in (.12,2.37):box('Scenic wall trim',(0,-.067,z),(2.4,.035,.07),m['cream'],.003)
 ticket(-.83,-.061,1.35)

def saloon():
 m=palette();door_jamb(2.02,2.58,m['darkwood'])
 for x in (-1.08,1.08):
  box('Saloon jamb footing',(x,0,.04),(.20,.88,.08),m['wood'],.004)
  beam('Saloon rear brace',(x,.10,1.6),(x,.39,.08),.055,.055,m['wood'])
 for s in (-1,1):
  cx=s*.485
  # Curved top silhouette is built from one simple watertight profile.
  pts=[(cx-.43,.49),(cx+.43,.49),(cx+.43,1.56),(cx+.28,1.61),(cx+.08,1.75),(cx-.11,1.81),(cx-.31,1.78),(cx-.43,1.73)]
  if s<0:pts=[(-x,z) for x,z in reversed([( .485-.43,.49),(.485+.43,.49),(.485+.43,1.56),(.485+.28,1.61),(.485+.08,1.75),(.485-.11,1.81),(.485-.31,1.78),(.485-.43,1.73)])]
  profile('Saloon scalloped wood door',pts,-.02,.075,m['wood'],.006)
  for z in (.60,1.40):box('Saloon door broad rail',(cx,-.072,z),(.84,.04,.14),m['darkwood'],.004)
  for i in range(5):box('Saloon raised vertical board',(cx+(i-2)*.155,-.067,1.0),(.135,.025,.66),m['wood'],.003)
  for z in (.67,1.48):
   box('Saloon broad strap hinge',(s*.89,-.09,z),(.25,.025,.075),m['steel'],.003)
   cyl('Saloon hinge barrel',(s*.97,-.10,z),.023,.14,m['steel'],sides=8)
 ticket(.45,-.10,.60)

def cell_gate():
 m=palette();wall_opening(2.2,2.5,1.40,0,2.22,m['mortar']);flat_back(2.2,2.5,0,.925,m['wood'])
 door_jamb(1.45,2.3,m['steel'],-.07)
 for x in (-.61,-.40,-.20,0,.20,.40,.61):cyl('Vertical cell iron bar',(x,-.05,1.10),.027,2.15,m['steel'],sides=6)
 for z in (.11,.78,1.53,2.17):box('Welded gate cross strap',(0,-.07,z),(1.32,.06,.07),m['steel'],.004)
 box('Gate lock body',(.49,-.11,1.04),(.23,.10,.20),m['steel'],.008)
 box('Gate latch tongue',(.68,-.12,1.04),(.19,.07,.065),m['metal'],.003)
 for z in (.45,1.85):cyl('Gate hinge barrel',(-.72,-.1,z),.04,.19,m['metal'],sides=8)
 ticket(.49,-.17,1.04)

def barn():
 m=palette();door_jamb(2.7,2.7,m['darkwood'])
 for x in (-1.38,1.38):
  box('Barn frame foot',(x,0,.035),(.24,.925,.07),m['wood'],.004)
  beam('Barn frame jack',(x,.1,1.7),(x,.42,.07),.06,.06,m['wood'])
 for s in (-1,1):
  cx=s*.665
  for j in range(6):box('Barn vertical tongue groove plank',(cx+(j-2.5)*.205,0,1.25),(.195,.10,2.46),m['red'],.004)
  for z in (.20,1.25,2.31):box('Barn wide horizontal brace',(cx,-.075,z),(1.24,.055,.14),m['wood'],.004)
  beam('Barn diagonal timber brace',(cx-.53,-.08,.28),(cx+.53,-.08,2.23),.14,.05,m['wood'])
  for z in (.32,2.15):box('Barn broad iron strap hinge',(s*1.08,-.12,z),(.49,.022,.075),m['steel'],.004)
  x=s*.15
  box('Barn handle mounting',(x,-.095,1.18),(.085,.03,.25),m['steel'],.005)
  tube('Barn bent pull handle',[(x,-.12,1.09),(x,-.18,1.10),(x,-.18,1.25),(x,-.12,1.26)],.018,m['metal'])
 ticket(-.80,-.060,1.78)

def shoji():
 m=palette();door_jamb(2.4,2.5,m['darkwood'])
 for z in (.06,2.38):box('Shoji sliding track',(0,0,z),(2.6,.22,.12),m['wood'],.004)
 for x in (-1.2,1.2):box('Shoji frame foot',(x,0,.035),(.13,.745,.07),m['wood'],.004)
 for s in (-1,1):
  cx=s*.57;yy=s*.045
  box('Rice paper screen',(cx,yy,1.23),(1.04,.013,2.15),m['paper'],0)
  rect_frame('Shoji door timber frame',1.08,.16,2.31,yy-.025,.055,.075,m['wood'],cx)
  for i in range(1,4):box('Shoji vertical kumiko',(cx-.54+i*.27,yy-.055,1.23),(.022,.030,2.10),m['wood'],.001)
  for z in (.52,.88,1.24,1.60,1.96):box('Shoji horizontal kumiko',(cx,yy-.057,z),(1.04,.03,.022),m['wood'],.001)
  box('Shoji lower kick board',(cx,yy-.045,.28),(1.03,.035,.20),m['wood'],.003)
  cyl('Recessed shoji finger pull',(cx-s*.42,yy-.067,1.06),.043,.014,m['darkwood'],(0,1,0),12)
 ticket(-.55,-.12,.28)

def sash_window():
 m=palette();wall_opening(2.4,2.4,1.25,.85,2.10,m['cream']);flat_back(2.4,2.4,0,1.12,m['wood'])
 rect_frame('Sash outer casing',1.38,.78,2.18,-.08,.11,.16,m['blue'])
 # Two frames with a real empty four-light opening; no opaque blue 'glass'.
 for b,t,y in ((.89,1.48,-.09),(1.50,2.08,-.04)):
  rect_frame('Sash sliding frame',1.17,b,t,y,.045,.07,m['cream'])
  box('Sash central glazing bar',(0,y,(b+t)/2),(.035,.07,t-b),m['cream'],.002)
 box('Projecting window sill',(0,-.19,.79),(1.55,.40,.095),m['blue'],.008)
 for x in (-.55,.55):profile('Sill bracket',[(x-.045,.72),(x+.045,.72),(x+.045,.60)],-.10,.14,m['blue'],.003)
 box('Wall skirting',(0,-.075,.12),(2.4,.045,.12),m['blue'],.003)
 ticket(-.87,-.057,1.35)

def porthole():
 m=palette();w=2.2;height=2.4;cz=1.45;inner=.48;n=16
 # Watertight radial sectors from the circular opening to the rectangular wall boundary.
 for i in range(n):
  pts=[]
  for j in (i,i+1):
   a=j*math.tau/n;dx=math.cos(a);dz=math.sin(a)
   t=min((w/2)/max(abs(dx),1e-9),(height-cz if dz>0 else cz)/max(abs(dz),1e-9))
   pts.append((dx*t,cz+dz*t))
  a0=i*math.tau/n;a1=(i+1)*math.tau/n
  corners=[(x,z) for x,z in [(-w/2,0),(w/2,0),(w/2,height),(-w/2,height)] if a0+1e-7 < math.atan2(z-cz,x)%math.tau < a1-1e-7]
  corners.sort(key=lambda p:math.atan2(p[1]-cz,p[0])%math.tau)
  profile('Bulkhead plate circular cutout',[(inner*math.cos(a0),cz+inner*math.sin(a0)),pts[0]]+corners+[pts[1],(inner*math.cos(a1),cz+inner*math.sin(a1))],0,.09,m['blue'],0)
 ring('Porthole thick circular flange',(0,-.08,cz),.61,.47,.11,m['metal'],16)
 ring('Porthole inner gasket',(0,-.145,cz),.49,.445,.025,m['black'],16)
 for a in range(0,16,2):
  x=.55*math.cos(a*math.tau/16);z=cz+.55*math.sin(a*math.tau/16)
  cyl('Porthole large flange bolt',(x,-.15,z),.029,.025,m['metal'],(0,1,0),6)
 # Rolled plate edges and rear stiffeners support the scenic skin.
 for x in (-1.05,1.05):box('Bulkhead edge angle',(x,.045,1.2),(.095,.12,2.4),m['steel'],.003)
 for z in (.10,2.30):box('Bulkhead transverse stiffener',(0,.075,z),(2.2,.12,.10),m['steel'],.003)
 for x in (-.91,.91):box('Bulkhead broad foot',(x,0,.04),(.20,.935,.08),m['steel'],.004)
 ticket(-.68,-.055,.58)

def serving_hatch():
 m=palette();wall_opening(2.4,2.5,1.45,.95,2.03,m['cream']);flat_back(2.4,2.5,0,1.34,m['wood'])
 rect_frame('Serving hatch timber surround',1.56,.90,2.11,-.08,.105,.15,m['blue'])
 box('Serving counter timber top',(0,-.11,.92),(1.88,1.12,.095),m['darkwood'],.009)
 for x in (-.64,.64):
  beam('Counter triangular bracket',(x,-.08,.50),(x,-.58,.87),.075,.075,m['wood'])
 # Fold-up shutter is shown raised as a supported canopy; window remains open.
 shutter=box('Raised serving hatch shutter',(0,-.35,2.17),(1.43,.77,.065),m['blue'],.005);shutter.rotation_euler.x=.16
 for x in (-.63,.63):beam('Hatch stay arm',(x,-.08,1.72),(x,-.64,2.12),.025,.025,m['metal'],.002)
 for x in (-.54,.54):cyl('Hatch hinge barrel',(x,0,2.09),.025,.18,m['metal'],(1,0,0),8)
 for z in (.13,.70):box('Serving wall dado trim',(0,-.073,z),(2.4,.045,.07),m['blue'],.003)
 ticket(-1.04,-.055,1.42)

def timber_portal():
 m=palette()
 for s in (-1,1):
  x=s*1.23;box('Portal square post',(x,0,1.29),(.23,.29,2.58),m['darkwood'],.008)
  box('Portal timber foot',(x,0,.08),(.55,.80,.16),m['darkwood'],.007)
  beam('Portal knee brace',(x,0,1.92),(s*.68,0,2.49),.15,.17,m['wood'])
  for z in (.30,2.31):box('Post iron binding',(x,-.004,z),(.25,.31,.09),m['steel'],.003)
 box('Portal heavy lintel',(0,0,2.60),(3.1,.35,.25),m['darkwood'],.008)
 box('Portal projecting crown',(0,0,2.755),(2.91,.44,.08),m['wood'],.005)
 ticket(-1.23,-.16,1.25)

def stair_flight(cx,start_y,dy,count,width,rise,base,m,rail_xs):
 # Seven broad treads and risers match the original walkable profile.
 for i in range(count):
  yy=start_y+i*dy;zz=base+(i+1)*rise
  box('Stair broad tread',(cx,yy,zz-.033),(width,abs(dy)+.02,.066),m['wood'],.004)
  box('Stair vertical riser',(cx,yy-dy*.45,zz-rise/2-.025),(width,.035,rise-.02),m['darkwood'],.002)
  box('Stair tread contrasting nosing',(cx,yy-dy*.49,zz+.004),(width+.025,.045,.026),m['cream'],.002)
 for x in (cx-width/2+.07,cx+width/2-.07):
  beam('Stair diagonal stringer',(x,start_y-dy*.45,max(.055,base+.04)),(x,start_y+(count-.45)*dy,base+count*rise-.08),.11,.11,m['darkwood'])
  # Open rear framework with grounded load paths instead of solid stacked boxes.
  top=base+count*rise-.07
  box('Stair rear supporting leg',(x,start_y+(count-.5)*dy,top/2),(.10,.10,top),m['darkwood'],.003)
 for x in rail_xs:
  for i in (0,count//2,count-1):
   z=base+(i+1)*rise
   box('Stair handrail post',(x,start_y+i*dy,z+.35),(.065,.065,.70),m['darkwood'],.003)
  beam('Stair continuous handrail',(x,start_y-dy*.3,base+rise+.70-rise*.3),(x,start_y+(count-1+.3)*dy,base+count*rise+.70+rise*.3),.08,.08,m['wood'])

def straight_stair():
 m=palette();stair_flight(0,-.891,.30,7,1.20,.21,0,m,[-.61,.61])
 box('Stair bottom grounding rail',(0,-.94,.04),(1.27,.17,.08),m['darkwood'],.004)
 ticket(.34,-1.057,.105)

def turning_stair():
 m=palette();stair_flight(-.62,-.75,.30,4,1.10,.22,0,m,[-1.14])
 stair_flight(.62,.15,-.30,4,1.10,.22,.88,m,[1.14])
 box('Turning stair landing deck',(0,.60,.835),(2.4,.60,.09),m['wood'],.005)
 for x in (-1.12,0,1.12):
  for y in (.37,.82):box('Landing support post',(x,y,.40),(.11,.11,.80),m['darkwood'],.003)
 for x in (-1.14,1.14):
  box('Landing rail corner post',(x,.84,1.24),(.075,.075,.72),m['darkwood'],.003)
  beam('Landing side handrail',(x,.25,1.60 if x<0 else 1.82),(x,.84,1.60),.075,.075,m['wood'])
 box('Landing rear handrail',(0,.84,1.60),(2.35,.075,.075),m['wood'],.004)
 beam('Landing rear diagonal brace',(-1.05,.80,.08),(1.05,.80,.78),.075,.075,m['darkwood'])
 ticket(-.60,-.913,.105)

def ramp():
 m=palette();height=lambda y:.425+y*.85/3
 # Thin plywood over two triangular side stringers retains the authored ramp plane.
 for x in (-.69,.69):
  o=profile('Ramp triangular side stringer',[(-1.5,.035),(1.5,.035),(1.5,.81)],x,.10,m['darkwood'],.002)
  # profile is XZ; turn to run along Y, moving x-coordinate from profile's extrusion.
  o.rotation_euler.z=math.pi/2
 beam('Ramp sloping plywood deck',(0,-1.47,.047),(0,1.47,.837),1.60,.075,m['wood'])
 # Beam helper's depth axis follows the slope; broad X span is the deck width.
 for x in (-.78,.78):
  for y in (-1.35,0,1.35):box('Ramp railing post',(x,y,height(y)+.38),(.07,.07,.76),m['steel'],.003)
  beam('Ramp continuous upper rail',(x,-1.45,height(-1.45)+.80),(x,1.45,height(1.45)+.80),.07,.07,m['steel'])
  beam('Ramp raised curb',(x,-1.48,height(-1.48)+.08),(x,1.48,height(1.48)+.08),.055,.09,m['darkwood'])
 for y in (-1.20,-.75,-.30,.15,.60,1.05):
  box('Ramp low anti slip transverse batten',(0,y,height(y)+.037),(1.41,.035,.012),m['darkwood'],.001)
 box('Ramp rear cross support',(0,1.40,.40),(1.53,.11,.80),m['darkwood'],.003)
 box('Ramp broad identification mounting plate',(.65,-1.40,.50),(.29,.025,.22),m['steel'],.003)
 ticket(.65,-1.419,.50)

def trapdoor():
 m=palette()
 for x in (-.89,.89):box('Stage side deck',(x,0,.57),(.62,2.4,.16),m['darkwood'],.004)
 for y in (-.90,.90):box('Stage end deck',(0,y,.57),(1.16,.60,.16),m['darkwood'],.004)
 # Planked removable lid, with a visible perimeter gap and two broad hinges.
 for i in range(5):box('Trapdoor lid plank',((i-2)*.211,0,.57),(.203,1.15,.15),m['wood'],.003)
 for x in (-1.,1.):
  for y in (-1.,1.):box('Stage structural leg',(x,y,.26),(.16,.16,.52),m['wood'],.004)
 for x in (-1.02,1.02):
  for y in (-1.,1.):beam('Stage corner knee brace',(x,y,.16),(x,y*.56,.49),.07,.07,m['wood'])
 for y in (-1.12,1.12):box('Stage perimeter fascia',(0,y,.43),(2.4,.09,.24),m['wood'],.004)
 for x in (-.32,.32):
  box('Trapdoor hinge leaf',(x,.53,.653),(.18,.10,.018),m['metal'],.002)
  cyl('Trapdoor hinge barrel',(x,.58,.658),.014,.20,m['metal'],(1,0,0),8)
 o=ring('Flush trapdoor pull ring',(.35,-.37,.658),.065,.046,.016,m['metal'],12)
 center=Vector((.35,-.37,.658));rotation=Matrix.Rotation(math.pi/2,4,'X')
 for v in o.data.vertices:v.co=center+rotation.to_3x3()@(v.co-center)
 # A separate dark backing inset makes the folded ring legible from above.
 box('Recessed handle plate',(.35,-.37,.648),(.17,.17,.015),m['steel'],.003)
 ticket(.55,-1.171,.415)

def plank_bridge():
 m=palette()
 for x in (-.60,.60):beam('Bridge longitudinal stringer',(x,-1.51,.16),(x,1.51,.16),.13,.14,m['darkwood'])
 for i in range(13):
  y=-1.43+i*.238;z=.245+.028*math.sin(i*math.pi/12)
  box('Bridge separate deck plank',(0,y,z),(1.28,.225,.085),m['wood'],.005)
 for x in (-.65,.65):
  for y in (-1.47,0,1.47):
   box('Bridge railing post',(x,y,.575),(.10,.10,1.15),m['darkwood'],.005)
   box('Bridge post foot',(x,y,.065),(.10,.16,.13),m['darkwood'],.003)
  # Rope rails use long straight spans with one controlled sag each, no modeled fibre noise.
  for z in (.76,1.08):tube('Bridge sagging rope rail',[(x,y,z-.10*math.sin((y+1.47)*math.pi/2.94)) for y in (-1.47,-.735,0,.735,1.47)],.023,m['wood'])
 box('Bridge end fascia beam',(0,-1.49,.20),(1.26,.12,.21),m['darkwood'],.004)
 ticket(.33,-1.557,.20)

def roof():
 m=palette();w=1.48;height=1.08;depth=2.20
 # Four broad overlapping rows on each slope, each a real folded roof panel.
 for s in (-1,1):
  for i in range(4):
   x0=s*w*i/4;x1=s*w*(i+1)/4;z0=height*(1-i/4);z1=height*(1-(i+1)/4)
   beam('Gable broad overlapping roof course',(x0,0,z0+.025),(x1,0,z1+.025),depth,.055,m['blue'])
   # Long local width points along Y for these sloped XZ panels.
   o=h.PARTS[-1];a=Vector((x0,0,z0+.025));b=Vector((x1,0,z1+.025));t=(b-a).normalized()
   # Explicit quad prism avoids to_track quaternion choosing the wrong wide axis.
   h.PARTS.remove(o);bpy.data.objects.remove(o,do_unlink=True)
   profile('Roof folded sheet course',[(x0,z0+.045),(x1,z1+.045),(x1,z1-.015),(x0,z0-.015)],0,depth,m['blue'],.003)
 for y in (-1.03,0,1.03):
  for s in (-1,1):beam('Gable timber rafter',(s*1.46,y,.055),(0,y,1.075),.085,.085,m['darkwood'])
 for y in (-1.06,1.06):
  beam('Gable front edge fascia',(-1.48,y,.035),(0,y,1.12),.085,.085,m['wood'])
  beam('Gable front edge fascia',(0,y,1.12),(1.48,y,.035),.085,.085,m['wood'])
  box('Gable horizontal tie',(0,y,.075),(2.92,.09,.12),m['darkwood'],.004)
 box('Roof ridge cap',(0,0,1.10),(.13,2.20,.06),m['metal'],.005)
 for s in (-1,1):box('Roof eaves purlin',(s*1.40,0,.045),(.09,2.20,.09),m['darkwood'],.003)
 profile('Front gable triangular timber gusset',[(-.32,.76),(.32,.76),(0,1.08)],-1.065,.07,m['wood'],.003)
 ticket(0,-1.108,.87)

def fireplace():
 m=palette()
 box('Fireplace broad hearth',(0,-.06,.09),(1.90,1.03,.18),m['stone'],.012)
 for s in (-1,1):
  for i in range(5):box('Fireplace ashlar jamb',(s*.66,0,.22+i*.245),(.37,.65,.23),m['stone2' if i%2 else 'stone'],.009)
 # Arch ring surrounds a real firebox opening, backed well behind its lip.
 for i in range(7):
  a0=i*math.pi/7+.01;a1=(i+1)*math.pi/7-.01
  pts=[(.48*math.cos(a0),.78+.48*math.sin(a0)),(.73*math.cos(a0),.78+.73*math.sin(a0)),(.73*math.cos(a1),.78+.73*math.sin(a1)),(.48*math.cos(a1),.78+.48*math.sin(a1))]
  profile('Fireplace radial arch stone',pts,-.04,.58,m['stone2' if i%2 else 'stone'],.007)
 box('Firebox charcoal rear',(0,.30,.59),(1.02,.055,.95),m['black'],.005)
 box('Fireplace projecting mantel',(0,-.035,1.44),(1.87,.84,.16),m['stone'],.012)
 for x in (-.32,.32):cyl('Fireplace low andiron',(x,-.17,.27),.025,.24,m['steel'],sides=6)
 for z,y in ((.22,-.12),(.27,.06)):
  cyl('Fireplace broad log',(0,y,z),.08,.80,m['darkwood'],(1,0,0),8)
 ticket(-.67,-.338,.70)

def elevator():
 m=palette();wall_opening(2.6,2.8,1.65,0,2.43,m['cream']);flat_back(2.6,2.8,0,.9525,m['wood'])
 for x in (-.88,.88):box('Elevator brushed steel jamb',(x,-.075,1.24),(.15,.22,2.48),m['metal'],.004)
 box('Elevator steel head',(0,-.075,2.47),(1.91,.22,.16),m['metal'],.004)
 box('Elevator threshold',(0,-.075,.045),(1.91,.27,.09),m['metal'],.004)
 for s in (-1,1):
  x=s*.413;box('Elevator sliding leaf',(x,-.03,1.23),(.81,.055,2.35),m['metal'],.003)
  for xx in (-.29,.29):box('Elevator broad recessed seam',(x+xx,-.062,1.24),(.016,.009,2.20),m['steel'],0)
 box('Elevator central meeting gap',(0,-.065,1.23),(.018,.010,2.35),m['black'],0)
 box('Elevator floor indicator housing',(0,-.09,2.66),(.58,.06,.14),m['steel'],.006)
 # A single numeral and call-button assembly read at distance without small LEDs.
 text=bpy.data.curves.new('Floor number','FONT');text.body='2';text.align_x='CENTER';text.size=.12;text.extrude=.001
 obj=bpy.data.objects.new('Floor number',text);bpy.context.collection.objects.link(obj);obj.location=(0,-.128,2.61);obj.rotation_euler=(math.pi/2,0,0)
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.convert(target='MESH');finish(bpy.context.object,m['cream'])
 box('Elevator call button plate',(1.08,-.08,1.25),(.17,.04,.30),m['metal'],.005)
 for z in (1.18,1.32):cyl('Elevator call push button',(1.08,-.11,z),.04,.027,m['steel'],(0,1,0),12)
 ticket(-1.10,-.057,1.3)

def room_corner():
 m=palette()
 # Original L is open to front/right in Godot. Preserve authored positions exactly.
 box('Corner left wall skin',(-.07,-1.136,1.25),(2.4,.13,2.5),m['cream'],.003)
 box('Corner return wall skin',(1.13,.064,1.25),(.13,2.4,2.5),m['blue'],.003)
 for x in (-1.20,-.10,1.03):box('Left wall back stud',(x,-1.036,1.25),(.07,.09,2.4),m['wood'],.003)
 for y in (-.986,.064,1.164):box('Return wall back stud',(1.23,y,1.25),(.08,.07,2.4),m['wood'],.003)
 for z in (.12,.85,2.43):
  box('Left wall architectural moulding',(-.07,-1.226,z),(2.4,.075,.07),m['blue'],.003)
  box('Return wall architectural moulding',(1.045,.064,z),(.075,2.4,.07),m['cream'],.003)
 for z in (.35,1.25,2.15):cyl('Folding corner hinge',(1.04,-1.04,z),.024,.20,m['metal'],sides=8)
 # Broad wainscot panels reinforce reading as an interior room corner.
 for x in (-.82,-.07,.68):rect_frame('Left wall wainscot',.61,.22,.72,-1.210,.022,.026,m['blue'],x)
 ticket(-.54,-1.208,1.36)

BUILDERS={'S001_hinged_door_wall':hinged_door,'S002_saloon_swing_doors':saloon,'S003_barred_cell_gate':cell_gate,'S004_barn_double_door':barn,'S005_sliding_shoji':shoji,'S006_sash_window_wall':sash_window,'S008_porthole_bulkhead':porthole,'S009_serving_hatch':serving_hatch,'S010_freestanding_arch':stone_arch,'S011_foam_column':column,'S012_timber_portal':timber_portal,'S013_straight_stair':straight_stair,'S014_turning_stair':turning_stair,'S015_access_ramp':ramp,'S017_trapdoor_platform':trapdoor,'S018_plank_bridge':plank_bridge,'S019_gable_roof':roof,'S020_crooked_chimney':chimney,'S021_scenic_fireplace':fireplace,'S022_broken_arch':lambda:stone_arch(True),'S023_elevator_facade':elevator,'S024_folding_room_corner':room_corner,'S025_sewer_entry':lambda:stone_arch(False,True)}

def bake_all():
 bpy.context.view_layer.update()
 for o in h.PARTS:
  o.data.transform(o.matrix_world);o.matrix_world=Matrix.Identity(4)
 bpy.context.view_layer.update()

def bounds():
 bpy.context.view_layer.update();ps=[o.matrix_world@v.co for o in h.PARTS for v in o.data.vertices]
 return Vector([min(p[i] for p in ps) for i in range(3)]),Vector([max(p[i] for p in ps) for i in range(3)])

def fit(envelope):
 bake_all();lo,hi=bounds();oldlo=Vector(envelope['min']);oldhi=Vector(envelope['max'])
 factor=Vector([(oldhi[i]-oldlo[i])/(hi[i]-lo[i]) for i in range(3)])
 transform=Matrix.Translation(oldlo)@Matrix.Diagonal((*factor,1))@Matrix.Translation(-lo)
 for o in h.PARTS+h.MARKERS:o.matrix_world=transform@o.matrix_world
 for o in h.MARKERS:o.matrix_world=Matrix.Translation(o.matrix_world.translation)
 bpy.context.view_layer.update();bake_all()
 lo,hi=bounds()
 if max(abs(lo[i]-oldlo[i]) for i in range(3))>1e-5 or max(abs(hi[i]-oldhi[i]) for i in range(3))>1e-5:raise RuntimeError('Envelope drift')
 return list(factor)

def validate():
 triangles=0
 for o in h.PARTS:
  if not all(math.isfinite(c) for v in o.data.vertices for c in v.co):raise RuntimeError('Nonfinite '+o.name)
  bm=bmesh.new();bm.from_mesh(o.data)
  bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
  if any(face.calc_area()<1e-12 for face in bm.faces):raise RuntimeError('Degenerate '+o.name)
  if any(not e.is_manifold for e in bm.edges):raise RuntimeError('Open shell '+o.name)
  bm.to_mesh(o.data);bm.free();o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
 if triangles>4500:raise RuntimeError('Triangle limit '+str(triangles))
 return triangles

def main():
 ARTIFACTS.mkdir(parents=True,exist_ok=True)
 rows=json.loads((ROOT/'godot/docs/PROP_REBUILD_ASSIGNMENTS.json').read_text(encoding='utf-8'))['architecture']
 envelopes=json.loads((SOURCE/'original_envelopes.json').read_text(encoding='utf-8'))
 requested=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
 manifest=[];replacements=[]
 for row in rows:
  name=row['original_file']
  if requested and name not in requested:continue
  bpy.ops.wm.read_factory_settings(use_empty=True);h.PARTS.clear();h.MARKERS.clear()
  BUILDERS[name]();factor=fit(envelopes[name]);n=validate()
  row_out=h.export_asset(name+'_rebuilt')
  row_out.update(kind=row['kind'],original_file=name,normalization_size=row['size_m'],mass_kg=row['mass_kg'],original_transformed_envelope=envelopes[name],authoring_axis_fit=factor,textures_embedded=False,validation={'finite_vertices':True,'closed_authored_shells':True,'nondegenerate_faces':True,'baked_transforms':True,'original_vertex_envelope_error_max':1e-5,'godot_runtime':'parent integration pending'})
  manifest.append(row_out);replacements.append(dict(kind=row['kind'],original_file=name,file=name+'_rebuilt'))
  bpy.ops.wm.save_as_mainfile(filepath=str(ARTIFACTS/(name+'_rebuilt.blend')))
  print('ARCHITECTURE_OK '+json.dumps(row_out),flush=True)
 for filename,data in [('build_manifest.json',manifest),('replacements.json',replacements)]:
  path=SOURCE/filename
  if requested and path.exists():
   old=json.loads(path.read_text(encoding='utf-8'));kinds={r['kind'] for r in data};data=[r for r in old if r['kind'] not in kinds]+data
  path.write_text(json.dumps(data,indent=2),encoding='utf-8')
if __name__=='__main__':main()
