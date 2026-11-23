"""HARI v2: native Blender modeling and matched multi-view paint guides.

Run in a factory-startup background Blender. Original HARI and Armored sources
are never written. Author coordinates are metres, Y up, +Z forward; Blender
conversion is (x, -z, y). No external character mesh is used.
"""
from pathlib import Path
import bpy, bmesh, math, json, sys, hashlib
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

HERE=Path(__file__).resolve().parent
ASSET=HERE.parent
OLD=ASSET.parent/'hari_lighting'
sys.path.insert(0,str(OLD))
from clump_mesh import make_clump

def cv(v): return Vector((v[0],-v[2],v[1]))
def ac(v): return (v[0],v[2],-v[1])
def srgb(v): return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def material(name,color,rough=.8):
    m=bpy.data.materials.new(name);m.use_nodes=True
    b=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
    b.inputs['Base Color'].default_value=(*[srgb(v) for v in color],1)
    b.inputs['Roughness'].default_value=rough
    return m
def mesh(name,v,f,mat,parent=None,pos=(0,0,0),uv=None):
    me=bpy.data.meshes.new(name);me.from_pydata([cv(p) for p in v],[],f);me.update()
    ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob)
    if mat:me.materials.append(mat)
    ob.parent=parent;ob.location=cv(pos)
    for p in me.polygons:p.use_smooth=True
    if uv:
        layer=me.uv_layers.new(name='PaintUV')
        for p in me.polygons:
            for li in p.loop_indices:layer.data[li].uv=uv[me.loops[li].vertex_index]
    return ob
def remove(names):
    for name in names:
        if name in bpy.data.objects:bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
def replace(name,v,f,mat,parent=None,pos=(0,0,0),uv=None):
    remove([name]);return mesh(name,v,f,mat,parent,pos,uv)
def activate(ob):
    bpy.ops.object.select_all(action='DESELECT');ob.select_set(True);bpy.context.view_layer.objects.active=ob
def weld(ob):
    bm=bmesh.new();bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
    for p in ob.data.polygons:p.use_smooth=True
def curve(name,points,radius,mat,parent=None,closed=False):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=12
    cu.bevel_depth=radius;cu.bevel_resolution=2;cu.use_fill_caps=True
    sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
    for p,co in zip(sp.bezier_points,points):p.co=cv(co);p.handle_left_type='AUTO';p.handle_right_type='AUTO'
    sp.use_cyclic_u=closed
    ob=bpy.data.objects.new(name,cu);bpy.context.collection.objects.link(ob);ob.parent=parent;cu.materials.append(mat)
    return ob
def sphere(name,center,scale,mat,parent=None,segments=48,rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings)
    ob=bpy.context.object;ob.name=name;ob.parent=parent;ob.location=cv(center)
    ob.scale=(scale[0],scale[2],scale[1]);ob.data.materials.append(mat)
    for p in ob.data.polygons:p.use_smooth=True
    activate(ob);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return ob
def loft(name,sections,mat,parent=None,n=64,rows=48,fold=None,pos=(0,0,0),cap=True):
    a=np.array(sections,float);ys=np.linspace(a[0,0],a[-1,0],rows)
    v=[];uv=[]
    for j,y in enumerate(ys):
        rx,rz,cx,cz=[np.interp(y,a[:,0],a[:,i]) for i in range(1,5)]
        for i in range(n):
            t=math.tau*i/n;delta=fold(y,t) if fold else 0
            v.append((cx+(rx+delta)*math.cos(t),y,cz+(rz+delta)*math.sin(t)));uv.append((i/n,j/(rows-1)))
    f=[]
    for j in range(rows-1):
        for i in range(n):f.append([j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i])
    if cap:f.extend([list(reversed(range(n))),list(range((rows-1)*n,rows*n))])
    return mesh(name,v,f,mat,parent,pos)
