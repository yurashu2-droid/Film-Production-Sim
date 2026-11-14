"""Reference-led lower-poly adventure and comedy props; Z-up/front -Y."""
from pathlib import Path
import importlib.util,json,math,sys
import bpy,bmesh
from mathutils import Vector,Matrix
SOURCE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('story_fresh',SOURCE.parents[1]/'fresh_props/source/build_assets.py')
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f);h=f.h
box,cylinder,material=h.box,h.cylinder,h.material

def finish(obj,mat,bevel=0,smooth=True):
    obj.data.materials.append(mat);bpy.context.view_layer.objects.active=obj
    if bevel:
        mod=obj.modifiers.new('One edge bevel','BEVEL');mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for p in obj.data.polygons:p.use_smooth=True
        mod=obj.modifiers.new('Weighted broad face normals','WEIGHTED_NORMAL');mod.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    h.PARTS.append(obj);return obj
h.finish=finish

def palette():
    return {k:material(k,c,r,m) for k,c,r,m in [
    ('wood','795439',.7,0),('edge','B99055',.65,0),('brass','BDA063',.37,.75),
    ('steel','ADB6B8',.38,.75),('dark','252D30',.65,.1),('paper','D9CCAA',.91,0),
    ('cream','F4E9CB',.72,0),('ink','36383A',.8,0),('red','973F34',.6,0),
    ('blue','3B6975',.57,0),('green','62804A',.75,0),('yellow','DAB638',.5,0),
    ('rubber','D4A42B',.59,0),('leather','78503D',.76,0),('glass','3D6975',.22,.25)]}

def lathe(name,profile,mat,at=(0,0,0),axis=(0,0,1),sides=20):
    obj=f.lathe(name,profile,mat,sides);obj.location=at
    obj.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler();return obj

def ball(name,at,scale,mat):return h.ellipsoid(name,at,scale,mat,16,8)
def tube(name,pts,r,mat,closed=False):return h.tube(name,pts,r,mat,closed,sides=6)
def beam(name,a,b,r,mat):return cylinder(name,(Vector(a)+Vector(b))/2,r,(Vector(b)-Vector(a)).length,mat,Vector(b)-Vector(a),12)
def ring(name,at,r,thick,mat,vertical=False,n=24):
    pts=[(at[0]+r*math.cos(t),at[1] if vertical else at[1]+r*math.sin(t),at[2]+r*math.sin(t) if vertical else at[2]) for t in [i*math.tau/n for i in range(n)]]
    return tube(name,pts,thick,mat,True)
def profile(name,pts,y,depth,mat,bevel=.001):return h.extruded_profile(name,pts,y,depth,mat,bevel)
def text(name,body,at,size,mat):
    bpy.ops.object.text_add(location=at,rotation=(math.pi/2,0,0));obj=bpy.context.object;obj.name=name
    obj.data.body=body;obj.data.size=size;obj.data.align_x='CENTER';obj.data.align_y='CENTER';obj.data.resolution_u=1
    obj.data.materials.append(mat);bpy.ops.object.convert(target='MESH');h.PARTS.append(bpy.context.object)

def newspaper():
    box('Folded newspaper pages',(0,0,.17),(.28,.024,.34),M['paper'],.001)
    box('Folded spine',(0,.012,.17),(.28,.005,.337),M['cream'],.001)
    text('Masthead','THE DAILY',(0,-.0135,.288),.031,M['ink'])
    box('Headline rule',(0,-.014,.26),(.248,.0005,.002),M['ink'],0)
    text('Headline','STUDIO NEWS',(0,-.014,.243),.016,M['ink'])
    box('News photograph block',(-.066,-.014,.183),(.104,.001,.081),M['blue'],0)
    for col in range(3):
        x=-.082+col*.082
        for line in range(9):
            z=.124-line*.01
            box('Printed newspaper column',(x,-.0145,z),(.067 if line%4 else .055,.0005,.0015),M['ink'],0)
    for line in range(7):box('Article beside photo',(.062,-.014,.212-line*.011),(.098,.0005,.0015),M['ink'],0)

