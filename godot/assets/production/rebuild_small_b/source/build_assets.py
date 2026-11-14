"""Photo-informed detective props, Blender Z-up/front -Y; static GLB export."""
from pathlib import Path
import importlib.util
import math
import json
import sys
import bpy
from mathutils import Vector

SOURCE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('small_b_helpers',SOURCE.parents[1]/'rebuild_small_a/source/build_assets.py')
a=importlib.util.module_from_spec(spec);spec.loader.exec_module(a)
f,h=a.f,a.h
box,cylinder,material=h.box,h.cylinder,h.material
mesh,slab,ribbon=a.mesh,a.slab,a.ribbon
TAU=math.tau


def alpha_material(name,color,roughness,alpha):
    mat=material(name,color,roughness)
    node=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    node.inputs['Alpha'].default_value=alpha
    mat.diffuse_color=(*mat.diffuse_color[:3],alpha)
    mat.surface_render_method='DITHERED'
    return mat


def text(name,body,at,size,mat):
    bpy.ops.object.text_add(location=at,rotation=(math.pi/2,0,0))
    obj=bpy.context.object;obj.name=name
    obj.data.body=body;obj.data.size=size;obj.data.align_x='CENTER';obj.data.align_y='CENTER'
    obj.data.extrude=.00012;obj.data.resolution_u=2
    obj.data.materials.append(mat)
    bpy.ops.object.convert(target='MESH');obj=bpy.context.object
    h.PARTS.append(obj)
    return obj


def circle_y(name,cx,y,cz,rx,rz,r,mat,n=48):
    return h.tube(name,[(cx+rx*math.cos(t),y,cz+rz*math.sin(t)) for t in [TAU*i/n for i in range(n)]],r,mat,True,6)


def lathe_y(name,profile,mat,z=0):
    obj=f.lathe(name,profile,mat,48);obj.rotation_euler.x=math.pi/2;obj.location.z=z
    return obj


def masquerade_mask():
    import bmesh
    purple=material('Mask lacquered plum papier-mache','5A285D',.38)
    gold=material('Mask raised gold borders','BCA16A',.33,.8)
    wood=material('Mask ebonized wooden handle','28242F',.58)
    liner=material('Mask dark fabric lining','30233C',.97)
    # Two shaped eye surrounds share the central bridge. Eye holes are real.
    n=64;verts=[];faces=[];outer_all=[];eyes=[]
    def surface(x,z):
        return -.010*(1-(x/.13)**2)-.024*math.exp(-(x/.022)**2)*max(0,min(1,(.295-z)/.055))
    for sign in (-1,1):
        outer=[];inner=[]
        for i in range(n):
            t=TAU*i/n
            x=sign*max(0,.052+.073*math.cos(t))
            z=.280+.045*math.sin(t)+.008*math.cos(t)
            outer.append((x,surface(x,z),z))
            x=sign*(.052+.033*math.cos(t))
            z=.279+.016*math.sin(t)*(.72+.28*abs(math.sin(t)))+.005*math.cos(t)
            inner.append((x,surface(x,z)-.0007,z))
        off=len(verts)
        for back in (False,True):
            verts += [(x,y+(.0035 if back else 0),z) for x,y,z in outer+inner]
        for i in range(n):
            j=(i+1)%n
            faces += [(off+i,off+j,off+n+j,off+n+i),
                      (off+2*n+i,off+3*n+i,off+3*n+j,off+2*n+j),
                      (off+n+i,off+n+j,off+3*n+j,off+3*n+i)]
            if abs(outer[i][0])+abs(outer[j][0])>.0001:
                faces.append((off+i,off+2*n+i,off+2*n+j,off+j))
        outer_all.append(outer);eyes.append(inner)
    obj=mesh('Continuous shaped mask with two eye openings',verts,faces,purple,True)
    bm=bmesh.new();bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    # Raised borders follow the curved shell; the nose bridge keeps a real profile.
    for inner in eyes:h.tube('Eye opening rolled gold edge',[(x,y-.001,z) for x,y,z in inner],.0017,gold,True,6)
    for outer in outer_all:
        pts=[(x,y-.0009,z) for x,y,z in outer if abs(x)>.00001]
        h.tube('Mask outer gold rim',pts,.0015,gold,sides=6)
    # Small upper-brow arcs are structural embossed ridges, not random filigree.
    for sign in (-1,1):
        pts=[]
        for i in range(21):
            x=sign*(.022+.078*i/20);z=.305+.009*math.sin(i*math.pi/20)
            pts.append((x,surface(x,z)-.001,z))
        h.tube('Upper brow raised sweep',pts,.0014,gold,sides=6)
    h.tube('Handle connected to cheek',[(.108,-.001,.259),(.111,-.001,.229),(.106,-.001,.207)],.0052,gold,sides=8)
    obj=f.lathe('Turned dark handle',[(0,0),(.007,0),(.008,.008),(.0065,.020),(.005,.17),(.007,.181),(.007,.198),(0,.198)],wood,32)
    obj.location=(.106,-.001,.009)
    for z in (.019,.192):cylinder('Handle gold ferrule',(.106,-.001,z),.0075,.008,gold,vertices=24)


