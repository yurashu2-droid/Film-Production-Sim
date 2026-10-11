# Godot Dev Session Implementation Plan

> Execution: superpowers:executing-plans; inline execution. User AGENTS authorizes proceeding without design approval.

**Goal:** Reuse one background Godot runtime for updates and playtesting without occupying the desktop.
**Architecture:** Explicit SceneTree entrypoint, always-processing control Node, localhost JSONL requests, Python standard-library CLI. Hidden SubViewport rendering is separate from true headless logic mode.
**Tech Stack:** Godot 4.7 GDScript, Python 3, Windows.
**Spec:** docs/superpowers/specs/2026-10-11-dev-session-design.md

## Global Constraints
- No editor requirement, no regular-game autoload changes, no third-party process termination.
- Preserve unrelated working changes. Commit/push only this deliverable.
- Paused control transport must keep responding; frame stepping must count real physics frames.

## Review Focus
- Bad script syntax keeps old behavior and session usable.
- Invalid paths/properties/actions yield errors rather than stuck requests.
- Hidden rendering must produce pixels, with no window visibility or cursor capture.
- Repeated starts reuse PID, disconnected clients do not terminate the worker.
- Scene reset releases input and keeps the development transport alive.

## Tasks
- [x] Add integration test using a small fixture: round-trip, input, frames, reload state, bad-code rollback, screenshot and shutdown.
- [x] Implement godot/addons/dev_session/runner.gd and runtime.gd, exposing status/load/tree/get/set/call/input/step/reload/capture/shutdown.
- [x] Implement tools/dev_session.py start/status/request/watch/stop and meaningful local errors/timeouts, document commands in the addon README.
- [x] Run fixture tests in both modes, then inspect the actual motion_lab under the hidden runtime; review changes for the push milestone.

## Verification evidence
- Real-engine fixture tests pass in headless and hidden-render modes, including first-tick input edges, exact frame counts, reload state retention, syntax rollback, PNG output and busy-session reuse protection.
- Actual production_game: jump input sent while paused gives upward velocity 5.8 on the first simulation tick.
- Actual motion_lab and production_game load in one PID; native window visibility and mouse capture stay false. Captures are in artifacts/dev-session.
- One scoped independent review found busy-start duplication and lost input edges; both were fixed and covered by the integration checks.
