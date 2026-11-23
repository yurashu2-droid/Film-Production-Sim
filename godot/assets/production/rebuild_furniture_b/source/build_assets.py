"""Low polygon interior furniture. Blender Z-up/front -Y; no external textures.
Run background Blender --factory-startup --python-exit-code 1 --python this_file.
"""
from pathlib import Path
import bpy, math, json, importlib.util, sys
from mathutils import Vector, Matrix
SOURCE=Path(__file__).resolve().parent
PRODUCTION=SOURCE.parents[1]
ROOT=SOURCE.parents[4]
spec=importlib.util.spec_from_file_location('fresh_helpers',PRODUCTION/'fresh_props/source/build_assets.py')
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)
h=f.h

def finish(o,mat,bevel=0,smooth=True):
    o.data.materials.append(mat)
    bpy.context.view_layer.objects.active=o
    if bevel:
        m=o.modifiers.new('One segment manufactured edge','BEVEL');m.width=bevel;m.segments=1
        bpy.ops.object.modifier_apply(modifier=m.name)
    for p in o.data.polygons:p.use_smooth=smooth
    if smooth:
        m=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');m.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=m.name)
    h.PARTS.append(o);return o
h.finish=finish
B=h.box; C=h.cylinder; M=h.material; E=h.ellipsoid
def T(name,pts,r,mat,closed=False,sides=6):
    # Explicit six-sided section, including joints, rather than curve bevel resolution.
    vs=[]
    for j,p in enumerate(pts):
        tangent=Vector(pts[(j+1)%len(pts)] if closed or j<len(pts)-1 else pts[j])-Vector(pts[j-1] if closed or j else pts[j])
        tangent.normalize(); ref=Vector((0,0,1))
        if abs(tangent.dot(ref))>.9:ref=Vector((0,1,0))
        a=tangent.cross(ref).normalized();b=tangent.cross(a).normalized()
        for i in range(sides):vs.append(Vector(p)+r*(a*math.cos(i*math.tau/sides)+b*math.sin(i*math.tau/sides)))
    faces=[]
    for j in range(len(pts) if closed else len(pts)-1):
        for i in range(sides):faces.append((j*sides+i,j*sides+(i+1)%sides,((j+1)%len(pts))*sides+(i+1)%sides,((j+1)%len(pts))*sides+i))
    if not closed:faces += [tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+i for i in range(sides))]
    return f.mesh(name,vs,faces,mat)
def L(name,profile,mat,n=24,at=(0,0,0),scale=(1,1,1)):
    o=f.lathe(name,profile,mat,n);o.location=at;o.scale=scale;return o
def beam(name,a,b,w,mat,depth=None):
    o=B(name,(Vector(a)+Vector(b))/2,(w,depth or w,(Vector(b)-Vector(a)).length),mat,.002)
    o.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler();return o
def profile(name,pts,y,d,mat):return h.extruded_profile(name,pts,y,d,mat,.003)
def palette():
    global wood,edge,dark,paint,steel,cream,red,brass,glass
    wood=M('Oiled warm oak','95653C',.56);edge=M('Oak end and edge','654329',.62)
    dark=M('Deep joint recess','23282B',.8);paint=M('Warm painted enamel','D1D8CF',.42)
    steel=M('Brushed steel','89999E',.34,1);cream=M('Warm ivory','E5DDC5',.52)
    red=M('Burgundy upholstery','813A36',.6);brass=M('Satin brass','B2964E',.35,1)
    glass=M('Reflective muted mirror','87A8AE',.18,.9)
def legs(w,d,z,mat= None):
    for x in (-w/2,w/2):
        for y in (-d/2,d/2):B('Structural foot',(x,y,z/2),(.055,.055,z),mat or edge,.004)
def pull(x,y,z,w=.12):
    T('Bent drawer pull',[(x-w/2,y+.012,z),(x-w/2,y-.018,z),(x+w/2,y-.018,z),(x+w/2,y+.012,z)],.008,steel)