def bevel(ob,width=.005):
    mod=ob.modifiers.new('Tailored soft edge','BEVEL');mod.width=width;mod.segments=3
    mod.limit_method='ANGLE'
def gauss(x,y,cx,cy,wx,wy):return math.exp(-((x-cx)/wx)**2-((y-cy)/wy)**2)

def face_z(x,y):
    q=max(0,1-(x/.297)**2-((y-.28)/.302)**2)
    z=.018+.258*math.sqrt(q)
    z+=.026*gauss(abs(x),y,.175,.205,.09,.10)
    z-=.025*gauss(abs(x),y,.126,.353,.08,.07)
    z+=.057*gauss(x,y,0,.251,.037,.045)
    z+=.014*gauss(x,y,0,.307,.027,.081)
    z+=.012*gauss(x,y,0,.163,.085,.034)
    z-=.006*gauss(x,y,0,.12,.07,.016)
    return z

def build_face(head,skin,ink,hair,white,iris,blush):
    remove(['Face_skull','Nose','Soft_smile','Lower_lip']+[p+s for s in ['Right','Left'] for p in
           ['Eye_white_','Iris_','Pupil_','Eye_glint_','Brow_','Upper_lid_','Ear_','Inner_ear_','Lens_']])
    n=96;rows=64;v=[(0,.582,.018)]
    for j in range(1,rows):
        phi=math.pi*j/rows;y=.28+.302*math.cos(phi)
        jaw=1-.13*max(0,(.25-y)/.27)
        for i in range(n):
            t=math.tau*i/n;x=.297*math.sin(phi)*math.cos(t)*jaw
            z=.018+.258*math.sin(phi)*math.sin(t)
            if z>.018:z=face_z(x,y)
            v.append((x,y,z))
    v.append((0,-.022,.018));f=[[0,1+i,1+(i+1)%n] for i in range(n)]
    for j in range(rows-2):
        for i in range(n):
            a=1+j*n+i;b=1+j*n+(i+1)%n;f.append([a,a+n,b+n,b])
    end=len(v)-1
    for i in range(n):f.append([end,1+(rows-2)*n+(i+1)%n,1+(rows-2)*n+i])
    face=mesh('Face_continuous_sculpt',v,f,skin,head)
    # Aperture surrounds a shallow almond eye, with outer banks returning to cheek.
    for s,label in [(-1,'Right'),(1,'Left')]:
        cx=s*.126;cy=.326;outline=[]
        for i in range(64):
            t=math.tau*i/64
            x=cx+.084*math.cos(t);y=cy+(.061 if math.sin(t)>0 else .053)*math.sin(t)
            y+=s*.012*(x-cx)/.080
            outline.append((x,y,.278-.014*(math.cos(t)**2)))
        ev=[(cx,cy,.298)]+outline
        ef=[[0,i+1,(i+1)%64+1] for i in range(64)]
        mesh('Eye_white_'+label,ev,ef,white,head)
        center=(cx+s*.004,cy+.003,.303)
        sphere('Iris_'+label,center,(.040,.044,.012),iris,head)
        sphere('Pupil_'+label,(center[0],center[1],.314),(.028,.034,.007),ink,head,32,16)
        sphere('Eye_glint_'+label,(center[0]-.009,center[1]+.017,.320),(.008,.010,.003),white,head,24,12)
        # Modeled eyelid banks, rather than a round pipe on top of the eye.
        vv=[]
        for j in range(5):
            a=j/4
            for x,y,z in outline:
                dx=x-cx;dy=y-cy
                xx=cx+dx*(1+.31*a);yy=cy+dy*(1+.38*a)
                depth=(1-a)*z+a*face_z(xx,yy)+.009*math.sin(math.pi*a)
                vv.append((xx,yy,depth))
        ff=[]
        for j in range(4):
            for i in range(64):ff.append([j*64+i,j*64+(i+1)%64,(j+1)*64+(i+1)%64,(j+1)*64+i])
        mesh('Lid_socket_bank_'+label,vv,ff,skin,head)
        upper=[outline[i] for i in range(1,32)]
        curve('Upper_lash_'+label,[(x,y,z+.003) for x,y,z in upper],.0035,ink,head)
        lower=[outline[i] for i in range(34,61)]
        curve('Lower_lid_'+label,[(x,y,z+.0015) for x,y,z in lower],.0014,blush,head)
        curve('Brow_'+label,[(s*.057,.434,.249),(s*.104,.455,.258),(s*.157,.453,.242),(s*.192,.438,.224)],.008,hair,head)
        # Ear helix, concha and tragus provide distinct structure in profile.
        sphere('Ear_'+label,(s*.290,.270,.018),(.049,.075,.043),skin,head)
        sphere('Ear_concha_'+label,(s*.326,.277,.041),(.012,.043,.019),blush,head)
        ep=[(s*(.314+.022*math.cos(t)),.278+.055*math.sin(t),.054+.008*math.cos(t)) for t in np.linspace(0,math.tau,28,endpoint=False)]
        curve('Ear_helix_'+label,ep,.006,skin,head,True)
        sphere('Ear_tragus_'+label,(s*.316,.254,.059),(.011,.013,.011),skin,head,24,12)
    # Lips seat on the actual continuous face, including the curved smile corners.
    pts=[]
    for x in np.linspace(-.065,.065,18):
        y=.164+.012*(abs(x)/.065)**1.7;pts.append((x,y,face_z(x,y)+.002))
    curve('Smile_contact',pts,.0021,ink,head)
    lipv=[];lipf=[]
    for j in range(4):
        for i,x in enumerate(np.linspace(-.060,.060,25)):
            fall=math.sqrt(max(0,1-(x/.061)**2));y=.159+.009*(abs(x)/.060)**1.7-j*.004*fall
            lipv.append((x,y,face_z(x,y)+.001+.004*math.sin(math.pi*j/3)*fall))
    for j in range(3):
        for i in range(24):lipf.append([j*25+i,j*25+i+1,(j+1)*25+i+1,(j+1)*25+i])
    mesh('Lower_lip_sculpt',lipv,lipf,blush,head)
    for s in [-1,1]:
        curve('Nostril_'+str(s),[(s*.009,.233,face_z(s*.009,.233)+.001),(s*.018,.231,face_z(s*.018,.231)+.001),(s*.026,.238,face_z(s*.026,.238)+.001)],.0015,blush,head)
    return face

