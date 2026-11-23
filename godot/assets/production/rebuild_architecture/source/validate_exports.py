from pathlib import Path
import bpy,json,math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
SOURCE=Path(__file__).resolve().parent;ROOT=SOURCE.parents[4]
rows=json.loads((SOURCE/'build_manifest.json').read_text())
checks=[]
for row in rows:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(ROOT/'godot/assets/production/scrap'/row['file']))
 bpy.context.view_layer.update()
 vertices=[];faces=[]
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  off=len(vertices);vertices.extend(o.matrix_world@v.co for v in o.data.vertices);faces.extend(tuple(off+i for i in p.vertices) for p in o.data.polygons)
 low=[min(p[i] for p in vertices) for i in range(3)];high=[max(p[i] for p in vertices) for i in range(3)]
 err=max(abs(a-b) for a,b in zip(low+high,row['original_transformed_envelope']['min']+row['original_transformed_envelope']['max']))
 assert err<1e-5,(row['file'],err)
 anchor=next(o for o in bpy.context.scene.objects if o.name=='DisposalTicketAnchor');a=anchor.matrix_world.translation
 assert max(abs(v) for v in anchor.rotation_euler)<1e-5
 scale=row['normalization_size']/max(high[i]-low[i] for i in range(3));hw=.065/scale;hh=.0425/scale
 bvh=BVHTree.FromPolygons(vertices,faces,all_triangles=False)
 deltas=[];missing=0
 for dx in (-hw,0,hw):
  for dz in (-hh,0,hh):
   pos,normal,idx,dist=bvh.ray_cast(Vector((a.x+dx,low[1]-2,a.z+dz)),Vector((0,1,0)))
   if pos is None:missing+=1
   else:deltas.append(round(pos.y-a.y,5))
 assert missing==0,(row['file'],'unsupported sticker sample')
 assert min(deltas)>0,(row['file'],'sticker clips',deltas)
 check={'file':row['file'],'bounds_error_max':err,'ticket_clearances':deltas,'ticket_missing_support_samples':missing,'ticket_anchor':list(a)};checks.append(check)
 print('CHECK',row['original_file'], 'envelope',round(err,8),'ticket',deltas,'missing',missing,flush=True)
(SOURCE/'export_validation.json').write_text(json.dumps(checks,indent=2))
