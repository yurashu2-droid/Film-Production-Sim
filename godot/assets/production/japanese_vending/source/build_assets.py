"""Japanese drink vending machine, using the user's real-machine photo for layout."""
from pathlib import Path
import importlib.util
import math
import json
import bpy

SOURCE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('fresh_helpers',SOURCE.parents[1]/'fresh_props/source/build_assets.py')
f=importlib.util.module_from_spec(spec)
spec.loader.exec_module(f)
h=f.h
box,cylinder,material=h.box,h.cylinder,h.material


def pocket_box(name,at,size,mat,holes,bevel):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for center,dimensions,radius in holes:
        bpy.ops.mesh.primitive_cube_add(size=1,location=center)
        cutter=bpy.context.object
        cutter.dimensions=dimensions
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        if radius:
            mod=cutter.modifiers.new('Rounded recess','BEVEL')
            mod.width,mod.segments=radius,3
            bpy.context.view_layer.objects.active=cutter
            bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.objects.active=obj
        mod=obj.modifiers.new('Physical opening','BOOLEAN')
        mod.operation,mod.solver,mod.object='DIFFERENCE','EXACT',cutter
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter,do_unlink=True)
    obj.data.materials.clear()
    for face in obj.data.polygons: face.material_index=0
    return f.finish(obj,mat,bevel)


def text(name,word,at,size,mat):
    data=bpy.data.curves.new(name,'FONT')
    data.body=word
    data.align_x='CENTER'
    data.align_y='CENTER'
    data.size=size
    data.extrude=.0003
    obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    obj.location=at
    obj.rotation_euler.x=math.pi/2
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.convert(target='MESH')
    obj=bpy.context.object
    f.finish(obj,mat,smooth=False)


