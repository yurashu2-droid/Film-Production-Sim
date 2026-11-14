"""Outdoor street/scenic furniture, low-poly construction-led rebuilds."""
from pathlib import Path
import importlib.util,math,bpy,json
from mathutils import Vector
SOURCE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('interior_helpers',SOURCE.parents[1]/'rebuild_furniture_b/source/build_assets.py')
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q)
h=q.h;f=q.f;B=q.B;C=q.C;M=q.M;E=q.E;T=q.T;L=q.L;beam=q.beam;P=q.profile
def mats():
    global wood,edge,dark,paint,steel,cream,red,brass,glass,green,leaf,lightleaf,stone,mortar,water
    q.palette()
    wood=q.wood;edge=q.edge;dark=q.dark;paint=q.paint;steel=q.steel;cream=q.cream;red=q.red;brass=q.brass;glass=q.glass
    green=M('Deep green outdoor paint','34574B',.56)
    leaf=M('Broad leaf midgreen','47724B',.86);lightleaf=M('Young leaf lighter green','64834B',.9)
    stone=M('Weathered light stone','999C90',.85);mortar=M('Dark rough stone joint','5E675E',.96)
    water=M('Still scenic bluegreen water','376F79',.22,.35)
def ground_base(r=.3):C('Weighted scenic base',(0,0,.03),r,.06,edge,vertices=16)
def main_marker(at):h.ticket_anchor(at)
def kiosk():
    mats();B('Kiosk floor',(0,0,.025),(.90,.64,.05),dark,.004)
    B('Counter lower enclosure',(0,0,.28),(.88,.60,.50),green,.004)
    for x in (-.425,.425):
        B('Corner structural upright',(x,0,.69),(.045,.60,.38),green,.002)
    B('Kiosk back wall',(0,.28,.69),(.84,.035,.38),green,.002)
    B('Roof fascia',(0,0,.94),(.99,.68,.085),green,.005)
    B('Overhanging roof cap',(0,0,1.0),(1.04,.72,.035),edge,.004)
    B('Service counter',(0,-.27,.545),(.94,.15,.05),wood,.003)
    B('Deep interior service shelf',(0,.04,.62),(.80,.38,.025),edge,.002)
    B('Header signboard',(0,-.313,.855),(.77,.025,.12),cream,.002)
    # Three broad glyphs suggest a newspaper headline at miniature reading distance.
    for x,w in ((-.21,.11),(0,.18),(.23,.09)):B('Sign headline',(x,-.328,.855),(w,.005,.018),dark,0)
    for x in (-.32,0,.32):
        B('Display magazine cover',(x,-.312,.32),(.24,.018,.23),cream,.001)
        B('Cover headline',(x,-.326,.39),(.18,.006,.027),red,.001)
        B('Cover picture',(x-.02,-.327,.30),(.14,.006,.09),glass,.001)
    B('Front kickboard',(0,-.317,.11),(.88,.024,.11),green,.002)
    main_marker((.20,-.332,.11))
def lamp():
    mats();B('Streetlamp square foot',(0,0,.035),(.25,.25,.07),green,.006)
    L('Turned lamp post',[(0,.07),(.07,.07),(.07,.16),(.038,.19),(.028,.91),(.055,.94),(.055,.98),(0,.98)],green,24)
    B('Lantern lower tray',(0,0,.995),(.21,.21,.045),green,.005)
    B('Frosted lantern panes',(0,0,1.115),(.16,.16,.21),cream,.002)
    for x in (-.086,.086):
        for y in (-.086,.086):beam('Lantern corner iron',(x,y,1.01),(x*.82,y*.82,1.225),.013,green)
    # The roof rests directly on the panes (pane top z=1.22) instead of floating above them.
    L('Lantern pyramidal roof',[(0,1.215),(.16,1.215),(.14,1.24),(.04,1.315),(0,1.33)],green,4)
    C('Lantern finial',(0,0,1.35),.012,.045,brass,vertices=12)
    # A broad pole collar gives the runtime 13x8.5cm ticket a genuinely flat backing.
    B('Streetlamp flat ticket collar',(0,-.036,.30),(.18,.015,.12),green,.003)
    main_marker((0,-.046,.30))