def treasure_map():
    # One slight crease, broad quiet panels and a few illustrative ink shapes.
    box('Old map sheet',(0,0,.14),(.375,.004,.28),M['paper'],0)
    for x in (-.15,.15):box('Printed border',(x,-.0026,.14),(.0015,.001,.236),M['edge'],0)
    for z in (.023,.257):box('Printed border',(0,-.0026,z),(.302,.001,.0015),M['edge'],0)
    outline=[(-.13,.10),(-.105,.18),(-.06,.20),(-.018,.16),(.024,.19),(.085,.14),(.065,.07),(.014,.09),(-.025,.065),(-.08,.085)]
    profile('Island silhouette',outline,-.0033,.0006,M['green'],0)
    for a,b in [((-.10,-.004,.12),(-.06,-.004,.155)),((-.04,-.004,.157),(0,-.004,.14)),((.015,-.004,.137),(.045,-.004,.117))]:beam('Dotted treasure route',a,b,.0018,M['edge'])
    for s in (-1,1):beam('Treasure X',(.042,-.005,.105+s*.012),(.068,-.005,.105-s*.012),.002,M['red'])
    text('Map north','N',(.125,-.004,.221),.021,M['ink'])
    h.ticket_anchor((-.12,-.006,.04))

def compass():
    lathe('Pocket compass brass case',[(0,0),(.065,0),(.071,.006),(.071,.024),(.068,.029),(.061,.029),(.061,.022),(0,.022)],M['brass'],sides=24)
    cylinder('Ivory compass dial',(0,0,.023),.060,.002,M['cream'],vertices=24)
    # Raised pointer and major indices are enough at game distance.
    for i in range(16):
        t=i*math.tau/16;r=.051
        obj=box('Compass dial tick',(r*math.sin(t),r*math.cos(t),.025),(.002,.009 if i%4==0 else .004,.001),M['ink'],0);obj.rotation_euler.z=-t
    f.mesh('Red compass north pointer',[(0,.049,.028),(-.007,0,.028),(.007,0,.028)],[(0,1,2)],M['red'],False)
    f.mesh('Dark compass south pointer',[(0,-.047,.028),(-.007,0,.028),(.007,0,.028)],[(0,2,1)],M['ink'],False)
    cylinder('Needle pin',(0,0,.029),.004,.004,M['brass'],vertices=12)
    ring('Pendant hanging ring',(0,.083,.017),.011,.003,M['brass'])

def potion():
    lathe('Solid colored glass bottle',[(0,0),(.048,0),(.063,.012),(.074,.065),(.067,.115),(.043,.155),(.024,.171),(.024,.202),(.030,.205),(.030,.214),(.019,.217),(0,.217)],M['glass'],sides=20)
    cylinder('Cork stopper',(0,0,.226),.021,.035,M['edge'],vertices=12)
    box('Potion label',(0,-.069,.08),(.065,.003,.062),M['paper'],.002)
    profile('Potion label diamond',[(-.012,.08),(0,.099),(.012,.08),(0,.061)],-.0715,.0008,M['red'],0)
    ring('Bottle neck collar',(0,0,.179),.026,.003,M['leather'])

def sword():
    # Diamond-section foam blade: long clean planes and a shaped point.
    verts=[(-.032,0,.235),(0,-.011,.235),(.032,0,.235),(0,.011,.235),(-.022,0,.73),(0,-.008,.73),(.022,0,.73),(0,.008,.73),(0,0,.82)]
    faces=[(3,2,1,0)]+[(i,(i+1)%4,(i+1)%4+4,i+4) for i in range(4)]+[(i+4,(i+1)%4+4,8) for i in range(4)]
    f.mesh('Foam silver blade',verts,faces,M['steel'],False)
    profile('Curved brass crossguard',[(-.12,.225),(-.112,.245),(-.04,.253),(0,.244),(.04,.253),(.112,.245),(.12,.225),(.105,.22),(.035,.231),(-.035,.231),(-.105,.22)],0,.026,M['brass'],.003)
    cylinder('Leather hand grip',(0,0,.145),.018,.15,M['leather'],vertices=12)
    for z in (.085,.113,.141,.169,.197):ring('Sparse grip wrap',(0,0,z),.0185,.0018,M['edge'],n=12)
    ball('Wheel pommel',(0,0,.044),(.033,.017,.033),M['brass'])

def shield():
    lathe('Wooden shield disk',[(0,-.018),(.19,-.018),(.217,-.008),(.22,.012),(.205,.023),(0,.023)],M['wood'],at=(0,0,.22),axis=(0,-1,0),sides=24)
    ring('Iron shield rim',(0,-.017,.22),.209,.008,M['steel'],True)
    ball('Domed central shield boss',(0,-.033,.22),(.071,.032,.071),M['steel'])
    for x in (-.14,-.07,.07,.14):
        length=math.sqrt(.197**2-x*x)
        box('Long plank boundary',(x,-.025,.22),(.002,.001,length*2),M['edge'],0)
    for x in (-.105,.105):box('Rear shield brace',(x,.027,.22),(.025,.018,.29),M['wood'],.002)
    tube('Rear supported hand grip',[(-.045,.04,.21),(-.035,.08,.21),(.035,.08,.21),(.045,.04,.21)],.009,M['leather'])

