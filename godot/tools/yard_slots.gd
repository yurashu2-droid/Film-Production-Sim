extends SceneTree
# 廃材置き場のモデルから「物を置ける空き場所」を計算して、置き場所の表を書き出す。
#   godot --headless --path godot -s res://tools/yard_slots.gd
# 出力：res://scripts/production_yard_slots.gd（手で直さず、このスクリプトを回し直す）
# 座標はヤードのローカル（Godot）座標。通路の中央は歩けるように空けておく。

const CELL := 0.25
const HALF := Vector2(15.0, 12.0)           # 囲いの内側
# 前はここに置いていたが、今は置かない物。ほかの物の置き場所を動かさないよう、場所だけ取っておき、表には書き出さない。
#   carton：段ボール箱は、段ボール置き場（scripts/cargo_kit.gd）から出す
const VACATED := ["carton"]
# 計算で決まった置き場所を、手で少しずらす物：[種類, 何個目（0から）, 新しい場所]。
# 空きは円（半径）と「高さのある部品」で見ているので、薄い板を積んだ低い山（パレットに布を積んだ、高さ 0.5m の山など）は拾えない。
# そこに重なった物だけ、足元の四角で空きを確かめた場所へずらす（ほかの物の場所は動かさない）。
#   flat 0  ：布の山（x -4.1〜-2.9 / z 2.8〜3.6）の上に載って、起動した直後に跳ねて傾いていた
#   riser 0 ：同じパレットの角に、足場の角が載っていた
const MOVED := [
	["flat", 0, Vector2(-3.69, 2.53)],
	["riser", 0, Vector2(-1.88, 3.88)],
]
# 低い山のそば（円が触れる）でも、足元の四角では重ならないと確かめた物。ここに無い物が出たら、画面で確かめる
const CHECKED := ["flat#0", "riser#0", "scrap_chimney#0", "scrap_windmill#0"]
# [種類, 個数, 置くのに要る半径(m)]。大きい物から順に置く
const WANT := [
	["greenscreen", 1, 1.9], ["ruin", 1, 1.5], ["scrap_arch", 1, 1.1], ["partition", 1, 1.2],
	["riser", 1, 1.0], ["boomflat", 2, 1.0], ["plywood", 2, 0.9], ["flat", 2, 1.0],
	["scrap_crane", 1, 0.9], ["scrap_tree", 1, 0.9], ["scrap_bus", 1, 0.8], ["scrap_bridge", 1, 0.8],
	["tomato_monster", 1, 0.9], ["scrap_capsule", 1, 0.8], ["scrap_kiosk", 1, 0.8], ["moon", 1, 0.8],
	["rock", 2, 0.7], ["carton", 4, 0.65],
	["witch_cauldron", 1, 0.7], ["scrap_mushroom", 1, 0.7], ["scrap_fan", 1, 0.7], ["scrap_duck", 1, 0.6],
	["scrap_toilet", 1, 0.6], ["scrap_chest", 1, 0.6], ["scrap_clock", 1, 0.6], ["scrap_chimney", 1, 0.6],
	["scrap_column", 1, 0.6], ["scrap_lamp", 1, 0.5], ["dragon_skull", 1, 0.5], ["applebox", 3, 0.4],
	["boom", 1, 0.5], ["basket", 1, 0.4], ["crown", 1, 0.35], ["fish", 1, 0.35], ["filmcan", 1, 0.35],
	["recorder", 1, 0.3], ["letter", 1, 0.3], ["tape", 1, 0.3],
	# 2026-10-12 追加分。今までの置き場所を動かさないよう、表の末尾に足す
	["scrap_windmill", 1, 0.9], ["scrap_train", 1, 0.8], ["scrap_tub", 1, 0.7], ["scrap_fountain", 1, 0.7],
	["scrap_phone", 1, 0.7], ["scrap_vending", 1, 0.7], ["scrap_cactus", 1, 0.7], ["scrap_fridge", 1, 0.6],
	["scrap_campfire", 1, 0.6], ["scrap_idol", 1, 0.4], ["scrap_chicken", 1, 0.35], ["scrap_torch", 1, 0.35],
	["scrap_plunger", 1, 0.3], ["scrap_poop", 1, 0.4], ["scrap_pie", 1, 0.35],
	# 2026-10-16 追加：ブルーシートの包み（振ると大道具が出る）・ゴミ袋（振ると小道具が出る）。features/junk_bags.gd
	["tarpbundle", 2, 0.6], ["trashbag", 4, 0.45],
]
# 日替わりの廃材ではない物（いつも出ている）。SLOTS ではなく BAG_SPOTS に書き出す
const ALWAYS := ["tarpbundle", "trashbag"]


