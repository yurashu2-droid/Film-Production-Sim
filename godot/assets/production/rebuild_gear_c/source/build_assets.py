"""Costume tools and supported stage machinery, authored from names and photo studies."""
from pathlib import Path
import importlib.util,json,math
import bpy
from mathutils import Vector
SOURCE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('gear_b_shared',SOURCE.parents[1]/'rebuild_gear_b/source/build_assets.py')
b=importlib.util.module_from_spec(spec);spec.loader.exec_module(b)
h,f=b.h,b.f
box,cyl,bar,tube,ring=b.box,b.cyl,b.bar,b.tube,b.ring
def sewing():
    m=b.M
    box('Sewing box base',(0,0,.035),(.34,.22,.05),m['wood'],.006)
    for x in (-.161,.161):box('Sewing box side',(x,0,.10),(.018,.22,.12),m['wood'],.003)
    for y in (-.101,.101):box('Sewing box end',(0,y,.10),(.32,.018,.12),m['wood'],.003)
    box('Open sewing box lid',(0,.109,.245),(.34,.023,.21),m['wood'],.005)
    box('Lid padded inset',(0,.093,.245),(.30,.012,.17),m['pink'],.003)
    for x in (-.105,0,.105):
        for y in (-.05,.05):
            cyl('Thread reel core',(x,y,.135),.024,.085,m['white'])
            cyl('Coarse wound thread',(x,y,.135),.029,.057,m['blue'] if x<0 else m['pink'] if x>0 else m['green'])
            for z in (.093,.177):cyl('Spool end flange',(x,y,z),.032,.008,m['white'])
    for x in (-.11,.11):box('Lid hinge',(x,.115,.155),(.04,.025,.03),m['silver'],.002)
    box('Front clasp',(0,-.117,.125),(.044,.014,.04),m['gold'],.002)
def pincushion():
    m=b.M
    cyl('Weighted fabric cushion base',(0,0,.022),.137,.044,m['wood'],n=24)
    h.ellipsoid('Tomato shaped cloth pin cushion',(0,0,.11),(.15,.15,.095),m['red'],24,10)
    # Four broad seam depressions are implied by shallow dark thread strips.
    for i in range(4):
        a=i*math.pi/2
        tube('Cushion gathered radial seam',[(.149*math.sin(t)*math.cos(a),.149*math.sin(t)*math.sin(a),.11+.092*math.cos(t)) for t in [0,.5,1,1.5,2]],.002,m['pink'])
    for i in range(6):
        a=i*math.tau/6;x=.085*math.cos(a);y=.085*math.sin(a);z=.185
        bar('Large visible dressmaking pin',(x,y,z),(x*1.25,y*1.25,z+.07),.002,m['silver'])
        h.ellipsoid('Colored pin head',(x*1.25,y*1.25,z+.074),(.008,.008,.008),m['white'] if i%2 else m['orange'],8,4)
def tape():
    m=b.M
    h.extruded_profile('Measuring tape cast housing',[(-.12,.015),(.10,.015),(.14,.055),(.14,.18),(.10,.23),(-.10,.23),(-.14,.18),(-.14,.055)],0,.105,m['orange'],.008)
    box('Rubber wraparound bumper',(0,0,.025),(.25,.122,.04),m['rubber'],.005)
    cyl('Coil face disc',(0,-.057,.125),.089,.012,m['shell'],(0,1,0),24)
    box('Extended steel measuring blade',(.21,0,.035),(.24,.034,.004),m['gold'],0)
    box('Bent tape end hook',(.33,0,.024),(.008,.045,.028),m['silver'],.001)
    for i in range(10):box('Sparse ruler graduation',(.107+i*.022,-.008,.039),(.002,.015 if i%2==0 else .008,.002),m['dark'],0)
    box('Top thumb lock',(0,0,.235),(.075,.068,.026),m['rubber'],.004)
