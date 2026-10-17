"""Lower-poly miniature vehicles and large film props; authored front -Y."""
from pathlib import Path
import importlib.util,math,json
import bpy
from mathutils import Vector,Matrix
SOURCE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('story_helpers_for_scenery',SOURCE.parents[1]/'rebuild_story/source/build_assets.py')
s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s);h,f=s.h,s.f
material=s.material
box,cylinder,ball,beam,tube,ring,lathe,profile,text=s.box,s.cylinder,s.ball,s.beam,s.tube,s.ring,s.lathe,s.profile,s.text

def back_support(width,height,depth):
    for x in (-width*.32,width*.32):
        box('Set support foot',(x,depth*.20,.035),(.065,depth,.07),M['wood'],.002)
        beam('Set rear brace',(x,depth*.62,.06),(x,0,height*.79),.023,M['wood'])

def wheel(name,x,y,z,r,axis=(1,0,0)):
    cylinder(name+' tire',(x,y,z),r,.08,M['dark'],axis,16)
    cylinder(name+' hub',(x,y,z),r*.53,.09,M['steel'],axis,12)

def crane():
    orange=material('Crane ochre paint','B58B34',.6,.1)
    box('Heavy crane plinth',(-.52,0,.09),(1.40,1.30,.18),M['dark'],.012)
    for x in (-.88,-.16):
        for y in (-.37,.37):box('Lattice tower upright',(x,y,1.26),(.07,.07,2.38),orange,.004)
    for z in (.35,.85,1.35,1.85,2.35):
        for y in (-.37,.37):
            beam('Tower horizontal tie',(-.88,y,z),(-.16,y,z),.025,orange)
            beam('Tower diagonal brace',(-.88,y,z-.25),(-.16,y,z+.25),.023,orange)
        for x in (-.88,-.16):beam('Lateral lattice tie',(x,-.37,z),(x,.37,z),.022,orange)
    box('Crane cab',(-.53,-.02,2.44),(.96,.82,.52),orange,.025)
    for x in (-.73,-.34):box('Cab front glazing',(x,-.44,2.49),(.30,.015,.29),M['glass'],.008)
    for z in (2.85,3.12):beam('Upper boom chord',(-1.15,0,z),(1.40,0,z),.028,orange)
    for x in (-1.15,-.65,-.15,.35,.85,1.4):beam('Boom lattice', (x,0,2.85),(min(x+.50,1.4),0,3.12),.024,orange)
    box('Crane counterweight',(-1.08,0,2.88),(.35,.44,.23),M['dark'],.007)
    beam('Hoist cable',(1.31,0,2.90),(1.31,0,1.87),.008,M['dark'])
    tube('Open hoist hook',[(1.31,0,1.87),(1.31,0,1.79),(1.36,0,1.74),(1.42,0,1.79)],.018,M['steel'])
    h.ticket_anchor((-.53,-.437,2.25))

def giant_clock():
    # Standing clock prop, with a clean dial and a real supporting cabinet.
    box('Clock cabinet plinth',(0,0,.09),(1.18,.62,.18),M['wood'],.022)
    box('Clock cabinet body',(0,0,1.11),(.98,.52,1.94),M['wood'],.015)
    box('Inset lower panel',(0,-.271,1.04),(.75,.025,1.55),M['edge'],.012)
    box('Pendulum window',(0,-.29,1.11),(.49,.015,1.20),M['glass'],.008)
    beam('Brass pendulum rod',(0,-.312,1.52),(0,-.312,.64),.014,M['brass'])
    cylinder('Pendulum brass disk',(0,-.325,.63),.13,.025,M['brass'],(0,-1,0),20)
    cylinder('Clock round head',(0,0,2.22),.57,.53,M['wood'],(0,1,0),24)
    cylinder('Clock cream face',(0,-.281,2.22),.48,.012,M['cream'],(0,1,0),24)
    ring('Clock dial rim',(0,-.298,2.22),.495,.017,M['brass'],True)
    for i in range(12):
        a=i*math.tau/12
        obj=box('Clock hour index',(.408*math.sin(a),-.293,2.22+.408*math.cos(a)),(.023,.009,.074),M['ink'],0);obj.rotation_euler.y=a
    beam('Clock hour hand',(0,-.311,2.22),(-.23,-.311,2.36),.018,M['ink'])
    beam('Clock minute hand',(0,-.318,2.22),(.25,-.318,2.52),.012,M['ink'])
    cylinder('Clock hand pivot',(0,-.325,2.22),.032,.018,M['brass'],(0,1,0),12)
    h.ticket_anchor((.33,-.29,.30))

