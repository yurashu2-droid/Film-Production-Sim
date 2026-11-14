extends SceneTree
## 接着剤の物理を、小さな試験場で確かめる。本物の Jolt の物を使い、モデル・ゲームの起動・通信は使わない。
## 確かめること：留めた点は支点（離れないが、そのまわりに自由に回る）。2点で蝶番、一直線でない3点でほぼ固まる。
## 重さが違っても暴れない。置き直し（撮り直し・現場への移動）のあとも接着が残る。近くの相手を選ぶ操作。
var failed := false
var game: Fixture
var glue: Node
var next_id := 100

class TestBody extends RigidBody3D:
	var pid := 0
	var absent := false
	var kind := "applebox"
	var label := "試験箱"
	var holder := 0
	var half := Vector3.ONE * 0.3
	var center := Vector3.ZERO

class TestPlayer extends Node3D:
	const REACH := 3.8
	var held := 0
	var peer_id := 1
	var cam: Camera3D

class Fixture extends Node3D:
	enum S { PREP, COUNTDOWN, TAKE }
	var state := S.PREP
	var replaying := false
	var input_locked := false
	var props := {}
	var players := {}
	var me: TestPlayer
	func local_player() -> Node:
		return me
	func ui_blocking() -> bool:
		return input_locked or replaying
	func host_ev(_name: String, _args: Array) -> void:
		pass
	@rpc("authority", "call_local", "reliable")
	func ev(_name: String, _args: Array) -> void:
		pass

func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(2))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	failed = failed or not ok
	print("ADHESIVE_COMPLIANCE_CHECK ", label, " ", "OK" if ok else "FAIL")

func frames(count: int) -> void:
	for i in count: await physics_frame

# 1辺60cmの試験箱。重力は切ってある（使う試験は gravity_scale を 1 にする）。
# solid が false の箱は何にもぶつからない（留め方だけで決まる動きを見るため）
func body(at: Vector3, weight := 1.0, fixed := false, solid := true) -> TestBody:
	var prop := TestBody.new()
	prop.pid = next_id
	next_id += 1
	prop.position = at
	prop.mass = weight
	prop.gravity_scale = 0.0
	prop.freeze = fixed
	prop.can_sleep = false
	prop.linear_damp = 0.0
	prop.angular_damp = 0.0
	if not solid:
		prop.collision_layer = 0
		prop.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = prop.half * 2.0
	shape.shape = box
	prop.add_child(shape)
	game.add_child(prop)
	game.props[prop.pid] = prop
	return prop

# それぞれの物の上の点（その物から見た位置）どうしを留める
func bond(a: TestBody, b: TestBody, pa: Vector3, pb: Vector3) -> Dictionary:
	glue.pairs.append({"a":a.pid,"b":b.pid,"pa":pa,"pb":pb,"joined":true})
	glue.rebuild()
	return glue.pairs.back()

# 試験場の中の1点（at）で、2つの物を留める
func pin(a: TestBody, b: TestBody, at: Vector3) -> Dictionary:
	return bond(a,b,a.to_local(at),b.to_local(at))

func gap(pair: Dictionary) -> float:
	return game.props[pair.a].to_global(pair.pa).distance_to(game.props[pair.b].to_global(pair.pb))

func worst_gap() -> float:
	var worst := 0.0
	for pair: Dictionary in glue.pairs:
		if pair.joined: worst = maxf(worst,gap(pair))
	return worst

# from の向きから、どれだけ回ったか（度）
func turned(prop: Node3D, from: Basis) -> float:
	return rad_to_deg(Quaternion(prop.global_basis.orthonormalized()).angle_to(Quaternion(from.orthonormalized())))

func clear_bodies() -> void:
	glue.clear()
	if game.me != null: game.me.held = 0
	glue.tool = null
	for prop: Node in game.props.values():
		prop.get_parent().remove_child(prop)
		prop.queue_free()
	game.props.clear()
	await frames(2)

