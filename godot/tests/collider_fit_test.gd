extends SceneTree
# 持てる物の「見た目」と「当たり判定」が合っているかの自動確認。ゲームの場面は開かず、物だけを作って確かめる。
#   godot --headless --path godot --script res://tests/collider_fit_test.gd
# 見るもの：
#   1) 全部の種類：当たり判定の外形が、見た目の外形から大きくはみ出していない・大きく足りなくない
#      （面ごとに、その向きの大きさの12%か8cmの大きいほうまで）。底が床にある。形の数が12個以下。
#   2) 空いているはずの所（アーチの下・脚の間・壁の後ろ など）に当たり判定が無く、形のある所にはある
#   3) 人が、アーチをくぐれる・太鼓橋を渡れる・足場や箱馬や段ボールなどに乗れる
#   4) 床に置いて放すと、動かず・倒れず・震えない
# 行は "COLLIDER_FIT_CHECK <説明> OK/FAIL"、最後に COLLIDER_FIT_TEST_OK / COLLIDER_FIT_TEST_FAIL。
# 重ねた写真は tools/collider_shots.gd で撮れる。形の表は scripts/prop_shapes.gd。
const Audit := preload("res://tools/collider_audit.gd")
const PropShapes := preload("res://scripts/prop_shapes.gd")
const Scrap := preload("res://scripts/production_scrap.gd")

const MAX_SHAPES := 12
const EDGE_RATIO := 0.12        # 面ごとのずれの許し：その向きの大きさの12%
const EDGE_MIN := 0.08          # …か、8cm の大きいほう
const FLOOR_LOW := -0.02        # 底の高さの許し（物の原点＝床）
const FLOOR_HIGH := 0.05
const SPACING := 40.0

# 形を付けていない飾り・張り出しのぶん、面ごとの許しを広げる（m）。面は "x-" "x+" "y-" "y+" "z-" "z+"。理由も書く
const LOOSE := {
	"scrap_straight_stair": {"y+": 0.65, "why": "手すりには形を付けない（段の上の斜めの板で歩いて上る）"},
	"scrap_turning_stair": {"y+": 0.60, "why": "手すりには形を付けない"},
	"scrap_access_ramp": {"y+": 0.55, "why": "手すりには形を付けない"},
	"dolly": {"y+": 1.60, "why": "後ろへ張り出した押し手には形を付けない（荷台に積むときのかさを広げないため）"},
	"camera": {"z-": 0.15, "why": "三脚は三角に開くので、丸い形で囲むと後ろ側が少し余る"},
	"spot": {"x-": 0.21, "why": "脚は +X へ長いが、どちら向きに置いても同じ幅になるよう、柱を中心にした円で囲む"},
	"boomflat": {"x-": 0.22, "x+": 0.22, "y+": 0.16, "z-": 2.20, "why": "寝ている爆炎の板には形を付けない（合図で跳ね上がる飾り）"},
	"carton": {"z+": 0.45, "why": "前のふたの先の小さな紙片が、箱の本体のメッシュに入っていて、ふたを閉じても前に残る（モデルの作り）"},
	"cleaning_cart": {"y+": 0.50, "z-": 0.13, "why": "横に立てかけたモップ（柄と房）には形を付けない"},
	"tomato_monster": {"x-": 0.23, "x+": 0.23, "why": "左右に張り出した細い腕には形を付けない"},
	"scrap_tub": {"y+": 0.15, "why": "蛇口には形を付けない（ふちの上は平らにして、乗れるようにしてある）"},
	"scrap_bridge": {"y+": 0.34, "why": "欄干には形を付けない（欄干の間は人の幅より狭く、付けると橋に乗れなくなる）"},
}

