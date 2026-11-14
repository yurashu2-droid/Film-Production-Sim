extends SceneTree
## Opt-in native regression: quit while hosting, without returning to the menu.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var net := root.get_node("Net")
	var err: int = await net.host_online()
	print("STEAM_QUIT_TEST_OK" if err == OK else "STEAM_QUIT_TEST_FAIL")
	if err != OK: print("STEAM_QUIT_ERROR ", net.last_error)
	quit(0 if err == OK else 1)
