"""Photo-informed equipment props. Run only in an isolated Blender CLI process."""
from pathlib import Path
import importlib.util
import math
import json
import bpy
import bmesh
from mathutils import Vector

SOURCE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('gear_a_fresh_helpers', SOURCE.parents[1]/'fresh_props/source/build_assets.py')
f=importlib.util.module_from_spec(spec)
spec.loader.exec_module(f)
h=f.h
box,cylinder,material=h.box,h.cylinder,h.material
OUT=h.PROJECT.parent/'artifacts/rebuild-gear-a'

def palette():
    return dict(shell=material('Graphite molded housing','303A42',.40),
        dark=material('Recess and speaker cloth','111C24',.86),
        rubber=material('Molded rubber contact pads','20282D',.78),
        silver=material('Satin aluminum fittings','AAB6BD',.31,.80),
        gray=material('Soft grey velour cushions','656F74',.95),
        pale=material('Ivory control caps','D9DCD4',.38),
        red=material('Safety red control','C54B3C',.42),
        blue=material('LCD blue grey glass','3B6678',.20),
        green=material('LCD readable segments','99BBA9',.52),
        orange=material('Lens case warm padded lining','BD8050',.89),
        fabric=material('Woven charcoal case fabric','414B4D',.94))

def between(name,a,b,r,mat,vertices=16):
    a,b=Vector(a),Vector(b)
    return cylinder(name,(a+b)/2,r,(b-a).length,mat,b-a,vertices)

def ring(name,center,axis,radius,thickness,mat,steps=32):
    axis=Vector(axis).normalized()
    n=axis.cross(Vector((0,1,0)))
    if n.length < .01: n=axis.cross(Vector((1,0,0)))
    n.normalize(); b=axis.cross(n).normalized()
    return h.tube(name,[Vector(center)+radius*(math.cos(i*math.tau/steps)*n+math.sin(i*math.tau/steps)*b)
                    for i in range(steps)],thickness,mat,True,sides=6)

def knob(name,at,r,height,mat,axis=(0,0,1)):
    obj=cylinder(name,at,r,height,mat,axis,20)
    a=Vector(axis).normalized()
    center=Vector(at)+a*(height/2+.001)
    n=a.cross(Vector((0,1,0)))
    if n.length<.01: n=a.cross(Vector((1,0,0)))
    n.normalize()
    between(name+' index',center+n*r*.25,center+n*r*.76,.0013,M['pale'],8)
    return obj

def walkie():
    m=M
    # Sloped shoulders, separate battery pack, seam, and gasketed face insert.
    profile=[(-.056,.035),(.056,.035),(.061,.215),(.047,.251),(-.047,.251),(-.061,.215)]
    h.extruded_profile('Radio continuous tapered housing',profile,0,.071,m['shell'],.008)
    box('Removable rear battery pack',(0,.044,.124),(.112,.030,.195),m['rubber'],.008)
    box('Battery heel',(0,.009,.023),(.119,.090,.036),m['shell'],.006)
    box('Face panel gasket',(0,-.039,.139),(.100,.008,.177),m['dark'],.007)
    box('Face panel inset',(0,-.044,.14),(.090,.009,.168),m['shell'],.005)
    box('Speaker grille recess',(0,-.050,.094),(.075,.003,.071),m['dark'],.004)
    for i in range(7):
        box('Raised speaker grille bar',(0,-.054,.065+i*.009),(.073,.005,.004),m['shell'],.0015)
    box('LCD recess',(0,-.050,.188),(.076,.005,.043),m['dark'],.003)
    box('Green backlit LCD',(0,-.054,.188),(.063,.003,.028),m['green'],.002)
    for i in range(4):
        box('LCD signal bar',(-.022+i*.008,-.056,.183+i*.002),(.005,.001,.008+i*.004),m['dark'],.0005)
    for x in (-.028,0,.028):
        box('Rubber function key',(x,-.054,.145),(.019,.010,.013),m['rubber'],.003)
    for z in (.076,.106,.136,.166):
        box('Left grip rib',(-.062,0,z),(.009,.065,.010),m['rubber'],.003)
        box('Right grip rib',(.062,0,z),(.009,.065,.010),m['rubber'],.003)
    box('Side push to talk',(-.067,0,.205),(.016,.040,.047),m['rubber'],.004)
    box('PTT tactile center',(-.076,-.002,.205),(.003,.024,.022),m['red'],.001)
    knob('Volume knob',(.029,0,.266),.016,.031,m['rubber'])
    cylinder('Antenna threaded collar',(-.031,.004,.264),.013,.020,m['rubber'],vertices=20)
    ant=f.lathe('Tapered flexible antenna',[(0,.267),(.010,.267),(.009,.29),(.006,.409),(.005,.439),(0,.443)],m['rubber'],24)
    ant.location.x=-.031; ant.location.y=.004
    box('Belt clip upper mount',(0,.065,.216),(.040,.013,.029),m['shell'],.003)
    h.tube('Belt clip sprung loop',[(-.016,.066,.221),(-.016,.080,.205),(-.016,.082,.100),(-.016,.068,.087)],.006,m['shell'],sides=6)
    h.ticket_anchor((0,-.060,.123))