def bus():
    cream=material('Bus warm cream paint','D6D2B9',.46,.1);blue=M['blue']
    # Front shell and short return sides retain the theater-set construction.
    box('Blue lower front shell',(0,-.25,.68),(2.38,.24,1.18),blue,.10)
    box('Bus upper body frame',(0,-.20,1.95),(2.35,.19,1.24),cream,.07)
    for x in (-.56,.56):box('Split windshield',(x,-.313,1.94),(1.01,.018,.83),M['glass'],.025)
    box('Destination recess',(0,-.307,2.56),(1.55,.035,.18),M['dark'],.025)
    text('Destination display','STUDIO',(0,-.331,2.56),.12,M['cream'])
    box('Front bumper',(0,-.41,.29),(2.52,.16,.15),M['steel'],.025)
    box('Center grille shadow',(0,-.378,.74),(1.25,.02,.38),M['dark'],.025)
    for z in (.62,.72,.82):box('Horizontal chrome grille',(0,-.398,z),(1.16,.018,.026),M['steel'],.004)
    for x in (-.91,.91):
        cylinder('Round headlamp bezel',(x,-.39,.82),.145,.055,M['steel'],(0,1,0),16)
        cylinder('Round pale headlight',(x,-.423,.82),.117,.008,M['cream'],(0,1,0),16)
        box('Amber turn signal',(x,-.391,1.13),(.19,.017,.08),M['yellow'],.01)
        tube('Windshield wiper',[(x*.4,-.332,1.59),(x*.65,-.332,1.91),(x*.76,-.332,2.1)],.012,M['dark'])
    for x in (-1.15,1.15):box('Shell return edge',(x,.035,1.40),(.11,.57,2.5),cream,.03)
    box('Bus rounded roof',(0,-.13,2.73),(2.38,.45,.14),cream,.04)
    box('Front number plate',(0,-.504,.35),(.44,.012,.17),M['paper'],.008)
    text('Bus plate digits','08',(0,-.515,.35),.11,M['ink']);back_support(2.3,2.5,1.15)
    h.ticket_anchor((.70,-.392,.43))

def capsule():
    ivory=material('Capsule aged white shell','D2D1C2',.54,.1)
    lathe('Continuous space capsule shell',[(0,0),(.94,0),(.95,.13),(.86,.19),(.85,1.35),(.75,1.73),(.55,2.15),(.46,2.46),(.26,2.58),(0,2.58)],ivory,sides=20)
    for z,r in [(.16,.90),(1.35,.85),(1.77,.73)]:ring('Capsule panel collar',(0,0,z),r,.021,M['steel'],n=20)
    box('Capsule door gasket',(0,-.82,.99),(.75,.12,1.45),M['dark'],.09)
    box('Capsule shaped hatch',(0,-.895,.99),(.67,.055,1.35),ivory,.09)
    cylinder('Circular observation window',(0,-.934,1.20),.225,.035,M['steel'],(0,-1,0),20)
    cylinder('Recessed blue porthole',(0,-.958,1.20),.185,.008,M['glass'],(0,-1,0),20)
    for x in (-.26,.26):box('Visible door hinge',(x,-.947,.70),(.075,.045,.15),M['steel'],.009)
    box('Red door latch',(.24,-.957,1.03),(.032,.04,.19),M['red'],.006)
    for i in range(6):
        a=i*math.tau/6
        cylinder('Heatshield fastening bolt',(.89*math.cos(a),.89*math.sin(a),.08),.035,.025,M['dark'],vertices=8)
    h.ticket_anchor((0,-.941,.51))

