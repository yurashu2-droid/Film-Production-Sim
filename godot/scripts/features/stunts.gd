extends Node
## スタントの土台：硬い所に強くぶつかると、少しのあいだ「のびる」。やわらかい物は受け止める。
## （2026-11-10 ユーザー：アクション映画の要素を撮影のときにもっと出したい。スタントが入ると、撮るのが難しい依頼になる）
##   ・速さ 9.5 m/秒より強く、床・壁にぶつかると、のびる（落ちる高さで、およそ 2.8m から。跳ぶ・低い段差では起きない）
##     漫画の理屈：ぺちゃんこになって（床なら床に、壁なら壁に貼りつく）、頭の上を星が回り、数秒で、ぽんと戻る。けがはしない。体力の数字は無い
##   ・のびている間は、歩けない・跳べない・物を持てない（持っていた物は落とす）。見回すことはできる
##   ・やわらかい物（段ボール箱・ゴミ袋・ブルーシートの包み・ソファ・ベッド）が体のそばにあると、受け止める。
##     物ごとに「受け止められる速さ」があり、足した分だけ、ぶつかった速さから引く。足りなければ、のびる（箱が足りない・ずれている）
##     受け止めた物は、はじかれて散らばる（積み直すのが、裏方の仕事）
##   ・スロー光線を浴びている人は、ゆっくり降りるので、その分だけ弱くぶつかる
##   ・準備中も本番中も同じ。見返しにも載る。失格にはしない（のびた姿が映るだけ）
##   ・星は制作班にだけ見える（映画には映らない）。ぺちゃんこの体と土ぼこりは、映る
## 自分がぶつかったかどうかは、自分の画面で測り（player.gd の impact）、ホストが、そばのやわらかい物を数えて決める。
## 確認は tests/stunts_test.gd。説明は docs/production/stunts.md
const Dust := preload("res://scripts/toon_dust.gd")
const Stars := preload("res://vfx/vfx_dizzy_stars.gd")

const KO_SPEED := 9.5            # これ以上の速さで硬い所にぶつかると、のびる（m/秒）
const DOWN_MIN := 2.4            # のびる時間（秒）：しきい値ちょうど
const DOWN_PER := 0.3            # 　〃　　　　　　：1 m/秒 強いごとに延びる分
const DOWN_MAX := 5.0            # 　〃　　　　　　：上限
# やわらかい物：種類 → 受け止められる速さ（m/秒）。そばにある分を足す
const SOFT := {
	"carton": 3.0, "trashbag": 3.5, "tarpbundle": 5.0,
	"scrap_wing_armchair": 5.0, "scrap_two_seat_sofa": 6.5, "scrap_single_bed": 7.5, "scrap_hospital_bed": 7.5,
}
const CATCH_PAD := 0.3           # 物の外形から、これだけ離れていても受け止める（m）
const BODY_TALL := 1.6           # 体の高さ（足元からこの高さまでの、どこかがそばにあればよい）
const FLAT := Vector3(1.45, 0.12, 1.45)       # 床でぺちゃんこ（actor.gd の、大岩につぶされた形と同じ）
const WALL_FLAT := Vector3(1.35, 1.0, 0.14)   # 壁でぺちゃんこ（壁に背中を付けて、うすく広がる）
const POP_SEC := 0.3             # 終わりの、ぽんと戻る時間
const WOBBLE_SEC := 0.45         # 受け止めた物が、ぽよんと揺れる時間
const CREW_LAYER := 1 << 11      # 映画に映らない層（film_camera.gd と同じ番号）
const HINTS := 2                 # 「やわらかい物の上なら平気」を知らせる回数（はじめの数回だけ）

var game: Node
var downs := {}                  # のびている人：参加者の番号 → {t, len, wall, stars}
var _wobble := {}                # 揺れている物：物のID → [残り秒, 元の大きさ]
var _last := Vector3.ZERO
var _grace := 0.0                # 置き直された直後は、数えない（秒）
var _asked := 0.0                # ホストへ頼んだ直後は、続けて頼まない（秒）
var _hints := 0


func setup() -> void:
	pass


# 落ちる高さ（m）→ ぶつかる速さ（m/秒）。説明と確認で使う
static func speed_from(height: float) -> float:
	return sqrt(2.0 * 16.0 * maxf(height, 0.0))        # 16 は player.gd の GRAVITY


# ---- 自分がぶつかったか（自分の画面） ----