# 留め方の試験に使う1組：固めた箱 a と、その右隣（面と面が付く位置）の動く箱 b。
# spots は、2つの箱が付く面のまん中から見た、留める点の位置。2つの箱はぶつからない
func side_pair(at: Vector3, weight: float, spots: Array) -> Dictionary:
	var a := body(at,12.0,true,false)
	var b := body(at+Vector3(0.6,0,0),weight,false,false)
	return {"a":a,"b":b,"face":at+Vector3(0.3,0,0),"spots":spots,"weight":weight,"pairs":[],"peak":0.0,"gap":0.0,"start_spin":0.0}

func join(sets: Array) -> void:
	await frames(2)
	for one: Dictionary in sets:
		for spot: Vector3 in one.spots:
			one.pairs.append(pin(one.a,one.b,one.face+spot))
		one["from"] = (one.b as Node3D).global_basis

# 回す力を一瞬だけ加える。重さに合わせるので、どの重さでも同じ速さで回り始める
func twist(one: Dictionary, axis: Vector3) -> void:
	(one.b as RigidBody3D).apply_torque_impulse(axis*0.3*float(one.weight))

# count コマ進めながら、組ごとに「いちばん回った角度」「留めた点がいちばん離れた距離」「回り始めの速さ」を覚える
func watch(sets: Array, count: int) -> void:
	for one: Dictionary in sets:
		one.peak = 0.0
		one.gap = 0.0
	for i in count:
		await frames(1)
		for one: Dictionary in sets:
			if i==0: one.start_spin = (one.b as RigidBody3D).angular_velocity.length()
			one.peak = maxf(one.peak,turned(one.b,one.from))
			for pair: Dictionary in one.pairs: one.gap = maxf(one.gap,gap(pair))

# 1点だけ留めた物は、その点のまわりに、どの向きにも大きく回れる。留めた時の向きへは戻らない
func pivot() -> void:
	var axes := [Vector3.RIGHT,Vector3.UP,Vector3.BACK]
	var weights := [1.0,12.0,24.0]
	var sets: Array = []
	for i in 3: sets.append(side_pair(Vector3(i*3.0,5,0),weights[i],[Vector3.ZERO]))
	await join(sets)
	for i in 3: twist(sets[i],axes[i])
	await watch(sets,120)
	for i in 3:
		var one: Dictionary = sets[i]
		var spin: float = (one.b as RigidBody3D).angular_velocity.length()
		print("ADHESIVE_COMPLIANCE_METRIC pivot axis=",axes[i]," mass=",weights[i]," peak_deg=",one.peak," end_deg=",turned(one.b,one.from)," max_gap_m=",one.gap," start_spin=",one.start_spin," end_spin=",spin)
		check(one.start_spin>1.0 and one.peak>30.0,"1点留め：点のまわりに大きく回れる")
		check(turned(one.b,one.from)>20.0,"1点留め：留めた時の向きへ戻そうとしない")
		check(one.gap<0.01,"1点留め：回っても、留めた点は離れない")
		check(spin<float(one.start_spin)*0.25,"1点留め：回る勢いは、2秒で4分の1より小さくなる")
	await clear_bodies()

# 離れた2点を留めると、2点を結ぶ線を軸にした蝶番になる。軸のまわりには回るが、ほかの向きには回らない
func hinge() -> void:
	var line := [Vector3(0,0,0.25),Vector3(0,0,-0.25)]
	var axes := [Vector3.BACK,Vector3.RIGHT,Vector3.UP]
	var sets: Array = []
	for i in 3: sets.append(side_pair(Vector3(i*3.0,5,0),1.0 if i==0 else 12.0,line))
	await join(sets)
	for i in 3: twist(sets[i],axes[i])
	await watch(sets,120)
	var swing: Dictionary = sets[0]
	var lean := rad_to_deg((swing.b as Node3D).global_basis.z.angle_to(Vector3.BACK))
	print("ADHESIVE_COMPLIANCE_METRIC hinge along_deg=",swing.peak," axis_lean_deg=",lean," across_deg=",[sets[1].peak,sets[2].peak]," max_gap_m=",[sets[0].gap,sets[1].gap,sets[2].gap])
	check(swing.peak>20.0,"2点留め：2点を結ぶ線のまわりには回れる")
	check(lean<2.0,"2点留め：回る軸は、2点を結ぶ線のまま")
	check(sets[1].peak<2.0 and sets[2].peak<2.0,"2点留め：ほかの向きには回らない")
	check(sets.all(func(one): return one.gap<0.01),"2点留め：どちらの点も離れない")
	await clear_bodies()

