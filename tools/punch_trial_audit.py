"""Common fine-frame audit and normal-speed preview of both punch trial outputs."""
import json
from pathlib import Path
import time

from PIL import Image, ImageDraw
from dev_session import ROOT, Session
from punch_workflow_trial import gpu_lock, SCENE, VIEWS


def sheets(samples, output, label):
    paths = []
    # Dense peak; adjacent middle/exit frames. All 46 raw samples remain available.
    groups = [list(range(0, 22, 2)), list(range(22, 46, 2)), list(range(46, 68, 2)) + [78, 90]]
    for number, frames in enumerate(groups):
        columns = 4
        rows = (len(frames) + columns - 1) // columns
        sheet = Image.new("RGB", (1280, rows * 206 * 3), "#182028")
        draw = ImageDraw.Draw(sheet)
        for vi, view in enumerate(VIEWS):
            for i, frame in enumerate(frames):
                sample = next(s for s in samples if int(s["frame"]) == frame)
                entry = next(im for im in sample["images"] if im["view"] == view["id"])
                x, y = (i % columns) * 320, (vi * rows + i // columns) * 206
                with Image.open(entry["path"]) as image:
                    sheet.paste(image.convert("RGB").resize((320, 180)), (x, y + 24))
                draw.text((x + 4, y + 5), f"{label} {view['id']} F{frame:02} {frame/60:.3f}s", fill="white")
        path = output / f"{label}_{number}.png"
        sheet.save(path)
        paths.append(str(path))
    return paths


def run():
    output = ROOT / "tools/diagnostics/punch-ab/common-audit"
    output.mkdir(parents=True, exist_ok=True)
    # Fixed anonymous mapping, kept outside the blind image folder.
    mapping = {"X": "b", "Y": "a"}
    blind = output / "blind"
    blind.mkdir(exist_ok=True)
    record = {"mapping": mapping, "samples": {}, "sheets": {}, "checks": {}}
    with gpu_lock():
        session = Session(name="punch_common_audit")
        try:
            status = session.start("render")
            before = session.log.stat().st_size
            start = time.perf_counter()
            for label, variant in mapping.items():
                result = session.request({"op": "review", "scene": SCENE,
                    "frames": list(range(0, 91, 2)), "size": [800, 450], "views": VIEWS,
                    "output": str(output / variant),
                    "events": [{"frame": 0, "op": "call", "method": "begin",
                                "args": [f"res://vfx/punch_trial_{variant}/punch.gd", 431]}],
                    "checks": [{"id": "expired_effects", "type": "property", "property": "expired_effects", "min": 0, "max": 0}]}, timeout=120)
                manifest = json.loads(Path(result["manifest"]).read_text(encoding="utf-8"))
                record["samples"][variant] = manifest["samples"]
                record["sheets"][label] = sheets(manifest["samples"], blind, label)
                record["checks"][variant] = [r for s in manifest["samples"] for r in s["checks"] if not r["passed"]]
            record["capture_and_sheet_s"] = round(time.perf_counter() - start, 3)
            with session.log.open("rb") as stream:
                stream.seek(before)
                logs = stream.read().decode("utf-8", errors="replace")
            (output / "engine.log").write_text(logs, encoding="utf-8")
            record["error_lines"] = [line for line in logs.splitlines() if "ERROR" in line or "WARNING:" in line]
            final_status = session.request({"op": "status"})
            record["status"] = {key: final_status[key] for key in ("paused", "window_visible", "pid")}
        finally:
            session.stop()
    # Reconstruct normal-speed motion from synchronized Godot renders (30 fps).
    frames = []
    for index, frame in enumerate(range(0, 91, 2)):
        image = Image.new("RGB", (1280, 384), "#182028")
        draw = ImageDraw.Draw(image)
        for column, variant in enumerate(("a", "b")):
            sample = record["samples"][variant][index]
            entry = next(im for im in sample["images"] if im["view"] == "game")
            with Image.open(entry["path"]) as source:
                image.paste(source.convert("RGB").resize((640, 360)), (column * 640, 24))
            draw.text((column * 640 + 8, 6), f"{'A / full' if variant == 'a' else 'B / compact'}  {frame/60:.2f}s", fill="white")
        frames.append(image)
    durations = [30 if i % 3 != 1 else 40 for i in range(len(frames))]
    durations[-1] = 700
    preview = output / "punch-comparison.gif"
    frames[0].save(preview, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=False)
    record["preview"] = str(preview)
    (output / "audit.json").write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in record.items() if key != "samples"}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    run()
