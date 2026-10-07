extends SceneTree

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	var test: Node = load("res://tests/productionlatejointest.gd").new()
	test.name = "ProductionLateJoinTest"
	root.add_child(test)
