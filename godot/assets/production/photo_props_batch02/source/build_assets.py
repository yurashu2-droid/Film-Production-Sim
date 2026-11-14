"""Photo-informed toilet, galvanized watering can and classic trophy cup."""
from pathlib import Path
import importlib.util
import math
import json
import bpy
from mathutils import Vector

SOURCE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('fresh_helpers',SOURCE.parents[1]/'fresh_props/source/build_assets.py')
f=importlib.util.module_from_spec(spec)
spec.loader.exec_module(f)
h=f.h
box,cylinder,material=h.box,h.cylinder,h.material


def oval_loft(name,profile,mat,cy=0.,rear=None,sides=64):
    vertices=[]
    for rx,ry,z in profile:
        for i in range(sides):
            a=i*math.tau/sides
            y=cy+ry*math.sin(a)
            vertices.append((rx*math.cos(a),min(y,rear) if rear is not None else y,z))
    faces=[]
    for j in range(len(profile)-1):
        for i in range(sides):
            a=j*sides+i
            b=j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    return f.mesh(name,vertices,faces,mat)


def toilet():
    porcelain=material('Toilet glazed ivory porcelain','E8E8DF',.23)
    plastic=material('Toilet white seat and lid','F0EFE5',.33)
    chrome=material('Toilet chrome lever and hinges','B5C0C4',.28,.9)
    seal=material('Toilet seam shadow','7D817B',.85)
    # A wide foot, narrowing pedestal and bowl are connected by overlapping roots.
    oval_loft('Ceramic floor pedestal',[(0,0,0),(.145,.202,0),(.154,.213,.016),
              (.151,.208,.038),(.134,.185,.10),(.115,.16,.18),
              (.125,.17,.25),(0,0,.25)],porcelain,cy=.012)
    oval_loft('Rounded hollow ceramic bowl',[(0,0,.16),(.10,.14,.16),(.135,.20,.21),
              (.18,.25,.30),(.225,.286,.38),(.244,.307,.424),
              (.244,.307,.444),(.232,.295,.455),(.215,.274,.455),
              (.20,.26,.438),(.18,.23,.38),(.12,.16,.30),
              (.055,.075,.274),(0,0,.274)],porcelain,cy=-.085,rear=.151)
    # A real seat ring, with a separate closed lid and visible hinge gap.
    oval_loft('Molded oval seat ring',[(.243,.303,.456),(.250,.310,.464),
              (.245,.305,.478),(.230,.290,.483),(.174,.231,.483),
              (.169,.226,.472),(.173,.230,.458),(.243,.303,.456)],plastic,cy=-.085,rear=.149)
    oval_loft('Closed curved seat lid',[(0,0,.486),(.21,.27,.486),
              (.243,.300,.488),(.248,.305,.495),(.240,.296,.506),
              (.21,.26,.516),(.14,.18,.523),(0,0,.526)],plastic,cy=-.085,rear=.150)
    box('Rear bowl platform',(0,.21,.435),(.43,.22,.07),porcelain,.025)
    box('Rounded water tank',(0,.28,.671),(.52,.24,.402),porcelain,.035)
    box('Tank lid seating seam',(0,.28,.875),(.508,.230,.006),seal,.012)
    box('Separate ceramic tank lid',(0,.28,.888),(.545,.259,.024),porcelain,.011)
    for x in (-.128,.128):
        cylinder('Seat hinge barrel',(x,.143,.486),.015,.070,chrome,(1,0,0),20)
        box('Hinge mounting',(x,.157,.470),(.074,.046,.012),plastic,.004)
    cylinder('Flush lever mount',(.267,.265,.792),.023,.018,chrome,(1,0,0),24)
    box('Flush lever',(.281,.235,.792),(.016,.070,.018),chrome,.006)
    for x in (-.14,.14):
        h.ellipsoid('Floor fastening cap',(x,.02,.035),(.011,.020,.010),plastic,16,8)
    h.ticket_anchor((.105,.159,.70))


