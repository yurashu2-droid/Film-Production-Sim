extends Node
## 編集者に頼む（2026-11-13 ユーザー「動画編集を編集者に依頼するみたいなのを、撮影後選ぶ」）。
## 撮ったテイクを納品する前に、編集者を1人選べる。試写会（features/premiere.gd）で流れる映像が、その人の編集になる。
##   ・直せるのは仕上げだけ：間をつめる・映り込んだ所を切る・テロップ・色・スロー・変な効果。
##     撮れていない場面は、撮れていないまま（採点の passed・追加注文の達成は変えない）
##   ・編集者には、得意と癖がある（EDITORS）。
##       steady 堅実：誰も映っていない間と、班が映り込んだ所を切る。ほかは何もしない
##       cm     CM向き：短くつめて、場面ごとに大きなテロップと「格安！」の札。CMなら効く。ほかの依頼だと浮く
##       mv     雰囲気もの向き：上下の黒い帯・色・爆発と決めの瞬間のスロー。月・夕日・結婚式なら効く。CMだと「何の宣伝？」
##       pro    名匠（上手くて安定）：テイクを 28 秒の予告編に組み直す。曲を書き下ろし、絵は曲の拍で切る。
##               大作の顔で始めて、一打のあとに無音。明るい曲で締めて、切った所は NG のおまけに。どの依頼でも効く。代金が高い
##       hype   ド派手（上手くて不安定）：28 秒ずっとサビ。巨大な字・色ずれ・刻み・点滅。見せ場が多い素材なら全部が拍に乗る。
##               少ないと、何も無い絵に効果だけが乗る（精算で引かれる）
##     pro と hype は「編集の台本」（edit/reel_build.gd）で動く：出来上がりの秒で並べた行（素材のどこを・どの速さで・どこへ寄って）を、
##     ホストが見返しの時計へ写す。順番を変える・くり返す・止める・曲を付ける、ができる。ほかの 4 人は、前からの作り（切る・遅くする）のまま
##       wild   前衛：何をするか分からない（爆発を3回くり返す・鏡・色の反転・急な寄り・止めて「！？」）。
##               見せ場（爆発・場面が撮れた瞬間）に重なればハマる。何も無い所だと滑る
##   ・結果は、試写会で初めて見る。精算には「編集代」と、編集の出来の行が付く（hook_fee_lines）
## 作り：
##   ・本番中に、ホストが「誰も映っていない間」「班が映り込んだ間」「爆発の時刻」を測っておく。
##   ・納品を頼まれた時（premiere.gd の _plan → hook_premiere_cues）に、ホストが編集（切る所・遅くする所・効果の時刻）を1回だけ組み、
##     "edit_on" の合図で全員へ配る。乱数は、ホストが決めた種だけ（どの画面でも同じ編集になる）
##   ・切る・遅くする・くり返すは、ホストが見返しの時計（main.gd の replay_t）を動かす。main.gd は書き換えない。
##     テロップ・色・寄りは、各自の画面で、届いた見返しの時計から出す（スクリーンに映す絵 premiere.gd の _film に重ねる）
##   ・だれに頼むか（pick）は、ホストが決めて "edit_pick" で配る。選び方（物で渡す）は、まだ作っていない。
##     自動確認が直接呼ぶ納品（game.h_deliver）と、pick が "none" の間は、今までと同じ
const UI := preload("res://scripts/ui/ui_theme.gd")
const Reel := preload("res://scripts/edit/reel_build.gd")
const ReelType := preload("res://scripts/edit/reel_type.gd")

const EDITORS := {
	"none": {"name": "頼まない", "tag": "撮ったまま出す", "fee": 0},
	"steady": {"name": "堅実のカタギリ", "tag": "変なことはしない", "fee": 60},
	"cm": {"name": "テロップのヤマネ", "tag": "CMが得意", "fee": 100},
	"mv": {"name": "映像詩人レイ", "tag": "雰囲気ものが得意", "fee": 100},
	"wild": {"name": "前衛のゴン", "tag": "何をするか分からない", "fee": 30},
	"pro": {"name": "名匠フェイブル", "tag": "上手くて、安定", "fee": 250},
	"hype": {"name": "ド派手のバンバ", "tag": "ハマれば最高。外すと効果だけ", "fee": 150},
}
const ORDER := ["none", "steady", "cm", "mv", "wild", "pro", "hype"]
const MUSIC_DIR := "res://assets/audio/music_local/"      # 編集者の曲（UVI の音色で作った物。公開リポジトリには無い。無ければ、無音で流す）
const CLOCK_SEC := 0.25          # 台本の時計を、みんなへ送る間隔
const NG_WINDOW := Rect2(0.06, 0.17, 0.5, 0.5)            # NG のおまけの、小さな窓（絵の中の割合）
const DUO := [[Color(0.09, 0.05, 0.32), Color(1.0, 0.86, 0.1)], [Color(0.4, 0.02, 0.12), Color(1.0, 0.72, 0.78)],
	[Color(0.02, 0.2, 0.22), Color(0.7, 1.0, 0.55)], [Color(0.1, 0.1, 0.1), Color(1.0, 0.5, 0.15)]]      # 止めた絵の 2 色刷り（暗い色・明るい色）
const KEY_BEFORE := 1.0          # 見せ場（爆発・場面が撮れた瞬間）の前後は、切らない
const KEY_AFTER := 0.6
const DEAD_MIN := 1.2            # 誰も映っていない間が、これより長ければ「間」
const MAX_CUT := 0.7             # 間がテイクのこの割合を超えたら、間は切らない
const WILD_NEAR := 1.5           # 前衛の効果が、見せ場からこの秒数までなら「ハマった」
# 色（film.gdshader の grade）
const GRADE := {"none": 0, "steady": 1, "cm": 5, "mv": 2, "wild": 0, "pro": 7, "hype": 9}
const FILM_SHADER := "
shader_type canvas_item;
uniform float zoom = 1.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform float mirror = 0.0;
uniform int grade = 0;
uniform float invert = 0.0;
uniform float rainbow = 0.0;
uniform float bars = 0.0;
uniform float clock = 0.0;
uniform float dim = 0.0;
uniform vec2 shake = vec2(0.0, 0.0);
uniform float rgb = 0.0;
uniform float duo = 0.0;
uniform vec3 duo_a = vec3(0.0);
uniform vec3 duo_b = vec3(1.0);
uniform float foot = 0.0;
uniform vec4 win = vec4(0.0);
vec3 hue(vec3 c, float a) {
	vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}