def magnifying_glass():
    brass=material('Magnifier solid brass frame','BEA16B',.29,.9)
    dark=material('Magnifier rim groove','675331',.5,.7)
    wood=material('Magnifier turned walnut handle','5C3B2A',.55)
    glass=alpha_material('Magnifier lightly frosted glass','C9E5E8',.13,.20)
    edge=material('Magnifier polished glass edge','9EBAC0',.2,.1)
    center=.182
    lathe_y('Thick open brass lens barrel',[(.045,-.006),(.051,-.006),(.054,-.003),(.054,.004),(.050,.008),(.045,.008),(.045,-.006)],brass,center)
    for y in (-.008,.006):circle_y('Rolled lens retaining rim',0,y,center,.047,.047,.0015,brass)
    circle_y('Brass barrel closing groove',0,.001,center,.054,.054,.0007,dark)
    # Biconvex finite-volume lens. Alpha coverage is an explicit runtime shorthand.
    lathe_y('Biconvex magnifying lens',[(0,-.004),(.018,-.0035),(.035,-.002),(.046,0),(.046,.001),(.035,.004),(.018,.006),(0,.0065)],glass,center)
    circle_y('Lens visible cut edge',0,-.001,center,.0455,.0455,.0008,edge)
    cylinder('Frame handle socket',(0,0,.123),.010,.028,brass,vertices=32)
    obj=f.lathe('Continuous turned wood grip',[(0,.003),(.011,.003),(.013,.011),(.012,.023),(.010,.092),(.012,.108),(.009,.117),(0,.117)],wood,32)
    for z in (.014,.105):cylinder('Handle brass collar',(0,0,z),.012,.007,brass,vertices=24)


def detective_notebook():
    leather=material('Notebook dark leather cover','39372F',.72)
    cut=material('Notebook brown cut leather edge','75634B',.87)
    paper=material('Notebook ivory page signatures','E8DEC1',.94)
    elastic=material('Notebook black woven elastic','211F20',.97)
    gold=material('Notebook restrained gold stamped title','C4A577',.63,.25)
    red=material('Notebook burgundy ribbon bookmark','913E4E',.65)
    # Separate rounded boards enclose a real depth of grouped page signatures.
    for y in (-.012,.012):
        obj=h.extruded_profile('Leather covered board',f.rounded_profile(.096,.148,.006),y,.003,leather,.001)
        h.extruded_profile('Board cut edge',f.rounded_profile(.094,.146,.005,.001),y+(.0016 if y>0 else -.0016),.0006,cut,.0002)
    for i in range(10):
        h.extruded_profile('Rounded paper signature',[(x+.003,z+.006) for x,z in f.rounded_profile(.084,.136,.003)],-.0088+i*.00195,.00175,paper,.0002)
    # Convex binding wraps around the left edge of both covers.
    h.tube('Rounded leather binding spine',[(-.046,0,z) for z in (.005,.025,.123,.143)],.0123,leather,sides=10)
    # A broad elastic physically crosses front/back and turns over the page edges.
    ribbon('Continuous elastic closure',[(.032,-.015,.003),(.032,-.015,.145),(.032,-.011,.151),(.032,.011,.151),(.032,.015,.145),(.032,.015,.003),(.032,.009,-.002),(.032,-.009,-.002),(.032,-.015,.003)],.005,elastic,(1,0,0),.0008)
    ribbon('Bookmark emerging below pages',[(0,.003,.055),(0,.003,.007),(.004,.003,-.013)],.006,red,(1,0,0),.0006)
    text('Large notebook title','CASE',(-.005,-.015,.106),.010,gold)
    text('Notebook title second line','NOTES',(-.005,-.015,.092),.007,gold)


