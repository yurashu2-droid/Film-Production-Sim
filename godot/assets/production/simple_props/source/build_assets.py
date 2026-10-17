"""Three deliberately economical, text-reference-led props. Blender 5.2 CLI."""
from pathlib import Path
import sys
import json
import math
import bpy

SOURCE = Path(__file__).resolve().parent
sys.path.insert(0, str(SOURCE.parents[1] / 'refined_props/source'))
import build_assets as h


def finish(obj, mat, bevel=0.0, smooth=True):
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    if bevel:
        mod = obj.modifiers.new('Single edge chamfer', 'BEVEL')
        mod.width, mod.segments = bevel, 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        for face in obj.data.polygons:
            face.use_smooth = True
        mod = obj.modifiers.new('Face normals', 'WEIGHTED_NORMAL')
        mod.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    h.PARTS.append(obj)
    return obj


h.finish = finish
box, cylinder, material = h.box, h.cylinder, h.material


def frustum(name, at, bottom, top, depth, mat, vertices=4):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=bottom,
                                  radius2=top, depth=depth, location=at)
    obj = bpy.context.object
    obj.name = name
    if vertices == 4:
        obj.rotation_euler.z = math.pi / 4
    return finish(obj, mat, smooth=False)


def lamp():
    green = material('Lamp dark green paint', '315B4A', .65)
    glass = material('Lamp opaque warm panes', 'F5D9A0', .5)
    # Match the existing three-part collider: base / pole / lantern.
    box('Foot', (0, 0, .045), (.25, .25, .09), green, .008)
    frustum('Tapered pedestal', (0, 0, .135), .12, .063, .09, green, 8)
    cylinder('Post', (0, 0, .57), .031, .84, green, vertices=12)
    cylinder('Collar', (0, 0, .985), .05, .04, green, vertices=12)
    frustum('Warm four panes', (0, 0, 1.105), .092, .127, .19, glass)
    box('Lantern lower rim', (0, 0, 1.002), (.145, .145, .025), green, .002)
    box('Lantern upper rim', (0, 0, 1.21), (.205, .205, .025), green, .002)
    for x in (-1, 1):
        for y in (-1, 1):
            # Corner bars follow the tapered four-pane housing.
            start = (x * .063, y * .063, 1.01)
            end = (x * .089, y * .089, 1.20)
            from mathutils import Vector
            delta = Vector(end) - Vector(start)
            cylinder('Corner bar', (Vector(start) + Vector(end)) / 2,
                     .007, delta.length, green, delta, vertices=6)
    frustum('Pyramid roof', (0, 0, 1.252), .157, 0, .084, green)
    # Ticket goes on the front of the wide base, not across the pole.
    h.ticket_anchor((0, -.126, .047))


def clock():
    wood = material('Clock plain walnut paint', '885536', .72)
    dark = material('Clock dial ink and recess', '2C2926', .85)
    ivory = material('Clock ivory dial', 'F1E2C1', .8)
    brass = material('Clock simple brass', 'C8A45C', .42, .55)
    box('Case', (0, .025, .66), (.50, .25, 1.21), wood, .008)
    box('Plinth', (0, 0, .065), (.60, .32, .13), wood, .008)
    points = [(-.27, 1.19), (-.27, 1.25)]
    points += [(.27 * math.cos(t), 1.25 + .15 * math.sin(t))
               for t in [math.pi - i * math.pi / 10 for i in range(11)]]
    points += [(.27, 1.19)]
    h.extruded_profile('Arched crown', points, .0, .29, wood, .003)
    # Dark inset is a shallow panel, not glass or a modeled internal mechanism.
    box('Pendulum window', (0, -.108, .47), (.33, .02, .55), dark, .006)
    box('Pendulum rod', (0, -.132, .51), (.018, .012, .40), brass, 0)
    cylinder('Pendulum disk', (0, -.143, .335), .084, .022, brass, (0, -1, 0), 20)
    cylinder('Dial rim', (0, -.116, 1.024), .232, .035, brass, (0, -1, 0), 32)
    cylinder('Dial face', (0, -.140, 1.024), .215, .016, ivory, (0, -1, 0), 32)
    for i in range(12):
        a = i * math.tau / 12
        tick = box('Hour tick', (.18 * math.sin(a), -.151, 1.024 + .18 * math.cos(a)),
                   (.013, .006, .035), dark, 0)
        tick.rotation_euler.y = a
    for angle, length in [(-.85, .12), (.92, .16)]:
        hand = box('Clock hand', (math.sin(angle) * length / 2, -.160,
                                 1.024 + math.cos(angle) * length / 2),
                   (.015, .008, length), dark, 0)
        hand.rotation_euler.y = angle
    cylinder('Hand pin', (0, -.169, 1.024), .018, .012, brass, (0, -1, 0), 12)
    h.ticket_anchor((.185, -.104, .19))


