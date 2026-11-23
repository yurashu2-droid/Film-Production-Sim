extends Node
# 三つの音VFX専用の合成スコア。親のageを音の再生位置へ対応させる。
# pause/slow/step時には音も同じ時計へ従い、親と一緒に片付く。
const RATE := 22050
static var _cache: Dictionary = {}
var _effect: Node3D
var _player: AudioStreamPlayer

static func attach(effect: Node3D, kind: String) -> Node:
	var score := new()
	score._effect = effect
	effect.add_child(score)
	score._start(kind)
	return score

func _start(kind: String) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not _cache.has(kind):
		var file := "res://assets/vfx/sound_scores/%s.wav"%kind
		var bytes := FileAccess.get_file_as_bytes(file)
		if bytes.size()<44:
			push_error("Missing VFX sound score: "+file)
			return
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = RATE
		stream.stereo = false
		stream.data = bytes.slice(44)
		_cache[kind] = stream
	_player = AudioStreamPlayer.new()
	_player.stream = _cache[kind]
	_player.volume_db = -7.0
	add_child(_player)
	# 画面なし検証／ミュート描画は再生を開始しない。プレビュー音は書き出し時に重ねる。
	if DisplayServer.get_name() != "headless" and not AudioServer.is_bus_mute(0):
		_player.play(_effect.age)

func _process(_delta: float) -> void:
	if not is_instance_valid(_player):return
	var stopped: bool = get_tree().paused or _effect.speed<=0.0 or Engine.time_scale<=0.0
	_player.stream_paused = stopped
	_player.pitch_scale = maxf(.01,_effect.speed*Engine.time_scale)
	if not stopped and _player.playing:
		var cursor := _player.get_playback_position()
		# コマ送りなどの不連続だけ再同期する。毎フレームseekして音を途切れさせない。
		if absf(cursor-_effect.age)>.18:
			_player.seek(_effect.age)

func _exit_tree() -> void:
	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null
