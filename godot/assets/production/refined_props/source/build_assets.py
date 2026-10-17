"""Build the two name-led reference props in a disposable Blender process.

blender --background --factory-startup --python PATH/TO/build_assets.py
The authoring scene is Z-up/front -Y; glTF export converts to Godot Y-up/front +Z.
"""
from pathlib import Path
import json
import math
import random
import sys
import bpy
from mathutils import Vector

PROJECT = Path(__file__).resolve().parents[4]
SOURCE = Path(__file__).resolve().parent
ASSETS = PROJECT / "assets/production/scrap"
EVIDENCE = PROJECT.parent / "artifacts/prop-refresh-20261017"
TAU = math.tau
PARTS = []
MARKERS = []


def linear(value):
    return value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4


def material(name, color, roughness, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    rgb = tuple(linear(int(color[i:i + 2], 16) / 255) for i in (0, 2, 4))
    shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*rgb, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = (*rgb, 1)
    return mat


def finish(obj, mat, bevel=0.0, smooth=True):
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    if bevel:
        mod = obj.modifiers.new("Crafted edge radii", "BEVEL")
        mod.width = bevel
        mod.segments = 5 if bevel > 0.02 else 3
        mod.limit_method = "ANGLE"
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for face in obj.data.polygons:
            face.use_smooth = True
        mod = obj.modifiers.new("Planar face normals", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        mod.weight = 50
        bpy.ops.object.modifier_apply(modifier=mod.name)
    PARTS.append(obj)
    return obj


def box(name, at, size, mat, bevel=0.004):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # Physical long grain follows the board's long axis on its broad faces.
    if mat.name.startswith("Walnut"):
        uv = obj.data.uv_layers.active
        for face in obj.data.polygons:
            normal = face.normal
            for li in face.loop_indices:
                p = obj.data.vertices[obj.data.loops[li].vertex_index].co
                if abs(normal.x) > 0.5:
                    u, v = p.y / max(size[1], 0.001), p.z / max(size[2], 0.001)
                elif abs(normal.z) > 0.5:
                    u, v = p.x / max(size[0], 0.001), p.y / max(size[1], 0.001)
                else:
                    u, v = p.x / max(size[0], 0.001), p.z / max(size[2], 0.001)
                uv.data[li].uv = (u * 1.7 + 0.5, v * 0.23 + at[2] * 0.9 + 0.5)
    return finish(obj, mat, bevel)


def cylinder(name, at, radius, length, mat, direction=(0, 0, 1), vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_euler = Vector(direction).to_track_quat("Z", "Y").to_euler()
    return finish(obj, mat, min(radius * 0.18, 0.0015))


def ellipsoid(name, at, scale, mat, segments=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=at)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, mat)


def tube(name, points, radius, mat, cyclic=False, sides=8):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = radius
    curve.bevel_resolution = max(1, sides // 4)
    curve.use_fill_caps = True
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for item, point in zip(spline.points, points):
        item.co = (*point, 1)
    spline.use_cyclic_u = cyclic
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    curve.materials.append(mat)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    for face in obj.data.polygons:
        face.use_smooth = True
    PARTS.append(obj)
    return obj


def extruded_profile(name, points_xz, y, thickness, mat, bevel=0.002):
    n = len(points_xz)
    vertices = [(x, y - thickness / 2, z) for x, z in points_xz]
    vertices += [(x, y + thickness / 2, z) for x, z in points_xz]
    faces = [tuple(reversed(range(n))), tuple(range(n, n * 2))]
    faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="UVMap")
    for face in mesh.polygons:
        for li in face.loop_indices:
            p = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv = (p.x * 3.0 + 0.5, p.z * 0.6 + 0.25)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, mat, bevel)


def curved_strip(name, x0, x1, angle0, angle1, outer, inner, base, mat, steps=12):
    vertices = []
    for x in (x0, x1):
        for radius in (outer, inner):
            for i in range(steps + 1):
                theta = angle0 + (angle1 - angle0) * i / steps
                vertices.append((x, radius * math.sin(theta), base + radius * math.cos(theta)))
    n = steps + 1
    faces = []
    for i in range(steps):
        faces += [(i, i + 1, 2*n+i+1, 2*n+i), (n+i, 3*n+i, 3*n+i+1, n+i+1)]
        faces += [(i, n+i, n+i+1, i+1), (2*n+i, 2*n+i+1, 3*n+i+1, 3*n+i)]
    faces += [(0, 2*n, 3*n, n), (n-1, 2*n-1, 4*n-1, 3*n-1)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    uv = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            p = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv = ((p.x + 0.35) / 0.7 * 1.7, math.atan2(p.y, p.z - base) * 0.3 + 0.5)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, mat, 0.0012)


def rivet(at, mat, side="front", radius=0.0065):
    scale = {"front": (radius, radius * 0.4, radius), "side": (radius * 0.4, radius, radius), "top": (radius, radius, radius * 0.4)}[side]
    return ellipsoid("Peened rivet", at, scale, mat, 12, 6)


def ticket_anchor(at):
    obj = bpy.data.objects.new("DisposalTicketAnchor", None)
    bpy.context.collection.objects.link(obj)
    obj.location = at
    # glTF converts empty-node coordinates too; its identity +Z is Godot's front.
    obj.rotation_euler.x = 0
    MARKERS.append(obj)


def build_chest():
    wood = material("Walnut boards", "8D4A28", 0.53)
    shader = next(n for n in wood.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    tex = wood.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(SOURCE.parent / "walnut_albedo.png"))
    wood.node_tree.links.new(tex.outputs["Color"], shader.inputs["Base Color"])
    brass = material("Aged brass reinforcement", "B28A48", 0.34, 1.0)
    edge = material("Polished brass edges", "D1AA61", 0.26, 1.0)
    dark = material("Recesses and iron pins", "30271F", 0.68, 0.75)
    # Body: separate full-thickness planks, not wood painted on one cube.
    for row in range(4):
        z = 0.074 + row * 0.073
        for y in (-0.214, 0.214):
            box("Joined horizontal walnut plank", (0, y, z), (0.66, 0.025, 0.070), wood, 0.0025)
        for x in (-0.318, 0.318):
            box("End wall board", (x, 0, z), (0.025, 0.405, 0.070), wood, 0.0025)
    box("Solid bottom panel", (0, 0, 0.038), (0.65, 0.43, 0.025), wood)
    box("Dark lid seating rebate", (0, 0, 0.334), (0.65, 0.43, 0.008), dark, 0.001)
    base, radius = 0.343, 0.218
    for slat in range(9):
        a0 = -math.pi/2 + slat * math.pi/9 + 0.004
        a1 = -math.pi/2 + (slat+1) * math.pi/9 - 0.004
        curved_strip("Arched lid walnut stave", -0.33, 0.33, a0, a1, radius, radius-0.018, base, wood, 4)
    # Three short curved end boards have the same grain and joints as the body.
    # Their profiles follow the arch rather than leaving an untextured cap.
    for sign in (-1, 1):
        for row in range(3):
            lo = radius * row / 3 + 0.001
            hi = radius * (row+1) / 3 - 0.001
            edge_samples = []
            for i in range(9):
                height = lo + (hi-lo)*i/8
                edge_samples.append((math.sqrt(max(0,radius*radius-height*height)),base+height))
            pts = edge_samples + [(-x,z) for x,z in reversed(edge_samples)]
            obj = extruded_profile("Joined arched end plank", pts, sign*0.317, 0.019, wood, 0.0015)
            obj.rotation_euler.z = math.pi/2
    # Three continuous straps wrap the lid, joining vertical body straps.
    for x in (-0.27, 0, 0.27):
        curved_strip("Lid brass hoop", x-0.018, x+0.018, -math.pi/2, math.pi/2, 0.225, 0.217, base, brass, 28)
        for y in (-0.232, 0.232):
            box("Body brass strap", (x, y, 0.18), (0.035, 0.009, 0.298), brass, 0.002)
            for z in (0.065, 0.17, 0.29, 0.333):
                rivet((x, y + (-0.006 if y < 0 else 0.006), z), edge)
        for a in (-0.8, 0, 0.8):
            rivet((x, 0.228*math.sin(a), base+0.228*math.cos(a)), edge, "top")
    for y in (-0.231, 0.231):
        for z in (0.052, 0.317):
            box("Brass horizontal rail", (0, y, z), (0.66, 0.009, 0.025), brass, 0.002)
    for x in (-0.333, 0.333):
        for z in (0.052, 0.317):
            box("End rail", (x, 0, z), (0.009, 0.438, 0.025), brass, 0.002)
        for y in (-0.201, 0.201):
            for z in (0.07, 0.303):
                box("Folded corner guard", (x, y, z), (0.012, 0.062, 0.057), brass)
                rivet((x + (0.009 if x > 0 else -0.009), y, z), edge, "side")
        box("Ring handle mounting plate", (x, 0, 0.212), (0.014, 0.073, 0.075), brass, 0.005)
        cylinder("Handle pivot barrel", (x*1.025, 0, 0.228), 0.009, 0.038, edge, (0, 1, 0))
        ring = [(x*1.06, 0.047*math.sin(a), 0.176+0.048*math.cos(a)) for a in [i*TAU/40 for i in range(40)]]
        tube("Cast brass carrying ring", ring, 0.007, brass, True)
    # Two rear hinge leaves and their actual horizontal pivot pins.
    for x in (-0.235, 0.235):
        box("Rear hinge leaf", (x, 0.239, 0.336), (0.073, 0.011, 0.068), brass)
        cylinder("Rear hinge pin", (x, 0.247, 0.343), 0.009, 0.077, edge, (1, 0, 0))
        for xx in (-0.021, 0.021):
            for zz in (0.312, 0.361):
                rivet((x+xx, 0.248, zz), edge, radius=0.0045)
    # A shaped hasp with a real keyhole through the metal.
    profile = [(-0.026,0.376),(0.026,0.376),(0.026,0.314),(0.034,0.289),(0.024,0.259),(0,0.247),(-0.024,0.259),(-0.034,0.289),(-0.026,0.314)]
    hasp = extruded_profile("Pierced shaped lock hasp", profile, -0.25, 0.012, brass)
    cutters = []
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.010, depth=0.08, location=(0,-0.25,0.287), rotation=(math.pi/2,0,0))
    cutters.append(bpy.context.object)
    cutter = extruded_profile("Keyhole slot cutter", [(-0.005,0.286),(0.005,0.286),(0.008,0.264),(-0.008,0.264)], -0.25, 0.08, dark, 0)
    PARTS.remove(cutter)
    cutters.append(cutter)
    for cutter in cutters:
        bpy.context.view_layer.objects.active = hasp
        mod = hasp.modifiers.new("Pierce keyhole", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.object = cutter
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cutter, do_unlink=True)
    cylinder("Hasp upper hinge", (0,-0.258,0.37), 0.010, 0.063, edge, (1,0,0))
    for x in (-0.284, 0.284):
        for y in (-0.174, 0.174):
            box("Short metal-shod foot", (x,y,0.022), (0.069,0.070,0.044), dark)
            box("Foot brass shoe", (x,y,0.012), (0.071,0.072,0.013), brass, 0.002)
    ticket_anchor((0.14,-0.227,0.22))