def wand():
    cylinder('Dark wand handle',(0,0,.225),.009,.44,M['blue'],vertices=12)
    for z in (.02,.11,.40):cylinder('Wand metal collar',(0,0,z),.011,.012,M['brass'],vertices=12)
    star=[]
    for i in range(10):
        a=math.pi/2+i*math.pi/5;r=.087 if i%2==0 else .037
        star.append((r*math.cos(a),.49+r*math.sin(a)))
    profile('Raised five-point wand star',star,0,.021,M['brass'],.002)
    ball('Small central enamel jewel',(0,-.014,.49),(.017,.006,.017),M['blue'])

def scroll():
    box('Parchment scroll',(0,0,.20),(.32,.003,.35),M['paper'],0)
    for z in (.029,.371):
        cylinder('Wood scroll roller',(0,0,z),.022,.37,M['wood'],(1,0,0),16)
        for x in (-.19,.19):cylinder('Carved roller finial',(x,0,z),.026,.025,M['brass'],(1,0,0),12)
    for i in range(7):box('Calligraphic decree line',(0,-.0025,.29-i*.023),(.22-(i%3)*.017,.001,.002),M['ink'],0)
    ball('Red wax seal',(.068,-.006,.10),(.025,.004,.025),M['red'])
    text('Scroll title','DECREE',(0,-.004,.324),.027,M['ink'])

def spellbook():
    box('Quiet ivory page block',(0,0,.17),(.235,.078,.308),M['paper'],.002)
    for y in (-.048,.048):box('Leather wrapped board',(0,y,.17),(.26,.012,.34),M['blue'],.004)
    box('Rounded bound spine',(-.126,0,.17),(.024,.10,.34),M['blue'],.008)
    for z in (.035,.08,.26,.305):box('Spine raised band',(-.139,0,z),(.009,.098,.009),M['brass'],.002)
    for x in (-.10,.10):
        for z in (.025,.315):box('Brass book corner',(x,-.056,z),(.036,.004,.025),M['brass'],.002)
    ring('Cover magical emblem',(0,-.056,.175),.052,.003,M['brass'],True)
    profile('Cover diamond',[(-.022,.175),(0,.21),(.022,.175),(0,.14)],-.057,.003,M['brass'],0)
    for z in (.045,.098,.15,.20,.25,.30):box('Page edges',(.125,0,z),(.001,.074,.0015),M['edge'],0)

def spyglass():
    # Telescope extends along depth, matching the original prop's axis.
    for y,r,l,mat in [(-.14,.05,.15,M['leather']),(-.015,.043,.10,M['brass']),(.09,.034,.11,M['brass']),(.19,.026,.09,M['brass'])]:
        cylinder('Telescoping barrel',(0,y,.05),r,l,mat,(0,1,0),20)
        cylinder('Barrel rim',(0,y-l/2,.05),r+.003,.009,M['brass'],(0,1,0),20)
    cylinder('Recessed objective lens',(0,-.218,.05),.043,.003,M['glass'],(0,1,0),20)
    cylinder('Small eye lens',(0,.239,.05),.018,.003,M['glass'],(0,1,0),16)

def satchel():
    box('Leather gusseted satchel body',(0,0,.14),(.28,.10,.25),M['leather'],.022)
    box('Folded covering flap',(0,-.057,.22),(.278,.014,.15),M['wood'],.017)
    for x in (-.073,.073):
        box('Buckle fixing strap',(x,-.068,.152),(.025,.009,.13),M['leather'],.003)
        box('Brass buckle plate',(x,-.075,.14),(.032,.005,.034),M['brass'],.002)
        box('Buckle cutout',(x,-.079,.14),(.019,.001,.020),M['dark'],0)
    # Supported broad shoulder strap; thick rectangular ribbon instead of rope.
    path=[(-.14,.01,.24),(-.17,.02,.31),(-.13,.025,.36),(0,.025,.39),(.13,.025,.36),(.17,.02,.31),(.14,.01,.24)]
    verts=[]
    for x,y,z in path:verts.extend([(x,y-.014,z-.002),(x,y+.014,z-.002),(x,y+.014,z+.002),(x,y-.014,z+.002)])
    faces=[(3,2,1,0),tuple(range((len(path)-1)*4,len(path)*4))]
    for i in range(len(path)-1):
        for j in range(4):faces.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
    f.mesh('Continuous thick leather strap',verts,faces,M['leather'],True)

