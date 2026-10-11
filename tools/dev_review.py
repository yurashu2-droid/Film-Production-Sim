"""Compact evidence for a single synchronized Godot review. Pillow loads lazily."""
import json
from pathlib import Path
import time


def select_samples(samples, limit=6):
    """Retain onset/midpoint/exit and the worst numeric failure plus neighbors."""
    if not samples:
        return []
    limit = max(3, min(8, int(limit)))
    if len(samples) <= limit:
        return list(range(len(samples)))
    selected = {0, len(samples) // 2, len(samples) - 1}
    worst = max(range(len(samples)), key=lambda i: max((c.get("severity", 0) for c in samples[i]["checks"]), default=0))
    if any(not c["passed"] for c in samples[worst]["checks"]):
        for index in (worst, max(0, worst - 1), min(len(samples) - 1, worst + 1)):
            if len(selected) < limit:
                selected.add(index)
    for fraction in (0.75, 0.25):
        if len(selected) < limit:
            selected.add(round((len(samples) - 1) * fraction))
    while len(selected) < limit:
        index = max((i for i in range(len(samples)) if i not in selected),
                    key=lambda i: (min(abs(i - chosen) for chosen in selected), i))
        selected.add(index)
    return sorted(selected)


def _images(manifest, folder, selected):
    from PIL import Image, ImageDraw
    samples = manifest["samples"]
    views = [entry["view"] for entry in samples[0]["images"]]
    tile_w, tile_h = 320, 180
    sheet = Image.new("RGB", (tile_w * len(selected), (tile_h + 38) * len(views)), "#182028")
    draw = ImageDraw.Draw(sheet)
    for row, view in enumerate(views):
        for col, index in enumerate(selected):
            sample = samples[index]
            entry = next(image for image in sample["images"] if image["view"] == view)
            with Image.open(entry["path"]) as image:
                thumb = image.convert("RGB")
                thumb.thumbnail((tile_w, tile_h))
                sheet.paste(thumb, (col * tile_w, row * (tile_h + 38) + 28))
            bad = any(not c["passed"] for c in sample["checks"])
            label = f'{view} / F{int(sample["frame"]):03} / {sample["time"]:.2f}s' + (" / FAIL" if bad else "")
            draw.text((col * tile_w + 5, row * (tile_h + 38) + 7), label, fill="#ff9977" if bad else "white")
    contact = folder / "contact.png"
    sheet.save(contact)
    pixels = sheet.width * sheet.height
    details = []
    failures = [(c.get("severity", 0), i, c) for i, sample in enumerate(samples) for c in sample["checks"] if not c["passed"]]
    if failures:
        _, index, check = max(failures, key=lambda item: item[0])
        # Keep a legible detail of the measured worst frame, preferring the side view.
        entry = next((im for im in samples[index]["images"] if im["view"] == "side"), samples[index]["images"][0])
        path = folder / "worst_detail.png"
        with Image.open(entry["path"]) as image:
            points = entry.get("focus", {}).get(check["id"], [])
            points = [(x, y) for x, y in points if 0 <= x < image.width and 0 <= y < image.height]
            if points:
                cx = sum(x for x, y in points) / len(points)
                cy = sum(y for x, y in points) / len(points)
                width = min(image.width, max(192, int(max(x for x, y in points) - min(x for x, y in points)) + 96))
                height = min(image.height, 144)
                left = max(0, min(image.width - width, int(cx - width / 2)))
                top = max(0, min(image.height - height, int(cy - height / 2)))
                image = image.crop((left, top, left + width, top + height))
                image = image.resize((width * 2, height * 2))
            image.convert("RGB").save(path)
            pixels += image.width * image.height
        details.append(str(path))
    return str(contact), details, pixels


def summarize(manifest_path, *, limit=6, log_text=""):
    path = Path(manifest_path).resolve()
    folder = path.parent
    manifest = json.loads(path.read_text(encoding="utf-8"))
    samples = manifest["samples"]
    selected = select_samples(samples, limit)
    contact, details, selected_pixels = _images(manifest, folder, selected)
    failures = [(sample, check) for sample in samples for check in sample["checks"] if not check["passed"]]
    worst = sorted(failures, key=lambda pair: pair[1].get("severity", 0), reverse=True)
    alerts = [{"frame": int(sample["frame"]), "check": check["id"], "value": round(check["value"], 5),
               "severity": round(check.get("severity", 0), 5)} for sample, check in worst[:3]]
    raw_images = [image for sample in samples for image in sample["images"]]
    errors = [line[:400] for line in log_text.splitlines() if "ERROR" in line or "WARNING:" in line]
    if log_text:
        (folder / "engine.log").write_text(log_text, encoding="utf-8")
    summary = {"report": str(folder / "report.md"), "contact": contact, "details": details,
               "sampled_frames": len(samples), "selected_frames": [int(samples[i]["frame"]) for i in selected],
               "views": len(samples[0]["images"]), "alerts": alerts, "failed_readings": len(failures),
               "errors": errors[:4], "error_lines": len(errors),
               "raw_images": len(raw_images), "raw_pixels": sum(im["width"] * im["height"] for im in raw_images),
               "review_images": 1 + len(details), "review_pixels": selected_pixels,
               "note": "Sampled checks only; full evidence retained. Text/pixel counts are token proxies, not actual token usage."}
    (folder / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    lines = ["# Godot review", "", f"Samples: {len(samples)}; views: {summary['views']}; failed readings: {len(failures)}; error lines: {len(errors)}.",
             f"Selected frames: {summary['selected_frames']}. One scene / same frozen physics frame for each camera.", "",
             "Checks are sampled at the captured and scheduled event frames. A clean result does not cover unsampled frames.",
             "Feet checks measure the supplied sole position relative to an explicit fixed ground plane; use on flat test stages, not arbitrary terrain.",
             "Visual quality still needs inspection of onset, motion and exit. No video playback inspection is claimed.", "",
             "## Worst sampled readings", "", "```json", json.dumps(alerts, ensure_ascii=False, indent=2), "```", "",
             "## Evidence", "", "![Views and timeline](contact.png)"]
    if details:
        lines += ["", "![Worst reading detail](worst_detail.png)"]
    lines += ["", "[Full manifest](manifest.json) · [Compact summary](summary.json)", "",
              f"Image pixel budget: {summary['raw_pixels']} raw -> {summary['review_pixels']} selected (including labels/details).",
              "This is not a measured model-token reduction.", ""]
    (folder / "report.md").write_text("\n".join(lines), encoding="utf-8")
    return summary


def review(session, scenario, output, *, limit=6):
    output = Path(output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    plan = dict(scenario, op="review", output=str(output))
    before = session.log.stat().st_size if session.log.exists() else 0
    start = time.perf_counter()
    result = session.request(plan, timeout=120)
    with session.log.open("rb") as stream:
        stream.seek(before)
        log_text = stream.read().decode("utf-8", errors="replace")
    summary = summarize(result["manifest"], limit=limit, log_text=log_text)
    summary["elapsed_s"] = round(time.perf_counter() - start, 3)
    (output / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
    return summary
