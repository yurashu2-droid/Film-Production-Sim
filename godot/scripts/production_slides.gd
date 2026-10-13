extends RefCounted
## 参考スライドの中身を決める（事務所の机の「のぞき箱」で、のぞいた人だけが見る絵）。
##
## 決めるのはホスト。依頼を受けたときに1回だけ決めて、production_flow.gd の snapshot() で全員へ送る
## （あとから入った人にも、同じ中身が届く）。送るのは「どの種類の物を、どこに並べるか」だけ。
## 絵は、発注画面の写真（assets/ui/catalog）を黒く抜いたシルエットにして、各自の画面で描く（scripts/ui/slide_view.gd）。
##
## build() が返す物
##   "job"  ：依頼の番号（絵コンテと依頼主の顔は、ここから引く）
##   "rows" ：役ごとのおすすめ [[役, [種類, 種類, 種類]], ...]（上から並べる順。"" は空き）
##   "plus" ：一緒に使うと良い2つ [[上の行の番号, 列], ...]。その列の、上の行の物と、すぐ下の行の物を「＋」でつなぐ
##   "likes"：依頼主の好みの属性ごとに、その属性を持つ物 [[種類, ...], ...]（属性の名前は入れない）
##
## おすすめの選び方
##   ・役ごとに3つ。らしさ（production_cast.gd の fit）が 2 の物から選び、足りなければ 1 の物で埋める。
##   ・役ごとに、今日手に入る物（available：今日の廃材に出ている物・会社にある物・借りられる物）を1つは入れる。
##     残りの2つは、今日あるかどうかを見ずに選ぶ。だから、並んだ物が全部そろう日は少ない。
##     どれが在るかは、絵には出さない（監督が聞いて、集める人が「無い！」と答える）。
##     今日は1つも無い役ができる日はある。ただし爆弾はいつでも借りられるので、全部の役が空振りになる日は無い。
##   ・名前つきのコンボ（production_cast.gd の NAMED）を1組、わざと混ぜる（IDEA_COMBO）。
##     らしさの低い物どうし（トイレとうんこ）でも、組で使えば得になることを、絵の「＋」だけで伝える。
##   ・並んだ物の中に、ほかにも組（名前つき・同じ属性）があれば「＋」を足す。全部で MAX_PLUS 組まで。
##     コンボの名前も、属性の名前も出さない。
const Cast := preload("res://scripts/production_cast.gd")

const PER_ROW := 3          # 役ごとに並べる数
const PER_LIKE := 3         # 好みの属性ごとに並べる数
const MAX_PLUS := 2         # 「＋」でつなぐ組の上限
const IDEA_COMBO := true    # 名前つきのコンボを1組、わざと混ぜるか


