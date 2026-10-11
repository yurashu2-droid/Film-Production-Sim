"""Five counterbalanced, byte-identical punch repair tasks. Not new-creation timing."""
import argparse
from datetime import datetime, timezone
import difflib
import hashlib
import json
import time
from pathlib import Path
from types import SimpleNamespace

from PIL import Image, ImageChops
from dev_session import ROOT, Session
from punch_workflow_trial import run as warm_capture, gpu_lock, SCENE, VIEWS, FRAMES, KEY_FRAMES, full_sheets
from dev_review import review

TASKS = {
    1: "衝撃が大きすぎます。参考人形1.7mに対して幅を約1.0〜1.4mに戻し、既存の形と時間を維持してください。",
    2: "ヒットが遅れ、拳が戻ってから出ます。予備動作は短く、0.10〜0.16秒にヒットが読めるよう、既存の動作全体の時刻を直してください。",
    3: "衝撃が拳の進行方向と逆へ抜けます。渡されたdirection（撮影では+X）へ押し出されるよう、既存の形と時間を維持して直してください。",
    4: "主層の形が中盤から止まり、退出の供給カットが進みません。0.16〜0.45秒の前進・時間差と、0.45〜0.90秒の根元から切れて抜ける動作を回復してください。新しい見た目には作り直さないでください。",
    5: "見えなくなった後もVFXノードが残ります。等速で寿命1.2秒以内、1.5秒にはノードも片付くよう直し、見えている間の形と時間は維持してください。",
}


def utc():
    return datetime.now(timezone.utc).isoformat()


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def folder(root=ROOT):
    return root / "godot/.godot/dev_session/punch_paired"


def candidate(worker, case, root=ROOT):
    return folder(root) / worker / f"case_{case:02}" / "punch.gd"


def evidence(worker, case):
    return ROOT / f"tools/diagnostics/punch-paired/{worker}/case_{case:02}"


def mode_for(worker, case):
    return "full" if (case % 2 == 1) == (worker == "left") else "compact"


def resource(path):
    return "res://" + path.relative_to(ROOT / "godot").as_posix()


def inject(code, case):
    old, new = {
        1: ("effect._size = size", "effect._size = size * 1.8"),
        2: ("effect.life = 1.05", "effect.life = 1.05\n\teffect.age = -0.18"),
        3: ("effect._axis = direction.normalized()", "effect._axis = -direction.normalized()"),
        4: ("var t := age - float(i) * 0.014", "var t := minf(age, 0.14) - float(i) * 0.014"),
        5: ("effect.life = 1.05", "effect.life = 0.0"),
    }[case]
    if code.count(old) != 1:
        raise ValueError(f"Canonical source changed at task {case}; do not silently skip injection")
    return code.replace(old, new, 1)


def prepare_files(root=ROOT):
    target = folder(root)
    target.mkdir(parents=True, exist_ok=True)
    if (target / "prepared.json").exists():
        raise ValueError("Already prepared; preserve this experiment instead of overwriting results")
    source = root / "godot/vfx/punch_trial_a/punch.gd"
    shader = root / "godot/vfx/punch_trial_a/mark.gdshader"
    frozen_shader = target / "mark.gdshader"
    frozen_shader.write_bytes(shader.read_bytes())
    canonical = source.read_text(encoding="utf-8").replace(
        "res://vfx/punch_trial_a/mark.gdshader", "res://.godot/dev_session/punch_paired/mark.gdshader")
    (target / "canonical.gd").write_text(canonical, encoding="utf-8")
    record = {"prepared_utc": utc(), "source_sha256": sha(source), "shader_sha256": sha(shader), "tasks": []}
    for case in TASKS:
        text = inject(canonical, case)
        for worker in ("left", "right"):
            path = candidate(worker, case, root)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
            (path.parent / "initial.txt").write_text(text, encoding="utf-8")
            record["tasks"].append({"worker": worker, "case": case, "mode": mode_for(worker, case), "initial_sha256": sha(path)})
        assert candidate("left", case, root).read_bytes() == candidate("right", case, root).read_bytes()
    (target / "prepared.json").write_text(json.dumps(record, indent=2), encoding="utf-8")
    return record


def capture_args(worker, case, iteration):
    return SimpleNamespace(mode=mode_for(worker, case), variant="paired_" + worker,
        effect=resource(candidate(worker, case)), iteration=iteration,
        output=evidence(worker, case) / f"cycle_{iteration:02}", stop=False)