def pocket_watch():
    gold=material('Watch polished yellow brass','BFA061',.25,.9)
    edge=material('Watch dark brass casing groove','806536',.4,.8)
    enamel=material('Watch warm enamel dial','EEE6CF',.38)
    ink=material('Watch charcoal hands and numerals','282925',.5)
    glass=alpha_material('Watch thin front glass','CFDFDC',.10,.075)
    z=.061
    lathe_y('Rounded watch case',[(0,-.010),(.041,-.010),(.051,-.007),(.055,-.002),(.055,.004),(.051,.010),(.046,.012),(0,.012)],gold,z)
    cylinder('Inset enamel clock dial',(0,-.013,z),.047,.002,enamel,(0,1,0),64)
    circle_y('Raised watch bezel',0,-.015,z,.049,.049,.0025,gold,64)
    circle_y('Watch case side seam',0,.004,z,.0547,.0547,.0007,edge,64)
    # Twelve readable hour marks, quarter numerals, minute ticks and hands.
    for i in range(60):
        t=TAU*i/60
        r0=.0405 if i%5 else .038
        r1=.0435
        h.tube('Hour marker' if i%5==0 else 'Minute tick',[(r0*math.sin(t),-.015,z+r0*math.cos(t)),(r1*math.sin(t),-.015,z+r1*math.cos(t))],.00055 if i%5==0 else .00024,ink,sides=4)
    for body,x,dz in [('12',0,.030),('3',.031,0),('6',0,-.029),('9',-.031,0)]:text('Quarter hour numeral',body,(x,-.0154,z+dz),.009,ink)
    def hand(name,angle,length,width,y):
        t=math.radians(angle);u=Vector((math.sin(t),math.cos(t)));v=Vector((math.cos(t),-math.sin(t)))
        points=[-u*.008-v*width*.35,-u*.008+v*width*.35,u*length*.68+v*width*.5,u*length,u*length*.68-v*width*.5]
        h.extruded_profile(name,[(p.x,z+p.y) for p in points],y,.0010,ink,.0003)
    hand('Hour spear hand',-55,.027,.004,-.017)
    hand('Minute spear hand',56,.036,.0025,-.0185)
    cylinder('Central watch hand pin',(0,-.020,z),.0028,.002,gold,(0,1,0),20)
    # Subsidiary seconds are visibly part of the dial, never floating above it.
    circle_y('Small seconds dial',0,-.0154,z-.019,.0095,.0095,.00045,edge,32)
    h.tube('Small seconds hand',[(0,-.0164,z-.019),(.004,-.0164,z-.025)],.00045,ink,sides=4)
    lathe_y('Slightly domed watch crystal',[(0,.0205),(.028,.0198),(.046,.0172),(.046,.0163),(0,.0195)],glass,z)
    cylinder('Winding stem',(0,0,.121),.0045,.015,gold,vertices=20)
    cylinder('Fluted winding crown',(0,0,.129),.008,.010,gold,vertices=32)
    for i in range(12):
        t=TAU*i/12
        h.tube('Crown grip ridge',[(.008*math.cos(t),.008*math.sin(t),.125),(.008*math.cos(t),.008*math.sin(t),.133)],.0006,edge,sides=4)
    circle_y('Open chain bow',0,0,.144,.013,.012,.0025,gold,40)


