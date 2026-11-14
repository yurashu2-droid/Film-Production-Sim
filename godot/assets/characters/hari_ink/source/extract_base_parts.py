"""One-time read-only extraction from the user's official CC0 base bundle."""
from pathlib import Path
import bpy,hashlib,json
HERE=Path(__file__).resolve().parent
LIB=Path('C:/Programer___Amano/遊び場/BaseMeshes/blender_human_base_meshes/human-base-meshes-bundle-v1.4.1/human_base_meshes_bundle.blend')
names=['GEO-head_stylized','GEO-head_stylized.eye.R','GEO-head_stylized.eye.L','GEO-body_female_stylized']
with bpy.data.libraries.load(str(LIB)) as (a,b):b.objects=names
head=next(o for o in b.objects if o.name=='GEO-head_stylized');origin=head.location.copy()
for ob in b.objects:
    ob.animation_data_clear()
    if '.eye.' in ob.name:ob.location-=origin
    else:ob.location=(0,0,0)
    for mod in list(ob.modifiers):ob.modifiers.remove(mod)
    ob['source_author']='Julien Kaspar';ob['source_license']='CC0'
    ob['source_bundle']='Human Base Meshes v1.4.1'
bpy.data.libraries.write(str(HERE/'human_base_parts.blend'),set(b.objects),fake_user=True)
metadata=dict(bundle='Human Base Meshes v1.4.1',author='Julien Kaspar',license='CC0',
    source_url='https://www.blender.org/download/demo-files/',
    source_sha256=hashlib.sha256(LIB.read_bytes()).hexdigest(),
    objects={o.name:dict(vertices=len(o.data.vertices),polygons=len(o.data.polygons),relative_location=list(o.location)) for o in b.objects},
    metadata_evidence='Head - Stylized and Body Female - Stylized collection asset_data inspected in the source bundle',
    usage='Head topology is adapted in the rendered character; full female body is a hidden editable fitting reference.')
(HERE/'base_provenance.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
print('CC0_BASE_PARTS_EXTRACTED',metadata['objects'])
