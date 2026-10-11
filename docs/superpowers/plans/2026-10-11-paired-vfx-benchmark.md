# Paired VFX Repair Benchmark Implementation Plan

> **For agentic workers:** Use the project VFX playbook and the scoped task brief. User AGENTS.md takes precedence over approval and per-task review rituals.

**Goal:** Compare five identical repair tasks under full and compact review, including author time, tokens, fallback reads and final quality.

**Architecture:** Two isolated workers repair byte-identical copies of the same existing punch. Each worker uses both methods; task order is reversed. Both arms use hidden persistent sessions, batch capture (2 RPCs), and short numeric summaries. The isolated variable is full versus selected visual evidence. A separate common audit compares every final image with a canonical render and checks node cleanup.

**Tech Stack:** Python, Pillow, Godot 4.7, existing dev_session runner.

**Spec:** The user accepted the proposal to compare the same repair tasks instead of two independent new creations. Full and compact visual evidence follow the previous benchmark, with batching and concise logs now applied equally. Five tasks: oversized effect, delayed hit, reversed travel, frozen layer age, invisible lingering node. Repair only the requested defect; preserve the existing look.

## Constraints

- Both workers: gpt-6.1-sol/high, fresh context, identical common brief.
- Full and compact assignments alternate; workers repair tasks in opposite order.
- Read only the current task's candidate GD, shared shader and evidence; never the canonical GD or the other worker's results.
- Candidate copies and raw captures stay in ignored development/diagnostic folders. Do not change gameplay or the existing punch assets.
- Warm sessions before timing. Record GPU waits and capture times separately. Start timing before reading candidate code; end after inspecting the repaired evidence.
- Measure per-task token deltas between marker boundaries, plus separate shared worker overhead. Cached input and reasoning output must not be double-counted.
- Both methods may open raw images; record every actual viewed path. Never sacrifice quality for the benchmark.
- No five fresh creations. This evaluates bounded repairs; it cannot establish total new-creation performance.

## Steps

- [x] Add a paired-task harness and one configuration test verifying identical starting code, one assignment per method per pair, and non-overlapping worker folders.
- [x] Prepare ten candidates and warm two hidden sessions. Preserve starting hashes and the frozen shared shader hash.
- [x] Dispatch two workers once, each with all five independent tasks and the full completion contract.
- [x] Audit all ten results with the same dense 46-frame, three-view capture and canonical image comparison. Inspect differences if any.
- [x] Aggregate per-task elapsed time, capture time, lock waits, actual token deltas, viewed images, and quality failures. Report both wins and losses, not only the average.
- [x] Run the narrow harness test, review the accounting and save a short verdict. Delivery is one scoped commit/push after these checks.

## Decision

Do not make compact review the default on this small sample alone. Favor full timelines for final visual acceptance; retain persistent sessions and batch capture. A recommendation for compact intermediate checks requires a useful median saving and no detected quality misses in the common audit. Five paired repairs only provide a practical local indication.

## Execution result

All ten repairs finished in one revision each. Dense audit: 1,380 identical images, zero render errors and zero residual nodes at the checked deadline. Two focused tests passed. Full report: `docs/benchmarks/punch-paired-results.md`.