def build_hair(head,hair,light,ink):
    remove(['Bob_recessed_coverage','Fringe_major','Fringe_lower','Part_short','Temple_left','Temple_right']+['Nape_'+str(i) for i in range(5)])
    # Scalp-following coverage under directional, unequal groups.
    n=96;rows=32;v=[(.025,.621,0)]
    for j in range(1,rows+1):
        for i in range(n):
            t=math.tau*i/n;front=max(0,math.sin(t));phi=(2.19-1.22*front)*j/rows
            v.append((.327*math.sin(phi)*math.cos(t),.283+.338*math.cos(phi),.010+.286*math.sin(phi)*math.sin(t)))
    f=[[0,1+i,1+(i+1)%n] for i in range(n)]
    for j in range(rows-1):
        for i in range(n):a=1+j*n+i;b=1+j*n+(i+1)%n;f.append([a,a+n,b+n,b])
    f.append(list(range(1+(rows-1)*n,1+rows*n)))
    mesh('Hair_coverage',v,f,hair,head)
    specs=[]
    # Fringe bands turn from an off-center part across the forehead to the left temple.
    for i in range(6):
        k=i/5
        pts=[(.11+.018*k,.569-.019*k,.050+.030*k),(.068-.037*k,.574-.010*k,.187+.024*k),
             (-.109-.025*k,.535-.030*k,.271+.014*k),(-.250-.018*k,.430-.040*k,.248+.013*k),
             (-.315-.008*k,.245-.029*k,.150+.010*k),(-.280+.012*k,.085-.017*k,.080+.007*k)]
        specs.append(('Fringe_wave_'+str(i),pts,[.025,.070,.068,.060,.046,.006],[.013,.026,.027,.027,.023,.009],(0,0,1)))
    # Short side follows a different growth direction, preserving the ear window.
    for i in range(4):
        a=i/3
        pts=[(.155,.58-.01*a,.062-.10*a),(.272,.509,.155-.125*a),(.327,.380,.133-.135*a),
             (.330,.247,.081-.135*a),(.301,.110,.036-.14*a),(.253,.060,-.012-.11*a)]
        specs.append(('Short_side_'+str(i),pts,[.035,.059,.060,.056,.043,.005],[.017,.028,.032,.029,.023,.009],(1,0,.25)))
    # Broad rear panels tuck into a softly scalloped nape, not a repeated tube ring.
    for i,a in enumerate(np.linspace(math.pi,math.tau,9)):
        ca,sa=math.cos(a),math.sin(a)
        pts=[(.08*ca+.035,.574,.065*sa),(.254*ca,.505,.226*sa),(.327*ca,.344,.291*sa),
             (.320*ca,.180,.287*sa),(.269*ca,.086+.012*math.sin(i*1.7),.233*sa),(.222*ca,.051+.017*math.sin(i*2),.191*sa)]
        width=.087+.015*math.sin(i*2.1)
        specs.append(('Rear_panel_'+str(i),pts,[.032,width*.78,width,width*.87,width*.65,.010],[.011,.019,.024,.025,.022,.011],(ca,0,sa)))
    for index,(name,pts,widths,depths,outward) in enumerate(specs):
        vv,ff=make_clump(pts,widths,depths,rings=32,outward=outward,ridge=.025)
        ob=mesh(name,vv,[list(x) for x in ff],hair,head)
        sub=ob.modifiers.new('Soft sculptural lock','SUBSURF');sub.levels=1;sub.render_levels=1
        # A few finer directional ridges per parent group, subdued in brightness.
        for stripe in [-.35,.2]:
            pp=[]
            for p,w,d in zip(pts,widths,depths):
                o=Vector(outward).normalized();side=Vector((-o.z,0,o.x))
                pp.append(tuple(Vector(p)+o*d*.98+side*w*stripe))
            curve(name+'_flow_'+str(stripe),pp,.0009,light if index%3 else ink,head)