def train():
    black=material('Locomotive charcoal enamel','30383A',.45,.35);red=M['red']
    box('Locomotive red chassis',(0,0,.27),(2.05,1.71,.28),red,.025)
    for x in (-.92,.92):
        for y in (-.55,.50):wheel('Locomotive road wheel',x,y,.25,.25)
    cylinder('Horizontal boiler body',(0,0,1.14),.65,1.66,black,(0,1,0),24)
    cylinder('Front boiler silver band',(0,-.852,1.14),.66,.06,M['steel'],(0,1,0),24)
    cylinder('Recessed boiler face',(0,-.892,1.14),.60,.03,black,(0,1,0),24)
    ring('Boiler front rim',(0,-.916,1.14),.61,.018,M['dark'],True)
    for x in (-.3,.3):box('Boiler hinge',(x,-.93,1.13),(.09,.04,.15),M['steel'],.008)
    cylinder('Boiler center handwheel',(0,-.96,1.14),.11,.06,M['brass'],(0,1,0),12)
    lathe('Flared locomotive chimney',[(.17,0),(.17,.48),(.25,.56),(.25,.66),(.15,.66),(.13,.60),(.13,0)],black,(0,0,1.72),sides=16)
    box('Headlamp bracket',(0,-.5,1.87),(.25,.25,.10),red,.008)
    cylinder('Round top headlamp',(0,-.57,2.01),.13,.19,M['brass'],(0,1,0),16)
    cylinder('Headlamp glass',(0,-.676,2.01),.105,.012,M['cream'],(0,1,0),16)
    for x in (-.60,.60):beam('Long boiler grab rail',(x,-.65,1.45),(x,.69,1.45),.018,M['brass'])
    # Open slats retain the characteristic cowcatcher silhouette.
    for x in (-.95,-.63,-.31,0,.31,.63,.95):beam('Cowcatcher steel slat',(x,-.75,.39),(x*.8,-1.06,.09),.025,red)
    box('Cowcatcher lower rail',(0,-1.06,.09),(2.10,.08,.08),red,.008)
    h.ticket_anchor((.38,-.933,.78))

def windmill():
    plaster=material('Windmill warm plaster','D0C3A2',.87)
    # Tapered tower, supported facade returns and four lattice sails.
    profile('Tapered mill tower',[(-.66,.07),(.66,.07),(.46,2.25),(-.46,2.25)],0,.72,plaster,.008)
    profile('Pitched mill roof',[(-.56,2.23),(0,2.90),(.56,2.23)],0,.90,M['red'],.008)
    box('Mill door',(0,-.375,.48),(.37,.035,.80),M['wood'],.018)
    cylinder('Mill door latch',(.12,-.406,.48),.022,.04,M['brass'],(0,1,0),12)
    for z in (1.28,1.94):
        box('Small tower window',(0,-.373,z),(.25,.024,.30),M['glass'],.01)
        box('Window crossbar',(0,-.391,z),(.025,.012,.29),M['cream'],.002)
    hub=Vector((0,-.55,1.88));angle=.25
    for i in range(4):
        a=angle+i*math.pi/2;u=Vector((math.cos(a),0,math.sin(a)));v=Vector((-math.sin(a),0,math.cos(a)))
        for side in (-1,1):
            p=hub+u*.13+v*side*.13;q=hub+u*1.40+v*side*.13
            beam('Windmill long sail spar',p,q,.022,M['wood'])
        for t in (.30,.52,.74,.96,1.18,1.40):beam('Windmill lattice sail rung',hub+u*t-v*.13,hub+u*t+v*.13,.015,M['edge'])
    cylinder('Windmill brass axle',hub,.10,.18,M['brass'],(0,1,0),16)
    back_support(1.28,2.1,1.24);h.ticket_anchor((.43,-.377,.28))