# 点の確認：[種類, 点（物の原点から。表を書いたときの大きさでの座標）, 当たるはずか, 説明]
const POINTS := [
	["scrap_arch", Vector3(0, 1.0, 0), false, "アーチの下は空いている"],
	["scrap_arch", Vector3(0, 1.9, 0), false, "アーチの丸みのすぐ下も空いている"],
	["scrap_arch", Vector3(0.73, 0.7, 0), true, "アーチの柱に当たる"],
	["scrap_arch", Vector3(0, 2.1, 0), true, "アーチのてっぺんに当たる"],
	["window", Vector3(0, 1.2, 0.2), true, "窓の壁（ガラス）に当たる"],
	["window", Vector3(0, 1.2, -0.3), false, "窓の壁の後ろは空いている"],
	["window", Vector3(0.88, 0.05, -0.3), true, "窓の壁の後ろの足に当たる"],
	["flat", Vector3(0, 0.5, 0), true, "書割の板に当たる"],
	["flat", Vector3(0, 0.5, -0.3), false, "書割の後ろ（足の間）は空いている"],
	["scrap_bus", Vector3(0, 0.6, -0.15), false, "バスの書割の後ろは空いている"],
	["standin", Vector3(0, 0.03, -0.35), false, "等身大パネルの足の間は空いている"],
	["standin", Vector3(0.255, 0.03, -0.35), true, "等身大パネルの床の足に当たる"],
	["monitor", Vector3(0, 0.6, -0.1), false, "モニターの支柱の間は空いている"],
	["monitor", Vector3(0.58, 0.6, -0.19), true, "モニターの支柱に当たる"],
	["monitor", Vector3(0, 1.84, 0), true, "モニターの画面に当たる"],
	["witch_cauldron", Vector3(0, 0.05, 0), false, "鍋の脚の間は空いている"],
	["witch_cauldron", Vector3(0.4, 0.6, 0), true, "鍋の胴（ふち近く）に当たる"],
	["tomato_monster", Vector3(0.4, 0.12, 0), false, "トマト怪獣の体の下（足の外）は空いている"],
	["tomato_monster", Vector3(0.4, 0.74, 0), true, "トマト怪獣の丸い体に当たる"],
	["fx", Vector3(0.24, 0.56, 0.2), false, "爆弾の玉の角は空いている"],
	["fx", Vector3(0, 0.37, 0), true, "爆弾の玉に当たる"],
	["camera", Vector3(0.33, 0.9, 0.33), false, "三脚の上のほうの外側は空いている"],
	["camera", Vector3(0, 1.33, 0), true, "カメラに当たる"],
	["scrap_tub", Vector3(0, 0.05, 0), false, "バスタブの足の間は空いている"],
	["scrap_tub", Vector3(0, 0.5, 0), true, "バスタブのふちの面に当たる"],
	["scrap_bridge", Vector3(0, 0.05, 0), false, "太鼓橋の下は空いている"],
	["scrap_bridge", Vector3(0, 0.18, 0), true, "太鼓橋の板に当たる"],
	["scrap_mushroom", Vector3(0.3, 0.4, 0), false, "キノコの傘の下は空いている"],
	["scrap_mushroom", Vector3(0.3, 0.78, 0), true, "キノコの傘に当たる"],
	["scrap_tree", Vector3(0.4, 0.5, 0), false, "木の葉の下は空いている"],
	["scrap_tree", Vector3(0.3, 1.25, -0.1), true, "木の葉に当たる"],
	["scrap_crane", Vector3(0.4, 0.8, 0), false, "クレーンの腕の下は空いている"],
	["scrap_crane", Vector3(0.4, 1.42, -0.03), true, "クレーンの腕に当たる"],
	["scrap_column", Vector3(0.24, 0.9, 0.24), false, "丸い柱の角は空いている"],
	["scrap_cactus", Vector3(0.3, 0.2, 0), false, "サボテンの腕の下は空いている"],
	["scrap_fountain", Vector3(0.45, 0.6, 0), false, "噴水の上の皿のまわりは空いている"],
	["scrap_fan", Vector3(0.4, 1.1, 0), false, "送風機の丸いかごの角は空いている"],
	["rock", Vector3(-0.5, 0.6, 0.05), false, "岩の肩の外は空いている"],
	["balcony", Vector3(0, 0.3, 0), false, "バルコニーの床下（脚の間）は空いている"],
	["balcony", Vector3(0, 1.4, 0.62), true, "バルコニーの手すりに（人は）当たる"],
	["moon", Vector3(0.3, 0.2, 0), false, "月の土台の上は空いている"],
	["partition", Vector3(1.089, 0.9, 0.0), false, "パーテーションの折れ目の外は空いている"],
]