def wrench():
    m=b.M
    # Extruded fork is a continuous open jaw, not a solid disk with a black patch.
    pts=[(-.055,.02),(.055,.02),(.047,.31),(.111,.355),(.137,.455),(.085,.49),(.063,.401),(-.036,.375),(-.082,.454),(-.128,.425),(-.115,.343),(-.049,.31)]
    h.extruded_profile('Open ended forged wrench',pts,0,.041,m['silver'],.005)
    box('Wrench broad rubber grip',(0,0,.17),(.16,.055,.22),m['rubber'],.009)
    for z in (.075,.265):box('Grip guard ridge',(0,0,z),(.17,.06,.016),m['rubber'],.003)
def step():
    m=b.M
    box('Flat anti slip step top',(0,0,.37),(.55,.39,.05),m['blue'],.008)
    for x in (-.19,.19):
        for y in (-1,1):
            bar('Splayed folding step leg',(x,y*.13,.35),(x*1.17,y*.205,.02),.021,m['silver'],8)
            box('Step rubber foot',(x*1.17,y*.205,.016),(.075,.07,.032),m['rubber'],.004)
        cyl('Folding hinge',(x,0,.33),.032,.34,m['shell'],(0,1,0))
        bar('Leg spread stop',(x,-.17,.16),(x,.17,.16),.012,m['shell'])
    for x in (-.21,-.105,0,.105,.21):box('Top non slip raised strip',(x,0,.399),(.07,.33,.006),m['rubber'],.002)
def dustpan():
    m=b.M
    # Real open tray: floor and three walls, including a thin tapered collecting lip.
    verts=[(-.20,-.17,.008),(.20,-.17,.008),(.18,.15,.025),(-.18,.15,.025),(-.20,-.17,.018),(.20,-.17,.018),(.18,.15,.04),(-.18,.15,.04)]
    f.mesh('Sloping thin dustpan floor',verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],m['blue'],False)
    for s in (-1,1):
        ob=box('Dustpan raised side',(s*.19,0,.07),(.018,.31,.105),m['blue'],.004);ob.rotation_euler.z=-s*.06
    box('Dustpan back wall',(0,.15,.08),(.38,.018,.11),m['blue'],.005)
    tube('Connected short dustpan handle',[(0,.16,.08),(0,.24,.14),(0,.37,.15)],.024,m['blue'])
    ring('Open grip hanging eye',(0,.39,.15),.032,.009,m['blue'],(0,0,1))
def popcorn():
    m=b.M
    butter=b.material('Pale butter popcorn lobes','F0E4BE',.92)
    f.lathe('Open tapered paper popcorn tub',[(.0,0),(.12,0),(.17,.32),(.17,.34),(.161,.34),(.158,.32),(.111,.015),(0,.015)],m['white'],24)
    for i in range(12):
        a=i*math.tau/12
        verts=[(.124*math.cos(a-.11),.124*math.sin(a-.11),.01),(.124*math.cos(a+.11),.124*math.sin(a+.11),.01),(.174*math.cos(a+.11),.174*math.sin(a+.11),.32),(.174*math.cos(a-.11),.174*math.sin(a-.11),.32)]
        f.mesh('Broad red paper tub stripe',verts,[(0,1,2,3)],m['red'],False)
    # Only the visible coarse popcorn mound is modeled; kernels overlap as soft lobes.
    for j,(r,z,num) in enumerate([(.115,.335,10),(.075,.382,7),(0,.417,1)]):
        for i in range(num):
            a=i*math.tau/num+j*.4;x=r*math.cos(a);y=r*math.sin(a)
            h.ellipsoid('Popped corn cluster',(x,y,z),(.043,.042,.039),m['white'],8,4)
            h.ellipsoid('Pale irregular popcorn lobe',(x+.022,y-.012,z+.021),(.027,.025,.024),butter,8,4)
def feet(x,z=.02,depth=.55):
    m=b.M
    box('Steel stabilizing foot',(x,0,z),(.16,depth,.04),m['shell'],.005)
    for y in (-depth/2+.04,depth/2-.04):box('Rubber foot pad',(x,y,.008),(.16,.07,.016),m['rubber'],.002)
