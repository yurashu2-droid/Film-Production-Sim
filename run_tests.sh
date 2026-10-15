#!/bin/bash
# Keep all logs. A zero exit without its success marker is a failure.
# --graphics includes render-dependent tests; --self-test runs only the assessor.
set -uo pipefail
cd "$(dirname "$0")" || exit 2
GD=${GODOT_BIN:-./tools/godot/Godot_v4.7.2-stable_win64_console.exe}
LOG_DIR="tools/diagnostics/test-runs/$(date -u +%Y%m%dT%H%M%S)-$$"
if command -v cygpath >/dev/null 2>&1; then
  LOG_DIR=$(cygpath -m "$PWD/$LOG_DIR")
else
  LOG_DIR="$PWD/$LOG_DIR"
fi
mkdir -p "$LOG_DIR" || exit 2
TOTAL=0 PASSED=0 FAILED=0 TIMED_OUT=0 NOT_RUN=0 LAST_EXIT=0
LAST_RESULT=""
OWN_PIDS=()
ERROR_PATTERN='SCRIPT ERROR|ERROR:|Parse Error|above the MTU'
FAIL_PATTERN='[A-Z][A-Z0-9_]*_FAIL([[:space:]:]|$)|_CHECK.*[[:space:]]FAIL([[:space:]]|$)|CLAPPER_NET.*[[:space:]]FAIL([[:space:]]|$)'
cleanup_own_workers() {
  local pid
  for pid in "${OWN_PIDS[@]}"; do
    # These are only our timeout wrappers. Never enumerate/kill Godot.
    if kill -0 "$pid" 2>/dev/null; then kill "$pid" 2>/dev/null || true; fi
  done
}
trap cleanup_own_workers EXIT INT TERM
assess_log() {
  local label=$1 code=$2 marker=$3 log=$4
  local reasons=()
  TOTAL=$((TOTAL + 1))
  LAST_EXIT=$code
  if [ "$code" -eq 124 ] || [ "$code" -eq 137 ]; then
    TIMED_OUT=$((TIMED_OUT + 1))
    reasons+=(timeout)
  elif [ "$code" -eq 3 ]; then reasons+=(pending)
  elif [ "$code" -ne 0 ]; then reasons+=("exit=$code"); fi
  if grep -Eq "$ERROR_PATTERN" "$log"; then reasons+=(godot-error); fi
  if grep -Eq "$FAIL_PATTERN" "$log"; then reasons+=(check-failure); fi
  if ! grep -Eq "$marker" "$log"; then reasons+=(missing-success-marker); fi
  grep -E "$ERROR_PATTERN|$FAIL_PATTERN|TEST_(OK|PASS|PENDING|TIMEOUT)|TEST_OK|TEST_PASS|TEST_FAIL|NETTEST_|PRODUCTIONNET_|STARTMENUTEST_|HANDS_ON_|HANDLING_.*MEASURE" "$log" || true
  if [ "${#reasons[@]}" -gt 0 ]; then
    FAILED=$((FAILED + 1))
    LAST_RESULT=FAIL
    printf 'TEST_CASE_FAIL %s exit=%s reasons=%s log=%s\n' "$label" "$code" "${reasons[*]}" "$log"
  else
    PASSED=$((PASSED + 1))
    LAST_RESULT=OK
    printf 'TEST_CASE_OK %s exit=0 log=%s\n' "$label" "$log"
  fi
}
run_case() {
  local label=$1 seconds=$2 marker=$3
  shift 3
  local log="$LOG_DIR/$label.log"
  printf 'TEST_CASE_START %s timeout=%ss\n' "$label" "$seconds"
  timeout "$seconds" "$@" > "$log" 2>&1
  local code=$?
  assess_log "$label" "$code" "$marker" "$log"
}
script_case() {
  local label=$1 seconds=$2 marker=$3 script=$4
  shift 4
  run_case "$label" "$seconds" "$marker" "$GD" --headless --log-file "$LOG_DIR/$label-engine.log" --path godot "$@" --script "res://tests/$script"
}
run_pair() {
  local label=$1 seconds=$2 host_marker=$3 client_marker=$4
  local host_log="$LOG_DIR/$label-host.log" client_log="$LOG_DIR/$label-client.log"
  printf 'TEST_PAIR_START %s timeout=%ss\n' "$label" "$seconds"
  timeout "$seconds" "$GD" --headless --log-file "$LOG_DIR/$label-host-engine.log" --path godot "${PAIR_HOST[@]}" > "$host_log" 2>&1 &
  local host_pid=$!
  OWN_PIDS+=("$host_pid")
  sleep 2
  timeout "$seconds" "$GD" --headless --log-file "$LOG_DIR/$label-client-engine.log" --path godot "${PAIR_CLIENT[@]}" > "$client_log" 2>&1
  local client_code=$?
  wait "$host_pid"
  local host_code=$?
  assess_log "$label-client" "$client_code" "$client_marker" "$client_log"
  assess_log "$label-host" "$host_code" "$host_marker" "$host_log"
  OWN_PIDS=() # Remove reaped children: PID reuse.
}
runner_self_test() {
  run_case self-pass 3 '^SELF_OK$' "$BASH" -c 'printf "%s\n" SELF_OK'
  local self_ok=true
  [ "$LAST_RESULT" = OK ] || self_ok=false
  run_case self-missing 3 '^SELF_OK$' "$BASH" -c 'printf "%s\n" no-marker'
  [ "$LAST_RESULT" = FAIL ] && [ "$LAST_EXIT" -eq 0 ] || self_ok=false
  run_case self-error 3 '^SELF_OK$' "$BASH" -c 'printf "%s\n" "ERROR: seeded error" SELF_OK'
  [ "$LAST_RESULT" = FAIL ] && [ "$LAST_EXIT" -eq 0 ] || self_ok=false
  run_case self-check 3 '^SELF_OK$' "$BASH" -c 'printf "%s\n" "SELF_CHECK seeded FAIL" SELF_OK'
  [ "$LAST_RESULT" = FAIL ] && [ "$LAST_EXIT" -eq 0 ] || self_ok=false
  run_case self-exit 3 '^SELF_OK$' "$BASH" -c 'printf "%s\n" SELF_OK; exit 7'
  [ "$LAST_RESULT" = FAIL ] && [ "$LAST_EXIT" -eq 7 ] || self_ok=false
  run_case self-timeout 1 '^SELF_OK$' "$BASH" -c 'printf "%s\n" SELF_OK; sleep 3'
  [ "$LAST_RESULT" = FAIL ] && [ "$LAST_EXIT" -eq 124 ] || self_ok=false
  if $self_ok && [ "$TOTAL" -eq 6 ] && [ "$PASSED" -eq 1 ] && [ "$FAILED" -eq 5 ] && [ "$TIMED_OUT" -eq 1 ]; then
    printf 'TEST_RUNNER_SELF_TEST_OK cases=6 expected_failures=5 logs=%s\n' "$LOG_DIR"
    return 0
  fi
  printf 'TEST_RUNNER_SELF_TEST_FAIL total=%s passed=%s failed=%s timeouts=%s\n' "$TOTAL" "$PASSED" "$FAILED" "$TIMED_OUT"
  return 1
}
if [ "${1:-}" = --self-test ]; then runner_self_test; exit $?; fi
if [ "${1:-}" != "" ] && [ "${1:-}" != --graphics ]; then
  printf 'Usage: bash run_tests.sh [--graphics|--self-test]\n' >&2
  exit 2
