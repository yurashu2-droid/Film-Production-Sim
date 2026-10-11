#!/usr/bin/env python3
"""Paired VFX edit-to-PNG benchmark: fresh Godot vs a persistent worker.

The baseline uses a standalone --script capture without the development runtime.
Both workflows use the same scene, physics frames and image-capture API.
Only an ignored copy of the existing sculpted dust effect is edited.
Requires Pillow for decoded-pixel checks and the contact sheet.
"""
import argparse
import csv
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import statistics
import subprocess
import time

from PIL import Image, ImageChops, ImageDraw
from dev_session import ROOT, Session, native_windows

SCENE = "res://addons/dev_session/benchmarks/vfx_preview.tscn"
EFFECT = "res://.godot/dev_session/vfx_benchmark_effect.gd"
FRAMES = (12, 30, 54, 72)


def timed(operation):
    start = time.perf_counter()
    result = operation()
    return result, time.perf_counter() - start


def state(session):
    return session.request({"op": "call", "method": "sample_state"})


def render(session, folder):
    folder.mkdir(parents=True, exist_ok=True)
    previous = 0
    simulation = capture = 0.0
    states = []
    for frame in FRAMES:
        _, elapsed = timed(lambda: session.request({"op": "step", "frames": frame - previous}))
        simulation += elapsed
        _, elapsed = timed(lambda: session.request({"op": "capture", "path": str(folder / f"{frame:03}.png")}))
        capture += elapsed
        states.append(state(session))
        previous = frame
    return simulation, capture, states


def compare(left, right):
    checks = []
    for frame in FRAMES:
        with Image.open(left / f"{frame:03}.png") as a, Image.open(right / f"{frame:03}.png") as b:
            difference = ImageChops.difference(a.convert("RGB"), b.convert("RGB"))
            checks.append({"frame": frame, "identical_pixels": difference.getbbox() is None,
                           "max_channel_difference": max(hi for lo, hi in difference.getextrema())})
    return checks


