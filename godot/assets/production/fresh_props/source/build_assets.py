"""Name-only reference study: a ceramic teapot and leather suitcase."""
from pathlib import Path
import sys
import math
import json
import importlib.util
import bpy
from mathutils import Vector

SOURCE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('prop_helpers', SOURCE.parents[1]/'refined_props/source/build_assets.py')
h = importlib.util.module_from_spec(spec)
spec.loader.exec_module(h)
box, cylinder, material = h.box, h.cylinder, h.material


def finish(obj, mat, bevel=0., smooth=True):
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    if bevel:
        mod=obj.modifiers.new('Rounded crafted edges','BEVEL')
        mod.width,mod.segments=bevel,2
        mod.limit_method='ANGLE'
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for p in obj.data.polygons: p.use_smooth=True
        mod=obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
        mod.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    h.PARTS.append(obj)
    return obj


h.finish=finish


def mesh(name, vertices, faces, mat, smooth=True):
    data=bpy.data.meshes.new(name)
    data.from_pydata(vertices,[],faces)
    data.update()
    obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.use_smooth = smooth
    h.PARTS.append(obj)
    return obj


def lathe(name, profile, mat, sides=48):
    verts=[(r*math.cos(i*math.tau/sides), r*math.sin(i*math.tau/sides), z)
           for r,z in profile for i in range(sides)]
    faces=[]
    for j in range(len(profile)-1):
        for i in range(sides):
            a=j*sides+i
            b=j*sides+(i+1)%sides
            faces.append((a,b,b+sides,a+sides))
    return mesh(name,verts,faces,mat)


def teapot():
    glaze=material('Warm ivory ceramic glaze','E8E0CE',.22)
    clay=material('Unglazed stoneware foot','A98A65',.85)
    interior=material('Teapot inner ceramic','88765D',.5)
    # Continuous revolved vessel, with a real neck and wall behind the fitted lid.
    lathe('Ceramic vessel',[(0,.009),(.070,.009),(.093,.018),(.116,.038),
          (.141,.070),(.157,.108),(.165,.147),(.162,.181),(.151,.216),
          (.134,.241),(.115,.258),(.110,.261),(.105,.256),(.105,.244),
          (.126,.231),(.143,.208),(.153,.178),(.155,.146),(.147,.109),
          (.129,.070),(.105,.045),(.070,.027),(0,.027)],glaze)
    lathe('Stoneware foot ring',[(.079,.0),(.091,.0),(.094,.009),(.091,.017),
          (.083,.017),(.079,.009),(.079,.0)],clay)
    lathe('Lid seating shadow',[(.100,.254),(.108,.254),(.108,.261),(.100,.261),(.100,.254)],interior)
    lathe('Domed fitted lid',[(0,.263),(.075,.263),(.101,.264),(.103,.267),
          (.096,.274),(.078,.282),(.054,.289),(.030,.292),(0,.292)],glaze)
    lathe('Lid rim accent',[(.100,.263),(.104,.264),(.104,.267),(.100,.268),(.100,.263)],clay)
    cylinder('Knob stem',(0,0,.298),.013,.022,glaze,vertices=24)
    h.ellipsoid('Rounded lid knob',(0,0,.321),(.023,.023,.024),glaze,24,12)
    # A changing-radius tube with an open mouth and an inner ceramic wall.
    centers=[(-.085,0,.104),(-.143,0,.128),(-.181,0,.151),
             (-.201,0,.189),(-.223,0,.224),(-.250,0,.250),(-.270,0,.264)]
    radii=[.048,.043,.036,.029,.025,.022,.021]
    n=28
    verts=[]
    for inner in (False,True):
        for j,p in enumerate(centers):
            tangent=Vector(centers[min(j+1,len(centers)-1)])-Vector(centers[max(j-1,0)])
            tangent.normalize()
            normal=Vector((0,1,0))
            binormal=tangent.cross(normal).normalized()
            radius=radii[j]-(.004 if inner else 0)
            for i in range(n):
                a=i*math.tau/n
                verts.append(Vector(p)+radius*(math.cos(a)*normal+math.sin(a)*binormal))
    faces=[]
    count=len(centers)*n
    for inside in (0,1):
        offset=inside*count
        for j in range(len(centers)-1):
            for i in range(n):
                a,b=offset+j*n+i,offset+j*n+(i+1)%n
                face=(a,b,b+n,a+n)
                faces.append(tuple(reversed(face)) if inside else face)
    for i in range(n):
        a=(len(centers)-1)*n+i
        b=(len(centers)-1)*n+(i+1)%n
        faces.append((a,b,b+count,a+count))
    mesh('Curved hollow spout',verts,faces,glaze)
    # Deep dark ceramic at the base makes the open mouth legible at game distance.
    throat=cylinder('Spout inner throat',centers[3],.024,.006,interior,
                    Vector(centers[4])-Vector(centers[2]),vertices=28)
    handle=[(.105+.134*math.cos(a)-.025*(abs(a)/1.45)**6,0,.155+.095*math.sin(a))
            for a in [-1.45+i*2.90/32 for i in range(33)]]
    h.tube('Continuous ceramic handle',handle,.017,glaze,sides=10)