void fragment() {
	// 小さな窓（NG のおまけ）：窓の中に絵を縮めて、外は暗い地
	vec2 base = UV;
	bool outside = false;
	if (win.z > 0.0) {
		base = (UV - win.xy) / win.zw;
		outside = base.x < 0.0 || base.y < 0.0 || base.x > 1.0 || base.y > 1.0;
	}
	vec2 uv = (base - center) / zoom + center + shake;
	if (mirror > 0.5 && uv.x > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	vec4 src = texture(TEXTURE, clamp(uv, vec2(0.0), vec2(1.0)));
	vec3 col = src.rgb;
	if (rgb > 0.0) {
		col.r = texture(TEXTURE, clamp(uv + vec2(rgb, 0.0), vec2(0.0), vec2(1.0))).r;
		col.b = texture(TEXTURE, clamp(uv - vec2(rgb, 0.0), vec2(0.0), vec2(1.0))).b;
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	if (grade == 1) {
		col = (col - 0.5) * 1.06 + 0.52;
	} else if (grade == 2) {
		vec3 tone = mix(vec3(0.04, 0.2, 0.26), vec3(1.0, 0.8, 0.62), smoothstep(0.05, 0.9, l));
		col = mix(mix(vec3(l), col, 0.55), tone, 0.42);
		col = (col - 0.5) * 1.15 + 0.47;
	} else if (grade == 5) {
		col = mix(vec3(l), col, 1.3) * 1.08 + 0.02;
	} else if (grade == 7) {
		// 名匠の前半（大作の予告の顔）：強めのコントラスト、少し色を抜く。影は青緑、明るい所は暖色。四隅を落とす
		col = (col - 0.5) * 1.18 + 0.47;
		float ll = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(ll), col, 0.85);
		col += mix(vec3(-0.03, 0.012, 0.04), vec3(0.035, 0.012, -0.03), smoothstep(0.2, 0.8, ll));
		vec2 q = UV - 0.5;
		col *= 1.0 - dot(q, q) * 0.6;
	} else if (grade == 8) {
		// 名匠の後半（正直な会社）：明るく、色を少し足す
		col = pow(max(col, vec3(0.0)), vec3(0.9));
		col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, 1.15) * 1.05 + vec3(0.015, 0.01, 0.0);
	} else if (grade == 9) {
		// ド派手：コントラストと色を強く
		col = (col - 0.5) * 1.25 + 0.5;
		col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, 1.35);
	}
	if (duo > 0.0) {
		float dl = dot(clamp(col, 0.0, 1.0), vec3(0.299, 0.587, 0.114));
		col = mix(col, mix(duo_a, duo_b, smoothstep(0.22, 0.68, dl)), duo);
	}
	if (rainbow > 0.5) {
		col = hue(col, clock * 9.0 + UV.x * 3.0);
	}
	col = mix(col, 1.0 - col, invert);
	col *= 1.0 - dim;
	col *= 1.0 - foot * smoothstep(0.55, 1.0, UV.y);
	if (UV.y < bars || UV.y > 1.0 - bars) {
		col = vec3(0.0);
	}
	if (outside) {
		col = vec3(0.055, 0.05, 0.045);
	}
	COLOR = vec4(clamp(col, 0.0, 1.0), src.a);
}
"
# 字を、下の絵との差で焼き込む（白い字なら、字の中だけ絵の色が反転する）
const DIFF_SHADER := "
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
void fragment() {
	vec4 c = COLOR;
	vec3 under = texture(screen, SCREEN_UV).rgb;
	COLOR = vec4(abs(under - c.rgb), c.a);
}
"

var game: Node
var pick := "none"               # 次の納品を、だれに頼むか（全員の画面で同じ）
var edit := {}                   # いま流している編集（全員の画面。空＝編集なし）
var edit_index := -1             # edit が、どのテイクの物か
var last_lines: Array = []       # いちばん新しい編集の、精算の行（確認用）
# ---- 本番中に測る物（ホスト） ----
var _dead: Array = []            # 誰も映っていない間 [[始め, 終わり], ...]
var _cameo: Array = []           # 班が映り込んだ間
var _bursts: Array = []          # 爆発の時刻
var _faces := {}                 # 役者の番号 → [一番大きく映った時刻, その大きさ, 頭まで入っていたか]（出番の役者だけ）
var _burst_info: Array = []      # 爆発ごとの [場所 [x, y, z], 種類（"flat" 書割 ／ "dud" 火薬なし ／ "real"）]
var _pop_t := -9.0               # いちばん新しく、書割が起きた時刻（すぐ後の爆発は、書割の爆発）
var _dead_from := -1.0
var _cameo_from := -1.0
var _crew_before := 0.0
var _measured := {}              # テイクの番号 → {dead, cameo, bursts}
var _lines := {}                 # テイクの番号 → 精算の行 [[文, コイン], ...]（ホスト）
# ---- 流している間（ホスト） ----
var _rep_done: Array = []        # くり返した回数
var _again: Array = []           # くり返しの間に、もう一度出す合図 [時刻, 名前, 引数]
var _again_i := 0
var _rolled := false             # この編集で、流し始めたか
var debug_pick := ""             # デバッグ起動の --editor=<ID>：依頼ごとに、この人に頼んだ事にする
# ---- 画面（全員） ----
var _mat: ShaderMaterial
var _over: Control
var _band: PanelContainer
var _band_text: Label
var _sticker: Control
var _mark: Label
var _flash: ColorRect
# ---- 編集の台本（pro・hype）を流している間 ----
var out_t := 0.0                 # 台本の時計（出来上がりの秒。ホストが進めて、みんなへ送る。各自の画面でも進める）
var _reel_on := false
var _seg_i := -1                 # いま流している行（ホスト）
var _src_prev := 0.0             # 前のコマの、素材の時刻（ホスト。ここから今までの合図を出す）
var _clock_t := 0.0
var _show_i := 0                 # いま見せている行（各自の画面）
var _center := Vector2(0.5, 0.5) # 寄っている所（各自の画面で、なめらかに追う）
var _crop_key := ""
var _music: AudioStreamPlayer
var _music_name := ""
var _type: Control               # 字（edit/reel_type.gd）：ふつう・絵との差・字の形の窓
var _type_diff: Control
var _type_mask: Control
var _mask_bg: ColorRect
var _mask_film: TextureRect
var _dressed: TextureRect       # 色の材質を付けた、スクリーンの絵
var _last_t := 0.0
var _loops := 0                  # 見返しの時計が戻った回数（くり返しの「×3」。各自の画面で数える）
var _sticker_words := ""


