"""Name/photo-led low-poly film equipment. Blender CLI only; old meshes supply envelope only."""
from pathlib import Path
import importlib.util, json, math, sys
import bpy, bmesh
from mathutils import Vector
SOURCE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('gear_b_helpers',SOURCE.parents[1]/'fresh_props/source/build_assets.py')
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f);h=f.h
ROOT=h.PROJECT.parent

def finish(obj,mat,bevel=0,smooth=True):
    obj.data.materials.append(mat);bpy.context.view_layer.objects.active=obj
    if bevel:
        mod=obj.modifiers.new('Single segment softened edge','BEVEL');mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for p in obj.data.polygons:p.use_smooth=True
        mod=obj.modifiers.new('Broad surface normals','WEIGHTED_NORMAL');mod.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    h.PARTS.append(obj);return obj
h.finish=finish
box=h.box;material=h.material
def cyl(name,at,r,length,mat,axis=(0,0,1),n=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=length,location=at)
    ob=bpy.context.object;ob.name=name;ob.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    return finish(ob,mat)
def bar(name,a,b,r,mat,n=6):
    a,b=Vector(a),Vector(b);return cyl(name,(a+b)/2,r,(b-a).length,mat,b-a,n)
def tube(name,points,r,mat,cyclic=False,n=6):
    points=[Vector(p) for p in points];verts=[]
    for j,p in enumerate(points):
        axis=points[(j+1)%len(points)]-points[j-1] if cyclic else points[min(j+1,len(points)-1)]-points[max(j-1,0)]
        axis.normalize();u=axis.cross(Vector((0,1,0)))
        if u.length<.01:u=axis.cross(Vector((1,0,0)))
        u.normalize();v=axis.cross(u).normalized()
        verts.extend([p+r*(math.cos(i*math.tau/n)*u+math.sin(i*math.tau/n)*v) for i in range(n)])
    faces=[]
    for j in range(len(points) if cyclic else len(points)-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,((j+1)%len(points))*n+(i+1)%n,((j+1)%len(points))*n+i))
    if not cyclic:faces.extend([tuple(reversed(range(n))),tuple(range((len(points)-1)*n,len(points)*n))])
    return f.mesh(name,verts,faces,mat)
def ring(name,at,r,t,mat,axis=(0,0,1),n=16):
    axis=Vector(axis).normalized();u=axis.cross(Vector((0,1,0)))
    if u.length<.01:u=axis.cross(Vector((1,0,0)))
    u.normalize();v=axis.cross(u)
    return tube(name,[Vector(at)+r*(math.cos(i*math.tau/n)*u+math.sin(i*math.tau/n)*v) for i in range(n)],t,mat,True)
def palette():
    colors={'shell':('34414A',.5,0),'dark':('131C24',.9,0),'rubber':('24272A',.85,0),'silver':('B9C1BE',.34,1),'white':('E7E3D2',.7,0),'red':('B63837',.55,0),'blue':('426B80',.45,0),'green':('7CADA0',.5,0),'orange':('E18B3F',.6,0),'wood':('A26C42',.7,0),'pink':('B95A6A',.7,0),'gold':('BC964B',.4,1)}
    return {k:material(k,*v) for k,v in colors.items()}
def handle(x,y,z,w,mat=None):
    mat=mat or M['shell'];tube('Open carrying handle',[(x-w/2,y,z),(x-w/2,y,z+.05),(x+w/2,y,z+.05),(x+w/2,y,z)],.012,mat)
def flat_ring(name,x,z,rx,rz,y,r,mat,n=20):
    return tube(name,[(x+rx*math.cos(i*math.tau/n),y,z+rz*math.sin(i*math.tau/n)) for i in range(n)],r,mat,True)
def recess(x,y,z,w,height):
    box('Recessed face gasket',(x,y,z),(w,.01,height),M['dark'],.005)
