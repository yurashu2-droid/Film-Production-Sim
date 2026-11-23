"""Capture matching MAP views; temporary old scripts are reconstructed from Git."""
import argparse
from pathlib import Path
import subprocess

from dev_session import Session


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine", type=Path)
    parser.add_argument("--baseline", default="9ee51d5cf975b6429df81a0c353447af73a0e75b")
    parser.add_argument("--views", nargs="+", default=[
        "wide", "amenities", "service", "truck", "hopper", "junk", "road",
        "mailbox", "appliances", "television"])
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    fixture = root / "godot/tools/map_scenery_baseline"
    fixture.mkdir(parents=True, exist_ok=True)
    (fixture / ".gdignore").touch()
    names = ["production_office", "production_yard", "dump_dressing", "ward_lot"]
    for name in names:
        source = subprocess.check_output([
            "git", "show", f"{args.baseline}:godot/scripts/{name}.gd"], cwd=root).decode("utf-8")
        for dependency in names:
            source = source.replace(f"res://scripts/{dependency}.gd",
                                    f"res://tools/map_scenery_baseline/{dependency}.gd")
        (fixture / f"{name}.gd").write_text(source, encoding="utf-8")
    out = root / "artifacts/map-scenery"
    out.mkdir(parents=True, exist_ok=True)
    session = Session(project=root / "godot", name="map_scenery_review", engine=args.engine)
    session.start("render")
    try:
        session.request({"op": "load", "scene": "res://tools/map_scenery_review.tscn"})
        for old in (True, False):
            for view in args.views:
                session.request({"op": "call", "method": "show_view", "args": [view, old]})
                session.request({"op": "capture", "path": str(out / f"{view}_{'old' if old else 'new'}.png")})
        print("MAP_COMPARISONS_CAPTURED")
    finally:
        session.stop()


if __name__ == "__main__":
    main()