def band(name,rx,rz,base,depth,thick,mat,start=0,end=math.pi,steps=40):
    verts=[]
    for radial in (0,1):
        for y in (-depth/2,depth/2):
            for i in range(steps+1):
                a=start+(end-start)*i/steps
                verts.append(((rx-radial*thick)*math.cos(a),y,base+(rz-radial*thick)*math.sin(a)))
    n=steps+1; faces=[]
    for i in range(steps):
        faces.extend([(i,i+1,n+i+1,n+i),(2*n+i,3*n+i,3*n+i+1,2*n+i+1),
            (i,2*n+i,2*n+i+1,i+1),(n+i,n+i+1,3*n+i+1,3*n+i)])
    faces.extend([(0,n,3*n,2*n),(n-1,3*n-1,4*n-1,2*n-1)])
    return f.mesh(name,verts,faces,mat)

def oval_pad(name,x,cy,cz,ry,rz,radial,depth,mat):
    verts=[]; n=40; k=10
    for i in range(n):
        a=i*math.tau/n
        for j in range(k):
            b=j*math.tau/k
            verts.append((x+depth*math.cos(b),cy+(ry+radial*math.sin(b))*math.cos(a),cz+(rz+radial*math.sin(b))*math.sin(a)))
    faces=[]
    for i in range(n):
        for j in range(k):
            faces.append((i*k+j,((i+1)%n)*k+j,((i+1)%n)*k+(j+1)%k,i*k+(j+1)%k))
    return f.mesh(name,verts,faces,mat)

def cup(side,single=False):
    m=M; x=side*.112; z=.107
    h.ellipsoid('Molded closed earcup',(x,0,z),(.026,.052,.065),m['shell'],32,16)
    h.ellipsoid('Acoustic inner fabric',(x-side*.025,0,z),(.003,.037,.048),m['dark'],24,12)
    oval_pad('Deep oval ear cushion',x-side*.025,0,z,.040,.051,.010,.012,m['gray'] if not single else m['rubber'])
    # Two actual forks reach the front/back pivots and the band adjustment rail.
    for y in (-.043,.043):
        h.tube('Steel earcup yoke',[(side*.109,y,.121),(side*.140,y,.133),(side*.143,y*.72,.185),(side*.119,0,.201)],.0045,m['silver'],sides=8)
        cylinder('Earcup pivot pin',(side*.135,y,.124),.007,.011,m['dark'],(1,0,0),16)
    box('Sliding headband adjuster',(side*.117,0,.211),(.018,.036,.054),m['shell'],.003)
    h.ellipsoid('Earcup outer cap',(x+side*.022,0,z),(.005,.034,.043),m['dark'],24,12)

def headphones(single=False):
    m=M
    band('Continuous spring steel headband',.121,.141,.213,.028,.005,m['silver'])
    band('Thick padded headband cover',.127,.146,.213,.045,.015,m['rubber'],.36,math.pi-.36)
    band('Headband lower comfort lining',.114,.131,.213,.036,.006,m['gray'],.40,math.pi-.40)
    cup(-1,single)
    if not single: cup(1)
    else:
        box('Single ear temple pad support',(.119,0,.210),(.015,.027,.038),m['shell'],.003)
        h.ellipsoid('Single ear padded temple rest',(.104,0,.190),(.015,.031,.036),m['rubber'],20,12)
        cylinder('Mic boom pivot',(-.147,-.015,.104),.014,.014,m['shell'],(1,0,0),20)
        h.tube('Connected adjustable gooseneck mic',[(-.151,-.015,.104),(-.15,-.071,.088),(-.127,-.124,.079),(-.075,-.153,.083)],.004,m['shell'],sides=8)
        mic=h.ellipsoid('Foam mic windscreen',(-.059,-.157,.083),(.024,.012,.013),m['rubber'],24,12)
    h.tube('Connected short headphone lead',[(-.115,.010,.047),(-.12,.02,.018),(-.085,.065,.010),(-.014,.090,.012),(.028,.075,.018)],.0035,m['rubber'],sides=8)
    between('Cable connector',(.028,.075,.018),(.055,.068,.019),.005,m['shell'])
    between('Cable jack plug',(.055,.068,.019),(.069,.064,.019),.0024,m['silver'],12)
    h.ticket_anchor((-.145,-.014,.11))

