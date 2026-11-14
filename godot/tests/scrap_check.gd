extends SceneTree
# 廃材置き場の追加小道具の自動確認。SCRAPCHECK_OK / SCRAPCHECK_FAIL: ... を出力する。
const Scrap := preload("res://scripts/production_scrap.gd")
const Audit := preload("res://tools/collider_audit.gd")
var game: Node
var problems: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func fail(msg: String) -> void:
	problems.append(msg)

func tri_count(node: Node) -> int:
	var tris := 0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arr := m.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			tris += (idx.size() if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return tris

func collider_bottom(p: Node3D) -> float:
	var low := INF
	for c in p.get_children():
		if c is CollisionShape3D:
			# 回した箱・球・カプセルも正しく測る：形の表面の点を世界の座標へ直して、いちばん低い所を見る
			var to_world: Transform3D = (c as CollisionShape3D).global_transform
			for point: Vector3 in Audit.shape_points((c as CollisionShape3D).shape):
				low = minf(low, (to_world * point).y)
	return low

func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 150:
		await physics_frame
	var found := {}
	for pid in game.props:
		found[game.props[pid].kind] = game.props[pid]
	var scrap: Array = []
	var total_tris := 0
	for item: Dictionary in Scrap.ITEMS:
		var kind: String = item["kind"]
		if not found.has(kind):
			fail("%s: not in game.props" % kind)
			continue
		var p: Node3D = found[kind]
		scrap.append(p)
		if String(p.label).is_empty():
			fail("%s: empty label" % kind)
		if not (p.tags is Array) or p.tags.is_empty():
			fail("%s: tags missing" % kind)
		if p.half.x <= 0.0 or p.half.y <= 0.0 or p.half.z <= 0.0:
			fail("%s: half not positive" % kind)
		var bottom := collider_bottom(p)
		# 廃材置き場の床は地面より3cmほど高い（砂利と舗装のぶん）
		if bottom < -0.03 or bottom > 0.09:
			fail("%s: collider bottom %.3f not on floor" % [kind, bottom])
		if p.global_basis.y.y <= 0.95:
			fail("%s: not upright (%.3f)" % [kind, p.global_basis.y.y])
		if p.mass > 12.0:
			fail("%s: mass %.1f too heavy" % [kind, p.mass])
		var tris := tri_count(p.visual)
		total_tris += tris
		print("SCRAP %s tris=%d mass=%.1f half=(%.2f, %.2f, %.2f) tags=%s bottom=%.3f up=%.3f pos=(%.2f, %.2f, %.2f)" % [kind, tris, p.mass, p.half.x, p.half.y, p.half.z, p.tags, bottom, p.global_basis.y.y, p.global_position.x, p.global_position.y, p.global_position.z])
	# 全プロップ同士（生成済みの全部）で、x/z の中心間距離が半寸の和より近い物がないか
	for p in scrap:
		for pid in game.props:
			var q: Node3D = game.props[pid]
			if q == p or q.kind == "mark" or q.absent or q.global_position.y < -5.0:
				continue
			var dx := absf(p.global_position.x - q.global_position.x)
			var dz := absf(p.global_position.z - q.global_position.z)
			if dx < p.half.x + q.half.x and dz < p.half.z + q.half.z:
				fail("%s overlaps %s (dx=%.2f dz=%.2f)" % [p.kind, q.kind, dx, dz])
	# 既存の怪獣タグ
	for kind in ["tomato_monster", "dragon_skull"]:
		if not found.has(kind) or not ("monster" in found[kind].tags):
			fail("%s lacks monster tag" % kind)
	var counts := {"city": 0, "monster": 0, "castle": 0}
	for p in scrap:
		for t in counts:
			if t in p.tags:
				counts[t] += 1
	print("SCRAP totals: props=%d tris=%d tags=%s" % [scrap.size(), total_tris, counts])
	if scrap.size() != Scrap.ITEMS.size():
		fail("count mismatch")
	if problems.is_empty():
		print("SCRAPCHECK_OK")
	else:
		print("SCRAPCHECK_FAIL: ", "; ".join(problems))
	quit(0 if problems.is_empty() else 1)