def vending():
    red = material('Vending muted red paint', 'AE4243', .63)
    ivory = material('Vending ivory plastic', 'E8DDC5', .7)
    dark = material('Vending recess and feet', '292F34', .8)
    silver = material('Vending can rims', 'ADB5B8', .4, .65)
    colors = [material('Drink ' + name, color, .6) for name, color in
              [('orange', 'E3A342'), ('blue', '4D9BAE'), ('green', '77A15E')]]
    # Face is assembled around real shallow openings; rear stays a plain panel.
    box('Cabinet back', (0, .085, .78), (.80, .33, 1.44), red, .016)
    for x in (-.365, .365):
        box('Cabinet side', (x, -.165, .78), (.07, .17, 1.44), red, .008)
    box('Top face', (0, -.165, 1.455), (.66, .17, .09), red, .008)
    box('Lower face', (0, -.165, .48), (.66, .17, .24), red, .006)
    box('Bottom face', (0, -.165, .12), (.66, .17, .12), red, .006)
    box('Control strip', (.266, -.165, 1.0), (.128, .17, .81), red, .004)
    box('Display dark back', (-.065, -.085, 1.0), (.56, .025, .81), dark, .003)
    for x in (-.335, .205):
        box('Display upright trim', (x, -.238, 1.0), (.024, .028, .81), ivory, .003)
    for z in (.601, 1.40):
        box('Display horizontal trim', (-.065, -.238, z), (.56, .028, .025), ivory, .003)
    for row, z in enumerate((.755, 1.14)):
        box('Product shelf', (-.065, -.165, z - .105), (.52, .15, .028), ivory, .002)
        for column in range(4):
            x = -.26 + column * .13
            cylinder('Can', (x, -.17, z), .043, .16, colors[(column + row) % 3], vertices=12)
            for dz in (-.077, .077):
                cylinder('Can rolled rim', (x, -.17, z + dz), .044, .012, silver, vertices=12)
            # A broad stripe stands in for a brand label; no text or art textures.
            box('Can label', (x, -.212, z), (.046, .004, .052), ivory, 0)
            box('Selection button', (x, -.245, z - .132), (.062, .014, .023), dark, .006)
    box('Payment panel', (.266, -.254, 1.04), (.087, .014, .23), dark, .006)
    box('Coin slot', (.266, -.264, 1.085), (.052, .008, .009), silver, 0)
    box('Return lever', (.266, -.266, .993), (.028, .012, .030), silver, .003)
    box('Hatch dark back', (0, -.09, .265), (.64, .02, .16), dark, .002)
    box('Hatch sill', (0, -.16, .18), (.66, .18, .024), dark, .003)
    for x in (-.29, .29):
        for y in (-.16, .16):
            box('Foot', (x, y, .03), (.09, .09, .06), dark, .004)
    h.ticket_anchor((.22, -.252, .475))


def main():
    evidence = h.PROJECT.parent / 'artifacts/simple-props-20261017'
    evidence.mkdir(parents=True, exist_ok=True)
    results = []
    for name, filename, build in [('lamp', 'S051_street_lamp_simple', lamp),
                                  ('clock', 'S096_giant_clock_simple', clock),
                                  ('vending', 'S059_vending_machine_simple', vending)]:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        h.PARTS.clear()
        h.MARKERS.clear()
        build()
        row = h.export_asset(filename)
        row['textures_embedded'] = False
        results.append(row)
        bpy.ops.wm.save_as_mainfile(filepath=str(evidence / (name + '.blend')))
    (SOURCE / 'build_manifest.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    print('SIMPLE_PROPS_OK ' + json.dumps(results))


if __name__ == '__main__':
    main()