def fresh_render(folder):
    """Start ordinary Godot, collect four PNGs, and wait for its natural exit."""
    folder.mkdir(parents=True, exist_ok=True)
    for name in ("begin", "ready.json", "done.json"):
        (folder / name).unlink(missing_ok=True)
    engine = ROOT / "tools/godot/Godot_v4.7.2-stable_win64.exe"
    command = [str(engine), "--path", str(ROOT / "godot"), "--audio-driver", "Dummy",
               "--position", "-32000,-32000", "--script",
               "res://addons/dev_session/benchmarks/fresh_capture.gd", "--log-file",
               str(folder / "engine.log"), "--", "--output=" + str(folder)]
    options = {"stdin": subprocess.DEVNULL, "stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL}
    if os.name == "nt":
        options["creationflags"] = subprocess.CREATE_NO_WINDOW | subprocess.CREATE_NEW_PROCESS_GROUP
    start = time.perf_counter()
    process = subprocess.Popen(command, **options)
    try:
        def wait_for(path):
            while not path.exists():
                if process.poll() is not None or time.perf_counter() - start > 30:
                    raise RuntimeError("Fresh Godot failed; inspect " + str(folder / "engine.log"))
                time.sleep(0.005)
            return json.loads(path.read_text(encoding="utf-8"))
        status = wait_for(folder / "ready.json")
        if os.name == "nt":
            import ctypes
            for handle in native_windows(process.pid):
                ctypes.windll.user32.ShowWindow(handle, 0)
            status["window_visible"] = any(ctypes.windll.user32.IsWindowVisible(h) for h in native_windows(process.pid))
        else:
            status["window_visible"] = False
        update_s = time.perf_counter() - start
        (folder / "begin").touch()
        result = wait_for(folder / "done.json")
        result["elapsed_s"] = time.perf_counter() - start
        _, result["shutdown_s"] = timed(lambda: process.wait(timeout=5))
        result["update_s"] = update_s
        result["status"] = status
        return result
    finally:
        if process.poll() is None:
            process.terminate()  # Only the process this measurement owns.
            process.wait(timeout=5)


def contact_sheet(output, pairs):
    # First and last variant, both execution paths, normal-speed sample timestamps.
    tiles = []
    for pair in (pairs[0], pairs[-1]):
        for mode in ("fresh", "persistent"):
            tiles.append((f'{pair["kind"]} / {mode} / revision {pair["revision"]}',
                          output / pair[mode]["folder"]))
    sheet = Image.new("RGB", (1440, len(tiles) * 245), "#182028")
    draw = ImageDraw.Draw(sheet)
    for row, (label, folder) in enumerate(tiles):
        draw.text((8, row * 245 + 4), label, fill="white")
        for column, frame in enumerate(FRAMES):
            with Image.open(folder / f"{frame:03}.png") as im:
                sheet.paste(im.convert("RGB").resize((360, 203)), (column * 360, row * 245 + 24))
            draw.text((column * 360 + 8, row * 245 + 229), f"{frame}/60 s", fill="white")
    sheet.save(output / "comparison.png")


def benchmark(args):
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    effect_file = ROOT / "godot/.godot/dev_session/vfx_benchmark_effect.gd"
    effect_file.parent.mkdir(parents=True, exist_ok=True)
    original = (ROOT / "godot/scripts/sculpted_dust.gd").read_text(encoding="utf-8")
    assert original.count("exp(-t * 3.0)") == 1
    assert original.count("_cores = 3 if trail else 8") == 1
    effect_file.write_text(original, encoding="utf-8")
    live = Session(name="vfx_benchmark_live")
    # Own named workers only; do not alter any user's development/game session.
    live.stop()
    report = {"timestamp": datetime.now().astimezone().isoformat(),
              "host": platform.platform(), "python": platform.python_version(),
              "resolution": [1600, 900], "physics_hz": 60, "sample_frames": FRAMES,
              "baseline": "Fresh Godot --script per edit, no development runtime or TCP; no editor/UI overhead",
              "authoring_time": "Excluded: scripted identical edits, no human design timing",
              "source_sha256": hashlib.sha256(original.encode("utf-8")).hexdigest(),
              "pairs": []}
    try:
        warmup = fresh_render(output / "warmup_fresh")
        report["fresh_first_start_and_load_s"] = warmup["update_s"]
        report["engine_banner"] = (output / "warmup_fresh/engine.log").read_text(encoding="utf-8").splitlines()[:2]
        status, report["persistent_first_start_s"] = timed(lambda: live.start("render"))
        live_pid = status["pid"]
        _, report["persistent_initial_load_s"] = timed(lambda: live.request({"op": "load", "scene": SCENE}))
        render(live, output / "warmup_live")
        report["warmup_pixel_checks"] = compare(output / "warmup_fresh", output / "warmup_live")
        if not all(check["identical_pixels"] for check in report["warmup_pixel_checks"]):
            raise AssertionError("Warmup images differ")

        for kind in ("motion", "construction"):
            for revision in range(1, args.pairs + 1):
                pair = {"kind": kind, "revision": revision,
                        "order": ["fresh", "persistent"] if revision % 2 else ["persistent", "fresh"]}
                source = original.replace("exp(-t * 3.0)", f"exp(-t * {3.0 + revision * 0.35:.2f})")
                if kind == "construction":
                    source = source.replace("_cores = 3 if trail else 8", f"_cores = 3 if trail else {8 + revision}")
                expected_count = (8 + (revision if kind == "construction" else 0)) * 2 + 4
                for mode in pair["order"]:
                    start = time.perf_counter()
                    _, write_s = timed(lambda: effect_file.write_text(source, encoding="utf-8"))
                    before_instance = state(live)["instance"] if mode == "persistent" else None
                    folder = Path(f"{kind}_{revision:02}_{mode}")
                    if mode == "fresh":
                        result = fresh_render(output / folder)
                        startup = result["status"]
                        update_s = result["update_s"]
                        simulation_s, capture_s, states = result["simulation_s"], result["capture_s"], result["states"]
                        total_s = write_s + result["elapsed_s"]
                        shutdown_s = result["shutdown_s"]
                    else:
                        startup = live.request({"op": "status"})
                        if startup["pid"] != live_pid:
                            raise AssertionError("Persistent PID changed")
                        _, update_s = timed(lambda: live.request({"op": "reload", "path": EFFECT}))
                        if kind == "construction":
                            _, load_s = timed(lambda: live.request({"op": "load", "scene": SCENE}))
                        else:
                            _, load_s = timed(lambda: live.request({"op": "call", "method": "replay"}))
                        update_s += load_s
                        instance = state(live)["instance"]
                        if kind == "motion" and instance != before_instance:
                            raise AssertionError("Hot reload replaced the effect instance")
                        simulation_s, capture_s, states = render(live, output / folder)
                        total_s = time.perf_counter() - start
                        shutdown_s = 0.0
                    if startup["window_visible"] or startup["mouse_captured"]:
                        raise AssertionError("Benchmark occupied the desktop")
                    for frame, sample in zip(FRAMES, states):
                        if not sample["alive"] or sample["count"] != expected_count:
                            raise AssertionError(f"Wrong live effect state: {sample}")
                        if abs(sample["age"] - frame / 60) > 0.00001:
                            raise AssertionError(f"Wrong simulation time: {sample}")
                    pair[mode] = dict(folder=folder.as_posix(), pid=startup["pid"], write_s=write_s,
                                      update_s=update_s, simulation_s=simulation_s, capture_s=capture_s,
                                      total_s=total_s, shutdown_s=shutdown_s, states=states)
                pair["pixel_checks"] = compare(output / pair["fresh"]["folder"], output / pair["persistent"]["folder"])
                if not all(check["identical_pixels"] for check in pair["pixel_checks"]):
                    raise AssertionError(f"Image mismatch: {pair['pixel_checks']}")
                report["pairs"].append(pair)
                print(f"{kind} {revision}: fresh={pair['fresh']['total_s']:.3f}s persistent={pair['persistent']['total_s']:.3f}s pixels=identical", flush=True)

        live.request({"op": "step", "frames": 12})
        report["cleanup_state"] = state(live)
        if report["cleanup_state"]["alive"]:
            raise AssertionError("Effect did not expire")
        report["summary"] = {}
        for kind in ("motion", "construction"):
            rows = [pair for pair in report["pairs"] if pair["kind"] == kind]
            medians = {mode: {key: statistics.median(pair[mode][key] for pair in rows)
                             for key in ("total_s", "update_s", "simulation_s", "capture_s")}
                       for mode in ("fresh", "persistent")}
            medians["saved_percent"] = 100 * (1 - medians["persistent"]["total_s"] / medians["fresh"]["total_s"])
            medians["distinct_revision_images"] = len({hashlib.sha256((output / pair["fresh"]["folder"] / "030.png").read_bytes()).hexdigest() for pair in rows})
            if medians["distinct_revision_images"] != len(rows):
                raise AssertionError("An edited revision did not change the rendered image")
            report["summary"][kind] = medians
        contact_sheet(output, report["pairs"])
        with (output / "timings.csv").open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=["kind", "revision", "mode", "pid", "write_s", "update_s", "simulation_s", "capture_s", "total_s", "shutdown_s"])
            writer.writeheader()
            for pair in report["pairs"]:
                for mode in ("fresh", "persistent"):
                    row = {key: pair[mode][key] for key in writer.fieldnames if key in pair[mode]}
                    writer.writerow(dict(row, kind=pair["kind"], revision=pair["revision"], mode=mode))
        print(json.dumps(report["summary"], indent=2), flush=True)
    finally:
        live.stop()
        effect_file.write_text(original, encoding="utf-8")
        (output / "results.json").write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pairs", type=int, default=5, help="Pairs per change type (default: 5)")
    parser.add_argument("--output", type=Path, default=ROOT / "godot/.godot/dev_session/vfx_benchmark")
    options = parser.parse_args()
    if options.pairs < 1:
        parser.error("--pairs must be at least 1")
    benchmark(options)
