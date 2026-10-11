# Compact Godot Review Implementation Plan

> Execute inline with superpowers:executing-plans. User AGENTS permits implementation without design approval; one feature-level review at the end.

**Goal:** Run a repeatable multi-camera review with one client request, retain evidence locally, return a small useful summary.

**Architecture:** A development-only capture helper shares the running scene's World3D with additional SubViewports. The runtime executes scheduled calls/input/sets and captures while paused at exact physics frames. Python selects representative and anomalous frames, makes small contact sheets and targeted crops, and saves full metadata/logs separately.

**Tech Stack:** Godot 4.7.2, Python standard library, Pillow for image selection/assembly.

**Spec / constraints:** Same paused frame for all views; never clone/replay the scene per camera. Existing commands retain behavior. Additional viewports/cameras are removed and original viewport size, pause state and held inputs restored on failure/completion. Ordinary game startup unaffected. At most 600 simulation frames and 120 capture times per request. Checks have explicit tolerance and sampled coverage; unsupported checks fail clearly. Do not alter game/VFX assets or unrelated WIP.

**Interface:** `python tools/dev_session.py --name visual review scenario.json --output <folder>`. Scenario: optional scene, scheduled events (`input`, `call`, `set` at frames), capture frames, size, camera positions/targets or offsets following a node, checks (foot bottom height vs a fixed plane, numeric property limits, group counts). RPC `review` returns only manifest path/counts; detailed samples live in manifest.json. RPC `capture_views` offers the same synchronized capture without advancing the game.

**Output:** Raw PNGs; manifest with frame/time/check readings; 6–8 representative times including start/mid/end and worst anomaly; contact sheet; worst-anomaly detail; full log and short summary.json/report.md. Reports describe sampling, fixed-plane foot limitations, and that image/text volume are token proxies rather than measured model usage.

## Tasks

- [x] Add meaningful real-engine tests: synchronized views, exact scheduled input edge/frame, foot-plane failure detection, invalid-request cleanup/state restoration. Observe failure before implementation.
- [x] Add capture/review helper and runtime operations, keeping existing step/input/capture/reload behavior.
- [x] Add Python scenario runner, image selection, compact summaries/log reporting and CLI command; test selection includes onset, middle, exit and worst anomaly.
- [x] Compare individual RPC operations vs one review on identical seeded fixtures, alternating order in 5 pairs. Verify matching pixels/checks and record elapsed time, calls, JSON characters and image pixel budgets.
- [x] Run a real motion-lab dash review with multi-camera foot checks. Inspect contact sheet and anomaly crop, run only related session tests, document limitations and usage.
- [x] One feature-level review and scoped fixes; prepare completed files for a scoped commit and push.

## Review focus

- Invalid schedules/camera nodes must not leave input held or change the running scene.
- All views must represent the same scene state/time; billboards may legitimately differ by camera.
- Checks cannot call a bone origin a sole or silently assume a ground plane on arbitrary terrain.
- Sampling must be visible in output; a clean sampled result is not proof of absence between samples.
- Compact selection must retain beginning, middle and ending, plus evidence of the worst measured anomaly.

## Progress

Design read back in chat. Existing addon paths are clean; execute in shared checkout without staging unrelated game work.

Feature review completed. Fixed same-frame transform readback, disappearing camera targets, preflight combined timeline validation and authentication-token persistence. Added focused assertions to the existing integration test. Related 4 tests passed; final sequential benchmark matched all 315 images. Medians: 5.254s individual vs 2.225s batched. Actual motion-lab CLI review saved 63 synchronized images, zero sampled failures/log errors, and a 6-time contact sheet. Numeric checks cover capture/event times only and fixed flat ground.
