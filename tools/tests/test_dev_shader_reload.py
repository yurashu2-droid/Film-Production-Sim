import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from dev_session import ROOT, Session
from punch_workflow_trial import gpu_lock


class ShaderReloadTest(unittest.TestCase):
    def test_cached_material_changes_without_restarting_or_rebuilding(self):
        from PIL import Image
        folder = ROOT / "godot/.godot/dev_session"
        folder.mkdir(parents=True, exist_ok=True)
        shader = folder / "reload_test.gdshader"
        code = "shader_type spatial; render_mode unshaded; void fragment(){ALBEDO=vec3(1.0,0.1,0.05);}"
        shader.write_text(code, encoding="utf-8")
        script = folder / "shader_fixture.gd"
        script.write_text('''extends Node3D
const SHADER = preload("res://.godot/dev_session/reload_test.gdshader")
var box: MeshInstance3D
func _ready():
    box = MeshInstance3D.new()
    box.mesh = BoxMesh.new()
    var mat = ShaderMaterial.new()
    mat.shader = SHADER
    box.material_override = mat
    add_child(box)
    var camera = Camera3D.new()
    camera.position = Vector3(0,0,3)
    add_child(camera)
    camera.look_at(Vector3.ZERO)
    camera.make_current()
func shader_id(): return SHADER.get_instance_id()
func box_id(): return box.get_instance_id()
''', encoding="utf-8")
        scene = folder / "shader_fixture.tscn"
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://.godot/dev_session/shader_fixture.gd" id="1"]\n[node name="Fixture" type="Node3D"]\nscript = ExtResource("1")\n', encoding="utf-8")
        with gpu_lock():
            s = Session(name="test_shader_reload")
            try:
                pid = s.start("render")["pid"]
                s.request({"op": "load", "scene": "res://.godot/dev_session/shader_fixture.tscn"})
                first = s.request({"op": "capture_views", "output": str(folder / "shader_before"), "size": [320, 180]})
                ids = [s.request({"op": "call", "method": name}) for name in ("shader_id", "box_id")]
                shader.write_text(code.replace("1.0,0.1,0.05", "0.05,0.8,0.1"), encoding="utf-8")
                s.request({"op": "reload", "path": "res://.godot/dev_session/reload_test.gdshader"})
                second = s.request({"op": "capture_views", "output": str(folder / "shader_after"), "size": [320, 180]})
                colors = []
                for result in (first, second):
                    manifest = json.loads(Path(result["manifest"]).read_text(encoding="utf-8"))
                    with Image.open(manifest["samples"][0]["images"][0]["path"]) as image:
                        colors.append(image.getpixel((160, 90)))
                self.assertGreater(colors[0][0], colors[0][1] + 80)
                self.assertGreater(colors[1][1], colors[1][0] + 80)
                self.assertEqual(ids, [s.request({"op": "call", "method": name}) for name in ("shader_id", "box_id")])
                status = s.request({"op": "status"})
                self.assertEqual(status["pid"], pid)
                self.assertTrue(status["paused"])
                self.assertFalse(status["window_visible"])
            finally:
                s.stop()


if __name__ == "__main__":
    unittest.main()