def banana():
    yellow=M['yellow'];cream=M['cream']
    cylinder('Broken banana neck',(0,0,.064),.022,.095,yellow,vertices=10)
    for branch in range(3):
        angle=branch*math.tau/3;verts=[]
        for i,(r,z,w) in enumerate([(0,.10,.014),(.025,.07,.029),(.07,.032,.036),(.105,.010,.027),(.135,.018,.010)]):
            for u in (-1,0,1):
                x=r*math.cos(angle)-u*w*math.sin(angle);y=r*math.sin(angle)+u*w*math.cos(angle)
                verts.append((x,y,z+(.006 if u==0 else 0)))
        faces=[]
        for i in range(4):
            for j in range(2):faces.append((i*3+j,i*3+j+1,(i+1)*3+j+1,(i+1)*3+j))
        obj=f.mesh('Curled peel lobe',verts,faces,cream,True)
        obj.data.materials.append(yellow)
        mod=obj.modifiers.new('Thick rubber banana skin','SOLIDIFY');mod.thickness=.006;mod.material_offset=1
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)
    ball('Dark banana stalk',(0,0,.11),(.014,.014,.018),M['wood'])

def sandwich():
    outline=[(-.11,-.095),(.11,-.095),(0,.10)]
    def layer(name,z,t,mat):
        verts=[(x,y,z) for x,y in outline]+[(x,y,z+t) for x,y in outline]
        return f.mesh(name,verts,[(2,1,0),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],mat,False)
    layer('Lower golden bread crust',0,.025,M['edge']);layer('Lower soft bread crumb',.024,.009,M['cream'])
    layer('Cheese slice',.033,.009,M['yellow']);layer('Folded lettuce',.042,.015,M['green'])
    layer('Thick ham filling',.057,.012,M['red']);layer('Top soft bread crumb',.069,.020,M['cream'])
    layer('Upper golden bread crust',.089,.012,M['edge'])
    for x,y in [(-.045,-.045),(.04,-.045),(0,.025)]:
        cylinder('Tomato cross section',(x,y,.06),.032,.011,M['red'],vertices=12)
        cylinder('Tomato pale core',(x,y,.066),.014,.001,M['paper'],vertices=10)

def cream_pie():
    lathe('Fluted silver pie tin',[(0,0),(.095,0),(.127,.02),(.132,.025),(.128,.03),(.119,.03),(.093,.007),(0,.007)],M['steel'],sides=24)
    lathe('Golden pastry crust',[(0,.009),(.10,.009),(.125,.03),(.127,.037),(.119,.043),(.105,.03),(0,.024)],M['edge'],sides=24)
    lathe('Cream filling',[(0,.024),(.108,.024),(.114,.041),(.106,.055),(.073,.071),(0,.077)],M['cream'],sides=20)
    for i in range(10):
        t=i*math.tau/10
        lathe('Whipped cream rosette',[(0,0),(.018,0),(.022,.008),(.015,.025),(.01,.038),(0,.045)],M['cream'],(.094*math.cos(t),.094*math.sin(t),.043),sides=8)
    lathe('Central cream swirl',[(0,0),(.032,0),(.025,.02),(.021,.035),(.009,.05),(0,.055)],M['cream'],(0,0,.07),sides=12)
    cylinder('Paper inventory flag stem',(0,-.065,.073),.0015,.10,M['edge'],vertices=6)
    box('Paper inventory flag',(0,-.066,.088),(.083,.002,.058),M['paper'],.001)
    h.ticket_anchor((0,-.068,.088))

def union_shell(name,parts,mat,voxel=.012,ratio=.20):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();obj=bpy.context.object;obj.name=name
    h.PARTS[:]=[o for o in h.PARTS if o not in parts]+[obj]
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=obj.modifiers.new('Continuous molded silhouette','REMESH');mod.mode='VOXEL';mod.voxel_size=voxel
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=obj.modifiers.new('Relax molded shell','SMOOTH');mod.factor=1.;mod.iterations=3;bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=obj.modifiers.new('Sparse toy shell topology','DECIMATE');mod.ratio=ratio;bpy.ops.object.modifier_apply(modifier=mod.name)
    for face in obj.data.polygons:face.use_smooth=True
    return obj