var failed := false


# 確かめるために歩かせる人（体の大きさは player.gd と同じ）
class Walker extends CharacterBody3D:
	func _init() -> void:
		collision_layer = 8
		collision_mask = 1 | 2 | 4
		floor_snap_length = 0.25
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.32
		capsule.height = 1.5
		shape.shape = capsule
		shape.position = Vector3(0, 0.75, 0)
		add_child(shape)

	# 1コマぶん動く。walk＝横の速さ（m/秒）
	func step(walk: Vector3) -> void:
		velocity.x = walk.x
		velocity.z = walk.z
		velocity.y = 0.0 if is_on_floor() else velocity.y - 16.0 / 60.0
		move_and_slide()


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	failed = failed or not ok
	print("COLLIDER_FIT_CHECK ", label, " ", "OK" if ok else "FAIL")


func frames(count: int) -> void:
	for i in count:
		await physics_frame


func run() -> void:
	var fixture := Audit.Fixture.new()
	root.add_child(fixture)
	var stage := Audit.new_stage(fixture)
	# 物が増えても全部が床に載るよう、並べる升目に合わせて床を広げる（10列 × 行数）
	Audit.add_floor(fixture, maxf(600.0, (ceilf(Audit.kinds().size() / 10.0) + 2.0) * SPACING * 1.3))
	var kinds: Array[String] = Audit.kinds()
	var bodies := {}
	var order: Array = []
	for i in kinds.size():
		var body := Audit.make(stage, kinds[i], Vector3((i % 10) * SPACING, 0.0, (i / 10) * SPACING))
		body.set_fixed(true)
		if kinds[i] == "carton":
			# 段ボール箱は、ふたを閉じた姿で比べる（開いたふたは当たらない紙）
			body.set("opened", false)
			body.set("open_amount", 0.0)
			body.call("_apply_lids")
		bodies[kinds[i]] = body
		order.append(body)
	await frames(4)

	# ---- 1) 外形・底・形の数 ----
	for kind: String in kinds:
		var problems := fit_problems(kind, bodies[kind])
		check(problems.is_empty(), "%s の当たり判定は見た目に合っている%s" % [kind, "" if problems.is_empty() else "（" + "／".join(problems) + "）"])
	# 表の書き方の確認
	for kind: String in PropShapes.TABLE:
		var entry: Dictionary = PropShapes.TABLE[kind]
		var sized: bool = Scrap.has_kind(kind) or kind in ["witch_cauldron", "tomato_monster", "dragon_skull"]
		if sized and not entry.has("size"):
			check(false, "%s の表に size が書いてある（大きさを変えても形が付いてくる）" % kind)
		if not bodies.has(kind):
			check(false, "表の %s は、作れる物の種類にある" % kind)

	# 大きさを変えても、形が同じ比率で付いてくる（廃材置き場の物を 1.5倍・0.6倍にして確かめる）
	var resized: Array = []
	for item: Array in [["scrap_arch", 1.5], ["scrap_windmill", 0.6], ["scrap_fountain", 1.5]]:
		var changed: Dictionary = Scrap.find(item[0]).duplicate()
		changed["size"] = float(changed["size"]) * float(item[1])
		var body: RigidBody3D = Audit.MovieProp.new()
		body.call("_build_scrap", changed)
		stage._register(body, Vector3(-SPACING * (resized.size() + 1), 0.0, 0.0), 0.0)
		body.set_fixed(true)
		resized.append([item, body])
	await frames(2)
	for entry: Array in resized:
		var problems := fit_problems(entry[0][0], entry[1])
		check(problems.is_empty(), "%s を %.1f倍にしても、当たり判定が見た目に付いてくる%s" % [entry[0][0], entry[0][1], "" if problems.is_empty() else "（" + "／".join(problems) + "）"])

	# ---- 2) 空いている所・当たる所 ----
	var space := fixture.get_world_3d().direct_space_state
	for row: Array in POINTS:
		var body: RigidBody3D = bodies[row[0]]
		var hit := touches(space, body, (row[1] as Vector3) * Audit.table_scale(row[0]))
		check(hit == bool(row[2]), String(row[3]))

	# ---- 3) 人が通れる・乗れる ----
	var walker := Walker.new()
	fixture.add_child(walker)
	await walk_checks(walker, bodies)
	walker.queue_free()

	# ---- 4) 床に置いて放す ----
	var rows: Array = await Audit.settle(self, order)
	var restless: PackedStringArray = []
	for i in kinds.size():
		var r: Dictionary = rows[i]
		if not r["ok"]:
			restless.append("%s（横%.2fm 高さ%.2f 傾き%.0f度 速さ%.2f）" % [kinds[i], r["moved"], r["height"], r["tilt"], r["speed"]])
	check(restless.is_empty(), "床に置いた %d 種類は、動かず・倒れず・震えない%s" % [kinds.size(), "" if restless.is_empty() else "：" + "、".join(restless)])

	print("COLLIDER_FIT_TEST_FAIL" if failed else "COLLIDER_FIT_TEST_OK")
	fixture.queue_free()
	await process_frame
	quit(1 if failed else 0)


