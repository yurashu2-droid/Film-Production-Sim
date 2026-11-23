"""Render the actual model as pixel-registered image-edit targets; retain UV data."""
from pathlib import Path
import bpy,json,math,sys,numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parent;ASSET=HERE.parent
ROOT=ASSET.parents[3];TEMP=ROOT/'artifacts/hari-ink';TEMP.mkdir(parents=True,exist_ok=True)
sys.path.insert(0,str(HERE));from build_hari_ink import render_view
sc=bpy.context.scene;sc.frame_set(0)
objects=[o for o in sc.objects if o.type=='MESH' and not o.hide_render]
# Replace the output with evenly lit pigment + local AO. No key/rim light is baked.
for m in {m for o in objects for m in o.data.materials if m}:
    if not m.use_nodes:continue
    nt=m.node_tree;bs=next((n for n in nt.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if not bs:continue
    ao=nt.nodes.new('ShaderNodeAmbientOcclusion');ao.inputs['Distance'].default_value=.045
    if bs.inputs['Base Color'].is_linked:nt.links.new(bs.inputs['Base Color'].links[0].from_socket,ao.inputs['Color'])
    else:ao.inputs['Color'].default_value=bs.inputs['Base Color'].default_value
    em=nt.nodes.new('ShaderNodeEmission');nt.links.new(ao.outputs['Color'],em.inputs['Color'])
    out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');nt.links.new(em.outputs[0],out.inputs['Surface'])
sc.cycles.samples=20;sc.cycles.use_denoising=True
bg=next(n for n in sc.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.12,.13,.14,1);bg.inputs[1].default_value=1
views=[dict(name='front',direction=[0,-1,0],right=[1,0,0]),dict(name='back',direction=[0,1,0],right=[-1,0,0]),
       dict(name='left',direction=[-1,0,0],right=[0,-1,0]),dict(name='right',direction=[1,0,0],right=[0,1,0])]
for view in views:
    view.update(center=[.055,0,.835],vertical_m=2.35,width=512,height=1024)
    render_view('guide_'+view['name'],view['direction'],tuple(view['center']),2.35,(512,1024),ASSET/'reference')
render_view('guide_face',[0,-1,0],(0,-.055,1.40),.83,(1024,1024),ASSET/'reference')
meta=dict(views=views,face=dict(center=[0,-.055,1.40],vertical_m=.83,width=1024,height=1024,direction=[0,-1,0],right=[1,0,0]),
          pose='frame 0',registered_model='hari_ink_shape.blend',method='Unlit pigment with local ambient occlusion; four actual orthographic cameras')
(ASSET/'reference/guide_cameras.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
# World-space geometry + actual UVs, then visibility toward the same cameras.
world_v=[];world_f=[];records=[];offset=0
for ob in objects:
    me=ob.data;me.calc_loop_triangles();mw=np.array(ob.matrix_world)
    co=np.empty(len(me.vertices)*3,np.float32);me.vertices.foreach_get('co',co);co=co.reshape(-1,3)
    co=co@mw[:3,:3].T+mw[:3,3]
    no=np.empty(len(me.vertices)*3,np.float32);me.vertices.foreach_get('normal',no);no=no.reshape(-1,3)@np.linalg.inv(mw[:3,:3])
    no/=np.maximum(np.linalg.norm(no,axis=1,keepdims=True),1e-9)
    tri=np.empty(len(me.loop_triangles)*3,np.int32);me.loop_triangles.foreach_get('vertices',tri);tri=tri.reshape(-1,3)
    tl=np.empty(len(me.loop_triangles)*3,np.int32);me.loop_triangles.foreach_get('loops',tl);tl=tl.reshape(-1,3)
    uv=np.empty(len(me.loops)*2,np.float32);me.uv_layers.active.data.foreach_get('uv',uv);uv=uv.reshape(-1,2)
    colors=[]
    for t in me.loop_triangles:
        mat=me.materials[t.material_index]
        bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        c=bs.inputs['Base Color'].default_value[:3] if bs else (.2,.2,.2)
        colors.append(c)
    records.append((ob.name,co,no,tri,uv[tl],np.array(colors,np.float32)))
    world_v.extend(co);world_f.extend(tri+offset);offset+=len(co)
bvh=BVHTree.FromPolygons(world_v,world_f,all_triangles=True,epsilon=.00001)
P=[];N=[];UV=[];VIS=[];C=[];IDs=[];names=[]
for oi,(name,co,no,tri,uv,colors) in enumerate(records):
    vis=np.zeros((len(co),4),np.float32)
    for k,view in enumerate(views):
        d=np.array(view['direction'],float)
        for vi in np.where(no@d>.015)[0]:
            hit=bvh.ray_cast(Vector(co[vi]+d*.0005),Vector(d),5)
            vis[vi,k]=1 if hit[0] is None else 0
    P.append(co[tri]);N.append(no[tri]);UV.append(uv);VIS.append(vis[tri]);C.append(colors);IDs.append(np.full(len(tri),oi,np.int32));names.append(name)
    if oi%25==0:print('UV_PROJECT_RECORD',oi,name,flush=True)
np.savez_compressed(TEMP/'paint_geometry.npz',positions=np.concatenate(P),normals=np.concatenate(N),uv=np.concatenate(UV),
                    visibility=np.concatenate(VIS),colors=np.concatenate(C),ids=np.concatenate(IDs),names=np.array(names))
print('REGISTERED_PAINT_GUIDES_OK triangles',sum(len(x) for x in P),flush=True)
