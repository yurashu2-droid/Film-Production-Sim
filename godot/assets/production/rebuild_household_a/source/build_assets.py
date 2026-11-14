"""Continuous toilet body and five household props for the all-prop rebuild."""
from pathlib import Path
import importlib.util
import math
import json
import bpy
from mathutils import Vector

SOURCE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('previous_household',SOURCE.parents[1]/'photo_props_batch02/source/build_assets.py')
b=importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)
f,h=b.f,b.h
box,cylinder,material=h.box,h.cylinder,h.material


def remove_named(names):
    for obj in list(h.PARTS):
        if obj.name in names:
            h.PARTS.remove(obj)
            bpy.data.objects.remove(obj,do_unlink=True)


def toilet():
    b.toilet()
    remove_named({'Ceramic floor pedestal','Rounded hollow ceramic bowl',
                  'Rounded water tank','Tank lid seating seam','Separate ceramic tank lid'})
    ceramic=bpy.data.materials['Toilet glazed ivory porcelain']
    # One continuous outside wall, from a deep floor foot to the full bowl.
    # Varying centers carry the rear body toward the tank instead of pinching
    # the bowl into a goblet balanced on an unrelated truncated cone.
    rings=[(0,0,0,.035),(.15,.225,0,.035),(.162,.235,.02,.035),
           (.164,.235,.06,.035),(.160,.23,.12,.035),(.161,.235,.19,.025),
           (.180,.253,.26,.005),(.210,.278,.33,-.03),(.236,.300,.39,-.07),
           (.244,.307,.424,-.085),(.244,.307,.444,-.085),
           (.232,.295,.455,-.085),(.215,.274,.455,-.085),
           (.20,.26,.438,-.085),(.18,.23,.38,-.085),
           (.12,.16,.30,-.085),(.055,.075,.274,-.085),(0,0,.274,-.085)]
    n=24
    vertices=[]
    for rx,ry,z,cy in rings:
        for i in range(n):
            a=i*math.tau/n
            vertices.append((rx*math.cos(a),min(cy+ry*math.sin(a),.20 if z<.33 else .151),z))
    faces=[]
    for j in range(len(rings)-1):
        for i in range(n):
            a=j*n+i
            c=j*n+(i+1)%n
            faces.append((a,c,c+n,a+n))
    f.mesh('Unified floor to bowl ceramic body',vertices,faces,ceramic)
    box('Rounded water tank',(0,.28,.671),(.52,.24,.402),ceramic,.025)
    box('Tank lid seating seam',(0,.28,.874),(.506,.229,.003),bpy.data.materials['Toilet seam shadow'],.009)
    box('Separate ceramic tank lid',(0,.28,.887),(.53,.248,.025),ceramic,.009)


def mug():
    glaze=material('Mug blue glazed stoneware','426C80',.24)
    f.lathe('Hollow mug wall and base',[(0,0),(.064,0),(.074,.006),(.080,.028),
            (.087,.12),(.088,.14),(.086,.146),(.081,.146),
            (.079,.14),(.078,.12),(.071,.026),(.063,.015),(0,.015)],glaze,64)
    points=[(.085+.065*math.cos(a)-.008*(abs(a)/1.5)**4,0,.078+.055*math.sin(a))
            for a in [-1.5+i*3/36 for i in range(37)]]
    h.tube('Continuous mug handle',points,.012,glaze,sides=10)


def rolling_pin():
    wood=material('Rolling pin pale beech','C6A372',.64)
    handle=material('Rolling pin turned handles','A17A4E',.6)
    drum=f.lathe('Smooth rolling barrel',[(0,-.205),(.047,-.205),(.053,-.199),
                 (.055,-.185),(.055,.185),(.053,.199),(.047,.205),(0,.205)],wood,64)
    drum.rotation_euler.y=math.pi/2
    drum.location.z=.055
    for side in (-1,1):
        profile=[(0,.20),(.015,.20),(.015,.216),(.021,.223),(.023,.24),
                 (.022,.276),(.017,.289),(0,.292)]
        part=f.lathe('Turned wooden grip',[(r,z*side) for r,z in profile],handle,40)
        part.rotation_euler.y=math.pi/2
        part.location.z=.055


def frying_pan():
    iron=material('Pan seasoned cast iron','292D2E',.73,.35)
    f.lathe('Thick hollow cast iron pan',[(0,0),(.11,0),(.137,.004),(.147,.012),
            (.158,.045),(.159,.053),(.155,.058),(.149,.056),
            (.146,.047),(.137,.018),(.128,.011),(0,.011)],iron,64)
    # Flat cast handle and actual hanging eye, with a narrow supporting neck.
    handle=h.extruded_profile('Flat cast handle',[(.145,-.014),(.175,-.018),
             (.313,-.017),(.325,-.011),(.325,.011),(.313,.017),
             (.175,.018),(.145,.014)],0,.013,iron,.003)
    handle.rotation_euler.x=math.pi/2
    handle.location.z=.039
    eye=f.lathe('Open handle hanging eye',[(.011,0),(.020,0),(.023,.004),
                (.023,.009),(.020,.014),(.011,.014),(.011,0)],iron,32)
    eye.location=(.340,0,.032)
    # Small opposite assist loop, attached at both ends.
    h.tube('Pan helper grip',[(-.148,-.044,.039),(-.185,-.046,.04),
           (-.198,0,.04),(-.185,.046,.04),(-.148,.044,.039)],.008,iron,sides=8)