# 一直線でない3点を留めると、ほぼ固まる。一直線に並べた3点は、蝶番のまま。
# 3点でも、すぐ近くにまとめて打つと重さで垂れる（離して留めるほど、しっかりする）
func rigid() -> void:
	var triangle := [Vector3(0,0.25,0),Vector3(0,-0.25,0.25),Vector3(0,-0.25,-0.25)]
	var axes := [Vector3.RIGHT,Vector3.UP,Vector3.BACK]
	var weights := [1.0,12.0,24.0]
	var sets: Array = []
	for i in 3: sets.append(side_pair(Vector3(i*3.0,5,0),weights[i],triangle))
	var row: Dictionary = side_pair(Vector3(9,5,0),5.0,[Vector3(0,0,0.25),Vector3.ZERO,Vector3(0,0,-0.25)])
	sets.append(row)
	# 2cmほどの間隔にまとめた3点
	var tight: Dictionary = side_pair(Vector3(12,5,0),12.0,[Vector3(0,0.01,0),Vector3(0,-0.01,0.01),Vector3(0,-0.01,-0.01)])
	sets.append(tight)
	await join(sets)
	# 持つ処理は、固く留まった相手だけを「いっしょに動かす仲間」にする
	check(glue.rigid_ids((sets[0].b as TestBody).pid).size()==2,"離れた3点で留めた相手は、固く留まった仲間に数える")
	check(glue.rigid_ids((row.b as TestBody).pid).size()==1 and glue.rigid_ids((tight.b as TestBody).pid).size()==1,"一直線の3点・すぐ近くの3点で留めた相手は、固く留まった仲間に数えない")
	for i in 3: twist(sets[i],axes[i])
	twist(row,Vector3.BACK)
	await watch(sets,60)
	print("ADHESIVE_COMPLIANCE_METRIC rigid twist_deg=",[sets[0].peak,sets[1].peak,sets[2].peak]," max_gap_m=",[sets[0].gap,sets[1].gap,sets[2].gap]," row_deg=",row.peak)
	check(sets[0].peak<2.0 and sets[1].peak<2.0 and sets[2].peak<2.0,"3点留め：どの向きに回そうとしても、ほとんど動かない")
	check(row.peak>10.0,"一直線に並べた3点：その線のまわりには、まだ回る")
	# 横へ突き出した形のまま、重さがかかっても垂れない
	var before: Array = []
	for i in 3:
		before.append((sets[i].b as Node3D).global_position)
		(sets[i].b as RigidBody3D).gravity_scale = 1.0
	(tight.b as RigidBody3D).gravity_scale = 1.0
	sets.erase(row)
	await watch(sets,90)
	sets.erase(tight)
	var sag := 0.0
	for i in 3: sag = maxf(sag,(sets[i].b as Node3D).global_position.distance_to(before[i]))
	print("ADHESIVE_COMPLIANCE_METRIC rigid_weight turn_deg=",[sets[0].peak,sets[1].peak,sets[2].peak]," sag_m=",sag," max_gap_m=",[sets[0].gap,sets[1].gap,sets[2].gap]," tight_deg=",tight.peak," tight_gap_m=",tight.gap)
	check(sets.all(func(one): return one.peak<2.0) and sag<0.01,"3点留め：重さがかかっても垂れない")
	check(sets.all(func(one): return one.gap<0.01),"3点留め：どの点も離れない")
	check(tight.peak>3.0 and tight.gap<0.02,"すぐ近くにまとめた3点：重さで垂れる（離して留めるほど、しっかりする）")
	await clear_bodies()