def lens_case():
    m=M
    profile=[(0,.012),(.083,.012),(.099,.021),(.105,.047),(.106,.207),(.100,.237),(.090,.244),(.081,.240),(.082,.225),(.087,.209),(.086,.047),(.078,.035),(0,.035)]
    f.lathe('Padded cylindrical lens case shell',profile,m['fabric'],48)
    f.lathe('Visible soft orange case lining',[(.079,.040),(.085,.048),(.085,.218),(.081,.236),(.075,.234),(.077,.207),(.077,.047),(.079,.040)],m['orange'],48)
    for z in (.028,.229): ring('Rolled fabric piping',(0,0,z),(0,0,1),.100,.003,m['shell'],48)
    ring('Zipper dark channel',(0,0,.237),(0,0,1),.097,.003,m['dark'],48)
    for i in range(40):
        a=i*math.tau/40
        cylinder('Coarse zipper tooth',(.098*math.cos(a),.098*math.sin(a),.237),.0018,.004,m['silver'],vertices=6)
    for x in (-.038,.038):
        box('Sewn rear strap support',(x,.101,.136),(.020,.010,.160),m['shell'],.003)
    h.tube('Connected fabric carrying loop',[(-.038,.103,.18),(-.038,.127,.269),(.038,.127,.269),(.038,.103,.18)],.009,m['shell'],sides=8)
    # A hinged lid stands behind the lens, attached to the rear zipper opening.
    cylinder('Lid outer padded disk',(0,.107,.327),.099,.021,m['fabric'],(0,1,0),48)
    cylinder('Lid warm padded inner disk',(0,.093,.327),.086,.010,m['orange'],(0,1,0),48)
    ring('Lid bound rim',(0,.091,.327),(0,1,0),.096,.004,m['shell'],48)
    box('Fabric lid hinge',(0,.099,.246),(.062,.025,.029),m['shell'],.005)
    # Barrel, focus ring, stepped front bezel and recessed opaque optical glass.
    cylinder('Lens barrel inside case',(0,-.010,.189),.064,.123,m['shell'],vertices=40)
    for z,r in [(.225,.066),(.245,.064),(.266,.067),(.281,.066)]:
        cylinder('Layered lens barrel ring',(0,-.010,z),r,.010,m['dark'],vertices=40)
    for i in range(30):
        a=i*math.tau/30
        between('Lens focus ring grip rib',(.065*math.cos(a),-.010+.065*math.sin(a),.230),(.065*math.cos(a),-.010+.065*math.sin(a),.254),.0018,m['rubber'],6)
    cylinder('Lens front optical surround',(0,-.010,.285),.059,.007,m['shell'],vertices=40)
    cylinder('Recessed blue coated lens',(0,-.010,.289),.050,.002,m['blue'],vertices=48)
    ring('Inner lens optical ring',(0,-.010,.291),(0,0,1),.039,.0018,m['dark'],40)
    h.tube('Lens broad reflection arc',[(.032*math.cos(a),-.010+.032*math.sin(a),.293) for a in [0.30+i*.65/12 for i in range(13)]],.0014,m['green'],sides=6)
    h.ticket_anchor((0,-.109,.12))

