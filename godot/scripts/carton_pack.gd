extends RefCounted
## 段ボール箱の内側に、物を実寸で積む計算。入る量は、数ではなく、箱の内側の広さと物の大きさで決まる。
##   ・箱の内側（room）の床を細かいマス目に分け、マスごとに「いま積んである高さ」を持つ
##   ・新しい物は、向き（立てたまま2通り・寝かせて4通り）と場所を全部試して、いちばん低く収まる所に置く。
##     下にある物の、いちばん高い所に載る（めり込まない・宙に浮かない）
##   ・箱の口（内側の上の端）から少しはみ出す所までは入る（押し込める）。はみ出していると、ふたは閉まらない
##   ・物の大きさは、見た目を囲む箱形（prop.gd の center・half）で見る
## 置き方は「箱から見た、物の置き方（Transform3D）」で持つ。cargo_kit.gd が決めて、全員へ配る

const CELL := 0.025          # マス目の細かさ（m）
const SQUEEZE := 0.02        # 横は、これだけ押し込める（段ボールがたわむ分）
const OVER := 0.25           # 口から、ここまでは、はみ出して入る（物の高さの半分まで）
const LID_GIVE := 0.03       # 口からこれだけ出ているくらいなら、ふたは閉まる


# 試す向き：[向き, 寝かせているか]。立てたまま（そのまま・横に90度）を先に試す
static func turns() -> Array:
	var quarter := snap(Basis(Vector3.UP, PI * 0.5))
	var on_side := snap(Basis(Vector3.BACK, PI * 0.5))
	var on_back := snap(Basis(Vector3.RIGHT, PI * 0.5))
	return [[Basis.IDENTITY, false], [quarter, false], [on_side, true], [quarter * on_side, true], [on_back, true], [quarter * on_back, true]]


# いちばん近い「まっすぐな向き」（軸に沿った24通りのどれか）にそろえる
static func snap(b: Basis) -> Basis:
	var x := _main_axis(b.x, -1)
	var skip := 0 if absf(x.x) > 0.5 else (1 if absf(x.y) > 0.5 else 2)
	var y := _main_axis(b.y, skip)
	return Basis(x, y, x.cross(y))


static func _main_axis(v: Vector3, skip: int) -> Vector3:
	var best := -1
	var size := -1.0
	for k in 3:
		if k != skip and absf(v[k]) > size:
			size = absf(v[k])
			best = k
	var out := Vector3.ZERO
	out[best] = 1.0 if v[best] >= 0.0 else -1.0
	return out


# その向きに置いたときの、囲む箱形の半分の大きさ
static func extent(b: Basis, half: Vector3) -> Vector3:
	return Vector3(
		absf(b.x.x) * half.x + absf(b.y.x) * half.y + absf(b.z.x) * half.z,
		absf(b.x.y) * half.x + absf(b.y.y) * half.y + absf(b.z.y) * half.z,
		absf(b.x.z) * half.x + absf(b.y.z) * half.y + absf(b.z.z) * half.z)


# 置いた物が占める範囲（箱から見た箱形）
static func box_of(xf: Transform3D, center: Vector3, half: Vector3) -> AABB:
	var ext := extent(xf.basis, half)
	return AABB(xf * center - ext, ext * 2.0)


# マス目の数（横・奥）
static func grid(room: AABB) -> Vector2i:
	return Vector2i(maxi(1, roundi(room.size.x / CELL)), maxi(1, floori(room.size.z / CELL)))


# lo〜hi が掛かるマスの範囲 [始まり, 終わりの次]
static func _span(lo: float, hi: float, origin: float, cell: float, n: int) -> Vector2i:
	var a := clampi(floori((lo + SQUEEZE * 0.5 - origin) / cell + 0.001), 0, n - 1)
	var b := clampi(ceili((hi - SQUEEZE * 0.5 - origin) / cell - 0.001), a + 1, n)
	return Vector2i(a, b)


# その幅の物が使うマスの数
static func _cells(width: float, cell: float) -> int:
	return maxi(1, ceili((width - SQUEEZE) / cell - 0.001))


# いま積んである高さ（床からの高さ。マスごと）。blocks：中の物が占める範囲の一覧
static func heights(room: AABB, blocks: Array) -> PackedFloat32Array:
	var n := grid(room)
	var out := PackedFloat32Array()
	out.resize(n.x * n.y)
	out.fill(0.0)
	for block: AABB in blocks:
		_stamp(out, room, n, block)
	return out


static func _stamp(hmap: PackedFloat32Array, room: AABB, n: Vector2i, block: AABB) -> void:
	var sx := _span(block.position.x, block.end.x, room.position.x, room.size.x / n.x, n.x)
	var sz := _span(block.position.z, block.end.z, room.position.z, room.size.z / n.y, n.y)
	var top: float = block.end.y - room.position.y
	for v in range(sz.x, sz.y):
		for u in range(sx.x, sx.y):
			if hmap[v * n.x + u] < top:
				hmap[v * n.x + u] = top