# 留めた2つの物も、点以外の所ではふつうにぶつかる。面と面が付いた箱は、面のまん中の1点だけでも、面がつっかえて垂れない。
# ぶつからない箱を同じ形で留めると、点のまわりに回って垂れる（つっかえていたのは接着ではなく、箱どうしの当たり）
func contact() -> void:
	var sets: Array = []
	for solid: bool in [true,false]:
		var a := body(Vector3(0.0 if solid else 4.0,5,0),12.0,true,solid)
		var b := body(a.position+Vector3(0.601,0,0),5.0,false,solid)
		b.gravity_scale = 1.0
		sets.append({"a":a,"b":b,"peak":0.0,"gap":0.0})
	await frames(2)
	for one: Dictionary in sets:
		one["pair"] = pin(one.a,one.b,(one.a as Node3D).global_position+Vector3(0.3,0,0))
		one["from"] = (one.b as Node3D).global_basis
	for i in 90:
		await frames(1)
		for one: Dictionary in sets:
			one.peak = maxf(one.peak,turned(one.b,one.from))
			one.gap = maxf(one.gap,gap(one.pair))
	print("ADHESIVE_COMPLIANCE_METRIC contact solid_deg=",sets[0].peak," ghost_deg=",sets[1].peak," max_gap_m=",[sets[0].gap,sets[1].gap])
	check(sets[0].peak<5.0,"留めた物どうしもぶつかる：面と面が付いていれば、まん中の1点でも垂れない")
	check(sets[1].peak>45.0,"ぶつからない箱を同じ形で留めると、点のまわりに回って垂れる")
	check(sets[0].gap<0.01 and sets[1].gap<0.01,"どちらの場合も、留めた点は離れない")
	await clear_bodies()

# 重力の下で1点留めの物は、点からぶら下がって揺れ、ゆっくり落ち着く。2つの箱は、点以外の所ではふつうにぶつかる。
# そのあと、撮り直しのように元の場所へ戻しても、同じ点で留まったまま
func hang() -> void:
	var a := body(Vector3(0,5,0),12.0,true)
	var b := body(Vector3(0.6,4.4,0),5.0)
	b.gravity_scale = 1.0
	await frames(2)
	# 固めた箱の右下の辺と、動く箱の左上の辺が重なっている。その辺のまん中を留める
	var point := Vector3(0.3,4.7,0)
	var pair := pin(a,b,point)
	var start := b.global_transform
	var peak := 0.0
	var max_gap := 0.0
	var speed := 0.0
	var early_spin := 0.0
	for i in 300:
		await frames(1)
		peak = maxf(peak,turned(b,start.basis))
		max_gap = maxf(max_gap,gap(pair))
		speed = maxf(speed,b.linear_velocity.length())
		if i==20: early_spin = b.angular_velocity.length()
	var below: Vector3 = b.global_position-point
	print("ADHESIVE_COMPLIANCE_METRIC hang peak_deg=",peak," end_deg=",turned(b,start.basis)," below=",below," max_gap_m=",max_gap," peak_speed=",speed," early_spin=",early_spin," end_spin=",b.angular_velocity.length())
	check(early_spin>0.5,"ぶら下げ：留めた点を支点に、すぐ回り始める")
	check(peak>50.0,"ぶら下げ：行き過ぎて揺れるほど、自由に回る")
	check(Vector2(below.x,below.z).length()<0.06 and below.y<-0.35,"ぶら下げ：最後は、重心が留めた点の真下に来る")
	check(b.angular_velocity.length()<0.3,"ぶら下げ：揺れは、ゆっくり落ち着く")
	check(max_gap<0.02 and speed<4.0 and b.global_position.is_finite(),"ぶら下げ：点は離れず、暴れない")
	var old_joint: Node = glue.joints[0]
	glue.mark(1,a.pid,Vector3(0,0.3,0))
	check(glue.joints[0]==old_joint,"別の点を付けても、いまの留め具は作り直さない")
	var saved: Dictionary = glue.snapshot()
	b.global_transform = start
	b.linear_velocity = Vector3.ZERO
	b.angular_velocity = Vector3.ZERO
	glue.restore(saved)
	check(glue.joints.size()==1 and glue.connected_to(a.pid,b.pid) and glue.first.size()==1,"撮り直し：戻したあとも接着が残る")
	check(glue.pairs[0].pa==saved.pairs[0].pa and glue.pairs[0].pb==saved.pairs[0].pb,"撮り直し：留めた点は、物の上の同じ位置のまま")
	peak = 0.0
	max_gap = 0.0
	for i in 90:
		await frames(1)
		peak = maxf(peak,turned(b,start.basis))
		max_gap = maxf(max_gap,gap(glue.pairs[0]))
	print("ADHESIVE_COMPLIANCE_METRIC hang_again peak_deg=",peak," max_gap_m=",max_gap)
	check(peak>30.0 and max_gap<0.02,"撮り直し：戻した場所から、また同じ点でぶら下がる")
	await clear_bodies()