def car():
    paint=material('Vintage car muted red paint','873E36',.43,.25)
    box('Car chassis',(0,0,.25),(2.12,1.80,.21),M['dark'],.025)
    for x in (-.96,.96):wheel('Front car wheel',x,-.20,.27,.27)
    box('Car hood',(0,-.12,.77),(1.52,1.28,.44),paint,.10)
    box('Rear upright windshield frame',(0,.61,1.26),(1.63,.09,.68),paint,.035)
    box('Dark windshield',(0,.553,1.28),(1.46,.018,.51),M['glass'],.016)
    for x in (-.88,.88):
        box('Rounded front fender',(x,-.21,.57),(.45,1.34,.31),paint,.10)
        cylinder('Round car lamp bezel',(x,-.91,.71),.15,.12,M['steel'],(0,1,0),16)
        cylinder('Car headlamp glass',(x,-.98,.71),.122,.012,M['cream'],(0,1,0),16)
    box('Car front grille',(0,-.81,.60),(.86,.06,.42),M['dark'],.025)
    for x in (-.34,-.23,-.12,0,.12,.23,.34):box('Grille metal upright',(x,-.85,.60),(.025,.015,.36),M['steel'],.003)
    box('Front chrome bumper',(0,-1.0,.27),(2.17,.11,.11),M['steel'],.02)
    box('Car plate',(0,-1.063,.31),(.43,.012,.15),M['paper'],.005)
    text('Car plate digits','24',(0,-1.075,.31),.10,M['ink']);h.ticket_anchor((.31,-.784,.89))

def rowboat():
    # Continuous solid hull wall follows the keel, broad middle and pinched ends.
    n=20;verts=[]
    for ring_id in range(4):
        for i in range(n):
            a=i*math.tau/n;x=.78*math.cos(a);y=1.4*math.sin(a)
            if ring_id in (0,1):x*=.35;y*=.84
            if ring_id==0:z=.06
            elif ring_id==1:z=.12
            else:z=.55+.10*abs(math.sin(a))**3
            if ring_id in (1,3):x*=.92;y*=.97
            verts.append((x,y,z))
    faces=[]
    for j,k in [(0,2),(2,3),(3,1),(1,0)]:
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,k*n+(i+1)%n,k*n+i))
    faces.extend([tuple(reversed(range(n))),tuple(range(n,2*n))])
    f.mesh('Thick wooden clinker boat hull',verts,faces,M['wood'],False)
    for z,factor in [(.28,.62),(.43,.84),(.58,1.)]:
        pts=[(.78*factor*math.cos(t),1.4*(.84+.16*factor)*math.sin(t),z+.10*abs(math.sin(t))**3) for t in [i*math.tau/n for i in range(n)]]
        tube('Hull plank course',pts,.013,M['edge'],True)
    for y,width in [(-.64,.90),(.18,1.33),(.75,.79)]:box('Wooden thwart seat',(0,y,.44),(width,.20,.055),M['edge'],.006)
    for x in (-.27,0,.27):box('Bottom floorboard',(x,0,.145),(.23,1.75,.04),M['wood'],.003)
    for side in (-1,1):
        beam('Oar shaft',(side*.25,-.35,.49),(side*.88,.84,.58),.022,M['edge'])
        blade=box('Oar broad blade',(side*.88,.92,.58),(.14,.37,.025),M['edge'],.01);blade.rotation_euler.z=side*.30
    h.ticket_anchor((0,-1.24,.44))

def rickshaw():
    dark=M['dark'];red=M['red'];wood=M['wood']
    box('Passenger platform',(0,0,.55),(1.23,1.20,.16),wood,.008)
    box('Rickshaw seat cushion',(0,.10,.83),(1.13,.66,.20),red,.045)
    box('Rickshaw upholstered back',(0,.55,1.18),(1.12,.16,.70),red,.06)
    for x in (-.66,.66):
        cylinder('Rickshaw wheel tire',(x,0,.50),.50,.12,dark,(1,0,0),20)
        cylinder('Wheel spoke dark inset',(x*1.1,0,.50),.43,.015,M['wood'],(1,0,0),20)
        # Six strong spokes, no dense wire web.
        for i in range(6):
            t=i*math.tau/6
            beam('Wheel radial spoke',(x*1.13,0,.50),(x*1.13,.41*math.cos(t),.50+.41*math.sin(t)),.012,M['steel'])
        beam('Long pulling shaft',(x*.75,-.32,.59),(x*.70,-1.78,.88),.033,wood)
        beam('Canopy front upright',(x*.85,-.25,.75),(x*.85,-.25,1.82),.022,dark)
        beam('Canopy rear upright',(x*.85,.57,.62),(x*.85,.57,1.82),.022,dark)
        box('Rickshaw armrest',(x*.84,.11,1.02),(.09,.82,.08),wood,.012)
    # Four broad bent canopy sections, slight crown and real thickness.
    for i in range(4):
        y=-.33+i*.29
        obj=box('Canopy cloth panel',(0,y,1.83), (1.31,.30,.06),M['cream'],.015)
    h.ticket_anchor((0,-.253,.80))