# ---- 編集を組む（計算だけ。どこからでも呼べる） ----

# 依頼の種類：cm（CM・紹介動画）／mood（雰囲気もの：月・夕日・結婚式・旅）／action（そのほか）
static func genre_of(job: Dictionary) -> String:
	var title := str(job.get("title", ""))
	for word: String in ["CM", "紹介動画"]:
		if title.contains(word):
			return "cm"
	for word: String in ["月", "夕日", "夕暮れ", "結婚式", "旅する", "舳先"]:
		if title.contains(word):
			return "mood"
	return "action"


# spans から、見せ場（keys）の前後をよけて、min_len より長い所だけ残す。margin は、両端を残す長さ
static func clear_spans(spans: Array, keys: Array, min_len: float, margin: float) -> Array:
	var out: Array = []
	for span: Array in spans:
		var parts: Array = [[float(span[0]) + margin, float(span[1]) - margin]]
		for key: float in keys:
			var next: Array = []
			for p: Array in parts:
				var a: float = p[0]
				var b: float = p[1]
				var lo := key - KEY_BEFORE
				var hi := key + KEY_AFTER
				if hi <= a or lo >= b:
					next.append(p)
					continue
				if lo > a:
					next.append([a, lo])
				if hi < b:
					next.append([hi, b])
			parts = next
		for p: Array in parts:
			if float(p[1]) - float(p[0]) >= min_len:
				out.append(p)
	return out


# 重なった所をまとめて、時刻の順に
static func merged(spans: Array) -> Array:
	var sorted_spans: Array = spans.duplicate(true)
	sorted_spans.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for s: Array in sorted_spans:
		if not out.is_empty() and float(s[0]) <= float(out[-1][1]) + 0.05:
			out[-1][1] = maxf(float(out[-1][1]), float(s[1]))
		else:
			out.append([float(s[0]), float(s[1])])
	return out


# 編集を組む。d：{dur, passes（場面が撮れた時刻。撮れていなければ -1）, dead, cameo, bursts, genre, titles}
# 返す物：{id, cuts [[a,b]], slows [[a,b,速さ]], reps [[時刻, 戻る秒, 回数]], fx [[a, b, 種類, 文]], grade, bars, lines [[文, コイン]], cues [[時刻, せりふ, 気分]]}
static func build_edit(id: String, d: Dictionary, seed_value: int) -> Dictionary:
	var out := {"id": id, "cuts": [], "slows": [], "reps": [], "fx": [], "grade": int(GRADE.get(id, 0)), "bars": 0.0, "lines": [], "cues": []}
	if id == "none" or not EDITORS.has(id):
		out["id"] = "none"
		return out
	var dur := float(d.get("dur", 0.0))
	var genre := str(d.get("genre", "action"))
	var net := bool(d.get("net", false))
	var titles: Array = d.get("titles", [])
	var bursts: Array = d.get("bursts", [])
	var keys: Array = []
	var passes: Array = []
	for i in (d.get("passes", []) as Array).size():
		var p := float(d["passes"][i])
		if p >= 0.0:
			passes.append([p, i])
			keys.append(p)
	for b: float in bursts:
		keys.append(b)
	var who: Dictionary = EDITORS[id]
	var lines: Array = [["編集代（%s）" % str(who["name"]), -int(who["fee"])]]
	var cues: Array = []
	var dead: Array = clear_spans(d.get("dead", []), keys, 0.6, 0.3)
	# ほとんどが「間」のテイクは、間を切らない（映像が残らなくなる）
	var dead_sum := 0.0
	for s: Array in dead:
		dead_sum += float(s[1]) - float(s[0])
	if dead_sum > dur * MAX_CUT:
		dead = []
	var cameo: Array = clear_spans(d.get("cameo", []), keys, 0.2, 0.0)
	match id:
		"steady":
			out["cuts"] = merged(dead + cameo)
			if not dead.is_empty():
				lines.append(["編集：間を %d か所つめた" % dead.size(), mini(dead.size() * 30, 120)])
			if not cameo.is_empty():
				lines.append(["編集：映り込みを %d か所切った" % cameo.size(), mini(cameo.size() * 40, 120)])
			if dead.is_empty() and cameo.is_empty():
				lines.append(["編集：直す所が無かった", 0])
		"cm":
			out["cuts"] = merged(dead + cameo)
			for p: Array in passes:
				var title := str(titles[int(p[1])]).split("（")[0] if int(p[1]) < titles.size() else "場面%d" % (int(p[1]) + 1)
				out["fx"].append([maxf(float(p[0]) - 2.4, 0.0), float(p[0]) + 0.3, "telop", title + "！"])
				out["fx"].append([maxf(float(p[0]) - 2.4, 0.0), maxf(float(p[0]) - 2.15, 0.25), "punch", ""])
			if not passes.is_empty():
				out["fx"].append([maxf(dur - 3.2, 0.0), dur + 1.0, "sticker", "格安！"])
			if genre == "cm":
				lines.append(["編集：テロップが決まった（CM向き）", 160])
				cues.append([maxf(dur - 2.0, 0.5), "テロップ、分かりやすい" if net else "これこれ、こういうのでいいんだよ", "happy"])
			else:
				lines.append(["編集：テロップが浮いている（CMではない）", -60])
				cues.append([maxf(dur * 0.5, 0.5), "テロップで台無しw" if net else "……この文字、要ります？", "sad"])
			if not dead.is_empty():
				lines.append(["編集：間を %d か所つめた" % dead.size(), mini(dead.size() * 30, 120)])
		"mv":
			out["cuts"] = merged(dead.filter(func(s: Array) -> bool: return float(s[1]) - float(s[0]) >= 1.6))        # 長い間だけ。映り込みは気にしない
			out["bars"] = 0.11
			for b: float in bursts:
				out["slows"].append([maxf(b - 0.15, 0.0), b + 0.55, 0.3])
				out["fx"].append([maxf(b - 0.15, 0.0), b + 0.1, "flash", ""])
			for p: Array in passes:
				out["slows"].append([maxf(float(p[0]) - 0.5, 0.0), float(p[0]), 0.45])
			out["slows"] = merged_slows(out["slows"])
			if genre == "mood":
				lines.append(["編集：映像が美しい（雰囲気もの向き）", 160])
				cues.append([maxf(dur - 2.0, 0.5), "映像きれいすぎん？" if net else "……美しい", "happy"])
			elif genre == "cm":
				lines.append(["編集：きれいだが、何の宣伝か分からない", -60])
				cues.append([maxf(dur * 0.5, 0.5), "で、何の会社？" if net else "……で、商品は？", "sad"])
			else:
				lines.append(["編集：映像に品が出た", 40])
			if not bursts.is_empty():
				lines.append(["編集：爆発のスローが効いた", mini(bursts.size() * 30, 90)])
		"pro", "hype":
			# 編集の台本（edit/reel_build.gd）。切る・遅くする、ではなく、出来上がりの秒で並べ直す
			var made: Dictionary = Reel.pro(d) if id == "pro" else Reel.hype(d)
			out["reel"] = made["reel"]
			out["fx"] = made["fx"]
			out["out"] = made["out"]
			out["music"] = made["music"]
			lines = made["lines"]
			cues = made["cues"]
		"wild":
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var used: Array = []
			var hits := 0
			var misses := 0
			# 爆発があれば、まず 3 回くり返す
			if not bursts.is_empty():
				var b0 := float(bursts[0])
				out["reps"].append([b0 + 1.1, 1.5, 3])
				out["fx"].append([b0 - 0.4, b0 + 1.1, "count", ""])
				used.append(b0)
				hits += 1
				cues.append([b0 + 1.0, "爆発3回は草" if net else "な、何回爆発するんだ！", "wow"])
			var kinds := ["mirror", "invert", "rainbow", "zoom", "mark"]
			var tries := 0
			while used.size() < 4 and tries < 40 and dur > 3.0:
				tries += 1
				# 半分は見せ場のそばへ、半分は当てずっぽう
				var at := rng.randf_range(1.0, maxf(dur - 1.5, 1.2))
				if not keys.is_empty() and rng.randf() < 0.5:
					at = clampf(float(keys[rng.randi() % keys.size()]) + rng.randf_range(-1.2, 0.2), 0.5, maxf(dur - 1.0, 0.6))
				var clash := false
				for u: float in used:
					clash = clash or absf(u - at) < 2.6
				if clash:
					continue
				used.append(at)
				var kind: String = kinds[rng.randi() % kinds.size()]
				var near := false
				for key: float in keys:
					near = near or absf(key - at) <= WILD_NEAR
				match kind:
					"mark":
						out["slows"].append([at, at + 0.06, 0.06])
						out["fx"].append([at, at + 0.06, "mark", "！？"])
					"zoom":
						out["fx"].append([at, at + 1.4, "zoom", ""])
					"invert":
						out["fx"].append([at, at + 0.9, "invert", ""])
					_:
						out["fx"].append([at, at + 1.8, kind, ""])
				if near:
					hits += 1
				else:
					misses += 1
					cues.append([at + 0.5, "？？？" if net else "……いまのは、何です？", "sad"])
			out["slows"] = merged_slows(out["slows"])
			if hits > 0:
				lines.append(["編集：前衛がハマった ×%d" % hits, hits * 70])
			if misses > 0:
				lines.append(["編集：前衛が滑った ×%d" % misses, -misses * 60])
			if hits > misses:
				cues.append([maxf(dur - 1.5, 0.5), "編集、天才か？" if net else "わ、分からないが……すごい！", "happy"])
	out["fx"].sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	out["lines"] = lines
	out["cues"] = cues
	return out


