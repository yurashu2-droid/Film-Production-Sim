extends Node
## グリーンバックの合成：背景フィルム缶（城・宇宙・海）を撮影カメラに入れると、そのカメラは、映像の緑の所を缶の背景に置き換えて写す。
##   ・缶は会社の備品（仕掛けの道具の隣）。持って、撮影カメラを見て F で入れる（同じ缶でもう一度 F で外す。別の缶なら入れ替え）。
##   ・合成はカメラの中で行う（撮影カメラの映像そのものが合成済み）。確認用モニター・見返し・試写会・フィルムの採点のコマも、合成済みに映る。
##   ・緑の布（グリーンバック）の前で撮ると、背景が差し替わる。緑っぽい物（緑の服・カエルの顔・草）も透ける。本物の合成の事故も、そのまま
##   ・いまは見た目だけ（採点には数えない。城の背景を「城の役」と数えるかは、遊んでから決める）
## 決めるのはホスト。どのカメラにどの缶が入っているかは "backdrop" の合図で全員へ配る（本番中は記録にも残る）
const Prop := preload("res://scripts/prop.gd")
const CREW_LAYER := 1 << 11
const THEMES := {"castle": "城", "space": "宇宙", "sea": "海"}
const HOME := [["castle", Vector3(67.55, 0.05, 18.75)], ["space", Vector3(67.55, 0.05, 19.2)], ["sea", Vector3(67.55, 0.05, 19.65)]]
const SCALE := 1.2
const TEX_SIZE := Vector2i(512, 288)
# 緑の布（GS06 の「Matte chroma green」）は、線形で (0.02, 0.41, 0.03)。緑が赤・青より、緑の量の 6 割以上多い所だけを抜く
# （草や木の緑は、そこまで濃くない）。緑でない所は描かない（先に描かれた文字・半透明の物を消さない）。板は、持ち主のカメラから見た時だけ画面いっぱいに描く（ほかのカメラ・人の目には映らない）
const KEY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D backdrop : source_color, filter_linear;
void vertex() {
	if (distance(CAMERA_POSITION_WORLD, NODE_POSITION_WORLD) < 0.4) {
		POSITION = vec4(VERTEX.xy, 0.5, 1.0);
	} else {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	}
}
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float ratio = (c.g - max(c.r, c.b)) / max(c.g, 0.001);
	float key = smoothstep(0.6, 0.75, ratio) * smoothstep(0.004, 0.02, c.g);
	ALBEDO = texture(backdrop, SCREEN_UV).rgb;
	ALPHA = key;
}
"""

var game: Node
var cans: Array = []                      # 背景フィルム缶（物）
var backdrop: Dictionary = {}             # 撮影カメラの物のID → 缶の背景（"castle" など）
var _quads: Dictionary = {}               # 撮影カメラの物のID → 合成の板
var _textures: Dictionary = {}
var _shader: Shader
var _live := {}


func setup() -> void:
	for row: Array in HOME:
		cans.append(_spawn_can(str(row[0]), row[1]))
	if Net.is_host() and game.production != null:
		for c: RigidBody3D in cans:
			game.production._home_layout[c.pid] = c.get_state()


func _spawn_can(theme: String, at: Vector3) -> RigidBody3D:
	var p: RigidBody3D = Prop.new()
	p.kind = "bgcan_" + theme
	p.label = "背景フィルム（%s）" % THEMES[theme]
	p.mass = 0.8
	var model: Node3D = (load("res://assets/props/P057_film_can.glb") as PackedScene).instantiate()
	model.scale = Vector3.ONE * SCALE
	p.visual = model
	p.add_child(model)
	var box: AABB = game.stage.merged_aabb(model)
	box = AABB(box.position * SCALE, box.size * SCALE)
	p.center = box.get_center()
	p.half = box.size * 0.5
	p.hold_min = maxf(1.1, p.half.z + 0.95)
	game.stage._shape(p, box.get_center(), box.size * 0.97, false)
	# ふたの上の札（制作班にだけ見える）
	var tag := Label3D.new()
	tag.text = THEMES[theme]
	tag.font_size = 36
	tag.pixel_size = 0.003
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.outline_size = 8
	tag.layers = CREW_LAYER
	tag.position = Vector3(0, box.end.y + 0.08, 0)
	p.add_child(tag)
	return game.stage._register(p, at, 0.0)


func _theme_of(p: Node) -> String:
	return str(p.kind).trim_prefix("bgcan_") if p != null and str(p.kind).begins_with("bgcan_") else ""


# ---- 自分の操作 ----

func hook_f(me: Node) -> bool:
	var held: Node = game.props.get(me.held) if me.held != 0 else null
	var theme := _theme_of(held)
	var cam: Node = me.target
	if theme == "" or cam == null or cam.kind != "camera" or cam.absent:
		return false
	h_set.rpc_id(1, int(cam.pid), theme)
	return true


func hook_hud(me: Node, _label: String, _keys: String) -> Dictionary:
	var held: Node = game.props.get(me.held) if me.held != 0 else null
	var theme := _theme_of(held)
	if theme == "":
		return {}
	var cam: Node = me.target
	if cam == null or cam.kind != "camera":
		return {"keys": "撮影カメラを見て F 背景フィルムを入れる（緑の所が、%sの背景になる）" % THEMES[theme]}
	var now := str(backdrop.get(int(cam.pid), ""))
	return {"keys_all": ("F 背景フィルムを外す" if now == theme else "F 背景フィルム（%s）を入れる" % THEMES[theme]) + "\n" + str(game.hold_hint())}


@rpc("any_peer", "call_local", "reliable")
func h_set(cam_pid: int, theme: String) -> void:
	var who := Net.sender()
	var cam: Node = game.props.get(cam_pid)
	var pl: Node = game.players.get(who)
	if not Net.is_host() or game.replaying or cam == null or cam.kind != "camera" or pl == null or not THEMES.has(theme):
		return
	var held: Node = game.props.get(pl.held) if pl.held != 0 else null
	if _theme_of(held) != theme or pl.reach_base().distance_to(cam.center_global()) > game.Player.REACH + 2.0:
		return
	var next: Dictionary = backdrop.duplicate()
	if str(next.get(cam_pid, "")) == theme:
		next.erase(cam_pid)
		game.ev.rpc_id(who, "toast", ["背景フィルムを外した", 0])
	else:
		next[cam_pid] = theme
		game.ev.rpc_id(who, "toast", ["背景フィルム（%s）を入れた。このカメラは、緑の所を%sの背景に置き換えて写す" % [THEMES[theme], THEMES[theme]], 0])
	game.host_ev("sfx", ["fix", cam.global_position])
	game.host_ev("backdrop", [next])


# ---- 全員の画面：合成 ----

func hook_events() -> Array:
	return ["backdrop"]


func hook_rec_events() -> Array:
	return ["backdrop"]


func hook_event(_n: String, a: Array) -> void:
	backdrop = (a[0] as Dictionary).duplicate()
	_apply()


func hook_sync(who: int) -> void:
	if multiplayer.is_server() and who != multiplayer.get_unique_id():
		game.ev.rpc_id(who, "backdrop", [backdrop])


func hook_take_start() -> void:
	game._rec_events.append([0.0, "backdrop", [backdrop.duplicate()]])


func hook_playback(on: bool) -> void:
	if on:
		_live = backdrop.duplicate()
	else:
		game.host_ev("backdrop", [_live])


func hook_return_office() -> void:
	if Net.is_host() and not backdrop.is_empty():
		game.host_ev("backdrop", [{}])


func _apply() -> void:
	for pid: int in _quads.keys():
		if not backdrop.has(pid):
			(_quads[pid] as Node).queue_free()
			_quads.erase(pid)
	for pid: int in backdrop:
		var cam: Node = game.props.get(pid)
		var vc: Camera3D = cam.get("view_cam") if cam != null else null
		if vc == null:
			continue
		if not _quads.has(pid):
			_quads[pid] = _make_quad(vc)
		var mat: ShaderMaterial = (_quads[pid] as MeshInstance3D).material_override
		mat.set_shader_parameter("backdrop", _texture(str(backdrop[pid])))


# カメラのすぐ前の、画面いっぱいの板。カメラの映像を読み、緑の所を背景に置き換えて描く
func _make_quad(vc: Camera3D) -> MeshInstance3D:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = KEY_SHADER
	var mi := MeshInstance3D.new()
	mi.name = "BackdropKey"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)          # 頂点は ±1。描く時に、そのまま画面の四隅へ置く
	mi.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 16.0
	mi.position = Vector3(0, 0, -(vc.near + 0.01))
	vc.add_child(mi)
	return mi


# ---- 背景の絵（コードで描く） ----

func _texture(theme: String) -> Texture2D:
	if _textures.has(theme):
		return _textures[theme]
	var img := Image.create(TEX_SIZE.x, TEX_SIZE.y, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = theme.hash()
	# 緑の布は、たいてい画面のまん中に写る。見せ場（城・惑星・太陽）は、まん中に描く
	match theme:
		"space":
			_gradient(img, Color("05060f"), Color("1b1640"), 0, TEX_SIZE.y)
			for i in 320:
				var s := rng.randi_range(1, 2)
				img.fill_rect(Rect2i(rng.randi_range(0, TEX_SIZE.x - 2), rng.randi_range(0, TEX_SIZE.y - 2), s, s), Color(1, 1, 0.9).lerp(Color(0.7, 0.8, 1.0), rng.randf()))
			_disc(img, Vector2(276, 148), 22, Color("f0a25c"), Color("8a4a2a"))
			img.fill_rect(Rect2i(246, 147, 60, 2), Color("e8d2a8"))
			_disc(img, Vector2(222, 188), 7, Color("d6dfec"), Color("7f8fa8"))
		"sea":
			_gradient(img, Color("5aa2e6"), Color("cfe6f7"), 0, 150)
			_gradient(img, Color("2b6fa6"), Color("123d66"), 150, TEX_SIZE.y)
			_disc(img, Vector2(286, 128), 14, Color("fff4c8"), Color("ffd98a"))
			for i in 70:
				var y := rng.randi_range(155, TEX_SIZE.y - 4)
				img.fill_rect(Rect2i(rng.randi_range(0, TEX_SIZE.x - 40), y, rng.randi_range(12, 40), 2), Color(0.85, 0.93, 1.0, 1.0))
		_:
			_gradient(img, Color("ffb86a"), Color("d77a9a"), 0, 196)
			_gradient(img, Color("4a6a3a"), Color("2c4024"), 196, TEX_SIZE.y)
			var stone := Color("8a8098")
			var shade := Color("6a6078")
			img.fill_rect(Rect2i(214, 160, 84, 36), stone)
			for k in 7:
				img.fill_rect(Rect2i(216 + k * 12, 155, 6, 5), stone)
			for t: Array in [[204, 136, 18], [247, 122, 18], [290, 136, 18]]:
				var x0 := int(t[0])
				var y0 := int(t[1])
				var w := int(t[2])
				img.fill_rect(Rect2i(x0, y0, w, 196 - y0), stone)
				img.fill_rect(Rect2i(x0 + w - 4, y0, 4, 196 - y0), shade)
				for k in 3:
					img.fill_rect(Rect2i(x0 + k * 7, y0 - 5, 4, 5), stone)
				img.fill_rect(Rect2i(x0 + w / 2 - 2, y0 + 8, 3, 6), Color("f6d27a"))
			img.fill_rect(Rect2i(250, 178, 12, 18), Color("3a2a35"))
			img.fill_rect(Rect2i(255, 104, 1, 18), Color("3a2a35"))
			img.fill_rect(Rect2i(256, 104, 9, 6), Color("c0392b"))
	var tex := ImageTexture.create_from_image(img)
	_textures[theme] = tex
	return tex


static func _gradient(img: Image, top: Color, bottom: Color, y0: int, y1: int) -> void:
	for y in range(y0, y1):
		img.fill_rect(Rect2i(0, y, img.get_width(), 1), top.lerp(bottom, float(y - y0) / maxf(float(y1 - y0 - 1), 1.0)))


static func _disc(img: Image, c: Vector2, r: float, inner: Color, outer: Color) -> void:
	for y in range(int(c.y - r), int(c.y + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			var d := Vector2(x, y).distance_to(c)
			if d <= r and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, inner.lerp(outer, d / r))