func _init() -> void:
	var yard: Node3D = (load("res://assets/stage/yard/dirty_yard_seed_41.glb") as PackedScene).instantiate()
	var nx := int(HALF.x * 2.0 / CELL)
	var nz := int(HALF.y * 2.0 / CELL)
	var blocked := PackedByteArray()
	blocked.resize(nx * nz)
	# 薄い板を積んだ低い山（確かめ用。置き場所の計算には使わない＝今までの場所を動かさない）
	var low := PackedByteArray()
	low.resize(nx * nz)
	var lanes: Array = []
	var stack: Array = [[yard, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		var t: Transform3D = it[1]
		if node is Node3D and node != yard:
			t = t * (node as Node3D).transform
		if node is MeshInstance3D:
			var b: AABB = t * (node as MeshInstance3D).mesh.get_aabb()
			var nm := String(node.name).to_lower()
			if nm.contains("aisle") and nm.contains("clear") or nm.contains("spur") or nm.contains("apron"):
				lanes.append(b)
			elif b.end.y > 0.22 and b.end.y < 1.3 and b.size.y <= 0.12 and maxf(b.size.x, b.size.z) >= 0.9:
				# 当たり判定の付く大きさ（0.9m 以上）で、上の面が腰より低い、薄い板
				for iz in range(maxi(0, int((b.position.z + HALF.y) / CELL)), mini(nz, int((b.end.z + HALF.y) / CELL) + 1)):
					for ix in range(maxi(0, int((b.position.x + HALF.x) / CELL)), mini(nx, int((b.end.x + HALF.x) / CELL) + 1)):
						low[iz * nx + ix] = 1
			elif b.end.y > 0.22 and b.size.y > 0.12:
				# 高さのある物は「ふさがっている」
				for iz in range(maxi(0, int((b.position.z - 0.15 + HALF.y) / CELL)), mini(nz, int((b.end.z + 0.15 + HALF.y) / CELL) + 1)):
					for ix in range(maxi(0, int((b.position.x - 0.15 + HALF.x) / CELL)), mini(nx, int((b.end.x + 0.15 + HALF.x) / CELL) + 1)):
						blocked[iz * nx + ix] = 1
		for c in node.get_children():
			stack.push_back([c, t])
	# 通路の中央は歩く道として空ける
	for b: AABB in lanes:
		print("LANE pos=", b.position, " size=", b.size)
		var along_z: bool = b.size.z > b.size.x
		var keep := 0.95
		var lo := Vector2(b.position.x, b.position.z)
		var hi := Vector2(b.end.x, b.end.z)
		if along_z:
			var cx := (lo.x + hi.x) * 0.5
			lo.x = cx - keep
			hi.x = cx + keep
		else:
			var cz := (lo.y + hi.y) * 0.5
			lo.y = cz - keep
			hi.y = cz + keep
		for iz in range(maxi(0, int((lo.y + HALF.y) / CELL)), mini(nz, int((hi.y + HALF.y) / CELL) + 1)):
			for ix in range(maxi(0, int((lo.x + HALF.x) / CELL)), mini(nx, int((hi.x + HALF.x) / CELL) + 1)):
				blocked[iz * nx + ix] = 1
	# コンテナの置き場と扉の前
	for iz in range(int((-12.0 + HALF.y) / CELL), int((-2.6 + HALF.y) / CELL)):
		for ix in range(int((8.4 + HALF.x) / CELL), int((13.8 + HALF.x) / CELL)):
			blocked[iz * nx + ix] = 1

	# 入口（+Z側の中央）に近い順に、空いている場所へ置いていく
	var cells: Array = []
	for iz in nz:
		for ix in nx:
			var p := Vector2(-HALF.x + (ix + 0.5) * CELL, -HALF.y + (iz + 0.5) * CELL)
			cells.append([p.distance_to(Vector2(0, 9.0)) + absf(p.x) * 0.15, p])
	cells.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out := {}
	var placed: Array = []
	var missing: Array = []
	for want: Array in WANT:
		var r: float = want[2]
		for k in int(want[1]):
			var found := false
			for c: Array in cells:
				var p: Vector2 = c[1]
				if absf(p.x) > HALF.x - r - 0.5 or absf(p.y) > HALF.y - r - 0.5:
					continue
				var ok := true
				for q: Array in placed:
					if p.distance_to(q[0]) < r + float(q[1]) + 0.12:
						ok = false
						break
				if not ok:
					continue
				var rr := int(ceil(r / CELL))
				var cx := int((p.x + HALF.x) / CELL)
				var cz := int((p.y + HALF.y) / CELL)
				for dz in range(-rr, rr + 1):
					for dx in range(-rr, rr + 1):
						if dx * dx + dz * dz <= rr * rr and blocked[clampi(cz + dz, 0, nz - 1) * nx + clampi(cx + dx, 0, nx - 1)] == 1:
							ok = false
							break
					if not ok:
						break
				if ok:
					placed.append([p, r])
					if not out.has(want[0]):
						out[want[0]] = []
					(out[want[0]] as Array).append(p)
					found = true
					break
			if not found:
				missing.append(want[0])
	for move: Array in MOVED:
		var moved_list: Array = out[move[0]]
		moved_list[int(move[1])] = move[2]
	# 低い山のそばに置かれた物を書き出す
	var radius := {}
	for want: Array in WANT:
		radius[want[0]] = float(want[2])
	var near_low: Array = []
	for kind: String in out:
		for n in (out[kind] as Array).size():
			var p: Vector2 = out[kind][n]
			var rr := int(ceil(float(radius[kind]) / CELL))
			var cx := int((p.x + HALF.x) / CELL)
			var cz := int((p.y + HALF.y) / CELL)
			var touches := false
			for dz in range(-rr, rr + 1):
				for dx in range(-rr, rr + 1):
					if dx * dx + dz * dz <= rr * rr and low[clampi(cz + dz, 0, nz - 1) * nx + clampi(cx + dx, 0, nx - 1)] == 1:
						touches = true
			if touches and not ("%s#%d" % [kind, n]) in CHECKED and not kind in VACATED:
				near_low.append("%s#%d" % [kind, n])
	var text := "extends RefCounted\n# 廃材置き場の中の置き場所（ヤードのローカル座標 x,z）。tools/yard_slots.gd が書き出す。手で直さない。\nconst SLOTS := {\n"
	for kind: String in out:
		if kind in VACATED or kind in ALWAYS:
			continue
		var pts: Array = []
		for p: Vector2 in out[kind]:
			pts.append("Vector2(%.2f, %.2f)" % [p.x, p.y])
		text += "\t\"%s\": [%s],\n" % [kind, ", ".join(pts)]
	text += "}\n# いつも出ている物の置き場所（日替わりの廃材ではない。features/junk_bags.gd のゴミ袋・包み）\nconst BAG_SPOTS := {\n"
	for kind: String in ALWAYS:
		if not out.has(kind):
			continue
		var spots: Array = []
		for p: Vector2 in out[kind]:
			spots.append("Vector2(%.2f, %.2f)" % [p.x, p.y])
		text += "\t\"%s\": [%s],\n" % [kind, ", ".join(spots)]
	text += "}\n"
	var f := FileAccess.open("res://scripts/production_yard_slots.gd", FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("YARD_SLOTS placed=", placed.size(), " missing=", missing, " near_low_stack=", near_low)
	yard.free()
	quit()