def build():
    blue=material('Vending cobalt blue paint','24469B',.34)
    white=material('Vending ivory shelves and labels','F1F0DF',.55)
    dark=material('Vending dark recesses and rubber','172329',.76)
    steel=material('Vending brushed steel fittings','AEB7BA',.34,.85)
    red=material('Vending red advertisement','BA2F32',.46)
    green=material('Vending green status display','76B04C',.6)
    yellow=material('Vending return pocket surround','D7A940',.4)
    drinks=[red,material('Drink orange','E9AF32',.4),
            material('Drink light blue','5BADC6',.4),green,
            material('Drink coffee brown','493125',.55)]
    openings=[((-.05,-.24,1.11),(.652,.25,.654),.009),
              ((-.05,-.24,.34),(.606,.25,.17),.009)]
    pocket_box('Continuous steel cabinet',(0,0,.77),(.82,.58,1.46),blue,openings,.012)
    through=[((x,-.32,z),(w,.12,ht),r) for (x,y,z),(w,depth,ht),r in openings]
    pocket_box('Door perimeter seal',(0,-.294,.77),(.795,.012,1.432),dark,through,.007)
    pocket_box('Blue front door',(0,-.307,.77),(.784,.024,1.42),blue,through,.007)
    pocket_box('White display surround',(-.05,-.324,1.11),(.675,.019,.677),white,
               [((-.05,-.33,1.11),(.632,.10,.634),.005)],.003)
    box('White product well',(-.05,-.122,1.11),(.64,.018,.64),white,.004)
    box('Upper window light',(-.05,-.21,1.416),(.58,.11,.015),white,.002)
    for row in range(3):
        base=.856+row*.195
        # Every drink stands on a recessed shelf; the white fascia carries buttons.
        box('Shelf',(-.05,-.221,base-.008),(.628,.182,.016),white,.002)
        box('Selection fascia',(-.05,-.311,base-.030),(.628,.033,.034),white,.002)
        for col in range(8):
            x=-.302+col*.072
            color=drinks[(col+2*row)%len(drinks)]
            bottle=(row+col)%4==0
            if bottle:
                profile=[(0,base),(.022,base),(.025,base+.008),(.025,base+.091),
                         (.013,base+.113),(.012,base+.136),(0,base+.136)]
            else:
                profile=[(0,base),(.024,base),(.027,base+.006),(.027,base+.116),
                         (.024,base+.124),(0,base+.124)]
            body=f.lathe('Bottle' if bottle else 'Can',profile,color,16)
            body.location.x=x
            body.location.y=-.226
            band=f.lathe('Wrapped drink label',[(.0255 if bottle else .0275,base+.027),
                         (.0255 if bottle else .0275,base+.073)],white,16)
            band.location.x=x
            band.location.y=-.226
            # A large simple emblem reads as printed packaging, without microtext.
            cylinder('Drink label emblem',(x,-.254,base+.052),.011,.0015,color,(0,-1,0),12)
            if bottle:
                cylinder('Bottle cap',(x,-.226,base+.139),.013,.013,white,vertices=12)
            else:
                cylinder('Can top',(x,-.226,base+.125),.024,.004,steel,vertices=16)
            button=cylinder('Oval selection button',(x,-.332,base-.030),.010,.007,dark,(0,-1,0),16)
            button.scale.x=1.8
            box('Selection indicator',(x,-.337,base-.024),(.014,.002,.002),green,.0005)
    # This machine has a narrow right rail, with a status panel beside row 1.
    box('Status panel',(.335,-.325,.933),(.085,.013,.063),green,.003)
    text('Status','100',(.335,-.334,.943),.019,white)
    box('Status lower label',(.335,-.334,.914),(.065,.002,.009),white,0)
    box('Vertical coin mounting',(.335,-.326,.823),(.045,.013,.073),steel,.005)
    cylinder('Coin entry round recess',(.335,-.335,.835),.015,.004,dark,(0,-1,0),20)
    box('Coin entry slot',(.335,-.338,.835),(.003,.002,.022),steel,0)
    # Advertising area on the left; payment hardware and instruction card on right.
    box('Red coffee advertisement',(-.225,-.324,.675),(.282,.012,.204),red,.004)
    text('Coffee advertising','COFFEE',(-.225,-.332,.690),.040,white)
    box('Advertisement rule',(-.225,-.333,.650),(.22,.002,.003),white,0)
    box('Banknote slot plate',(.080,-.327,.704),(.103,.014,.035),dark,.003)
    box('Banknote slot',(.080,-.336,.705),(.078,.002,.009),steel,0)
    box('Payment equipment plate',(.272,-.327,.662),(.196,.014,.071),dark,.003)
    box('Bill opening metal lip',(.225,-.338,.664),(.071,.009,.035),steel,.003)
    box('Bill opening',(.225,-.344,.668),(.057,.002,.013),dark,0)
    cylinder('Coin return knob rim',(.330,-.342,.677),.023,.014,steel,(0,-1,0),20)
    cylinder('Coin return knob',(.330,-.352,.677),.016,.012,dark,(0,-1,0),20)
    box('Return lever',(.317,-.361,.675),(.035,.008,.008),yellow,.002)
    box('Payment instruction card',(.272,-.326,.573),(.196,.003,.093),white,.002)
    for z in (.590,.573,.556):
        box('Instruction line',(.272,-.329,z),(.156,.001,.004),blue,0)
    # Wide low collection door, with a real recess and a separate angled flap.
    pocket_box('Pickup steel rim',(-.05,-.325,.34),(.626,.020,.19),steel,
               [((-.05,-.33,.34),(.585,.09,.149),.005)],.003)
    box('Pickup dark rear',(-.05,-.128,.34),(.597,.014,.16),dark,.003)
    flap=box('Pickup hinged flap',(-.05,-.285,.355),(.571,.013,.123),steel,.003)
    flap.rotation_euler.x=-.15
    box('Pickup sill',(-.05,-.232,.266),(.586,.18,.015),dark,.002)
    box('Pickup grip',(-.05,-.305,.314),(.116,.016,.015),dark,.004)
    # Small yellow coin-return pocket, and the low ventilation grille.
    pocket_box('Change return yellow surround',(.323,-.328,.212),(.080,.023,.067),yellow,
               [((.323,-.34,.217),(.057,.08,.043),.008)],.006)
    box('Change return dark back',(.323,-.325,.217),(.059,.004,.044),dark,.003)
    box('Lower ventilation inset',(-.04,-.323,.092),(.51,.008,.026),dark,.002)
    for i in range(26):
        box('Vent bar',(-.285+i*.0196,-.329,.092),(.005,.005,.022),blue,0)
    box('Bottom plinth',(0,.005,.025),(.785,.54,.05),dark,.005)
    h.ticket_anchor((-.255,-.320,.18))


def main():
    out=h.PROJECT.parent/'artifacts/japanese-vending-20261017'
    out.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    h.PARTS.clear()
    h.MARKERS.clear()
    build()
    row=h.export_asset('S059_vending_machine_jp')
    row['textures_embedded']=False
    (SOURCE/'build_manifest.json').write_text(json.dumps(row,indent=2),encoding='utf-8')
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'vending.blend'))
    print('JAPANESE_VENDING_OK '+json.dumps(row))


if __name__=='__main__':
    main()