def capture_batched(args):
    """Both arms use the same batch request and short numeric summary."""
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    plan = {"scene":SCENE,"frames":FRAMES,"key_frames":KEY_FRAMES,"size":[640,360],"views":VIEWS,
        "events":[{"frame":0,"op":"call","method":"begin","args":[args.effect,431]}],
        "checks":[{"id":"effects","type":"group_count","group":"vfx","min":0,"max":16},
                  {"id":"expired_effects","type":"property","property":"expired_effects","min":0,"max":0}]}
    with gpu_lock() as wait:
        session = Session(name="punch_"+args.variant)
        reuse = time.perf_counter()
        status = session.start("render")
        reuse = time.perf_counter()-reuse
        if status["window_visible"]:raise RuntimeError("Capture window became visible")
        started=time.perf_counter()
        session.request({"op":"reload","path":args.effect})
        summary=review(session,plan,output,limit=8)
        if args.mode=="full":
            manifest=json.loads((output/"manifest.json").read_text(encoding="utf-8"))
            images=full_sheets(manifest["samples"],output)+summary["details"]
        else:images=[summary["contact"]]+summary["details"]
        pixels=0
        for name in images:
            with Image.open(name) as im:pixels+=im.width*im.height
        metrics={"mode":args.mode,"iteration":args.iteration,"recorded_at":utc(),"pid":status["pid"],
            "gpu_lock_wait_s":round(wait,3),"startup_or_reuse_s":round(reuse,3),
            "review_s":round(time.perf_counter()-started,3),"rpc_calls":2,"image_files":images,
            "image_pixels":pixels,"error_lines":summary["error_lines"]}
        feedback={"images":images,"manifest":str(output/"manifest.json"),"presented_frames":FRAMES if args.mode=="full" else summary["selected_frames"],
            "alerts":summary["alerts"],"failed_readings":summary["failed_readings"],"errors":summary["errors"],"metrics":metrics}
        encoded=json.dumps(feedback,ensure_ascii=False,indent=2)
        (output/"feedback.json").write_text(encoded,encoding="utf-8")
        metrics["feedback_chars"]=len(encoded)
        (output/"metrics.json").write_text(json.dumps(metrics,indent=2),encoding="utf-8")
        print(encoded)


def start(worker, case):
    path = candidate(worker, case)
    marker = path.parent / "timing.json"
    if marker.exists():
        raise ValueError("Task already started; do not reset its timer")
    prepared = json.loads((folder() / "prepared.json").read_text(encoding="utf-8"))
    expected = next(r["initial_sha256"] for r in prepared["tasks"] if r["worker"] == worker and r["case"] == case)
    if sha(path) != expected:
        raise ValueError("Candidate changed before timing began")
    for other in (folder()/worker).glob("case_*/timing.json"):
        if "finished_utc" not in json.loads(other.read_text(encoding="utf-8")):
            raise ValueError("Finish the current task before starting another")
    # Warmup occurs before workers start; reuse and lock waits are still logged per capture.
    record = {"worker": worker, "case": case, "mode": mode_for(worker, case), "started_utc": utc(),
        "initial_sha256": sha(path), "candidate": str(path), "review_path": str(path.parent / "review.json"),
        "task": TASKS[case]}
    marker.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(record, ensure_ascii=False, indent=2))


