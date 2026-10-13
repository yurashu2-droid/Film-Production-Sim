"""Capture only our dedicated hidden Godot session, then shut it down."""
from pathlib import Path
import json
import sys
import os

OUT = Path(__file__).resolve().parent
REPO = OUT.parents[3]
sys.path.insert(0, str(REPO / "tools"))
from dev_session import Session
from build_assets import STATES, SOURCE, MODEL
import hashlib

def capture():
    # Keep shader cache and user data inside this authorized working directory.
    userdata = REPO / "tools/diagnostics/robot_expressions_v1/userdata"
    userdata.mkdir(parents=True, exist_ok=True)
    os.environ["APPDATA"] = str(userdata)
    renders = OUT / "renders"
    renders.mkdir(exist_ok=True)
    session = Session(name="robot_expressions_v1")
    before = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in (SOURCE, MODEL)}
    try:
        session.start("render")
        session.request({"op": "load", "scene": "res://assets/characters/robot_expressions_v1/preview.tscn"})
        print("OWN_SESSION", json.dumps(session.request({"op": "status"})))
        inspection = session.request({"op": "call", "method": "inspection"})
        (OUT / "render_inspection.json").write_text(json.dumps(inspection, indent=2), encoding="utf-8")
        session.request({"op": "capture", "path": str(renders / "source_body.png")})
        session.request({"op": "call", "method": "set_view", "args": ["face", "front"]})
        session.request({"op": "capture", "path": str(renders / "source_face.png")})
        for i, (name, _, _) in enumerate(STATES):
            session.request({"op": "call", "method": "apply_expression", "args": [i]})
            for mode in ("body", "face"):
                session.request({"op": "call", "method": "set_view", "args": [mode, "front"]})
                session.request({"op": "capture", "path": str(renders / f"{name}_{mode}.png")})
            session.request({"op": "call", "method": "set_view", "args": ["face", "diagonal"]})
            session.request({"op": "capture", "path": str(renders / f"{name}_diagonal.png")})
            print("RENDERED", name, flush=True)
    finally:
        session.stop()
    after = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in (SOURCE, MODEL)}
    assert before == after, "Existing source changed during preview."
    (OUT / "source_guard.json").write_text(json.dumps({"before": before, "after": after, "unchanged": True}, indent=2), encoding="utf-8")
    print("ROBOT_EXPRESSIONS_RENDER_OK 20 captures; own_session_stopped=True; sources_unchanged=True")

if __name__ == "__main__":
    capture()
