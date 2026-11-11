# -*- coding: utf-8 -*-
# ドローン（drone_pop.blend）を、ゲーム用の glb に書き出す。
#   blender -b drone_pop.blend -P blend_export.py -- <出力.glb>
# ・照明・カメラ・背景・光の筒（ゲーム側で描く）は外す
# ・手続きの材質は書き出せないので、つながりを外して、元の色・ざらつきの値だけにする
# ・面を減らす（胴 21万 → 2万ほど）。羽根 4 つは回すので別の物のまま、ほかは 1 つにまとめる
import bpy, sys
out = sys.argv[sys.argv.index("--") + 1]
DROP = {"hover_beam", "cyclorama"}
for o in list(bpy.data.objects):
    if o.type != 'MESH' or o.name in DROP:
        if o.name != "drone_root":
            bpy.data.objects.remove(o, do_unlink=True)

# 材質：色・ざらつきのつながりを外す。光る強さは、にじみすぎないよう抑える
for m in bpy.data.materials:
    if not m.node_tree:
        continue
    for n in m.node_tree.nodes:
        if n.type != 'BSDF_PRINCIPLED':
            continue
        for name in ("Base Color", "Roughness", "Normal", "Metallic", "Alpha"):
            for l in list(n.inputs[name].links):
                m.node_tree.links.remove(l)
        if n.inputs["Emission Strength"].default_value > 2.5:
            n.inputs["Emission Strength"].default_value = 2.5
    if m.name == "lens_glass_m":
        for n in m.node_tree.nodes:
            if n.type == 'BSDF_PRINCIPLED':
                n.inputs["Alpha"].default_value = 0.16
        m.blend_method = 'BLEND'

RATIO = {"chassis": 0.11, "lens_text": 0.35, "canopy": 0.5, "lens_front_glass": 0.25, "lens_mid_glass": 0.25, "lens_rear_glass": 0.25}
view = bpy.context.view_layer
for o in bpy.data.objects:
    if o.type != 'MESH':
        continue
    view.objects.active = o
    for md in o.modifiers:
        if md.type == 'SUBSURF':
            md.levels = 1
            md.render_levels = 1
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.ops.object.convert(target='MESH')
    if o.name in RATIO:
        d = o.modifiers.new("dec", 'DECIMATE')
        d.ratio = RATIO[o.name]
        bpy.ops.object.modifier_apply(modifier="dec")
    # 空の材質の枠を埋める
    for s in o.material_slots:
        if s.material is None:
            s.material = bpy.data.materials["ivory"]
    for p in o.data.polygons:
        p.use_smooth = True

# 羽根のほかを 1 つにまとめる
bpy.ops.object.select_all(action='DESELECT')
rest = [o for o in bpy.data.objects if o.type == 'MESH' and not o.name.startswith("blades_")]
for o in rest:
    o.select_set(True)
view.objects.active = bpy.data.objects["chassis"]
bpy.ops.object.join()
bpy.data.objects["chassis"].name = "body"
tot = 0
for o in bpy.data.objects:
    if o.type == 'MESH':
        o.data.calc_loop_triangles()
        tot += len(o.data.loop_triangles)
        print("OUT", o.name, len(o.data.loop_triangles), [round(v, 3) for v in o.matrix_local.translation])
print("OUT_TOTAL", tot)
bpy.data.objects["drone_root"].location = (0, 0, 0)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_apply=True, export_yup=True, export_animations=False)
print("SAVED", out)
