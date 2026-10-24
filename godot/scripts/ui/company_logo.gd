extends RefCounted
## 会社の名前＝事務所の前に掛けた段ボールの看板の絵（features/company_sign.gd が撮る）。
##   ・会社が呼ばれる文（お知らせ・電話・コメント欄・作品の札・依頼主のひとこと など）には、名前の文字の代わりに TOKEN を書いておく
##   ・表示する側が show_in(label, 文) で、TOKEN を看板の絵（小さな画像）に替えて出す。絵はそれぞれの画面で撮った物
##   ・看板がまだ無い（掛ける前・倒産して新しい会社になった直後）ときは、NAMELESS の文字を出す
##   ・文字しか出せない所（ウィンドウの題など）は plain() で文字にする
const TOKEN := "{会社}"
const NAMELESS := "名無しの会社"
const DEFAULT := "格安アクション映画制作班"       # 文字しか出せない所の名前（production_flow.gd の DEFAULT_COMPANY）
const PLACE := "■"                                 # 隠した Label の中で、絵の幅を取っておく字
const TWIN := "CompanyLogoText"
static var texture: Texture2D = null                # 看板の絵（背景は透明）。無ければ null
static var version := 0                             # 絵を撮り直すたびに増える


static func set_logo(tex: Texture2D) -> void:
	texture = tex
	version += 1


static func has_logo() -> bool:
	return texture != null and texture.get_width() > 0 and texture.get_height() > 0


# 文字だけの所：TOKEN を文字の名前にする
static func plain(text: String) -> String:
	return text.replace(TOKEN, DEFAULT if has_logo() else NAMELESS)


# 看板の絵を、文の中に出すときの大きさ（字の大きさ px から）
static func image_size(font_size: int) -> Vector2:
	if not has_logo():
		return Vector2.ZERO
	var h := float(font_size) * 2.6      # 手書きの字が読める大きさ
	var w := h * float(texture.get_width()) / float(texture.get_height())
	var cap := float(font_size) * 10.0
	if w > cap:
		h *= cap / w
		w = cap
	return Vector2(w, h).round()


# 絵の幅だけ字を詰めた文（Label の大きさ・折り返しを、絵を入れた文とそろえる）
static func layout_text(text: String, font_size: int) -> String:
	if not text.contains(TOKEN):
		return text
	if not has_logo():
		return text.replace(TOKEN, NAMELESS)
	var n := maxi(1, int(ceil(image_size(font_size).x / float(font_size))))
	return text.replace(TOKEN, PLACE.repeat(n))


# Label に文を出す。TOKEN があって看板の絵があれば、同じ字・同じ色の RichTextLabel（子）に、絵を埋め込んで出す。
# Label 自身は、絵の幅の字を詰めた文で大きさを決めて、字は見せない（self_modulate）
static func show_in(label: Label, text: String) -> void:
	var size := label.get_theme_font_size("font_size")
	var twin := label.get_node_or_null(TWIN) as RichTextLabel
	var on := text.contains(TOKEN) and has_logo()
	label.text = layout_text(text, size)
	label.self_modulate.a = 0.0 if on else 1.0
	if not on:
		if twin != null:
			twin.visible = false
		return
	if twin == null:
		twin = RichTextLabel.new()
		twin.name = TWIN
		twin.bbcode_enabled = false
		twin.scroll_active = false
		twin.clip_contents = false
		twin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		twin.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.add_child(twin)
	twin.visible = true
	twin.add_theme_font_override("normal_font", label.get_theme_font("font"))
	twin.add_theme_font_size_override("normal_font_size", size)
	twin.add_theme_color_override("default_color", label.get_theme_color("font_color"))
	twin.add_theme_color_override("font_outline_color", label.get_theme_color("font_outline_color"))
	twin.add_theme_constant_override("outline_size", label.get_theme_constant("outline_size"))
	twin.add_theme_constant_override("line_separation", label.get_theme_constant("line_spacing"))
	twin.autowrap_mode = label.autowrap_mode
	twin.horizontal_alignment = label.horizontal_alignment
	twin.vertical_alignment = label.vertical_alignment
	write(twin, text, size)


# RichTextLabel に、TOKEN を看板の絵に替えて書く（字は bbcode として読まない）
static func write(rich: RichTextLabel, text: String, font_size: int) -> void:
	rich.clear()
	var parts := text.split(TOKEN)
	var pic := image_size(font_size)
	for i in parts.size():
		if i > 0:
			if has_logo():
				rich.add_image(texture, int(pic.x), int(pic.y), Color.WHITE, INLINE_ALIGNMENT_CENTER)
			else:
				rich.add_text(NAMELESS)
		if parts[i] != "":
			rich.add_text(parts[i])