# その物の、外形・底・形の数のずれ（無ければ空）
func fit_problems(kind: String, body: RigidBody3D) -> PackedStringArray:
	var out: PackedStringArray = []
	var r := Audit.measure(body, false)
	var total: int = int(r["count"]) + int(r["thin"]) + int(r["off"])
	if total < 1:
		out.append("当たり判定が無い")
		return out
	if total > MAX_SHAPES:
		out.append("形が%d個（%d個まで）" % [total, MAX_SHAPES])
	var vis: AABB = r["vis"]
	var col: AABB = r["col"]
	if col.position.y < FLOOR_LOW or col.position.y > FLOOR_HIGH:
		out.append("当たり判定の底が床に無い（%.3fm）" % col.position.y)
	if vis.position.y < FLOOR_LOW or vis.position.y > FLOOR_HIGH:
		out.append("見た目の底が床に無い（%.3fm）" % vis.position.y)
	var loose: Dictionary = LOOSE.get(kind, {})
	var lo: Vector3 = r["lo"]
	var hi: Vector3 = r["hi"]
	for axis in 3:
		var axis_name: String = ["x", "y", "z"][axis]
		var allow := maxf(EDGE_MIN, EDGE_RATIO * vis.size[axis])
		for side: Array in [[axis_name + "-", lo[axis]], [axis_name + "+", hi[axis]]]:
			var limit := maxf(allow, float(loose.get(side[0], 0.0)))
			if absf(float(side[1])) > limit:
				out.append("%s の面が %+.2fm（許し %.2fm）" % [side[0], float(side[1]), limit])
	return out