def build_fridge():
    ivory = material("Ivory enamel cabinet", "E7D8B7", 0.32)
    red = material("Burgundy enamel doors", "773638", 0.26)
    chrome = material("Polished chrome fittings", "CDCED0", 0.23, 1.0)
    steel = material("Brushed steel plinth", "9B9C9B", 0.40, 1.0)
    rubber = material("Rubber gaskets and feet", "222326", 0.77)
    dark = material("Rear pressed metal", "42413E", 0.55, 0.7)
    copper = material("Copper refrigerant lines", "9C6036", 0.37, 1.0)
    # Main shell and doors retain generous planar areas between controlled rounds.
    box("Enamel cabinet shell", (0,0.015,0.744), (0.68,0.53,1.272), ivory, 0.060)
    for z, height in ((1.169,0.342), (0.587,0.778)):
        box("Continuous black rubber door seal", (0,-0.258,z), (0.613,0.027,height+0.023), rubber, 0.035)
        box("Fine chrome door edge", (0,-0.274,z), (0.604,0.030,height+0.012), chrome, 0.034)
        box("Formed burgundy enamel door", (0,-0.291,z), (0.592,0.103,height), red, 0.034)
        # Horizontal sculpted pull handles have roots attached to the actual door.
        box("Handle rubber backing", (-0.229,-0.345,z+0.015), (0.050,0.008,0.096), rubber, 0.008)
        box("Chromed handle escutcheon", (-0.229,-0.351,z+0.015), (0.046,0.009,0.092), chrome, 0.008)
        box("Handle cast neck", (-0.221,-0.371,z+0.012), (0.031,0.045,0.033), chrome, 0.007)
        ellipsoid("Tapered horizontal chrome handle", (-0.152,-0.397,z+0.013), (0.094,0.021,0.018), chrome, 24, 10)
        for zz in (-0.019,0.049):
            rivet((-0.229,-0.358,z+zz), chrome, radius=0.0035)
        for zz in (z-height*0.33,z+height*0.33):
            box("Hinge body leaf", (0.314,-0.230,zz), (0.026,0.042,0.060), chrome, 0.005)
            box("Hinge door leaf", (0.297,-0.285,zz), (0.021,0.052,0.053), chrome, 0.004)
            cylinder("External hinge barrel", (0.318,-0.270,zz), 0.010, 0.068, chrome)
            for gap in (-0.015,0.015):
                cylinder("Hinge knuckle seam", (0.318,-0.270,zz+gap), 0.0105, 0.0018, dark)
    box("Folded brushed metal kick plate", (0,-0.265,0.135), (0.605,0.026,0.081), steel, 0.009)
    for x in (-0.266,0.266):
        rivet((x,-0.281,0.135), chrome, radius=0.004)
    # Small supported chips expose the cream primer at a few handling edges.
    for i, (x,z,length) in enumerate([(-0.250,0.237,0.012),(-0.244,0.253,0.007),(0.252,0.225,0.010),(0.249,1.038,0.006)]):
        y = -0.3431
        pts = [(x-length/2,z),(x-length*0.25,z+0.004),(x+length*0.45,z+0.002),(x+length/2,z-0.003),(x,z-0.005)]
        extruded_profile("Selective enamel chip %d" % i, pts, y, 0.0005, ivory, 0)
    for x in (-0.251,0.251):
        for y in (-0.177,0.196):
            cylinder("Rubber leveling foot", (x,y,0.040), 0.031, 0.040, rubber, vertices=20)
            cylinder("Steel leveling collar", (x,y,0.088), 0.024, 0.064, steel, vertices=16)
    # Rear is a complete assembly, including its physical frame and coil clips.
    box("Recessed rear service panel", (0,0.282,0.750), (0.567,0.022,1.147), dark, 0.020)
    for x in (-0.265,0.265):
        box("Rear panel folded edge", (x,0.301,0.746), (0.018,0.020,1.135), steel, 0.003)
    for z in (0.198,1.299):
        box("Rear panel horizontal frame", (0,0.301,z), (0.538,0.020,0.017), steel, 0.003)
    coil_points = []
    for row in range(10):
        z = 1.245 - row*0.075
        start = -0.210 if row%2 == 0 else 0.210
        end = -start
        coil_points += [(start,0.322,z),(end,0.322,z)]
        if row < 9:
            sign = 1 if end > 0 else -1
            for i in range(1,17):
                a = i*math.pi/16
                coil_points.append((end+sign*0.0375*math.sin(a),0.322,z-0.0375+0.0375*math.cos(a)))
    tube("Continuous serpentine condenser tube", coil_points, 0.0048, dark, sides=8)
    for x in [-0.185 + i*0.0116 for i in range(33)]:
        tube("Fine condenser cooling wire", [(x,0.328,0.535),(x,0.328,1.255)], 0.0012, steel, sides=4)
    for x in (-0.197,0.197):
        for z in (0.570,1.210):
            box("Condenser mounting clip", (x,0.331,z), (0.047,0.012,0.019), steel, 0.003)
            rivet((x,0.340,z), steel, radius=0.0038)
    box("Compressor support tray", (0,0.285,0.190), (0.470,0.169,0.024), steel, 0.005)
    ellipsoid("Compressor pressed steel dome", (0.045,0.306,0.276), (0.113,0.074,0.084), dark, 24, 12)
    box("Compressor lower seam", (0.045,0.306,0.231), (0.213,0.129,0.014), dark, 0.005)
    for x in (-0.056,0.146):
        box("Compressor rubber mount", (x,0.304,0.207), (0.030,0.075,0.019), rubber)
    box("Electrical relay housing", (-0.191,0.309,0.290), (0.069,0.070,0.108), dark, 0.009)
    pipe = [(0.126,0.331,0.259),(0.211,0.331,0.259),(0.247,0.331,0.290),(0.247,0.331,1.281),(-0.235,0.331,1.281),(-0.210,0.322,1.245)]
    tube("Copper compressor outlet", pipe, 0.004, copper)
    tube("Condenser return connection", [(-0.210,0.322,0.570),(-0.235,0.322,0.532),(-0.235,0.322,0.274),(-0.066,0.322,0.267)], 0.004, copper)
    # Cord winds on an attached cleat, with both plug pins visibly modeled.
    box("Cord storage cleat", (0.248,0.318,0.796), (0.044,0.030,0.236), rubber, 0.008)
    cord = []
    for i in range(145):
        a = i*TAU/48
        cord.append((0.249+0.025*math.sin(a),0.344+(i/145)*0.005,0.792+0.100*math.cos(a)))
    tube("Wound mains cable", cord, 0.0031, rubber)
    tube("Mains plug lead", [(0.249,0.349,0.692),(0.266,0.349,0.649),(0.254,0.349,0.605)], 0.0031, rubber)
    box("Mains plug body", (0.254,0.349,0.585), (0.025,0.016,0.030), rubber, 0.004)
    for x in (0.247,0.261):
        box("Mains plug pin", (x,0.349,0.563), (0.003,0.004,0.018), steel, 0.0006)
    for x in (-0.265,0.265):
        for z in (0.216,1.282):
            rivet((x,0.313,z), steel, radius=0.004)
    ticket_anchor((0.17,-0.343,0.40))