def panel_frame(x,y,z,w,ht,mat= None):
    for xx in (x-w/2,x+w/2):B('Vertical face stile',(xx,y,z),(.035,.025,ht),mat or wood,.002)
    for zz in (z-ht/2,z+ht/2):B('Horizontal face rail',(x,y,zz),(w,.025,.035),mat or wood,.002)

def screen():
    for i,ang in enumerate((-.28,.28,-.28)):
        before=len(h.PARTS);cx=(i-1)*.46
        B('Opaque linen inset',(0,0,.76),(.425,.025,1.18),cream,.003)
        for x in (-.23,.23):B('Screen timber upright',(x,0,.69),(.035,.05,1.38),wood,.003)
        for z in (.16,1.37):B('Screen cross rail',(0,0,z),(.47,.05,.04),wood,.003)
        B('Inset lower rail',(0,-.02,.39),(.43,.025,.035),wood,.002)
        for o in h.PARTS[before:]:o.matrix_world=Matrix.Translation((cx,0,0))@Matrix.Rotation(ang,4,'Z')@o.matrix_world
    for x in (-.23,.23):
        for z in (.3,1.15):C('Hinge barrel',(x,-.015,z),.012,.08,brass,vertices=12)
def wardrobe():
    legs(.89,.39,.16)
    B('Cabinet carcass', (0,.015,.85),(.99,.47,1.42),wood,.006)
    B('Crown cap',(0,.015,1.59),(1.06,.53,.07),edge,.004)
    B('Plinth rail',(0,-.005,.17),(1.04,.51,.09),edge,.004)
    for x in (-.242,.242):
        B('Raised door panel',(x,-.239,.88),(.465,.025,1.30),edge,.003)
        panel_frame(x,-.26,.88,.412,1.23,wood)
        C('Brass knob',(x*.22,-.291,.86),.018,.023,brass,(0,-1,0),12)
def bookshelf():
    for x in (-.45,.45):B('Full height side',(x,0,.73),(.045,.35,1.46),wood,.003)
    B('Thin rear plywood',(0,.167,.73),(.9,.025,1.46),edge,.001)
    for z in (.04,.39,.74,1.09,1.44):B('Supported shelf',(0,0,z),(.9,.36,.035),wood,.002)
    colors=[M('Book cloth blue','465F73',.85),M('Book cloth ochre','AF894E',.85),red]
    for row in range(3):
        for j in range(3+row):
            x=-.34+j*.075
            B('Bound volume',(x,-.015,.08+row*.35+.12),(.06,.23,.24+(j%2)*.035),colors[(j+row)%3],.002)
def filing():
    legs(.49,.43,.06,steel)
    B('Folded steel cabinet shell',(0,0,.57),(.59,.51,1.05),paint,.006)
    for z in (.24,.57,.90):
        B('Drawer seam',(0,-.258,z),(.54,.015,.307),dark,.001)
        B('Inset drawer front',(0,-.269,z),(.515,.018,.286),paint,.004)
        pull(0,-.288,z+.025,.16)
        B('Label frame',(0,-.282,z+.09),(.14,.008,.045),steel,.001)
        B('Paper label',(0,-.288,z+.09),(.115,.002,.027),cream,0)
def reception():
    B('Counter face',(0,-.22,.55),(1.65,.055,1.0),wood,.004)
    for x in (-.80,.80):B('Counter side',(x,.025,.52),(.06,.52,.94),edge,.004)
    B('Reception top ledge',(0,-.18,1.05),(1.76,.26,.075),edge,.007)
    B('Working desktop',(0,.09,.76),(1.58,.47,.055),wood,.004)
    B('Plinth',(0,-.14,.06),(1.65,.39,.1),dark,.003)
    for x in (-.50,.50):B('Face recessed panel',(x,-.25,.55),(.40,.018,.68),edge,.003)
