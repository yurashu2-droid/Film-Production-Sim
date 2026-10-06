#!/bin/bash
# 自動確認をまとめて実行する（画面なし）
cd "$(dirname "$0")"
GD=./tools/godot/Godot_v4.7.2-stable_win64_console.exe
timeout 150 $GD --headless --path godot -- --autotest 2>&1 | grep -E "SCRIPT ERROR|HANDS_ON_|AUTOTEST_"
timeout 150 $GD --headless --path godot -- --failtest 2>&1 | grep -E "SCRIPT ERROR|FAILTEST_"
(timeout 100 $GD --headless --path godot -- --host --nettest > /dev/null 2>&1 &)
sleep 3
timeout 100 $GD --headless --path godot -- --join=127.0.0.1 --nettest 2>&1 | grep -E "SCRIPT ERROR|NETTEST_"