def skeleton_key():
    brass=material('Key aged solid brass','A88A50',.42,.9)
    dark=material('Key recessed ward edge','6E5836',.55,.85)
    # Thick oval open bow is joined to a turned barrel by a cast neck.
    circle_y('Continuous open key bow',0,0,.191,.030,.026,.006,brass,56)
    cylinder('Bow-to-shaft neck',(0,0,.158),.011,.028,brass,vertices=28)
    f.lathe('Turned key barrel',[(.0035,.005),(.008,.005),(.008,.020),(.0065,.025),(.0065,.135),(.010,.139),(.010,.148),(.007,.153),(.0035,.153),(.0035,.005)],brass,32)
    for z in (.028,.129):cylinder('Key barrel collar',(0,0,z),.009,.006,brass,vertices=28)
    outline=[(.004,.013),(.042,.013),(.042,.024),(.031,.024),(.031,.032),(.042,.032),(.042,.046),(.023,.046),(.023,.039),(.015,.039),(.015,.049),(.004,.049)]
    h.extruded_profile('Solid cut key bit with working wards',outline,0,.011,brass,.0012)
    # A clear stepped recess across the bit is construction, not random engraving.
    h.tube('Ward inset edge',[(.027,-.0057,.016),(.027,-.0057,.027),(.018,-.0057,.027),(.018,-.0057,.035)],.0007,dark,sides=4)


def evidence_bag():
    plastic=alpha_material('Evidence pouch frosted clear polyethylene','D3E4DE',.33,.15)
    seam=alpha_material('Evidence pouch heat-welded seam','ADC6BE',.46,.60)
    red=material('Evidence tamper seal burgundy','9D3441',.63)
    white=material('Evidence white documentation label','EDE8DA',.92)
    ink=material('Evidence charcoal print','354047',.90)
    blue=material('Blue nitrile glove','478FBC',.63)
    blue2=material('Second blue nitrile glove','6CAAC4',.67)
    cuff=material('Nitrile cuff rolled edge','346E94',.72)
    # Integrated glove silhouettes retain five fingers, thumb, palm and wrist.
    outline=[(-.019,0),(.017,0),(.024,.045),(.032,.056),(.033,.083),(.029,.089),(.025,.085),(.023,.064),(.021,.105),(.017,.111),(.012,.108),(.011,.068),(.007,.122),(.002,.126),(-.003,.122),(-.003,.070),(-.009,.113),(-.015,.116),(-.019,.111),(-.016,.063),(-.032,.085),(-.040,.082),(-.041,.074),(-.024,.045),(-.024,.015)]
    for i in range(2):
        obj=h.extruded_profile('Continuous empty nitrile glove',[(x*.75,z*.75) for x,z in outline],0,.005,blue if i==0 else blue2,.002)
        angle=math.radians(-12 if i==0 else 18)
        obj.rotation_euler.y=angle;obj.location=(-.027 if i==0 else .027,.001 if i==0 else .006,.061 if i==0 else .068)
        # The rolled wrist cuffs are shallow ellipses, matching the thin empty glove.
        pts=[(x*.75,0,z*.75) for x,z in [(-.019,.006),(-.009,.003),(.009,.003),(.018,.006),(.009,.009),(-.009,.009)]]
        c=h.tube('Rolled glove wrist cuff',pts,.0015,cuff,True,6)
        c.rotation_euler.y=angle;c.location=obj.location
    # A softly inflated closed pouch uses broad quiet planes, not random creases.
    verts=[]
    cols,rows=12,16
    for side in (-1,1):
        for j in range(rows+1):
            z=.012+j*.198/rows
            for i in range(cols+1):
                x=-.076+i*.152/cols
                bulge=.006+.010*math.sin(i*math.pi/cols)*math.sin(j*math.pi/rows)
                verts.append((x,side*bulge,z))
    n=(cols+1)*(rows+1);faces=[]
    for side in (0,1):
        off=side*n
        for j in range(rows):
            for i in range(cols):
                q=(off+j*(cols+1)+i,off+j*(cols+1)+i+1,off+(j+1)*(cols+1)+i+1,off+(j+1)*(cols+1)+i)
                faces.append(q if side==0 else tuple(reversed(q)))
    border=list(range(cols+1))+[j*(cols+1)+cols for j in range(1,rows+1)]+list(range(n-2,n-cols-2,-1))+[j*(cols+1) for j in range(rows-1,0,-1)]
    faces += [(border[j],border[(j+1)%len(border)],border[(j+1)%len(border)]+n,border[j]+n) for j in range(len(border))]
    mesh('Thin sealed polyethylene pouch',verts,faces,plastic,True)
    for x in (-.074,.074):box('Visible welded bag side seam',(x,0,.111),(.003,.013,.198),seam,.0004)
    box('Welded bag bottom',(0,0,.014),(.148,.013,.003),seam,.0004)
    box('Wide tamper-evident closure',(0,0,.211),(.154,.014,.018),red,.0008)
    text('Evidence bag header','EVIDENCE',(0,-.008,.212),.011,white)
    box('Evidence documentation label',(0,-.0148,.042),(.112,.001,.035),white,.001)
    text('Evidence label field','ITEM 017',(0,-.0156,.051),.0055,ink)
    for z in (.035,.041):box('Printed evidence form rule',(0,-.0157,z),(.093,.0004,.0006),ink,.0001)


