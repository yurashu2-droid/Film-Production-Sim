"""Grouped front/rear visual contact sheet, exported GLBs only."""
from pathlib import Path
import bpy,json,math,sys
from mathutils import Vector
source=(Path(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else Path(__file__).parent).resolve()
rows=json.loads((source/'build_manifest.json').read_text())
root=source.parents[4];assets=source.parents[1]/'scrap'
bpy.ops.wm.read_factory_settings(use_empty=True)
for i,row in enumerate(rows):
    before=set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(assets/row['file']))
    obs=list(set(bpy.context.scene.objects)-before);bpy.context.view_layer.update()
    pts=[o.matrix_world@v.co for o in obs if o.type=='MESH' for v in o.data.vertices]
    lo=Vector([min(p[j] for p in pts) for j in range(3)]);hi=Vector([max(p[j] for p in pts) for j in range(3)])
    scale=1.65/max(hi-lo);offset=Vector(((i%4)*2.4,(i//4)*2.65,0))
    for o in obs:
        if o.type=='MESH':
            mw=o.matrix_world.copy()
            for v in o.data.vertices:v.co=(mw@v.co-Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z)))*scale+offset
            o.matrix_world.identity()
    bpy.ops.object.text_add(location=offset+Vector((-.75,-.9,.02)))
    o=bpy.context.object;o.data.body=row['original_file'].split('_')[0];o.data.size=.18
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12;scene.cycles.use_denoising=True
scene.render.resolution_x=1300;scene.render.resolution_y=1300;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio');scene.world.color=(.38,.38,.38)
scene.view_settings.view_transform='AgX'
for pos,power,size in [((-3,-4,12),2000,8),((10,4,10),1700,7),((4,12,8),1600,6)]:
    data=bpy.data.lights.new('Broad studio','AREA');data.energy=power;data.shape='DISK';data.size=size
    o=bpy.data.objects.new('Light',data);bpy.context.collection.objects.link(o);o.location=pos
    o.rotation_euler=(Vector((3.6,3.6,0))-o.location).to_track_quat('-Z','Y').to_euler()
target=Vector((3.6,(math.ceil(len(rows)/4)-1)*1.325,.7))
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=max(12,math.ceil(len(rows)/4)*3)
scene.camera=cam
for name,direction in [('front',Vector((3,-9,8))),('rear',Vector((-3,9,8)))]:
    cam.location=target+direction;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(root/'artifacts/props-refresh-all'/('furniture_'+source.parents[0].name+'_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