def tripod():
    m=M
    cylinder('Three leg central hinge hub',(0,0,.222),.046,.090,m['shell'],vertices=32)
    for i in range(3):
        a=-math.pi/2+i*math.tau/3; radial=Vector((math.cos(a),math.sin(a),0)); tangent=Vector((-math.sin(a),math.cos(a),0))
        # Sculpted, tapered, flattened leg cross sections; all share the hub.
        centers=[radial*.024+Vector((0,0,.242)),radial*.065+Vector((0,0,.192)),radial*.164+Vector((0,0,.077)),radial*.238+Vector((0,0,.029))]
        widths=[.030,.032,.025,.020]; depths=[.016,.020,.016,.012]
        verts=[]; n=12
        for j,c in enumerate(centers):
            axis=(centers[min(j+1,3)]-centers[max(j-1,0)]).normalized()
            normal=axis.cross(tangent).normalized()
            for k in range(n):
                angle=k*math.tau/n
                verts.append(c+tangent*widths[j]*math.cos(angle)+normal*depths[j]*math.sin(angle))
        faces=[tuple(reversed(range(n))),tuple(range(3*n,4*n))]
        for j in range(3):
            for k in range(n): faces.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
        f.mesh('Tapered molded tripod leg',verts,faces,m['shell'])
        between('Leg hinge cross pin',radial*.043-tangent*.032+Vector((0,0,.231)),radial*.043+tangent*.032+Vector((0,0,.231)),.010,m['silver'],16)
        foot=radial*.239+Vector((0,0,.018))
        h.ellipsoid('Flattened rubber tripod foot',foot,(.029,.029,.018),m['rubber'],20,10)
        h.tube('Leg inset rubber grip',[centers[1]+Vector((0,0,.017)),centers[2]+Vector((0,0,.014)),centers[3]+Vector((0,0,.010))],.009,m['rubber'],sides=8)
    cylinder('Ball socket collar',(0,0,.278),.036,.037,m['rubber'],vertices=32)
    h.ellipsoid('Polished ball head',(0,0,.305),(.030,.030,.030),m['silver'],32,16)
    cylinder('Mounting neck',(0,0,.331),.016,.025,m['silver'],vertices=20)
    cylinder('Camera mounting platform',(0,0,.348),.049,.014,m['shell'],vertices=32)
    cylinder('Cork rubber camera pad',(0,0,.357),.043,.005,m['rubber'],vertices=32)
    cylinder('Camera mounting screw',(0,0,.367),.006,.017,m['silver'],vertices=16)
    cylinder('Ball lock red push button',(0,-.039,.28),.019,.017,m['red'],(0,-1,0),24)
    h.ticket_anchor((0,-.049,.235))

def recorder():
    m=M
    profile=[(-.061,.020),(.061,.020),(.066,.235),(.050,.278),(-.050,.278),(-.066,.235)]
    h.extruded_profile('Recorder tapered rubber sleeve',profile,0,.071,m['rubber'],.006)
    box('Recorder front control deck',(0,-.040,.151),(.111,.014,.234),m['shell'],.005)
    box('LCD protective surround',(0,-.050,.209),(.091,.010,.075),m['dark'],.004)
    box('Recorder backlit LCD',(0,-.057,.209),(.076,.003,.057),m['green'],.002)
    for z in (.192,.208):
        box('LCD meter track',(0,-.059,z),(.061,.001,.005),m['dark'],.0005)
    for x in (-.027,-.016,-.005,.006):
        box('LCD active meter segments',(x,-.060,.222),(.007,.001,.008),m['blue'],.0005)
    cylinder('Record key rim',(0,-.054,.147),.019,.007,m['silver'],(0,-1,0),24)
    cylinder('Large red record key',(0,-.060,.147),.015,.008,m['red'],(0,-1,0),24)
    for x in (-.034,0,.034):
        box('Recorder transport key',(x,-.053,.102),(.025,.012,.018),m['rubber'],.004)
    for x in (-.035,.035):
        for z in (.060,.078): box('Input selector key',(x,-.053,z),(.025,.011,.010),m['pale'],.002)
    box('Battery door',(0,.041,.135),(.101,.012,.173),m['shell'],.004)
    box('Rear battery latch',(0,.049,.211),(.033,.006,.015),m['rubber'],.002)
    for side in (-1,1):
        a=Vector((side*.028,0,.271)); axis=Vector((side*.72,0,.69)).normalized()
        between('XY microphone swivel stem',a,a+axis*.038,.011,m['shell'],20)
        center=a+axis*.058
        cylinder('XY microphone metal capsule',center,.018,.068,m['silver'],axis,24)
        for offset in (-.025,-.016,-.007,.002,.011,.020,.029):
            ring('Microphone grille dark opening',center+axis*offset,axis,.0184,.0016,m['dark'],24)
        # Longitudinal ribs tie grille rings into a real capsule envelope.
        normal=Vector((0,1,0)); other=axis.cross(normal)
        for i in range(6):
            radial=(normal*math.cos(i*math.tau/6)+other*math.sin(i*math.tau/6))*.0188
            between('Capsule grille support rib',center-axis*.030+radial,center+axis*.031+radial,.0011,m['silver'],6)
        cylinder('Bottom combo input rim',(side*.030,0,.013),.020,.015,m['silver'],vertices=24)
        cylinder('Bottom combo input socket',(side*.030,0,.005),.015,.003,m['dark'],vertices=24)
    knob('Side record gain wheel',(.068,0,.179),.017,.010,m['rubber'],(1,0,0))
    h.ticket_anchor((0,-.062,.162))

