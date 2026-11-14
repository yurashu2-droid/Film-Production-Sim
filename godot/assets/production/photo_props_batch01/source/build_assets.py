"""Three photo-informed props, retaining game sizes and material batching."""
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


def ring(name,radius,y,z,thickness,mat,steps=48):
    h.tube(name,[(radius*math.cos(i*math.tau/steps),y,z+radius*math.sin(i*math.tau/steps))
                 for i in range(steps)],thickness,mat,True,sides=6)


def fan():
    orange=material('Fan orange powder coat','D86A25',.45)
    black=material('Fan dark steel stand and guard','293034',.5)
    steel=material('Fan aluminum impeller','9AA6AD',.35,.85)
    rubber=material('Fan rubber feet','191F21',.88)
    # Axis is Blender Y / Godot Z; proportions retain the existing collider table.
    shell=f.lathe('Open rolled steel drum',[(.438,-.14),(.450,-.14),(.450,.12),
                  (.438,.12),(.438,-.14)],orange,64)
    shell.rotation_euler.x=math.pi/2
    shell.location=(0,-.026,.751)
    for y in (-.154,.114):
        ring('Rolled drum edge',.448,y,.751,.008,orange)
    for angle in [i*math.tau/4 for i in range(4)]:
        pts=[(.045,.08),(.13,.09),(.235,.21),(.205,.365),
             (.11,.405),(-.01,.35),(-.035,.22)]
        blade=h.extruded_profile('Swept impeller blade',pts,-.035,.013,steel,.007)
        blade.rotation_euler.y=angle
        blade.location.z=.751
    cylinder('Motor rear housing',(0,.10,.751),.11,.22,black,(0,1,0),32)
    cylinder('Blade central hub',(0,-.075,.751),.085,.075,steel,(0,1,0),32)
    for rear in (False,True):
        for r in (.115,.195,.275,.355,.438):
            y=.135 if rear else -.182-.022*(1-r/.45)
            ring('Rear grille ring' if rear else 'Front grille ring',r,y,.751,.0027,black,48)
        for i in range(12):
            a=i*math.tau/12
            y=.135 if rear else -.184
            h.tube('Grille radial spoke',[(.075*math.cos(a),y,.751+.075*math.sin(a)),
                   (.438*math.cos(a),y,.751+.438*math.sin(a))],.003,black,sides=6)
    cylinder('Front hub cap',(0,-.201,.751),.082,.020,black,(0,-1,0),32)
    for side in (-1,1):
        # A stable front/back U frame, with the feet kept inside the old footprint.
        x=side*.313
        h.tube('Stand side loop',[(side*.436,-.026,.751),(x,-.22,.09),
               (x,-.22,.035),(x,-.17,.025),(x,.20,.025),
               (x,.245,.065),(side*.436,-.026,.751)],.016,black,sides=8)
        cylinder('Tilt pivot',(side*.445,-.026,.751),.034,.045,black,(1,0,0),20)
        for y in (-.19,.20):
            box('Stand rubber pad',(x,y,.015),(.062,.075,.030),rubber,.007)
    h.tube('Stand cross rail',[(-.313,.20,.025),(.313,.20,.025)],.016,black,sides=8)
    box('Rear control switch',(0,.226,.77),(.083,.045,.069),black,.007)
    box('Control rocker',(0,.253,.78),(.029,.008,.024),orange,.003)
    h.ticket_anchor((0,-.213,.751))


def tub():
    enamel=material('Tub white acrylic enamel','ECEBE2',.22)
    chrome=material('Tub chrome claw feet and drain','B6BFC5',.26,.92)
    dark=material('Tub drain recess','293238',.65)
    # Outer bowl, rolled lip and inner bowl are one continuous surface.
    profile=[(.0,.0,.16),(.30,.13,.16),(.38,.18,.18),(.47,.225,.24),
             (.55,.275,.35),(.59,.30,.44),(.62,.315,.515),
             (.641,.329,.538),(.649,.331,.550),(.642,.323,.562),
             (.626,.303,.558),(.610,.289,.543),(.589,.277,.505),
             (.556,.258,.425),(.50,.225,.32),(.42,.18,.245),
             (.31,.125,.212),(.20,.075,.205),(0,0,.205)]
    count=72
    verts=[]
    for rx,ry,z in profile:
        for i in range(count):
            a=i*math.tau/count
            # Raised ends create a restrained double-slipper silhouette.
            rise=.012*(math.cos(a)**4)*max(0,(z-.3)/.26)
            verts.append((rx*math.cos(a),ry*math.sin(a),z+rise))
    faces=[]
    for j in range(len(profile)-1):
        for i in range(count):
            a=j*count+i
            b=j*count+(i+1)%count
            faces.append((a,b,b+count,a+count))
    f.mesh('Continuous hollow bathtub',verts,faces,enamel)
    for sx in (-1,1):
        for sy in (-1,1):
            # A visible haunch, curved ankle and three toes read as a claw foot.
            h.ellipsoid('Claw foot haunch',(sx*.37,sy*.145,.18),(.045,.034,.052),chrome,20,10)
            h.tube('Curved cast ankle',[(sx*.34,sy*.125,.22),(sx*.38,sy*.15,.16),
                   (sx*.415,sy*.18,.08),(sx*.45,sy*.20,.037)],.024,chrome,sides=8)
            h.ellipsoid('Claw pad',(sx*.45,sy*.20,.027),(.041,.033,.025),chrome,20,10)
            for offset in (-.022,0,.022):
                h.ellipsoid('Claw toe',(sx*.45+offset,sy*.22,.018),(.012,.025,.018),chrome,12,6)
    cylinder('Drain flange',(-.25,0,.211),.026,.005,chrome,vertices=32)
    cylinder('Drain dark center',(-.25,0,.215),.015,.003,dark,vertices=24)
    for dx in (-.009,0,.009):
        box('Drain strainer',(-.25+dx,0,.217),(.002,.026,.002),chrome,.0005)
    h.ticket_anchor((0,-.285,.38))


