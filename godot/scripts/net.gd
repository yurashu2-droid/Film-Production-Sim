extends Node
# 接続管理。P2P（参加者の1人がホスト）方式。
# ソロは「相手のいないホスト」として同じ経路を通るので、ゲーム側は区別しない。

signal peer_joined(id: int)
signal peer_left(id: int)
signal joined_host
signal join_failed

const PORT := 24680
const MAX_PEERS := 3

var mode := "solo"   # solo / host / client


func _ready() -> void:
	multiplayer.peer_connected.connect(func(id: int) -> void: peer_joined.emit(id))
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_left.emit(id))
	multiplayer.connected_to_server.connect(func() -> void: joined_host.emit())
	multiplayer.connection_failed.connect(func() -> void: join_failed.emit())


func host(port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PEERS)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "host"
	return OK


func join(address: String, port: int = PORT) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "client"
	return OK


func is_host() -> bool:
	return multiplayer.is_server()


func my_id() -> int:
	return multiplayer.get_unique_id()


# RPCを呼んだ相手。自分自身の呼び出しは 0 が返るので自分のIDに直す
func sender() -> int:
	var s := multiplayer.get_remote_sender_id()
	return s if s != 0 else my_id()


func has_peers() -> bool:
	return not multiplayer.get_peers().is_empty()
