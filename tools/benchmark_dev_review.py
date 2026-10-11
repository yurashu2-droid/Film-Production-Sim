#!/usr/bin/env python3
"""Compare identical individual operations vs one review; measure token PROXIES."""
import argparse
from datetime import datetime, timezone
import json
from pathlib import Path
import platform
import statistics
import time

from PIL import Image, ImageChops
from dev_session import ROOT, Session
from dev_review import review, summarize

FIXTURE = '''extends Node3D
var ticks := 0
var sole_y := 0.0
var block: MeshInstance3D
func _ready():
    block = MeshInstance3D.new()
    block.mesh = BoxMesh.new()
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(1, 0.3, 0.1)
    block.material_override = material
    add_child(block)
    var camera := Camera3D.new()
    camera.position = Vector3(3, 2, 4)
    add_child(camera)
    camera.look_at(Vector3.ZERO)
    camera.make_current()
func _physics_process(_delta):
    ticks += 1
    block.position.y = 0.5 + sin(ticks * 0.08) * 0.2
    block.rotation.y = ticks * 0.02
func foot_position(side):
    return Vector3(-0.1 if side == "L" else 0.1, sole_y, 0)
'''


def make_fixture():
    folder = ROOT / "godot/.godot/dev_session"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "compact_fixture.gd").write_text(FIXTURE, encoding="utf-8")
    scene = "res://.godot/dev_session/compact_fixture.tscn"
    (folder / "compact_fixture.tscn").write_text('[gd_scene load_steps=2 format=3]\n[ext_resource type="Script" path="res://.godot/dev_session/compact_fixture.gd" id="1"]\n[node name="Fixture" type="Node3D"]\nscript = ExtResource("1")\n', encoding="utf-8")
    return {"scene": scene, "frames": list(range(0, 121, 6)), "size": [640, 360],
            "views": [{"id": "game"}, {"id": "side", "position": [4, 1, 0], "target": [0, 0.5, 0]},
                      {"id": "above", "position": [0, 5, 0], "target": [0, 0, 0]}],
            "events": [{"frame": 36, "op": "set", "property": "sole_y", "value": -0.2},
                       {"frame": 60, "op": "set", "property": "sole_y", "value": 0.0}],
            "checks": [{"id": "sole_clearance", "type": "feet", "node": ".", "ground_y": 0.0, "tolerance": 0.03},
                       {"id": "tick_range", "type": "property", "node": ".", "property": "ticks", "min": 0, "max": 120}]}


def individual(session, scenario, output):
    output.mkdir(parents=True, exist_ok=True)
    responses = []
    def request(payload):
        result = session.request(payload)
        responses.append(result)
        return result
    start = time.perf_counter()
    request({"op": "load", "scene": scenario["scene"]})
    samples = []
    previous = 0
    for frame in scenario["frames"]:
        if frame > previous:
            request({"op": "step", "frames": frame - previous})
        for event in scenario["events"]:
            if event["frame"] == frame:
                request(event)
        sample_folder = output / f"frame_{frame:03}"
        result = request(dict(scenario, op="capture_views", scene="", output=str(sample_folder)))
        sample = json.loads(Path(result["manifest"]).read_text(encoding="utf-8"))["samples"][0]
        sample["frame"] = frame
        sample["time"] = frame / 60
        samples.append(sample)
        responses.append(sample)  # Individual workflow exposes each measured image/check.
        previous = frame
    manifest = output / "manifest.json"
    manifest.write_text(json.dumps({"scenario": scenario, "samples": samples}, indent=2), encoding="utf-8")
    summary = summarize(manifest)
    elapsed = time.perf_counter() - start
    return {"elapsed_s": elapsed, "rpc_calls": len(responses) - len(samples),
            "visible_text_chars": len(json.dumps(responses, ensure_ascii=False)),
            "input_images": summary["raw_images"], "input_pixels": summary["raw_pixels"]}


def compare(a, b):
    left = json.loads((a / "manifest.json").read_text(encoding="utf-8"))
    right = json.loads((b / "manifest.json").read_text(encoding="utf-8"))
    assert len(left["samples"]) == len(right["samples"])
    matched = 0
    for first, second in zip(left["samples"], right["samples"]):
        assert first["frame"] == second["frame"]
        assert first["checks"] == second["checks"]
        for x, y in zip(first["images"], second["images"]):
            assert x["view"] == y["view"]
            with Image.open(x["path"]) as im, Image.open(y["path"]) as other:
                assert ImageChops.difference(im.convert("RGB"), other.convert("RGB")).getbbox() is None, (first["frame"], x["view"])
            matched += 1
    return matched


def benchmark(args):
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    scenario = make_fixture()
    session = Session(name="benchmark_compact_review")
    session.stop()
    data = {"recorded_at": datetime.now(timezone.utc).isoformat(), "platform": platform.platform(),
            "python": platform.python_version(), "engine": "Godot 4.7.2",
            "timing": "Includes load, simulation, PNG readback/save and compact-summary assembly for both paths; excludes worker startup and pixel comparison.",
            "note": "Model tokens not measured; compare exposed JSON characters and image pixels only.",
            "baseline": "Individual RPCs exposing every image/check vs one review with compact evidence; both use a warm persistent engine.",
            "pairs": []}
    try:
        status = session.start("render")
        assert not status["window_visible"]
        # Warm both camera creation/readback paths before measuring.
        individual(session, scenario, output / "warmup_individual")
        review(session, scenario, output / "warmup_review")
        for i in range(args.pairs):
            pair = {"revision": i + 1, "order": ["individual", "review"] if i % 2 == 0 else ["review", "individual"]}
            for mode in pair["order"]:
                folder = output / f"{i+1:02}_{mode}"
                if mode == "individual":
                    pair[mode] = individual(session, scenario, folder)
                else:
                    start = time.perf_counter()
                    summary = review(session, scenario, folder)
                    pair[mode] = {"elapsed_s": time.perf_counter() - start, "rpc_calls": 1,
                                  "visible_text_chars": len(json.dumps(summary, ensure_ascii=False)),
                                  "input_images": summary["review_images"], "input_pixels": summary["review_pixels"]}
            pair["matched_images"] = compare(output / f"{i+1:02}_individual", output / f"{i+1:02}_review")
            data["pairs"].append(pair)
            print(f"Pair {i+1}: individual={pair['individual']['elapsed_s']:.3f}s review={pair['review']['elapsed_s']:.3f}s matched={pair['matched_images']}", flush=True)
        data["medians"] = {mode: {key: statistics.median(p[mode][key] for p in data["pairs"])
                                 for key in ("elapsed_s", "rpc_calls", "visible_text_chars", "input_images", "input_pixels")}
                           for mode in ("individual", "review")}
        print(json.dumps(data["medians"], indent=2), flush=True)
    finally:
        session.stop()
        (output / "results.json").write_text(json.dumps(data, indent=2), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pairs", type=int, default=5)
    parser.add_argument("--output", type=Path, default=ROOT / "godot/.godot/dev_session/compact_benchmark")
    args = parser.parse_args()
    if args.pairs < 1:
        parser.error("--pairs must be positive")
    benchmark(args)
