extends Node
# 見返しの撮影映像だけを保存する。ファイルはこの参加者の手元へ書く。
const FRAME_SIZE := Vector2i(640,360)
var game: Node
var busy := false
var last_saved := ""
var last_notice := ""
var _images: Array[Image] = []
var _times: Array[float] = []
var _token := 0
var _approved := false
var _metadata: Dictionary = {}
var _expired_before := false

func _ready() -> void:
	var menu: Node = game.get_parent()
	if menu != null and menu.get("status") is Label:
		var old_note: Node = menu.status.get_parent().get_node_or_null("FilmExportNotice")
		if old_note != null:
			old_note.queue_free()

func begin() -> void:
	if busy or game.state != game.S.RESULT or game.production.phase != 4 or game.selected < 0 or game.selected >= game.takes.size():
		return
	if DisplayServer.get_name() == "headless":
		_notice("8コマ保存は、画面を表示している参加者が使えます。",true)
		return
	var take: Dictionary = game.takes[game.selected]
	if float(take.get("dur",0.0)) <= 0.0:
		_notice("このテイクには保存できる長さがありません。",true)
		return
	busy = true
	_approved = false
	_token += 1
	_images.clear()
	_times.clear()
	_expired_before = game.production.expired
	_metadata = {"take_number":game.selected+1,"title":game.production.job()["title"],"duration":float(take["dur"]),"passed":take["passed"].duplicate(),"extras":take.get("extras",{}).duplicate(true),"source_capture":"replay"}
	_notice("見返しながら8コマを集めています…")
	game.h_export_replay.rpc_id(1,game.selected,_token)
	_collect(_token)

func _collect(token: int) -> void:
	var waiting_since := Time.get_ticks_msec()
	while busy and token == _token and not _approved:
		if Time.get_ticks_msec()-waiting_since > 5000 or game.production.phase != 4:
			cancel("見返しを開始できませんでした。")
			return
		await get_tree().process_frame
	# The client may retain the final clock from an earlier replay until rx_live arrives.
	if busy and token == _token and not Net.is_host():
		game.replay_t = 0.0
	while busy and token == _token and _images.size() < 8:
		if not _replay_valid():
			cancel("見返しが終わったため、保存を中断しました。")
			return
		var target: float = float(_metadata["duration"])*(0.5+_images.size())/8.0
		if game.replay_t < target:
			await get_tree().process_frame
			continue
		await RenderingServer.frame_post_draw
		if not busy or token != _token:
			return
		if not _replay_valid():
			cancel("見返しが終わったため、保存を中断しました。")
			return
		var image: Image = game.film.view.get_texture().get_image()
		if image == null or image.is_empty():
			cancel("撮影映像を取得できず、保存を中断しました。")
			return
		image.convert(Image.FORMAT_RGB8)
		image.resize(FRAME_SIZE.x,FRAME_SIZE.y,Image.INTERPOLATE_LANCZOS)
		_images.append(image)
		_times.append(game.replay_t)
		if _images.size() < 8:
			await get_tree().process_frame
	if busy and token == _token and _images.size() == 8:
		_save()

func accept_reply(success: bool, token: int) -> void:
	if not busy or token != _token:
		return
	if not success:
		cancel("見返しを開始できず、8コマ保存を中断しました。")
		return
	_approved = true

func replay_state_changed(state: int) -> void:
	if busy and _approved and state != game.S.REPLAY:
		cancel("見返しが終わったため、保存を中断しました。")

func _replay_valid() -> bool:
	return game.state == game.S.REPLAY and game.production.phase == 4 and (_expired_before or not game.production.expired)

func cancel(reason: String = "8コマ保存を中断しました。") -> void:
	if not busy:
		return
	busy = false
	_token += 1
	_images.clear()
	_times.clear()
	_notice(reason,true)

func _notice(message: String, warning: bool = false) -> void:
	last_notice = message
	if is_instance_valid(game.hud) and game.hud.is_inside_tree():
		game.hud.show_toast(message,game.hud.YELLOW if not warning else game.hud.RED,5.0)

func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data,"\t"))
	return file.get_error() == OK

func _save() -> void:
	# 取得途中はフォルダも作らない。
	var stamp := Time.get_datetime_string_from_system().replace(":","-")
	var folder := "user://film_stills/%s_%d" % [stamp,Time.get_ticks_msec()]
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		cancel("保存先を作れませんでした。")
		return
	var sheet := Image.create(1280,1440,false,Image.FORMAT_RGB8)
	var entries: Array = []
	for i in 8:
		var filename := "frame_%02d.png" % (i+1)
		var metadata: Dictionary = _metadata.duplicate(true)
		metadata["frame_number"] = i+1
		metadata["requested_time"] = float(_metadata["duration"])*(0.5+i)/8.0
		metadata["capture_time"] = _times[i]
		metadata["file"] = filename
		if _images[i].save_png(folder+"/"+filename) != OK or not _write_json(folder+"/frame_%02d.json" % (i+1),metadata):
			cancel("画像を書き込めませんでした。保存先を確認してください。")
			return
		sheet.blit_rect(_images[i],Rect2i(Vector2i.ZERO,FRAME_SIZE),Vector2i((i%2)*640,(i/2)*360))
		entries.append(metadata)
	var manifest: Dictionary = _metadata.duplicate(true)
	manifest["saved_at"] = Time.get_datetime_string_from_system()
	manifest["frames"] = entries
	manifest["contact_sheet"] = "contact_sheet.png"
	if sheet.save_png(folder+"/contact_sheet.png") != OK or not _write_json(folder+"/manifest.json",manifest):
		cancel("8コマ一覧を書き込めませんでした。")
		return
	last_saved = ProjectSettings.globalize_path(folder)
	busy = false
	_images.clear()
	_times.clear()
	_notice("8コマを保存しました。Oで保存先を開けます。")

func open_saved() -> void:
	if last_saved.is_empty() or DisplayServer.get_name() == "headless":
		return
	if OS.shell_open(last_saved) != OK:
		_notice("保存先を開けませんでした："+last_saved,true)

func _exit_tree() -> void:
	if not busy:
		return
	cancel("会社を閉じたため、8コマ保存を中断しました。")
	# 会社のHUDも破棄されるので、元の起動画面に中断の案内を残す。
	var menu: Node = game.get_parent()
	if menu != null and menu.is_inside_tree() and not menu.is_queued_for_deletion() and menu.get("status") is Label:
		var rows: Node = menu.status.get_parent()
		var label: Label = rows.get_node_or_null("FilmExportNotice")
		if label == null:
			label = Label.new()
			label.name = "FilmExportNotice"
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = 540
			label.add_theme_font_size_override("font_size",18)
			rows.add_child(label)
		label.text = last_notice