static func merged_slows(slows: Array) -> Array:
	var sorted_slows: Array = slows.duplicate(true)
	sorted_slows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array = []
	for s: Array in sorted_slows:
		if not out.is_empty() and float(s[0]) < float(out[-1][1]):
			out[-1][1] = maxf(float(out[-1][1]), float(s[1]))
			out[-1][2] = minf(float(out[-1][2]), float(s[2]))
		else:
			out.append(s)
	return out


# 編集のあとの長さ（確認用）：切った分を引く
static func cut_seconds(e: Dictionary) -> float:
	var sum := 0.0
	for c: Array in e.get("cuts", []):
		sum += float(c[1]) - float(c[0])
	return sum


# ---- 本番中に測る（ホスト） ----

func hook_take_start() -> void:
	_dead = []
	_cameo = []
	_bursts = []
	_dead_from = -1.0
	_cameo_from = -1.0
	_crew_before = 0.0
	_faces = {}
	_burst_info = []
	_pop_t = -9.0


func hook_core_event(n: String, _a: Array) -> void:
	if not Net.is_host() or game.state != game.S.TAKE or game.replaying:
		return
	if n == "pop":
		_pop_t = float(game.take_t)
	elif n == "burst":
		_bursts.append(float(game.take_t))
		var pos: Vector3 = _a[0] if _a.size() >= 1 and _a[0] is Vector3 else Vector3.ZERO
		var kind := "real" if _a.size() >= 2 and float(_a[1]) > 0.0 else ("flat" if float(game.take_t) - _pop_t < 0.2 else "dud")
		_burst_info.append([[pos.x, pos.y, pos.z], kind])


func hook_take_cut() -> void:
	if not Net.is_host() or (game.takes as Array).is_empty():
		return
	var t := float(game.take_t)
	if _dead_from >= 0.0:
		_dead.append([_dead_from, t])
	if _cameo_from >= 0.0:
		_cameo.append([_cameo_from, t])
	_dead_from = -1.0
	_cameo_from = -1.0
	var faces: Array = []
	var beats: Variant = game.get("beats")
	for aid: int in _faces:
		var name := str(beats.role_name(aid)) if beats != null and beats.has_method("role_name") else ""
		faces.append([aid, float(_faces[aid][0]), bool(_faces[aid][2]), name])
	_measured[game.takes.size() - 1] = {"dead": _dead.duplicate(true), "cameo": _cameo.duplicate(true), "bursts": _bursts.duplicate(),
		"faces": faces, "burst_info": _burst_info.duplicate(true)}


func hook_new_job() -> void:
	_measured.clear()
	_lines.clear()
	edit = {}
	edit_index = -1
	var want := debug_pick if EDITORS.has(debug_pick) else "none"
	if Net.is_host() and pick != want:
		game.host_ev("edit_pick", [want])


# デバッグ起動（play_debug.bat。-- --debug --editor=cm）：選び方ができるまでの、試す手段
func setup() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--editor="):
			debug_pick = arg.trim_prefix("--editor=")


func _physics_process(delta: float) -> void:
	if game == null or not Net.is_host() or game.get("production") == null:
		return
	if game.state == game.S.TAKE and not game.take_held():
		_measure()
	elif game.state == game.S.REPLAY and not edit.is_empty() and _screening():
		if edit.has("reel"):
			_reel_step(delta)
		else:
			_warp(delta)
	elif game.state != game.S.REPLAY and not edit.is_empty() and not _screening() and edit_index >= 0 and _rolled:
		# 試写会が終わった：編集を外す（このあとの、ふつうの見返しには掛けない）
		game.host_ev("edit_on", [-1, {}])
	if game.state == game.S.REPLAY and _screening():
		_rolled = true