def plunger():
    red=material('Plunger matte red rubber','9F3E35',.86)
    wood=material('Plunger wooden shaft','B6905F',.65)
    f.lathe('Open rubber suction cup',[(.09,0),(.10,.008),(.098,.021),
            (.086,.053),(.065,.087),(.027,.105),(.025,.119),
            (.015,.12),(.015,.102),(.025,.094),(.055,.077),
            (.075,.047),(.085,.014),(.084,0),(.09,0)],red,64)
    cylinder('Wooden handle',(0,0,.349),.012,.48,wood,vertices=32)
    h.ellipsoid('Rounded handle end',(0,0,.590),(.012,.012,.012),wood,20,10)
    paper=material('Plunger hanging paper tag','D2C5A2',.9)
    box('Paper disposal tag',(0,-.019,.44),(.13,.003,.085),paper,.001)
    h.tube('Tag hanging loop',[(0,0,.52),(-.025,-.02,.49),(0,-.02,.482),(.025,-.02,.49),(0,0,.52)],.0015,red,sides=4)
    h.ticket_anchor((0,-.022,.44))


def broom():
    wood=material('Broom varnished wooden handle','AD8352',.63)
    straw=material('Broom bound golden straw','BE9C59',.86)
    thread=material('Broom red binding cord','8C4737',.9)
    darkstraw=material('Broom darker straw fibers','9D7C40',.88)
    cylinder('Long wood shaft',(0,0,.64),.014,.92,wood,vertices=32)
    h.ellipsoid('Rounded handle end',(0,0,1.101),(.014,.014,.014),wood,20,10)
    # A broad, thin fan of straw with restrained irregularity at the sweeping edge.
    n=32
    vertices=[]
    for y in (-.026,.026):
        for i in range(n+1):
            x=-.145+i*.29/n
            bottom=.006+.003*(math.sin(i*2.7)**2)
            vertices += [(x,y,bottom),(x*.23,y*.67,.235)]
    faces=[]
    stride=(n+1)*2
    for i in range(n):
        a=i*2
        faces += [(a,a+2,a+3,a+1),(a+stride+1,a+stride+3,a+stride+2,a+stride),
                  (a,a+stride,a+stride+2,a+2),(a+1,a+3,a+stride+3,a+stride+1)]
    faces += [(0,1,stride+1,stride),(n*2,n*2+stride,n*2+stride+1,n*2+1)]
    f.mesh('Shaped bound straw head',vertices,faces,straw,False)
    for i in range(25):
        x=-.138+i*.276/24
        for side in (-1,1):
            h.tube('Grouped visible straw',[(x,side*.026,.012),
                   (x*.65,side*.023,.13),(x*.23,side*.018,.232)],.0012,
                   darkstraw if i%3==0 else straw,sides=6)
    for z in (.08,.125,.175,.222):
        width=.29*(1-z/.235)+.067*(z/.235)
        h.tube('Binding loop',[(-width/2,-.028,z),(width/2,-.028,z),
               (width/2,.028,z),(-width/2,.028,z)],.0025,thread,True,sides=6)


BUILDS=[('scrap_toilet','S042_cartoon_toilet',toilet),
        ('scrap_mug','P036_mug',mug),('scrap_rolling_pin','P037_rolling_pin',rolling_pin),
        ('scrap_frying_pan','P038_frying_pan',frying_pan),
        ('scrap_plunger','P045_plunger',plunger),('scrap_broom','P046_broom',broom)]


def main():
    out=h.PROJECT.parent/'artifacts/rebuild-household-a'
    out.mkdir(parents=True,exist_ok=True)
    rows=[]
    replacements=[]
    for kind,original,build in BUILDS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        h.PARTS.clear()
        h.MARKERS.clear()
        build()
        row=h.export_asset(original+'_rebuilt')
        row['textures_embedded']=False
        rows.append(row)
        replacements.append(dict(kind=kind,original_file=original,file=original+'_rebuilt'))
        bpy.ops.wm.save_as_mainfile(filepath=str(out/(kind+'.blend')))
    for name,data in [('build_manifest.json',rows),('replacements.json',replacements)]:
        (SOURCE/name).write_text(json.dumps(data,indent=2),encoding='utf-8')
    print('HOUSEHOLD_A_BUILD_OK '+json.dumps(rows))


if __name__=='__main__':
    main()
