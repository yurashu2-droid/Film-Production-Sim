extends Node
## ホストの会社だけを保存する。依頼の途中は、直前の事務所チェックポイントから再開する。
const FIELDS := ["day", "wallet", "company", "levels", "reputation", "rent_no",
	"rent_shift", "debut_redo", "owned", "films", "sack_stock"]

var game: Node
var slot := 0
var _store: RefCounted
var _saved := {}
var _office_arrival := false
var _save_failed := false


func restore(data: Dictionary) -> void:
	if data.is_empty():
		return
	var flow: Node = game.production
	var snapshot: Dictionary = flow.snapshot()
	for key: String in FIELDS:
		snapshot[key] = data[key]
	flow.apply(snapshot)
	flow.park_truck_for_day()
	flow.restock()
	game._apply_order()
	var sign: Node = game.hooks.feature("company_sign")
	sign.restore_checkpoint(data.get("sign", {}))


func activate(store: RefCounted, selected_slot: int, progress: Dictionary) -> Error:
	_store = store
	slot = selected_slot
	_saved = progress.duplicate(true)
	return _checkpoint()


func hook_office_ready() -> void:
	_office_arrival = true


func hook_production_applied() -> void:
	if slot == 0 or not Net.is_host() or int(game.production.phase) != 0:
		return
	if _office_arrival or int(game.production.day) > 1:
		_office_arrival = false
		var error := _checkpoint()
		if error != OK and not _save_failed:
			game.hud.show_toast("会社を保存できませんでした。", game.Hud.YELLOW)
		_save_failed = error != OK


func save_at_office() -> Error:
	if slot == 0 or not Net.is_host() or int(game.production.day) <= 1:
		return OK
	return _checkpoint()


func _checkpoint() -> Error:
	var flow: Node = game.production
	if int(flow.phase) != 0:
		return OK
	var progress := {}
	for key: String in FIELDS:
		progress[key] = flow.get(key)
	var sign: Node = game.hooks.feature("company_sign")
	progress["sign"] = sign.checkpoint()
	if progress == _saved:
		return OK
	var error: Error = _store.write(slot, progress)
	if error == OK:
		_saved = progress.duplicate(true)
	return error