# いま、その編集のテイクを試写会で流しているか
func _screening() -> bool:
	var premiere: Node = game.hooks.feature("premiere")
	return premiere != null and int(premiere.screening) == edit_index and edit_index >= 0


# 誰も映っていない間・班が映り込んだ間を、テイクの時計で控える
func _measure() -> void:
	var t := float(game.take_t)
	# 見るのは、いま出番の役者だけ（出番でない役者が後ろに立っていても、「映っている」に数えない）。
	# 出番の役者が 1 人もいない間は、測らない（全部が「間」になって、切りすぎるのを防ぐ）
	var frame: Dictionary = game.judge.frame
	var actors: Array = frame.get("actors", [])
	var present: Array = frame.get("present", [])
	var shown := present.is_empty()
	for aid: Variant in present:
		if int(aid) >= 0 and int(aid) < actors.size():
			var seen_actor: Dictionary = actors[int(aid)]
			shown = shown or bool(seen_actor.get("shown", false))
			# その役者が、一番大きく映った時刻（寄りの絵）を控える。編集の台本が、一人ずつ見せる所に使う
			var big := float(seen_actor.get("h", 0.0))
			if bool(seen_actor.get("shown", false)) and (not _faces.has(int(aid)) or big > float(_faces[int(aid)][1]) + 0.02):
				_faces[int(aid)] = [t, big, bool(seen_actor.get("head", true))]
	if not shown and _dead_from < 0.0:
		_dead_from = t
	elif shown and _dead_from >= 0.0:
		if t - _dead_from >= DEAD_MIN:
			_dead.append([_dead_from, t])
		_dead_from = -1.0
	var notes: RefCounted = game.production.notes
	var crew := float(notes.crew_seconds) if notes != null else 0.0
	var seen := crew > _crew_before + 0.0001
	_crew_before = crew
	if seen and _cameo_from < 0.0:
		_cameo_from = t
	elif not seen and _cameo_from >= 0.0:
		_cameo.append([_cameo_from, t])
		_cameo_from = -1.0


# ---- 頼む・組む（ホスト） ----

# だれに頼むかを決める（ホスト）。お金は、納品の精算で引く
func host_pick(id: String) -> void:
	if Net.is_host() and EDITORS.has(id):
		game.host_ev("edit_pick", [id])


# 試写会の反応の予定を組む時（features/premiere.gd の _plan）に、編集も組んで、全員へ配る
func hook_premiere_cues(index: int) -> Array:
	edit_index = -1
	_lines.erase(index)
	if pick == "none" or game.production == null or index < 0 or index >= (game.takes as Array).size():
		game.host_ev("edit_on", [index, {}])
		return []
	var premiere: Node = game.hooks.feature("premiere")
	var m: Dictionary = _measured.get(index, {})
	var job: Dictionary = game.production.job()
	var d := {
		"dur": float(game.takes[index].get("dur", 0.0)),
		"passes": (premiere._times.get(index, []) as Array).duplicate() if premiere != null else [],
		"dead": m.get("dead", []), "cameo": m.get("cameo", []), "bursts": m.get("bursts", []),
		"faces": m.get("faces", []), "burst_info": m.get("burst_info", []),
		"job": str(job.get("title", "")), "company": str(game.production.company_name()) if game.production.has_method("company_name") else "",
		"genre": genre_of(job), "titles": game.scene_titles(), "net": bool(job.get("debut", false)),
	}
	var seed_value := hash([int(game.production.chosen_job), int(game.production.day), index, int(float(d["dur"]) * 10.0)])
	var made := build_edit(pick, d, seed_value)
	_lines[index] = made["lines"]
	last_lines = made["lines"]
	var cues: Array = made["cues"]
	var send := made.duplicate(true)
	send.erase("lines")
	send.erase("cues")
	game.host_ev("edit_on", [index, send])
	return cues


# その時刻は、編集で切られるか（試写会が、切った所の映り込みに触れないために聞く）
func cut_at(t: float) -> bool:
	if edit.has("reel"):
		# 編集の台本：本編（静かにしない行）に入っていない時刻は、切られた扱い（NG のおまけに出した映り込みには、触れない）
		for s: Array in edit["reel"]:
			var from := float(s[2])
			var to := from + (float(s[1]) - float(s[0])) * float(s[3])
			if not bool(s[5]) and t >= from - 0.1 and t <= to + 0.1:
				return false
		return true
	for c: Array in edit.get("cuts", []):
		if t >= float(c[0]) - 0.6 and t <= float(c[1]):
			return true
	return false


# 精算の行（編集代と、編集の出来）。編集して流したテイクだけ
func hook_fee_lines(index: int) -> Array:
	return (_lines.get(index, []) as Array).duplicate(true)


func hook_events() -> Array:
	return ["edit_pick", "edit_on", "edit_clock"]


func hook_event(n: String, a: Array) -> void:
	match n:
		"edit_pick":
			pick = str(a[0])
		"edit_on":
			edit_index = int(a[0])
			edit = (a[1] as Dictionary).duplicate(true)
			_rep_done = []
			_rep_done.resize((edit.get("reps", []) as Array).size())
			_rep_done.fill(0)
			_again = []
			_again_i = 0
			_last_t = 0.0
			_loops = 0
			_rolled = false
			_reel_on = false
			out_t = 0.0
			_show_i = 0
			_crop_key = ""
		"edit_clock":
			# 台本の時計（ホストから）。ずれが大きい時だけ合わせる
			if not Net.is_host() and absf(out_t - float(a[0])) > 0.12:
				out_t = float(a[0])


# ---- 見返しの時計を動かす（ホスト）：切る・遅くする・くり返す ----

func _warp(delta: float) -> void:
	var t := float(game.replay_t)
	for c: Array in edit.get("cuts", []):
		if t >= float(c[0]) and t < float(c[1]):
			game.replay_t = float(c[1])
			return
	var reps: Array = edit.get("reps", [])
	for i in reps.size():
		var r: Array = reps[i]
		if t >= float(r[0]) and int(_rep_done[i]) < int(r[2]) - 1:
			_rep_done[i] = int(_rep_done[i]) + 1
			var back := maxf(float(r[0]) - float(r[1]), 0.0)
			# くり返す間の合図（爆発）を、もう一度出す（見返しの合図は、前にしか進まない）
			_again = []
			for e: Array in game._replay["events"]:
				if str(e[1]) == "burst" and float(e[0]) >= back and float(e[0]) < float(r[0]):
					_again.append(e)
			_again_i = 0
			game.replay_t = back
			game._replay_i = 0
			return
	while _again_i < _again.size() and float(_again[_again_i][0]) <= t:
		game.ev.rpc(_again[_again_i][1], _again[_again_i][2])
		_again_i += 1
	for s: Array in edit.get("slows", []):
		if t >= float(s[0]) and t < float(s[1]):
			game.replay_t = t - delta * (1.0 - float(s[2]))
			return


