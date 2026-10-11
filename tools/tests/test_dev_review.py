"""Focused integration checks for synchronized capture and compact selection."""
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dev_session import ROOT, Session, SessionError

FIXTURE = '''extends Node3D
var ticks := 0
var first_edge := false
var sole_y := 0.0
var pressed := false
var edge_count := 0
func _ready():
    InputMap.add_action("review_move")
    var mesh := MeshInstance3D.new()
    mesh.name = "Block"
    mesh.mesh = BoxMesh.new()
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(1, 0.3, 0.1)
    mesh.material_override = material
    add_child(mesh)
    var camera := Camera3D.new()
    camera.position = Vector3(3, 2, 4)
    add_child(camera)
    camera.look_at(Vector3.ZERO)
    camera.make_current()
func _physics_process(_delta):
    ticks += 1
    pressed = Input.is_action_pressed("review_move")
    if Input.is_action_just_pressed("review_move"):
        edge_count += 1
    if ticks == 1:
        first_edge = Input.is_action_just_pressed("review_move")
func foot_position(side):
    return global_position + Vector3(-0.1 if side == "L" else 0.1, sole_y, 0)
'''


class ReviewTest(unittest.TestCase):
    def test_real_capture_and_failure_cleanup(self):
        s = Session(name="test_review")
        folder = ROOT / "godot/.godot/dev_session"
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "review_fixture.gd").write_text(FIXTURE, encoding="utf-8")
        (folder / "review_fixture.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://.godot/dev_session/review_fixture.gd" id="1"]\n[node name="ReviewFixture" type="Node3D"]\nscript = ExtResource("1")\n', encoding="utf-8")
        plan = {"op": "review", "scene": "res://.godot/dev_session/review_fixture.tscn",
                "output": str(folder / "review_test"), "frames": [0, 6, 12], "size": [320, 180],
                "views": [{"id": "game"}, {"id": "side", "position": [4, 1, 0], "target": [0, 0, 0]}],
                "events": [{"frame": 0, "op": "input", "action": "review_move", "pressed": True},
                           {"frame": 3, "op": "set", "property": "sole_y", "value": -0.2},
                           {"frame": 3, "op": "set", "node": "Block", "property": "position", "value": [10, 0, 0]},
                           {"frame": 6, "op": "set", "node": "Block", "property": "position", "value": [0, 0, 0]},
                           {"frame": 6, "op": "set", "property": "sole_y", "value": 0.0}],
                "checks": [{"id": "feet", "type": "feet", "node": ".", "ground_y": 0.0, "tolerance": 0.03}]}
        try:
            start = s.start("render")
            result = s.request(plan)
            manifest = json.loads(Path(result["manifest"]).read_text(encoding="utf-8"))
            self.assertNotIn("token", manifest["scenario"])
            self.assertEqual([x["frame"] for x in manifest["samples"]], [0, 3, 6, 12])
            self.assertEqual(result["images"], 8)
            self.assertAlmostEqual(manifest["samples"][1]["checks"][0]["value"], -0.2)
            self.assertFalse(manifest["samples"][1]["checks"][0]["passed"])
            self.assertTrue(manifest["samples"][-1]["checks"][0]["passed"])
            for sample in manifest["samples"]:
                self.assertEqual({image["physics_frames"] for image in sample["images"]}, {sample["physics_frames"]})
                for image in sample["images"]:
                    self.assertTrue(Path(image["path"]).exists())
                    from PIL import Image
                    with Image.open(image["path"]) as im:
                        pixel = im.getpixel((im.width // 2, im.height // 2))
                        if sample["frame"] == 3:
                            self.assertLessEqual(pixel[0], pixel[1] + 50, "Same-frame set must move the mesh before capture")
                        else:
                            self.assertGreater(pixel[0], pixel[1] + 50, "Each camera must see the shared orange mesh")
            values = s.request({"op": "get", "properties": ["ticks", "first_edge"]})
            self.assertEqual(values["ticks"], 12)
            self.assertTrue(values["first_edge"])
            self.assertEqual(s.request({"op": "status"})["pid"], start["pid"])
            self.assertTrue(s.request({"op": "status"})["paused"])
            self.assertFalse(s.request({"op": "status"})["window_visible"])
            # A property read makes held input observable without extending the fixture.
            s.request({"op": "step", "frames": 1})
            self.assertFalse(s.request({"op": "get", "properties": ["pressed"]})["pressed"])
            original = s.request({"op": "capture", "path": str(folder / "review_after.png")})
            from PIL import Image
            with Image.open(original) as im:
                self.assertEqual(im.size, (1600, 900))
            s.request({"op": "input", "action": "review_move", "pressed": True})
            s.request({"op": "step", "frames": 1})
            edge_count = s.request({"op": "get", "properties": ["edge_count"]})["edge_count"]
            s.request({"op": "capture_views", "output": str(folder / "review_held"), "size": [320, 180]})
            s.request({"op": "step", "frames": 1})
            self.assertEqual(s.request({"op": "get", "properties": ["edge_count"]})["edge_count"], edge_count)
            s.request({"op": "input", "action": "review_move", "pressed": False})
            with self.assertRaises(SessionError):
                s.request(dict(plan, scene="", frames=[12, 2]))
            with self.assertRaises(SessionError):
                s.request(dict(plan, scene="", views=[{"id": "side", "follow": "missing"}]))
            ticks = s.request({"op": "get", "properties": ["ticks"]})["ticks"]
            with self.assertRaises(SessionError):
                s.request(dict(plan, scene="res://motion_lab.tscn", frames=[0] + list(range(2, 121)),
                               events=[{"frame": 1, "op": "set", "property": "sole_y", "value": 0}]))
            self.assertEqual(s.request({"op": "get", "properties": ["ticks"]})["ticks"], ticks)
            # Execution failure after pressing input must restore a paused usable worker.
            failing = dict(plan, scene="", events=[plan["events"][0], {"frame": 2, "op": "call", "method": "missing"}])
            with self.assertRaises(SessionError):
                s.request(failing)
            self.assertTrue(s.request({"op": "status"})["paused"])
            self.assertEqual(s.request({"op": "status"})["pid"], start["pid"])
            s.request({"op": "step", "frames": 1})
            self.assertFalse(s.request({"op": "get", "properties": ["pressed"]})["pressed"])
            disappearing = dict(plan, scene="", frames=[0, 2], checks=[],
                                views=[{"id": "follow", "follow": "Block", "offset": [4, 1, 0], "look_offset": [0, 0, 0]}],
                                events=[{"frame": 0, "op": "call", "node": "Block", "method": "queue_free"}])
            with self.assertRaisesRegex(SessionError, "disappeared"):
                s.request(disappearing)
            self.assertTrue(s.request({"op": "status"})["paused"])
        finally:
            s.stop()

    def test_selection_retains_phases_and_worst_anomaly(self):
        from dev_review import select_samples
        samples = [{"frame": i, "checks": [{"passed": i != 7, "value": -0.4 if i == 7 else 0,
                                             "severity": 0.4 if i == 7 else 0}]} for i in range(20)]
        chosen = select_samples(samples, 6)
        self.assertEqual(len(chosen), 6)
        self.assertIn(0, chosen)
        self.assertIn(19, chosen)
        self.assertIn(7, chosen)
        self.assertTrue(any(8 <= i <= 12 for i in chosen))


if __name__ == "__main__":
    unittest.main()