fi

# Feature registration (scripts/feature_hooks.gd): run this first after touching a feature or a core file.
script_case feature-hooks 90 'FEATURE_HOOKS_TEST_OK' feature_hooks_test.gd --fixed-fps 60
script_case cargo-packing 40 'CARGO_PACKING_TEST_OK' cargo_packing_test.gd
script_case cargo-adhesive 40 'CARGO_ADHESIVE_TEST_OK' cargo_adhesive_test.gd
script_case handling-physics 120 'HANDLING_PHYSICS_TEST_OK' handling_physics_test.gd
script_case held-contact 40 'HELD_CONTACT_TEST_OK' held_contact_test.gd
script_case held-jump 20 'HELD_JUMP_TEST_OK' held_jump_test.gd
script_case hold-jump-game 60 'HOLDJUMP_GAME_TEST_OK' holdjump_game_test.gd --fixed-fps 60
script_case grab-feel 100 'GRABFEEL_TEST_OK' grabfeel_test.gd
script_case hold-spin 60 'HOLD_SPIN_TEST_OK' hold_spin_test.gd --fixed-fps 60
script_case ruin-collision 40 'RUIN_COLLISION_TEST_OK' ruin_collision_test.gd
script_case plywood-structure 40 'PLYWOOD_STRUCTURE_TEST_OK' plywood_structure_test.gd
script_case collider-fit 120 'COLLIDER_FIT_TEST_OK' collider_fit_test.gd
if [ -f godot/tests/adhesive_compliance_test.gd ]; then
  script_case adhesive-compliance 60 'ADHESIVE_COMPLIANCE_TEST_OK' adhesive_compliance_test.gd