def pedestal():
    stone=material('Pedestal pale limestone','B9B49D',.88)
    for at,size in [((0,0,.09),(1.1,1.1,.18)),((0,0,.23),(.93,.93,.12)),((0,0,.66),(.73,.73,.76)),((0,0,1.06),(.90,.90,.13)),((0,0,1.20),(1.03,1.03,.15))]:box('Stepped stone pedestal',at,size,stone,.015)
    for x in (-.29,.29):box('Pedestal recessed vertical edge',(x,-.373,.66),(.035,.012,.60),M['edge'],.003)
    box('Inset display inscription',(0,-.38,.76),(.38,.01,.14),M['brass'],.006)
    h.ticket_anchor((0,-.381,.49))

def waterwheel():
    for x in (-.75,.75):
        box('Waterwheel stone pier',(x,0,.64),(.42,.65,1.28),M['wood'],.006)
        box('Pier cap',(x,0,1.30),(.49,.72,.12),M['edge'],.008)
    cylinder('Waterwheel central axle',(0,0,1.27),.10,1.70,M['dark'],(1,0,0),12)
    # Wheel turns around X, as a broad scenic side-view wheel.
    for x in (-.29,.29):
        pts=[(x,1.10*math.cos(t),1.27+1.10*math.sin(t)) for t in [i*math.tau/20 for i in range(20)]]
        tube('Heavy wheel ring',pts,.045,M['wood'],True)
        for i in range(8):
            t=i*math.tau/8
            beam('Waterwheel timber spoke',(x,0,1.27),(x,1.08*math.cos(t),1.27+1.08*math.sin(t)),.035,M['wood'])
    for i in range(12):
        t=i*math.tau/12
        obj=box('Water-catching paddle',(0,1.08*math.cos(t),1.27+1.08*math.sin(t)),(.71,.25,.055),M['edge'],.003);obj.rotation_euler.x=t
    rotation=Matrix.Rotation(math.pi/2,4,'Z')
    bpy.context.view_layer.update()
    for obj in h.PARTS:obj.matrix_world=rotation@obj.matrix_world
    h.ticket_anchor((0,-.985,.62))

def turnstile():
    box('Ticket station broad base',(0,0,.045),(2.10,.88,.09),M['dark'],.012)
    for x in (-.81,.81):
        box('Folded sheet metal turnstile column',(x,0,.65),(.43,.64,1.20),M['steel'],.025)
        box('Blue top ticket reader',(x,-.03,1.27),(.43,.60,.09),M['blue'],.012)
        box('Black ticket slot',(x,-.12,1.321),(.19,.026,.004),M['dark'],.003)
        box('Green direction arrow',(x,-.334,.94),(.12,.01,.07),M['green'],.002)
    cylinder('Turnstile hub',(-.52,0,.77),.13,.14,M['dark'],(1,0,0),16)
    for i in range(3):
        t=i*math.tau/3
        p=Vector((-.44,0,.77));q=Vector((.44,.30*math.cos(t),.77+.30*math.sin(t)))
        beam('Three turnstile stainless arms',p,q,.027,M['steel'])
    h.ticket_anchor((.81,-.333,.54))