def finish(worker, case):
    path = candidate(worker, case)
    marker = path.parent / "timing.json"
    record = json.loads(marker.read_text(encoding="utf-8"))
    if "finished_utc" in record:
        raise ValueError("Already finished")
    inspection = json.loads((path.parent / "review.json").read_text(encoding="utf-8"))
    if not inspection.get("inspected_images") or not inspection.get("fix_summary"):
        raise ValueError("Record actual viewed images and fix summary before finish")
    for name in inspection["inspected_images"]:
        if not Path(name).is_file():
            raise ValueError("Missing reported evidence: " + name)
    cycles = sorted(evidence(worker, case).glob("cycle_*/metrics.json"))
    if len(cycles) < 2:
        raise ValueError("Baseline and repaired capture both required")
    last = json.loads(cycles[-1].read_text(encoding="utf-8"))
    manifest = json.loads((cycles[-1].parent / "manifest.json").read_text(encoding="utf-8"))
    if last["error_lines"] or any(not check["passed"] for s in manifest["samples"] for check in s["checks"]):
        raise ValueError("Final capture still has errors or failed sampled checks")
    record["finished_utc"] = utc()
    record["elapsed_s"] = round((datetime.fromisoformat(record["finished_utc"]) - datetime.fromisoformat(record["started_utc"])).total_seconds(), 3)
    record["final_sha256"] = sha(path)
    record["patch"] = "".join(difflib.unified_diff((path.parent / "initial.txt").read_text(encoding="utf-8").splitlines(keepends=True), path.read_text(encoding="utf-8").splitlines(keepends=True), fromfile="initial.gd", tofile="repaired.gd"))
    record["inspection"] = inspection
    record["cycles"] = [json.loads(p.read_text(encoding="utf-8")) for p in cycles]
    marker.write_text(json.dumps(record, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({k:record[k] for k in ("worker", "case", "mode", "elapsed_s", "finished_utc")}, ensure_ascii=False))


def audit():
    target = ROOT / "tools/diagnostics/punch-paired/common-audit"
    target.mkdir(parents=True, exist_ok=True)
    results = []
    for worker in ("left", "right"):
        for case in TASKS:
            record = json.loads((candidate(worker, case).parent / "timing.json").read_text(encoding="utf-8"))
            if "finished_utc" not in record:
                raise ValueError("All repairs must finish before audit")
            if sha(candidate(worker,case)) != record["final_sha256"]:
                raise ValueError("Candidate changed after finish")
    prepared = json.loads((folder() / "prepared.json").read_text(encoding="utf-8"))
    if sha(folder() / "mark.gdshader") != prepared["shader_sha256"]:
        raise ValueError("Frozen shared shader changed; experiment is invalid")
    with gpu_lock():
        s = Session(name="punch_paired_audit")
        try:
            s.start("render")
            before = s.log.stat().st_size
            def render(path, label):
                result = s.request({"op":"review", "scene":SCENE,"frames":list(range(0,91,2)),
                    "size":[640,360],"views":VIEWS,"output":str(target/label),
                    "events":[{"frame":0,"op":"call","method":"begin","args":[resource(path),431]}],
                    "checks":[{"id":"expired_effects","type":"property","property":"expired_effects","min":0,"max":0}]}, timeout=120)
                return json.loads(Path(result["manifest"]).read_text(encoding="utf-8"))
            golden = render(folder() / "canonical.gd", "canonical")
            print("Canonical rendered", flush=True)
            for case in TASKS:
                for worker in ("left", "right"):
                    manifest = render(candidate(worker, case), f"{worker}_{case:02}")
                    differences = []
                    for expected, actual in zip(golden["samples"], manifest["samples"], strict=True):
                        for gi, ai in zip(expected["images"], actual["images"], strict=True):
                            with Image.open(gi["path"]) as a, Image.open(ai["path"]) as b:
                                box = ImageChops.difference(a.convert("RGB"), b.convert("RGB")).getbbox()
                            if box:
                                differences.append({"frame":int(actual["frame"]),"view":ai["view"],"bbox":box,"expected":gi["path"],"actual":ai["path"]})
                    failed = [c for sample in manifest["samples"] for c in sample["checks"] if not c["passed"]]
                    results.append({"worker":worker,"case":case,"compared_images":len(manifest["samples"])*len(VIEWS),"pixel_differences":differences,"failed_checks":failed})
                    print(f"{worker} case {case}: {len(differences)} differing images, {len(failed)} failed checks", flush=True)
            with s.log.open("rb") as stream:
                stream.seek(before)
                logs = stream.read().decode("utf-8",errors="replace")
            (target/"engine.log").write_text(logs,encoding="utf-8")
            errors = [line for line in logs.splitlines() if "ERROR" in line or "WARNING:" in line]
        finally:
            s.stop()
            for worker in ("left","right"):
                Session(name="punch_paired_"+worker).stop()
    report = {"render_errors":errors,"results":results,"note":"Same final 46-frame / 3-view evidence compared with frozen canonical; inspect differences rather than assuming every valid fix is pixel-identical."}
    (target/"audit.json").write_text(json.dumps(report,indent=2),encoding="utf-8")


def main():
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("op",choices=["prepare","start","capture","finish","audit"])
    p.add_argument("--worker",choices=["left","right"])
    p.add_argument("--case",type=int,choices=list(TASKS))
    p.add_argument("--iteration",type=int,default=0)
    args=p.parse_args()
    if args.op=="prepare":
        record=prepare_files()
        print(json.dumps(record,indent=2))
        for worker in ("left","right"):
            warm_capture(SimpleNamespace(mode="compact",variant="paired_"+worker,effect=resource(folder()/"canonical.gd"),iteration=0,output=ROOT/f"tools/diagnostics/punch-paired/warm_{worker}",stop=False))
    elif args.op=="audit":audit()
    else:
        if args.worker is None or args.case is None:p.error("worker and case required")
        if args.op=="start":start(args.worker,args.case)
        elif args.op=="capture":
            if not (candidate(args.worker,args.case).parent/"timing.json").exists():p.error("start before capture")
            if (evidence(args.worker,args.case)/f"cycle_{args.iteration:02}"/"manifest.json").exists():p.error("preserve existing capture; use a new iteration")
            capture_batched(capture_args(args.worker,args.case,args.iteration))
        else:finish(args.worker,args.case)


if __name__=="__main__":main()