def duck():
    yellow=material('Duck warm yellow vinyl','E9BD28',.43)
    pieces=[ball('Duck body',(0,.035,.085),(.085,.135,.085),yellow),
            ball('Duck breast',(0,-.05,.11),(.076,.072,.09),yellow),
            ball('Duck neck',(0,-.068,.15),(.049,.05,.068),yellow),
            ball('Duck head',(0,-.08,.195),(.064,.06,.067),yellow),
            ball('Upturned duck tail',(0,.14,.10),(.036,.06,.057),yellow)]
    union_shell('Single molded duck shell',pieces,yellow,.008,.28)
    orange=material('Duck bill orange vinyl','D4772F',.46)
    for z,scale in [(.179,(.053,.044,.012)),(.164,(.047,.040,.009))]:ball('Molded bill lip',(0,-.14,z),scale,orange)
    for x in (-.056,.056):
        ball('Duck eye white',(x,-.106,.211),(.009,.006,.012),M['cream'])
        ball('Duck eye black',(x,-.111,.211),(.005,.003,.007),M['ink'])
    for s in (-1,1):
        pts=[(s*.079,.005,.10),(s*.085,.045,.12),(s*.073,.094,.10)]
        tube('Subtle molded wing ridge',pts,.003,yellow)
    h.ticket_anchor((0,-.115,.115))

def chicken():
    yellow=M['rubber']
    pieces=[ball('Chicken pear body',(0,0,.13),(.066,.052,.12),yellow),
            ball('Long rubber chicken neck',(0,0,.29),(.023,.025,.12),yellow),
            ball('Chicken head',(0,-.005,.395),(.035,.032,.05),yellow)]
    union_shell('Continuous rubber chicken body',pieces,yellow,.007,.25)
    red=material('Chicken red comb and feet','A94330',.66)
    for x in (-.04,.04):
        beam('Thin hanging leg',(x,0,.07),(x,0,.02),.011,red)
        for dx in (-.017,0,.017):beam('Three molded toes',(x,0,.018),(x+dx,-.04,.012),.006,red)
    for z in (.391,.416,.438):ball('Red comb lobe',(0,.014,z),(.009,.027,.014),red)
    ball('Rubber beak',(0,-.044,.398),(.019,.025,.012),M['yellow'])
    ball('Chicken wattle',(0,-.028,.367),(.012,.012,.025),red)
    for x in (-.030,.030):ball('Chicken black eye',(x,-.022,.411),(.005,.004,.005),M['ink'])
    for s in (-1,1):ball('Rubber chicken wing',(s*.057,0,.15),(.018,.04,.064),yellow)
    h.ticket_anchor((0,-.054,.13))