# 物を置ける場所を探す。{"xf": 箱から見た置き方, "over": 口からはみ出す高さ（負なら口より下）}。置けなければ {}
#   center・half：物の、見た目を囲む箱形（物のローカル座標）
# 順番：口より下に立てて置ける所 → 寝かせれば口より下に収まる所 → はみ出すが押し込める所。その中で、いちばん低い所
static func find(room: AABB, hmap: PackedFloat32Array, center: Vector3, half: Vector3) -> Dictionary:
	var n := grid(room)
	var cx: float = room.size.x / n.x
	var cz: float = room.size.z / n.y
	var best := {}
	var best_key := INF
	for turn: Array in turns():
		var basis: Basis = turn[0]
		var ext := extent(basis, half)
		var fw := _cells(ext.x * 2.0, cx)
		var fd := _cells(ext.z * 2.0, cz)
		if fw > n.x or fd > n.y:
			continue
		var tall: float = ext.y * 2.0
		var limit: float = room.size.y + minf(OVER, ext.y)
		if tall > limit:
			continue
		var base: float = 10.0 if turn[1] else 0.0
		for j in n.y - fd + 1:
			for i in n.x - fw + 1:
				var rest := 0.0
				var sum := 0.0
				var cut := false
				for v in range(j, j + fd):
					var row: int = v * n.x
					for u in range(i, i + fw):
						var h: float = hmap[row + u]
						sum += h
						if h > rest:
							rest = h
							# これより良くはならない場所は、途中でやめる
							var bound: float = 100.0 + rest + tall if rest + tall > room.size.y + LID_GIVE else base + rest
							if rest + tall > limit or bound >= best_key:
								cut = true
								break
					if cut:
						break
				if cut:
					continue
				var top: float = rest + tall
				# 口より下に収まるなら：立てたまま → 低い所 → すき間の少ない所。はみ出すなら：はみ出しの少ない置き方
				var key: float = base + rest + (rest - sum / float(fw * fd)) * 0.5 + float(j * n.x + i) * 0.00001
				if top > room.size.y + LID_GIVE:
					key = 100.0 + top + base * 0.005 + float(j * n.x + i) * 0.00001
				if key < best_key:
					best_key = key
					var at := Vector3(room.position.x + (float(i) + float(fw) * 0.5) * cx, room.position.y + rest + ext.y, room.position.z + (float(j) + float(fd) * 0.5) * cz)
					best = {"xf": Transform3D(basis, at - basis * center), "over": top - room.size.y}
	return best


# 手で置いた・落とした物を、その場所のまま中身にする。basis：そろえた向き / at：物の真ん中（箱から見た位置）。
# その場所の下に積んである物の上に載せる。箱の内側に収まらない・はみ出しすぎるなら {}
static func drop(room: AABB, hmap: PackedFloat32Array, basis: Basis, center: Vector3, half: Vector3, at: Vector3) -> Dictionary:
	var n := grid(room)
	var cx: float = room.size.x / n.x
	var cz: float = room.size.z / n.y
	var ext := extent(basis, half)
	var fw := _cells(ext.x * 2.0, cx)
	var fd := _cells(ext.z * 2.0, cz)
	if fw > n.x or fd > n.y:
		return {}
	var i := clampi(roundi((at.x - room.position.x) / cx - float(fw) * 0.5), 0, n.x - fw)
	var j := clampi(roundi((at.z - room.position.z) / cz - float(fd) * 0.5), 0, n.y - fd)
	var rest := 0.0
	for v in range(j, j + fd):
		for u in range(i, i + fw):
			rest = maxf(rest, hmap[v * n.x + u])
	var top: float = rest + ext.y * 2.0
	if top > room.size.y + minf(OVER, ext.y):
		return {}
	var spot := Vector3(room.position.x + (float(i) + float(fw) * 0.5) * cx, room.position.y + rest + ext.y, room.position.z + (float(j) + float(fd) * 0.5) * cz)
	return {"xf": Transform3D(basis, spot - basis * center), "over": top - room.size.y}


# 下の物が抜けたあと、残りを下へ詰め直す（横の場所と向きはそのまま、下に積んである物の上まで落とす）。
# rows：[[置き方, center, half], ...]。同じ順で、新しい置き方を返す
static func settle(room: AABB, rows: Array) -> Array:
	var n := grid(room)
	var order: Array = []
	for k in rows.size():
		order.append([box_of(rows[k][0], rows[k][1], rows[k][2]).position.y, k])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] if not is_equal_approx(a[0], b[0]) else a[1] < b[1])
	var hmap := heights(room, [])
	var out: Array = []
	out.resize(rows.size())
	for entry: Array in order:
		var k: int = entry[1]
		var xf: Transform3D = rows[k][0]
		var block := box_of(xf, rows[k][1], rows[k][2])
		var sx := _span(block.position.x, block.end.x, room.position.x, room.size.x / n.x, n.x)
		var sz := _span(block.position.z, block.end.z, room.position.z, room.size.z / n.y, n.y)
		var rest := 0.0
		for v in range(sz.x, sz.y):
			for u in range(sx.x, sx.y):
				rest = maxf(rest, hmap[v * n.x + u])
		xf.origin.y += room.position.y + rest - block.position.y
		block.position.y = room.position.y + rest
		_stamp(hmap, room, n, block)
		out[k] = xf
	return out