def supported_wall(w=1.3,height=1.4):
    m=b.M
    box('Scenic wall panel',(0,.04,height/2+.05),(w,.09,height),m['shell'],.006)
    for x in (-w*.36,w*.36):
        feet(x);bar('Rear scenic diagonal brace',(x,.03,height*.70),(x,.32,.06),.025,m['silver'],6)
def curtain():
    m=b.M
    for x in (-.80,.80):
        feet(x,depth=.62);bar('Curtain support upright',(x,0,.04),(x,0,1.65),.032,m['shell'],8)
    bar('Curtain suspension cross rail',(-.86,0,1.65),(.86,0,1.65),.035,m['silver'],8)
    # Supported unequal pleats have a real front/back thickness and free scalloped hem.
    for side in (-1,1):
        verts=[];nx=16;nz=5
        for back in (0,1):
            for j in range(nz):
                t=j/(nz-1)
                for i in range(nx):
                    u=i/(nx-1);x=side*(.12+.68*u+.035*math.sin(t*math.pi)*math.sin(u*math.pi))
                    y=-.025+.047*math.cos(u*math.tau*4)+.008*back
                    z=1.60-t*(1.49-.035*math.cos(u*math.tau*4))
                    verts.append((x,y,z))
        faces=[];off=nx*nz
        for k in (0,off):
            for j in range(nz-1):
                for i in range(nx-1):a=k+j*nx+i;faces.append((a,a+1,a+1+nx,a+nx))
        for j in (0,nz-1):
            for i in range(nx-1):a=j*nx+i;faces.append((a,a+off,a+off+1,a+1))
        for i in (0,nx-1):
            for j in range(nz-1):a=j*nx+i;faces.append((a,a+nx,a+nx+off,a+off))
        f.mesh('Suspended thick velvet curtain leaf',verts,faces,m['red'])
        tube('Curtain tieback cord',[(side*.23,-.085,.72),(side*.45,-.09,.67),(side*.70,-.085,.72)],.009,m['gold'])
def backdrop():
    m=b.M
    for x in (-.78,.78):
        feet(x,depth=.65);bar('Background stand telescoping post',(x,0,.04),(x,0,1.65),.026,m['silver'],8)
        cyl('Stand height clamp',(x,0,.9),.037,.08,m['shell'])
    cyl('Backdrop roll core',(0,0,1.61),.075,1.5,m['white'],(1,0,0),24)
    for x in (-.76,.76):cyl('Roll end flange',(x,0,1.61),.085,.025,m['shell'],(1,0,0),16)
    box('Unrolled thick paper backdrop',(0,-.055,.87),(1.44,.012,1.42),m['blue'],.002)
    bar('Weighted lower paper edge',(-.72,-.055,.16),(.72,-.055,.16),.018,m['shell'],8)
    tube('Roller continuous operating chain',[(.79,-.02,1.62),(.82,-.02,1.5),(.82,-.02,.5),(.79,-.02,.45),(.76,-.02,.5),(.76,-.02,1.5)],.004,m['silver'],True)
def wagon():
    m=b.M
    box('Heavy scenic wagon frame',(0,0,.16),(1.25,.83,.13),m['shell'],.008)
    for i in range(7):box('Thick plywood stage deck',(-.534+i*.178,0,.25),(.173,.85,.065),m['wood'],.003)
    for x in (-.49,.49):
        for y in (-.30,.30):
            box('Swivel caster fork',(x,y,.09),(.10,.11,.12),m['silver'],.003)
            cyl('Rubber caster wheel',(x,y,.065),.065,.045,m['rubber'],(1,0,0))
            cyl('Wheel axle hub',(x-.025,y,.065),.023,.05,m['silver'],(1,0,0),12)
    tube('Wagon push handle',[(-.49,.33,.20),(-.49,.38,.8),(.49,.38,.8),(.49,.33,.20)],.025,m['shell'])
