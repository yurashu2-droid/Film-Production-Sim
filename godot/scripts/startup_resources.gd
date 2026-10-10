extends Node
# ホーム表示中にモデルを背景で読み、PackedSceneへの参照を保持して読み直しを防ぐ。
signal completed
var is_prepared := false
var _pending: Array[String] = []
var _active := ""
var _retained: Array[Resource] = []

func _ready() -> void:
	var directories: Array[String] = ["res://assets/stage/", "res://assets/props/", "res://assets/gear/", "res://assets/cast/", "res://assets/production/"]
	while not directories.is_empty():
		var directory: String = directories.pop_front()
		for file: String in ResourceLoader.list_directory(directory):
			if file.ends_with("/"):
				directories.append(directory + file)
			elif file.ends_with(".glb"):
				_pending.append(directory + file)

func _process(_delta: float) -> void:
	if _active != "":
		var status := ResourceLoader.load_threaded_get_status(_active)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_retained.append(ResourceLoader.load_threaded_get(_active))
		_active = ""
	if _pending.is_empty():
		is_prepared = true
		set_process(false)
		completed.emit()
		return
	_active = _pending.pop_front()
	if ResourceLoader.load_threaded_request(_active, "PackedScene") != OK:
		_active = ""