func _physics_process(delta: float) -> void:
	if game == null:
		return
	var me := game.local_player() as Node3D
	if me == null or not ("impact" in me):
		return
	var hit: float = me.impact
	me.impact = 0.0
	_asked = maxf(_asked - delta, 0.0)
	# 置き直し（復帰・帰社・撮り直し）は、ぶつかったことにしない
	if me.global_position.distance_to(_last) > 3.0:
		_grace = 0.25
	_grace = maxf(_grace - delta, 0.0)
	_last = me.global_position
	if hit < KO_SPEED or _grace > 0.0 or _asked > 0.0 or me.down > 0.0 or game.replaying or me.vehicle_riding() or me.operating != 0:
		return
	var slow: Object = game.hooks.feature("slow_ray")
	if slow != null and int(me.peer_id) in (slow.players_in as Array):
		hit *= float(slow.SLOW)                       # ゆっくり降りている
	if hit < KO_SPEED:
		return
	_asked = 0.5
	h_impact.rpc_id(1, hit, me.global_position, me.impact_normal)


# ---- 決める（ホスト） ----

@rpc("any_peer", "call_local", "reliable")
func h_impact(speed: float, at: Vector3, normal: Vector3) -> void:
	var who := Net.sender()
	if not Net.is_host() or game.replaying or not game.players.has(who) or downs.has(who):
		return
	if not is_finite(speed) or not at.is_finite() or not normal.is_finite():
		return
	speed = clampf(speed, 0.0, 60.0)
	var soft := soft_near(at, who)
	var absorb := 0.0
	var pids: Array = []
	for row: Array in soft:
		absorb += float(row[1])
		pids.append(int((row[0] as Node).pid))
		_kick(row[0] as RigidBody3D, at, speed)
	if speed - absorb >= KO_SPEED:
		var secs := clampf(DOWN_MIN + (speed - absorb - KO_SPEED) * DOWN_PER, DOWN_MIN, DOWN_MAX)
		game.host_ev("stunt_down", [who, secs, at, normal])
	elif not pids.is_empty():
		game.host_ev("stunt_soft", [who, at, pids])


# 体のそばにある、やわらかい物：[[物, 受け止められる速さ], ...]。自分で持っている物は数えない
func soft_near(at: Vector3, who: int) -> Array:
	var out: Array = []
	for p: Variant in game.props.values():
		var prop := p as RigidBody3D
		if prop == null or prop.absent or not SOFT.has(str(prop.kind)) or int(prop.holder) == who:
			continue
		var centre: Vector3 = prop.to_global(prop.center)
		var radius: float = maxf(prop.half.x, maxf(prop.half.y, prop.half.z))
		# 体（足元から頭までの線）の、いちばん近い所までの距離
		var along := clampf(centre.y - at.y, 0.0, BODY_TALL)
		if centre.distance_to(at + Vector3(0.0, along, 0.0)) <= radius + CATCH_PAD:
			out.append([prop, float(SOFT[str(prop.kind)])])
	return out


# 受け止めた物は、はじかれて散らばる
func _kick(prop: RigidBody3D, at: Vector3, speed: float) -> void:
	if prop == null or prop.freeze or int(prop.holder) != 0:
		return
	var away: Vector3 = prop.to_global(prop.center) - at
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3(randf() - 0.5, 0.0, randf() - 0.5)
	prop.sleeping = false
	prop.apply_central_impulse((away.normalized() * 0.4 * speed + Vector3.UP * 2.0) * prop.mass)


# ---- 全員の画面 ----

func hook_events() -> Array:
	return ["stunt_down", "stunt_soft"]


func hook_rec_events() -> Array:
	return ["stunt_down", "stunt_soft"]


func hook_event(n: String, a: Array) -> void:
	var who := int(a[0])
	var pl := game.players.get(who) as Node3D
	if pl == null:
		return
	var mine: bool = pl.is_local and not game.replaying
	if n == "stunt_down":
		var secs := float(a[1])
		var at: Vector3 = a[2]
		var normal: Vector3 = a[3]
		var wall := normal.y < 0.6
		_clear(who)
		var stars: Node3D = Stars.new()
		add_child(stars)
		stars.start(CREW_LAYER)
		stars.follow(_star_spot(pl, wall))
		downs[who] = {"t": 0.0, "len": secs, "wall": wall, "stars": stars}
		if wall:
			# 壁に背中を付ける
			pl.vis.rotation.y = atan2(normal.x, normal.z)
		pl.vis.set_face("shock")
		Sfx.play("thump", at)
		Sfx.play("land", at)
		_dust(at, 1.0, 4)
		if mine:
			pl.down = secs
			pl._face_t = secs + 0.4
			pl.velocity = Vector3.ZERO
			if int(pl.held) != 0:
				game.act_release()
			_shake(0.12)
			if _hints < HINTS:
				_hints += 1
				game.hud.show_toast("強くぶつかって、のびた。段ボール箱など、やわらかい物が受け止めてくれる", game.hud.YELLOW, 3.4)
	elif n == "stunt_soft":
		var at: Vector3 = a[1]
		Sfx.play("drop", at)
		Sfx.play("bump", at)
		_dust(at, 0.6, 2)
		for pid: Variant in a[2]:
			var prop := game.props.get(int(pid)) as Node3D
			if prop != null and prop.get("visual") != null and not _wobble.has(int(pid)):
				_wobble[int(pid)] = [WOBBLE_SEC, (prop.visual as Node3D).scale]
		pl.vis.set_face("surprised")
		if mine:
			pl._face_t = 1.2
			pl.velocity.y = maxf(pl.velocity.y, 3.0)       # ぽよん、と少しはずむ