def poop():
    brown=material('Soft molded brown novelty rubber','775037',.78)
    points=[];verts=[];n=64;sides=8
    for i in range(n):
        t=i/(n-1);a=t*math.tau*2.65;r=.29*(1-t)**.76
        c=Vector((r*math.cos(a),r*math.sin(a),.10+t*.30));radius=.112*(1-t*.4)
        if i>n-7:radius*=max(.12,(n-i)/7)
        tangent=Vector((-r*math.sin(a),r*math.cos(a),.075)).normalized();u=tangent.cross(Vector((0,0,1))).normalized();v=tangent.cross(u)
        for j in range(sides):verts.append(c+radius*(u*math.cos(j*math.tau/sides)+v*math.sin(j*math.tau/sides)))
    faces=[tuple(reversed(range(sides))),tuple(range((n-1)*sides,n*sides))]
    for i in range(n-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    f.mesh('One tapered rubber coil',verts,faces,brown,True);h.ticket_anchor((.1,-.22,.10))

def torch():
    cylinder('Torch stained wooden handle',(0,0,.19),.019,.38,M['wood'],vertices=12)
    for z in (.34,.39):cylinder('Iron torch binding',(0,0,z),.038,.032,M['dark'],vertices=12)
    # Fixed translucent-looking painted flame shell, intentionally no extra VFX.
    flame=material('Torch painted orange shell','D6762F',.64)
    verts=[(-.055,0,.38),(.055,0,.38),(.064,0,.45),(.023,0,.48),(.045,0,.53),(-.007,0,.58),(-.025,0,.50),(-.049,0,.46)]
    profile('Broad shaped fake flame',[(x,z) for x,y,z in verts],0,.038,flame,.002)
    profile('Inner pale flame',[(-.026,.385),(.031,.385),(.033,.435),(.006,.477),(-.005,.44),(-.029,.426)],-.022,.005,M['yellow'],0)
    box('Torch paper inventory tag',(0,-.027,.16),(.10,.003,.071),M['paper'],.001)
    tube('Inventory tag cord',[(0,0,.24),(-.02,-.028,.20),(0,-.028,.195),(.02,-.028,.20),(0,0,.24)],.0015,M['leather'])
    h.ticket_anchor((0,-.030,.16))

def idol():
    stone=material('Owl molded metallic gold paint','C0A15B',.41,.70)
    box('Square owl plinth',(0,0,.023),(.19,.15,.045),stone,.005)
    ball('Carved owl body',(0,0,.138),(.084,.061,.108),stone)
    profile('Carved owl ears',[(-.081,.19),(-.092,.29),(-.033,.257),(.033,.257),(.092,.29),(.081,.19)],0,.093,stone,.003)
    for x in (-.039,.039):
        cylinder('Carved eye ring',(x,-.063,.22),.034,.009,M['edge'],(0,-1,0),12)
        cylinder('Inset eye',(x,-.069,.22),.019,.004,M['dark'],(0,-1,0),12)
    profile('Carved beak',[(-.014,.204),(0,.174),(.014,.204)],-.075,.014,M['edge'],.001)
    h.ticket_anchor((0,-.077,.023))
    for side in (-1,1):
        for z in (.09,.12,.15):beam('Wing carved chevron',(side*.075,-.037,z+.012),(side*.042,-.061,z-.01),.003,M['wood'])

BUILDS={'P020_newspaper':newspaper,'P021_treasure_map':treasure_map,'P022_compass':compass,'P023_potion_bottle':potion,'P024_foam_sword':sword,'P025_round_shield':shield,'P026_star_wand':wand,'P028_royal_scroll':scroll,'P032_spell_book':spellbook,'P033_spyglass':spyglass,'P034_adventure_satchel':satchel,'P040_banana_peel':banana,'P041_giant_sandwich':sandwich,'P042_cream_pie':cream_pie,'P043_rubber_chicken':chicken,'P049_rubber_duck':duck,'J001_rubber_poop':poop,'P030_fake_torch':torch,'P031_ancient_idol':idol}

def fit_bake(original):
    bpy.context.view_layer.update();bounds=json.loads((SOURCE/'original_envelopes.json').read_text())[original]
    target=Vector(bounds['max'])-Vector(bounds['min'])
    points=[o.matrix_world@v.co for o in h.PARTS for v in o.data.vertices]
    lo=Vector([min(v[i] for v in points) for i in range(3)]);hi=Vector([max(v[i] for v in points) for i in range(3)])
    scale=Vector([target[i]/(hi[i]-lo[i]) for i in range(3)])
    xf=Matrix.Diagonal((*scale,1))@Matrix.Translation(Vector((-(lo.x+hi.x)/2,-(lo.y+hi.y)/2,-lo.z)))
    for obj in h.PARTS:
        obj.data.transform(xf@obj.matrix_world);obj.matrix_world.identity()
        # Weld lathe poles before triangulation; normals recalculated by exporter.
        bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9);bm.to_mesh(obj.data);bm.free()
    for marker in h.MARKERS:marker.matrix_world=xf@marker.matrix_world
    bpy.context.view_layer.update()

def main():
    global M
    rows=[];mapping=[]
    entries=json.loads((h.PROJECT/'docs/PROP_REBUILD_MANIFEST.json').read_text(encoding='utf-8'))['entries']
    for original,build in BUILDS.items():
        bpy.ops.wm.read_factory_settings(use_empty=True);h.PARTS.clear();h.MARKERS.clear();M=palette();build()
        entry=next(e for e in entries if e['original_file']==original)
        if not h.MARKERS:
            # Runtime bag objects simply ignore an unused anchor.
            h.ticket_anchor((0,-.06,.1))
        fit_bake(original);row=h.export_asset(original+'_rebuilt');row.update(kind=entry['kind'],textures_embedded=False,style='lower-poly')
        rows.append(row);mapping.append(dict(kind=entry['kind'],original_file=original,file=original+'_rebuilt'))
    (SOURCE/'build_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (SOURCE/'replacements.json').write_text(json.dumps(mapping,indent=2),encoding='utf-8')
    print('STORY_BUILD_OK',len(rows))
if __name__=='__main__':main()