def rounded_profile(width,height,radius,base=0,steps=7):
    points=[]
    for cx,cz,start in [(width/2-radius,base+height-radius,0),
                        (-width/2+radius,base+height-radius,math.pi/2),
                        (-width/2+radius,base+radius,math.pi),
                        (width/2-radius,base+radius,math.pi*1.5)]:
        for i in range(steps+1):
            a=start+i*math.pi/2/steps
            points.append((cx+radius*math.cos(a),cz+radius*math.sin(a)))
    return points


def suitcase():
    leather=material('Suitcase chestnut leather','75452E',.62)
    trim=material('Suitcase dark leather bindings','422B20',.72)
    piping=material('Suitcase warm seam piping','AC8053',.7)
    brass=material('Suitcase aged brass fittings','BF9956',.38,.85)
    dark=material('Suitcase joint shadow','241B16',.85)
    profile=rounded_profile(.56,.36,.035)
    for y in (-.047,.047):
        h.extruded_profile('Leather case half',profile,y,.092,leather,.003)
    # The opening seam wraps all four sides, supported by both case halves.
    h.tube('Central closing seam',[(x,0,z) for x,z in profile],.002,dark,True,sides=6)
    for y in (-.095,.095):
        edge=rounded_profile(.54,.34,.028,.01)
        h.tube('Rolled edge piping',[(x,y,z) for x,z in edge],.0017,piping,True,sides=6)
    for x in (-.171,.171):
        box('Wraparound belt',(x,0,.18),(.043,.195,.370),trim,.015)
        # Actual open buckle, with a crossbar and a tongue over the strap.
        y=-.104
        buckle=[(x-.026,y,.247),(x+.026,y,.247),(x+.026,y,.205),
                (x-.026,y,.205)]
        h.tube('Brass buckle frame',buckle,.003,brass,True,sides=8)
        cylinder('Buckle crossbar',(x,y,.235),.002,.047,brass,(1,0,0),12)
        box('Buckle tongue',(x,y-.003,.224),(.004,.005,.023),brass,.001)
        # A pointed strap end makes the belt read as leather rather than a box band.
        h.extruded_profile('Belt pointed tail',[(x-.018,.211),(x+.018,.211),
              (x+.018,.157),(x,.145),(x-.018,.157)],-.103,.006,trim,.002)
        for z in (.173,.186):
            cylinder('Belt punched hole',(x,-.108,z),.0018,.0015,dark,(0,-1,0),10)
        box('Top latch mounting',(x,.022,.372),(.066,.057,.007),brass,.004)
        box('Top latch bridge',(x,.009,.382),(.035,.04,.012),brass,.003)
    # Protective patches follow the rounded front corners and wrap onto the side.
    for sx in (-1,1):
        for top in (False,True):
            z=.36 if top else 0
            # Quarter-round cap with two radiused ends; main outline remains rounded.
            pts=[(sx*.213,z), (sx*.245,z), (sx*.270,z+(-.013 if top else .013)),
                 (sx*.280,z+(-.035 if top else .035)),
                 (sx*.280,z+(-.068 if top else .068)),
                 (sx*.253,z+(-.068 if top else .068)),
                 (sx*.225,z+(-.047 if top else .047))]
            h.extruded_profile('Leather corner protector',pts,-.096,.010,trim,.004)
            for px,pz in [(sx*.251,z+(-.021 if top else .021)),
                          (sx*.263,z+(-.052 if top else .052))]:
                h.ellipsoid('Corner rivet',(px,-.104,pz),(.0035,.0018,.0035),brass,12,6)
    for x in (-.083,.083):
        box('Handle mounting plate',(x,0,.372),(.048,.048,.008),brass,.004)
        points=[(x-.012,0,.374),(x-.012,0,.399),(x+.012,0,.399),(x+.012,0,.374)]
        h.tube('Handle attachment loop',points,.0035,brass,False,sides=8)
    grip=[(-.083+i*.166/20,0,.395+.035*math.sin(i*math.pi/20)) for i in range(21)]
    h.tube('Curved leather grip',grip,.012,trim,sides=10)
    h.tube('Handle edge seam',[(x,-.011,z+.002) for x,y,z in grip],.001,piping,sides=6)
    for x in (-.17,.17):
        box('Rear hinge',(x,.099,.11),(.055,.008,.035),brass,.003)
        cylinder('Hinge pin',(x,.105,.11),.004,.057,brass,(1,0,0),12)


def main():
    out=h.PROJECT.parent/'artifacts/fresh-props-20261017'
    out.mkdir(parents=True,exist_ok=True)
    rows=[]
    for name,filename,build in [('teapot','P035_teapot_fresh',teapot),
                                ('suitcase','P048_travel_suitcase_fresh',suitcase)]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        h.PARTS.clear()
        h.MARKERS.clear()
        build()
        row=h.export_asset(filename)
        row['textures_embedded']=False
        rows.append(row)
        bpy.ops.wm.save_as_mainfile(filepath=str(out/(name+'.blend')))
    (SOURCE/'build_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    print('FRESH_PROPS_OK '+json.dumps(rows))


if __name__=='__main__':
    main()