def rain():
    m=b.M
    for x in (-.8,.8):
        feet(x,depth=.65);bar('Rain rig upright',(x,0,.05),(x,0,1.5),.031,m['silver'],8)
        bar('Stand diagonal brace',(x,-.27,.04),(x,0,.45),.016,m['silver'])
        cyl('Rain bar end coupling',(x,0,1.5),.048,.10,m['shell'],(1,0,0))
    bar('Main water distribution rain bar',(-.88,0,1.5),(.88,0,1.5),.042,m['blue'],16)
    for x in [-.7+i*.175 for i in range(9)]:
        cyl('Downward spray nozzle',(x,0,1.444),.014,.06,m['gold'],n=8)
        cyl('Dark nozzle aperture',(x,0,1.413),.007,.002,m['dark'],n=8)
    tube('Connected flexible supply hose',[(.86,0,1.5),(.95,.04,1.3),(.94,.08,.2),(.8,.15,.04),(.50,.24,.025)],.018,m['rubber'])
def chimney():
    m=b.M
    box('Smoke stack scenic base',(0,0,.13),(.62,.48,.26),m['shell'],.01)
    # Hollow open chimney assembled from stepped wall sections; mouth is visibly deep.
    f.lathe('Open sheet metal smoke stack',[(.14,.25),(.17,.29),(.17,.92),(.20,.96),(.20,1.01),(.176,1.01),(.153,.96),(.145,.32),(.12,.28),(.14,.25)],m['silver'],24)
    for z in (.32,.72):ring('Stack joining hoop',(0,0,z),.174,.014,m['shell'],n=24)
    box('Fan grille recess',(0,-.248,.14),(.36,.012,.15),m['dark'],.003)
    for x in (-.14,-.07,0,.07,.14):box('Smoke fan protective grille',(x,-.257,.14),(.018,.012,.145),m['shell'],.002)
def console():
    m=b.M
    box('Console lower plinth',(0,0,.09),(1.12,.56,.18),m['shell'],.01)
    for x in (-.38,.38):box('Console leg support',(x,.08,.39),(.19,.31,.6),m['silver'],.008)
    h.extruded_profile('Sloped control console cabinet',[(-.60,.57),(.60,.57),(.60,.84),(-.60,.84)],0,.58,m['shell'],.01)
    for x in (-.32,.32):
        box('CRT monitor raised surround',(x,.12,1.02),(.48,.16,.36),m['dark'],.015)
        box('Blue monitor screen',(x,.032,1.02),(.41,.012,.28),m['blue'],.008)
        for z in (.94,1.02,1.10):box('Screen information bar',(x,-.0,z),(.25,.007,.008),m['green'],0)
    for x in (-.45,-.3,-.15,0,.15,.3,.45):
        cyl('Control bank pushbutton',(x,-.17,.855),.025,.027,m['red'] if x<0 else m['white'],n=12)
    for x in (-.45,.45):
        bar('Joystick stem',(x,-.20,.86),(x,-.20,.95),.012,m['silver'])
        h.ellipsoid('Joystick knob',(x,-.20,.96),(.035,.035,.035),m['rubber'],12,6)
def reactor():
    m=b.M
    cyl('Reactor foot plinth',(0,0,.08),.44,.16,m['shell'],n=24)
    cyl('Vertical reactor vessel',(0,0,.68),.27,1.04,m['silver'],n=24)
    for z in (.20,.47,.88,1.16):cyl('Heavy reactor containment ring',(0,0,z),.33,.07,m['shell'],n=24)
    cyl('Reactor domed lid neck',(0,0,1.23),.21,.09,m['shell'],n=24)
    for i in range(6):
        a=i*math.tau/6
        bar('Supported outer containment rod',(.33*math.cos(a),.33*math.sin(a),.20),(.33*math.cos(a),.33*math.sin(a),1.19),.023,m['gold'],8)
    box('Reactor instrument panel',(0,-.298,.68),(.30,.13,.23),m['blue'],.008)
