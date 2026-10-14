extends Node
## Steam lobby lifecycle. Transport is owned by Net; this node keeps callbacks alive.
signal host_lobby_ready(id: int)
signal join_lobby_ready(host_id: int, id: int)
signal failed(message: String)
signal shutting_down

const GAME_ID := "FilmProductionCrew"
const PROTOCOL := "1"
const TIMEOUT := 25.0
var lobby_id := 0
var error_message := ""
var _api: Object
var _initialized := false
var _request := ""
var _target := 0
var _elapsed := 0.0
var _pending_create := false
var _create_elapsed := 0.0
var _pending_joins := {}
var _host_entries: Array[int] = []

func _init(api: Object = null) -> void:
	_api = api
	process_mode = Node.PROCESS_MODE_ALWAYS

func parse_room(text: String) -> int:
	var value := text.strip_edges()
	if value.is_empty() or not value.is_valid_int(): return 0
	var number := value.to_int()
	return number if number > 0 and str(number) == value else 0

func _initialize_steam() -> Error:
	if _initialized:
		if _api.loggedOn(): return OK
		error_message = "Steamをオンラインで起動してください。"
		return ERR_UNAVAILABLE
	if _api == null:
		if not Engine.has_singleton("Steam"):
			error_message = "GodotSteamが読み込めませんでした。"
			return ERR_UNAVAILABLE
		_api = Engine.get_singleton("Steam")
	var app_id := int(ProjectSettings.get_setting("steam/app_id", 480))
	var result: Dictionary = _api.steamInitEx(app_id, false)
	if int(result.get("status", -1)) != 0:
		error_message = "Steamを起動・ログインしてください。" + str(result.get("verbal", ""))
		return ERR_UNAVAILABLE
	_initialized = true
	_api.lobby_created.connect(_created)
	_api.lobby_joined.connect(_joined)
	if not _api.loggedOn():
		error_message = "Steamをオンラインで起動してください。"
		return ERR_UNAVAILABLE
	return OK

func host() -> Error:
	if _pending_create or not _request.is_empty() or lobby_id != 0:
		error_message = "前の接続処理を待っています。最大25秒で再試行できます。"
		return ERR_BUSY
	var err := _initialize_steam()
	if err != OK: return err
	error_message = ""
	_request = "host"
	_pending_create = true
	_create_elapsed = 0.0
	_elapsed = 0.0
	_api.createLobby(3, 4)
	return OK

func join_room(text: String) -> Error:
	var id := parse_room(text)
	if id == 0:
		error_message = "会社番号を数字で入力してください。"
		return ERR_INVALID_PARAMETER
	if not _request.is_empty() or lobby_id != 0: return ERR_BUSY
	var err := _initialize_steam()
	if err != OK: return err
	error_message = ""
	_request = "join"
	_target = id
	_pending_joins[id] = true
	_elapsed = 0.0
	_api.joinLobby(id)
	return OK

func _created(result: int, id: int) -> void:
	_pending_create = false
	if _request != "host":
		if result == 1 and id != 0: _api.leaveLobby(id)
		return
	if result != 1 or id == 0:
		_fail("会社を開けませんでした（Steam: %d）。" % result)
		return
	lobby_id = id
	_request = ""
	_leave_host_entries(id)
	if not _api.setLobbyData(id, "film_game", GAME_ID) or not _api.setLobbyData(id, "film_protocol", PROTOCOL):
		_fail("会社情報をSteamに登録できませんでした。")
		return
	_api.setLobbyJoinable(id, true)
	host_lobby_ready.emit(id)

func _joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	var requested_join := _pending_joins.has(id)
	_pending_joins.erase(id)
	# Creating a lobby also produces lobby_joined. Do not leave our own host lobby.
	if id == lobby_id: return
	if _request == "host" and _pending_create and not requested_join:
		# The automatic enter may precede lobby_created. Keep it only until
		# the current created callback identifies our actual host lobby.
		if response == 1 and id not in _host_entries: _host_entries.append(id)
		return
	if _request != "join" or id != _target:
		if response == 1: _api.leaveLobby(id)
		return
	if response != 1:
		_fail("会社に参加できませんでした。番号・満員・ホストの起動を確認してください（Steam: %d）。" % response)
		return
	lobby_id = id
	_request = ""
	if _api.getLobbyData(id, "film_game") != GAME_ID or _api.getLobbyData(id, "film_protocol") != PROTOCOL:
		_fail("この会社には参加できません。相手と同じゲームの版を使ってください。")
		return
	var host_id: int = _api.getLobbyOwner(id)
	if host_id == 0 or host_id == _api.getSteamID():
		_fail("別のSteamアカウントが開いた会社番号を入力してください。")
		return
	join_lobby_ready.emit(host_id, id)

func contains_member(steam_id: int) -> bool:
	if not _initialized or lobby_id == 0: return false
	for index in range(_api.getNumLobbyMembers(lobby_id)):
		if _api.getLobbyMemberByIndex(lobby_id, index) == steam_id: return true
	return false

func _process(delta: float) -> void:
	if _initialized: _api.run_callbacks()
	if _pending_create:
		_create_elapsed += delta
		if _create_elapsed >= TIMEOUT: _pending_create = false
	if _request.is_empty(): return
	_elapsed += delta
	if _elapsed >= TIMEOUT: _fail("Steamへの接続が時間切れになりました。もう一度お試しください。")

func _fail(message: String) -> void:
	error_message = message
	close()
	failed.emit(message)

func close() -> void:
	_request = ""
	_target = 0
	_leave_host_entries()
	if lobby_id != 0:
		_api.leaveLobby(lobby_id)
		lobby_id = 0

func _leave_host_entries(keep: int = 0) -> void:
	for id in _host_entries:
		if id != keep: _api.leaveLobby(id)
	_host_entries.clear()

func _exit_tree() -> void:
	# Steam sockets must be closed before unloading the Steam API.
	shutting_down.emit()
	close()
	if _initialized:
		_api.lobby_created.disconnect(_created)
		_api.lobby_joined.disconnect(_joined)
		_api.steamShutdown()