# 動く物どうしを留める。重さが大きく違っても、留める点が少し離れていても、物が重なっていても、暴れない
func mixed() -> void:
	var ground := StaticBody3D.new()
	var slab := CollisionShape3D.new()
	var slab_box := BoxShape3D.new()
	slab_box.size = Vector3(60,1,20)
	slab.shape = slab_box
	ground.position = Vector3(0,-0.5,0)
	ground.add_child(slab)
	game.add_child(ground)
	# [左の箱の重さ, 右の箱の重さ, 面と面のすき間（マイナスは重なり）]
	var setups := [[1.0,24.0,0.001],[24.0,1.0,0.001],[5.0,5.0,0.08],[5.0,12.0,-0.06]]
	var sets: Array = []
	for i in setups.size():
		var a := body(Vector3(i*4.0,0.3,0),setups[i][0])
		var b := body(Vector3(i*4.0+0.6+float(setups[i][2]),0.3,0),setups[i][1])
		a.gravity_scale = 1.0
		b.gravity_scale = 1.0
		sets.append({"a":a,"b":b})
	await frames(20)
	# それぞれの箱の、向かい合う面の上寄りの点どうしを留める（すき間や重なりの分だけ、点どうしもずれている）
	for one: Dictionary in sets:
		glue.pairs.append({"a":one.a.pid,"b":one.b.pid,"pa":Vector3(0.3,0.2,0),"pb":Vector3(-0.3,0.2,0),"joined":true})
	glue.rebuild()
	var speed := 0.0
	for i in 60:
		await frames(1)
		for prop: RigidBody3D in game.props.values(): speed = maxf(speed,prop.linear_velocity.length())
	print("ADHESIVE_COMPLIANCE_METRIC mixed_join peak_speed=",speed," gap_m=",worst_gap())
	check(speed<1.5,"留めた瞬間：物を置き直さず、弾き飛ばさない")
	check(worst_gap()<0.01,"留めた点が少し離れていても重なっていても、物理が点どうしを寄せる")
	# 右の箱を上へ打ち上げる（相手ごと持ち上がって、落ちる）
	for one: Dictionary in sets:
		(one.b as RigidBody3D).apply_central_impulse(Vector3(0,4.0*(one.b as RigidBody3D).mass,0))
	speed = 0.0
	var max_gap := 0.0
	for i in 180:
		await frames(1)
		max_gap = maxf(max_gap,worst_gap())
		for prop: RigidBody3D in game.props.values(): speed = maxf(speed,prop.linear_velocity.length())
	var rest_speed := 0.0
	var finite := true
	for prop: RigidBody3D in game.props.values():
		rest_speed = maxf(rest_speed,prop.linear_velocity.length())
		finite = finite and prop.global_position.is_finite() and prop.global_position.y>0.0 and prop.global_position.y<3.0
	print("ADHESIVE_COMPLIANCE_METRIC mixed_kick max_gap_m=",max_gap," peak_speed=",speed," end_gap_m=",worst_gap()," end_speed=",rest_speed)
	check(max_gap<0.03 and worst_gap()<0.01,"重さの違う物どうし：打ち上げても、留めた点は離れない")
	check(speed<6.0 and rest_speed<0.2 and finite,"重さの違う物どうし：暴れずに落ち着く")
	ground.queue_free()
	await clear_bodies()