def valve(x,y,z,r=.14):
    m=b.M
    cyl('Valve stem',(x,y+.03,z),.028,.14,m['silver'],(0,1,0),12)
    ring('Open valve handwheel',(x,y-.06,z),r,.015,m['red'],(0,1,0),16)
    for a in (0,math.pi*2/3,math.pi*4/3):bar('Handwheel spoke',(x,y-.06,z),(x+r*.93*math.cos(a),y-.06,z+r*.93*math.sin(a)),.012,m['red'])
    cyl('Handwheel hub',(x,y-.06,z),.035,.035,m['red'],(0,1,0),12)
def gauge(x,y,z,r=.08):
    m=b.M
    cyl('Pressure gauge rim',(x,y,z),r,.045,m['silver'],(0,1,0),16)
    cyl('Pressure gauge ivory face',(x,y-.025,z),r*.83,.008,m['white'],(0,1,0),16)
    bar('Gauge broad pointer',(x,y-.032,z),(x-r*.45,y-.032,z+r*.4),.005,m['dark'])
def boiler():
    m=b.M
    for x in (-.26,.26):box('Boiler raised steel support',(x,0,.11),(.13,.44,.22),m['shell'],.006)
    f.lathe('Boiler tank casing',[(0,.18),(.26,.18),(.34,.24),(.36,.35),(.36,.96),(.32,1.06),(.22,1.10),(0,1.10)],m['blue'],24)
    for z in (.30,.95):ring('Tank sheet join band',(0,0,z),.364,.015,m['silver'],n=24)
    cyl('Firebox door rim',(0,-.36,.42),.135,.04,m['shell'],(0,1,0),24)
    cyl('Inset firebox door',(0,-.385,.42),.108,.02,m['rubber'],(0,1,0),24)
    valve(0,-.42,.42,.075);gauge(-.14,-.32,.84,.08)
    tube('Steam outlet elbow',[(.16,0,1.05),(.16,0,1.25),(.27,0,1.33),(.43,0,1.33)],.037,m['silver'],n=8)
    mouth=f.lathe('Hollow steam outlet mouth',[(.037,-.035),(.037,.04),(.027,.04),(.027,-.035),(.037,-.035)],m['silver'],16)
    mouth.rotation_euler.y=math.pi/2;mouth.location=(.44,0,1.33)
def pipewall():
    m=b.M;supported_wall(1.25,1.30)
    paths=[[(-.42,-.05,.15),(-.42,-.05,.95),(-.24,-.05,1.12),(.52,-.05,1.12)],[(.4,-.075,.12),(.4,-.075,.78),(.18,-.075,.94)], [(-.52,-.09,.42),(.52,-.09,.42)]]
    for pts in paths:tube('Connected scenic metal pipe',pts,.044,m['silver'],n=8)
    for x,z in [(-.42,.55),(.40,.70)]:
        cyl('Pipe valve casting',(x,-.055,z),.065,.11,m['shell']);valve(x,-.14,z,.13)
    gauge(.10,-.075,1.13,.09)