def flashlight():
    paint=material('Flashlight charcoal enamel barrel','3C474C',.42)
    steel=material('Flashlight nickel plated reflector','B8C5C5',.19,.95)
    rim=material('Flashlight satin steel hardware','8B9A9C',.32,.9)
    rubber=material('Flashlight vulcanized rubber grip','273237',.85)
    dark=material('Flashlight switch slot','192227',.88)
    bulb=material('Flashlight warm bulb glass','E6DCC0',.21)
    lens=alpha_material('Flashlight clear protective lens','D4E5E3',.12,.10)
    f.lathe('Continuous flashlight casing',[(0,.008),(.021,.008),(.024,.015),(.024,.174),(.026,.184),(.038,.198),(.049,.224),(.051,.238),(.046,.243),(.040,.235),(.025,.202),(.021,.187),(0,.187)],paint,48)
    f.lathe('Screw-on battery end cap',[(0,0),(.021,0),(.025,.006),(.025,.017),(.023,.021),(0,.021)],rim,40)
    # Six broad molded rings show an intentional gripping span.
    for z in (.045,.057,.069,.081,.093,.105):
        f.lathe('Broad grip rib',[(.023,z-.003),(.026,z-.002),(.027,z),(.026,z+.002),(.023,z+.003),(.023,z-.003)],rubber,40)
    # Concave reflector remains visible through its protective lens.
    f.lathe('Recessed parabolic metal reflector',[(.006,.204),(.015,.208),(.026,.218),(.037,.231),(.046,.241),(.046,.243),(.038,.234),(.026,.221),(.014,.211),(.006,.207),(.006,.204)],steel,56)
    f.lathe('Rolled head bezel',[(.045,.238),(.051,.238),(.053,.242),(.052,.247),(.046,.247),(.045,.244),(.045,.238)],rim,56)
    cylinder('Bulb threaded base',(0,0,.208),.007,.012,rim,vertices=24)
    h.ellipsoid('Central flashlight bulb',(0,0,.220),(.008,.008,.014),bulb,24,12)
    f.lathe('Protective lens disk',[(0,.246),(.045,.246),(.045,.248),(0,.248)],lens,56)
    box('Switch steel mounting channel',(0,-.0255,.148),(.022,.006,.040),rim,.003)
    box('Recessed slide switch track',(0,-.029,.148),(.011,.002,.029),dark,.002)
    box('Large thumb slide switch',(0,-.032,.156),(.014,.006,.014),paint,.002)
    for z in (.154,.158):box('Switch thumb ridge',(0,-.0354,z),(.009,.0008,.001),rim,.0002)
    # Rear hanging loop is attached into the battery cap.
    circle_y('Battery cap hanging loop',0,.024,.010,.009,.006,.0018,rim,28)


