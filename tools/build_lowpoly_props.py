"""Build reference props with the approved lower polygon authoring settings.
Blender --background --factory-startup --python tools/build_lowpoly_props.py -- rebuild_household_a
"""
from pathlib import Path
import importlib.util
import sys
import types
import bpy

ROOT=Path(__file__).resolve().parents[1]
group=sys.argv[sys.argv.index('--')+1]
source=ROOT/'godot/assets/production'/group/'source/build_assets.py'
spec=importlib.util.spec_from_file_location('selected_prop_group',source)
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
h,f=module.h,module.f

def cap(original,parameter,limit):
    import inspect
    signature=inspect.signature(original)
    from functools import wraps
    @wraps(original)
    def wrapped(*args,**kwargs):
        bound=signature.bind(*args,**kwargs);bound.apply_defaults()
        bound.arguments[parameter]=min(bound.arguments[parameter],limit)
        return original(*bound.args,**bound.kwargs)
    return wrapped

replacements={h.cylinder:cap(h.cylinder,'vertices',16),
              h.tube:cap(h.tube,'sides',6),
              h.ellipsoid:cap(cap(h.ellipsoid,'segments',16),'rings',8),
              f.lathe:cap(f.lathe,'sides',24)}
# Apply to aliases in the selected group and its helper chain, not older assets.
seen=set()
def patch(target):
    if id(target) in seen:return
    seen.add(id(target))
    for key,value in list(vars(target).items()):
        if isinstance(value,types.FunctionType) and value in replacements:
            setattr(target,key,replacements[value])
        elif isinstance(value,types.ModuleType) and key in ('a','b','f','h'):
            patch(value)
patch(module)
# One bevel segment gives readable deliberate edges instead of dense roundovers.
def finish(obj,mat,bevel=0.,smooth=True):
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active=obj
    if bevel:
        mod=obj.modifiers.new('Single bevel edge','BEVEL')
        mod.width=bevel;mod.segments=1;mod.limit_method='ANGLE'
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for face in obj.data.polygons:face.use_smooth=True
        mod=obj.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');mod.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    h.PARTS.append(obj)
    return obj
h.finish=finish
# Bake furniture beam rotations: Godot measures transformed mesh AABBs.
# Leaving a diagonal board as a rotated local box inflates its bounds and
# makes the normalized chair float despite correctly grounded vertices.
if group=='rebuild_furniture_a':
    export=h.export_asset
    def export_baked(filename):
        bpy.context.view_layer.update()
        for obj in h.PARTS:
            obj.data.transform(obj.matrix_world)
            obj.matrix_world.identity()
        bpy.context.view_layer.update()
        return export(filename)
    h.export_asset=export_baked
# Godot owns matched runtime previews; avoid redundant studio rendering.
if group=='rebuild_furniture_a':module.preview=lambda *args:None
sys.argv=[sys.argv[0]]
module.main()
