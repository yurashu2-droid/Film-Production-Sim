"""Shared controlled VFX authoring review; serializes GPU use across both authors."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import sys
import time

from PIL import Image, ImageDraw
from dev_session import ROOT, Session
from dev_review import review

FRAMES = list(range(0, 43, 3)) + [48, 54, 60, 66, 72, 78, 84, 90]
KEY_FRAMES = [6, 9, 24, 42, 54]
VIEWS = [{"id": "game"}, {"id": "side", "position": [0, 1.4, 5.5], "target": [0, 1.05, 0], "fov": 35},
         {"id": "front", "position": [5.5, 1.4, 0.03], "target": [0, 1.05, 0], "fov": 35}]
SCENE = "res://addons/dev_session/benchmarks/punch_stage.tscn"


@contextmanager
def gpu_lock():
    path = ROOT / "godot/.godot/dev_session/punch_gpu.lock"
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a+b") as stream:
        stream.seek(0, 2)
        if stream.tell() == 0:
            stream.write(b"0")
            stream.flush()
        start = time.perf_counter()
        while True:
            stream.seek(0)
            try:
                if os.name == "nt":
                    import msvcrt
                    msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
                else:
                    import fcntl
                    fcntl.flock(stream.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError:
                if time.perf_counter() - start > 120:
                    raise TimeoutError("GPU capture lock busy for 120s")
                time.sleep(0.1)
        try:
            yield time.perf_counter() - start
        finally:
            if os.name == "nt":
                msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                fcntl.flock(stream.fileno(), fcntl.LOCK_UN)


def full_sheets(samples, output):
    paths = []
    for number in range(3):
        group = samples[number * 8:(number + 1) * 8]
        cols = 4
        rows = (len(group) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * 320, rows * 218 * len(VIEWS)), "#182028")
        draw = ImageDraw.Draw(sheet)
        for view_index, view in enumerate(VIEWS):
            for index, sample in enumerate(group):
                x, y = (index % cols) * 320, (view_index * rows + index // cols) * 218
                entry = next(im for im in sample["images"] if im["view"] == view["id"])
                with Image.open(entry["path"]) as source:
                    sheet.paste(source.convert("RGB").resize((320, 180)), (x, y + 28))
                draw.text((x + 5, y + 7), f'{view["id"]} / F{int(sample["frame"]):03} / {sample["time"]:.2f}s', fill="white")
        path = output / f"full_{number+1}.png"
        sheet.save(path)
        paths.append(str(path))
    return paths


def run(args):
    output = args.output.resolve() if args.output else ROOT / f"tools/diagnostics/punch-ab/{args.variant}/cycle_{args.iteration:02}"
    plan = {"scene": SCENE, "frames": FRAMES, "size": [640, 360], "views": VIEWS,
            "key_frames": KEY_FRAMES, "events": [{"frame": 0, "op": "call", "method": "begin", "args": [args.effect, 431]}],
            "checks": [{"id": "effects", "type": "group_count", "group": "vfx", "min": 0, "max": 16},
                       {"id": "expired_effects", "type": "property", "property": "expired_effects", "min": 0, "max": 0}]}
    with gpu_lock() as wait:
        session = Session(name="punch_" + args.variant)
        if args.stop:
            print(json.dumps(session.stop()))
            return
        startup = time.perf_counter()
        status = session.start("render")
        startup = time.perf_counter() - startup
        assert not status["window_visible"]
        before = session.log.stat().st_size
        output.mkdir(parents=True, exist_ok=True)
        start = time.perf_counter()
        calls = 0
        def request(payload):
            nonlocal calls
            calls += 1
            return session.request(payload, timeout=120)
        request({"op": "reload", "path": args.effect})
        if args.mode == "compact":
            summary = review(session, plan, output, limit=8)
            calls += 1
            paths = [summary["contact"]] + summary["details"]
            feedback = dict(summary)
        else:
            request({"op": "load", "scene": SCENE})
            request(plan["events"][0])
            samples = []
            previous = 0
            for frame in FRAMES:
                if frame > previous:
                    request({"op": "step", "frames": frame - previous})
                result = request(dict(plan, op="capture_views", scene="", output=str(output / f"frame_{frame:03}")))
                sample = json.loads(Path(result["manifest"]).read_text(encoding="utf-8"))["samples"][0]
                sample.update(frame=frame, time=frame / 60)
                samples.append(sample)
                previous = frame
            (output / "manifest.json").write_text(json.dumps({"scenario": plan, "samples": samples}, indent=2), encoding="utf-8")
            paths = full_sheets(samples, output)
            feedback = {"samples": samples}
        with session.log.open("rb") as stream:
            stream.seek(before)
            logs = stream.read().decode("utf-8", errors="replace")
        errors = [line for line in logs.splitlines() if "ERROR" in line or "WARNING:" in line]
        (output / "engine.log").write_text(logs, encoding="utf-8")
        elapsed = time.perf_counter() - start
        pixels = 0
        for path in paths:
            with Image.open(path) as image:
                pixels += image.width * image.height
        record = {"mode": args.mode, "variant": args.variant, "iteration": args.iteration,
                  "recorded_at": datetime.now(timezone.utc).isoformat(), "pid": status["pid"],
                  "gpu_lock_wait_s": round(wait, 3), "startup_or_reuse_s": round(startup, 3),
                  "review_s": round(elapsed, 3), "rpc_calls": calls, "image_files": paths,
                  "image_pixels": pixels, "error_lines": len(errors), "error_excerpt": errors[:4]}
        feedback.update(metrics=record)
        encoded = json.dumps(feedback, ensure_ascii=False, indent=2)
        record["feedback_chars"] = 0
        for _ in range(3):
            encoded = json.dumps(feedback, ensure_ascii=False, indent=2)
            if record["feedback_chars"] == len(encoded):
                break
            record["feedback_chars"] = len(encoded)
        (output / "feedback.json").write_text(encoded, encoding="utf-8")
        (output / "metrics.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
        print(encoded)


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mode", choices=["full", "compact"], required=True)
    p.add_argument("--variant", required=True)
    p.add_argument("--effect", required=True)
    p.add_argument("--iteration", type=int, default=0)
    p.add_argument("--output", type=Path)
    p.add_argument("--stop", action="store_true")
    run(p.parse_args())