# 物のローカルの点 at に、その物の当たり判定（薄い手すりも含む）があるか
func touches(space: PhysicsDirectSpaceState3D, body: RigidBody3D, at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.02
	query.shape = ball
	query.transform.origin = body.global_transform * at
	query.collision_mask = 2 | 4
	for hit: Dictionary in space.intersect_shape(query):
		var other: Node = hit["collider"]
		if other == body or body.is_ancestor_of(other):
			return true
	return false


# 人をその物の上へ降ろして、立てるか（上の面の高さ top は物の原点から）
func stands_on(walker: Walker, body: RigidBody3D, at: Vector2, top: float) -> bool:
	walker.global_position = body.global_transform * Vector3(at.x, top + 0.25, at.y)
	walker.velocity = Vector3.ZERO
	for i in 45:
		await physics_frame
		walker.step(Vector3.ZERO)
	var height := walker.global_position.y - body.global_position.y
	return walker.is_on_floor() and absf(height - top) < 0.06


# 人を from から、横の速さ walk で count コマ歩かせる。通った高さのいちばん高い所を返す
func walks(walker: Walker, from: Vector3, walk: Vector3, count: int) -> float:
	walker.global_position = from
	walker.velocity = Vector3.ZERO
	var highest := from.y
	for i in count:
		await physics_frame
		walker.step(walk)
		highest = maxf(highest, walker.global_position.y)
	return highest


func walk_checks(walker: Walker, bodies: Dictionary) -> void:
	# アーチ：まん中はくぐれる。柱へ向かうと止まる
	var arch: RigidBody3D = bodies["scrap_arch"]
	await walks(walker, arch.global_position + Vector3(0, 0.05, 1.6), Vector3(0, 0, -3.4), 60)
	check(walker.global_position.z < arch.global_position.z - 1.0, "人がアーチをくぐれる（%.2fm 先まで歩けた）" % (arch.global_position.z + 1.6 - walker.global_position.z))
	await walks(walker, arch.global_position + Vector3(0.73 * Audit.table_scale("scrap_arch"), 0.05, 1.6), Vector3(0, 0, -3.4), 60)
	check(walker.global_position.z > arch.global_position.z + 0.3, "アーチの柱へ向かうと止まる")
	# 太鼓橋：端から上がって、反対側へ渡れる
	var bridge: RigidBody3D = bodies["scrap_bridge"]
	var highest := await walks(walker, bridge.global_position + Vector3(0, 0.05, 1.4), Vector3(0, 0, -2.0), 100)
	check(walker.global_position.z < bridge.global_position.z - 1.0 and highest > bridge.global_position.y + 0.15, "人が太鼓橋を歩いて渡れる（いちばん高い所 %.2fm）" % (highest - bridge.global_position.y))
	# 乗れる物：上の面が平らで、そこに立てる
	check(await stands_on(walker, bodies["riser"], Vector2.ZERO, 0.9), "人が足場（木箱）に乗れる")
	check(await stands_on(walker, bodies["applebox"], Vector2.ZERO, top_of(bodies["applebox"])), "人が箱馬に乗れる")
	check(await stands_on(walker, bodies["carton"], Vector2.ZERO, top_of(bodies["carton"])), "人が、ふたを閉じた段ボール箱に乗れる")
	check(await stands_on(walker, bodies["balcony"], Vector2.ZERO, 0.85), "人がバルコニーに乗れる")
	check(await stands_on(walker, bodies["rock"], Vector2(-0.03, 0.04), top_of(bodies["rock"])), "人が岩のてっぺんに乗れる")
	check(await stands_on(walker, bodies["scrap_tub"], Vector2(0.3, 0.0) * Audit.table_scale("scrap_tub"), top_of(bodies["scrap_tub"])), "人がバスタブのふちに乗れる")
	check(await stands_on(walker, bodies["scrap_toilet"], Vector2(0.0, 0.2) * Audit.table_scale("scrap_toilet"), 0.58 * Audit.table_scale("scrap_toilet")), "人がトイレのふたに乗れる")
	check(await stands_on(walker, bodies["scrap_chest"], Vector2.ZERO, top_of(bodies["scrap_chest"])), "人がお宝の箱に乗れる")
	# バルコニーの手すり：上で前へ歩いても落ちない
	var balcony: RigidBody3D = bodies["balcony"]
	await walks(walker, balcony.global_position + Vector3(0, 0.9, 0), Vector3(0, 0, 2.0), 70)
	check(walker.global_position.y > balcony.global_position.y + 0.8 and walker.global_position.z < balcony.global_position.z + 0.45, "バルコニーの手すりで、人が前へ落ちない")


# 当たり判定のいちばん高い所（物の原点から。無効の形と薄い手すりは除く）
func top_of(body: RigidBody3D) -> float:
	return Audit.shapes_aabb(Audit.shapes(body), false).end.y
