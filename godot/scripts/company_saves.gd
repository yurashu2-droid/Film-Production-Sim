extends RefCounted
## 会社ごとの事務所チェックポイント。個人設定や制作班スキルのファイルとは別。
const SLOT_COUNT := 3
const VERSION := 1

var directory := "user://companies"


func _path(slot: int) -> String:
	return directory.path_join("company_%d.cfg" % slot)


func status(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return {"error": ERR_INVALID_PARAMETER}
	var path := _path(slot)
	if not FileAccess.file_exists(path):
		return {"error": OK, "data": {}}
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK:
		return {"error": error}
	var data: Variant = config.get_value("company", "progress", {})
	if config.get_value("company", "version", 0) != VERSION or not _valid(data):
		return {"error": ERR_FILE_CORRUPT}
	return {"error": OK, "data": data, "updated": str(config.get_value("company", "updated", ""))}


func read(slot: int) -> Dictionary:
	return status(slot).get("data", {})


func write(slot: int, data: Dictionary) -> Error:
	if slot < 1 or slot > SLOT_COUNT or not _valid(data):
		return ERR_INVALID_PARAMETER
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var config := ConfigFile.new()
	config.set_value("company", "version", VERSION)
	config.set_value("company", "progress", data)
	config.set_value("company", "updated", Time.get_datetime_string_from_system(false, true))
	var path := _path(slot)
	var tmp := "%s.%d.%d.tmp" % [path, OS.get_process_id(), Time.get_ticks_usec()]
	error = config.save(tmp)
	if error == OK:
		error = DirAccess.rename_absolute(tmp, path)
	if error != OK and FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)
	return error


static func _valid(data: Variant) -> bool:
	if not data is Dictionary or not data.get("day") is int or data.day < 1:
		return false
	for key in ["wallet", "reputation", "rent_no", "rent_shift"]:
		if not data.get(key) is int:
			return false
	if not data.get("company") is String or not data.get("debut_redo") is bool:
		return false
	if not data.get("levels") is Dictionary or not data.get("owned") is Dictionary:
		return false
	for key in ["car", "studio", "monitor", "plan"]:
		var level: Variant = data.levels.get(key)
		if not level is int or level < 0:
			return false
	if not data.get("films") is Array or not data.get("sack_stock") is Array:
		return false
	for film in data.films:
		if not film is Dictionary or not film.get("job") is int or not film.get("ok") is int or not film.get("of") is int:
			return false
	for quantity in data.sack_stock:
		if not (quantity is int or quantity is float) or not is_finite(float(quantity)) or float(quantity) < 0.0:
			return false
	return _valid_sign(data.get("sign", {}))


static func _valid_sign(sign: Variant) -> bool:
	if not sign is Dictionary:
		return false
	if sign.is_empty():
		return true
	if not sign.get("order") is Array or not sign.get("boards") is Dictionary or not sign.get("joints") is Array:
		return false
	var seen := {}
	for i in sign.order:
		if not i is int or i < 0 or i in seen:
			return false
		seen[i] = true
		var board: Variant = sign.boards.get(i)
		if not board is Array or board.size() != 5 or not board[0] is Vector3 or not board[1] is Quaternion:
			return false
		if not board[0].is_finite() or not board[1].is_finite() or not board[1].is_normalized():
			return false
		if board[2] != true or not board[3] is int or not board[4] is PackedByteArray:
			return false
	for joint in sign.joints:
		if not joint is Array or joint.size() != 4 or not joint[0] is int or not joint[1] is int:
			return false
		if not joint[0] in seen or not joint[1] in seen or not joint[2] is Vector3 or not joint[3] is Vector3:
			return false
		if not joint[2].is_finite() or not joint[3].is_finite():
			return false
	return true