def build_external_head(head,skin,ink,hair,white,iris,blush):
    """Preserve authored eye/lip/ear topology from the inspected CC0 asset."""
    remove(['Face_skull','Nose','Soft_smile','Lower_lip','Neck']+[p+s for s in ['Right','Left'] for p in
           ['Eye_white_','Iris_','Pupil_','Eye_glint_','Brow_','Upper_lid_','Ear_','Inner_ear_','Lens_']])
    with bpy.data.libraries.load(str(HERE/'human_base_parts.blend')) as (a,b):b.objects=list(a.objects)
    base=next(o for o in b.objects if o.name.startswith('GEO-head_stylized') and '.eye.' not in o.name)
    def warp(p):
        x,y,z=p;w=math.exp(-((abs(x)-.044)/.037)**2-((z-.173)/.05)**2)
        xx=2.05*x+(1 if x>=0 else -1)*.025*w+(x-(.044 if x>=0 else -.044))*.70*w
        yy=.326+(z-.173)*(2.10 if z<=.173 else 1.70)+(z-.173)*.4*w
        d=-y
        zz=2*d+.035 if d<=.11 else .255+.65*(d-.11)
        # Reduce lower jaw and ease the mouth corners into a modest smile.
        xx*=1+.10*math.exp(-((z-.073)/.035)**2)
        yy+=.015*math.exp(-((abs(x)-.036)/.015)**2-((z-.100)/.015)**2)
        return (xx,yy,zz)
    for ob in b.objects:
        if 'body_' in ob.name:
            collection=bpy.data.collections.new('ANATOMY_REFERENCE_CC0');bpy.context.scene.collection.children.link(collection)
            collection.objects.link(ob);ob.name='CC0_female_body_fitting_reference';ob.hide_render=True;ob.hide_set(True)
            ob['scope']='Editable construction reference. Not a bound/posed runtime body.'
            continue
        bpy.context.collection.objects.link(ob)
        offset=ob.location.copy()
        for v in ob.data.vertices:v.co=cv(warp(v.co+offset))
        ob.location=(0,0,0);ob.parent=head;ob.data.materials.clear()
        ob.data.materials.append(white if '.eye.' in ob.name else skin)
        if '.eye.' in ob.name:
            label='Right' if '.R' in ob.name else 'Left';s=-1 if label=='Right' else 1
            ob.name='Eye_white_'+label
            center=warp(offset);cx,cy=center[0],center[1]
            sphere('Iris_'+label,(cx,cy,.277),(.038,.044,.006),iris,head)
            sphere('Pupil_'+label,(cx,cy,.283),(.026,.033,.003),ink,head,32,16)
            sphere('Eye_glint_'+label,(cx-.009,cy+.018,.286),(.008,.010,.002),white,head,24,12)
        else:
            ob.name='Face_CC0_adapted';ob['adaptation']='Eye region expansion, shortened forehead, softened jaw, restrained smile; original face/ear topology retained.'
        mod=ob.modifiers.new('CC0 smooth facial surface','SUBSURF');mod.levels=1;mod.render_levels=1
        for p in ob.data.polygons:p.use_smooth=True
    bpy.context.view_layer.update()
    bvh=BVHTree.FromObject(base,bpy.context.evaluated_depsgraph_get())
    for s,label in [(-1,'Right'),(1,'Left')]:
        points=[]
        for x,y in [(s*.062,.419),(s*.106,.439),(s*.153,.433),(s*.184,.415)]:
            hit,normal,_,_=bvh.ray_cast(cv((x,y,1)),cv((0,0,-1)))
            if hit is not None:points.append(ac(hit+normal*.004))
        curve('Brow_'+label,points,.007,hair,head)
    return base

