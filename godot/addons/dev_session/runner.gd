extends SceneTree
# Explicit --script entry point; never loaded by the regular game.

func _initialize() -> void:
	root.unfocusable = true
	Engine.max_fps = 60
	_boot.call_deferred()

func _boot() -> void:
	var port := 0
	var token := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-port="):
			port = int(arg.get_slice("=", 1))
		elif arg.begins_with("--dev-token="):
			token = arg.get_slice("=", 1)
	if port <= 0 or token.is_empty():
		push_error("Dev session requires its CLI launcher")
		quit(2)
		return
	var runtime := preload("res://addons/dev_session/runtime.gd").new()
	root.add_child(runtime)
	if runtime.start(port, token) != OK:
		quit(2)
		return
	paused = true