# ---- 編集の台本を流す（ホスト）：出来上がりの秒 → 素材の時刻。合図も、ここから出す ----

func _reel_step(delta: float) -> void:
	var reel: Array = edit["reel"]
	var events: Array = game._replay["events"]
	if not _reel_on:
		_reel_on = true
		out_t = 0.0
		_seg_i = -1
		_clock_t = 0.0
	out_t += delta
	# 見返しの本体（main.gd）には、合図を出させない（順番を変えると、前にしか進まない合図が合わなくなる）
	game._replay_ev = events.size()
	if out_t >= float(edit.get("out", 0.0)) or reel.is_empty():
		game.replay_t = float(game._replay["dur"]) + 0.3      # 終わり：次のコマで、見返しが終わる
		return
	var i: int = Reel.seg_at(reel, out_t, maxi(_seg_i, 0))
	var seg: Array = reel[i]
	var src: float = Reel.src_at(seg, out_t)
	if i != _seg_i:
		var jumped := _seg_i < 0 or absf(src - _src_prev) > 0.2
		if jumped:
			_seek(events, _src_prev if _seg_i >= 0 else 0.0, src)
			_src_prev = src - 0.0005
		_seg_i = i
	_emit(events, _src_prev, src, bool(seg[5]))
	if src < float(game.replay_t):
		game._replay_i = 0          # コマの位置は、前にしか進まない。戻る時は、頭から探し直させる
	_src_prev = src
	game.replay_t = src - delta     # 本体は、次のコマで delta を足してから姿を当てる
	_clock_t -= delta
	if _clock_t <= 0.0 and Net.has_peers():
		_clock_t = CLOCK_SEC
		game.host_ev("edit_clock", [out_t])


# 素材の a〜b の間の合図を出す。曲は出さない（編集者の曲が鳴っている）。静かな行では、効果音と爆発も出さない
func _emit(events: Array, a: float, b: float, quiet: bool) -> void:
	if b <= a:
		return
	for e: Array in events:
		var at := float(e[0])
		if at <= a:
			continue
		if at > b:
			break
		var n := str(e[1])
		if n == "music" or (quiet and n in ["sfx", "burst", "dash_dust", "fuse"]):
			continue
		game.ev.rpc(n, e[2])


# 飛んだ時：採用カメラは、飛んだ先の時刻の物に。前へ飛んだ時は、とばした間に起きた「物の状態が変わる合図」だけ出す
func _seek(events: Array, from: float, to: float) -> void:
	var cam: Array = []
	for e: Array in events:
		var at := float(e[0])
		if at > to:
			break
		var n := str(e[1])
		if n == "camera_program":
			cam = e
		elif at > from and n in ["pop", "carton", "stage_fx", "perform"]:
			game.ev.rpc(n, e[2])
	if not cam.is_empty():
		game.ev.rpc("camera_program", cam[2])


# ---- 編集の台本を見せる（全員）：寄り・色・字・曲。出来上がりの秒（out_t）から ----

func _reel_show(delta: float) -> void:
	var reel: Array = edit["reel"]
	if not _reel_on and not Net.is_host():
		_reel_on = true
		out_t = 0.0
	if not Net.is_host():
		out_t += delta
	var t := out_t
	_play_music(t)
	_band.visible = false
	_sticker.visible = false
	_mark.visible = false
	if reel.is_empty():
		return
	_show_i = Reel.seg_at(reel, t, _show_i)
	var seg: Array = reel[_show_i]
	var crop: Array = seg[4]
	var zoom := 1.0
	var want := Vector2(0.5, 0.5)
	if crop.size() >= 4:
		var k := clampf((t - float(seg[0])) / maxf(float(seg[1]) - float(seg[0]), 0.01), 0.0, 1.0)
		zoom = lerpf(float(crop[2]), float(crop[3]), k * k * (3.0 - 2.0 * k))
		want = _crop_point(crop)
	# 寄る相手が替わった時は、すぐ替える。同じ相手の間は、なめらかに追う
	var key := str(crop.slice(0, 2)) if crop.size() >= 2 else ""
	if key != _crop_key:
		_crop_key = key
		_center = want
	else:
		_center = _center.lerp(want, 1.0 - exp(-10.0 * delta))
	var grade := int(edit.get("grade", 0))
	var bars := 0.0
	var flash := 0.0
	var dim := 0.0
	var foot := 0.0
	var rgb := 0.0
	var duo := 0.0
	var duo_i := 0
	var invert := 0.0
	var shake := Vector2.ZERO
	var window := false
	var words: Array = []
	for f: Array in edit.get("fx", []):
		var a := float(f[0])
		var b := float(f[1])
		if t < a or t >= b:
			continue
		var kind := str(f[2])
		var k := clampf((t - a) / maxf(b - a, 0.01), 0.0, 1.0)
		match kind:
			"look":
				grade = int(f[4])
			"bars":
				bars = 0.11 * clampf((b - t) / maxf(float(f[4]), 0.01), 0.0, 1.0)
			"flash":
				flash = maxf(flash, 1.0 - k)
			"dim":
				dim = maxf(dim, float(f[4]) * clampf((t - a) / 0.2, 0.0, 1.0))
			"shake":
				shake = Vector2(sin(t * 131.0), cos(t * 173.0)) * 0.012 * (1.0 - k)
				zoom = maxf(zoom, 1.03)
			"rgb":
				rgb = maxf(rgb, 0.012 * (1.0 - k))
			"duo":
				duo = 1.0
				duo_i = int(f[4]) % DUO.size()
			"strobe":
				invert = 1.0 if int((t - a) / maxf(float(f[4]), 0.01)) % 2 == 0 else 0.0
			"pulse":
				# 拍ごとに、小さく寄って戻る
				var phase := fmod(t - a, maxf(float(f[4]), 0.01)) / maxf(float(f[4]), 0.01)
				zoom *= 1.0 + 0.035 * pow(1.0 - phase, 3.0)
			"window":
				window = true
			_:
				words.append([kind, str(f[3]), t - a, b - t, int(f[4])])
				if kind in ["t_name", "t_lower", "t_note", "t_end", "t_sub", "t_build"]:
					foot = maxf(foot, 0.5 * minf(clampf((t - a) / 0.3, 0.0, 1.0), clampf((b - t) / 0.3, 0.0, 1.0)))
	zoom = clampf(zoom, 1.0, Reel.ZOOM_MAX * 1.1)
	var half := 0.5 / zoom
	var center := Vector2(clampf(_center.x, half, 1.0 - half), clampf(_center.y, half, 1.0 - half))
	_flash.color = Color(1, 1, 1, flash * 0.85)
	_mat.set_shader_parameter("zoom", zoom)
	_mat.set_shader_parameter("center", center)
	_mat.set_shader_parameter("mirror", 0.0)
	_mat.set_shader_parameter("invert", invert)
	_mat.set_shader_parameter("rainbow", 0.0)
	_mat.set_shader_parameter("clock", t)
	_mat.set_shader_parameter("grade", grade)
	_mat.set_shader_parameter("bars", bars)
	_mat.set_shader_parameter("dim", dim)
	_mat.set_shader_parameter("shake", shake)
	_mat.set_shader_parameter("rgb", rgb)
	_mat.set_shader_parameter("duo", duo)
	_mat.set_shader_parameter("duo_a", Vector3(DUO[duo_i][0].r, DUO[duo_i][0].g, DUO[duo_i][0].b))
	_mat.set_shader_parameter("duo_b", Vector3(DUO[duo_i][1].r, DUO[duo_i][1].g, DUO[duo_i][1].b))
	_mat.set_shader_parameter("foot", foot)
	_mat.set_shader_parameter("win", Vector4(NG_WINDOW.position.x, NG_WINDOW.position.y, NG_WINDOW.size.x, NG_WINDOW.size.y) if window else Vector4.ZERO)
	_type.show_items(words)
	_type_diff.show_items(words)
	# 字の形の窓：黒い地の上に、字の中だけ絵
	var masked: bool = _type_mask.show_items(words)
	_mask_bg.visible = masked
	_type_mask.visible = masked
	if masked:
		var pic: Rect2 = _type_mask.picture()
		_mask_film.position = pic.position
		_mask_film.size = pic.size
		_mask_film.texture = _dressed.texture