# job：依頼の番号 / story：台本 / likes：依頼主の好みの属性 / available：今日手に入る物の種類 / seed_value：乱数の種
static func build(job: int, story: String, likes: Array, available: Array, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var roles: Array = Cast.roles_for(story)
	var rows := {}              # 役 → 種類の並び
	var sure := {}              # 役 → 今日手に入る物として入れた1つ（入れ替えない。無ければ ""）
	var shown := {}             # もう、どこかの役に並べた種類（同じ形が2つの役に並ばないよう、後回しにする）
	for role: String in roles:
		var picked: Array = _pick_row(role, available, shown, rng)
		rows[role] = picked[0]
		sure[role] = picked[1]
		for kind: String in rows[role]:
			shown[kind] = true
	var pairs: Array = []       # 「＋」でつなぐ組 [[役, 種類, 役, 種類], ...]
	if IDEA_COMBO:
		_add_idea(story, rows, sure, pairs, rng)
	_find_pairs(story, rows, pairs, rng)
	var placed: Array = _layout(roles, rows, pairs, rng)
	return {"job": job, "rows": placed[0], "plus": placed[1], "likes": _pick_likes(likes, available, rng)}


# その役に、らしさがちょうど grade の物（ジョーカーは、形のおすすめにならないので外す）
static func kinds_with_fit(role: String, grade: int) -> Array:
	var out: Array = []
	for kind: String in Cast.PROPS:
		if not Cast.is_joker(kind) and Cast.fit(kind, role) == grade:
			out.append(kind)
	return out


# その属性を持つ物
static func kinds_with_attr(attr: String) -> Array:
	var out: Array = []
	for kind: String in Cast.PROPS:
		if not Cast.is_joker(kind) and attr in Cast.attrs(kind):
			out.append(kind)
	return out


# その2つを、その役で一緒に使うとコンボになるか（名前つき・同じ属性のどちらでも）
static func is_combo(story: String, role_a: String, kind_a: String, role_b: String, kind_b: String) -> bool:
	if role_a == role_b or kind_a == kind_b or kind_a == "" or kind_b == "":
		return false
	var used := {role_a: [{"kind": kind_a, "label": "", "tags": []}], role_b: [{"kind": kind_b, "label": "", "tags": []}]}
	return not (Cast.score(story, used)["combos"] as Array).is_empty()


# 並べた種類を全部（確認や、絵の先読みに使う）
static func kinds_of(deck: Dictionary) -> Array:
	var out: Array = []
	for row: Array in deck.get("rows", []):
		for kind: String in row[1]:
			if kind != "" and kind not in out:
				out.append(kind)
	for group: Array in deck.get("likes", []):
		for kind: String in group:
			if kind != "" and kind not in out:
				out.append(kind)
	return out


# 「＋」の組を、役と種類に直す [[役, 種類, 役, 種類], ...]
static func plus_pairs(deck: Dictionary) -> Array:
	var out: Array = []
	var rows: Array = deck.get("rows", [])
	for mark: Array in deck.get("plus", []):
		var upper: int = mark[0]
		var col: int = mark[1]
		if upper < 0 or upper + 1 >= rows.size():
			continue
		out.append([str(rows[upper][0]), str(rows[upper][1][col]), str(rows[upper + 1][0]), str(rows[upper + 1][1][col])])
	return out


# ---- 役ごとの行 ----

# [並べる種類, 今日手に入る物として入れた1つ]
static func _pick_row(role: String, available: Array, shown: Dictionary, rng: RandomNumberGenerator) -> Array:
	# らしい順（2 → 1）。同じらしさの中は、ばらばらの順。ほかの役にもう並べた物は、後ろへ回す
	var order: Array = _later(_shuffled(kinds_with_fit(role, 2), rng), shown) + _later(_shuffled(kinds_with_fit(role, 1), rng), shown)
	var sure := ""
	for kind: String in order:
		if kind in available:
			sure = kind
			break
	var row: Array = [] if sure == "" else [sure]
	for kind: String in order:
		if row.size() >= PER_ROW:
			break
		if kind not in row:
			row.append(kind)
	return [row, sure]


# shown にある物を、順を保ったまま後ろへ回す
static func _later(list: Array, shown: Dictionary) -> Array:
	var front: Array = []
	var back: Array = []
	for kind: String in list:
		if shown.has(kind):
			back.append(kind)
		else:
			front.append(kind)
	return front + back


# ---- 一緒に使うと良い組 ----

# 名前つきのコンボを1組、行に混ぜる。もう並んでいる物で組めるなら、それを使う。
# 先に2つとも決めてから行を直す（片方だけ入って、組にならない、ということが起きないように）
static func _add_idea(story: String, rows: Dictionary, sure: Dictionary, pairs: Array, rng: RandomNumberGenerator) -> void:
	var roles: Array = Cast.roles_for(story)
	var recipes: Array = []
	for recipe: Dictionary in Cast.NAMED:
		var need: Dictionary = recipe["need"]
		if need.size() == 2 and need.keys().all(func(role: String) -> bool: return role in roles and rows.has(role)):
			recipes.append(recipe)
	if recipes.is_empty():
		return
	var chosen: Dictionary = recipes[rng.randi() % recipes.size()]["need"]
	var parts: Array = []           # [役, 種類, 役, 種類]
	for role: String in chosen:
		var partner: String = str(parts[1]) if parts.size() >= 2 else ""
		var options: Array = _options(chosen[role]).filter(func(kind: String) -> bool: return kind != partner)
		if options.is_empty():
			return
		var kind := ""
		for have: String in rows[role]:
			if have in options:
				kind = have
				break
		if kind == "":
			# その役に、なるべくらしい物を選ぶ。ほかの役の行にもう並んでいる物は、避けられるなら避ける
			var top := 0
			for option: String in options:
				top = maxi(top, Cast.fit(option, role))
			var best: Array = options.filter(func(option: String) -> bool: return Cast.fit(option, role) == top)
			var fresh: Array = best.filter(func(option: String) -> bool: return not _shown_elsewhere(option, role, rows))
			if not fresh.is_empty():
				best = fresh
			kind = best[rng.randi() % best.size()]
			# ほかの役の「今日手に入る1つ」と同じ物になるなら、今回は混ぜない（同じ形を2か所に出さない）
			for other: String in rows:
				if other != role and sure[other] == kind:
					return
		parts.append(role)
		parts.append(kind)
	if parts.size() != 4 or not is_combo(story, parts[0], parts[1], parts[2], parts[3]):
		return
	for i in [0, 2]:
		var role: String = parts[i]
		var kind: String = parts[i + 1]
		var row: Array = rows[role]
		if kind not in row:
			# 今日手に入る1つ（sure）は残して、ほかの1つと入れ替える
			var at := row.size() - 1
			while at > 0 and row[at] == sure[role]:
				at -= 1
			if row.size() < PER_ROW:
				row.append(kind)
			else:
				row[at] = kind
		_drop_elsewhere(kind, role, rows, sure, rng)
	pairs.append(parts)


# その種類が、ほかの役の行に並んでいるか
static func _shown_elsewhere(kind: String, role: String, rows: Dictionary) -> bool:
	for other: String in rows:
		if other != role and kind in rows[other]:
			return true
	return false


# 同じ物が、ほかの役の行にも並んでいたら、そちらを別の物に替える（同じ形が2か所に出ないように）。
# その行の「今日手に入る1つ」だった場合と、替わりが無い場合は、そのまま
static func _drop_elsewhere(kind: String, role: String, rows: Dictionary, sure: Dictionary, rng: RandomNumberGenerator) -> void:
	for other: String in rows:
		var row: Array = rows[other]
		var at: int = row.find(kind)
		if other == role or at < 0 or sure[other] == kind:
			continue
		for spare: String in _shuffled(kinds_with_fit(other, 2), rng) + _shuffled(kinds_with_fit(other, 1), rng):
			if spare not in row and not _shown_elsewhere(spare, other, rows):
				row[at] = spare
				break


# コンボの材料の書き方（種類の名前か、"attr:属性"）を、種類の一覧に直す
static func _options(wanted: Array) -> Array:
	var out: Array = []
	for want: String in wanted:
		var kinds: Array = kinds_with_attr(want.trim_prefix("attr:")) if want.begins_with("attr:") else [want]
		for kind: String in kinds:
			if Cast.castable(kind) and kind not in out:
				out.append(kind)
	return out


# 並んだ物の中から、コンボになる2つを探して足す（1つの物は、1組にだけ入る）
static func _find_pairs(story: String, rows: Dictionary, pairs: Array, rng: RandomNumberGenerator) -> void:
	var busy := {}
	for pair: Array in pairs:
		busy["%s/%s" % [pair[0], pair[1]]] = true
		busy["%s/%s" % [pair[2], pair[3]]] = true
	var roles: Array = rows.keys()
	var found: Array = []
	for i in roles.size():
		for j in range(i + 1, roles.size()):
			for a: String in rows[roles[i]]:
				for b: String in rows[roles[j]]:
					if is_combo(story, roles[i], a, roles[j], b):
						found.append([roles[i], a, roles[j], b])
	for pair: Array in _shuffled(found, rng):
		if pairs.size() >= MAX_PLUS:
			break
		var first := "%s/%s" % [pair[0], pair[1]]
		var second := "%s/%s" % [pair[2], pair[3]]
		if busy.has(first) or busy.has(second):
			continue
		# 行は上下に並べるので、組になった役どうしが、となり合えるときだけ足す
		if not _fits(roles, pairs + [pair]):
			continue
		busy[first] = true
		busy[second] = true
		pairs.append(pair)


# ---- 並べ方 ----

# 行の順と列を決める：組の2つが、上下にとなり合う同じ列に来るようにする。[[[役, [種類...]], ...], [[上の行, 列], ...]]
static func _layout(roles: Array, rows: Dictionary, pairs: Array, rng: RandomNumberGenerator) -> Array:
	var order: Array = _row_order(roles, pairs)
	var cols: Array = _shuffled(range(PER_ROW), rng)
	var grid := {}
	for role: String in order:
		var blank: Array = []
		blank.resize(PER_ROW)
		blank.fill("")
		grid[role] = blank
	var plus: Array = []
	for i in pairs.size():
		var pair: Array = pairs[i]
		var col: int = cols[i]
		grid[pair[0]][col] = pair[1]
		grid[pair[2]][col] = pair[3]
		plus.append([mini(order.find(pair[0]), order.find(pair[2])), col])
	var out: Array = []
	for role: String in order:
		var line: Array = grid[role]
		var rest: Array = _shuffled((rows[role] as Array).filter(func(kind: String) -> bool: return kind not in line), rng)
		for col in PER_ROW:
			if line[col] == "" and not rest.is_empty():
				line[col] = rest.pop_front()
		out.append([role, line])
	return [out, plus]


# 組になった役どうしが、上下にとなり合う並び順（無ければ、元の順）
static func _row_order(roles: Array, pairs: Array) -> Array:
	for order: Array in _orders(roles):
		var ok := true
		for pair: Array in pairs:
			if absi(order.find(pair[0]) - order.find(pair[2])) != 1:
				ok = false
		if ok:
			return order
	return roles.duplicate()


static func _fits(roles: Array, pairs: Array) -> bool:
	for order: Array in _orders(roles):
		var ok := true
		for pair: Array in pairs:
			if absi(order.find(pair[0]) - order.find(pair[2])) != 1:
				ok = false
		if ok:
			return true
	return false


# 並び順を全部（元の順が先頭）。役は3つほどなので、総当たりでよい
static func _orders(list: Array) -> Array:
	if list.size() <= 1:
		return [list.duplicate()]
	var out: Array = []
	for i in list.size():
		var rest: Array = list.duplicate()
		var head: Variant = rest.pop_at(i)
		for tail: Array in _orders(rest):
			out.append([head] + tail)
	return out


# ---- 依頼主の好み ----

# 好みの属性ごとに、その属性を持つ物を並べる。今日手に入る物を1つは入れる（あれば）
static func _pick_likes(likes: Array, available: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var shown := {}
	for attr: String in likes:
		var pool: Array = _later(_shuffled(kinds_with_attr(attr), rng), shown)
		var group: Array = []
		for kind: String in pool:
			if kind in available:
				group.append(kind)
				break
		for kind: String in pool:
			if group.size() >= PER_LIKE:
				break
			if kind not in group:
				group.append(kind)
		group = _shuffled(group, rng)
		for kind: String in group:
			shown[kind] = true
		out.append(group)
	return out


static func _shuffled(list: Array, rng: RandomNumberGenerator) -> Array:
	var out: Array = list.duplicate()
	for n in range(out.size() - 1, 0, -1):
		var k: int = rng.randi_range(0, n)
		var swap: Variant = out[n]
		out[n] = out[k]
		out[k] = swap
	return out
