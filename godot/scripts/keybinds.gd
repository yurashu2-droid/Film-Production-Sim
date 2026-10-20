class_name Keybinds
extends RefCounted
## キー設定：遊ぶ人が替えられるキーの一覧と、今の割り当て。user://settings.cfg の [keys] に保存する（音量・感度と同じファイル）。
##   ・キーを読む所は、KEY_F のような決め打ちではなく code("operate") を使う（動く・走る などは InputMap のアクションのまま）
##   ・画面の案内の文は、初期のキー名（"F 荷台に積む"）で書いてよい。見せるときに shown() が今のキー名へ読み替える
##   ・マウスのボタン（左クリックで持つ など）と、画面の操作（Enter・Esc・矢印・発注や確認画面の Space）は替えない
const FILE := "user://settings.cfg"
# [アクション, 画面の名前, 初期のキー]。並びは設定の紙に出す順
const ACTIONS := [
	["move_forward", "前へ", KEY_W], ["move_back", "後ろへ", KEY_S], ["move_left", "左へ", KEY_A], ["move_right", "右へ", KEY_D],
	["run", "走る", KEY_SHIFT], ["jump", "ジャンプ", KEY_SPACE], ["crouch", "しゃがむ", KEY_CTRL],
	["operate", "使う・開く", KEY_F], ["rot_left", "左に傾ける", KEY_Q], ["rot_right", "右に傾ける", KEY_E],
	["hold_upright", "起こす", KEY_R], ["hold_pull", "起こして手元へ", KEY_G], ["hold_lift", "持ち上げる（台車）", KEY_L],
	["limp", "力を抜く", KEY_N],
	["talent", "特技", KEY_K], ["cast_role", "役を決める", KEY_Y],
	["act", "演技", KEY_Z], ["effect", "効果", KEY_X], ["act_menu", "演技を選ぶ", KEY_H],
	["cue_1", "合図 1", KEY_1], ["cue_2", "合図 2", KEY_2], ["cue_3", "合図 3", KEY_3], ["cut", "カット", KEY_T],
	["reset_actors", "役者を戻す", KEY_B], ["ping", "目印", KEY_V],
	["help", "あそびかた", KEY_TAB], ["character", "キャラクター", KEY_C], ["view", "視点", KEY_F2],
]
# 替えられないキー（画面の操作に使う）
const RESERVED := [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]

static var _codes := {}            # アクション → 今のキー
static var _loaded := false


static func defaults() -> Dictionary:
	var out := {}
	for a: Array in ACTIONS:
		out[a[0]] = a[2]
	return out


# 保存した割り当てを読み、InputMap に入れる（main.gd の _setup_input から。何度呼んでもよい）
static func apply_saved() -> void:
	_codes = defaults()
	var file := ConfigFile.new()
	if file.load(FILE) == OK:
		for id: String in _codes:
			var v: int = int(file.get_value("keys", id, _codes[id]))
			if v > 0 and v not in RESERVED:
				_codes[id] = v
	_loaded = true
	for id: String in _codes:
		_apply(id)


static func _apply(id: String) -> void:
	if not InputMap.has_action(id):
		InputMap.add_action(id)
	for e: InputEvent in InputMap.action_get_events(id):
		if e is InputEventKey:
			InputMap.action_erase_event(id, e)
	var k := InputEventKey.new()
	k.physical_keycode = _codes[id]
	InputMap.action_add_event(id, k)


static func code(id: String) -> int:
	if not _loaded:
		apply_saved()
	return int(_codes.get(id, 0))


# このキーの押下か（押した瞬間だけ。押しっぱなしの繰り返しは数えない）
static func pressed(event: InputEvent, id: String) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == code(id)


static func key_name(keycode: int) -> String:
	match keycode:
		KEY_SHIFT: return "Shift"
		KEY_CTRL: return "Ctrl"
		KEY_ALT: return "Alt"
		KEY_SPACE: return "Space"
		KEY_TAB: return "Tab"
	return OS.get_keycode_string(keycode)


static func label(id: String) -> String:
	return key_name(code(id))


# 割り当てを替える。ほかの操作が使っていたキーなら、そちらと入れ替える（どの操作もキーを失わない）
static func rebind(id: String, keycode: int) -> bool:
	if keycode <= 0 or keycode in RESERVED or not _codes.has(id):
		return false
	var old: int = code(id)
	for other: String in _codes:
		if other != id and int(_codes[other]) == keycode:
			_codes[other] = old
			_apply(other)
	_codes[id] = keycode
	_apply(id)
	_save()
	return true


static func reset() -> void:
	_codes = defaults()
	for id: String in _codes:
		_apply(id)
	_save()


static func _save() -> void:
	var file := ConfigFile.new()
	file.load(FILE)          # 音量・感度を消さないよう、読んでから書く
	for id: String in _codes:
		file.set_value("keys", id, _codes[id])
	file.save(FILE)


# 画面の案内のキー名（初期のキー名で書いてある）を、今のキー名へ。初期の名前の操作が無ければ、そのまま
#   "F" → 今の「使う」のキー / "1・2・3" → 合図の3つ / "WASD" → 移動の4つ / "Q・E" → 回す2つ
static func shown(token: String) -> String:
	if token == "WASD":
		var moves := [label("move_forward"), label("move_left"), label("move_back"), label("move_right")]
		return "".join(moves) if moves == ["W", "A", "S", "D"] or moves.all(func(s: String) -> bool: return s.length() == 1) else "・".join(moves)
	if "・" in token:
		var parts: Array = []
		for p: String in token.split("・"):
			parts.append(shown(p))
		return "・".join(parts)
	for a: Array in ACTIONS:
		if key_name(a[2]) == token:
			return label(a[0])
	return token


# 文の中のキー名（"[F] 開く"・"K：頭にしまう"）を、今のキー名へ。狙った物の名前の横の文など、札にならない所に使う
static var _bracket := RegEx.create_from_string("\\[([^\\]]+)\\]")
static var _colon := RegEx.create_from_string("(^|[\\s　])([A-Z][0-9]?|Tab|Space|Shift)：")


static func translate(text: String) -> String:
	if text.find("[") < 0 and text.find("：") < 0:
		return text
	var out := text
	for m: RegExMatch in _bracket.search_all(text):
		out = out.replace(m.get_string(0), "[%s]" % shown(m.get_string(1)))
	for m: RegExMatch in _colon.search_all(out):
		var key := m.get_string(2)
		var now := shown(key)
		if now != key:
			out = out.replace(m.get_string(0), m.get_string(1) + now + "：")
	return out