func components() -> void:
	var a := body(Vector3(0,5,0),12.0)
	var b := body(Vector3(0.6,5,0))
	var c := body(Vector3(1.2,5,0))
	var d := body(Vector3(0.6,5,0.6))
	await frames(2)
	bond(a,b,Vector3(0.3,0,0),Vector3(-0.3,0,0))
	bond(b,c,Vector3(0.3,0,0),Vector3(-0.3,0,0))
	bond(b,d,Vector3(0,0,0.3),Vector3(0,0,-0.3))
	check(glue.connected_ids(c.pid).size()==4 and glue.connected_to(c.pid,d.pid),"枝分かれしてつながった物を、ぜんぶ1回ずつ数える")
	var hung: Array = glue.hanging_groups([a.pid])
	check(glue.rigid_ids(a.pid).size()==1,"1点ずつ留めただけでは、固く留まった仲間はいない")
	check(hung.size()==1 and hung[0].bodies.size()==3 and hung[0].points.size()==1 and hung[0].points[0][0]==a.pid and (hung[0].points[0][1] as Vector3).is_equal_approx(Vector3(0.3,0,0)),"点で留めた先の物を、その点からぶら下がるまとまりとして数える")
	c.apply_central_impulse(Vector3(2,1,0))
	d.apply_torque_impulse(Vector3(0,0,0.08))
	var max_gap := 0.0
	for i in 60:
		await frames(1)
		max_gap = maxf(max_gap,worst_gap())
	check(max_gap<0.015,"つながった物が動いても、3か所の留めた点は離れない")
	var metrics: Array = glue.bond_metrics()
	check(metrics.size()==3 and metrics.all(func(m): return m.gap<0.015),"bond_metrics が、留めてある組ごとの離れぐあいを返す")
	var old_joint: Node = glue.joints[0]
	glue.mark(1,a.pid,Vector3(0.3,0,0.2))
	glue.mark(1,b.pid,Vector3(-0.3,0,0.2))
	glue._physics_process(0.0)
	await frames(60)
	check(glue.joints.size()==4 and glue.joints[0]==old_joint,"同じ2つの物にもう1点留めても、前の留め具は作り直さない")
	check(worst_gap()<0.015,"何点留めても、それぞれの点は離れない")
	var saved: Dictionary = glue.snapshot()
	var transfer := Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(4,0,3))
	for prop: TestBody in [a,b,c,d]:
		prop.global_transform = transfer * prop.global_transform
		prop.linear_velocity = Vector3.ZERO
		prop.angular_velocity = Vector3.ZERO
	glue.rebuild()
	await frames(60)
	check(glue.pairs[0].pa==saved.pairs[0].pa and glue.pairs[0].pb==saved.pairs[0].pb,"まとめて別の場所へ移しても、留めた点は物の上の同じ位置のまま")
	check(worst_gap()<0.015,"移した先でも、どの点も離れない")
	glue.drop_joints()
	check(glue.joints.is_empty() and glue.pairs.size()==4,"見返しの間は留め具だけ外し、接着の内容は残す")
	glue.restore(saved)
	check(glue.joints.size()==4,"覚えた内容から、留め具を作り直せる")
	d.absent = true
	check(glue.connected_ids(a.pid).size()==3 and not glue.connected_to(a.pid,d.pid),"現場に無い物は、つながりに数えない")
	hung = glue.hanging_groups([a.pid])
	check(hung.size()==1 and hung[0].bodies.size()==2 and hung[0].points.size()==2,"現場に無い物は、ぶら下がりにも数えない")
	a.freeze = true
	check(glue.hanging_groups([c.pid]).is_empty(),"固めてある物につながる先は、ぶら下がりに数えない")
	await clear_bodies()