def vanity():
    legs(.84,.38,.66)
    B('Desktop',(0,0,.73),(.99,.50,.07),wood,.005)
    B('Drawer apron',(0,-.015,.63),(.87,.43,.16),edge,.004)
    for x in (-.22,.22):
        B('Drawer face',(x,-.239,.63),(.41,.023,.13),wood,.003);pull(x,-.26,.63,.12)
    B('Mirror backing',(0,.18,1.15),(.84,.05,.8),wood,.005)
    B('Mirror glass',(0,.148,1.15),(.65,.018,.64),glass,.005)
    for x in (-.37,.37):
        for z in (.88,1.14,1.40):
            C('Bulb socket',(x,.121,z),.032,.035,brass,(0,-1,0),12)
            E('Vanity frosted bulb',(x,.086,z),(.045,.044,.045),cream,12,6)
def sink():
    glaze=M('Glazed white porcelain','EFECE1',.2)
    L('Tapered ceramic pedestal',[(0,0),(.14,0),(.16,.035),(.13,.12),(.085,.38),(.10,.62),(.14,.70),(0,.70)],glaze)
    # Continuous bowl wall over the support, open at top, with a recessed inner floor.
    L('Hollow oval washbasin',[(0,.66),(.13,.66),(.21,.70),(.30,.81),(.31,.85),(.30,.875),(.27,.87),(.24,.81),(.17,.74),(.055,.73),(0,.73)],glaze,24,scale=(1,.79,1))
    B('Rear faucet deck',(0,.16,.839),(.47,.12,.055),glaze,.01)
    T('Gooseneck faucet',[(0,.16,.86),(0,.16,.98),(0,.12,1.01),(0,.03,1.01),(0,.0,.98)],.017,steel)
    for x in (-.105,.105):
        C('Tap body',(x,.16,.89),.022,.06,steel,vertices=12)
        B('Tap lever',(x,.16,.928),(.075,.018,.016),steel,.002)
    C('Drain',(0,0,.734),.028,.005,steel,vertices=16)
    C('Dark drain center',(0,0,.738),.013,.005,dark,vertices=12)
def stove():
    legs(.62,.49,.10,dark)
    B('Enamel oven cabinet',(0,0,.45),(.72,.58,.75),paint,.006)
    B('Oven gasket',(0,-.298,.39),(.61,.018,.47),dark,.004)
    B('Oven door surround',(0,-.315,.39),(.58,.025,.43),paint,.005)
    B('Oven dark glass',(0,-.332,.37),(.45,.012,.265),dark,.012)
    pull(0,-.351,.56,.40)
    B('Hob surface',(0,0,.84),(.75,.61,.05),cream,.005)
    B('Control fascia',(0,-.296,.745),(.70,.025,.12),edge,.003)
    for x in (-.24,-.08,.08,.24):C('Control dial',(x,-.325,.75),.025,.035,dark,(0,-1,0),12)
    for x in (-.19,.19):
        for y in (-.16,.16):
            L('Burner ring',[(.045,.868),(.075,.868),(.075,.882),(.045,.882),(.045,.868)],dark,16,at=(x,y,0))
            for a in (0,math.pi/2):
                o=B('Pan support',(x,y,.894),(.19,.012,.014),steel,.001);o.rotation_euler.z=a
def booth():
    for x in (-.64,.64):
        B('Bench toe plinth',(x,0,.13),(.42,.95,.26),dark,.005)
        B('Upholstered bench seat',(x,0,.40),(.48,1.0,.20),red,.028)
        B('Upholstered tall back',(x+(-.18 if x<0 else .18),0,.74),(.16,1.0,.65),red,.023)
        B('Back crown piping',(x+(-.18 if x<0 else .18),0,1.06),(.17,1.01,.025),cream,.005)
    B('Table top',(0,0,.65),(.72,.92,.065),cream,.008)
    C('Table pedestal',(0,0,.31),.048,.62,steel,vertices=16)
    B('Table pedestal foot',(0,0,.035),(.55,.6,.07),dark,.006)