def bridge():
    mats()
    z=lambda y:.03+.17*(1-(y/.60)**2)
    for j in range(13):
        y=-.60+j*.10
        o=B('Arched deck plank',(0,y,z(y)),(.61,.094,.035),wood,.002);o.rotation_euler.x=math.atan(-.34*y/.36)
    for x in (-.285,.285):
        pts=[(x,-.63+j*.105,z(-.63+j*.105)-.035) for j in range(13)]
        T('Continuous curved stringer',pts,.03,edge,sides=6)
        pts=[(x,-.63+j*.105,z(-.63+j*.105)+.34) for j in range(13)]
        T('Curved handrail',pts,.022,red,sides=6)
        for y in (-.60,-.30,0,.30,.60):B('Railing square post',(x,y,z(y)+.16),(.035,.035,.36),red,.002)
    # Small end-fascia backing supports the ticket without filling the central arch void.
    B('Bridge front ticket fascia',(0,-.642,.055),(.18,.018,.11),edge,.003)
    main_marker((0,-.654,.055))
def mushroom():
    mats();cap=M('Mushroom lacquer red','A84535',.42);under=M('Mushroom pale underside','D5BB8E',.72)
    ground_base(.215)
    L('Mushroom tapered stem',[(0,.05),(.12,.05),(.14,.12),(.095,.40),(.10,.62),(.16,.72),(0,.74)],cream)
    L('Mushroom continuous domed cap',[(0,.72),(.20,.70),(.36,.71),(.43,.76),(.42,.80),(.34,.89),(.23,.96),(0,1.0)],cap,24)
    L('Concave cap underside',[(.10,.70),(.21,.69),(.34,.71),(.40,.74),(.43,.76)],under,24)
    def cap_z(r):
        profile=[(0,1.0),(.23,.96),(.34,.89),(.42,.80),(.43,.76)]
        for (r0,z0),(r1,z1) in zip(profile,profile[1:]):
            if r<=r1:return z0+(z1-z0)*(r-r0)/(r1-r0)
        return .76
    for a,r in ((.3,.21),(1.5,.29),(2.7,.17),(3.8,.32),(5.1,.25)):
        # Painted dots conform to the upper cap profile; no hovering flattened spheres.
        cx,cy=r*math.cos(a),r*math.sin(a)
        pts=[(cx,cy,cap_z(r)+.003)]
        for i in range(12):
            t=i*math.tau/12;x=cx+.052*math.cos(t);y=cy+.047*math.sin(t)
            pts.append((x,y,cap_z(math.hypot(x,y))+.003))
        f.mesh('Pale cap painted spot',pts,[(0,i+1,(i+1)%12+1) for i in range(12)],cream)
    B('Stem ticket patch',(0,-.112,.28),(.15,.015,.11),cream,.003)
    main_marker((0,-.122,.28))
def tree():
    mats();ground_base(.265)
    L('Broadleaf tree sculpted trunk',[(0,.06),(.13,.06),(.10,.18),(.072,.56),(.065,1.05),(.035,1.3),(0,1.32)],edge,16)
    for a,end in [(.15,(.35,.02,1.30)),(2.7,(-.37,.04,1.23)),(4.8,(.02,-.24,1.47))]:
        p=(.01,0,.75);T('Branch carrying foliage',[p,(end[0]*.5,end[1]*.5,1.04),end],.035,wood)
    # Coherent crown with subordinate lobes, open branch necks below.
    for j,(x,y,z,s) in enumerate([(-.31,0,1.26,.34),(.30,.07,1.31,.35),(.025,-.16,1.50,.36),(-.17,-.07,1.47,.26),(.18,-.10,1.52,.24),(-.43,-.02,1.34,.16),(.45,.08,1.38,.16),(-.13,.20,1.39,.25),(.16,.25,1.38,.22)]):
        E('Grouped foliage crown',(x,y,z),(s,s*.85,s*.81),leaf if j%3 else lightleaf,12,6)
    B('Tree trunk ticket patch',(0,-.08,.44),(.15,.015,.11),wood,.003);main_marker((0,-.091,.44))