func _process(delta: float) -> void:
	for who: Variant in downs.keys():
		var row: Dictionary = downs[who]
		var pl := game.players.get(who) as Node3D
		if pl == null or not is_instance_valid(pl):
			_clear(int(who))
			continue
		row.t = float(row.t) + delta
		var vis: Node3D = pl.vis
		var stars: Variant = row.stars
		if float(row.t) < float(row.len) - POP_SEC:
			# ぺちゃんこ：すぐ平たく広がる
			vis.scale = vis.scale.move_toward(WALL_FLAT if row.wall else FLAT, delta * 14.0)
			if is_instance_valid(stars):
				stars.follow(_star_spot(pl, row.wall))
		else:
			# ぽんと戻る。星は、回す力が切れて落ちる
			vis.scale = vis.scale.move_toward(Vector3.ONE, delta * 6.0)
			if is_instance_valid(stars):
				stars.release(pl.global_position.y)
			if float(row.t) >= float(row.len):
				vis.scale = Vector3.ONE
				downs.erase(who)
	for pid: Variant in _wobble.keys():
		var row: Array = _wobble[pid]
		var prop := game.props.get(pid) as Node3D
		var left := float(row[0]) - delta
		if prop == null or prop.get("visual") == null:
			_wobble.erase(pid)
			continue
		var visual: Node3D = prop.visual
		if left <= 0.0:
			visual.scale = row[1]
			_wobble.erase(pid)
			continue
		row[0] = left
		# つぶれて、戻りすぎて、収まる
		var s := left / WOBBLE_SEC
		var amount := 0.3 * s * cos((1.0 - s) * TAU * 1.5)
		visual.scale = (row[1] as Vector3) * Vector3(1.0 + amount * 0.5, 1.0 - amount, 1.0 + amount * 0.5)


# 星が回る場所：床でぺちゃんこなら体の少し上、壁なら頭の上
func _star_spot(pl: Node3D, wall: bool) -> Vector3:
	if wall:
		return pl.global_position + Vector3(0.0, 2.05, 0.0)
	return pl.global_position + Vector3(0.0, 0.62, 0.0)


func _clear(who: int) -> void:
	if not downs.has(who):
		return
	var row: Dictionary = downs[who]
	if is_instance_valid(row.stars):
		(row.stars as Node).queue_free()
	var pl := game.players.get(who) as Node3D
	if pl != null and is_instance_valid(pl):
		pl.vis.scale = Vector3.ONE
		if pl.is_local:
			pl.down = 0.0
	downs.erase(who)


func _clear_all() -> void:
	for who: Variant in downs.keys():
		_clear(int(who))


# 土ぼこり（ぶつかった所から、まわりへ）
func _dust(at: Vector3, size: float, count: int) -> void:
	for k in count:
		var turn := TAU * float(k) / float(count) + 0.5
		var puff: Node3D = Dust.new()
		add_child(puff)
		puff.global_position = at + Vector3(sin(turn), 0.0, cos(turn)) * 0.2
		puff.burst(Vector3(sin(turn), 0.0, cos(turn)), size)


func _shake(power: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var tw := cam.create_tween()
	for k in 6:
		var amount := power * (1.0 - float(k) / 6.0)
		tw.tween_property(cam, "h_offset", randf_range(-amount, amount), 0.04)
		tw.parallel().tween_property(cam, "v_offset", randf_range(-amount, amount), 0.04)
	tw.tween_property(cam, "h_offset", 0.0, 0.05)
	tw.parallel().tween_property(cam, "v_offset", 0.0, 0.05)


# のびている人は、物を持てない（ホストが断る。自分の画面の案内にも出る）
func hook_grab_block(_prop: Node) -> String:
	return "のびている間は、持てない" if downs.has(Net.sender()) else ""


# ---- 場面の切り替わり：のびたままにしない ----

func hook_return_office() -> void:
	_clear_all()


func hook_retake() -> void:
	_clear_all()


func hook_playback(_on: bool) -> void:
	_clear_all()