def conveyor():
    m=b.M
    for x in (-.58,.58):
        for y in (-.22,.22):
            box('Conveyor square steel leg',(x,y,.28),(.055,.055,.56),m['silver'],.003)
            box('Conveyor foot plate',(x,y,.015),(.15,.14,.03),m['shell'],.003)
        bar('Conveyor lower leg crossbar',(x,-.22,.17),(x,.22,.17),.02,m['silver'],6)
    # Continuous belt wraps around two actual drum rollers at both ends.
    for x in (-.66,.66):cyl('Conveyor end drum',(x,0,.62),.07,.52,m['silver'],(0,1,0),16)
    verts=[];profile=[]
    for cx,start in [(.66,-math.pi/2),(-.66,math.pi/2)]:
        for i in range(9):a=start+i*math.pi/8;profile.append((cx+.077*math.cos(a),.62+.077*math.sin(a)))
    # Tube-like closed strip along the roller profile, open between the upper/lower runs.
    n=len(profile)
    verts=[(x,y,z) for y in (-.23,.23) for x,z in profile]
    faces=[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    belt=f.mesh('Continuous rubber conveyor belt',verts,faces,m['rubber'],False)
    sol=belt.modifiers.new('Belt wall thickness','SOLIDIFY');sol.thickness=.008;bpy.context.view_layer.objects.active=belt;bpy.ops.object.modifier_apply(modifier=sol.name)
    for y in (-.28,.28):box('Conveyor side support beam',(0,y,.60),(1.42,.04,.115),m['blue'],.004)
    box('Geared drive motor',(-.53,.36,.55),(.24,.20,.20),m['shell'],.007)
    cyl('Motor shaft',(-.66,.28,.62),.025,.18,m['silver'],(0,1,0))
def vault():
    m=b.M
    # Heavy rectangular frame is separately supported and encloses a recessed thick door.
    for x in (-.55,.55):box('Vault jamb',(x,0,.76),(.13,.23,1.52),m['shell'],.008)
    for z in (.07,1.45):box('Vault frame cross lintel',(0,0,z),(1.10,.23,.14),m['shell'],.008)
    box('Vault door slab',(0,-.015,.76),(.95,.17,1.25),m['silver'],.012)
    box('Door recessed front plate',(0,-.108,.76),(.82,.025,1.1),m['blue'],.007)
    for z in (.33,1.18):
        box('Heavy door hinge leaf',(-.48,-.10,z),(.15,.08,.16),m['shell'],.004)
        cyl('Door vertical hinge barrel',(-.53,-.13,z),.045,.22,m['silver'])
    valve(.03,-.23,.79,.22)
    for a in [i*math.tau/6 for i in range(6)]:
        x=.03+math.cos(a)*.32;z=.79+math.sin(a)*.32
        bar('Radial vault locking rod',(.03,-.15,.79),(x,-.15,z),.016,m['silver'])
        ob=box('Locking bolt guide',(x,-.145,z),(.10,.08,.08),m['shell'],.003);ob.rotation_euler.y=-a
    gauge(.25,-.14,1.17,.063)
    for x in (-.40,.40):feet(x,depth=.55)
def gear(name,x,y,z,r,teeth=12):
    m=b.M;n=teeth*4;verts=[]
    # True center opening and thick annular toothed wheel, with broad cast teeth.
    for yy in (y-.03,y+.03):
        for inner in (False,True):
            for i in range(n):
                a=i*math.tau/n;rr=r*.32 if inner else r*(1 if i%4 in (1,2) else .83)
                verts.append((x+rr*math.cos(a),yy,z+rr*math.sin(a)))
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces.extend([(i,j,2*n+j,2*n+i),(n+i,3*n+i,3*n+j,n+j),(i,n+i,n+j,j),(2*n+i,2*n+j,3*n+j,3*n+i)])
    f.mesh(name,verts,faces,m['gold'],False)
    for i in range(4):
        a=i*math.tau/4;bar('Cast wheel spoke',(x+r*.14*math.cos(a),y,z+r*.14*math.sin(a)),(x+r*.37*math.cos(a),y,z+r*.37*math.sin(a)),r*.05,m['gold'],6)
    cyl('Gear axle hub',(x,y,z),r*.15,.10,m['silver'],(0,1,0),12)
def gearwall():
    m=b.M;supported_wall(1.4,1.35)
    for i,(x,z,r) in enumerate([(-.28,.98,.30),(.26,.95,.29),(-.20,.40,.29),(.28,.44,.23)]):gear('Large cast scenic gear',x,-.08,z,r,12 if r>.25 else 10)

BUILDERS=[sewing,pincushion,tape,wrench,step,lambda:b.case(False),dustpan,popcorn,curtain,backdrop,wagon,rain,chimney,console,reactor,boiler,pipewall,conveyor,vault,gearwall]
def main():
    items=json.loads((b.ROOT/'godot/docs/PROP_REBUILD_ASSIGNMENTS.json').read_text(encoding='utf-8'))['gear'][20:]
    b.build_batch(SOURCE,items,BUILDERS,'rebuild_gear_c')
if __name__=='__main__':main()
