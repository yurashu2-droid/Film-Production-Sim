extends SceneTree
## 見た目だけだったMAP実体と、意図して残す空間を物理ワールドで確認する。
const Office := preload("res://scripts/production_office.gd")
const Yard := preload("res://scripts/production_yard.gd")
const Look := preload("res://scripts/production_look.gd")
const Extras := preload("res://scripts/features/map_street_details.gd")
var map: Node3D
var failed := false

class Walker extends CharacterBody3D:
	func _init() -> void:
		collision_layer = 2
		collision_mask = 1
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = .28
		cap.height = 1.6
		cs.shape = cap
		cs.position.y = .8
		add_child(cs)

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print("MAP_SCENERY_CHECK ",label," ","OK" if ok else "FAIL")
	failed = failed or not ok

func occupied(at: Vector3, radius: float = .035) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = radius
	q.shape = ball
	q.transform.origin = at
	q.collision_mask = 1
	q.margin = .001
	return not map.get_world_3d().direct_space_state.intersect_shape(q,8).is_empty()

func walk(at: Vector3, velocity: Vector3, frames: int) -> Vector3:
	var actor := Walker.new()
	map.add_child(actor)
	actor.position = at
	for i in frames:
		await physics_frame
		actor.velocity.x = velocity.x
		actor.velocity.z = velocity.z
		actor.velocity.y -= 20.0/60.0
		actor.move_and_slide()
	var result := actor.position
	actor.free()
	return result

func run() -> void:
	map = Node3D.new()
	root.add_child(map)
	Office.build(map,Look.font())
	Yard.build(map)
	Extras.build(map)
	# 電柱は単独でも確かめ、隣接する敷地の見えない壁を誤検出しない。
	var pole := Look.Batch.new()
	var mat := Look.plain(Color.GRAY)
	Yard._pole_line(pole,[Vector3.ZERO],mat,mat,mat)
	pole.build(map,"IsolatedPole")
	for i in 4:await physics_frame
	for pair: Array in [[Vector3(57.5,.42,-5.2),"ドラム缶"],
			[Vector3(81.5,.45,-4.3),"ゴミ箱"],[Vector3(64.4,.8,8.6),"木の幹"],
			[Vector3(64,.7,6.4),"街灯の柱"],[Vector3(72,.6,49),"道沿いの電柱"],
			[Vector3(41.9,1,36.4),"閉じた区の門"],[Vector3(66.4,.85,8),"追加の郵便ポスト"],
			[Vector3(45.67,1.39,33.45),"清掃車の運転席"],[Vector3(48.25,1.45,33.45),"清掃車の荷箱"]]:
		check(occupied(pair[0]),pair[1]+"に当たる")
	check(occupied(Vector3(72,3,4)),"切り欠き用の社屋の書割にも体は当たる")
	check(occupied(Vector3(0,.8,0)),"電柱の幹が単独で当たる")
	check(not occupied(Vector3(.45,.8,0)),"電柱の横の空間は空いている")
	check(not occupied(Vector3(47.9,.2,33.45)),"清掃車の車体下を塞がない")
	check(not occupied(Vector3(50.7,1.35,33.45)),"清掃車の投入口を大きな箱で塞がない")
	check(not occupied(Vector3(66.7,.20,8)),"郵便ポストの細い支柱の横は空く")
	check(not occupied(Vector3(40.2,1.1,-9.5)),"車庫の柱の間を空ける")
	var blocked := await walk(Vector3(55.7,.02,-5.2),Vector3(2.5,0,0),100)
	check(blocked.x < 57.15,"人がドラム缶を素通りしない")
	var breach := await walk(Vector3(64.6,.03,15.5),Vector3(-2.5,0,0),65)
	check(breach.x < 62.4 and breach.y > -.1,"フェンスの破れ目から荷運びの通路を通れる")
	var entry := await walk(Vector3(72,.03,7),Vector3(0,0,-2.5),100)
	check(entry.z < 3.5 and entry.y > -.1,"会社の入口を歩いて通れる")
	# 粗大ごみ置き場：会社の側には入口が無く、金網をペンチで切った穴だけ。本当の門（鎖と南京錠）は南の区道の側
	var yard: Node3D = map.find_child("ScrapYard",true,false)
	var hole: Vector3 = Yard.gate_point()
	check(hole.x > 60.5 and hole.z > 13.3 and hole.z < 15.7,"出入り口は会社の側の金網の穴の前")
	var shut := await walk(hole + Vector3(.6,.03,0),Vector3(-2.5,0,0),60)
	check(shut.x > 60.1,"穴をふさいでいる間は、ヤードへ入れない")
	Yard.set_gate(yard,1.0)
	for i in 3:await physics_frame
	var through := await walk(hole + Vector3(.6,.03,0),Vector3(-2.5,0,0),80)
	check(through.x < 59.0 and through.y > -.1,"めくった金網の穴から、人がヤードへ入れる")
	var old_gate := await walk(Vector3(61.4,.03,18.0),Vector3(-2.5,0,0),60)
	check(old_gate.x > 60.1,"前の門の場所（会社の側）は金網でふさがっている")
	check(yard.get_node("HoleTies").visible == false and yard.get_node("HolePliers").visible,"開いている間は、留めた針金が外れてペンチが転がっている")
	Yard.set_gate(yard,0.0)
	check(yard.get_node("HoleTies").visible and not yard.get_node("HolePliers").visible,"閉じると、網を戻して針金で留める")
	var south := await walk(Vector3(42,.03,32.4),Vector3(0,0,-2.5),70)
	check(south.z > 31.1,"南の区の門は閉まっていて通れない")
	check(occupied(Vector3(38.55,1.5,31.4)),"防犯カメラの柱に当たる（カメラは柱に付いている）")
	var lock := yard.get_node("DumpLockShut") as Node3D
	var lock_box := AABB()
	for mi: MeshInstance3D in lock.find_children("*","MeshInstance3D",true,false):
		lock_box = mi.global_transform * mi.get_aabb()
	check(absf(lock_box.get_center().x - 42.0) < .4 and lock_box.get_center().z > 31.0 and lock_box.get_center().z < 31.6,"鎖と南京錠は、南の門の扉の合わせ目（外側）にある")
	check(map.find_children("*","Label3D",true,false).all(func(l: Node) -> bool: return l.name == "CompanyNameSign"),"町に置いた文字は、社名の看板（スプレーで書く）だけ")
	print("MAP_SCENERY_TEST_FAIL" if failed else "MAP_SCENERY_TEST_OK")
	quit(1 if failed else 0)
