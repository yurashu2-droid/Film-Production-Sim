#!/bin/bash
# 自動確認をまとめて実行する（--graphics で画面つきも確認）
set -euo pipefail
cd "$(dirname "$0")"
GD=./tools/godot/Godot_v4.7.2-stable_win64_console.exe
timeout 150 $GD --headless --path godot -- --autotest 2>&1 | grep -E "SCRIPT ERROR|HANDS_ON_|AUTOTEST_"
timeout 150 $GD --headless --path godot -- --autotest --route=balcony 2>&1 | grep -E "SCRIPT ERROR|AUTOTEST_" | sed "s/AUTOTEST_/AUTOTEST(balcony)_/"
timeout 150 $GD --headless --path godot -- --failtest 2>&1 | grep -E "SCRIPT ERROR|FAILTEST_"
(timeout 100 $GD --headless --path godot -- --host --nettest > /dev/null 2>&1 &)
sleep 3
timeout 100 $GD --headless --path godot -- --join=127.0.0.1 --nettest 2>&1 | grep -E "SCRIPT ERROR|NETTEST_"

# 描画完了後の物理置き直しは画面なしでは再現しないため、画面つき確認も選べる。
if [ "${1:-}" = "--graphics" ]; then
  timeout 40 $GD --path godot --script res://tests/restoretest.gd 2>&1 | grep -E "SCRIPT ERROR|RESTORE"
  timeout 150 $GD --path godot -- --autotest --shots 2>&1 | grep -E "SCRIPT ERROR|HANDS_ON_|AUTOTEST_|PERF"
  timeout 150 $GD --path godot -- --autotest --route=balcony --shots 2>&1 | grep -E "SCRIPT ERROR|AUTOTEST_|PERF"
fi