def piano():
    B('Upright piano cabinet',(0,.12,.69),(1.29,.35,1.30),wood,.005)
    B('Top lid overhang',(0,.11,1.36),(1.39,.43,.065),edge,.004)
    B('Lower framed face',(0,-.071,.39),(1.15,.04,.54),edge,.004)
    B('Upper framed face',(0,-.075,1.06),(1.18,.04,.44),edge,.004)
    panel_frame(0,-.101,1.06,1.10,.36,wood)
    B('Keyboard bed',(0,-.26,.755),(1.28,.43,.075),edge,.004)
    # Thirty-six readable white keys and raised black-key groups, coarse at game distance.
    for i in range(36):
        x=-.568+i*.0325
        B('Ivory piano key',(x,-.28,.806),(.030,.29,.035),cream,.0006)
        if i%7 not in (2,6):B('Raised ebony key',(x+.015,-.19,.836),(.017,.15,.04),dark,.001)
    for x in (-.59,.59):
        B('Keyboard cheek',(x,-.23,.83),(.065,.40,.12),wood,.004)
        beam('Front support leg',(x,-.36,.04),(x,-.32,.73),.065,edge)
        B('Piano foot',(x,-.20,.04),(.12,.52,.08),edge,.005)
    for x in (-.10,0,.10):B('Brass pedal',(x,-.20,.12),(.045,.18,.022),brass,.007)
def hospital():
    blue=M('Hospital vinyl blue','618D9D',.68)
    B('Steel mattress frame',(0,0,.43),(.77,1.78,.10),steel,.005)
    B('Mattress',(0,-.01,.56),(.74,1.72,.19),cream,.028)
    B('Folded hospital blanket',(0,-.18,.667),(.76,1.13,.055),blue,.012)
    B('Supported pillow',(0,.57,.69),(.57,.34,.12),cream,.032)
    for x in (-.34,.34):
        for y in (-.78,.78):
            C('Bed steel leg',(x,y,.26),.023,.34,steel,vertices=12)
            C('Rubber caster',(x,y,.075),.075,.04,dark,(1,0,0),12)
    for y,ht in ((-.85,.86),(.85,1.04)):
        T('Rounded bed end', [(-.37,y,.20),(-.37,y,ht-.07),(-.31,y,ht),(.31,y,ht),(.37,y,ht-.07),(.37,y,.2)],.023,paint)
        for x in (-.18,0,.18):C('End support spindle',(x,y,(ht+.5)/2),.013,ht-.5,paint,vertices=12)
        C('End lower rail',(0,y,.5),.018,.73,paint,(1,0,0),12)
    for x in (-.40,.40):T('Raised side safety rail',[(x,-.5,.46),(x,-.5,.76),(x,.36,.76),(x,.36,.46)],.017,steel)
def lectern():
    B('Lectern base',(0,0,.045),(.66,.52,.09),edge,.005)
    o=profile('Tapered lectern pedestal',[(-.26,.09),(.26,.09),(.20,.92),(-.20,.92)],.035,.28,wood)
    for p in o.data.polygons:p.use_smooth=False
    o=B('Sloped reading surface',(0,-.02,1.0),(.74,.55,.055),edge,.004);o.rotation_euler.x=math.radians(-16)
    B('Book retaining lip',(0,-.28,1.095),(.70,.033,.045),wood,.002)
    B('Front inset face',(0,-.113,.52),(.30,.018,.58),edge,.003)
def pew():
    for x in (-.80,.80):
        profile('Solid shaped pew end',[(x-.055,0),(x+.055,0),(x+.055,.92),(x+.02,1.03),(x-.055,1.03)],0,.56,wood)
        B('Armrest',(x,-.04,.71),(.11,.64,.065),edge,.013)
    B('Pew seat',(0,-.03,.43),(1.60,.52,.07),wood,.004)
    o=B('Pew back',(0,.20,.73),(1.60,.055,.56),wood,.005);o.rotation_euler.x=math.radians(8)
    B('Rear hymn book rail',(0,.265,.67),(1.48,.075,.035),edge,.003)
    B('Seat front apron',(0,-.24,.35),(1.58,.04,.10),edge,.003)