def mixer():
    m=M
    box('Rigid mixer lower chassis',(0,0,.050),(.414,.266,.076),m['shell'],.012)
    box('Recessed mixer top deck',(0,-.002,.090),(.382,.244,.012),m['silver'],.005)
    box('Dark mixer inset control fascia',(-.025,0,.098),(.314,.218,.006),m['dark'],.003)
    for side in (-1,1):
        h.tube('Connected protective mixer grab rail',[(side*.198,-.096,.068),(side*.228,-.096,.080),(side*.228,.096,.080),(side*.198,.096,.068)],.010,m['rubber'],sides=8)
        for y in (-.097,.097): box('Rubber chassis foot',(side*.149,y,.009),(.047,.041,.018),m['rubber'],.004)
    for j,x in enumerate((-.132,-.057,.018)):
        box('Channel vertical recessed strip',(x,0,.104),(.062,.195,.004),m['shell'],.002)
        for y,r in ((.071,.014),(.025,.011)):
            knob('Channel rotary gain', (x,y,.119),r,.023,m['pale'] if y>.05 else m['blue'])
        box('Fader travel slot',(x,-.050,.109),(.006,.071,.004),m['dark'],.001)
        y=-.070+j*.018
        box('Physical sliding fader cap',(x,y,.119),(.031,.018,.016),m['pale'],.003)
        box('Fader cap center index',(x,y,.129),(.022,.003,.002),m['dark'],.0005)
        for yy in (-.082,-.049,-.016):
            box('Fader scale tick',(x+.019,yy,.108),(.008,.002,.0015),m['pale'],.0003)
        box('Channel mute button',(x,.096,.109),(.019,.010,.008),m['red'],.002)
    box('Twin level meter surround',(.102,.031,.106),(.056,.132,.010),m['rubber'],.004)
    for x in (.089,.112):
        for i in range(8):
            box('Visible meter segment',(x,-.021+i*.014,.113),(.012,.008,.003),m['green'] if i<6 else m['red'],.001)
    knob('Master monitor knob',(.104,-.079,.123),.024,.029,m['shell'])
    for x in (-.129,-.045,.039):
        cylinder('Front XLR metal flange',(x,-.139,.050),.025,.011,m['silver'],(0,-1,0),24)
        cylinder('Front XLR inset socket',(x,-.146,.050),.019,.005,m['dark'],(0,-1,0),24)
        for dx,dz in [(-.007,-.005),(.007,-.005),(0,.007)]:
            cylinder('XLR visible pin',(x+dx,-.151,.050+dz),.0022,.005,m['silver'],(0,-1,0),8)
    for x in (.115,.158):
        cylinder('Headphone and line jack rim',(x,.139,.048),.013,.009,m['silver'],(0,1,0),20)
        cylinder('Headphone jack aperture',(x,.145,.048),.007,.005,m['dark'],(0,1,0),16)
    box('Rear DC power switch',(-.129,.140,.052),(.043,.011,.026),m['rubber'],.003)
    h.ticket_anchor((0,-.157,.064))