def glass_material():
    mat=material('Booth clear slightly green glass','B4CEC7',.14)
    mat.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=.12
    mat.surface_render_method='DITHERED'
    mat.use_backface_culling=False
    return mat


def pane(name,points,mat):
    f.mesh(name,points,[(0,1,2,3)],mat,False)


def phone():
    metal=material('Booth satin aluminum','B3BEC2',.38,.8)
    green=material('Booth green roof and payphone','318565',.42)
    dark=material('Booth seals and phone hardware','253635',.72)
    glass=glass_material()
    white=material('Booth phone labels','E6E9DC',.65)
    floor=material('Booth floor','606C69',.8)
    box('Threshold plinth',(0,0,.045),(.72,.66,.09),floor,.006)
    box('Interior floor',(0,0,.096),(.65,.59,.012),metal,.002)
    for x in (-.33,.33):
        for y in (-.30,.30):
            box('Structural aluminum post',(x,y,.81),(.035,.035,1.44),metal,.002)
    box('Green roof fascia',(0,0,1.55),(.76,.70,.10),green,.007)
    box('Roof underside',(0,0,1.493),(.68,.62,.014),white,.002)
    for y in (-.30,.30):
        for z in (.125,1.47):
            box('Front rear horizontal frame',(0,y,z),(.65,.026,.031),metal,.002)
    for x in (-.33,.33):
        for z in (.125,.76,1.47):
            box('Side horizontal frame',(x,0,z),(.026,.60,.025),metal,.002)
    pane('Front door glass',[(-.31,-.30,.145),(.31,-.30,.145),(.31,-.30,1.451),(-.31,-.30,1.451)],glass)
    pane('Rear glass',[(-.31,.30,.145),(.31,.30,.145),(.31,.30,1.451),(-.31,.30,1.451)],glass)
    for x in (-.33,.33):
        pane('Side glass',[(x,-.28,.145),(x,.28,.145),(x,.28,1.451),(x,-.28,1.451)],glass)
    # Door frame, push/pull handle and hinge barrels.
    for x in (-.30,.30):
        box('Door seal',(x,-.318,.80),(.009,.008,1.31),dark,.001)
    h.tube('Door pull handle',[(.255,-.326,.70),(.255,-.355,.73),
           (.255,-.355,.88),(.255,-.326,.91)],.009,metal,sides=8)
    for z in (.35,1.25):
        cylinder('Door hinge',(-.319,-.315,z),.009,.065,metal,vertices=16)
    # The payphone is a modeled interior object rather than an opaque wall decal.
    box('Phone pedestal',(-.07,.20,.47),(.11,.13,.72),metal,.005)
    box('Payphone cabinet',(-.065,.18,.96),(.235,.16,.35),green,.014)
    box('Phone upper display',(-.02,.094,1.055),(.117,.008,.047),dark,.004)
    box('Phone LCD',(-.02,.088,1.055),(.096,.003,.029),white,.002)
    box('Phone keypad panel',(-.02,.094,.98),(.118,.012,.094),dark,.004)
    for row in range(4):
        for col in range(3):
            box('Keypad button',(-.055+col*.035,.085,1.01-row*.020),(.024,.009,.013),white,.002)
    box('Coin slot surround',(.02,.094,1.108),(.046,.008,.022),metal,.002)
    box('Coin slot',(.02,.088,1.108),(.023,.002,.004),dark,0)
    box('Coin return panel',(-.02,.094,.85),(.11,.008,.049),dark,.003)
    box('Coin return mouth',(-.02,.088,.852),(.078,.004,.019),metal,.002)
    h.tube('Green handset',[(-.165,.055,1.10),(-.19,.040,1.075),
           (-.19,.040,.97),(-.165,.055,.94)],.015,green,sides=10)
    for z in (.949,1.091):
        h.ellipsoid('Handset receiver',(-.17,.052,z),(.024,.022,.025),green,20,10)
    cord=[(-.18+.006*math.cos(i*math.tau/6),.075+.006*math.sin(i*math.tau/6),.925-i*.003)
          for i in range(43)]
    h.tube('Coiled handset cord',cord,.0025,dark,sides=6)
    h.tube('Cord return',[cord[-1],(-.12,.07,.77),(-.10,.094,.83)],.0025,dark,sides=6)
    box('Small writing shelf',(-.07,.08,.63),(.32,.27,.020),metal,.005)
    box('Shelf information sheet',(-.07,.025,.643),(.23,.15,.002),white,.001)
    h.ticket_anchor((0,-.332,.0475))


def main():
    out=h.PROJECT.parent/'artifacts/photo-props-batch01-20261017'
    out.mkdir(parents=True,exist_ok=True)
    rows=[]
    for name,filename,build in [('fan','S079_large_wind_fan_photo',fan),
                                ('tub','S040_clawfoot_tub_photo',tub),
                                ('phone','S058_phone_booth_photo',phone)]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        h.PARTS.clear()
        h.MARKERS.clear()
        build()
        row=h.export_asset(filename)
        row['textures_embedded']=False
        rows.append(row)
        bpy.ops.wm.save_as_mainfile(filepath=str(out/(name+'.blend')))
    (SOURCE/'build_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    print('PHOTO_PROPS_OK '+json.dumps(rows))


if __name__=='__main__':
    main()
