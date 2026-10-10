#!/bin/bash
# 自動確認をまとめて実行する（--graphics で画面つきも確認）
set -euo pipefail
cd "$(dirname "$0")"
GD=./tools/godot/Godot_v4.7.2-stable_win64_console.exe
timeout 25 $GD --headless --path godot --script res://tests/start_intro_test.gd 2>&1 | grep -E "SCRIPT ERROR|ERROR:|START_INTRO_CHECK.*FAIL|START_INTRO_TEST_"
timeout 30 $GD --headless --path godot --fixed-fps 60 --script res://tests/productiontest.gd 2>&1 | grep -E "SCRIPT ERROR|ERROR:|PRODUCTION_CHECK.*FAIL|PRODUCTIONTEST_"
# 制作会社の一周と昇降台を実ENet二人で確認。両プロセスの終了も待つ。
PRODUCTION_LOG=$(mktemp)
timeout 65 $GD --headless --path godot -- --host --productionnettest > "$PRODUCTION_LOG" 2>&1 &
PRODUCTION_HOST=$!
sleep 2
timeout 65 $GD --headless --path godot -- --join=127.0.0.1 --productionnettest 2>&1 | grep -E "SCRIPT ERROR|ERROR:|PRODUCTION_NET.*FAIL|PRODUCTIONNET_"
wait "$PRODUCTION_HOST"
grep -E "SCRIPT ERROR|ERROR:|PRODUCTIONNET_|above the MTU" "$PRODUCTION_LOG"
rm -f "$PRODUCTION_LOG"
# 起動画面の実ボタン経路でも、ホストと参加者のidentityとNodeパスを確認。
MENU_LOG=$(mktemp)
timeout 35 $GD --headless --path godot -- --menutest=host > "$MENU_LOG" 2>&1 &
MENU_HOST=$!
sleep 2
timeout 35 $GD --headless --path godot -- --menutest=client 2>&1 | grep -E "SCRIPT ERROR|ERROR:|START_MENU_CHECK.*FAIL|STARTMENUTEST_"
wait "$MENU_HOST"
grep -E "SCRIPT ERROR|ERROR:|STARTMENUTEST_" "$MENU_LOG"
rm -f "$MENU_LOG"
timeout 25 $GD --headless --path godot --fixed-fps 60 --script res://tests/footgroundtest.gd 2>&1 | grep -E "SCRIPT ERROR|FOOT_CHECK.*FAIL|FOOTTEST_"
timeout 25 $GD --headless --path godot --script res://tests/labtest.gd 2>&1 | grep -E "SCRIPT ERROR|LAB_CHECK.*FAIL|LABTEST_"
timeout 30 $GD --headless --path godot --script res://tests/choicetest.gd 2>&1 | grep -E "SCRIPT ERROR|CHOICE_CHECK.*FAIL|CHOICETEST_"
timeout 25 $GD --headless --path godot --script res://tests/vfxtest.gd 2>&1 | grep -E "SCRIPT ERROR|ERROR:|VFX_CHECK.*FAIL|VFXTEST_"
timeout 25 $GD --headless --path godot --script res://tests/pxtest.gd 2>&1 | grep -E "SCRIPT ERROR|ERROR:|PX_CHECK.*FAIL|PXTEST_"
timeout 40 $GD --headless --path godot --script res://tests/motiontest.gd 2>&1 | grep -E "SCRIPT ERROR|MOTION_CHECK.*FAIL|MOTIONTEST_"
timeout 150 $GD --headless --path godot -- --autotest 2>&1 | grep -E "SCRIPT ERROR|HANDS_ON_|AUTOTEST_"
timeout 150 $GD --headless --path godot -- --autotest --route=balcony 2>&1 | grep -E "SCRIPT ERROR|AUTOTEST_" | sed "s/AUTOTEST_/AUTOTEST(balcony)_/"
timeout 150 $GD --headless --path godot -- --failtest 2>&1 | grep -E "SCRIPT ERROR|FAILTEST_"
(timeout 100 $GD --headless --path godot -- --host --nettest > /dev/null 2>&1 &)
sleep 3
timeout 100 $GD --headless --path godot -- --join=127.0.0.1 --nettest 2>&1 | grep -E "SCRIPT ERROR|NETTEST_"

# 描画完了後の物理置き直しは画面なしでは再現しないため、画面つき確認も選べる。
if [ "${1:-}" = "--graphics" ]; then
  timeout 25 $GD --path godot --script res://tests/labtest.gd 2>&1 | grep -E "SCRIPT ERROR|LAB_CHECK.*FAIL|LABTEST_"
  timeout 30 $GD --path godot --script res://tests/choicetest.gd 2>&1 | grep -E "SCRIPT ERROR|CHOICE_CHECK.*FAIL|CHOICETEST_"
  timeout 40 $GD --path godot --script res://tests/carrytest.gd 2>&1 | grep -E "SCRIPT ERROR|CARRY_CHECK.*FAIL|CARRYTEST_"
  timeout 40 $GD --path godot --script res://tests/restoretest.gd 2>&1 | grep -E "SCRIPT ERROR|RESTORE"
  timeout 150 $GD --path godot -- --autotest --shots 2>&1 | grep -E "SCRIPT ERROR|HANDS_ON_|AUTOTEST_|PERF"
  timeout 150 $GD --path godot -- --autotest --route=balcony --shots 2>&1 | grep -E "SCRIPT ERROR|AUTOTEST_|PERF"
fi