def garment_details(chest,root,cloth,lining,pants,seam,ink):
    # The jacket front is genuinely open, with a thin facing around its cut.
    remove(['Jacket_body','Hem_band_Right','Hem_band_Left','Cotton_shirt'])
    n=72;rows=48;v=[];f=[]
    sections=np.array([[0,.226,.149],[.07,.235,.152],[.19,.242,.151],[.30,.248,.142],[.36,.230,.124],[.398,.158,.098]])
    for j,y in enumerate(np.linspace(0,.398,rows)):
        rx=np.interp(y,sections[:,0],sections[:,1]);rz=np.interp(y,sections[:,0],sections[:,2]);cut=math.acos(.052/rx)
        for i in range(n):
            t=math.pi-cut+(math.pi+2*cut)*i/(n-1)
            fold=.005*math.sin(7*t+.3)*math.exp(-((y-.047)/.065)**2)
            fold+=.004*math.sin(3*t+y*12)*math.exp(-((y-.27)/.13)**2)
            v.append(((rx+fold)*math.cos(t),y+(j==0)*.004*math.cos(3*t),(rz+fold)*math.sin(t)))
    for j in range(rows-1):
        for i in range(n-1):f.append([j*n+i,j*n+i+1,(j+1)*n+i+1,(j+1)*n+i])
    ob=mesh('Jacket_open_panels',v,f,cloth,chest)
    mod=ob.modifiers.new('Cloth facing thickness','SOLIDIFY');mod.thickness=.005;mod.offset=-1
    loft('Cotton_shirt',[(.01,.207,.136,0,0),(.12,.213,.141,0,0),(.30,.209,.128,0,0),(.37,.127,.089,0,0)],
         bpy.data.materials['Eye white / cotton shirt'],chest,n=48,rows=32)
    for s,label in [(-1,'Right'),(1,'Left')]:
        shoulder=bpy.data.objects['Shoulder_'+label]
        remove(['Sleeve_'+label])
        def fold(y,t):
            inner=max(0,s*math.cos(t))
            return .012*math.sin(24*y+3*t)*math.exp(-((y+.18)/.06)**2)*(0.3+.7*inner)+.004*math.sin(5*t-4*y)
        loft('Sleeve_'+label,[(-.242,.096,.098,0,0),(-.18,.108,.109,0,0),(-.11,.107,.108,0,0),
             (-.04,.103,.106,0,0),(.025,.078,.084,0,0),(.050,.034,.053,0,0)],cloth,shoulder,n=48,rows=36,fold=fold)
        cuff=bpy.data.objects['Rolled_cuff_'+label];weld(cuff)
        mod=cuff.modifiers.new('Soft rolled fabric','SUBSURF');mod.levels=2
        # Tailored pocket panels and restrained seam geometry.
        for name in ['Chest_pocket_'+label,'Pocket_flap_'+label,'Cargo_pocket_'+label,'Cargo_flap_'+label,'Rear_pocket_'+label]:
            ob=bpy.data.objects[name];weld(ob);bevel(ob,.004)
        x=s*.16
        curve('Chest_pocket_seam_'+label,[(x-s*.046,.228,.151),(x-s*.046,.150,.151),(x,.140,.152),(x+s*.046,.150,.127),(x+s*.046,.228,.129)],.0013,seam,chest)
        curve('Jacket_front_seam_'+label,[(s*.066,.02,.147),(s*.067,.11,.153),(s*.067,.25,.143),(s*.072,.33,.122)],.0014,seam,chest)
        curve('Jacket_shoulder_seam_'+label,[(s*.071,.37,.102),(s*.160,.368,.096),(s*.228,.326,.052),(s*.252,.295,-.019)],.0015,seam,chest)
        # Thigh/shin fold families follow contact and compression, with unequal sides.
        x=s*.139
        remove(['Canvas_leg_'+label])
        def trouser_fold(y,t):
            cuff=.010*math.sin(7*t+24*y+s)*math.exp(-((y-.225)/.038)**2)
            knee=.009*math.cos(4*t-32*y+s*.7)*math.exp(-((y-.36)/.057)**2)
            return cuff+knee+.003*math.sin(3*t+7*y)
        loft('Canvas_leg_'+label,[(.181,.076,.082,x,.002),(.215,.094,.102,x,.001),(.29,.106,.106,x,.007),
            (.36,.110,.108,x,.007),(.45,.116,.112,x,0),(.54,.123,.116,x,0),(.617,.118,.118,x,0)],pants,root,
            n=64,rows=64,fold=trouser_fold)
        curve('Trouser_side_seam_'+label,[(s*.246,.572,-.022),(s*.259,.49,-.024),(s*.248,.36,-.014),(s*.236,.26,-.003),(s*.20,.197,.012)],.0012,seam,root)
        # Boot shaft panel seam and ankle compression describe footwear construction.
        remove(['Boot_foot_'+label,'Boot_front_seam_'+label])
        loft('Boot_foot_'+label,[(.034,.087,.135,0,.05),(.052,.094,.142,0,.057),(.090,.093,.139,0,.056),
             (.120,.085,.124,0,.043),(.153,.073,.091,0,.005)],bpy.data.materials['Burgundy rubber boots'],root,
             n=64,rows=40,pos=(x,0,0))
        for prefix in ['Boot_shaft_']:
            ob=bpy.data.objects[prefix+label];weld(ob)
            mod=ob.modifiers.new('Leather soft form','SUBSURF');mod.levels=1
        for prefix in ['Boot_sole_','Glove_wrist_']:
            ob=bpy.data.objects[prefix+label];weld(ob);bevel(ob,.004)
        curve('Boot_shaft_seam_'+label,[(x-.051,.191,.055),(x-.05,.150,.06),(x-.052,.115,.083),(x-.046,.091,.15)],.0015,seam,root)
    # Continuous trouser pelvis-to-leg transition replaces the exposed capped cylinders.
    remove(['Trouser_pelvis'])
    sphere('Trouser_pelvis',(0,.613,0),(.226,.085,.149),pants,root)
    objects=[bpy.data.objects[n] for n in ['Trouser_pelvis','Canvas_leg_Right','Canvas_leg_Left']]
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:ob.select_set(True)
    bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
    ob=objects[0];ob.name='Trousers_continuous';ob.data.remesh_voxel_size=.006
    bpy.ops.object.voxel_remesh()
    mod=ob.modifiers.new('Connected garment fairing','SMOOTH');mod.factor=.5;mod.iterations=3
    for p in ob.data.polygons:p.use_smooth=True

