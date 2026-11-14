extends RefCounted
## 段ボールの原形・開閉・持ち方を保ち、絵柄の紙だけを貼る。
const RECIPES := {"window":"ビルの窓", "sign":"映画の看板", "shield":"盾の紋章"}
static var _textures := {}

static func apply(prop: Node3D, recipe: String) -> void:
	var old: Node = prop.get_node_or_null("CrewArtwork")
	if old != null:
		prop.remove_child(old)
		old.queue_free()
	if prop.has_meta("crew_original_label"):
		prop.label = prop.get_meta("crew_original_label")
		prop.tags = prop.get_meta("crew_original_tags").duplicate()
	if not RECIPES.has(recipe) or prop.kind != "carton": return
	if not prop.has_meta("crew_original_label"):
		prop.set_meta("crew_original_label", prop.label)
		prop.set_meta("crew_original_tags", prop.tags.duplicate())
	prop.label = "段ボール工作・" + RECIPES[recipe]
	if recipe == "window" and "city" not in prop.tags: prop.tags.append("city")
	var root := Node3D.new()
	root.name = "CrewArtwork"
	prop.add_child(root)
	var material := StandardMaterial3D.new()
	material.albedo_texture = _texture(recipe)
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1, 1]:
		var mesh := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(prop.half.x * 1.65, prop.half.y * 1.45)
		mesh.mesh = quad
		mesh.material_override = material
		mesh.position = prop.center + Vector3(0, 0, side * (prop.half.z + 0.012))
		mesh.rotation.y = PI if side < 0 else 0.0
		root.add_child(mesh)

static func _texture(recipe: String) -> Texture2D:
	if _textures.has(recipe): return _textures[recipe]
	var art := ""
	match recipe:
		"window":
			art = '<rect x="28" y="26" width="200" height="204" fill="#283c4e" stroke="#f0dfb4" stroke-width="14"/><path d="M128 27V230M28 126H228" stroke="#c5a77b" stroke-width="14"/><path d="M46 52L92 36M156 218L211 171" stroke="#a1c1c4" stroke-width="8"/>'
		"sign":
			art = '<rect x="12" y="27" width="232" height="199" rx="8" fill="#263438"/><path d="M20 31L61 68M77 31L119 68M135 31L177 68M194 31L235 68" stroke="#eee2c5" stroke-width="22"/><path d="M46 181L74 99L102 181M55 153H93M128 106H210M169 105V183" fill="none" stroke="#efce70" stroke-width="12"/>'
		"shield":
			art = '<path d="M128 17L229 52L215 153Q199 212 128 244Q57 212 41 153L27 52Z" fill="#596c85" stroke="#f0d27e" stroke-width="10"/><path d="M128 43L146 96L202 97L157 130L173 184L128 151L83 184L99 130L54 97L110 96Z" fill="#efce70"/>'
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256"><rect width="256" height="256" fill="#b99260"/>' + art + '</svg>'
	var img := Image.new()
	img.load_svg_from_string(svg)
	var texture := ImageTexture.create_from_image(img)
	_textures[recipe] = texture
	return texture
