from pathlib import Path
import bpy,json,math,sys
from mathutils import Vector
SOURCE=Path(__file__).resolve().parent
ROOT=SOURCE.parents[4]
OUT=ROOT/'artifacts/rebuild-architecture'
rows=json.loads((SOURCE/'build_manifest.json').read_text())
requested=set(sys.argv[sys.argv.index('--')+1:]) if '--' in sys.argv else set()
for row in rows:
 name=row['original_file']
 if requested and name not in requested:continue
 bpy.ops.wm.open_mainfile(filepath=str(OUT/(name+'_rebuilt.blend')))
 scene=bpy.context.scene;scene.render.engine='BLENDER_WORKBENCH'
 scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100
 scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True
 scene.display.shading.show_cavity=True;scene.display.shading.cavity_type='BOTH';scene.display.shading.curvature_ridge_factor=1.3;scene.display.shading.curvature_valley_factor=1.0
 scene.display.shading.background_type='WORLD';scene.world=bpy.data.worlds.new('Preview gray world');scene.world.color=(.58,.60,.61)
 scene.view_settings.view_transform='Standard'
 low=Vector(row['blender_bounds_min']);high=Vector(row['blender_bounds_max']);size=high-low;target=(low+high)/2;extent=max(size)
 bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=extent*1.40;scene.camera=cam
 for view,direction in [('front',(3,-5,3)),('rear',(-3,5,3))]:
  cam.location=target+Vector(direction)*extent;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
  scene.render.filepath=str(OUT/(name+'_'+view+'.png'));bpy.ops.render.render(write_still=True)
 print('PREVIEW',name,flush=True)
