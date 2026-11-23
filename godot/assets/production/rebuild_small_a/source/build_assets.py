"""Eight photo-informed small production props, built in disposable Blender CLI.

Z-up, presentation front -Y. Shared exporter batches by material for Godot.
Reference sources and scoped construction decisions are in README.md.
"""
from pathlib import Path
import importlib.util
import json
import math
import sys
import bpy
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('small_a_fresh_helpers', SOURCE.parents[1] / 'fresh_props/source/build_assets.py')
f = importlib.util.module_from_spec(spec)
spec.loader.exec_module(f)
h = f.h
box, cylinder, material = h.box, h.cylinder, h.material
TAU = math.tau


def mesh(name, verts, faces, mat, smooth=False):
    return f.mesh(name, verts, faces, mat, smooth)


def slab(name, outline, z, thickness, mat, bevel=0):
    """Closed extruded XY outline with correct caps, also for concave hearts."""
    n = len(outline)
    verts = [(x,y,z) for x,y in outline] + [(x,y,z+thickness) for x,y in outline]
    faces = [tuple(reversed(range(n))), tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    obj = mesh(name, verts, faces, mat)
    if bevel:
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Small manufactured edge radius','BEVEL')
        mod.width,mod.segments=bevel,2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def wall(name, outline, inset, z0, z1, mat):
    """Continuous hollow outline wall with a top rim and inner wall."""
    n=len(outline)
    cx=sum(x for x,y in outline)/n;cy=sum(y for x,y in outline)/n
    rings=[[(x,y,z0) for x,y in outline],[(x,y,z1) for x,y in outline],
           [(cx+(x-cx)*inset,cy+(y-cy)*inset,z1) for x,y in outline],
           [(cx+(x-cx)*inset,cy+(y-cy)*inset,z0) for x,y in outline]]
    verts=sum(rings,[])
    faces=[]
    for j in range(4):
        k=(j+1)%4
        faces += [(j*n+i,j*n+(i+1)%n,k*n+(i+1)%n,k*n+i) for i in range(n)]
    return mesh(name,verts,faces,mat,True)


def roundrect(w,d,r,steps=6):
    pts=[]
    for x,y,start in [(w/2-r,d/2-r,0),(-w/2+r,d/2-r,math.pi/2),
                      (-w/2+r,-d/2+r,math.pi),(w/2-r,-d/2+r,math.pi*1.5)]:
        for i in range(steps+1):
            a=start+i*math.pi/2/steps
            pts.append((x+r*math.cos(a),y+r*math.sin(a)))
    return pts


def heart(width=.24):
    return [(width/32*16*math.sin(a)**3, width/32*(13*math.cos(a)-5*math.cos(2*a)-2*math.cos(3*a)-math.cos(4*a)))
            for a in [TAU*i/80 for i in range(80)]]


def ribbon(name, points, width, mat, across=(0,1,0), thickness=.0012):
    """A real broad strip with finite thickness, not a tube used as a bow."""
    u=Vector(across).normalized()*width/2
    verts=[]
    for i,p in enumerate(points):
        tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        normal=tangent.cross(u).normalized()*thickness/2
        c=Vector(p)
        verts += [c-u-normal,c+u-normal,c+u+normal,c-u+normal]
    faces=[]
    for i in range(len(points)-1):
        for j in range(4):
            faces.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
    faces += [(3,2,1,0),tuple(range((len(points)-1)*4,len(points)*4))]
    return mesh(name,verts,faces,mat,True)


def ring_box():
    velvet=material('Claret velvet shell','72203B',.89)
    lining=material('Rose velvet lining','B66F7D',.98)
    dark=material('Cushion slot shadow','2B1020',1)
    gold=material('Ring yellow gold','D7B36B',.23,.85)
    stone=material('Diamond graphic cool crystal','D6EBEE',.10,.34)
    outline=roundrect(.112,.10,.023)
    slab('Rounded covered base',outline,0,.012,velvet,.002)
    wall('Open velvet case walls',outline,.87,.009,.043,velvet)
    # Two cushion rolls lie front and back with a left-right slot, so the ring faces the open front.
    for y in (-.024,.024):
        h.ellipsoid('Plush ring cushion',(0,y,.034),(.039,.024,.018),lining,24,12)
    box('Ring insertion slot',(0,0,.039),(.062,.004,.003),dark,.001)
    # The band goes into the actual cushion slot, and supports the prong basket.
    h.tube('Continuous gold ring band',[(.023*math.cos(i*TAU/48),0,.052+.023*math.sin(i*TAU/48)) for i in range(48)],.0027,gold,True,8)
    cylinder('Gem basket seat',(0,0,.076),.009,.004,gold,vertices=16)
    for a in [TAU*i/4+math.pi/4 for i in range(4)]:
        h.tube('Gem setting prong',[(.006*math.cos(a),.006*math.sin(a),.076),
               (.009*math.cos(a),.009*math.sin(a),.082),(.009*math.cos(a),.009*math.sin(a),.087)],.0013,gold,sides=6)
    verts=[(0,0,.077)]
    for r,z in [(.011,.084),(.0065,.090)]:
        verts += [(r*math.cos(i*TAU/8),r*math.sin(i*TAU/8),z) for i in range(8)]
    faces=[(0,1+(i+1)%8,1+i) for i in range(8)]
    faces += [(1+i,1+(i+1)%8,9+(i+1)%8,9+i) for i in range(8)]
    faces += [tuple(range(9,17))]
    mesh('Eight-sided cut solitaire',verts,faces,stone)
    # Lid is authored flat then rotated around the back hinge as one assembly.
    start=len(h.PARTS)
    slab('Rounded velvet lid',outline,.0,.016,velvet,.002)
    slab('Inset padded lid lining',roundrect(.094,.082,.017),.016,.007,lining,.002)
    for obj in h.PARTS[start:]:
        # 100 degrees from shut; local bottom face now faces presentation camera.
        for v in obj.data.vertices:
            q=v.co-Vector((0,.05,0))
            a=math.radians(-100)
            v.co=Vector((q.x,math.cos(a)*q.y-math.sin(a)*q.z,math.sin(a)*q.y+math.cos(a)*q.z))+Vector((0,.046,.043))
    cylinder('Visible brass hinge',(0,.045,.044),.0035,.055,gold,(1,0,0),16)


def chocolates():
    red=material('Heart box red paper','A91936',.58)
    rim=material('Heart box gilt edge','D7B76D',.4,.35)
    tray=material('Molded gold candy tray','A88750',.50,.15)
    cup=material('Pleated cocoa paper cups','432B23',.94)
    dark=material('Dark chocolate','42231D',.37)
    milk=material('Milk chocolate','794936',.40)
    white=material('White chocolate','E9D3A6',.44)
    pts=heart(.235)
    slab('Heart-shaped box bottom',pts,0,.006,red,.001)
    wall('Continuous heart box wall',pts,.952,.005,.034,red)
    wall('Thin gilt rim',pts,.967,.032,.035,rim)
    slab('Heart tray insert',[(x*.92,y*.92) for x,y in pts],.007,.007,tray)
    positions=[(-.067,.042),(-.023,.050),(.023,.05),(.067,.042),(-.067,-.002),(-.022,.005),(.022,.005),(.067,-.002),(-.035,-.043),(.010,-.043),(0,-.081)]
    for i,(x,y) in enumerate(positions):
        n=32
        outline=[(x+(.019+(i0%2)*.001)*math.cos(i0*TAU/n),y+(.019+(i0%2)*.001)*math.sin(i0*TAU/n)) for i0 in range(n)]
        wall('Fluted candy paper',outline,.88,.014,.025,cup)
        mat=[dark,milk,white][i%3]
        if i%3==0:
            candy=slab('Heart bonbon',[(x+hx,y+hy) for hx,hy in heart(.030)],.020,.013,mat,.002)
        elif i%3==1:
            h.ellipsoid('Domed truffle',(x,y,.026),(.016,.016,.012),mat,20,10)
        else:
            box('Square praline',(x,y,.027),(.028,.027,.017),mat,.004)
        if i in (1,4,7):
            for j in (-1,0,1):
                h.tube('Single readable chocolate drizzle',[(x-.010,y+j*.006,.035),(x,y+j*.006+.002,.039),(x+.010,y+j*.006,.035)],.0012,white,sides=4)
    # Offset lid behind the open tray, with a real lip and a quiet recessed heart.
    lidpts=[(x+.225,y+.075) for x,y in pts]
    slab('Matching heart lid',lidpts,0,.011,red,.001)
    wall('Gilt lid perimeter',lidpts,.974,.009,.012,rim)
    slab('Lid heart medallion',[(x*.36+.225,y*.36+.075) for x,y in pts],.011,.001,rim)


def perfume():
    glass=material('Frosted rose glass graphic opaque','B77F8D',.24)
    edge=material('Thick pale glass edge','E5C8CC',.18)
    brass=material('Perfume brushed gold','C5A566',.27,.75)
    label=material('Perfume ivory paper label','F2E5C8',.8)
    ink=material('Perfume charcoal lettering','4C3540',.8)
    # Rounded rectangular section is lofted into curved shoulders and a narrow neck.
    rings=[(.074,.044,.010,.0),(.080,.050,.012,.007),(.080,.050,.012,.083),
           (.078,.049,.012,.094),(.067,.043,.013,.105),(.040,.031,.012,.113),(.022,.022,.008,.117)]
    verts=[]
    for w,d,r,z in rings:
        verts += [(x,y,z) for x,y in roundrect(w,d,r)]
    n=len(roundrect(.08,.05,.012))
    faces=[tuple(reversed(range(n)))]
    for j in range(len(rings)-1):
        faces += [(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for i in range(n)]
    faces.append(tuple(range((len(rings)-1)*n,len(rings)*n)))
    mesh('Continuous bottle with curved shoulder',verts,faces,glass,True)
    slab('Substantial glass foot',roundrect(.078,.048,.011),0,.009,edge,.001)
    cylinder('Crimp neck collar',(0,0,.117),.013,.008,brass,vertices=32)
    box('Heavy rounded gold cap',(0,0,.134),(.042,.033,.028),brass,.006)
    box('Front paper label',(0,-.0256,.057),(.048,.0012,.042),label,.002)
    # Large quiet label marks survive game scale without copied branding.
    for z,w in [(.067,.026),(.062,.020),(.042,.017)]:
        box('Label typographic rule',(0,-.0264,z),(w,.0005,.0012),ink,.0002)
    h.ellipsoid('Perfume emblem',(0,-.0265,.051),(.0045,.0005,.0045),brass,16,8)


def hand_mirror():
    brass=material('Hand mirror warm brass','B69456',.32,.82)
    inset=material('Hand mirror recessed bronze','705334',.5,.65)
    silver=material('Hand mirror silver face','B6D1D9',.15,.85)
    back=material('Hand mirror enamel reverse','436E68',.35,.1)
    # Oval frame consists of a thick continuous outer wall and rolled rim.
    outer=[(.073*math.cos(a),.179+.086*math.sin(a)) for a in [i*TAU/64 for i in range(64)]]
    body=h.extruded_profile('Solid oval mirror backing',outer,0,.012,brass,.002)
    inner=[(.061*math.cos(a),.179+.074*math.sin(a)) for a in [i*TAU/64 for i in range(64)]]
    h.extruded_profile('Inset reflective glass',inner,-.007,.002,silver,.001)
    h.extruded_profile('Inset green enamel back',inner,.007,.002,back,.001)
    for y in (-.009,.0085):
        h.tube('Continuous rolled oval frame',[(.067*math.cos(a),y,.179+.080*math.sin(a)) for a in [i*TAU/64 for i in range(64)]],.003,brass,True,6)
    # Tapered cast-metal handle joins broad neck directly into the frame.
    profile=[(-.014,.112),(-.011,.085),(-.008,.058),(-.015,.022),(-.013,.006),
             (0,0),(.013,.006),(.015,.022),(.008,.058),(.011,.085),(.014,.112)]
    h.extruded_profile('Continuous shaped metal handle',profile,0,.013,brass,.003)
    h.tube('Handle inset fluting',[(0,-.008,.015),(0,-.008,.040),(0,-.008,.068),(0,-.008,.092)],.002,inset,sides=6)
    for z,s in [(.012,.006),(.098,.008)]:
        h.ellipsoid('Cast handle leaf accent',(0,-.008,z),(s,.002,s*1.4),brass,16,8)
    # Few large relief leaves rather than an unreadable scatter of filigree.
    for sign in (-1,1):
        for i in range(3):
            a=sign*(.36+i*.50)
            x=.069*math.sin(a);z=.179+.082*math.cos(a)
            leaf=h.ellipsoid('Raised frame leaf',(x,-.011,z),(.005,.002,.010),brass,12,6)
            leaf.rotation_euler.y=a


def folding_fan():
    paper=material('Fan ivory washi','EEE3C9',.92)
    alternate=material('Fan shaded washi pleat','DED1B5',.92)
    bamboo=material('Fan bamboo ribs','A77B44',.68)
    guard=material('Fan dark outer guard sticks','67452B',.64)
    red=material('Fan broad vermilion print','B54943',.86)
    brass=material('Fan pivot pin','B29864',.4,.6)
    pivot=.018
    count=20
    a0,a1=math.radians(-66),math.radians(66)
    def point(a,r,y=0):return (r*math.sin(a),y,pivot+r*math.cos(a))
    # Each face pair forms one physical mountain/valley pleat; no flat arc tile.
    for i in range(count):
        left=a0+(a1-a0)*i/count;right=a0+(a1-a0)*(i+1)/count
        angles=[left,(left+right)/2,right]
        verts=[]
        for depth in (-.0006,.0006):
            for r in (.088,.132,.192,.224):
                for j,a in enumerate(angles):
                    verts.append(point(a,r,depth+(.0035 if j==1 else -.0035)*(r/.224)))
        faces=[]
        for side in (0,1):
            k=side*12
            for row in range(3):
                for col in range(2):
                    q=(k+row*3+col,k+row*3+col+1,k+(row+1)*3+col+1,k+(row+1)*3+col)
                    faces.append(tuple(reversed(q)) if side else q)
        border=[0,1,2,5,8,11,10,9,6,3]
        faces += [(border[j],border[(j+1)%10],border[(j+1)%10]+12,border[j]+12) for j in range(10)]
        obj=mesh('Folded washi fan leaf',verts,faces,paper)
        obj.data.materials.append(alternate)
        obj.data.materials.append(red)
        for p in obj.data.polygons:
            if p.index<12:
                p.material_index=1 if p.index%2 else 0
                if i in range(5,15) and p.index%6 in (2,3):p.material_index=2
    for i in range(count+1):
        a=a0+(a1-a0)*i/count
        # Bamboo is narrow and visibly supports the leaf from pivot through paper.
        u=Vector((math.cos(a),0,-math.sin(a)))
        inner=Vector(point(a,.002,-.004));outer=Vector(point(a,.222,-.004))
        width=.005 if i in (0,count) else .0025
        verts=[p+u*sign*width/2+Vector((0,y,0)) for y in (-.001,.001) for p in (inner,outer) for sign in (-1,1)]
        mesh('Outer guard' if i in (0,count) else 'Continuous bamboo rib',verts,[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],guard if i in (0,count) else bamboo)
    cylinder('Fan riveted pivot',(0,-.004,pivot+.005),.005,.010,brass,(0,1,0),20)


def parasol():
    paper=material('Parasol deep vermilion paper','BA3938',.72)
    shade=material('Parasol alternate warm paper','C64743',.72)
    ivory=material('Parasol ivory snake-eye ring','EBDDC1',.83)
    bamboo=material('Parasol bamboo ribs','B28C58',.61)
    black=material('Parasol lacquered shaft','352C26',.39)
    hubmat=material('Parasol dark wooden hubs','7B5536',.63)
    # 32 slender connected bamboo ribs carry an oil-paper dome, not a flat disk.
    count=32
    radii=[.009,.08,.18,.27,.34,.39]
    def z(r):return .69-.18*(r/.39)**1.42
    for i in range(count):
        verts=[]
        for down in (0,.0012):
            for r in radii:
                for s in range(3):
                    a=TAU*(i+s/2)/count
                    # Very slight draw between ribs; paper remains broad and taut.
                    verts.append((r*math.cos(a),r*math.sin(a),z(r)-(.002 if s==1 else 0)*(r/.39)-down))
        n=len(radii)*3
        faces=[]
        for side in (0,1):
            k=side*n
            for row in range(len(radii)-1):
                for col in range(2):
                    face=(k+row*3+col,k+row*3+col+1,k+(row+1)*3+col+1,k+(row+1)*3+col)
                    faces.append(tuple(reversed(face)) if side else face)
        border=[0,1,2]+[r*3+2 for r in range(1,len(radii))]+[n-2,n-3]+[r*3 for r in range(len(radii)-2,0,-1)]
        faces += [(border[j],border[(j+1)%len(border)],border[(j+1)%len(border)]+n,border[j]+n) for j in range(len(border))]
        obj=mesh('Taut oil-paper canopy panel',verts,faces,paper if i%2 else shade,True)
        obj.data.materials.append(ivory)
        # One structural, readable snake-eye paper band around the dome.
        for p in obj.data.polygons:
            if p.index in (2,3,12,13):p.material_index=1
        a=TAU*i/count
        h.tube('Continuous underside bamboo rib',[(r*math.cos(a),r*math.sin(a),z(r)-.0035) for r in radii],.0025,bamboo,sides=6)
        r=.245
        h.tube('Opening support strut',[(0,0,.385),(r*math.cos(a),r*math.sin(a),z(r)-.004)],.002,bamboo,sides=6)
    cylinder('Straight lacquered parasol shaft',(0,0,.35),.008,.70,black,vertices=24)
    cylinder('Grip sleeve',(0,0,.061),.012,.122,black,vertices=24)
    cylinder('Upper wooden hub',(0,0,.674),.019,.025,hubmat,vertices=24)
    cylinder('Lower sliding hub',(0,0,.386),.018,.045,hubmat,vertices=24)
    cylinder('Canopy top finial',(0,0,.706),.014,.038,black,vertices=24)
    # Rim ties are restrained: broad colored bindings at the rib endpoints.
    for i in range(count):
        a=TAU*i/count;r=.389
        cylinder('Dark rib-end binding',(r*math.cos(a),r*math.sin(a),z(r)-.002),.0038,.012,black,(math.cos(a),math.sin(a),-.5),10)


def tulip_bouquet():
    pink=material('Tulip pink petals','D66B88',.53)
    light=material('Tulip pale inner petals','EC9DAC',.57)
    green=material('Tulip living stems','568047',.74)
    leaves=material('Tulip broad waxy leaves','3C7048',.64)
    kraft=material('Bouquet kraft wrapping','BA8D58',.92)
    inside=material('Bouquet pale inner wrapping','E7D6AC',.96)
    tie=material('Bouquet rose satin tie','A04460',.40)
    heads=[(-.071,0,.36),(.008,.005,.405),(.077,.006,.355),(-.040,.057,.395),(.042,.063,.393),(-.047,-.048,.337),(.045,-.050,.336)]
    for i,(x,y,z) in enumerate(heads):
        bottom=(x*.12,y*.12,.005+(.004*i%3))
        stem=[bottom,(x*.23,y*.23,.11),(x*.7,y*.7,.25),(x,y,z)]
        h.tube('Continuous tulip stem',stem,.0032,green,sides=6)
        # Six overlapping cupped petals share their base and make a closed bud.
        for k in range(6):
            a=k*TAU/6+(i%2)*.3
            verts=[]
            for side in (0,1):
                for row in range(7):
                    t=row/6
                    r=.005+.025*math.sin(t*math.pi*.80)
                    half=.58*math.sin(math.pi*t/2)**.65
                    for col in range(7):
                        u=(col/6*2-1)
                        theta=a+u*half
                        # Rounded petals cup inward at their subtly unequal tips.
                        rr=r+side*.0010
                        verts.append((x+rr*math.cos(theta),y+rr*math.sin(theta),z+.064*t-.009*u*u*t+(.002 if k%2 else 0)))
            n=49;faces=[]
            for s in (0,1):
                for row in range(6):
                    for col in range(6):
                        q=(s*n+row*7+col,s*n+row*7+col+1,s*n+(row+1)*7+col+1,s*n+(row+1)*7+col)
                        faces.append(q if s==0 else tuple(reversed(q)))
            border=list(range(7))+[r*7+6 for r in range(1,7)]+list(range(47,41,-1))+[r*7 for r in range(5,0,-1)]
            faces += [(border[j],border[(j+1)%len(border)],border[(j+1)%len(border)]+n,border[j]+n) for j in range(len(border))]
            mesh('Cupped tulip petal',verts,faces,pink if k%2 else light,True)
        # A broad lancet leaf grows from each stem, with a central fold.
        a=i*2.3
        b=Vector((x*.33,y*.33,.155));tip=Vector((x+math.cos(a)*.05,y+math.sin(a)*.05,z+.010))
        axis=tip-b;u=Vector((-math.sin(a),math.cos(a),0))
        verts=[]
        for t in (0,.2,.45,.7,1):
            c=b+axis*t+Vector((math.cos(a),math.sin(a),0))*.025*math.sin(t*math.pi)
            w=.018*math.sin(t*math.pi)
            verts += [c-u*w,c+Vector((0,0,.004*math.sin(t*math.pi))),c+u*w]
        obj=mesh('Folded lance-shaped leaf',verts,[(r*3+j,r*3+j+1,(r+1)*3+j+1,(r+1)*3+j) for r in range(4) for j in range(2)],leaves,True)
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Real leaf thickness','SOLIDIFY');mod.thickness=.001
        bpy.ops.object.modifier_apply(modifier=mod.name)
    # Two broad overlapping sheets gather at a narrow supported tied waist.
    for sheet in range(2):
        verts=[]
        for row,(r,z) in enumerate([(.018,.07),(.026,.125),(.082,.242),(.120,.31)]):
            r+=sheet*.0025
            for j in range(33):
                a=TAU*(j/32*.70+sheet*.49)
                zz=z+(max(0,row-1)/2)*(.018*math.cos(a)+.021*math.cos(2*a+.6))
                verts.append((r*math.cos(a),r*math.sin(a),zz))
        obj=mesh('Overlapping kraft wrap sheet',verts,[(r*33+j,r*33+j+1,(r+1)*33+j+1,(r+1)*33+j) for r in range(3) for j in range(32)],kraft if sheet==0 else inside,True)
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Paper edge thickness','SOLIDIFY');mod.thickness=.0014
        bpy.ops.object.modifier_apply(modifier=mod.name)
    h.tube('Gathered ribbon around stems',[(.027*math.cos(a),.027*math.sin(a),.126) for a in [i*TAU/36 for i in range(36)]],.005,tie,True,6)
    for sign in (-1,1):
        points=[(sign*.036*math.sin(math.pi*t),-.031-.006*math.sin(TAU*t),.127+.020*math.sin(TAU*t)) for t in [j/32 for j in range(33)]]
        ribbon('Small tied ribbon loop',points,.009,tie,(0,0,1),.001)
    box('Bouquet ribbon knot',(0,-.033,.127),(.014,.012,.014),tie,.003)


def ribbon_gift():
    paper=material('Gift deep blue coated paper','30616F',.68)
    lidmat=material('Gift blue lid','3F7580',.63)
    gap=material('Gift lid seam shadow','18383F',.89)
    satin=material('Gift warm ivory satin','E7D2A1',.35)
    edge=material('Gift bow soft gold edge','B9995E',.45)
    box('Rigid wrapped gift body',(0,0,.079),(.236,.193,.158),paper,.003)
    box('Lid closing seam',(0,0,.153),(.238,.195,.004),gap,.001)
    box('Separate fitted box lid',(0,0,.166),(.246,.203,.024),lidmat,.003)
    # Broad continuous ribbons wrap all four sides and cross below the knot.
    for axis in ('x','y'):
        half=.124 if axis=='x' else .103
        pts=[(-half,0,.005),(-half,0,.166),(-half+.004,0,.180),
             (half-.004,0,.180),(half,0,.166),(half,0,.005),(-half,0,.005)]
        if axis=='y':pts=[(y,x,z) for x,y,z in pts]
        ribbon('Continuous wraparound satin band',pts,.028,satin,(0,1,0) if axis=='x' else (1,0,0))
    for sign in (-1,1):
        pts=[]
        for j in range(49):
            t=j/48
            pts.append((sign*.084*math.sin(math.pi*t),.016*math.sin(TAU*t),.19+.055*math.sin(math.pi*t)+.014*math.sin(TAU*t)))
        ribbon('Full hollow satin bow loop',pts,.031,satin,(0,1,0),.0013)
    # Two folded tails lie on the lid and drop over the front edge.
    for sign in (-1,1):
        pts=[(0,0,.192),(sign*.025,-.032,.187),(sign*.040,-.069,.182),
             (sign*.047,-.100,.180),(sign*.052,-.104,.160),(sign*.058,-.104,.133)]
        ribbon('Folded satin bow tail',pts,.028,satin,(1,0,0),.0013)
    box('Soft bow central knot',(0,0,.195),(.032,.040,.026),satin,.008)


ASSETS = [
    ('scrap_ring_box','P002_ring_box',ring_box),
    ('scrap_heart_chocolates','P003_heart_chocolates',chocolates),
    ('scrap_perfume','P004_perfume',perfume),
    ('scrap_hand_mirror','P005_hand_mirror',hand_mirror),
    ('scrap_folding_fan','P006_folding_fan',folding_fan),
    ('scrap_parasol','P007_parasol',parasol),
    ('scrap_tulip_bouquet','P008_tulip_bouquet',tulip_bouquet),
    ('scrap_ribbon_gift','P009_ribbon_gift',ribbon_gift),
]


def preview(filename, row, out):
    """Local Blender evidence only; game import QA is owned by integration."""
    # Re-import the actual exported delivery representation in a fresh scene.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(h.ASSETS/(filename+'.glb')))
    # glTF importer returns Blender Z-up. Use the stored authoring bounds.
    low=Vector(row['blender_bounds_min']);high=Vector(row['blender_bounds_max'])
    center=(low+high)/2;extent=max(high-low)*1.5
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=20
    scene.cycles.use_denoising=True
    scene.render.resolution_x=600;scene.render.resolution_y=600
    scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Neutral studio');scene.world.color=(.3,.3,.3)
    scene.view_settings.view_transform='AgX'
    for at,power,size in [((-2,-3,4),300,3),((2,-1,2),180,2),((0,3,3),300,2)]:
        data=bpy.data.lights.new('Broad studio area','AREA');data.energy=power;data.shape='DISK';data.size=size
        obj=bpy.data.objects.new('Broad studio area',data);bpy.context.collection.objects.link(obj)
        obj.location=center+Vector(at)*max(extent,.5)
        obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add()
    camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=extent
    camera.location=center+Vector((1.3,-2.8,1.6))*extent
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    scene.camera=camera
    scene.render.image_settings.file_format='PNG'
    scene.render.filepath=str(out/(filename+'_delivery_preview.png'))
    bpy.ops.render.render(write_still=True)


def main():
    out=h.PROJECT.parent/'artifacts/rebuild-small-a'
    out.mkdir(parents=True,exist_ok=True)
    rows=[]
    for kind,original,build in ASSETS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        h.PARTS.clear();h.MARKERS.clear()
        build()
        row=h.export_asset(original+'_rebuilt')
        row.update(kind=kind,original_file=original,textures_embedded=False,finite_geometry=True)
        rows.append(row)
        bpy.ops.wm.save_as_mainfile(filepath=str(out/(original+'.blend')))
        if '--preview' in sys.argv or '--preview='+original in sys.argv:
            preview(original+'_rebuilt',row,out)
    (SOURCE/'build_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    replacements=[dict(kind=kind,original_file=original,file=original+'_rebuilt') for kind,original,_ in ASSETS]
    (SOURCE/'replacements.json').write_text(json.dumps(replacements,indent=2),encoding='utf-8')
    print('SMALL_A_BUILD_OK '+json.dumps(rows))


if __name__=='__main__':main()