def cactus():
    mats();cactusmat=M('Matte cactus scenic paint','568064',.76);rib=M('Cactus ridge highlight','6B9371',.8)
    ground_base(.24)
    L('Rounded fluted cactus trunk',[(0,.06),(.10,.06),(.115,.16),(.115,1.37),(.09,1.46),(.05,1.50),(0,1.51)],cactusmat,16)
    for sx,z in ((-1,.48),(1,.77)):
        T('Raised cactus arm',[(sx*.08,0,z),(sx*.25,0,z),(sx*.34,0,z+.08),(sx*.34,0,z+.34)],.066,cactusmat,sides=12)
        E('Rounded cactus arm tip',(sx*.34,0,z+.34),(.066,.066,.068),cactusmat,12,6)
    for a in [i*math.tau/8 for i in range(8)]:T('Broad cactus ridge',[(.115*math.cos(a),.115*math.sin(a),.16),(.115*math.cos(a),.115*math.sin(a),1.36)],.006,rib)
    B('Cactus ticket patch',(0,-.12,.33),(.15,.012,.11),cactusmat,.003);main_marker((0,-.13,.33))
def campfire():
    mats();char=M('Charred log ends','3D3027',.95);flame=M('Painted scenic orange flame','DE7834',.7);yellow=M('Painted scenic yellow flame','E9BD55',.73)
    for i in range(10):
        a=i*math.tau/10;E('Ring stone',(math.cos(a)*.40,math.sin(a)*.40,.09),(.115,.10,.085),stone,12,6)
    for a,z in ((.35,.09),(1.8,.12),(2.7,.16)):
        d=Vector((math.cos(a),math.sin(a),0));C('Crossed firewood log',(0,0,z),.055,.59,edge,d,12)
        for s in (-1,1):C('Visible sawn log end',d*.30+Vector((0,0,z)),.047,.006,char,d,12)
    for x,y,ht in ((0,0,.48),(-.09,.02,.36),(.10,.06,.39)):
        P('Rigid painted flame silhouette',[(x-.09,.16),(x-.10,ht*.65),(x-.025,ht*.74),(x+.02,ht),(x+.06,ht*.65),(x+.10,.20)],y,.045,flame)
    P('Inner yellow flame',[(-.055,.16),(-.06,.27),(-.02,.25),(.018,.38),(.055,.22),(.07,.16)],-.033,.018,yellow)
    B('Scenic base front plaque',(0,-.43,.09),(.17,.025,.10),edge,.002);main_marker((0,-.445,.09))
def fountain():
    mats();C('Fountain pedestal slab',(0,0,.035),.60,.07,stone,vertices=24)
    L('Lower hollow fountain basin',[(0,.07),(.30,.07),(.38,.13),(.56,.23),(.57,.28),(.53,.30),(.50,.27),(.45,.22),(.29,.16),(0,.16)],stone)
    C('Lower still scenic water',(0,0,.19),.39,.008,water,vertices=24)
    L('Fountain turned column',[(0,.17),(.1,.17),(.10,.24),(.06,.32),(.06,.57),(.12,.61),(0,.63)],stone)
    L('Upper hollow fountain bowl',[(0,.60),(.13,.60),(.29,.67),(.30,.71),(.27,.73),(.24,.69),(.12,.65),(0,.65)],stone)
    C('Upper scenic water',(0,0,.67),.20,.008,water,vertices=24)
    L('Top spout pedestal',[(0,.65),(.048,.65),(.05,.70),(.032,.89),(.052,.91),(.035,.95),(0,.95)],stone)
    B('Base ticket plaque',(0,-.587,.05),(.17,.018,.085),stone,.003);main_marker((0,-.60,.05))
def bench():
    mats()
    for x in (-.48,.48):
        T('Continuous cast iron bench leg',[(x,-.28,.03),(x,-.24,.42),(x,.18,.42),(x,.30,.03)],.028,green)
        T('Bench back support',[(x,.18,.3),(x,.24,.89)],.022,green)
        T('Bench armrest',[(x,-.25,.42),(x,-.25,.64),(x,.20,.64)],.025,green)
    for y in (-.21,-.07,.07,.21):B('Timber seat slat',(0,y,.45),(1.2,.125,.045),wood,.003)
    for z in (.64,.81):
        o=B('Timber back slat',(0,.24,z),(1.2,.045,.14),wood,.003);o.rotation_euler.x=.11
def gable_roof(w,d,z,mat):
    for sx in (-1,1):
        o=B('Pitched roof plane',(sx*w*.25,0,z),((w/2+.04),d,.05),mat,.003);o.rotation_euler.y=sx*math.radians(27)
    C('Ridge cap',(0,0,z+w*.125),.035,d,edge,(0,1,0),12)
