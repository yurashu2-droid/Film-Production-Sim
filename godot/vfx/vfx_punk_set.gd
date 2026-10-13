extends "res://vfx/vfx_base.gd"
# パンクなペン画の絵柄のエフェクト集（大1・中2・小3）。光らせない。色は墨・骨・深紅・薄紫のべた塗り。
# 絵柄の決まりは .claude/skills/godot-vfx/STYLE-punk-ink.md。形は shaders/punk.gdshader が描く。
#   小  cross   ×のヒット：ばんそうこうの×が貼られ、墨の短い線が四方へ飛ぶ。×はかすれて消える
#   小  zig     ギザギザ：深紅のギザギザが二本、描かれて先へ走り去る
#   小  crown   王冠の落書き：スプレーで左から描かれ、ペンキが垂れ、斜めに掻き消される
#   中  rag     赤い布の斬撃：ちぎれた布の帯が弧に走り、切れ端が落ちる。帯は先へ走り去る
#   中  bolt    薄紫の稲妻：黒い輪郭の太いギザギザが落ち、3回描き直される。上（供給元）から消える
#   大  spikes  棘の地走り：棘が一本ずつ地面を走って生え、最後に大きな棘と王冠。手前から順に折れる
# 終わりはどれも「絵として消える」：掻き消す・かすれる・走り去る・折れる・落ちる。縮小とフェードは使わない。
# 12 コマ/秒。線は 8 コマ/秒で描き直して震える。

const FPS := 12.0
const BONE := Vector3(0.91, 0.86, 0.85)
const INK := Vector3(0.03, 0.03, 0.035)
const RED := Vector3(0.55, 0.015, 0.045)
const LILAC := Vector3(0.62, 0.6, 0.86)
const LIFE := {"cross": 0.75, "zig": 0.65, "crown": 1.05, "rag": 1.5, "bolt": 1.25, "spikes": 3.5}

var _kind := "cross"
var _size := 1.0
var _frame := -1
var _a: Array = []      # 主役の板
var _b: Array = []      # 脇の板
var _data: Array = []   # 脇の板ごとの数値


static func spawn(parent: Node, pos: Vector3, size: float = 1.0, kind: String = "cross") -> Node3D:
	var fx: Node3D = new()
	parent.add_child(fx)
	fx.global_position = pos
	fx.start(size, kind)
	return fx


func start(size: float, kind: String) -> void:
	_size = size
	_kind = kind
	life = float(LIFE[kind])
	match kind:
		"cross":
			_a.append(_board({"mode": 2, "fill": BONE, "roll": 0.2}, Vector3.ZERO, 1.9))
			for i in 4:
				var a := 0.6 + i * TAU / 4.0
				_b.append(_board({"mode": 1, "fill": INK, "outline": 0.0, "roll": a, "grow": 0.0}, Vector3(cos(a), sin(a), 0.0) * 1.5, 1.0))
		"zig":
			_a.append(_board({"mode": 1, "fill": RED, "outline": 0.0, "grow": 0.0}, Vector3.ZERO, 2.4))
			_a.append(_board({"mode": 1, "fill": RED, "outline": 0.0, "grow": 0.0, "roll": 0.25}, Vector3(0.35, -0.6, 0.0), 1.3))
		"crown":
			_a.append(_board({"mode": 4, "fill": RED, "grow": 0.0}, Vector3.ZERO, 2.6))
		"rag":
			_a.append(_board({"mode": 3, "fill": RED, "roll": -0.3, "grow": 0.0}, Vector3.ZERO, 4.4))
			for i in 3:
				_b.append(_board({"mode": 1, "fill": INK, "outline": 0.0, "roll": -0.3, "grow": 0.0}, Vector3(-0.3 + 0.5 * i, 0.95 - 0.5 * i, -0.05), 1.5))
			for i in 5:
				var m := _board({"mode": 3, "fill": RED, "roll": randf() * TAU}, Vector3.ZERO, 0.75)
				m.visible = false
				_b.append(m)
				_data.append([0.14 + 0.03 * i, Vector3(-1.2 + 0.6 * i, 0.5 - 0.25 * i, 0.0), Vector3(randf_range(-0.6, 1.2), randf_range(0.6, 1.8), 0.0), randf_range(-5.0, 5.0)])
		"bolt":
			_a.append(_board({"mode": 1, "fill": LILAC, "outline": 1.0, "roll": -PI / 2.0, "grow": 0.0}, Vector3(0.0, 2.2, 0.0), 4.4))
			_a.append(_board({"mode": 0, "fill": BONE, "spikes": 13.0}, Vector3(0.0, 0.35, 0.1), 2.0))
			for i in 3:
				var a := 0.4 + i * 1.2
				_b.append(_board({"mode": 1, "fill": RED, "outline": 0.0, "roll": a, "grow": 0.0}, Vector3(cos(a) * 1.3, 0.5 + sin(a) * 0.6, 0.05), 1.2))
		"spikes":
			for i in 9:
				var last := i == 8
				var h := 5.2 if last else 2.0 + 0.25 * i
				var m := _board({"mode": 5, "fill": BONE, "grow": 0.0}, Vector3(-4.4 + 1.05 * i, h * 0.5, 0.4 if i % 2 == 0 else -0.4), 1.0)
				m.scale = Vector3(h * 0.62, h, 1.0) * size
				_a.append(m)
				var a := randf_range(0.4, 2.6)
				_b.append(_board({"mode": 1, "fill": RED, "outline": 0.0, "roll": a, "grow": 0.0}, Vector3(-4.4 + 1.05 * i + cos(a) * 0.7, h * 0.75, 0.0), 1.6))
			_b.append(_board({"mode": 4, "fill": RED, "grow": 0.0}, Vector3(4.2, 6.3, 0.0), 2.4))
	_pose(0.0)


