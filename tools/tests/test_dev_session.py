"""Integration tests against the real engine; no editor or visible game window."""
import importlib.util
import json
from pathlib import Path
import unittest
from concurrent.futures import ThreadPoolExecutor
import time

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("dev_session", ROOT / "tools/dev_session.py")
dev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dev)

FIXTURE = '''extends Node3D
var count := 7
var ticks := 0
var pressed := false
var events := 0
var edge := false
func _ready():
    if not InputMap.has_action("dev_test_move"):
        InputMap.add_action("dev_test_move")
func _physics_process(_delta):
    ticks += 1
    pressed = Input.is_action_pressed("dev_test_move")
    edge = edge or Input.is_action_just_pressed("dev_test_move")
func answer():
    return 10
func _unhandled_input(event):
    if event.is_action_pressed("dev_test_move"):
        events += 1
'''


class DevSessionTest(unittest.TestCase):
    def exercise(self, mode):
        project = ROOT / "godot"
        session = dev.Session(project, name="test_" + mode)
        folder = project / ".godot/dev_session"
        folder.mkdir(parents=True, exist_ok=True)
        fixture = folder / ("fixture_" + mode + ".gd")
        scene = folder / ("fixture_" + mode + ".tscn")
        fixture.write_text(FIXTURE, encoding="utf-8")
        path = "res://.godot/dev_session/" + fixture.name
        scene.write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="' + path + '" id="1"]\n[node name="Fixture" type="Node3D"]\nscript = ExtResource("1")\n', encoding="utf-8")
        try:
            status = session.start(mode)
            self.assertEqual(session.start(mode)["pid"], status["pid"])
            self.assertFalse(status["window_visible"])
            session.request({"op": "load", "scene": "res://.godot/dev_session/" + scene.name})
            self.assertEqual(session.request({"op": "call", "method": "answer"}), 10)
            session.request({"op": "set", "property": "count", "value": 23})
            session.request({"op": "input", "action": "dev_test_move", "pressed": True})
            before = session.request({"op": "get", "properties": ["ticks"]})["ticks"]
            session.request({"op": "step", "frames": 1})
            self.assertTrue(session.request({"op": "get", "properties": ["edge"]})["edge"])
            session.request({"op": "step", "frames": 7})
            values = session.request({"op": "get", "properties": ["ticks", "pressed"]})
            self.assertEqual(values["ticks"] - before, 8)
            self.assertTrue(values["pressed"])
            self.assertTrue(session.request({"op": "get", "properties": ["edge"]})["edge"])
            self.assertEqual(session.request({"op": "get", "properties": ["events"]})["events"], 1)
            fixture.write_text(FIXTURE.replace("return 10", "return 20"), encoding="utf-8")
            session.request({"op": "reload", "path": path})
            self.assertEqual(session.request({"op": "call", "method": "answer"}), 20)
            self.assertEqual(session.request({"op": "get", "properties": ["count"]})["count"], 23)
            fixture.write_text("extends Node3D\nTHIS IS INVALID\n", encoding="utf-8")
            with self.assertRaises(dev.SessionError):
                session.request({"op": "reload", "path": path})
            self.assertEqual(session.request({"op": "call", "method": "answer"}), 20)
            with self.assertRaises(dev.SessionError):
                session.request({"op": "get", "properties": ["nonexistent"]})
            with self.assertRaises(dev.SessionError):
                session.request({"op": "input", "action": "unknown_action"})
            with self.assertRaises(dev.SessionError):
                session.request({"op": "step", "frames": 0})
            if mode == "render":
                shot = folder / "test_capture.png"
                session.request({"op": "capture", "path": str(shot)})
                self.assertGreater(shot.stat().st_size, 1000)
            self.assertEqual(session.request({"op": "status"})["pid"], status["pid"])
            if mode == "headless":
                metadata = session.state.read_text(encoding="utf-8")
                with ThreadPoolExecutor(max_workers=1) as executor:
                    advancing = executor.submit(session.request, {"op": "step", "frames": 120})
                    time.sleep(0.15)
                    with self.assertRaises(dev.SessionError):
                        session.start(mode)
                    advancing.result()
                self.assertEqual(session.state.read_text(encoding="utf-8"), metadata)
                self.assertEqual(session.request({"op": "status"})["pid"], status["pid"])
            session.request({"op": "load", "scene": "res://.godot/dev_session/" + scene.name})
            self.assertFalse(session.request({"op": "get", "properties": ["pressed"]})["pressed"])
        finally:
            fixture.write_text(FIXTURE, encoding="utf-8")
            session.stop()

    def test_headless(self):
        self.exercise("headless")

    def test_hidden_render(self):
        self.exercise("render")


if __name__ == "__main__":
    unittest.main()