def export_asset(filename):
    import bmesh
    # Apply per-part normals, fix winding, then batch by material for runtime draw calls.
    grouped = {}
    for obj in PARTS:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()
        grouped.setdefault(obj.data.materials[0].name, []).append(obj)
    batches = []
    for name, objects in grouped.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        obj = bpy.context.object
        obj.name = name.replace(" ", "_")
        obj.data.calc_loop_triangles()
        batches.append(obj)
    points = [obj.matrix_world @ v.co for obj in batches for v in obj.data.vertices]
    low = [min(v[i] for v in points) for i in range(3)]
    high = [max(v[i] for v in points) for i in range(3)]
    for obj in batches:
        for vertex in obj.data.vertices:
            if not all(math.isfinite(value) for value in vertex.co):
                raise RuntimeError("Nonfinite vertex in " + filename)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in batches:
        obj.select_set(True)
    for obj in MARKERS:
        obj.select_set(True)
    ASSETS.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(ASSETS / (filename + ".glb")), export_format="GLB", use_selection=True, export_yup=True, export_animations=False, export_cameras=False, export_lights=False)
    return {"file": filename + ".glb", "mesh_batches": len(batches), "triangles": sum(len(o.data.loop_triangles) for o in batches), "blender_bounds_min": low, "blender_bounds_max": high, "textures_embedded": True}