def led(x,y,z,mat):cyl('Status lamp',(x,y,z),.007,.003,mat,(0,-1,0),8)
def battery():
    box('Molded battery lower shell',(0,0,.17),(.23,.13,.32),M['shell'],.012)
    box('Battery split casing',(0,0,.325),(.23,.13,.015),M['dark'],.002)
    box('Battery shoulder cap',(0,0,.35),(.21,.12,.04),M['shell'],.008)
    for x in (-.055,-.018,.018,.055):box('Recessed brass terminal',(x,.043,.373),(.025,.025,.008),M['gold'],.001)
    for x in (-.109,.109):
        for z in (.06,.11,.16,.21):box('Side protective rib',(x,0,z),(.018,.137,.016),M['rubber'],.003)
    box('Rear V mount wedge',(0,.075,.21),(.13,.022,.14),M['dark'],.004)
    recess(0,-.07,.19,.17,.14)
    for i in range(4):led(-.045+i*.03,-.078,.30,M['green'])
def charger():
    box('Dual charger enclosure',(0,0,.065),(.34,.23,.13),M['shell'],.014)
    for x in (-.085,.085):
        box('Battery docking recess',(x,0,.137),(.125,.18,.018),M['dark'],.005)
        for xx in (-.057,.057):box('Dock guide rail',(x+xx,0,.16),(.012,.17,.04),M['shell'],.002)
        for xx in (-.025,.025):box('Charging contact',(x+xx,.065,.153),(.02,.018,.008),M['gold'],.001)
        led(x,-.119,.075,M['green'])
    for x in (-.13,.13):
        for y in (-.08,.08):box('Rubber charger foot',(x,y,.006),(.04,.04,.012),M['rubber'],.002)
    tube('Mains cable',[(.16,.07,.05),(.22,.11,.025),(.25,.03,.012),(.29,-.04,.012)],.008,M['rubber'])
    box('Mains plug',(.30,-.045,.016),(.035,.04,.028),M['dark'],.003)
def reel():
    cyl('Cable spool core',(0,0,.22),.135,.12,M['orange'],(0,1,0),24)
    for y in (-.075,.075):cyl('Reel side flange',(0,y,.22),.17,.016,M['shell'],(0,1,0),24)
    for y in (-.043,-.015,.015,.043):ring('Coiled cable turn',(0,y,.22),.137,.011,M['orange'],(0,1,0),24)
    for x in (-.079,.079):
        for z in (.15,.28):
            cyl('Socket rim',(x,-.088,z),.039,.012,M['white'],(0,1,0))
            for xx in (-.012,.012):box('Socket live neutral opening',(x+xx,-.096,z),(.007,.003,.017),M['dark'],0)
    for x in (-.19,.19):tube('Tubular steel reel stand',[(x,-.12,.012),(x,.11,.012),(x,.07,.28),(x,0,.43)],.012,M['silver'])
    bar('Cross handle',(-.19,0,.43),(.19,0,.43),.018,M['rubber'])
def paper(kind):
    if kind=='binder':
        for x in (-.16,.16):box('Binder hard cover',(x,0,.235),(.30,.018,.44),M['shell'],.006)
        box('Binder cloth spine',(0,.008,.235),(.035,.036,.44),M['dark'],.004)
        for x in (-.16,.16):box('Stack of script pages',(x,-.014,.235),(.27,.018,.41),M['white'],.002)
        for z in (.12,.235,.35):flat_ring('Open binder metal ring',0,z,.026,.014,-.035,.003,M['silver'],12)
    else:
        box('Rigid backing board',(0,0,.225),(.33,.023,.45),M['wood'] if kind=='clip' else M['shell'],.006)
        box('Layered paper edge',(0,-.018,.225),(.295,.012,.411),M['white'],.002)
        if kind=='clip':
            box('Steel sprung clip',(0,-.03,.425),(.17,.019,.052),M['silver'],.004)
            flat_ring('Clip finger lift',0,.454,.028,.016,-.04,.004,M['silver'],12)
        else:
            for x in (-.12,-.06,0,.06,.12):flat_ring('Pad binding ring',x,.444,.008,.016,-.02,.0028,M['silver'],8)
        if kind=='story':
            for z in (.14,.30):
                for x in (-.075,.075):
                    box('Storyboard frame',(x,-.025,z),(.132,.002,.118),M['shell'],0)
                    box('Storyboard blank panel',(x,-.027,z),(.118,.002,.102),M['white'],0)
                    bar('Thumbnail horizon',(x-.045,-.029,z-.02),(x+.045,-.029,z-.02),.002,M['blue'])
        elif kind=='cue':
            for z,w in [(.32,.23),(.28,.18),(.24,.22)]:box('Large cue line',(0,-.026,z),(w,.002,.008),M['shell'],0)