func assistance() -> void:
	check(glue.has_method("nearby_candidates"),"近くの表面から相手の候補を出せる")
	check(glue.has_method("h_assisted_mark"),"候補を選ぶクリックは、ホストが確かめてから留める")
	if not glue.has_method("nearby_candidates") or not glue.has_method("h_assisted_mark"): return
	game.me = TestPlayer.new()
	game.me.position = Vector3(0.28,4,2)
	game.add_child(game.me)
	game.players[1] = game.me
	game.me.cam = Camera3D.new()
	game.me.cam.position = Vector3.UP
	game.me.add_child(game.me.cam)
	var tool := body(Vector3(10,5,0),0.5,true)
	tool.kind = "glue"
	tool.holder = 1
	glue.tool = tool
	game.me.held = tool.pid
	var a := body(Vector3(0,5,0),1.0,true)
	var b := body(Vector3(0.65,5,0),12.0,true)
	await frames(2)
	var choices: Array = glue.nearby_candidates(a.pid,Vector3(0.3,0,0.3))
	check(choices.size()==1 and choices[0].b==b.pid and choices[0].gap<0.12,"近くの表面から、相手を1つだけ選ぶ")
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	check(not glue.handle_input(left) and glue.pairs.is_empty(),"左クリックでは留めない（置く操作のまま）")
	# 持っている間は、F を押すだけで塗る
	var click := InputEventAction.new()
	click.action = "operate"
	click.pressed = true
	check(glue.handle_input(click),"F を押すと、接着剤が受け取る")
	await frames(2)
	check(glue.pairs.size()==1 and glue.pairs[0].a==a.pid and glue.pairs[0].b==b.pid and glue.pairs[0].joined,"F を1回押すと、表示していた近くの相手と留まる")
	var count: int = glue.pairs.size()
	glue.handle_input(click)
	check(glue.pairs.size()==count,"同じ所でもう一度押しても、接着は増えない")
	glue.clear()
	var c := body(Vector3(0.65,5,0.62),12.0,true)
	await frames(2)
	choices = glue.nearby_candidates(a.pid,Vector3(0.3,0,0.3))
	check(choices.size()==2,"近くに2つあれば、別々の候補として出す")
	glue.applying = true
	glue.handle_input(click)
	check(glue.pairs.is_empty() and glue.first.has(1),"相手が決まらないときは、1点目を付けるだけ")
	game.me.cam.position = Vector3(0.37,1,-4)
	game.me.cam.rotation.y = PI
	glue.handle_input(click)
	check(glue.pairs.size()==1 and glue.pairs[0].b==b.pid,"2回目に狙った物が相手になる")
	glue.clear()
	c.absent = true
	check(glue.nearby_candidates(a.pid,Vector3(0.3,0,0.3)).size()==1,"現場に無い物は候補にしない")
	b.global_position.x = 0.721
	await frames(2)
	choices = glue.nearby_candidates(a.pid,Vector3(0.3,0,0))
	check(choices.size()==1 and choices[0].gap>0.12 and choices[0].gap<0.18,"12cm より離れた相手も、18cm までは候補に出す")
	game.me.cam.position = Vector3(0,1,0)
	# 印が2つ出ていれば、F で動かせる方を引き寄せて、点どうしを重ねてから留める
	b.freeze = false
	glue.h_assisted_mark(Vector3(0.28,5,2),Vector3.FORWARD,a.pid,b.pid)
	check(glue.pairs.size()==1 and not glue.pairs[0].joined,"F を押すと、離れた相手を引き寄せ始める")
	await frames(60)
	if glue.pairs.size()==1:
		var pulled: Dictionary = glue.pairs[0]
		var apart: float = a.to_global(pulled.pa).distance_to(b.to_global(pulled.pb))
		check(pulled.joined and apart<0.02,"動かせる方が寄ってきて、点どうしが重なってから留まる（残り %.3f m）" % apart)
	glue.clear()
	b.freeze = true
	b.linear_velocity = Vector3.ZERO
	b.global_rotation = Vector3.ZERO
	b.global_position = Vector3(0.65,5,0)
	await frames(2)
	glue.h_assisted_mark(Vector3(0.28,5,2),Vector3.FORWARD,a.pid,c.pid)
	check(glue.pairs.is_empty(),"選んだ相手がいなくなっても、近くの別の物には留めない")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.01,0.5,0.5)
	shape.shape = box
	wall.position = Vector3(0.325,5,0)
	wall.add_child(shape)
	game.add_child(wall)
	await frames(2)
	check(glue.nearby_candidates(a.pid,Vector3(0.3,0,0)).is_empty(),"間に壁があれば、候補にしない")
	wall.queue_free()
	await clear_bodies()
	game.me.queue_free()
	game.me = null
	game.players.clear()

func run() -> void:
	if not InputMap.has_action("operate"): InputMap.add_action("operate")
	game = Fixture.new()
	root.add_child(game)
	glue = load("res://scripts/adhesive.gd").new()
	glue.game = game
	game.add_child(glue)
	await pivot()
	await hinge()
	await rigid()
	await contact()
	await hang()
	await mixed()
	await components()
	await assistance()
	var network_script: GDScript = load("res://tests/adhesive_net_test.gd")
	check(network_script.can_instantiate(),"二人通信の試験のスクリプトが読み込める（通信は開かない）")
	print("ADHESIVE_COMPLIANCE_TEST_FAIL" if failed else "ADHESIVE_COMPLIANCE_TEST_OK")
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
