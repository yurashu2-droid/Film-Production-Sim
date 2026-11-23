extends Node
# 接続管理。P2P（参加者の1人がホスト）方式。
# ソロは「相手のいないホスト」として同じ経路を通るので、ゲーム側は区別しない。

signal peer_joined(id: int)
signal peer_left(id: int)
signal joined_host
signal join_failed
signal online_host_finished(error: int)

const PORT := 24680
const MAX_PEERS := 3

var mode := "solo"   # solo / host / client
var transport := "lan"
var last_error := ""
var steam_session: Node
var _hosting_online := false
# 自動確認だけが使う：ひとつの画面の中で、別の参加者の操作として頼みを出す（0＝使わない。遊びの中では、いつも 0）
var acting_as := 0


func _ready() -> void:
	steam_session = preload("res://scripts/steam_session.gd").new()
	add_child(steam_session)
	steam_session.host_lobby_ready.connect(_steam_host_ready)
	steam_session.join_lobby_ready.connect(_steam_join_ready)
	steam_session.failed.connect(_steam_failed)
	steam_session.shutting_down.connect(close)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: joined_host.emit())
	multiplayer.connection_failed.connect(func() -> void: join_failed.emit())


func host(port: int = PORT) -> Error:
	transport = "lan"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PEERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "host"
	return OK


func join(address: String, port: int = PORT) -> Error:
	transport = "lan"
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "client"
	return OK


func host_online() -> Error:
	last_error = ""
	var err: Error = steam_session.host()
	if err != OK:
		last_error = steam_session.error_message
		return err
	_hosting_online = true
	transport = "steam"
	return await online_host_finished


func join_online(room: String) -> Error:
	last_error = ""
	var err: Error = steam_session.join_room(room)
	if err != OK:
		last_error = steam_session.error_message
		return err
	transport = "steam"
	mode = "client"
	return OK


func _steam_peer() -> MultiplayerPeer:
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		last_error = "Steam通信機能を読み込めませんでした。"
		return null
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.set("server_relay", true)
	return peer


func _steam_host_ready(_room: int) -> void:
	if not _hosting_online: return
	var peer := _steam_peer()
	var err := ERR_UNAVAILABLE if peer == null else int(peer.call("create_host", 0))
	if err == OK:
		multiplayer.multiplayer_peer = peer
		mode = "host"
	else:
		if peer != null: peer.close()
		steam_session.close()
		last_error = "Steamの会社を開けませんでした（%d）。" % err
	_hosting_online = false
	online_host_finished.emit(err)


func _steam_join_ready(host_id: int, _room: int) -> void:
	if mode != "client" or transport != "steam": return
	var peer := _steam_peer()
	var err := ERR_UNAVAILABLE if peer == null else int(peer.call("create_client", host_id, 0))
	if err == OK:
		multiplayer.multiplayer_peer = peer
	else:
		if peer != null: peer.close()
		_steam_failed("Steamの会社につながりませんでした（%d）。" % err)


func _steam_failed(message: String) -> void:
	last_error = message
	steam_session.close()
	if _hosting_online:
		_hosting_online = false
		online_host_finished.emit(ERR_CANT_CONNECT)
	else:
		join_failed.emit()


func _peer_connected(id: int) -> void:
	if transport == "steam" and mode == "host":
		var peer := multiplayer.multiplayer_peer
		var steam_id: int = peer.call("get_steam_id_for_peer_id", id)
		if multiplayer.get_peers().size() > MAX_PEERS or not steam_session.contains_member(steam_id):
			# Lobby membership is required even when someone knows the host Steam ID.
			peer.disconnect_peer(id, true)
			return
	peer_joined.emit(id)


func close() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null: peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	steam_session.close()
	mode = "solo"
	transport = "lan"
	if _hosting_online:
		_hosting_online = false
		online_host_finished.emit(ERR_SKIP)


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


# RPCを呼んだ相手。自分自身の呼び出しは 0 が返るので自分のIDに直す
func sender() -> int:
	if acting_as != 0:
		return acting_as
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else my_id()


func has_peers() -> bool:
	return not multiplayer.get_peers().is_empty()