def well():
    mats()
    L('Deep open stone shaft',[(.30,0),(.45,0),(.45,.56),(.30,.56),(.30,0)],mortar,16)
    for row in range(3):
        for i in range(10):
            a=(i+(.5 if row%2 else 0))*math.tau/10
            o=B('Well masonry block',(.385*math.cos(a),.385*math.sin(a),.095+row*.18),(.23,.16,.17),stone,.012);o.rotation_euler.z=a+math.pi/2
    L('Well coping open ring',[(.29,.54),(.47,.54),(.47,.60),(.29,.60),(.29,.54)],stone,24)
    for x in (-.39,.39):B('Roof support post',(x,0,.81),(.065,.085,1.56),wood,.003)
    gable_roof(1.13,.84,1.67,red)
    C('Winding axle',(0,0,1.18),.033,.99,edge,(1,0,0),16)
    C('Rope drum',(0,0,1.18),.065,.20,wood,(1,0,0),16)
    T('Well rope',[(0,-.06,1.18),(0,-.06,.36)],.009,cream)
    T('Winding crank',[(.50,0,1.18),(.57,0,1.18),(.57,0,1.04),(.65,0,1.04)],.018,steel)
def stall():
    mats()
    for x in (-.64,.64):
        for y in (-.33,.33):
            height=1.66 if y<0 else 1.56
            B('Market frame upright',(x,y,height/2),(.055,.055,height),wood,.003)
    B('Market counter',(0,0,.70),(1.40,.80,.075),wood,.004)
    B('Counter front plank',(0,-.32,.40),(1.29,.045,.54),edge,.003)
    for x in (-.6,.6):B('Counter side plank',(x,0,.40),(.045,.62,.54),edge,.003)
    for j in range(7):
        x=-.60+j*.20
        o=B('Striped supported fabric canopy',(x,0,1.61),(.20,.98,.035),cream if j%2 else green,.002);o.rotation_euler.x=-.13
        B('Canopy front valance',(x,-.48,1.60),(.20,.025,.15),cream if j%2 else green,.003)
    for x in (-.40,0,.40):
        B('Produce crate',(x,0,.80),(.34,.48,.12),edge,.003)
        for j in range(3):E('Display fruit',(x-.10+j*.10,-.02,.89),(.055,.06,.055),red,12,6)
def shelter():
    mats();glass2=M('Opaque tinted shelter panel','8BA8A6',.31)
    for x in (-.82,.82):
        for y in (-.32,.32):B('Shelter structural post',(x,y,.83),(.045,.045,1.66),green,.002)
    B('Shelter rear panel',(0,.32,.86),(1.65,.022,1.35),glass2,.001)
    for x in (-.82,.82):B('Shelter side panel',(x,.04,.86),(.022,.53,1.35),glass2,.001)
    B('Flat shelter roof',(0,0,1.68),(1.87,.88,.075),green,.004)
    B('Roof fascia',(0,-.44,1.63),(1.86,.035,.12),cream,.003)
    B('Bench seat',(0,.08,.49),(1.25,.31,.055),wood,.004)
    for x in (-.49,.49):B('Bench floor support',(x,.08,.24),(.045,.18,.48),green,.002)
    B('Timetable case',(.52,.294,1.05),(.32,.025,.49),green,.002)
    B('Timetable paper',(.52,.277,1.05),(.27,.005,.43),cream,.001)
    for z in (.91,1.02,1.13):B('Timetable print line',(.52,.272,z),(.21,.002,.012),green,0)
def mailbox():
    mats();mailred=M('Mailbox painted postal red','AC3F32',.48)
    B('Mailbox foot',(0,0,.035),(.45,.38,.07),dark,.004)
    B('Mailbox pedestal',(0,.015,.24),(.17,.19,.40),mailred,.004)
    B('Postal box main body',(0,0,.69),(.55,.42,.63),mailred,.008)
    B('Mailbox weather cap',(0,0,1.025),(.60,.46,.075),mailred,.01)
    B('Letter slot recess',(0,-.217,.88),(.36,.018,.075),dark,.003)
    B('Letter slot hood',(0,-.246,.93),(.40,.09,.025),mailred,.004)
    B('Collection door recess',(0,-.216,.58),(.37,.015,.34),dark,.003)
    B('Collection door',(0,-.23,.58),(.34,.017,.31),mailred,.003)
    C('Collection lock',(.12,-.245,.59),.015,.01,brass,(0,-1,0),12)
    B('Mail collection label',(0,-.244,.69),(.23,.005,.08),cream,.002)