def studio_render(name, target):
    # Authoring-only scene: a matched 3/4 preview and an opposite-side preview.
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1000
    scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new("Studio neutral surroundings")
    scene.world.color = (0.30,0.30,0.30)
    scene.view_settings.view_transform = "AgX"
    # Ground and lamps are deliberately created after the export selection.
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-0.004))
    floor = bpy.context.object
    floor.data.materials.append(material("Studio matte ground", "64665E", 0.85))
    for at, power, size in [((-2,-3,4),330,3),((2,-1,2.5),230,2),((0,3,3),400,2)]:
        data = bpy.data.lights.new("Broad reflection card", "AREA")
        data.energy, data.shape, data.size = power, "DISK", size
        lamp = bpy.data.objects.new(data.name,data)
        bpy.context.collection.objects.link(lamp)
        lamp.location = at
        lamp.rotation_euler = (Vector(target)-lamp.location).to_track_quat("-Z","Y").to_euler()
    bpy.ops.object.camera_add()
    camera = bpy.context.object
    camera.data.type = "ORTHO"
    extent = 1.0 if name == "treasure_chest" else 1.65
    camera.data.ortho_scale = extent
    scene.camera = camera
    for view, at in [("front",(2,-3,1.75)),("rear",(-2,3,1.75))]:
        camera.location = Vector(target)+Vector(at)*extent
        camera.rotation_euler = (Vector(target)-camera.location).to_track_quat("-Z","Y").to_euler()
        scene.render.filepath = str(EVIDENCE / (name+"_"+view+"_blender.png"))
        bpy.ops.render.render(write_still=True)


def main():
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    random.seed(17)
    results = []
    for name, filename, build, target in [
        ("treasure_chest","P029_treasure_chest_refined",build_chest,(0,0,0.29)),
        ("retro_fridge","S044_retro_refrigerator_refined",build_fridge,(0,0,0.70)),
    ]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        PARTS.clear()
        MARKERS.clear()
        build()
        results.append(export_asset(filename))
        # Keep an editable source locally; the compact generator is committed.
        bpy.ops.wm.save_as_mainfile(filepath=str(EVIDENCE / (name+".blend")))
        if "--no-renders" not in sys.argv:
            studio_render(name, target)
    (SOURCE / "build_manifest.json").write_text(json.dumps(results,indent=2),encoding="utf-8")
    print("REFINED_PROPS_BUILD_OK " + json.dumps(results))


if __name__ == "__main__":
    main()
