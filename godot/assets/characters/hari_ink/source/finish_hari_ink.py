"""Bind the painted atlas, save a packed native file, export and inspect."""
from pathlib import Path
import bpy,bmesh,json,struct,hashlib,sys,math
from mathutils import Vector
HERE=Path(__file__).resolve().parent;ASSET=HERE.parent
sys.path.insert(0,str(HERE));from build_hari_ink import render_view
sc=bpy.context.scene;sc.frame_set(0);sc.frame_start=0;sc.frame_end=96;sc.render.fps=24
objects=[o for o in sc.objects if o.type=='MESH' and not o.hide_render]
image=bpy.data.images.load(str(ASSET/'textures/hari_pigment_4k.png'));image.colorspace_settings.name='sRGB'
image.pack()
for m in {m for o in objects for m in o.data.materials if m}:
    nt=m.node_tree;bs=next((n for n in nt.nodes if n.type=='BSDF_PRINCIPLED'),None)
    if not bs:continue
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image;tex.label='Registered painted views → shared 4K UV pigment'
    nt.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value=max(.65,bs.inputs['Roughness'].default_value)
    bs.inputs['Metallic'].default_value=min(.3,bs.inputs['Metallic'].default_value)
    out=next(n for n in nt.nodes if n.type=='OUTPUT_MATERIAL');nt.links.new(bs.outputs[0],out.inputs['Surface'])
    m['paint_source']='reference/painted_body_sheet.png + painted_face.png'
outline=bpy.data.materials.new('Native_ink_contour');outline.use_nodes=True;outline.use_backface_culling=True
nt=outline.node_tree;nt.nodes.clear()
out=nt.nodes.new('ShaderNodeOutputMaterial');geo=nt.nodes.new('ShaderNodeNewGeometry')
em=nt.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(.012,.009,.018,1)
transparent=nt.nodes.new('ShaderNodeBsdfTransparent');mix=nt.nodes.new('ShaderNodeMixShader')
nt.links.new(geo.outputs['Backfacing'],mix.inputs[0]);nt.links.new(em.outputs[0],mix.inputs[1]);nt.links.new(transparent.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],out.inputs[0])
hulls=[]
for ob in objects:
    if not ob.name.startswith(('Face_CC0','Hair_coverage','Fringe_wave','Short_side','Rear_panel','Jacket_open','Sleeve_',
        'Rolled_cuff','Trousers_','Boot_','Glove_palm','Lamp_round','Tool_pouch','Cargo_pocket','Chest_pocket')):continue
    hull=ob.copy();hull.data=ob.data.copy();hull.name='Contour_'+ob.name;sc.collection.objects.link(hull)
    hull.data.materials.clear();hull.data.materials.append(outline)
    thickness=.0014 if ob.name.startswith('Face') else .0021
    for v in hull.data.vertices:v.co+=v.normal*thickness
    bm=bmesh.new();bm.from_mesh(hull.data);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(hull.data);bm.free()
    hull['scope']='Inverted hull silhouette; does not replace garment or facial topology.';hulls.append(hull)
sc.cycles.samples=36;sc.cycles.use_denoising=True
# Preserve the authored full assembly in the native deliverable, including the
# hidden CC0 anatomy reference and packed pigment image.
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'HARI_Painted_v02.blend'))
for name,d in [('front',(0,-1,0)),('left',(-1,0,0)),('right',(1,0,0)),('back',(0,1,0)),('hero',(.43,-1,.12))]:
    render_view(name,d,target=(.04,0,.83),scale=2.02,size=(1200,1400))
render_view('face',(.05,-1,.025),target=(0,-.045,1.39),scale=.82,size=(1100,1100))
render_view('face_profile',(1,0,.03),target=(0,-.045,1.39),scale=.82,size=(1100,1100))
render_view('jacket',(.20,-1,.05),target=(0,0,.91),scale=.77,size=(1100,1100))
render_view('boots',(.3,-1,.1),target=(0,-.01,.25),scale=.66,size=(1100,1100))
# glTF is exported with a simple opaque, single-sided contour material.
export_ink=bpy.data.materials.new('Export_ink_contour');export_ink.use_nodes=True;export_ink.use_backface_culling=True
bs=next(n for n in export_ink.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(.012,.009,.018,1);bs.inputs['Roughness'].default_value=1
for hull in hulls:hull.data.materials.clear();hull.data.materials.append(export_ink)
sc.frame_set(0)
samples=[]
for frame in range(0,97,4):
    sc.frame_set(frame)
    samples.append(dict(frame=frame,feet={s:list(bpy.data.objects['Boot_sole_'+s].matrix_world.translation) for s in ['Right','Left']},
        lamp_parent=bpy.data.objects['LampPivot'].parent.name,
        head=list(bpy.data.objects['HeadPivot'].rotation_euler)))
sc.frame_set(0)
bpy.ops.object.select_all(action='DESELECT')
for ob in objects+hulls:ob.select_set(True)
for ob in sc.objects:
    if ob.type=='EMPTY' and not ob.hide_render:ob.select_set(True)
props=bpy.ops.export_scene.gltf.get_rna_type().properties
settings=dict(filepath=str(ASSET/'hari_ink.glb'),export_format='GLB',use_selection=True,export_animations=True,
              export_cameras=False,export_lights=False,export_frame_range=True)
if 'export_animation_mode' in props:
    choices=[i.identifier for i in props['export_animation_mode'].enum_items]
    if 'SCENE' in choices:settings['export_animation_mode']='SCENE'
if 'export_animation_merge' in props:print('ANIMATION_MERGE_OPTIONS',[i.identifier for i in props['export_animation_merge'].enum_items])
bpy.ops.export_scene.gltf(**settings)
# Give the one scene-baked authored loop its established engine clip name.
path=ASSET/'hari_ink.glb';blob=path.read_bytes();jl=struct.unpack_from('<I',blob,12)[0];doc=json.loads(blob[20:20+jl]);rest=blob[20+jl:]
if len(doc.get('animations',[]))==1:doc['animations'][0]['name']='Light_Check'
enc=json.dumps(doc,separators=(',',':')).encode();enc+=b' '*((-len(enc))%4)
path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(enc)+len(rest))+struct.pack('<II',len(enc),0x4e4f534a)+enc+rest)
triangles=sum(len(o.data.loop_triangles) if o.data.loop_triangles else sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)
report=dict(blender=bpy.app.version_string,model_meshes=len(objects),contour_meshes=len(hulls),model_triangles=triangles,
            native='source/HARI_Painted_v02.blend',glb_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
            animations=[a['name'] for a in doc.get('animations',[])],source_head='CC0 Human Base Meshes / Head - Stylized, Julien Kaspar',
            body_reference='CC0 Body Female - Stylized; hidden fitting reference, not the exported skin',
            paint_method='AI-painted actual orthographic guides projected to one 4096px UV atlas',
            movement='Existing four-second rigid-node look-and-nod loop; no new full-body skinning',samples=samples)
(ASSET/'preview/model_evidence.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('HARI_PAINTED_NATIVE_AND_GLB_OK',json.dumps({k:v for k,v in report.items() if k!='samples'}),flush=True)