def build_gloves(ink,lining,seam):
    for s,label in [(-1,'Right'),(1,'Left')]:
        wrist=bpy.data.objects['Wrist_'+label]
        remove(['Glove_palm_'+label,'Glove_thumb_'+label]+['Glove_stitch_'+label+str(i) for i in range(3)])
        sphere('Glove_palm_'+label,(0,-.05,.005),(.058,.065,.045),ink,wrist)
        # Four staggered digits: relaxed right hand, hooked left grip around lamp handle.
        for i in range(4):
            x=(i-1.5)*.024
            length=[.060,.075,.070,.052][i]
            if label=='Left':
                pts=[(x,-.081,.016),(x,-.106,.046),(x,-.129,.045),(x,-.132,.021),(x,-.116,.011)]
            else:pts=[(x,-.080,.014),(x+s*.004,-.110,.020),(x+s*.007,-.080-length,.029),(x+s*.008,-.089-length,.036)]
            curve('Glove_finger_'+label+str(i),pts,.013,ink,wrist)
            curve('Finger_seam_'+label+str(i),[(x,-.072,.047),(x,-.090,.048),(x,-.108,.045)],.0008,seam,wrist)
        curve('Glove_thumb_'+label,[(-s*.04,-.035,.029),(-s*.064,-.056,.041),(-s*.071,-.084,.057),(-s*.057,-.10,.063)],.019,ink,wrist)

