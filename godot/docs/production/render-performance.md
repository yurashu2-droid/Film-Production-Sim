# Production render comparison — RTX 4060 — 2026-10-08

Godot 4.7.2 Forward+, window 1600x900, VSync disabled and Engine.max_fps=0.
One dedicated Godot rendering process at a time, parent suspended other renders/tests.
Each case independently loads its normal scene, waits 0.8 seconds, configures the site,
warms up 2 seconds, then samples uninterrupted real time for 2.5 seconds.
No image encoding, file loads or saves occur within the sample.
Static observer camera fov68: office (76,4,10) looking at (72,1,-2), sites/legacy
(9.5,4,9) looking at (0,1,-3). Normal physics, actors, HUD and film viewport continue.
These are idle preparation views, not active explosions or full recording workloads.
Monitor process/physics values are engine rolling monitor readings, not per-frame timings.
Render CPU/GPU sums root and film viewport measured timing; disabling film may leave its
last measured time in the sum, so FPS and draw-call deltas are the stronger evidence.

| Case | Real FPS | Process ms | Physics ms | Render CPU ms | GPU ms | Draw calls/frame |
|---|---:|---:|---:|---:|---:|---:|
| production office |148.3|8.85|1.34|3.37|2.87|5561|
| legacy main PREP |131.5|9.58|1.33|4.23|3.38|7840|
| production studio |250.1|5.95|1.23|1.74|2.79|2734|
| production yard |292.3|5.46|1.15|1.08|2.91|1228|
| yard hose reel hidden |297.8|4.93|1.12|0.85|2.90|676|
| office film UPDATE_DISABLED |414.0|3.42|1.18|0.66|1.76|836|

Hose reel hide improves FPS 1.9%; office film off improves FPS 179% and removes
4725 draw calls/frame. Existing film_camera.gd uses 1280x720 UPDATE_ALWAYS, which
continues rendering the old stage even while the player is at the distant office.
Primary candidate is unnecessary second-view scene submission, rather than hose geometry.
The new idle scenes were faster than legacy PREP in this controlled comparison;
the user's 42–53 FPS was not reproduced by these idle views.

Applied smallest source change: in production state apply, use
SubViewport.UPDATE_DISABLED in phases0..3 (office/order/loading/travel), and restore
UPDATE_ALWAYS in phases4..5 (site filming/result). Keep legacy unchanged. This preserves
the main visible office/studio/yard and maintains film judge/record/replay when needed.
Check the phase4 transition revives the film image; no VFX change is indicated here.

Reproduce a case:
Godot_v4.7.2-stable_win64_console.exe --path godot --script res://tests/shots/perf_production/benchmark.gd --resolution 1600x900 -- --bench=office
Cases: office, legacy, studio, yard, yard_nohose, office_nofilm.

## 最終portableの通常描画（2026-10-08 06:58）

RTX4060 / Vulkan Forward+ / 1600×900、VSyncをこの計測processだけ無効にし、画像保存・固定FPS指定を使わず2秒間の実frame数を測った。portable EXE/PCKだけを作業場所にして、起動画面からsolo、購入0で積載、通常8秒移動後の未設営倉庫へ進めた。

| 場面 | frames | 秒 | 実FPS | film SubViewport更新 |
| --- | ---: | ---: | ---: | --- |
| 事務所 | 811 | 2.000519 | 405.4 | DISABLED |
| 積み込み | 719 | 2.004775 | 358.6 | DISABLED |
| 到着後の未設営倉庫 | 280 | 2.011890 | 139.2 | ALWAYS |

ログはignored `tools/diagnostics/portable-fps.log`。既知の42〜53fpsは今回の静止場面でも再現していない。爆発中・重い積載・四人の同時実描画の負荷や、他のPCでの性能の保証には使わない。