# 寄る先を、絵の中の割合で（役者の頭・世界の中の点は、いまの撮影カメラで映る位置。映っていなければ、真ん中）
func _crop_point(crop: Array) -> Vector2:
	var world := Vector3.ZERO
	match str(crop[0]):
		"uv":
			return Vector2(float(crop[1][0]), float(crop[1][1]))
		"actor":
			var aid := int(crop[1])
			if aid < 0 or aid >= (game.actors as Array).size():
				return Vector2(0.5, 0.45)
			world = game.actors[aid].head_pos()
		"at":
			world = Vector3(float(crop[1][0]), float(crop[1][1]), float(crop[1][2]))
	var camera: Node = game.program_camera()
	if camera == null or not camera.get("view_cam") is Camera3D:
		return Vector2(0.5, 0.45)
	var cam: Camera3D = camera.view_cam
	if cam.is_position_behind(world):
		return Vector2(0.5, 0.45)
	var size := Vector2((camera.view as SubViewport).size)
	var p := cam.unproject_position(world) / size
	return Vector2(clampf(p.x, 0.0, 1.0), clampf(p.y, 0.0, 1.0))


# 編集者の曲を、台本の時計に合わせて鳴らす（無ければ、無音）。撮影の時の曲は止める
func _play_music(t: float) -> void:
	if Sfx.current_music() != "":
		Sfx.stop_music(0.05)
	var track := str(edit.get("music", ""))
	if _music == null:
		_music = AudioStreamPlayer.new()
		_music.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
		_music.volume_db = -5.0
		add_child(_music)
	if track != _music_name:
		_music_name = track
		var path := MUSIC_DIR + track + ".res"
		_music.stream = load(path) if track != "" and ResourceLoader.exists(path) else null
	if _music.stream == null:
		return
	if t >= _music.stream.get_length():
		if _music.playing:
			_music.stop()
		return
	if not _music.playing:
		_music.play(maxf(t, 0.0))
	elif absf(_music.get_playback_position() - t) > 0.3:
		_music.seek(maxf(t, 0.0))


func _stop_music() -> void:
	if _music != null and _music.playing:
		_music.stop()


# ---- 画面（全員）：色・寄り・テロップ・札 ----