def watering_can():
    zinc=material('Watering can satin galvanized steel','A4B2B7',.43,.85)
    edge=material('Watering can rolled metal edges','C0C8C8',.34,.9)
    brass=material('Watering can brass rose','C5A460',.43,.85)
    dark=material('Watering can perforation recess','26373B',.85)
    wood=material('Watering can red carrying grip','883D37',.62)
    f.lathe('Thin walled body and sloping shoulder',[(0,0),(.137,0),(.147,.009),
            (.149,.026),(.149,.274),(.144,.286),(.116,.307),
            (.065,.307),(.061,.303),(.061,.296),(.113,.296),
            (.138,.276),(.138,.025),(.13,.013),(0,.013)],zinc,64)
    f.lathe('Bottom rolled seam',[(.145,.006),(.152,.010),(.153,.017),
            (.148,.023),(.145,.019),(.145,.006)],edge,64)
    f.lathe('Upper rolled shoulder seam',[(.143,.275),(.151,.279),(.151,.286),
            (.145,.291),(.140,.285),(.143,.275)],edge,64)
    f.lathe('Open filling neck',[(.061,.295),(.067,.300),(.067,.310),
            (.062,.314),(.057,.310),(.057,.301),(.061,.295)],edge,48)
    cylinder('Dark interior floor',(0,0,.015),.115,.003,dark,vertices=48)
    # Functional front spout and its attached spray rose.
    start=Vector((-.115,0,.076))
    end=Vector((-.355,0,.317))
    delta=end-start
    bpy.ops.mesh.primitive_cone_add(vertices=32,radius1=.043,radius2=.016,
                                  depth=delta.length,location=(start+end)/2)
    obj=bpy.context.object
    obj.name='Long tapered pouring spout'
    obj.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    f.finish(obj,zinc,.0015)
    axis=delta.normalized()
    rose=f.lathe('Flared removable rose',[(.015,0),(.019,.008),(.024,.015),
            (.052,.038),(.055,.043),(.054,.049),(.047,.051),
            (0,.051)],brass,40)
    rose.rotation_euler=axis.to_track_quat('Z','Y').to_euler()
    rose.location=end
    face_center=end+axis*.052
    basis1=Vector((0,1,0))
    basis2=axis.cross(basis1).normalized()
    # At game scale, the rose holes are tiny inset dark disks, not hundreds of booleans.
    for radius,count in [(0,1),(.017,6),(.033,12)]:
        for i in range(count):
            a=i*math.tau/count
            at=face_center+radius*(math.cos(a)*basis1+math.sin(a)*basis2)
            cylinder('Rose perforation',at,.0026,.0015,dark,axis,10)
    for y in (-.149,.149):
        cylinder('Bail handle pivot',(0,y,.277),.016,.016,edge,(0,1,0),20)
    bail=[(0,.149*math.cos(a),.277+.186*math.sin(a))
          for a in [i*math.pi/36 for i in range(37)]]
    h.tube('Arched carrying handle',bail,.0055,edge,sides=8)
    cylinder('Red wooden grip',(0,0,.461),.012,.078,wood,(0,1,0),24)
    h.tube('Rear pouring grip',[(.142,0,.076),(.221,0,.105),
           (.228,0,.245),(.143,0,.268)],.009,edge,sides=8)
    h.tube('Rear body seam',[(.023,.148,.028),(.023,.148,.274)],.0016,edge,sides=6)


def smooth_path(points,steps=5):
    pts=[Vector(p) for p in points]
    result=[]
    for i in range(len(pts)-1):
        p0,p1,p2,p3=pts[max(0,i-1)],pts[i],pts[i+1],pts[min(len(pts)-1,i+2)]
        for j in range(steps):
            t=j/steps
            result.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+
                               (-p0+3*p1-3*p2+p3)*t*t*t))
    return result+[pts[-1]]


def trophy():
    gold=material('Trophy polished warm gold','D9B04C',.27,.96)
    base=material('Trophy black lacquer base','202325',.32)
    plaque=material('Trophy satin engraving plaque','BC9952',.5,.85)
    box('Base bottom step',(0,0,.010),(.18,.155,.020),base,.004)
    box('Black square pedestal',(0,0,.046),(.163,.138,.062),base,.004)
    box('Blank award plaque',(0,-.071,.044),(.125,.004,.037),plaque,.002)
    f.lathe('Turned supporting stem',[(0,.077),(.070,.077),(.073,.084),(.073,.093),
            (.063,.101),(.059,.117),(.046,.127),(.039,.135),(.036,.147),
            (.027,.155),(.022,.18),(.022,.204),(.030,.219),(.030,.231),(0,.231)],gold,64)
    f.lathe('Hollow trophy bowl',[(0,.225),(.025,.225),(.042,.244),(.066,.274),
            (.088,.311),(.106,.353),(.120,.409),(.130,.477),(.134,.492),
            (.134,.500),(.128,.504),(.122,.498),(.121,.479),(.111,.412),
            (.098,.359),(.080,.315),(.059,.281),(.036,.258),(0,.254)],gold,72)
    for side in (-1,1):
        points=[(side*.127,0,.478),(side*.160,0,.483),(side*.177,0,.525),
                (side*.204,0,.528),(side*.217,0,.497),(side*.205,0,.454),
                (side*.178,0,.406),(side*.143,0,.359),(side*.079,0,.293)]
        h.tube('Swept trophy handle',smooth_path(points),.008,gold,sides=8)
        h.ellipsoid('Handle lower root',(side*.082,0,.30),(.016,.012,.022),gold,20,10)
    f.lathe('Cup rolled lip',[(.128,.492),(.137,.494),(.139,.500),
            (.134,.505),(.127,.502),(.128,.492)],gold,72)


def main():
    out=h.PROJECT.parent/'artifacts/photo-props-batch02-20261017'
    out.mkdir(parents=True,exist_ok=True)
    rows=[]
    for name,filename,build in [('toilet','S042_cartoon_toilet_photo',toilet),
                               ('watering_can','P047_watering_can_photo',watering_can),
                               ('trophy','P050_trophy_cup_photo',trophy)]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        h.PARTS.clear()
        h.MARKERS.clear()
        build()
        row=h.export_asset(filename)
        row['textures_embedded']=False
        rows.append(row)
        bpy.ops.wm.save_as_mainfile(filepath=str(out/(name+'.blend')))
    (SOURCE/'build_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    print('PHOTO_PROPS_BATCH02_OK '+json.dumps(rows))


if __name__=='__main__':
    main()