func _board(params: Dictionary, pos: Vector3, dia: float) -> MeshInstance3D:
	var all := {"ink": INK, "seed": randf() * 9.0}
	all.merge(params, true)
	var m := MeshInstance3D.new()
	m.mesh = Lib.quad()
	m.material_override = Lib.material("punk", all)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = pos * _size
	m.scale = Vector3.ONE * dia * _size
	m.set_meta("dia", dia)
	add_child(m)
	return m


func _tick(_delta: float) -> void:
	var frame := int(age * FPS)
	if frame != _frame:
		_frame = frame
		_pose(frame / FPS)


# 出だしの「小さい → 行き過ぎ → 落ち着く」。since は出てからの秒数
static func _pop(since: float) -> float:
	return [0.6, 1.2, 1.0][clampi(int(since * FPS), 0, 2)]


func _pose(t: float) -> void:
	for m: MeshInstance3D in _a + _b:
		param(m, "phase", t)
	match _kind:
		"cross":
			_a[0].scale = Vector3.ONE * 1.9 * _size * _pop(t)
			param(_a[0], "wear", smoothstep(0.35, 0.65, t))
			for m: MeshInstance3D in _b:
				param(m, "grow", clampf(t / 0.1, 0.0, 1.0))
				param(m, "wear", clampf((t - 0.17) / 0.2, 0.0, 1.0))
		"zig":
			for i in 2:
				var since := t - 0.06 * i
				param(_a[i], "grow", clampf(since / 0.1, 0.0, 1.0))
				param(_a[i], "wear", clampf((since - 0.25) / 0.22, 0.0, 1.0))
		"crown":
			_a[0].scale = Vector3.ONE * 2.6 * _size * _pop(t)
			param(_a[0], "grow", clampf(t / 0.45, 0.0, 1.0))
			param(_a[0], "wear", smoothstep(0.65, 0.95, t))
		"rag":
			param(_a[0], "grow", clampf(t / 0.16, 0.0, 1.0))
			param(_a[0], "wear", clampf((t - 0.5) / 0.3, 0.0, 1.0))
			for i in 3:
				var since := t - 0.03 * i
				param(_b[i], "grow", clampf(since / 0.1, 0.0, 1.0))
				param(_b[i], "wear", clampf((since - 0.14) / 0.14, 0.0, 1.0))
			# 切れ端：帯から離れ、回りながら落ちる。地面に着く前に、かすれず「落ちて画面から抜ける」
			for i in 5:
				var m: MeshInstance3D = _b[3 + i]
				var d: Array = _data[i]
				var tau := t - float(d[0])
				var p: Vector3 = ((d[1] as Vector3) + (d[2] as Vector3) * tau + Vector3(0.0, -4.0 * tau * tau, 0.0)) * _size
				m.visible = tau >= 0.0 and global_position.y + p.y > 0.15
				m.position = p
				param(m, "roll", tau * float(d[3]))
		"bolt":
			var frame := int(t * FPS)
			if frame >= 1 and frame <= 3:
				param(_a[0], "seed", float(frame) * 3.7)
			param(_a[0], "grow", clampf(t / 0.08, 0.0, 1.0))
			param(_a[0], "wear", clampf((t - 0.45) / 0.25, 0.0, 1.0))
			var hit := t - 0.08
			_a[1].visible = hit >= 0.0
			_a[1].scale = Vector3.ONE * 2.0 * _size * _pop(hit)
			param(_a[1], "wear", smoothstep(0.5, 0.95, t))
			for i in 3:
				var since := hit - 0.05 * i
				_b[i].visible = since >= 0.0
				param(_b[i], "grow", clampf(since / 0.1, 0.0, 1.0))
				param(_b[i], "wear", clampf((since - 0.3) / 0.25, 0.0, 1.0))
		"spikes":
			for i in 9:
				var since := t - 0.15 * i
				var m: MeshInstance3D = _a[i]
				m.visible = since >= 0.0
				param(m, "grow", [0.7, 1.0, 1.0][clampi(int(since * FPS), 0, 2)])
				param(m, "wear", clampf((t - 2.3 - 0.07 * i) / 0.4, 0.0, 1.0))
				var z: MeshInstance3D = _b[i]
				z.visible = since >= 0.0 and since < 0.7
				param(z, "grow", clampf(since / 0.1, 0.0, 1.0))
				param(z, "wear", clampf((since - 0.3) / 0.3, 0.0, 1.0))
			var crown: MeshInstance3D = _b[9]
			var up := t - 1.45
			crown.visible = up >= 0.0
			crown.scale = Vector3.ONE * 2.4 * _size * _pop(up)
			param(crown, "grow", clampf(up / 0.45, 0.0, 1.0))
			param(crown, "wear", smoothstep(2.9, 3.3, t))