func _process(_delta: float) -> void:
	if game == null or game.get("production") == null:
		return
	var premiere: Node = game.hooks.feature("premiere")
	var on: bool = not edit.is_empty() and str(edit.get("id", "none")) != "none" and game.state == game.S.REPLAY and premiere != null and int(premiere.screening) == edit_index
	if not on:
		_undress()
		return
	if not _dress(premiere):
		return
	if edit.has("reel"):
		_reel_show(_delta)
		return
	_type.show_items([])
	_type_diff.show_items([])
	_type_mask.visible = false
	_mask_bg.visible = false
	for name: String in ["rgb", "duo", "foot"]:
		_mat.set_shader_parameter(name, 0.0)
	_mat.set_shader_parameter("win", Vector4.ZERO)
	var t := float(game.replay_t)
	if t < _last_t - 0.5:
		_loops += 1
	var zoom := 1.0
	var center := Vector2(0.5, 0.5)
	var mirror := 0.0
	var invert := 0.0
	var rainbow := 0.0
	var flash := 0.0
	var dim := 0.0
	var bars := float(edit.get("bars", 0.0))
	var shake := Vector2.ZERO
	_band.visible = false
	_sticker.visible = false
	_mark.visible = false
	for f: Array in edit.get("fx", []):
		var a := float(f[0])
		var b := float(f[1])
		var kind := str(f[2])
		# 始まった瞬間の音（各自の画面で 1 回）
		if _last_t < a and t >= a and t - _last_t < 1.0:
			match kind:
				"telop":
					Sfx.play("ui_ok", null, -4.0)
				"sticker":
					Sfx.play("success_fanfare", null, -6.0)
				"mark", "mirror", "invert", "rainbow", "zoom":
					Sfx.play("ui_select", null, -3.0)
		if t < a or t >= b:
			continue
		var k := clampf((t - a) / maxf(b - a, 0.01), 0.0, 1.0)
		match kind:
			"telop":
				_band.visible = true
				_band_text.text = str(f[3])
				var slide := clampf((t - a) / 0.18, 0.0, 1.0)
				# 右下へ、右から滑り込む（左下は、依頼主の顔・再生数の札と重なる）
				var rest := _over.size.x - _band.size.x - 96.0
				_band.position = Vector2(lerpf(_over.size.x + 40.0, rest, 1.0 - pow(1.0 - slide, 3.0)), _over.size.y - 168.0)
			"punch":
				zoom = maxf(zoom, lerpf(1.12, 1.0, k))
			"sticker":
				_sticker.visible = true
				if _sticker_words != str(f[3]):
					_sticker_words = str(f[3])
					_sticker.queue_redraw()
				var pop := clampf((t - a) / 0.22, 0.0, 1.0)
				_sticker.scale = Vector2.ONE * lerpf(2.2, 1.0, 1.0 - pow(1.0 - pop, 3.0))
				_sticker.rotation = lerpf(-0.6, -0.16, pop)
			"zoom":
				zoom = maxf(zoom, lerpf(1.0, 2.2, clampf((t - a) / 0.12, 0.0, 1.0)))
				center = Vector2(0.5, 0.36)
			"mirror":
				mirror = 1.0
			"invert":
				invert = 1.0
			"rainbow":
				rainbow = 1.0
			"flash":
				flash = maxf(flash, 1.0 - k)
			"bars":
				bars = maxf(bars, 0.105 * minf(clampf((t - a) / 0.35, 0.0, 1.0), clampf((b - t) / 0.35, 0.0, 1.0)))
			"shake":
				var amp := 0.012 * (1.0 - k)
				shake = Vector2(sin(t * 131.0), cos(t * 173.0)) * amp
				zoom = maxf(zoom, 1.03)
			"mark":
				_mark.visible = true
				_mark.text = str(f[3])
				zoom = maxf(zoom, 1.5)
			"count":
				# 爆発をくり返している間、右上に「×2」「×3」
				_mark.visible = _loops > 0
				_mark.text = "×%d" % (_loops + 1)
	_flash.color = Color(1, 1, 1, flash * 0.85)
	_mat.set_shader_parameter("zoom", zoom)
	_mat.set_shader_parameter("center", center)
	_mat.set_shader_parameter("mirror", mirror)
	_mat.set_shader_parameter("invert", invert)
	_mat.set_shader_parameter("rainbow", rainbow)
	_mat.set_shader_parameter("clock", t)
	_mat.set_shader_parameter("grade", int(edit.get("grade", 0)))
	_mat.set_shader_parameter("bars", bars)
	_mat.set_shader_parameter("dim", dim)
	_mat.set_shader_parameter("shake", shake)
	_last_t = t


# スクリーンの絵（premiere.gd の _film）に、色の材質と、重ねる物を付ける
func _dress(premiere: Node) -> bool:
	var film: TextureRect = premiere.get("_film")
	if film == null:
		return false
	if _mat == null:
		var shader := Shader.new()
		shader.code = FILM_SHADER
		_mat = ShaderMaterial.new()
		_mat.shader = shader
	if _dressed != film:
		_dressed = film
		film.material = _mat
	if _over == null:
		_build_over(film)
	_over.visible = true
	return true


func _undress() -> void:
	if _dressed != null and is_instance_valid(_dressed):
		_dressed.material = null
	_dressed = null
	if _over != null:
		_over.visible = false
	_stop_music()


func _build_over(film: TextureRect) -> void:
	_over = Control.new()
	_over.name = "EditOverlay"
	_over.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.offset_top = film.offset_top
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.clip_contents = true
	film.get_parent().add_child(_over)
	film.get_parent().move_child(_over, film.get_index() + 1)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.add_child(_flash)
	# CM のテロップ：黄色い帯に、赤い太い字（通販番組の安い帯。縁取りは付けない）
	_band = PanelContainer.new()
	_band.add_theme_stylebox_override("panel", UI.box(UI.TAPE, UI.STAMP_RED, 0, 0, 34, 10))
	_band.rotation = -0.035
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band_text = UI.label("", 64, UI.STAMP_RED, "title")
	_band.add_child(_band_text)
	_over.add_child(_band)
	# 「格安！」の札（ぎざぎざの赤い丸に、黄色い字）
	_sticker = Control.new()
	_sticker.position = Vector2(1010, 150)
	_sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sticker.draw.connect(_draw_sticker)
	_over.add_child(_sticker)
	# 編集の台本（名匠・ド派手）の字：帯も板も敷かない（edit/reel_type.gd）。下から、字の形の窓 → 絵との差 → ふつうの字
	_mask_bg = ColorRect.new()
	_mask_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mask_bg.color = Color(0.02, 0.02, 0.025)
	_mask_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask_bg.visible = false
	_over.add_child(_mask_bg)
	_type_mask = ReelType.new()
	_type_mask.mode = "mask"
	_type_mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	_type_mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	_type_mask.visible = false
	_over.add_child(_type_mask)
	_mask_film = TextureRect.new()
	_mask_film.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mask_film.stretch_mode = TextureRect.STRETCH_SCALE
	_mask_film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mask_film.material = _mat
	_type_mask.add_child(_mask_film)
	# 暗い絵でも字の形が読めるように、字の中に黄色を薄く足す
	var tint := ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.color = Color(UI.TAPE, 0.3)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_mask.add_child(tint)
	_type_diff = ReelType.new()
	_type_diff.mode = "diff"
	_type_diff.set_anchors_preset(Control.PRESET_FULL_RECT)
	var diff := Shader.new()
	diff.code = DIFF_SHADER
	var diff_mat := ShaderMaterial.new()
	diff_mat.shader = diff
	_type_diff.material = diff_mat
	_over.add_child(_type_diff)
	_type = ReelType.new()
	_type.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over.add_child(_type)
	_over.move_child(_flash, _over.get_child_count() - 1)
	# 前衛の「！？」と、くり返しの「×3」
	_mark = UI.label("", 150, UI.TAPE, "title")
	_mark.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mark.offset_left = -420
	_mark.offset_right = -110
	_mark.offset_top = 40
	_mark.offset_bottom = 240
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mark.rotation = 0.1
	_over.add_child(_mark)


func _draw_sticker() -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var r := 128.0 if i % 2 == 0 else 104.0
		pts.append(Vector2.from_angle(TAU * float(i) / 28.0) * r)
	_sticker.draw_colored_polygon(pts, UI.STAMP_RED)
	var font: Font = UI.fnt("title")
	var size := 66
	var width := font.get_string_size(_sticker_words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_sticker.draw_string(font, Vector2(-width * 0.5, 24.0), _sticker_words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UI.TAPE)