def signpost():
    mats();ground_base(.26);B('Signpost timber upright',(0,0,.83),(.095,.095,1.64),edge,.003)
    for x,z,s in ((-.12,1.43,1),(.10,1.13,-1),(-.03,.87,1)):
        pts=[(x-s*.45,z-.105),(x+s*.32,z-.105),(x+s*.47,z),(x+s*.32,z+.105),(x-s*.45,z+.105)]
        P('Arrow shaped plank',pts,-.065,.045,wood)
        for xx,w in ((x-.18,.12),(x,.16),(x+.20,.09)):B('Painted destination mark',(xx,-.091,z),(w,.005,.025),cream,0)
def signal():
    mats();ground_base(.25)
    C('Traffic signal pole',(0,.04,.70),.035,1.37,green,vertices=16)
    B('Signal housing',(0,0,1.30),(.30,.21,.75),dark,.018)
    lens=[M('Red signal lens','AF4539',.3),M('Amber signal lens','D6A443',.3),M('Green signal lens','528960',.3)]
    for z,mat in zip((1.54,1.30,1.06),lens):
        C('Signal lens bezel',(0,-.12,z),.10,.035,green,(0,-1,0),16)
        C('Signal circular lens',(0,-.143,z),.079,.018,mat,(0,-1,0),16)
        # Half-cylinder visor, open below; no expensive dense shell.
        vs=[]
        for y in (-.12,-.24):
            for i in range(9):
                a=i*math.pi/8;vs.append((.103*math.cos(a),y,z+.103*math.sin(a)))
        f.mesh('Signal top visor',vs,[(i,i+1,i+10,i+9) for i in range(8)],green)
def picket():
    mats()
    for x in (-.82,.82):
        B('Gate square post',(x,0,.57),(.11,.14,1.14),paint,.003)
        L('Picket post pyramidal cap',[(0,1.14),(.095,1.14),(0,1.24)],paint,4,at=(x,0,0))
    for z in (.28,.75):B('Gate structural rail',(0,.035,z),(1.54,.055,.07),paint,.002)
    for i in range(9):
        x=-.67+i*.168;P('Pointed timber picket',[(x-.055,.12),(x+.055,.12),(x+.055,.95),(x,1.04),(x-.055,.95)],-.025,.035,paint)
    beam('Gate diagonal brace',(-.69,.08,.25),(.69,.08,.8),.055,paint,.035)
    for x in (-.73,.73):B('Gate hinge plate',(x,-.052,.69),(.15,.012,.045),dark,.002)
def parapet():
    mats();brick=M('Warm brickwork','9A6250',.84);brick2=M('Brickwork alternate','AA725A',.85)
    B('Parapet mortar core',(0,0,.43),(1.58,.20,.80),mortar,.003)
    for row in range(5):
        # Staggered broad blocks, only the exterior face needs visible courses.
        count=5 if row%2 else 4;w=1.58/count
        for j in range(count):
            x=-.79+w*(j+.5)
            B('Staggered brick',(x,-.01,.1+row*.155),(w-.012,.27,.142),brick if (j+row)%3 else brick2,.004)
    B('Stone coping cap',(0,0,.87),(1.70,.35,.10),stone,.007)
    for x in (-.84,.84):B('Parapet end pier',(x,0,.46),(.20,.35,.92),brick,.006)
def fence():
    mats()
    for x in (-.82,.82):
        B('Iron fence post',(x,0,.64),(.075,.075,1.28),green,.003)
        L('Fence post finial',[(0,1.28),(.055,1.28),(.07,1.34),(0,1.45)],green,8,at=(x,0,0))
        B('Iron post foot',(x,0,.035),(.16,.22,.07),dark,.003)
    for z in (.24,1.07):B('Fence continuous rail',(0,0,z),(1.64,.045,.045),green,.002)
    for i in range(9):
        x=-.67+i*.168;B('Vertical iron picket',(x,0,.70),(.025,.025,1.10),green,.001)
        P('Spear tip',[(x-.045,1.19),(x,1.31),(x+.045,1.19),(x,1.21)],0,.025,green)
