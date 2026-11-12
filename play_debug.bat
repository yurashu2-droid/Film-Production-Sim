@echo off
rem Debug mode: every prop is out, the yard gate is open, plenty of coins, the board shows every job.
rem Add --day=N to start on day N (1 = the delivery box), --job=K to start with job K accepted, --coins=N for the wallet.
start "" "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0godot" -- --debug %*