def setup_scene():
    sc=bpy.context.scene;sc.frame_set(0);sc.render.engine='CYCLES';sc.cycles.samples=32
    sc.cycles.use_denoising=True
    sc.render.resolution_x=1200;sc.render.resolution_y=1500;sc.render.resolution_percentage=100
    sc.view_settings.view_transform='Standard';sc.view_settings.look='None';sc.view_settings.exposure=0
    sc.world.use_nodes=True
    bg=next(n for n in sc.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.22,.235,.25,1);bg.inputs[1].default_value=.65
    cd=bpy.data.cameras.new('InspectionCamera');cd.type='ORTHO';cd.ortho_scale=2.0
    cam=bpy.data.objects.new('InspectionCamera',cd);sc.collection.objects.link(cam);sc.camera=cam
    for name,power,size,loc in [('Key',210,4,(-3,-4,5)),('Fill',120,3,(3,-1,3)),('Rim',180,3,(0,3,4))]:
        ld=bpy.data.lights.new(name,'AREA');ld.energy=power;ld.shape='DISK';ld.size=size
        ob=bpy.data.objects.new(name,ld);sc.collection.objects.link(ob);ob.location=loc
        ob.rotation_euler=(Vector((0,0,1))-ob.location).to_track_quat('-Z','Y').to_euler()
    return sc,cam
