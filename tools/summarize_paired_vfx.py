"""Aggregate paired marker timings and actual per-author token-counter deltas."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import statistics

from PIL import Image
from paired_vfx_benchmark import ROOT, TASKS, candidate, folder


def stamp(value):
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def token_records(path):
    records=[]
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        item=json.loads(line)
        if item.get("type")=="event_msg" and item["payload"].get("type")=="token_count":
            records.append((stamp(item["timestamp"]),item["payload"]["info"]["total_token_usage"]))
    if not records:raise ValueError("No measured token counters")
    return records


def before(records, time):
    found=[value for timestamp,value in records if timestamp<=time]
    return found[-1] if found else {}


def subtract(last,first):
    result={key:last.get(key,0)-first.get(key,0) for key in ("input_tokens","cached_input_tokens","output_tokens","reasoning_output_tokens")}
    result["uncached_input_tokens"]=result["input_tokens"]-result["cached_input_tokens"]
    if any(value<0 for value in result.values()):raise ValueError("Non-monotonic counters; do not publish misleading deltas")
    return result


def summarize(left,right):
    workers={"left":token_records(left),"right":token_records(right)}
    audit=json.loads((ROOT/"tools/diagnostics/punch-paired/common-audit/audit.json").read_text(encoding="utf-8"))
    pairs=[]
    per_worker={w:[] for w in workers}
    for case in TASKS:
        pair={"case":case,"task":TASKS[case]}
        for worker,events in workers.items():
            record=json.loads((candidate(worker,case).parent/"timing.json").read_text(encoding="utf-8"))
            tokens=subtract(before(events,stamp(record["finished_utc"])),before(events,stamp(record["started_utc"])))
            if not tokens["output_tokens"]:raise ValueError("Token interval empty; inspect markers/log timestamps")
            images=record["inspection"]["inspected_images"]
            pixels=0
            for name in images:
                with Image.open(name) as im:pixels+=im.width*im.height
            waits=sum(c["gpu_lock_wait_s"] for c in record["cycles"])
            qa=next(r for r in audit["results"] if r["worker"]==worker and r["case"]==case)
            mode=record["mode"]
            pair[mode]={"worker":worker,"elapsed_s":record["elapsed_s"],"gpu_wait_s":round(waits,3),
                "elapsed_without_gpu_wait_s":round(record["elapsed_s"]-waits,3),
                "capture_sum_s":round(sum(c["review_s"] for c in record["cycles"]),3),
                "capture_cycles":len(record["cycles"]),"reported_inspected_images":len(images),"reported_inspected_source_pixels":pixels,
                "tokens":tokens,"quality":{"compared_images":qa["compared_images"],"different_images":len(qa["pixel_differences"]),"failed_checks":len(qa["failed_checks"])},
                "patch":record["patch"],"residual_issues":record["inspection"].get("residual_issues",[])}
            per_worker[worker].append(tokens)
        f,c=pair["full"],pair["compact"]
        pair["compact_saving_s"]=round(f["elapsed_without_gpu_wait_s"]-c["elapsed_without_gpu_wait_s"],3)
        pair["compact_saving_fraction"]=(f["elapsed_without_gpu_wait_s"]-c["elapsed_without_gpu_wait_s"])/f["elapsed_without_gpu_wait_s"]
        pairs.append(pair)
    shared={}
    for worker,events in workers.items():
        all_tokens=subtract(events[-1][1],{})
        measured={key:sum(t[key] for t in per_worker[worker]) for key in all_tokens}
        shared[worker]={"whole_worker":all_tokens,"outside_case_intervals":{key:all_tokens[key]-measured[key] for key in all_tokens}}
    totals={}
    for mode in ("full","compact"):
        entries=[p[mode] for p in pairs]
        totals[mode]={"elapsed_s":round(sum(e["elapsed_s"] for e in entries),3),
            "elapsed_without_gpu_wait_s":round(sum(e["elapsed_without_gpu_wait_s"] for e in entries),3),
            "capture_sum_s":round(sum(e["capture_sum_s"] for e in entries),3),
            "reported_inspected_images":sum(e["reported_inspected_images"] for e in entries),
            "reported_inspected_source_pixels":sum(e["reported_inspected_source_pixels"] for e in entries),
            "tokens":{key:sum(e["tokens"][key] for e in entries) for key in entries[0]["tokens"]}}
    result={"pairs":pairs,"totals":totals,"compact_time_wins":sum(p["compact_saving_s"]>0 for p in pairs),
        "median_compact_time_saving_fraction":statistics.median(p["compact_saving_fraction"] for p in pairs),
        "worker_tokens":shared,"common_render_errors":audit["render_errors"],
        "common_audit_engine_s":round(sum(json.loads(p.read_text(encoding="utf-8"))["elapsed_s"] for p in (ROOT/"tools/diagnostics/punch-paired/common-audit").glob("*/manifest.json")),3),
        "source":json.loads((folder()/"prepared.json").read_text(encoding="utf-8")),
        "limits":"Five seeded repairs, not five new creations. Same batching/logs; isolated visual evidence difference. Warmup, shared reading/between-case model turns, parent setup and common audit excluded from paired task times. Token deltas use final cumulative counters immediately before markers; shared author overhead reported separately. Parent/reviewer token costs not included. Viewed paths self-reported. Dense audit covers sampled frames only."}
    output=ROOT/"docs/benchmarks/punch-paired-results.json"
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding="utf-8")
    print(json.dumps({key:result[key] for key in ("totals","compact_time_wins","median_compact_time_saving_fraction","common_render_errors")},ensure_ascii=False,indent=2))


if __name__=="__main__":
    import sys
    sys.stdout.reconfigure(encoding="utf-8")
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--rollout-left",type=Path,required=True)
    p.add_argument("--rollout-right",type=Path,required=True)
    args=p.parse_args()
    summarize(args.rollout_left,args.rollout_right)