def coatrack():
    L('Turned coat rack upright',[(0,.05),(.05,.05),(.045,.14),(.033,.3),(.033,1.1),(.05,1.14),(.05,1.22),(.035,1.25),(.035,1.48),(0,1.5)],wood)
    for i in range(4):
        a=i*math.tau/4;v=Vector((math.cos(a),math.sin(a),0))
        T('Splayed timber foot',[v*.03+Vector((0,0,.22)),v*.18+Vector((0,0,.08)),v*.32+Vector((0,0,.025))],.028,edge)
    for i in range(6):
        a=i*math.tau/6;v=Vector((math.cos(a),math.sin(a),0))
        T('Bent wood coat hook',[v*.025+Vector((0,0,1.15)),v*.16+Vector((0,0,1.29)),v*.22+Vector((0,0,1.46)),v*.20+Vector((0,0,1.51))],.018,wood)
        E('Rounded hook end',v*.20+Vector((0,0,1.51)),(.023,.023,.023),wood,12,6)

BUILDERS={'S034':screen,'S035':wardrobe,'S036':bookshelf,'S037':filing,'S038':reception,'S039':vanity,'S041':sink,'S043':stove,'S045':booth,'S046':piano,'S047':hospital,'S048':lectern,'S049':pew,'S050':coatrack}
def bounds(objects):
    bpy.context.view_layer.update()
    pts=[o.matrix_world@v.co for o in objects if o.type=='MESH' for v in o.data.vertices]
    return [min(p[i] for p in pts) for i in range(3)],[max(p[i] for p in pts) for i in range(3)]
def old_bounds(filename):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(h.ASSETS/(filename+'.glb')))
    return bounds(list(bpy.context.scene.objects))
def build_packet(builders,source,add_anchor=False):
    assignments=json.loads((ROOT/'godot/docs/PROP_REBUILD_ASSIGNMENTS.json').read_text(encoding='utf-8'))['furniture']
    rows=[];replacements=[]
    for item in assignments:
        prefix=item['original_file'].split('_')[0]
        if prefix not in builders:continue
        oldlo,oldhi=old_bounds(item['current_file'])
        bpy.ops.wm.read_factory_settings(use_empty=True);h.PARTS.clear();h.MARKERS.clear();palette()
        builders[prefix]()
        lo,hi=bounds(h.PARTS)
        scale=[(oldhi[i]-oldlo[i])/(hi[i]-lo[i]) for i in range(3)]
        # Bake ALL transforms before material joining. Exported boxes must use true vertex envelopes.
        for o in h.PARTS:
            mw=o.matrix_world.copy()
            for v in o.data.vertices:
                p=mw@v.co
                v.co=tuple((p[i]-lo[i])*scale[i]+oldlo[i] for i in range(3))
            o.matrix_world=Matrix.Identity(4)
        for o in h.MARKERS:
            p=o.location.copy();o.location=tuple((p[i]-lo[i])*scale[i]+oldlo[i] for i in range(3));o.rotation_euler=(0,0,0)
        bpy.context.view_layer.update()
        filename=item['original_file']+'_rebuilt';row=h.export_asset(filename)
        row.update(kind=item['kind'],original_file=item['original_file'],old_bounds_min=oldlo,old_bounds_max=oldhi,textures_embedded=False)
        assert row['triangles']<=4500,(filename,row['triangles'])
        assert all(abs(row['blender_bounds_min'][i]-oldlo[i])<.0001 and abs(row['blender_bounds_max'][i]-oldhi[i])<.0001 for i in range(3))
        rows.append(row);replacements.append({k:item[k] for k in ('kind','original_file')}|{'file':filename})
        print('BUILT',filename,row['triangles'],flush=True)
    (source/'build_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (source/'replacements.json').write_text(json.dumps(replacements,indent=2),encoding='utf-8')
    return rows
if __name__=='__main__':build_packet(BUILDERS,SOURCE)