def detective_badge():
    leather=material('Badge dark leather holder','332C28',.76)
    cut=material('Badge holder cut edge','765D46',.88)
    gold=material('Detective badge brass relief','BD9E61',.3,.85)
    recess=material('Badge recessed brass','7B6339',.48,.8)
    enamel=material('Badge center midnight enamel','274E66',.32)
    ink=material('Badge dark stamped letters','3C3629',.74)
    stitch=material('Holder sewn edge thread','A68761',.88)
    outline=[(0,0),(-.029,.012),(-.044,.033),(-.047,.068),(-.042,.101),(0,.109),(.042,.101),(.047,.068),(.044,.033),(.029,.012)]
    h.extruded_profile('Thick leather badge holder',outline,0,.006,leather,.0015)
    h.tube('Cut leather holder perimeter',[(x,0,z) for x,z in outline],.0015,cut,True,6)
    face=[(x*.86,.007+z*.84) for x,z in outline]
    h.extruded_profile('Cast shield badge with real thickness',face,-.0055,.005,gold,.0012)
    h.tube('Raised shield perimeter',[(x,-.009,z) for x,z in face],.0013,gold,True,6)
    # Stitch marks follow the owning leather perimeter, kept outside the shield.
    for k in range(len(outline)):
        p=Vector(outline[k]);q=Vector(outline[(k+1)%len(outline)])
        for j in range(4):
            v=p.lerp(q,(j+.3)/4)*.955;u=p.lerp(q,(j+.7)/4)*.955
            h.tube('Holder edge stitch',[(v.x,-.0035,v.y+.002),(u.x,-.0035,u.y+.002)],.00035,stitch,sides=4)
    cylinder('Inset badge enamel seal',(0,-.009,.057),.019,.002,enamel,(0,1,0),40)
    circle_y('Brass medallion rim',0,-.011,.057,.0195,.0195,.0012,gold,40)
    star=[]
    for i in range(10):
        t=math.pi/2+i*math.pi/5;r=.011 if i%2==0 else .0049
        star.append((r*math.cos(t),.057+r*math.sin(t)))
    h.extruded_profile('Raised five-point badge star',star,-.0117,.0018,gold,.0003)
    banner=[(-.033,.081),(-.029,.092),(0,.096),(.029,.092),(.033,.081),(0,.085)]
    h.extruded_profile('Raised detective title banner',banner,-.009,.002,gold,.0005)
    text('Detective title','DETECTIVE',(0,-.0107,.088),.0053,ink)
    box('Badge number cartouche',(0,-.009,.025),(.034,.002,.012),recess,.002)
    text('Badge number','071',(0,-.0105,.025),.007,gold)
    # Actual rear belt clip has a supported folded return and air gap.
    ribbon('Rear spring belt clip',[(-.012,.004,.089),(-.012,.011,.089),(-.012,.014,.084),(-.012,.014,.047),(-.012,.011,.042)],.020,gold,(1,0,0),.001)


ASSETS=[('scrap_masquerade_mask','P010_masquerade_mask',masquerade_mask),
        ('scrap_magnifying_glass','P011_magnifying_glass',magnifying_glass),
        ('scrap_detective_notebook','P012_detective_notebook',detective_notebook),
        ('scrap_pocket_watch','P013_pocket_watch',pocket_watch),
        ('scrap_skeleton_key','P014_skeleton_key',skeleton_key),
        ('scrap_evidence_bag','P015_evidence_bag',evidence_bag),
        ('scrap_flashlight','P016_flashlight',flashlight),
        ('scrap_detective_badge','P017_detective_badge',detective_badge)]


def main():
    out=h.PROJECT.parent/'artifacts/rebuild-small-b';out.mkdir(parents=True,exist_ok=True)
    rows=[]
    for kind,original,build in ASSETS:
        bpy.ops.wm.read_factory_settings(use_empty=True);h.PARTS.clear();h.MARKERS.clear()
        build()
        row=h.export_asset(original+'_rebuilt')
        row.update(kind=kind,original_file=original,textures_embedded=False,finite_geometry=True)
        rows.append(row)
        bpy.ops.wm.save_as_mainfile(filepath=str(out/(original+'.blend')))
        if '--preview' in sys.argv or '--preview='+original in sys.argv:a.preview(original+'_rebuilt',row,out)
    (SOURCE/'build_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (SOURCE/'replacements.json').write_text(json.dumps([dict(kind=k,original_file=o,file=o+'_rebuilt') for k,o,b in ASSETS],indent=2),encoding='utf-8')
    print('SMALL_B_BUILD_OK '+json.dumps(rows))


if __name__=='__main__':main()