def mountain():
    board=material('Painted scenic green cardboard','71866C',.92);snow=M['cream']
    verts=[(-1,-.8,0),(.95,-.8,0),(.95,.82,0),(-1,.82,0),(-.5,.02,.83),(.12,.12,1.30),(.68,.23,.74),(0,-.4,.48),(-.4,.55,.45)]
    faces=[(0,1,7),(1,6,7),(1,2,6),(2,5,6),(2,3,8),(3,4,8),(3,0,4),(0,7,4),(4,7,5),(7,6,5),(4,5,8),(8,5,2),(3,2,1,0)]
    obj=f.mesh('Low polygon folded mountain',verts,faces,board,False)
    f.mesh('Broad painted snow cap',[(-.17,.10,.98),(.12,.12,1.307),(.35,.17,1.03),(.14,-.02,.88)],[(0,1,2),(0,2,3)],snow,False)
    apex=Vector((.12,.12,1.30))
    for left,right in [(Vector((-.5,.02,.83)),Vector((0,-.4,.48))),(Vector((0,-.4,.48)),Vector((.68,.23,.74)))]:
        p=apex.lerp(left,.48);q=apex.lerp(right,.38)
        normal=(left-apex).cross(right-apex).normalized()
        if normal.y>0:normal=-normal
        shift=normal*.003
        f.mesh('Snow painted on folded upper face',[apex+shift,p+shift,q+shift],[(0,1,2)],snow,False)
    for y in (-.5,.5):box('Cardboard base reinforcement' ,(0,y,.035),(1.7,.07,.07),M['wood'],0)
    h.ticket_anchor((-.60,-.806,.12))

def bicycle():
    paper=M['paper'];ink=M['blue']
    # Finite thickness cardboard wheel silhouettes, spokes represented as broad cuts.
    for y in (-.53,.53):
        cylinder('Thick cardboard wheel',(0,y,.28),.28,.018,paper,(1,0,0),20)
        for side in (-1,1):
            cylinder('Painted wheel inset',(side*.011,y,.28),.245,.002,ink,(1,0,0),20)
            cylinder('Wheel white center',(side*.013,y,.28),.20,.002,paper,(1,0,0),20)
        for i in range(6):
            t=i*math.tau/6
            for side in (-1,1):
                beam('Cardboard broad spoke',(side*.018,y,.28),(side*.018,y+.22*math.cos(t),.28+.22*math.sin(t)),.006,ink)
    pts=[(0,-.53,.28),(0,-.16,.65),(0,.18,.28),(0,-.53,.28),(0,.19,.67),(0,.53,.28),(0,.18,.28),(0,-.16,.65),(0,.19,.67)]
    tube('Painted cardboard bicycle frame',pts,.020,ink)
    box('Cardboard saddle',(0,-.18,.72),(.14,.25,.032),M['wood'],.01)
    beam('Seat post',(0,-.16,.65),(0,-.16,.72),.016,ink)
    tube('Bent cardboard handlebar',[(0,.19,.67),(0,.22,.87),(-.23,.22,.87),(.23,.22,.87)],.018,M['wood'])
    box('Bicycle cardboard foot',(0,0,.015),(.54,.20,.03),paper,.002)
    h.ticket_anchor((-.024,-.13,.45))

BUILDS={'S098_crane_tower':crane,'S096_giant_clock':giant_clock,'S090_bus_front_shell':bus,'S093_space_capsule':capsule,'S091_train_engine_front':train,'S100_scenic_windmill':windmill,'S089_car_front_shell':car,'S092_rowboat_shell':rowboat,'S094_rickshaw_cart':rickshaw,'S095_treasure_pedestal':pedestal,'S097_waterwheel':waterwheel,'S099_ticket_turnstile':turnstile,'X001_paper_mountain':mountain,'X002_cardboard_bicycle':bicycle}

def main():
    global M
    rows=[];mapping=[]
    entries=json.loads((h.PROJECT/'docs/PROP_REBUILD_MANIFEST.json').read_text(encoding='utf-8'))['entries']
    for original,build in BUILDS.items():
        bpy.ops.wm.read_factory_settings(use_empty=True);h.PARTS.clear();h.MARKERS.clear();M=s.palette();s.M=M;build()
        s.fit_bake(original);row=h.export_asset(original+'_rebuilt');entry=next(e for e in entries if e['original_file']==original)
        row.update(kind=entry['kind'],textures_embedded=False,style='lower-poly');rows.append(row);mapping.append(dict(kind=entry['kind'],original_file=original,file=original+'_rebuilt'))
    (SOURCE/'build_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (SOURCE/'replacements.json').write_text(json.dumps(mapping,indent=2),encoding='utf-8')
    print('SCENIC_BUILD_OK',len(rows))
if __name__=='__main__':main()
