extends SceneTree
var failed := 0

class FakeSteam extends Node:
	signal lobby_created(result: int, lobby: int)
	signal lobby_joined(lobby: int, permissions: int, locked: bool, response: int)
	var online := true
	var init_status := 0
	var host_id := 111
	var own_id := 222
	var metadata := {}
	var calls: Array = []
	func steamInitEx(_app: int, _callbacks: bool) -> Dictionary:
		calls.append("init")
		return {"status": init_status, "verbal": "Steam unavailable"}
	func loggedOn() -> bool: return online
	func run_callbacks() -> void: pass
	func steamShutdown() -> void: calls.append("shutdown")
	func createLobby(kind: int, count: int) -> void: calls.append(["create", kind, count])
	func joinLobby(id: int) -> void: calls.append(["join", id])
	func leaveLobby(id: int) -> void: calls.append(["leave", id])
	func setLobbyData(_id: int, key: String, value: String) -> bool:
		metadata[key] = value
		return true
	func getLobbyData(_id: int, key: String) -> String: return metadata.get(key, "")
	func setLobbyJoinable(_id: int, _on: bool) -> bool: return true
	func getLobbyOwner(_id: int) -> int: return host_id
	func getSteamID() -> int: return own_id
	func getNumLobbyMembers(_id: int) -> int: return 2
	func getLobbyMemberByIndex(_id: int, index: int) -> int: return [111,222][index]

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failed += 1
	print("STEAM_SESSION_CHECK ", label, " ", "OK" if ok else "FAIL")

func fixture(script: Script, api: FakeSteam) -> Node:
	root.add_child(api)
	var session: Node = script.new(api)
	root.add_child(session)
	return session

func dispose(session: Node, api: FakeSteam) -> void:
	session.free()
	api.free()

func _run() -> void:
	if not ResourceLoader.exists("res://scripts/steam_session.gd"):
		check(false, "Steam session implementation exists")
		print("STEAM_SESSION_TEST_FAIL")
		quit(1)
		return
	var script: Script = load("res://scripts/steam_session.gd")
	var api := FakeSteam.new()
	var session := fixture(script, api)
	for text: String in ["", "0", "-1", "+123", "12.3", "abc", "9223372036854775808"]:
		check(session.parse_room(text) == 0, "invalid room rejected: " + text)
	check(session.parse_room(" 109775244935345678 ") == 109775244935345678, "64 bit room preserved")
	check(session.join_room("abc") == ERR_INVALID_PARAMETER and api.calls.is_empty(), "invalid room does not contact Steam")
	api.online = false
	check(session.host() != OK and not api.calls.any(func(c): return c is Array and c[0] == "create"), "offline Steam does not create room")
	dispose(session, api)

	api = FakeSteam.new()
	session = fixture(script, api)
	var hosts: Array = []
	var joins: Array = []
	var errors: Array = []
	session.host_lobby_ready.connect(func(id: int): hosts.append(id))
	session.join_lobby_ready.connect(func(owner: int, id: int): joins.append([owner,id]))
	session.failed.connect(func(message: String): errors.append(message))
	check(session.host() == OK and api.calls.has(["create",3,4]), "room creation uses four player limit")
	api.lobby_created.emit(1, 10)
	check(hosts == [10] and session.lobby_id == 10, "host receives created room")
	check(api.metadata.get("film_game") == "FilmProductionCrew" and api.metadata.get("film_protocol") == "1", "room publishes game and protocol identity")
	check(session.contains_member(222) and not session.contains_member(333), "room membership checked")
	session.close()
	check(session.lobby_id == 0 and api.calls.has(["leave",10]), "closing company leaves lobby")
	check(session.join_room("20") == OK, "room number starts join")
	api.lobby_joined.emit(20, 0, false, 1)
	check(joins == [[111,20]], "joining resolves host Steam ID")
	session.close()
	api.metadata["film_protocol"] = "other"
	session.join_room("21")
	api.lobby_joined.emit(21,0,false,1)
	check(joins.size() == 1 and errors.size() == 1 and session.lobby_id == 0 and api.calls.has(["leave",21]), "incompatible game cannot start peer")
	api.metadata["film_protocol"] = "1"
	api.host_id = api.own_id
	session.join_room("22")
	api.lobby_joined.emit(22,0,false,1)
	check(joins.size() == 1 and errors.size() == 2, "same account cannot join own company")
	api.host_id = 111
	session.join_room("23")
	session.close()
	api.lobby_joined.emit(23,0,false,1)
	check(joins.size() == 1 and api.calls.has(["leave",23]), "late join after cancellation is discarded")
	session.host()
	session.close()
	check(session.host() == ERR_BUSY, "new create waits for cancelled pending request")
	api.lobby_created.emit(1,24)
	check(hosts.size() == 1 and api.calls.has(["leave",24]), "late created room is left")
	session.join_room("25")
	session._process(26.0)
	check(errors.size() == 3 and session.lobby_id == 0, "request timeout resets room")
	api.lobby_joined.emit(25,0,false,1)
	check(joins.size() == 1 and api.calls.has(["leave",25]), "late join after timeout is left")
	session.join_room("26")
	session.close()
	session.host()
	api.lobby_joined.emit(26,0,false,1)
	check(api.calls.has(["leave",26]), "late cancelled join during host creation is left")
	api.lobby_joined.emit(27,0,false,1)
	api.lobby_created.emit(1,27)
	check(session.lobby_id == 27 and not api.calls.has(["leave",27]), "host auto-join before created callback keeps its room")
	session.close()
	session.host()
	session._process(26.0)
	check(errors.size() == 4 and session.host() == OK, "host creation timeout permits retry without a callback")
	api.lobby_joined.emit(28,0,false,1)
	api.lobby_created.emit(1,29)
	check(session.lobby_id == 29 and api.calls.has(["leave",28]), "superseded host auto-join cannot retain a lobby slot")
	dispose(session, api)
	print("STEAM_SESSION_TEST_OK" if failed == 0 else "STEAM_SESSION_TEST_FAIL")
	quit(0 if failed == 0 else 1)