def chart(focus=False):
    box('Protective chart board',(0,0,.20),(.36,.022,.40),M['shell'],.005)
    box('Matte chart paper',(0,-.014,.20),(.33,.005,.37),M['white'],.001)
    if focus:
        verts=[];faces=[]
        for i in range(16):
            a=i*math.tau/16;b=a+math.pi/16;idx=len(verts)
            verts.extend([(0,-.018,.25),(.126*math.cos(a),-.018,.25+.126*math.sin(a)),(.126*math.cos(b),-.018,.25+.126*math.sin(b))]);faces.append((idx,idx+1,idx+2))
        f.mesh('Radial focus contrast wedges',verts,faces,M['dark'],False)
    else:
        cols=['82624F','C99D86','7192AC','64794C','A598C5','69A8A0','CB753D','6269A1','B65162','836294','B6C454','D9A147','416EA6','4D8F55','A83E3E','D4C550','B55999','4CABC0','E4E3DC','BCBCB3','979992','73766F','4B514D','262E2B']
        for i,c in enumerate(cols):box('Calibration color patch',(-.13+(i%6)*.052,-.018,.34-(i//6)*.071),(.044,.002,.061),material('Chart '+str(i),c,.8),0)
def reflector(flag=False):
    if flag:
        box('Stretched opaque flag fabric',(0,0,.36),(.43,.018,.43),M['dark'],.003)
        tube('Flag steel boundary',[(-.22,0,.14),(-.22,0,.58),(.22,0,.58),(.22,0,.14)],.006,M['silver'])
    else:
        # Broad mildly faceted reflector has a continuous rim and a real thin back.
        ob=cyl('Silver reflector membrane',(0,0,.36),.245,.012,M['white'],(0,1,0),24);ob.scale.z=.83
        flat_ring('Flexible black reflector rim',0,.36,.247,.205,0,.009,M['dark'],24)
    bar('Connected handgrip',(0,0,.015),(0,0,.17),.017,M['rubber'])
def clamp():
    for side in (-1,1):
        pts=[(side*.024,.16),(side*.105,.34),(side*.14,.36),(side*.14,.31),(side*.069,.15),(side*.13,.035),(side*.075,.02),(side*.005,.15)]
        h.extruded_profile('Crossed clamp lever',pts,0,.045,M['shell'],.004)
        box('Orange rotating jaw pad',(side*.113,0,.336),(.055,.067,.030),M['orange'],.004)
        ob=box('Rubber hand grip',(side*.075,-.002,.075),(.057,.053,.13),M['rubber'],.007);ob.rotation_euler.y=side*.45
    cyl('Central spring pivot',(0,0,.17),.037,.065,M['silver'],(0,1,0))
def arm():
    pts=[(-.17,0,.03),(-.06,0,.24),(.13,0,.36)]
    for a,b in zip(pts,pts[1:]):bar('Articulated aluminum segment',a,b,.022,M['silver'],8)
    for x,y,z in pts:
        cyl('Locking rosette',(x,y,z),.043,.055,M['shell'],(0,1,0));cyl('Tension knob',(x,-.038,z),.024,.026,M['rubber'],(0,1,0),12)
    for x,z in [(-.17,.015),(.13,.39)]:cyl('Mounting spigot',(x,0,z),.012,.04,M['silver'])
def mic():
    f.lathe('Tapered microphone handle',[(0,.0),(.026,0),(.030,.04),(.034,.29),(.031,.32),(0,.32)],M['shell'],16)
    cyl('Microphone ferrule',(0,0,.317),.044,.027,M['silver'])
    h.ellipsoid('Foam microphone windscreen',(0,0,.392),(.071,.071,.09),M['rubber'],16,8)
    box('Reporter mic flag cube',(0,0,.27),(.16,.12,.105),M['white'],.007)
    cyl('Recessed XLR socket',(0,0,.002),.017,.004,M['dark'])
def speaker():
    h.extruded_profile('Tapered speaker cabinet',[(-.15,.02),(.15,.02),(.15,.37),(.11,.42),(-.11,.42),(-.15,.37)],0,.20,M['shell'],.008)
    recess(0,-.107,.20,.255,.335)
    cyl('Woofer rubber surround',(0,-.117,.16),.10,.012,M['rubber'],(0,1,0),24)
    f.lathe('Speaker cone',[(0,0),(.025,.004),(.075,.024),(.092,.026)],M['shell'],24).rotation_euler.x=math.pi/2
    cone=h.PARTS[-1];cone.location=(0,-.122,.16)
    cyl('Tweeter',(0,-.12,.33),.036,.008,M['silver'],(0,1,0))
    handle(0,0,.42,.14)
    box('Rear amplifier panel',(0,.106,.22),(.21,.012,.25),M['dark'],.004)
    for x in (-.055,0,.055):cyl('Rear control knob',(x,.12,.28),.012,.02,M['silver'],(0,1,0),12)
def display():
    box('Timecode protective shell',(0,0,.13),(.48,.11,.25),M['shell'],.013)
    recess(0,-.06,.16,.44,.14)
    for i in range(8):
        x=-.184+i*.052
        for z in (.117,.16,.203):box('LED horizontal segment',(x,-.068,z),(.032,.003,.006),M['red'],0)
        for xx in (-.019,.019):
            for z in (.139,.181):box('LED vertical segment',(x+xx,-.068,z),(.005,.003,.028),M['red'],0)
    handle(0,0,.255,.18)
    for x in (-.16,.16):box('Rubber stand foot',(x,0,.006),(.07,.14,.012),M['rubber'],.003)
def case(makeup=True):
    color=M['pink'] if makeup else M['green']
    box('Rigid case lower shell',(0,0,.105),(.38,.23,.20),color,.012)
    box('Case closing seam',(0,0,.208),(.382,.232,.012),M['dark'],.002)
    box('Rigid fitted case lid',(0,0,.24),(.38,.23,.055),color,.009)
    for x in (-.13,.13):
        box('Case latch',(x,-.122,.22),(.035,.014,.05),M['silver'],.003)
        box('Rear lid hinge',(x,.122,.21),(.055,.015,.04),M['silver'],.002)
    handle(0,0,.27,.15)
    if makeup:
        for x in (-.191,.191):box('Aluminum case edge',(x,0,.13),(.012,.23,.21),M['silver'],.002)
    else:
        box('Medical cross vertical',(0,-.119,.13),(.035,.005,.105),M['white'],0)
        box('Medical cross horizontal',(0,-.12,.13),(.105,.005,.035),M['white'],0)
def brush():
    f.lathe('Tapered brush handle',[(0,0),(.022,0),(.031,.04),(.025,.26),(.034,.29),(0,.29)],M['shell'],16)
    cyl('Round metal brush ferrule',(0,0,.315),.043,.085,M['silver'])
    ob=f.lathe('Broad powder bristle tuft',[(0,.35),(.044,.35),(.073,.375),(.09,.41),(.079,.455),(.048,.49),(0,.50)],M['wood'],24);ob.scale.y=.70
def comb():
    box('Continuous comb spine',(0,0,.16),(.40,.025,.105),M['orange'],.006)
    for i in range(11):
        x=-.185+i*.037
        h.extruded_profile('Rounded broad comb tooth',[(x-.013,.12),(x+.013,.12),(x+.011,.025),(x,.015),(x-.011,.025)],0,.025,M['orange'],.003)
    box('Comb thumb grip',(-.15,0,.17),(.08,.038,.075),M['orange'],.008)
def hanger():
    tube('Continuous broad hanger shoulders',[(-.28,0,.08),(-.22,0,.17),(-.07,0,.28),(0,0,.30),(.07,0,.28),(.22,0,.17),(.28,0,.08)],.018,M['wood'])
    bar('Trouser hanging crossbar',(-.28,0,.08),(.28,0,.08),.016,M['wood'])
    tube('Open steel hanger hook',[(0,0,.30),(0,0,.39),(.035,0,.425),(.069,0,.40),(.068,0,.372)],.007,M['silver'])

BUILDERS=[battery,charger,reel,lambda:paper('binder'),lambda:paper('clip'),lambda:paper('story'),lambda:paper('cue'),chart,lambda:chart(True),reflector,lambda:reflector(True),clamp,arm,mic,speaker,display,case,brush,comb,hanger]

def bounds(objects):
    bpy.context.view_layer.update();p=[ob.matrix_world@v.co for ob in objects for v in ob.data.vertices]
    return Vector(tuple(min(q[i] for q in p) for i in range(3))),Vector(tuple(max(q[i] for q in p) for i in range(3)))
def old_bounds(original):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(h.ASSETS/(original+'.glb')))
    low,high=bounds([o for o in bpy.context.scene.objects if o.type=='MESH'])
    return low,high
def bake_fit(target):
    bpy.context.view_layer.update()
    for ob in h.PARTS:ob.data.transform(ob.matrix_world);ob.matrix_world.identity();ob.data.update()
    low,high=bounds(h.PARTS);tl,th=target
    scale=Vector(tuple((th[i]-tl[i])/(high[i]-low[i]) for i in range(3)))
    for ob in h.PARTS:
        for v in ob.data.vertices:v.co=Vector(tuple(tl[i]+(v.co[i]-low[i])*scale[i] for i in range(3)))
        ob.data.update()
    bpy.context.view_layer.update()
def clean():
    for ob in h.PARTS:
        bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free();ob.data.update()
def build_batch(source,items,builders,label):
    global M
    out=ROOT/'artifacts/props-refresh-all'/label;out.mkdir(parents=True,exist_ok=True)
    rows=[];replacements=[]
    for item,build in zip(items,builders):
        target=old_bounds(item['original_file'])
        bpy.ops.wm.read_factory_settings(use_empty=True);h.PARTS.clear();h.MARKERS.clear();M=palette();build();bake_fit(target);clean()
        row=h.export_asset(item['original_file']+'_rebuilt')
        # Joined material batches also get identity transforms: importer AABBs stay tight.
        for ob in [o for o in bpy.context.scene.objects if o.type=='MESH']:
            ob.data.transform(ob.matrix_world);ob.matrix_world.identity();ob.data.update()
        bpy.context.view_layer.update()
        bpy.ops.export_scene.gltf(filepath=str(h.ASSETS/(item['original_file']+'_rebuilt.glb')),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
        row.update(kind=item['kind'],original_file=item['original_file'],textures_embedded=False,finite_geometry=True,transforms_baked=True,export_y_up=True,front_godot='+Z',target_normalization_size=item['size_m'],old_bounds_min=list(target[0]),old_bounds_max=list(target[1]),bag=item.get('bag',True),disposal_ticket_anchor=False)
        assert row['triangles']<4500,(item,row['triangles'])
        rows.append(row);replacements.append(dict(kind=item['kind'],original_file=item['original_file'],file=item['original_file']+'_rebuilt'))
        bpy.ops.wm.save_as_mainfile(filepath=str(out/(item['original_file']+'.blend')))
        print('READY',item['original_file'],row['triangles'],flush=True)
    (source/'build_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (source/'replacements.json').write_text(json.dumps(replacements,indent=2),encoding='utf-8')
    print(label+'_BUILD_OK',len(rows),flush=True)
def main():
    items=json.loads((ROOT/'godot/docs/PROP_REBUILD_ASSIGNMENTS.json').read_text(encoding='utf-8'))['gear'][:20]
    build_batch(SOURCE,items,BUILDERS,'rebuild_gear_b')
if __name__=='__main__':main()
