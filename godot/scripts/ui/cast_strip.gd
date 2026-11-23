extends RefCounted
## キャラのモデルから「生身」（肌・顔・髪）の部品だけを抜いた絵を作る（キャラ選びのタンス用。2026-11-23 ユーザー：服と持ち物だけを吊るす）。
## モデルは1枚の絵だが、中は、つながっていない部品（島）の集まり（帽子・頭・目・服・靴…）。部品ごとに、
##   ・テクスチャの平均の色が、そのキャラの肌の色に近い　　・顔の骨（目・まぶた・瞳・口）に付いている
## のどちらかなら、その部品の三角を抜く。下調べの道具は tools/cast_parts.py（部品の表を出す）。
## 段ボール頭（箱が頭）とロボットは、抜く所が無い。
const SKIN := {
	"01": ["dfb54a", "b38f41", "7a5a44"],      # 黄色い体・足の裏・髪
	"02": ["a3ad60", "cea28b"],                # 緑の頭・口
	"03": ["cab9cf"],                          # 薄紫の頭
	"04": ["d4d1c9"],                          # 白い頭
	"06": ["d2b169"],                          # からし色の腕と手
	"09": ["151311", "573b21"],                # 口（黒い線と、そのふち）
	"M02": ["e9902b", "e38c29"],               # おなかのランプ
}
# 肌と似た色の服がある時は、付いている骨でも絞る（04：頭と靴・えり巻きが同じ白 / 06：手と王冠が同じ黄）
const ONLY_ON := {
	"03": ["FACE", "JAW"],
	"04": ["FACE", "JAW"],
	"06": ["UPPER_ARM", "FOREARM", "HAND", "FINGERS", "THUMB"],
}
# 段ボール頭とロボット（2026-11-23 ユーザー）。1回目は、箱そのもの・ロボットの殻を消して「必須の部分だけ消えてる」と言われた。
# 見て誰か分かる物（箱・殻）は残して、ほかの5人の「頭と顔」に当たる所を抜く：
#   段ボール頭：箱は残り、箱に付いた目・まぶた・口が無くなる（ただの段ボール箱になる）
#   ロボット：殻は残り、画面の顔・おなかの窓・ランプが無くなる（穴の開いた空の殻になる）
const DROP_BONES := {
	"09": ["EYE", "LID", "PUPIL"],
}
const KEEP := {}
const HIDE_MESH := {"M02": ["screen", "glass"]}      # 別の絵になっている部品は、絵ごと隠す
const KEEP_FACE := ["09", "M02"]               # 目・口の骨の決まりを使わないキャラ（ロボットの手は JAW_ という名前の骨）
const FACE_PARTS := ["EYE", "LID", "PUPIL", "MOUTH", "JAW"]
const NEAR := 0.085                            # 色の近さ（RGB の差の長さ。0〜1）
static var _cache: Dictionary = {}


# vis（cast_visual.gd）の体の絵を、生身を抜いた絵に替える。抜く所の無いキャラは、そのまま
static func strip(vis: Node3D, tag: String) -> void:
	if not SKIN.has(tag) and not DROP_BONES.has(tag):
		return
	for mi: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
		for part: String in HIDE_MESH.get(tag, []):
			if str(mi.name).ends_with(part):
				mi.visible = false
	var skel: Skeleton3D = vis.skel
	for mi: MeshInstance3D in vis.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or mi.mesh.get_surface_count() != 1 or mi.skin == null:
			continue
		var key := tag + ":" + str(mi.name)
		if not _cache.has(key):
			_cache[key] = _build(mi, skel, tag)
		if _cache[key] != null:
			mi.mesh = _cache[key]