def monitor():
    m=M
    box('Monitor rear aluminum housing',(0,.008,.226),(.463,.051,.285),m['shell'],.012)
    box('Display continuous front bezel',(0,-.024,.226),(.468,.020,.287),m['rubber'],.009)
    box('Recessed screen dark border',(0,-.037,.237),(.420,.004,.239),m['dark'],.003)
    box('Monitor blue black screen',(0,-.041,.239),(.396,.003,.220),m['blue'],.002)
    # A restrained graphic reflection keeps the dark panel readable at distance.
    f.mesh('Broad screen reflected light',[(-.194,-.043,.345),(.195,-.043,.345),(.195,-.043,.327),(-.194,-.043,.302)],[(0,1,2,3)],material('Screen soft reflection','507D8D',.26),False)
    for sx in (-1,1):
        for sz in (-1,1):
            x=sx*.166; z=.239+sz*.084
            h.tube('Screen framing corner',[(x-sx*.020,-.044,z),(x,-.044,z),(x,-.044,z-sz*.014)],.0012,m['green'],sides=6)
    for x in (-.101,-.053,-.005,.043):
        box('Bottom bezel navigation button',(x,-.039,.100),(.024,.008,.009),m['shell'],.002)
    cylinder('Monitor menu joystick',(.140,-.041,.101),.008,.010,m['pale'],(0,-1,0),16)
    h.ellipsoid('Power status indicator',(.184,-.041,.100),(.003,.002,.003),m['green'],12,6)
    # Two supported battery sleds and the connectors are modeled on the back.
    for x in (-.116,.116):
        box('Rear battery sled',(x,.044,.235),(.111,.027,.181),m['dark'],.006)
        for dx in (-.046,.046): box('Battery rail',(x+dx,.064,.236),(.010,.018,.164),m['shell'],.002)
        box('Camera battery block',(x,.077,.234),(.083,.047,.130),m['rubber'],.006)
        box('Battery release catch',(x,.074,.319),(.036,.018,.018),m['shell'],.003)
    box('Rear connector mounting strip',(0,.044,.228),(.077,.020,.187),m['silver'],.004)
    for z in (.174,.215):
        cylinder('Rear BNC connector barrel',(0,.062,z),.011,.018,m['silver'],(0,1,0),20)
        cylinder('BNC open center',(0,.073,z),.006,.005,m['dark'],(0,1,0),16)
    box('HDMI port outer',(0,.059,.267),(.030,.010,.017),m['dark'],.002)
    box('HDMI port inner',(0,.065,.267),(.021,.003,.008),m['silver'],.001)
    for side in (-1,1):
        cylinder('Yoke tilt pivot',(side*.241,.012,.213),.022,.030,m['shell'],(1,0,0),24)
        knob('Yoke tilt locking knob',(side*.259,.012,.213),.017,.015,m['rubber'],(side,0,0))
        # Solid side cheeks connect pivots to the low supporting bridge.
        h.tube('Monitor U bracket side',[(side*.251,.012,.213),(side*.251,.012,.062),(side*.218,.012,.040)],.009,m['silver'],sides=8)
    between('Monitor U bracket base',(-.218,.012,.040),(.218,.012,.040),.009,m['silver'])
    box('Monitor stand foot',(0,.018,.018),(.261,.177,.027),m['rubber'],.008)
    box('Stand neck',(0,.012,.041),(.061,.048,.036),m['shell'],.004)
    h.ticket_anchor((0,-.048,.101))

SPECS=[
 ('scrap_walkie_talkie','P053_walkie_talkie',.45,.4,walkie),
 ('scrap_headset','P054_headset',.4,.3,lambda:headphones(True)),
 ('scrap_headphones','P055_headphones',.45,.4,headphones),
 ('scrap_lens_case','P058_lens_case',.45,.5,lens_case),
 ('scrap_tabletop_tripod','P059_tabletop_tripod',.55,.6,tripod),
 ('scrap_audio_recorder','P060_audio_recorder',.4,.4,recorder),
 ('scrap_field_mixer','P061_field_mixer',.55,.8,mixer),
 ('scrap_portable_monitor','P062_portable_monitor',.55,.8,monitor)]

def main():
    global M
    OUT.mkdir(parents=True,exist_ok=True)
    rows=[]; replacements=[]
    for kind,original,size,mass,build in SPECS:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        h.PARTS.clear(); h.MARKERS.clear()
        M=palette(); build()
        # Collapse the repeated poles of turned parts before triangulation/export.
        for obj in h.PARTS:
            bm=bmesh.new(); bm.from_mesh(obj.data)
            bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
            bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-9)
            bm.to_mesh(obj.data); bm.free(); obj.data.update()
        row=h.export_asset(original+'_rebuilt')
        row.update(kind=kind,original_file=original,target_normalization_size=size,target_mass=mass,
            textures_embedded=False,finite_geometry=True,export_y_up=True,front_godot='+Z')
        rows.append(row)
        replacements.append(dict(kind=kind,original_file=original,file=original+'_rebuilt'))
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(original+'.blend')))
    (SOURCE/'build_manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    (SOURCE/'replacements.json').write_text(json.dumps(replacements,indent=2),encoding='utf-8')
    print('GEAR_A_BUILD_OK '+json.dumps(rows))

if __name__=='__main__': main()