else
  printf 'TEST_CASE_NOT_RUN adhesive-compliance file-not-created\n'
  NOT_RUN=$((NOT_RUN + 1))
fi
PAIR_HOST=(res://tests/handling_net_test.tscn -- --handling-host)
PAIR_CLIENT=(res://tests/handling_net_test.tscn -- --handling-client)
run_pair handling-net 75 'HOST HANDLING_NET_TEST_OK' 'CLIENT HANDLING_NET_TEST_OK'
PAIR_HOST=(res://tests/adhesive_net_test.tscn -- --adhesive-host)
PAIR_CLIENT=(res://tests/adhesive_net_test.tscn -- --adhesive-client)
run_pair adhesive-net 50 'ADHESIVE_NET_TEST_OK' 'ADHESIVE_NET_TEST_OK'
script_case cue-card 35 'CUE_CARD_TEST_OK' cue_card_test.gd
PAIR_HOST=(res://tests/cue_card_net_test.tscn -- --cue-host)
PAIR_CLIENT=(res://tests/cue_card_net_test.tscn -- --cue-client)
run_pair cue-card-net 35 'CUE_CARD_NET_TEST_OK' 'CUE_CARD_NET_TEST_OK'
PAIR_HOST=(res://tests/cast_net_test.tscn -- --cast-net-test-host)
PAIR_CLIENT=(res://tests/cast_net_test.tscn -- --cast-net-test-client)
run_pair cast-net 60 'CAST_NET_TEST_OK' 'CAST_NET_TEST_OK'
PAIR_HOST=(res://tests/cast_talent_net_test.tscn -- --cast-talent-net-test-host)
PAIR_CLIENT=(res://tests/cast_talent_net_test.tscn -- --cast-talent-net-test-client)
run_pair cast-talent-net 110 'CAST_TALENT_NET_TEST_OK' 'CAST_TALENT_NET_TEST_OK'
PAIR_HOST=(res://tests/standin_net_test.tscn -- --standin-net-test-host)
PAIR_CLIENT=(res://tests/standin_net_test.tscn -- --standin-net-test-client)
run_pair standin-net 70 'STANDIN_NET_TEST_OK' 'STANDIN_NET_TEST_OK'
PAIR_HOST=(res://tests/bomb_net_test.tscn -- --bomb-net-test-host)
PAIR_CLIENT=(res://tests/bomb_net_test.tscn -- --bomb-net-test-client)
run_pair bomb-net 80 'BOMB_NET_TEST_OK' 'BOMB_NET_TEST_OK'
script_case camera-operation 35 'CAMERA_OPERATION_TEST_OK' camera_operation_test.gd
script_case monitor-switcher 35 'MONITOR_SWITCHER_TEST_OK' monitor_switcher_test.gd
PAIR_HOST=(res://tests/monitor_net_test.tscn -- --monitor-host)
PAIR_CLIENT=(res://tests/monitor_net_test.tscn -- --monitor-client)
run_pair monitor-net 40 'MONITOR_NET_TEST_OK' 'MONITOR_NET_TEST_OK'
script_case start-intro 25 'START_INTRO_TEST_PASS' start_intro_test.gd
script_case performance 30 'PERFORMANCE_TEST_OK' performance_test.gd
script_case vehicle-driving 30 'VEHICLE_DRIVING_TEST_OK' vehicle_driving_test.gd
PAIR_HOST=(-- --performancenettest=host)
PAIR_CLIENT=(-- --performancenettest=client)
run_pair performance-net 30 'PERFORMANCE_NET_TEST_HOST_OK' 'PERFORMANCE_NET_TEST_CLIENT_OK'
script_case production 30 'PRODUCTIONTEST_OK' productiontest.gd --fixed-fps 60
PAIR_HOST=(-- --host --productionnettest)
PAIR_CLIENT=(-- --join=127.0.0.1 --productionnettest)
run_pair production-net 65 'HOST PRODUCTIONNET_OK' 'CLIENT PRODUCTIONNET_OK'
PAIR_HOST=(-- --menutest=host)
PAIR_CLIENT=(-- --menutest=client)
run_pair start-menu-net 35 'HOST STARTMENUTEST_OK' 'CLIENT STARTMENUTEST_OK'
script_case foot-ground 25 'FOOTTEST_OK' footgroundtest.gd --fixed-fps 60
script_case motion-lab 25 'LABTEST_OK' labtest.gd
script_case choice 30 'CHOICETEST_OK' choicetest.gd
script_case vfx 25 'VFXTEST_OK' vfxtest.gd
script_case psychic 25 'PSYCHIC_TEST_OK' psychic_test.gd
script_case esper 40 'ESPER_TEST_OK' esper_test.gd
script_case ink-sound 35 'INK_SOUND_TEST_OK' ink_sound_test.gd
script_case pixel-vfx 25 'PXTEST_OK' pxtest.gd
script_case pixel-50 30 'PX50TEST_OK' px50test.gd
script_case apotheosis 25 'APOTHEOSIS_TEST_OK' apotheosis_test.gd
script_case vfx-picker 25 'VFX_PICKER_TEST_OK' vfx_lab_picker_test.gd
script_case water 25 'WATERTEST_OK' watertest.gd
# Optional VFX packs: they are distributed separately, so they are checked only where the addon folder exists.
for entry in 'punk:40:PUNKTEST_OK:punkpacktest.gd:punk_ink_vfx' 'origami:70:ORIGAMITEST_OK:origamitest.gd:origami_vfx'; do
  IFS=: read -r label seconds marker script addon <<< "$entry"
  if [ -d "godot/addons/$addon" ] && [ -f "godot/tests/$script" ]; then
    script_case "$label" "$seconds" "$marker" "$script"
  else
    printf 'TEST_CASE_NOT_RUN %s reason=addon-absent\n' "$label"
    NOT_RUN=$((NOT_RUN + 1))
  fi
done
script_case motion 40 'MOTIONTEST_OK' motiontest.gd
script_case daily 100 'DAILYTEST_OK' dailytest.gd --fixed-fps 60
script_case cargo-reach 200 'CARGO_REACH_TEST_OK' cargo_reach_test.gd --fixed-fps 60
script_case carton-rope 240 'CARTON_ROPE_TEST_OK' carton_rope_test.gd --fixed-fps 60
script_case carton-pack 180 'CARTON_PACK_TEST_OK' carton_pack_test.gd --fixed-fps 60
PAIR_HOST=(res://tests/carton_rope_net_test.tscn -- --carton-rope-net-test-host)
PAIR_CLIENT=(res://tests/carton_rope_net_test.tscn -- --carton-rope-net-test-client)
run_pair carton-rope-net 85 'CARTON_ROPE_NET_TEST_OK' 'CARTON_ROPE_NET_TEST_OK'
script_case kaiju 120 'KAIJUTEST_OK' kaijutest.gd --fixed-fps 60
script_case kaiju5 400 'KAIJU5_TEST_OK' kaiju5_test.gd --fixed-fps 60
PAIR_HOST=(res://tests/kaiju5_net_test.tscn -- --kaiju5-net-test-host)
PAIR_CLIENT=(res://tests/kaiju5_net_test.tscn -- --kaiju5-net-test-client)
run_pair kaiju5-net 150 'KAIJU5_NET_TEST_OK' 'KAIJU5_NET_TEST_OK'
script_case cast 150 'CASTTEST_OK' casttest.gd --fixed-fps 60
script_case cast-talent 120 'CAST_TALENT_TEST_OK' cast_talent_test.gd --fixed-fps 60
script_case view 90 'VIEW_TEST_OK' view_test.gd --fixed-fps 60
script_case standin 80 'STANDIN_TEST_OK' standin_test.gd --fixed-fps 60
script_case bomb 180 'BOMB_TEST_OK' bomb_test.gd --fixed-fps 60
script_case rope-grab 180 'ROPE_GRAB_TEST_OK' rope_grab_test.gd --fixed-fps 60
script_case premiere 120 'PREMIERE_TEST_OK' premiere_test.gd --fixed-fps 60
script_case cuts 150 'CUTS_TEST_OK' cuts_test.gd --fixed-fps 60
script_case pr 420 'PR_TEST_OK' pr_test.gd --fixed-fps 60
script_case spectacle 120 'SPECTACLE_TEST_OK' spectacle_test.gd --fixed-fps 60
script_case travel 200 'TRAVEL_TEST_OK' travel_test.gd --fixed-fps 60
script_case signboard 120 'SIGNBOARD_TEST_OK' signboard_test.gd --fixed-fps 60
PAIR_HOST=(res://tests/cuts_net_test.tscn -- --cuts-net-test-host)
PAIR_CLIENT=(res://tests/cuts_net_test.tscn -- --cuts-net-test-client)
run_pair cuts-net 160 'CUTS_NET_TEST_OK' 'CUTS_NET_TEST_OK'
PAIR_HOST=(res://tests/rope_grab_net_test.tscn -- --rope-grab-net-test-host)
PAIR_CLIENT=(res://tests/rope_grab_net_test.tscn -- --rope-grab-net-test-client)
run_pair rope-grab-net 90 'ROPE_GRAB_NET_TEST_OK' 'ROPE_GRAB_NET_TEST_OK'
script_case purchase 120 'PURCHASE_TEST_OK' purchase_test.gd --fixed-fps 60
PAIR_HOST=(res://tests/purchase_net_test.tscn -- --purchase-net-test-host)
PAIR_CLIENT=(res://tests/purchase_net_test.tscn -- --purchase-net-test-client)
run_pair purchase-net 95 'PURCHASE_NET_TEST_OK' 'PURCHASE_NET_TEST_OK'
script_case director 200 'DIRECTOR_TEST_OK' director_test.gd --fixed-fps 60
PAIR_HOST=(res://tests/director_net_test.tscn -- --director-net-test-host)
PAIR_CLIENT=(res://tests/director_net_test.tscn -- --director-net-test-client)
run_pair director-net 120 'DIRECTOR_NET_TEST_OK' 'DIRECTOR_NET_TEST_OK'
run_case autotest 150 AUTOTEST_OK "$GD" --headless --log-file "$LOG_DIR/autotest-engine.log" --path godot -- --autotest
run_case autotest-balcony 150 AUTOTEST_OK "$GD" --headless --log-file "$LOG_DIR/autotest-balcony-engine.log" --path godot -- --autotest --route=balcony
run_case failure-path 150 FAILTEST_OK "$GD" --headless --log-file "$LOG_DIR/failure-path-engine.log" --path godot -- --failtest
PAIR_HOST=(-- --host --nettest)
PAIR_CLIENT=(-- --join=127.0.0.1 --nettest)
run_pair legacy-net 100 'HOST NETTEST_OK' 'CLIENT NETTEST_OK'

if [ "${1:-}" = --graphics ]; then
  for entry in 'mouse-order:60:MOUSE_ORDER_TEST_OK:mouse_order_test.gd' 'camera-input:40:CAMERA_INPUT_TEST_OK:camera_input_test.gd' 'motion-lab-render:25:LABTEST_OK:labtest.gd' 'choice-render:30:CHOICETEST_OK:choicetest.gd' 'carry-render:40:CARRYTEST_OK:carrytest.gd' 'restore-render:40:RESTORETEST_OK:restoretest.gd' 'handling-input:50:HANDLING_INPUT_TEST_OK:handling_input_test.gd'; do
    IFS=: read -r label seconds marker script <<< "$entry"
    run_case "$label" "$seconds" "$marker" "$GD" --log-file "$LOG_DIR/$label-engine.log" --path godot --script "res://tests/$script"
  done
  run_case autotest-render 150 AUTOTEST_OK "$GD" --log-file "$LOG_DIR/autotest-render-engine.log" --path godot -- --autotest --shots
  run_case autotest-balcony-render 150 AUTOTEST_OK "$GD" --log-file "$LOG_DIR/autotest-balcony-render-engine.log" --path godot -- --autotest --route=balcony --shots
else
  printf 'TEST_CASE_NOT_RUN graphics cases=9 use=--graphics\n'
  NOT_RUN=$((NOT_RUN + 9))
fi
if [ "$FAILED" -gt 0 ]; then
  printf 'TEST_SUITE_FAIL total=%s passed=%s failed=%s timeouts=%s not_run=%s logs=%s\n' "$TOTAL" "$PASSED" "$FAILED" "$TIMED_OUT" "$NOT_RUN" "$LOG_DIR"
  exit 1
fi
printf 'TEST_SUITE_OK selected=%s passed=%s not_run=%s logs=%s\n' "$TOTAL" "$PASSED" "$NOT_RUN" "$LOG_DIR"