static func _build(mi: MeshInstance3D, skel: Skeleton3D, tag: String) -> Mesh:
	var mesh := mi.mesh
	var arrays := mesh.surface_get_arrays(0)
	# テクスチャを貼っていない絵（ロボットの画面・ガラス）は、UV や骨が無い。そのまま残す
	for need: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_INDEX, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
		if arrays[need] == null:
			return null
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var mat := mesh.surface_get_material(0) as BaseMaterial3D
	if verts.is_empty() or index.is_empty() or bones.is_empty() or mat == null or mat.albedo_texture == null:
		return null
	var image := mat.albedo_texture.get_image()
	if image.is_compressed():
		image.decompress()
	# 骨の番号（絵の中の番号＝skin の並び）→ 顔の骨か
	var is_face := PackedByteArray()
	is_face.resize(mi.skin.get_bind_count())
	var is_zone := PackedByteArray()          # 肌の色で抜いてよい骨か（ONLY_ON が無ければ、どこでも）
	is_zone.resize(mi.skin.get_bind_count())
	for b in mi.skin.get_bind_count():
		var bone_name := str(mi.skin.get_bind_name(b))
		if bone_name == "" and mi.skin.get_bind_bone(b) >= 0:
			bone_name = skel.get_bone_name(mi.skin.get_bind_bone(b))
		for part: String in FACE_PARTS:
			if bone_name.begins_with(part):
				is_face[b] = 1
		if tag in KEEP_FACE:
			is_face[b] = 0
		for part: String in DROP_BONES.get(tag, []):
			if bone_name.begins_with(part):
				is_face[b] = 1               # 丸ごと抜く骨は、顔の骨と同じ扱いで数える
		is_zone[b] = 0 if ONLY_ON.has(tag) else 1
		for part: String in ONLY_ON.get(tag, []):
			if bone_name.begins_with(part):
				is_zone[b] = 1
	var n := verts.size()
	# 同じ場所の頂点を1つにまとめる（縫い目で頂点が分かれているため）
	var weld := PackedInt32Array()
	weld.resize(n)
	var seen: Dictionary = {}
	for i in n:
		var k := Vector3i((verts[i] * 20000.0).round())
		if not seen.has(k):
			seen[k] = seen.size()
		weld[i] = seen[k]
	var parent := PackedInt32Array()
	parent.resize(seen.size())
	for i in parent.size():
		parent[i] = i
	for t in range(0, index.size(), 3):
		var a := _find(parent, weld[index[t]])
		for j: int in [1, 2]:
			var b := _find(parent, weld[index[t + j]])
			if a != b:
				parent[b] = a
	# 部品ごとに、色と、顔の骨の重みを集める
	var per := bones.size() / n
	var groups := parent.size()
	var sum := PackedVector3Array()
	sum.resize(groups)
	var count := PackedInt32Array()
	count.resize(groups)
	var face := PackedFloat32Array()
	face.resize(groups)
	var total := PackedFloat32Array()
	total.resize(groups)
	var zone := PackedFloat32Array()
	zone.resize(groups)
	var size := Vector2(image.get_size() - Vector2i.ONE)
	var comp := PackedInt32Array()
	comp.resize(n)
	for i in n:
		var c := _find(parent, weld[i])
		comp[i] = c
		var uv := uvs[i].posmod(1.0) * size
		var px := image.get_pixel(int(uv.x), int(uv.y))
		sum[c] += Vector3(px.r, px.g, px.b)
		count[c] += 1
		for j in per:
			var w := weights[i * per + j]
			total[c] += w
			if bones[i * per + j] < is_face.size() and is_face[bones[i * per + j]] == 1:
				face[c] += w
			if bones[i * per + j] < is_zone.size() and is_zone[bones[i * per + j]] == 1:
				zone[c] += w
	var skins: Array[Vector3] = []
	var keeps: Array[Vector3] = []
	for hex: String in KEEP.get(tag, []):
		var kc := Color(hex)
		keeps.append(Vector3(kc.r, kc.g, kc.b))
	for hex: String in SKIN.get(tag, []):
		var col := Color(hex)
		skins.append(Vector3(col.r, col.g, col.b))
	var drop := PackedByteArray()
	drop.resize(groups)
	for c in groups:
		if count[c] == 0:
			continue
		var mean0 := sum[c] / float(count[c])
		var kept_color := false
		for kc: Vector3 in keeps:
			if mean0.distance_to(kc) < NEAR:
				kept_color = true
		if kept_color:
			continue
		if total[c] > 0.0 and face[c] / total[c] > 0.5:
			drop[c] = 1
			continue
		# テクスチャは sRGB のまま読んでいるので、色の表（sRGB の 16 進）と、そのまま比べる
		if total[c] <= 0.0 or zone[c] / total[c] < 0.5:
			continue
		var mean := sum[c] / float(count[c])
		for s: Vector3 in skins:
			if mean.distance_to(s) < NEAR:
				drop[c] = 1
	var kept := PackedInt32Array()
	for t in range(0, index.size(), 3):
		if drop[comp[index[t]]] == 0:
			kept.append(index[t])
			kept.append(index[t + 1])
			kept.append(index[t + 2])
	arrays[Mesh.ARRAY_INDEX] = kept
	var out := ArrayMesh.new()
	var flags := 0
	if per == 8:
		flags = Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	out.surface_set_material(0, mat)
	return out


static func _find(parent: PackedInt32Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x