def pine():
    mats();ground_base(.3)
    C('Pine trunk',(0,0,.66),.065,1.20,edge,vertices=16)
    # Layered scalloped bough skirts with varying silhouette radii, not solid cones.
    for j,(z,r,ht) in enumerate(((.46,.63,.68),(.91,.48,.66),(1.30,.34,.56),(1.65,.20,.43))):
        n=16;vs=[]
        for ring,rad,zz in ((0,r,z),(1,r*.90,z+.10),(2,r*.28,z+ht*.75),(3,0,z+ht)):
            for i in range(n):
                a=i*math.tau/n;rr=rad*(1 if i%2 else .87)
                vs.append((rr*math.cos(a),rr*math.sin(a),zz+(0 if ring!=0 else (i%2)*.07)))
        faces=[tuple(reversed(range(n)))]
        for k in range(3):
            for i in range(n):faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
        f.mesh('Scalloped pine branch tier',vs,faces,leaf if j%2 else green,False)
def hedge():
    mats()
    pts=[(-.85,0),(-.85,1.22)]
    pts += [(.85*math.cos(math.pi-i*math.pi/12),1.22+.85*math.sin(math.pi-i*math.pi/12)) for i in range(13)]
    pts +=[(.85,0),(.56,0),(.56,1.22)]
    pts +=[(.56*math.cos(i*math.pi/12),1.22+.56*math.sin(i*math.pi/12)) for i in range(13)]
    pts +=[(-.56,0)]
    P('Open hedge arch',pts,0,.44,leaf)
    for x in (-.72,.72):B('Scenic hedge foot',(x,0,.045),(.43,.57,.09),edge,.003)
    for i in range(9):
        a=i*math.pi/8;x=.72*math.cos(a);z=1.22+.72*math.sin(a)
        E('Hedge outer leaf cluster',(x,-.02,z),(.18,.26,.16),lightleaf if i%3 else leaf,12,6)
    for x in (-.72,.72):
        for z in (.30,.70,1.1):E('Hedge column cluster',(x,0,z),(.18,.25,.22),leaf,12,6)
def pond():
    mats()
    # Organic shoreline rings and a recessed single supported water surface.
    n=24;vs=[]
    for rad,z in ((1,0),(1.03,.08),(.90,.14),(.77,.07)):
        for i in range(n):
            a=i*math.tau/n;r=rad*(1+.07*math.sin(3*a)+.035*math.cos(5*a))
            vs.append((.95*r*math.cos(a),.65*r*math.sin(a),z))
    faces=[]
    for k in range(3):
        for i in range(n):faces.append((k*n+i,k*n+(i+1)%n,(k+1)*n+(i+1)%n,(k+1)*n+i))
    f.mesh('Sculpted pond shore rim',vs,faces,stone)
    L('Recessed pond water',[(0,.065),(.73,.065),(.73,.07),(0,.07)],water,24,scale=(1.25,.87,1))
    pad=M('Lily pad muted green','759352',.7)
    for x,y,r in ((-.30,-.12,.10),(.28,.13,.13),(.43,-.11,.075)):
        C('Lily pad',(x,y,.08),r,.006,pad,vertices=12)
    for x,y in ((-.69,.12),(-.55,.28),(-.65,.25)):
        T('Pond bank reed',[(x,y,.10),(x+.02,y,.36)],.008,green)
def dock():
    mats()
    for x in (-.43,.43):
        for y in (-.79,0,.79):
            C('Dock round pile',(x,y,.37),.065,.74,edge,vertices=16)
            C('Pile cut top',(x,y,.75),.066,.018,wood,vertices=16)
        B('Dock longitudinal beam',(x,0,.39),(.08,1.78,.11),edge,.003)
    for i in range(12):B('Dock cross plank',(0,-.81+i*.147,.48),(1.03,.14,.06),wood,.002)
    T('Dock mooring rope',[(-.45,-.79,.72),(-.48,-.39,.61),(-.45,0,.72)],.013,cream)
BUILDERS={'S060':kiosk,'S051':lamp,'S074':bridge,'S070':mushroom,'S066':tree,'S068':cactus,'S072':campfire,'S053':fountain,'S052':bench,'S054':well,'S055':stall,'S056':shelter,'S057':mailbox,'S061':signpost,'S062':signal,'S063':picket,'S064':parapet,'S065':fence,'S067':pine,'S069':hedge,'S071':pond,'S075':dock}
if __name__=='__main__':q.build_packet(BUILDERS,SOURCE)
