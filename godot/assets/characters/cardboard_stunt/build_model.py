"""Build an original, editable rigid-part character and node-animated GLB.

Python stdlib + Pillow; no downloaded models or textures. Y up, +Z forward,
metres. This is a scoped articulation study, not a skinned human rig.
"""
import io
import json
import math
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(a, s):
    return tuple(x * s for x in a)


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def unit(a):
    return mul(a, 1 / math.sqrt(sum(x*x for x in a)))


def quat(axis, degrees):
    a = math.radians(degrees)/2
    return [v*math.sin(a) for v in unit(axis)] + [math.cos(a)]


class Model:
    def __init__(self):
        self.bin = bytearray()
        self.doc = dict(asset=dict(version='2.0', generator='Cardboard Stunt / skill study'),
                        scene=0, scenes=[dict(nodes=[0])], nodes=[], meshes=[],
                        materials=[], bufferViews=[], accessors=[])
        self.stats = []

    def view(self, data, target=None):
        while len(self.bin) % 4:
            self.bin.append(0)
        v = dict(buffer=0, byteOffset=len(self.bin), byteLength=len(data))
        if target:
            v['target'] = target
        self.bin.extend(data)
        self.doc['bufferViews'].append(v)
        return len(self.doc['bufferViews'])-1

    def accessor(self, rows, kind, integer=False, target=None):
        flat = [x for row in rows for x in row]
        fmt = 'I' if integer else 'f'
        view = self.view(struct.pack('<'+fmt*len(flat), *flat), target)
        a = dict(bufferView=view, componentType=5125 if integer else 5126,
                 count=len(rows), type=kind)
        if not integer:
            a['min'] = [min(c) for c in zip(*rows)]
            a['max'] = [max(c) for c in zip(*rows)]
        self.doc['accessors'].append(a)
        return len(self.doc['accessors'])-1

    def mat(self, name, color, rough=.8, metal=0):
        # glTF factors are linear; design palette is entered as display/sRGB values.
        color = [c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in color]
        self.doc['materials'].append(dict(name=name, pbrMetallicRoughness=dict(
            baseColorFactor=[*color, 1], metallicFactor=metal, roughnessFactor=rough)))
        return len(self.doc['materials'])-1

    def node(self, name, parent=None, pos=(0, 0, 0), mesh=None, rotation=None):
        n = dict(name=name, translation=list(pos))
        if mesh is not None:
            n['mesh'] = mesh
        if rotation:
            n['rotation'] = rotation
        self.doc['nodes'].append(n)
        i = len(self.doc['nodes'])-1
        if parent is not None:
            self.doc['nodes'][parent].setdefault('children', []).append(i)
        return i

    def mesh(self, name, vertices, faces, material, parent, pos=(0, 0, 0), smooth=False, uvs=None, rotation=None):
        # Validate construction indices and closed volume before duplicating normals.
        edges = {}
        volume = 0.
        for face in faces:
            for a, b in zip(face, face[1:]+face[:1]):
                key = tuple(sorted((a, b)))
                edges[key] = edges.get(key, 0)+1
            for k in range(1, len(face)-1):
                a, b, c = [vertices[i] for i in (face[0], face[k], face[k+1])]
                volume += sum(x*y for x, y in zip(a, cross(b, c)))/6
        if volume < 0:
            faces = [list(reversed(f)) for f in faces]
        normals = [(0., 0., 0.) for _ in vertices]
        for f in faces:
            n = cross(sub(vertices[f[1]], vertices[f[0]]), sub(vertices[f[2]], vertices[f[0]]))
            for i in f:
                normals[i] = add(normals[i], n)
        if smooth:
            normals = [unit(n) for n in normals]
        vs, ns, ts, uv = [], [], [], []
        min_area = float('inf')
        for f in faces:
            normal = unit(cross(sub(vertices[f[1]], vertices[f[0]]), sub(vertices[f[2]], vertices[f[0]])))
            base = len(vs)
            for i in f:
                vs.append(vertices[i])
                ns.append(normals[i] if smooth else normal)
                if uvs:
                    uv.append(uvs[i])
            for k in range(1, len(f)-1):
                a, b, c = (vs[base], vs[base+k], vs[base+k+1])
                ar = math.sqrt(sum(x*x for x in cross(sub(b, a), sub(c, a))))/2
                if ar < 1e-12:
                    raise ValueError('Degenerate triangle: '+name)
                min_area = min(min_area, ar)
                ts.extend([(base,), (base+k,), (base+k+1,)])
        attrs = dict(POSITION=self.accessor(vs, 'VEC3', target=34962),
                     NORMAL=self.accessor(ns, 'VEC3', target=34962))
        if uv:
            attrs['TEXCOORD_0'] = self.accessor(uv, 'VEC2', target=34962)
        prim = dict(attributes=attrs, indices=self.accessor(ts, 'SCALAR', True, 34963), material=material)
        self.doc['meshes'].append(dict(name=name, primitives=[prim]))
        self.stats.append(dict(name=name, vertices=len(vertices), render_vertices=len(vs),
                               triangles=len(ts)//3, boundary_edges=sum(v==1 for v in edges.values()),
                               nonmanifold_edges=sum(v>2 for v in edges.values()), minimum_area=min_area))
        return self.node(name, parent, pos, len(self.doc['meshes'])-1, rotation)

    def animate(self, tracks):
        animation = dict(name='Action_Slate', samplers=[], channels=[], extras=dict(
            intent='Plant both boots, anticipate, signal action twice, settle.', fps=24,
            method='Rigid node rotations, authored poses; no cloth simulation or skin weights.'))
        for node, axis, keys in tracks:
            time = self.accessor([(t,) for t, value in keys], 'SCALAR')
            value = self.accessor([quat(axis, value) for t, value in keys], 'VEC4')
            animation['channels'].append(dict(sampler=len(animation['samplers']), target=dict(node=node, path='rotation')))
            animation['samplers'].append(dict(input=time, output=value, interpolation='LINEAR'))
        self.doc['animations'] = [animation]

    def save(self):
        self.doc['buffers'] = [dict(byteLength=len(self.bin))]
        j = json.dumps(self.doc, separators=(',', ':')).encode()
        j += b' '*((-len(j)) % 4)
        self.bin += b'\0'*((-len(self.bin)) % 4)
        data = struct.pack('<III', 0x46546c67, 2, 12+8+len(j)+8+len(self.bin))
        data += struct.pack('<II', len(j), 0x4e4f534a)+j
        data += struct.pack('<II', len(self.bin), 0x004e4942)+self.bin
        (OUT/'cardboard_stunt.glb').write_bytes(data)
        report = dict(height_m_approx=2.0, front='+Z', up='+Y', triangle_budget=14000,
                      triangles=sum(x['triangles'] for x in self.stats),
                      render_vertices=sum(x['render_vertices'] for x in self.stats),
                      animation_seconds=4, mesh_count=len(self.stats), materials=len(self.doc['materials']),
                      attachment='Rigid parts parented to joints. Feet parented to root, not chest.',
                      intentional_boundaries=['single-sided printed decal'], meshes=self.stats)
        assert report['triangles'] < report['triangle_budget']
        assert all(not s['nonmanifold_edges'] for s in self.stats)
        (OUT/'geometry_report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
        print(json.dumps({k:v for k,v in report.items() if k!='meshes'}))


def ellipsoid(scale, sectors=20, rings=10):
    verts = [(0, scale[1], 0)]
    for j in range(1, rings):
        phi = math.pi*j/rings
        for i in range(sectors):
            t = math.tau*i/sectors
            verts.append((scale[0]*math.sin(phi)*math.cos(t), scale[1]*math.cos(phi), scale[2]*math.sin(phi)*math.sin(t)))
    bottom = len(verts)
    verts.append((0, -scale[1], 0))
    faces = [[0, 1+(i+1)%sectors, 1+i] for i in range(sectors)]
    for j in range(rings-2):
        for i in range(sectors):
            a=1+j*sectors+i; b=1+j*sectors+(i+1)%sectors
            faces.append([a, b, b+sectors, a+sectors])
    for i in range(sectors):
        faces.append([bottom, 1+(rings-2)*sectors+i, 1+(rings-2)*sectors+(i+1)%sectors])
    return verts, faces


def bevelbox(size, bevel=.04):
    x,y,z = [s/2 for s in size]
    b = min(bevel, x*.7, y*.7, z*.7)
    section = [(-x+b,-z), (x-b,-z), (x,-z+b), (x,z-b), (x-b,z), (-x+b,z), (-x,z-b), (-x,-z+b)]
    verts=[]
    for h,f in [(-y,.87), (-y+b,1), (y-b,1), (y,.87)]:
        verts.extend([(a*f,h,c*f) for a,c in section])
    faces=[list(reversed(range(8))),list(range(24,32))]
    for j in range(3):
        for i in range(8):
            faces.append([j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i])
    return verts,faces


def hair_lock(points, widths, depths, outward):
    """Solid asymmetric 8-sided wedge; variable width/depth and buried roots.
    Implements the installed hair skill's lens-section construction.
    """
    vertices=[]
    last=outward
    section=[(-1,0),(-.55,.65),(.14,1),(.7,.52),(1,0),(.45,-.42),(-.3,-.48),(-.8,-.2)]
    for i,p in enumerate(points):
        tangent=unit(sub(points[min(i+1,len(points)-1)],points[max(i-1,0)]))
        n=unit(sub(last,mul(tangent,sum(x*y for x,y in zip(last,tangent)))))
        side=unit(cross(tangent,n)); last=n
        vertices.extend([add(p,add(mul(side,a*widths[i]),mul(n,b*depths[i]))) for a,b in section])
    faces=[list(reversed(range(8))),list(range((len(points)-1)*8,len(points)*8))]
    for j in range(len(points)-1):
        for i in range(8):
            faces.append([j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i])
    return vertices,faces


def main():
    m=Model()
    skin=m.mat('Warm skin',(.83,.52,.32),.8)
    hair=m.mat('Ink brown hair',(.052,.034,.025),.64)
    highlight=m.mat('Hair crest',(.10,.061,.034),.66)
    navy=m.mat('Washed navy workwear',(.045,.095,.12),.95)
    red=m.mat('Oxblood rubber',(.51,.069,.035),.65)
    sole=m.mat('Rubber sole / eyes',(.021,.029,.028),.86)
    board=m.mat('Uncoated kraft liner',(.56,.34,.145),.96)
    edge=m.mat('Exposed corrugated core',(.32,.185,.075),.97)
    tape=m.mat('Silver gaffer tape',(.37,.41,.39),.55,.28)
    cream=m.mat('Cream label / eyes',(.94,.86,.65),.85)
    badge=m.mat('Printed crew badge',(.9,.82,.61),.9)
    img=Image.new('RGB',(512,256),(226,205,157)); draw=ImageDraw.Draw(img)
    fontpath='C:/Windows/Fonts/arialbd.ttf'
    font=ImageFont.truetype(fontpath,68)
    draw.text((256,44),'STUNT',font=font,fill=(32,44,44),anchor='mt')
    draw.text((256,129),'01',font=ImageFont.truetype(fontpath,83),fill=(155,43,23),anchor='mt')
    draw.rectangle((12,12,499,243),outline=(86,61,35),width=5)
    png=io.BytesIO();img.save(png,format='PNG')
    m.doc['images']=[dict(bufferView=m.view(png.getvalue()),mimeType='image/png')]
    m.doc['textures']=[dict(source=0)]
    m.doc['materials'][badge]['pbrMetallicRoughness'].update(baseColorFactor=[1,1,1,1],baseColorTexture=dict(index=0))
    root=m.node('CardboardStunt')
    hips=m.node('HipPivot',root,(0,.61,0))
    chest=m.node('ChestPivot',hips,(0,.04,0))
    head=m.node('HeadPivot',chest,(0,.53,0))

    def box(name,size,mat,parent,pos=(0,0,0),rotation=None):
        v,f=bevelbox(size)
        return m.mesh(name,v,f,mat,parent,pos,rotation=rotation)

    def ball(name,size,mat,parent,pos=(0,0,0),smooth=True,sectors=20,rings=10):
        v,f=ellipsoid(size,sectors,rings)
        return m.mesh(name,v,f,mat,parent,pos,smooth)

    box('Coverall_pelvis',(.47,.23,.28),navy,hips,(0,-.03,0))
    ball('Shirt_under_armor',(.252,.31,.153),navy,chest,(0,.26,0))
    ball('Neck',(.10,.14,.10),skin,head,(0,.04,0),sectors=12,rings=6)
    ball('Head_volume',(.355,.385,.30),skin,head,(0,.30,.015))
    for s,word in [(-1,'L'),(1,'R')]:
        ball('Ear_'+word,(.065,.095,.060),skin,head,(s*.345,.30,.0),sectors=12,rings=6)
        ball('Ear_inner_'+word,(.021,.053,.033),red,head,(s*.389,.30,.025),sectors=10,rings=6)
        ball('Eye_white_'+word,(.065,.072,.029),cream,head,(s*.135,.335,.279),sectors=16,rings=8)
        ball('Eye_ink_'+word,(.030,.045,.018),sole,head,(s*.123,.327,.307),sectors=12,rings=6)
        ball('Eye_glint_'+word,(.009,.013,.007),cream,head,(s*.119-.007,.342,.322),sectors=8,rings=4)
        box('Brow_'+word,(.115,.027,.033),hair,head,(s*.138,.437,.273),quat((0,0,1),s*-9))
        ball('Cheek_'+word,(.069,.033,.014),red,head,(s*.22,.238,.247),sectors=12,rings=6)
    ball('Nose',(.050,.061,.076),skin,head,(0,.257,.303),sectors=12,rings=8)
    box('Smile',(.114,.023,.024),sole,head,(0,.146,.284),quat((0,0,1),-4))
    box('Bandaid',(.086,.044,.010),cream,head,(-.208,.245,.264),quat((0,0,1),-20))

    # Trimmed, recessed scalp coverage: upper hemisphere and rear/nape only.
    sectors=28; rr=10; v=[(0,.709,.015)]
    for j in range(1,rr+1):
        for i in range(sectors):
            t=math.tau*i/sectors
            end=1.43-.10*max(0,math.sin(t))
            p=end*j/rr
            v.append((.368*math.sin(p)*math.cos(t),.30+.409*math.cos(p),.015+.326*math.sin(p)*math.sin(t)))
    f=[[0,1+i,1+(i+1)%sectors] for i in range(sectors)]
    for j in range(rr-1):
        for i in range(sectors):
            a=1+j*sectors+i;b=1+j*sectors+(i+1)%sectors
            f.append([a,a+sectors,b+sectors,b])
    # Internal planar closure is hidden within the skull; no exposed empty scalp.
    f.append(list(reversed(range(1+(rr-1)*sectors,1+rr*sectors))))
    m.mesh('Recessed_hair_coverage',v,f,hair,head,smooth=True)
    locks=[
        ('Swept_fringe_A',[(-.10,.64,.12),(.05,.66,.25),(.22,.54,.31),(.25,.43,.26)],[.12,.14,.12,.012],[.065,.08,.07,.015],(0,0,1)),
        ('Swept_fringe_B',[(-.25,.56,.08),(-.17,.63,.25),(.02,.53,.35),(.09,.43,.31)],[.12,.14,.10,.012],[.065,.075,.06,.015],(0,0,1)),
        ('Fringe_short',[(-.30,.50,.06),(-.28,.56,.22),(-.17,.47,.30),(-.15,.38,.265)],[.10,.10,.075,.012],[.06,.065,.055,.014],(0,0,1)),
        ('Crown_quiff',[(-.10,.65,-.03),(-.17,.72,.07),(-.06,.755,.17),(.05,.70,.21)],[.12,.12,.09,.012],[.07,.07,.06,.014],(0,1,.2)),
        ('Right_temple',[(.23,.60,.0),(.33,.52,.03),(.35,.38,.10),(.31,.26,.09)],[.11,.12,.10,.015],[.055,.06,.05,.015],(1,0,.2)),
        ('Left_temple',[(-.26,.55,-.03),(-.34,.45,.02),(-.345,.34,.06),(-.32,.255,.04)],[.1,.10,.08,.015],[.055,.06,.045,.014],(-1,0,.2)),
        ('Rear_left',[(-.20,.61,-.09),(-.28,.49,-.19),(-.26,.35,-.26),(-.17,.235,-.245)],[.14,.15,.12,.02],[.06,.06,.055,.015],(-.3,0,-1)),
        ('Rear_center',[(0,.65,-.08),(-.03,.52,-.26),(.04,.35,-.31),(.045,.22,-.255)],[.18,.19,.14,.02],[.055,.06,.055,.015],(0,0,-1)),
        ('Rear_right',[(.19,.61,-.08),(.28,.49,-.18),(.255,.34,-.26),(.19,.25,-.25)],[.13,.14,.115,.02],[.065,.07,.055,.014],(.4,0,-1))]
    for i,(name,pts,w,d,outward) in enumerate(locks):
        v,f=hair_lock(pts,w,d,outward)
        n=m.mesh(name,v,f,highlight if i in (0,3) else hair,head)
        m.doc['nodes'][n]['extras']=dict(group=name.split('_')[0],root='scalp',termination='tapered free tip')

    # Thin front/rear cardboard plates with separate side walls and shoulder supports.
    box('Kraft_front',(.54,.43,.028),board,chest,(0,.285,.191))
    box('Kraft_back',(.54,.43,.028),board,chest,(0,.285,-.193))
    for s,word in [(-1,'L'),(1,'R')]:
        box('Kraft_side_'+word,(.025,.35,.32),edge,chest,(s*.272,.25,0))
        box('Shoulder_support_'+word,(.11,.025,.42),board,chest,(s*.20,.49,0))
        box('Tape_front_'+word,(.064,.14,.010),tape,chest,(s*.198,.433,.211),quat((0,0,1),s*11))
        box('Tape_back_'+word,(.064,.14,.010),tape,chest,(s*.198,.433,-.212),quat((0,0,1),s*11))
        # Exposed flute ends along lower edge only: broad faces remain quiet.
        for i in range(7):
            box('Core_flute_'+word+str(i),(.012,.007,.024),edge,chest,(s*(.08+i*.026),.068,.192))
    box('Repair_tape',(.19,.064,.009),tape,chest,(-.145,.137,.21),quat((0,0,1),-16))
    decal=[(-.158,.198,.208),(.158,.198,.208),(.158,.366,.208),(-.158,.366,.208)]
    m.mesh('STUNT_01_print',decal,[[0,1,2,3]],badge,chest,uvs=[(0,1),(1,1),(1,0),(0,0)])
    box('Back_tape_seam',(.057,.40,.009),tape,chest,(0,.278,-.214))

    shoulders={}; elbows={}; wrists={}
    for s,word in [(-1,'L'),(1,'R')]:
        # Overlapped rigid joints deliberately model a stop-motion puppet.
        shoulder=m.node('Shoulder_'+word,chest,(s*.335,.46,0),rotation=quat((0,0,1),s*18))
        shoulders[word]=shoulder
        ball('Shoulder_socket_'+word,(.115,.13,.115),navy,shoulder,(0,-.035,0),sectors=16,rings=8)
        box('Sleeve_'+word,(.165,.26,.19),navy,shoulder,(0,-.13,0))
        elbow=m.node('Elbow_'+word,shoulder,(0,-.25,0))
        elbows[word]=elbow
        ball('Elbow_socket_'+word,(.077,.077,.077),navy,elbow,sectors=12,rings=6)
        box('Forearm_'+word,(.133,.22,.151),navy,elbow,(0,-.10,0))
        box('Cuff_'+word,(.151,.055,.166),red,elbow,(0,-.207,0))
        wrist=m.node('Wrist_'+word,elbow,(0,-.26,0));wrists[word]=wrist
        ball('Glove_palm_'+word,(.096,.117,.072),red,wrist,(0,-.058,.014),sectors=16,rings=8)
        ball('Glove_thumb_'+word,(.045,.067,.047),red,wrist,(-s*.072,-.025,.040),sectors=12,rings=6)
        # Mitten is intentionally unarticulated; seams suggest knuckle rhythm.
        for i in range(2):
            box('Glove_seam_'+word+str(i),(.009,.050,.007),edge,wrist,((i-.5)*.042,-.080,.081))
        ball('Pant_thigh_'+word,(.114,.22,.125),navy,hips,(s*.152,-.18,0),sectors=16,rings=8)
        box('Kneepad_'+word,(.146,.103,.032),red,root,(s*.157,.36,.123))
        box('Pant_shin_'+word,(.182,.25,.202),navy,root,(s*.16,.225,0))
        box('Boot_collar_'+word,(.228,.18,.25),red,root,(s*.16,.17,0))
        box('Boot_'+word,(.252,.145,.40),red,root,(s*.16,.085,.082))
        box('Boot_sole_'+word,(.265,.043,.419),sole,root,(s*.16,.0215,.085))
        box('Boot_toe_patch_'+word,(.185,.059,.048),sole,root,(s*.16,.074,.263))

    # Event-led action, both soles are immutable. No root displacement.
    times=[0,.25,.5,.72,1.0,1.28,1.55,1.8,2.05,2.3,2.55,2.8,3.15,3.5,3.75,4]
    def track(node,axis,values):return (node,axis,list(zip(times,values)))
    m.animate([
        track(shoulders['R'],(0,0,1),[18,18,12,42,88,126,132,124,135,123,135,117,78,34,18,18]),
        track(elbows['R'],(0,0,1),[0,0,5,12,28,30,23,35,20,35,20,30,20,9,0,0]),
        track(wrists['R'],(0,0,1),[0,0,0,0,-4,-8,12,-14,13,-14,12,-8,-4,0,0,0]),
        track(shoulders['L'],(0,0,1),[-18,-18,-18,-21,-23,-24,-24,-24,-24,-24,-24,-23,-21,-19,-18,-18]),
        track(chest,(0,0,1),[0,0,2,1,-1,-2,-2,-2,-2,-2,-2,-1,1,.5,0,0]),
        track(head,(0,1,0),[0,0,-5,-9,-11,-8,-5,-5,-5,-5,-5,-4,-3,-1,0,0]),
    ])
    m.save()


if __name__=='__main__':
    main()
