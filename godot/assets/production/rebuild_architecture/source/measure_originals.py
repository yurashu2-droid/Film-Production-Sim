from pathlib import Path
import bpy,json
root=Path(__file__).resolve().parents[5]
rows=json.loads((root/'godot/docs/PROP_REBUILD_ASSIGNMENTS.json').read_text())['architecture']
out={}
for row in rows:
 bpy.ops.wm.read_factory_settings(use_empty=True)
 bpy.ops.import_scene.gltf(filepath=str(root/'godot/assets/production/scrap'/(row['original_file']+'.glb')))
 bpy.context.view_layer.update()
 points=[o.matrix_world@v.co for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices]
 lo=[min(v[i] for v in points) for i in range(3)]; hi=[max(v[i] for v in points) for i in range(3)]
 out[row['original_file']]={'min':lo,'max':hi}
 print(row['original_file'],[round(x,4) for x in lo],[round(x,4) for x in hi])
(Path(__file__).parent/'original_envelopes.json').write_text(json.dumps(out,indent=2))