def render_view(name,direction,target=(0,0,.84),scale=2.0,size=(900,1100),folder=None):
    sc=bpy.context.scene;cam=sc.camera;cam.data.ortho_scale=scale
    cam.location=Vector(target)+Vector(direction).normalized()*8
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()
    sc.render.resolution_x,sc.render.resolution_y=size
    sc.render.filepath=str((folder or ASSET/'preview')/(name+'.png'));bpy.ops.render.render(write_still=True)

def main():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(OLD/'hari_lighting.glb'))
    sc=bpy.context.scene;sc.frame_set(0)
    for ob in list(bpy.data.objects):
        if ob.type=='MESH':weld(ob)
    head=bpy.data.objects['HeadNod'];chest=bpy.data.objects['ChestPivot'];root=bpy.data.objects['HariLightingCrew']
    bpy.data.objects['HeadPivot'].location.z=.42
    head.scale=(.9,.9,.9)
    skin=material('Skin_painted_ochre',(.72,.49,.34),.86)
    ink=material('Warm_charcoal_ink',(.055,.049,.064),.9)
    hair=material('Navy_hair_pigment',(.105,.126,.20),.86)
    flow=material('Navy_selected_flow',(.16,.185,.27),.9)
    white=material('Warm_eye_white',(.88,.83,.74),.65)
    iris=material('Umber_iris',(.20,.105,.056),.6)
    blush=material('Rose_ochre_accents',(.48,.245,.19),.9)
    cloth=material('Mustard_canvas_pigment',(.75,.53,.23),.95)
    lining=material('Mustard_rolled_facing',(.81,.62,.34),.97)
    pants=material('Moss_canvas_pigment',(.30,.34,.255),.97)
    seam=material('Tailoring_ink',(.23,.205,.145),.95)
    build_external_head(head,skin,ink,hair,white,iris,blush)
    build_hair(head,hair,flow,ink)
    garment_details(chest,root,cloth,lining,pants,seam,ink)
    build_gloves(ink,lining,seam)
    for ob in bpy.data.objects:
        if ob.type=='MESH' and ob.name.startswith(('Neck','Forearm')):ob.data.materials.clear();ob.data.materials.append(skin)
        if ob.type=='MESH' and ob.name.startswith(('Rolled_cuff','Pocket_flap','Glove_patch')):ob.data.materials.clear();ob.data.materials.append(lining)
    # Apply construction modifiers to export-ready meshes. Author paths remain in script.
    for ob in list(bpy.data.objects):
        if ob.hide_render:continue
        if ob.type=='CURVE':activate(ob);bpy.ops.object.convert(target='MESH')
        if ob.type=='MESH':
            activate(ob)
            for mod in list(ob.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
            weld(ob)
    setup_scene()
    # Lighting is diffuse and consistent across every inspection view.
    for name,d in [('front',(0,-1,0)),('left',(-1,0,0)),('right',(1,0,0)),('back',(0,1,0)),('hero',(.45,-1,.15))]:
        render_view('shape_'+name,d)
    render_view('shape_face',(.10,-1,.03),(0,-.015,1.37),.80,(1000,1000))
    render_view('shape_hair_back',(.25,1,.1),(0,0,1.40),.83,(1000,1000))
    # One shared, nonoverlapping atlas over all rendered objects.
    bpy.ops.object.select_all(action='DESELECT')
    rendered=[ob for ob in bpy.data.objects if ob.type=='MESH' and not ob.hide_render]
    for ob in rendered:ob.select_set(True)
    bpy.context.view_layer.objects.active=rendered[0]
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.002)
    bpy.ops.object.mode_set(mode='OBJECT')
    sc=bpy.context.scene;sc.frame_set(0)
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'hari_ink_shape.blend'))
    print('HARI_INK_SHAPE_SAVED',flush=True)

if __name__=='__main__':main()
