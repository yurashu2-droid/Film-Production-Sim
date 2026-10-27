extends SceneTree
# 事務所の壁の実績（納品した作品のポスター）と、格の見た目を確かめる（scripts/features/office_wall.gd）。
#   godot --headless --path godot --fixed-fps 60 --script res://tests/office_wall_test.gd
# 納品すると films に1本増え、壁にポスターが貼られる。出来で貼り方が変わる。格で事務所の物が増え、下がると外れる。倒産で壁が空になる
var game: Node
var failed := false


func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print("OFFICE_WALL_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func posters(wall: Node) -> Array:
	return wall.slots.filter(func(n: Variant) -> bool: return n != null and is_instance_valid(n) and not n.is_queued_for_deletion())


func run() -> void:
	game = load("res://production_game.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.input_locked = true
	while not game.startup_complete:
		await process_frame
	await frames(10)
	var wall: Node = game.hooks.feature("office_wall")
	var flow: Node = game.production
	check(wall != null and "office_wall" in game.hooks.names(), "壁の仕組みが、置くだけで登録されている")
	check(game.hooks.problems().is_empty(), "登録の食い違いが無い %s" % [game.hooks.problems()])
	check(flow.films.is_empty() and posters(wall).is_empty(), "最初は、壁に何も貼っていない")
	check(not wall.rank_items[2].visible and not wall.rank_items[3].visible and not wall.rank_items[4].visible, "格1では、格の物は何も無い")
	check("films" in flow.snapshot(), "納品した作品は、会社の状態（snapshot）で全員へ配られる")

	# 出来の違う4本：全部・半分以上・少し・何も撮れていない
	flow.films = [{"job": 0, "ok": 3, "of": 3}, {"job": 3, "ok": 2, "of": 3}, {"job": 9, "ok": 1, "of": 3}, {"job": 10, "ok": 0, "of": 5}]
	wall.refresh()
	var list := posters(wall)
	check(list.size() == 4, "4本納品すると、ポスターが4枚")
	check(list.map(func(n: Node) -> int: return int(n.get_meta("grade"))) == [3, 2, 1, 0], "出来の段階：全部＝3・半分以上＝2・少し＝1・なし＝0")
	var tilts: Array = list.map(func(n: Node3D) -> float: return _roll(n))
	check(tilts[0] < 0.001 and tilts[1] < tilts[2] and tilts[2] < tilts[3], "出来が悪いほど、斜めに貼ってある %s" % [tilts])
	var face_best: MeshInstance3D = list[0].get_node("Face")
	var face_flop: MeshInstance3D = list[3].get_node("Face")
	check((face_flop.mesh as ArrayMesh).surface_get_array_len(0) > (face_best.mesh as ArrayMesh).surface_get_array_len(0), "何も撮れなかった作品は、角が破れている（紙の形の点が多い）")
	check(list[0].get_node("Hang").get_child_count() > 0 and list[0].get_node("Art") is SubViewport, "全部そろった作品は額に入り、絵は 2D の画面に描いて貼る")
	# 貼る場所：西の壁に入口の側から → 13枚目から奥の壁
	check(absf(list[0].global_position.x - wall.WEST_X) < 0.05 and list[0].global_position.z > list[1].global_position.z, "西の壁に、入口の側から奥へ並ぶ")
	var many: Array = []
	for i in 30:
		many.append({"job": i % 17, "ok": 3, "of": 3})
	many[29] = {"job": 9, "ok": 0, "of": 3}
	flow.films = many
	wall.refresh()
	list = posters(wall)
	check(list.size() == wall.MAX, "いっぱいになったら、新しい %d 枚だけ貼る" % wall.MAX)
	check(absf(list[wall.WEST_N].global_position.z - wall.BACK_Z) < 0.05 and int(list[-1].get_meta("grade")) == 0 and int(list[-1].get_meta("job")) == 9, "13枚目から奥の壁、最後の1枚が最新の作品")

	# 格：上がると物が増え、下がると外れる
	var expect := {0: [false, false, false], 4: [true, false, false], 9: [true, true, false], 15: [true, true, true]}
	for rep: int in [4, 9, 15, 4, 0]:
		flow.reputation = rep
		wall.refresh()
		var got := [wall.rank_items[2].visible, wall.rank_items[3].visible, wall.rank_items[4].visible]
		check(got == expect[rep], "評判 %d（格%d）：感謝状・トロフィーと名刺・台本の山 = %s" % [rep, flow.rank(), got])
	var solid: StaticBody3D = wall.rank_items[4].find_children("*", "StaticBody3D", true, false)[0]
	check(solid.collision_layer == 0, "外した台本の山には、ぶつからない")

	# 納品すると、1本記録される（settle）
	flow.films = []
	flow.reputation = 0
	game.takes = [{"passed": [true, true, false], "results": [], "extras": {}}]
	flow.chosen_job = 3
	flow.settle(0)
	await frames(2)
	check(flow.films.size() == 1 and int(flow.films[0]["job"]) == 3 and int(flow.films[0]["ok"]) == 2 and int(flow.films[0]["of"]) == 3, "納品すると、作品が1本記録される %s" % [flow.films])
	check(posters(wall).size() == 1 and int(posters(wall)[0].get_meta("grade")) == 2, "精算の知らせが届くと、壁にポスターが1枚増える")

	# 倒産：帰社すると、新しい会社。壁は空、格の物も無い
	flow.films = [{"job": 0, "ok": 3, "of": 3}, {"job": 3, "ok": 3, "of": 3}]
	flow.reputation = 10
	flow.bankrupt = true
	flow.phase = 5
	flow.return_office()
	await frames(2)
	wall.refresh()
	check(flow.films.is_empty() and flow.reputation == 0, "倒産して帰社すると、作品の記録と評判が 0 に")
	check(posters(wall).is_empty() and not wall.rank_items[2].visible and not wall.rank_items[3].visible, "新しい会社の壁は、空")

	print("OFFICE_WALL_TEST_FAIL" if failed else "OFFICE_WALL_TEST_OK")
	root.get_node("Sfx").silence_all()
	quit(1 if failed else 0)


# 壁の面の中での傾き（貼る場所の向きを外した、面の法線まわりの回転）
func _roll(n: Node3D) -> float:
	var up: Vector3 = n.global_transform.basis.y
	return acos(clampf(up.dot(Vector3.UP), -1.0, 1.0))
