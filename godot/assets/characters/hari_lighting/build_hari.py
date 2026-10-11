"""Reference-driven HARI lighting crew study. Metres, Y up, +Z forward.

Editable section curves / hair controls / joint angles; no downloaded meshes.
Uses the previous study's checked GLB writer and the installed hair skill's
closed clump builder (vendored alongside this file for reproducibility).
"""
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent/'cardboard_stunt'))
from build_model import Model, ellipsoid, bevelbox, add, sub, mul, cross, unit, quat
from clump_mesh import make_clump


class HariModel(Model):
    def save(self):
        self.doc['asset']['generator'] = 'HARI / reference-driven character skill study'
        self.doc['buffers'] = [dict(byteLength=len(self.bin))]
        encoded=json.dumps(self.doc,separators=(',',':')).encode()
        encoded+=b' '*((-len(encoded))%4)
        self.bin+=b'\0'*((-len(self.bin))%4)
        output=struct.pack('<III',0x46546c67,2,28+len(encoded)+len(self.bin))
        output+=struct.pack('<II',len(encoded),0x4e4f534a)+encoded
        output+=struct.pack('<II',len(self.bin),0x004e4942)+self.bin
        (HERE/'hari_lighting.glb').write_bytes(output)
        summary=dict(meshes=len(self.stats),triangles=sum(s['triangles'] for s in self.stats),
                     render_vertices=sum(s['render_vertices'] for s in self.stats),
                     materials=len(self.doc['materials']),animation_seconds=4,method='rigid node articulation',
                     reference_sha256=hashlib.sha256((HERE/'reference/design.png').read_bytes()).hexdigest(),
                     control_sha256=hashlib.sha256((HERE/'controls.json').read_bytes()).hexdigest(),
                     units='metres',up='+Y',front='+Z',parts=self.stats)
        assert summary['triangles']<24000
        assert all(s['nonmanifold_edges']==0 for s in self.stats)
        assert all(s['boundary_edges']==0 for s in self.stats if not s['name'].startswith(('Lens','Crew_patch')))
        (HERE/'geometry_report.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
        print(json.dumps({k:v for k,v in summary.items() if k!='parts'}))


def section_mesh(sections, sectors=24, phase=0):
    """Closed rounded garment/limb surface: (y, xradius, zradius, xoffset, zoffset).
    Authored compression varies with height; no random noise or cloth simulation.
    """
    verts=[]
    for y,rx,rz,x,z in sections:
        for i in range(sectors):
            t=math.tau*i/sectors+phase
            verts.append((x+rx*math.cos(t),y,z+rz*math.sin(t)))
    faces=[list(reversed(range(sectors)))]
    for j in range(len(sections)-1):
        for i in range(sectors):
            a=j*sectors+i;b=j*sectors+(i+1)%sectors
            faces.append([a,b,b+sectors,a+sectors])
    faces.append(list(range((len(sections)-1)*sectors,len(sections)*sectors)))
    return verts,faces


def tube(points, radius=.006, sides=8, closed=False):
    verts=[]; prior=(0,0,1)
    for i,p in enumerate(points):
        a=points[(i-1)%len(points)] if closed or i>0 else p
        b=points[(i+1)%len(points)] if closed or i<len(points)-1 else p
        tangent=unit(sub(b,a))
        projected=sub(prior,mul(tangent,sum(x*y for x,y in zip(prior,tangent))))
        if sum(x*x for x in projected)<1e-10:
            candidate=min([(1,0,0),(0,1,0),(0,0,1)],key=lambda a:abs(sum(x*y for x,y in zip(a,tangent))))
            projected=sub(candidate,mul(tangent,sum(x*y for x,y in zip(candidate,tangent))))
        n=unit(projected); side=unit(cross(tangent,n));prior=n
        for k in range(sides):
            t=math.tau*k/sides
            verts.append(add(p,add(mul(n,radius*math.cos(t)),mul(side,radius*math.sin(t)))))
    faces=[]
    for i in range(len(points) if closed else len(points)-1):
        j=(i+1)%len(points)
        for k in range(sides):
            faces.append([i*sides+k,i*sides+(k+1)%sides,j*sides+(k+1)%sides,j*sides+k])
    if not closed:
        faces.extend([list(reversed(range(sides))),list(range((len(points)-1)*sides,len(points)*sides))])
    return verts,faces


def ring(radius,thickness,center=(0,0,0),segments=40,oval=(1,1),depth=0):
    pts=[]
    for i in range(segments):
        t=math.tau*i/segments
        pts.append(add(center,(radius*oval[0]*math.cos(t),radius*oval[1]*math.sin(t),depth*math.cos(t))))
    return tube(pts,thickness,8,True)


def main():
    controls=json.loads((HERE/'controls.json').read_text())
    model=HariModel()
    skin=model.mat('Warm ochre skin',(.71,.46,.30),.83)
    blush=model.mat('Muted cheek warmth',(.71,.37,.27),.85)
    ink=model.mat('Eyes / charcoal rubber',(.055,.066,.073),.83)
    iris=model.mat('Brown iris',(.18,.095,.047),.74)
    white=model.mat('Eye white / cotton shirt',(.9,.86,.73),.94)
    hair=model.mat('Midnight navy hair',(.075,.088,.14),.66)
    crest=model.mat('Quiet navy hair crest',(.10,.125,.20),.65)
    yellow=model.mat('Mustard cotton jacket',(.73,.49,.16),.95)
    lining=model.mat('Cuff facing',(.81,.60,.26),.96)
    pants=model.mat('Moss green canvas trousers',(.29,.33,.22),.98)
    seam=model.mat('Recessed fabric seams',(.31,.28,.14),.96)
    leather=model.mat('Leather belt and pouch',(.23,.155,.11),.84)
    boot=model.mat('Burgundy rubber boots',(.32,.13,.14),.72)
    frame=model.mat('Rust acetate spectacles',(.33,.12,.075),.53)
    metal=model.mat('Bare steel hardware',(.39,.43,.43),.36,1)
    lamp=model.mat('Painted lamp housing',(.10,.13,.14),.69)
    glass=model.mat('Graphic clear lenses',(.93,.97,.99),.13)
    model.doc['materials'][glass].update(alphaMode='BLEND',doubleSided=True)
    model.doc['materials'][glass]['pbrMetallicRoughness']['baseColorFactor'][3]=.045
    diffuser=model.mat('Warm work lamp diffuser',(.94,.82,.51),.49)
    model.doc['materials'][diffuser]['emissiveFactor']=[.38,.27,.11]
    badge=model.mat('Cotton crew patch',(.92,.89,.79),.94)
    patch=Image.new('RGB',(256,256),(231,224,204)); draw=ImageDraw.Draw(patch)
    font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',180)
    draw.text((128,115),'02',fill=(38,48,64),anchor='mm',font=font)
    draw.rounded_rectangle((7,7,248,248),radius=22,outline=(180,167,135),width=7)
    image=io.BytesIO(); patch.save(image,format='PNG')
    model.doc['images']=[dict(bufferView=model.view(image.getvalue()),mimeType='image/png')]
    model.doc['textures']=[dict(source=0)]
    model.doc['materials'][badge]['pbrMetallicRoughness'].update(baseColorFactor=[1,1,1,1],baseColorTexture=dict(index=0))

    root=model.node('HariLightingCrew')
    chest=model.node('ChestPivot',root,(0,.67,0))
    yaw=model.node('HeadPivot',chest,(0,.39,0))
    head=model.node('HeadNod',yaw)
    model.doc['nodes'][root]['extras']=dict(authoritative='reference/design.png left hero',
        inferred='rear construction uses generated auxiliary views; not calibrated turnarounds',
        proportions='adult stylized crew member; approx 1.7m tall; larger head than realism')

    def mesh(name,geometry,mat,parent,pos=(0,0,0),smooth=True,rotation=None):
        v,f=geometry
        return model.mesh(name,v,[list(x) for x in f],mat,parent,pos,smooth,rotation=rotation)
    def box(name,size,mat,parent,pos=(0,0,0),rotation=None,smooth=False):
        return mesh(name,bevelbox(size,.025),mat,parent,pos,smooth,rotation)
    def ball(name,size,mat,parent,pos=(0,0,0),sectors=24,rings=12):
        return mesh(name,ellipsoid(size,sectors,rings),mat,parent,pos)
    def path(name,pts,radius,mat,parent,sides=8,closed=False):
        return mesh(name,tube(pts,radius,sides,closed),mat,parent)

    # Full skull remains intact behind hair. Taper lower jaw, keep cheek depth.
    vertices,faces=ellipsoid((.30,.305,.254),32,18)
    vertices=[(x*(1-.13*max(0,-y/.305)),y,z+.018+
        .013*math.exp(-((abs(x)-.152)/.080)**2-((y+.095)/.075)**2)*max(0,z/.254)) for x,y,z in vertices]
    mesh('Face_skull',(vertices,faces),skin,head,(0,.28,0))
    ball('Neck',(.072,.102,.075),skin,head,(0,-.03,0),16,8)
    for s,label in [(-1,'Right'),(1,'Left')]:
        eye_x=s*controls['eye_spacing']
        eye_y=controls['eye_y']
        ball('Ear_'+label,(.050,.073,.044),skin,head,(s*.293,.265,.01),16,10)
        ball('Inner_ear_'+label,(.015,.040,.023),blush,head,(s*.331,.266,.026),12,8)
        ball('Eye_white_'+label,(.074,.083,.039),white,head,(eye_x,eye_y,.236))
        ball('Iris_'+label,(.035,.051,.013),iris,head,(eye_x+.009,eye_y+.003,.273),20,12)
        ball('Pupil_'+label,(.021,.034,.008),ink,head,(eye_x+.009,eye_y+.003,.283),16,10)
        ball('Eye_glint_'+label,(.010,.014,.006),white,head,(eye_x+.001,eye_y+.023,.289),12,8)
        brow=[(s*.068,.422,.249),(s*.12,.441,.259),(s*.176,.431,.232)]
        path('Brow_'+label,brow,.012,hair,head)
        center=(eye_x,eye_y+.008,controls['glasses_z'])
        mesh('Glasses_rim_'+label,ring(controls['glasses_radius'],.0085,center,oval=(1,.98)),frame,head)
        # Subtle graphic transparency; no claim of physical transmission.
        r=controls['glasses_radius']-.009
        lens=[center]+[add(center,(r*math.cos(math.tau*i/40),r*.98*math.sin(math.tau*i/40),.001)) for i in range(40)]
        faces=[[0,1+i,1+(i+1)%40] for i in range(40)]
        mesh('Lens_'+label,(lens,faces),glass,head,smooth=False)
        path('Glasses_arm_'+label,[(eye_x+s*controls['glasses_radius'],eye_y+.013,controls['glasses_z']),
            (s*.287,eye_y+.015,.184),(s*.314,eye_y+.006,.060),(s*.306,.278,.007)],.0065,frame,head)
        path('Upper_lid_'+label,[(eye_x-.057,eye_y+.038,.266),(eye_x-.015,eye_y+.072,.269),
            (eye_x+.033,eye_y+.070,.268),(eye_x+.065,eye_y+.040,.255)],.0048,hair,head)
    path('Glasses_bridge',[(-.035,controls['eye_y']+.018,controls['glasses_z']),
        (0,controls['eye_y']+.031,controls['glasses_z']+.007),(.035,controls['eye_y']+.018,controls['glasses_z'])],.0065,frame,head)
    ball('Nose',(.038,.039,.055),skin,head,(0,.242,.259),20,12)
    smile=[(-.060,.160,.230),(-.028,.150,.243),(.012,.151,.246),(.054,.164,.235),(.070,.177,.224)]
    path('Soft_smile',smile,.0042,leather,head)
    ball('Lower_lip',(.043,.014,.013),blush,head,(.004,.142,.233),16,8)

    # Bob envelope: scalp-following upper crown, wider temples, curved tucked nape.
    n=40; rows=13; vertices=[(.03,.618,.0)]
    for j in range(1,rows+1):
        for i in range(n):
            t=math.tau*i/n
            front=max(0,math.sin(t))
            end=2.17-1.15*front
            phi=end*j/rows
            widen=1+.055*math.sin(phi)
            vertices.append((.322*math.sin(phi)*math.cos(t)*widen,
                             .28+.337*math.cos(phi),.018+.292*math.sin(phi)*math.sin(t)))
    faces=[[0,1+(i+1)%n,1+i] for i in range(n)]
    for j in range(rows-1):
        for i in range(n):
            a=1+j*n+i;b=1+j*n+(i+1)%n
            faces.append([a,b,b+n,a+n])
    faces.append(list(reversed(range(1+(rows-1)*n,1+rows*n))))
    mesh('Bob_recessed_coverage',(vertices,faces),hair,head)
    locks=[
        ('Fringe_major',[(.17,.54,.15),(.12,.575,.205),(-.10,.54,.29),(-.24,.42,.28),(-.322,.25,.18)],
         [.045,.072,.085,.065,.033],[.024,.030,.033,.026,.018],(0,0,1)),
        ('Fringe_lower',[(.20,.53,.12),(.10,.55,.255),(-.04,.49,.301),(-.19,.41,.28),(-.29,.278,.204)],
         [.042,.066,.066,.045,.025],[.023,.030,.029,.022,.014],(0,0,1)),
        ('Part_short',[(.19,.575,.045),(.29,.50,.132),(.336,.36,.136),(.34,.20,.084),(.29,.12,.055)],
         [.072,.078,.081,.062,.029],[.030,.040,.038,.028,.020],(1,0,.3)),
        ('Temple_left',[(-.20,.50,.13),(-.326,.40,.135),(-.346,.24,.12),(-.315,.105,.062),(-.264,.058,-.005)],
         [.067,.087,.081,.070,.029],[.024,.034,.035,.026,.017],(-1,0,.3)),
        ('Temple_right',[(.21,.48,-.02),(.329,.38,-.022),(.343,.24,-.040),(.313,.115,-.076),(.264,.059,-.102)],
         [.085,.1,.095,.071,.029],[.023,.031,.032,.024,.018],(1,0,0))]
    nape=[(-.26,-.14,-.18,.074,.052),(-.132,-.072,-.11,.107,.025),
          (.01,.036,-.028,.10,.042),(.16,.145,.085,.088,.068),(.276,.19,.19,.064,.090)]
    def skull_back(x,y):
        return .015-.308*math.sqrt(max(.03,1-(x/.355)**2-((y-.28)/.365)**2))
    for i,(x,rootx,tipx,width,end_y) in enumerate(nape):
        locks.append(('Nape_'+str(i),[(rootx,.52-abs(x)*.10,-.09),
            (x*.91,.427,skull_back(x*.91,.427)),(x,.255+i*.007,skull_back(x,.255+i*.007)),
            (x*.93,.13,skull_back(x*.93,.13)),(tipx,end_y,skull_back(tipx,end_y))],
            [.030,width*.86,width*.83,width*.60,.025],[.018,.027,.025,.020,.016],(x*.9,0,-1)))
    for i,(name,points,widths,depths,outward) in enumerate(locks):
        if name.startswith('Fringe'):
            points=[(x,y+controls['fringe_lift'],z) for x,y,z in points]
        v,f=make_clump(points,widths,depths,rings=14,outward=outward,ridge=.08)
        node=mesh(name,(v,f),crest if i==0 else hair,head)
        model.doc['nodes'][node]['extras']=dict(root='scalp',group=name.split('_')[0],role='broad parent lock',
            protected='eye and spectacle clearance',termination='blunt tapered bob')

    # Cropped tailored jacket: supported body, quiet authored large folds.
    section=[(0,.225,.144,0,0),(.025,.232,.149,0,0),(.085,.237,.149,0,.0),
             (.17,.243,.147,0,-.003),(.265,.25,.143,0,-.006),(.335,.248,.133,0,-.008),
             (.383,.197,.114,0,-.003),(.398,.155,.099,0,0)]
    mesh('Jacket_body',section_mesh(section),yellow,chest)
    # Cotton shirt and separated zipper borders sit on actual jacket front depth.
    box('Cotton_shirt',(.106,.308,.015),white,chest,(0,.187,.153),smooth=True)
    for s,label in [(-1,'Right'),(1,'Left')]:
        path('Zipper_border_'+label,[(s*.059,.018,.154),(s*.061,.11,.161),
            (s*.061,.25,.148),(s*.071,.345,.126)],.0036,metal,chest)
        box('Hem_band_'+label,(.168,.028,.024),lining,chest,(s*.143,.020,.121),smooth=True)
        box('Chest_pocket_'+label,(.112,.109,.020),yellow,chest,(s*.16,.19,.127),smooth=True)
        box('Pocket_flap_'+label,(.116,.030,.022),lining,chest,(s*.16,.23,.139),smooth=True)
        # Split collar follows shoulder/neck; backing is dark cotton, not a sphere.
        v=[(s*.057,.318,.126),(s*.189,.354,.082),(s*.141,.431,.047),(s*.054,.423,.082),
           (s*.057,.318,.118),(s*.189,.354,.074),(s*.141,.431,.039),(s*.054,.423,.074)]
        f=[[0,1,2,3],[7,6,5,4],[0,4,5,1],[1,5,6,2],[2,6,7,3],[3,7,4,0]]
        mesh('Collar_'+label,(v,f),hair,chest,smooth=False)
    box('Back_collar',(.25,.064,.037),hair,chest,(0,.403,-.073),smooth=True)
    v=[(.096,.253,.144),(.198,.253,.119),(.198,.342,.115),(.096,.342,.140)]
    model.mesh('Crew_patch_02',v,[[0,1,2,3]],badge,chest,uvs=[(0,1),(1,1),(1,0),(0,0)])
    path('Back_yoke',[(-.208,.26,-.105),(-.13,.268,-.148),(0,.270,-.157),(.13,.268,-.148),(.208,.26,-.105)],.0027,seam,chest)

    # Pants loops clustered around cuff, knee compression and hip load.
    mesh('Trouser_pelvis',section_mesh([(.555,.208,.146,0,0),(.59,.220,.151,0,0),
        (.638,.222,.150,0,0),(.68,.22,.145,0,0)]),pants,root)
    mesh('Leather_belt',section_mesh([(.661,.225,.150,0,0),(.696,.225,.150,0,0)]),leather,root)
    box('Belt_buckle',(.066,.056,.017),metal,root,(0,.678,.157))
    box('Buckle_inset',(.043,.033,.018),leather,root,(0,.678,.166))
    for s,label in [(-1,'Right'),(1,'Left')]:
        x=s*.136
        leg=[(.174,.070,.074,x,.007),(.198,.085,.082,x,-.004),(.222,.103,.096,x,.007),
             (.250,.099,.098,x,.004),(.282,.104,.100,x,-.003),(.322,.099,.096,x,.012),
             (.357,.111,.109,x,.006),(.390,.105,.103,x,-.003),(.426,.107,.107,x,-.004),
             (.485,.116,.114,x,-.001),(.551,.122,.115,x,0),(.60,.118,.112,x,0)]
        if s<0:
            leg=[(y+(.010 if .22<y<.39 else 0),rx*(.98 if .27<y<.38 else 1),rz,x,z-.004) for y,rx,rz,x,z in leg]
        mesh('Canvas_leg_'+label,section_mesh(leg,24),pants,root)
        box('Cargo_pocket_'+label,(.098,.145,.020),pants,root,(s*.218,.434,.061),quat((0,1,0),s*38),True)
        box('Cargo_flap_'+label,(.107,.039,.020),pants,root,(s*.223,.505,.069),quat((0,1,0),s*38),True)
        box('Rear_pocket_'+label,(.121,.092,.017),pants,root,(s*.123,.594,-.139),smooth=True)
        box('Belt_loop_'+label,(.018,.06,.022),pants,root,(s*.123,.676,.126),smooth=True)
        box('Boot_sole_'+label,(.20,.044,.312),ink,root,(x,.022,.050),smooth=True)
        mesh('Boot_foot_'+label,section_mesh([(.044,.085,.135,0,.05),(.068,.094,.142,0,.057),
            (.105,.091,.138,0,.055),(.131,.082,.116,0,.040),(.153,.071,.086,0,.002)],24),boot,root,(x,0,0))
        mesh('Boot_shaft_'+label,section_mesh([(.102,.079,.084,0,0),(.126,.079,.084,0,0),
            (.188,.080,.082,0,0),(.205,.084,.085,0,0)]),boot,root,(x,0,-.019))
        path('Boot_front_seam_'+label,[(x-.067,.127,.142),(x-.043,.143,.168),(x,.147,.178),
            (x+.043,.143,.168),(x+.067,.127,.142)],.003,leather,root)

    # Small pouch and a gravity-directed gathered cable, attached to belt.
    box('Tool_pouch',(.117,.148,.062),leather,root,(-.223,.589,.114),quat((0,1,0),-22),True)
    box('Pouch_flap',(.122,.045,.066),leather,root,(-.223,.650,.120),quat((0,1,0),-22),True)
    ball('Pouch_fastener',(.010,.010,.006),metal,root,(-.223,.631,.157),12,6)
    for i in range(4):
        pts=[]
        for j in range(32):
            a=math.tau*j/32
            pts.append((-.251+(.045+i*.011)*math.cos(a),.534+(.10+i*.017)*math.sin(a),.143+i*.012))
        path('Cable_coil_'+str(i),pts,.006,ink,root,6,True)
    box('Cable_keeper',(.044,.062,.024),lining,root,(-.251,.659,.17),smooth=True)

    shoulders={}; elbows={}; wrists={}
    for s,label in [(-1,'Right'),(1,'Left')]:
        shoulder=model.node('Shoulder_'+label,chest,(s*.238,.326,0),rotation=quat((0,0,1),s*23))
        shoulders[label]=shoulder
        mesh('Sleeve_'+label,section_mesh([(.045,.038,.051,0,0),(.021,.075,.082,0,0),(-.015,.103,.101,0,0),
            (-.074,.103,.105,0,.001),(-.131,.102,.099,0,0),(-.173,.090,.094,0,.002),
            (-.214,.10,.105,0,0),(-.238,.098,.101,0,0)],24),yellow,shoulder)
        # Rolled cuff is a closed annular tube with a real inner opening.
        yc=-.237; rad=controls['cuff_radius']; inner=.077
        vertices=[]; sectors=24
        for y,r in [(yc+.026,rad),(yc-.027,rad),(yc-.027,inner),(yc+.026,inner)]:
            for k in range(sectors):
                a=math.tau*k/sectors
                vertices.append((r*math.cos(a),y,r*.98*math.sin(a)))
        faces=[]
        for row in range(4):
            other=(row+1)%4
            for k in range(sectors):
                faces.append([row*sectors+k,row*sectors+(k+1)%sectors,
                    other*sectors+(k+1)%sectors,other*sectors+k])
        mesh('Rolled_cuff_'+label,(vertices,faces),lining,shoulder)
        elbow=model.node('Elbow_'+label,shoulder,(0,-.249,0));elbows[label]=elbow
        mesh('Forearm_'+label,section_mesh([(.018,.062,.064,0,0),(-.016,.065,.067,0,0),
            (-.078,.057,.061,0,.001),(-.137,.047,.05,0,0),(-.174,.040,.044,0,0)],20),skin,elbow)
        wrist=model.node('Wrist_'+label,elbow,(0,-.175,0));wrists[label]=wrist
        box('Glove_wrist_'+label,(.105,.047,.113),hair,wrist,(0,-.005,0),smooth=True)
        ball('Glove_palm_'+label,(.064,.087,.051),ink,wrist,(0,-.057,.008),20,12)
        ball('Glove_thumb_'+label,(.027,.050,.035),ink,wrist,(-s*.045,-.044,.035),16,10)
        box('Glove_patch_'+label,(.069,.042,.008),lining,wrist,(0,-.031,.059),smooth=True)
        for i in range(3):
            path('Glove_stitch_'+label+str(i),[((i-1)*.025,-.072,.053),((i-1)*.025,-.11,.045)],.0025,hair,wrist,6)

    # Lamp owned by left hand, handle and diffuser share the same attachment.
    lampnode=model.node('LampPivot',wrists['Left'],(0,controls['lamp_offset_y'],.010))
    rim_y=-.257
    handle=[(-.077,-.224,0),(-.079,-.170,0),(-.078,-.125,0),(-.06,-.10,0),(-.025,-.098,0),
        (.025,-.098,0),(.06,-.10,0),(.078,-.125,0),(.079,-.170,0),(.077,-.224,0)]
    path('Lamp_U_handle',handle,.009,lamp,lampnode)
    # Cylinder aligned Z: ellipse rotated from Y cylinder, rounded section rings.
    housing=[(-.063,.099,.099,0,0),(-.052,.116,.116,0,0),(.032,.122,.122,0,0),(.050,.118,.118,0,0)]
    mesh('Lamp_round_housing',section_mesh(housing,40),lamp,lampnode,(0,rim_y,0),rotation=quat((1,0,0),90))
    mesh('Lamp_mustard_rim',ring(.117,.008,(0,rim_y,.054),40),lining,lampnode)
    ball('Lamp_diffuser',(.108,.108,.016),diffuser,lampnode,(0,rim_y,.047),32,16)
    for s,label in [(-1,'Right'),(1,'Left')]:
        ball('Lamp_handle_joint_'+label,(.015,.017,.014),metal,lampnode,(s*.097,-.23,.0),12,8)
    for i in range(3):
        path('Lamp_back_vent_'+str(i),[(-.055,-.230-i*.023,-.066),(.055,-.230-i*.023,-.066)],.003,hair,lampnode,6)

    # Look left -> notice camera -> gentle nod -> settle. Planted soles and pelvis.
    times=[0,.25,.50,.80,1.10,1.45,1.80,2.10,2.40,2.65,2.9,3.25,3.60,3.8,4]
    def track(node,axis,values):return(node,axis,list(zip(times,values)))
    model.animate([
        track(yaw,(0,1,0),[0,0,5,14,18,18,13,3,-5,-5,-3,-1,0,0,0]),
        track(head,(1,0,0),[0,0,0,0,0,0,0,1,5,1,-1,0,0,0,0]),
        track(chest,(0,1,0),[0,0,0,2,3,3,2,1,0,0,0,0,0,0,0]),
        track(shoulders['Left'],(0,0,1),[23,23,24,25,25,25,25,24,23,23,23,23,23,23,23]),
        track(elbows['Left'],(1,0,0),[0,0,0,-2,-4,-4,-3,-1,0,0,0,0,0,0,0]),
        track(shoulders['Right'],(0,0,1),[-23,-23,-23,-24,-24,-24,-24,-23,-23,-23,-23,-23,-23,-23,-23]),
    ])
    animation=model.doc['animations'][0]
    animation['name']='Light_Check'
    animation['extras']['intent']='Hold work lamp; look aside, notice camera, return to calm pose.'
    model.save()


if __name__=='__main__':main()
