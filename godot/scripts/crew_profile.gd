extends RefCounted
## 一人分の成長。見た目・会社・ネットワークのpeer IDから独立して保存する。
const ROLES := ["actor", "camera", "backstage"]
const NAMES := {"actor":"演者", "camera":"撮影", "backstage":"裏方"}
const ACTIONS := {
	"actor":{"acting":"芝居", "action":"アクション", "ensemble":"共演"},
	"camera":{"framing":"構図", "operation":"本番操作", "lighting":"照明"},
	"backstage":{"cargo":"搬入", "setup":"設営", "effects":"仕掛け"},
}
const THRESHOLDS := [0, 60, 180, 360, 600]
const RUN_STYLES := {"sculpted":"土ぼこり", "mesh":"元の土ぼこり", "kenney":"絵の土ぼこり", "smear":"スミア", "volt":"スミア×雷", "thunder":"雷の疾走", "kick":"蹴り上げ", "scramble":"脚ぐるぐる"}
const BASIC_STYLES := ["sculpted", "mesh", "kenney"]
const UNLOCKS := {"actor":"追加リアクション・走りVFX 5種類", "camera":"構図メモ 2枠", "backstage":"段ボール工作（窓・看板・盾）"}

var xp := {"actor":0, "camera":0, "backstage":0}
var run_style := "sculpted"
var receipts: Array = []
var path := ""
var last_save_error := OK

static func level_for(total: int) -> int:
	var result := 1
	for threshold: int in THRESHOLDS.slice(1):
		if total >= threshold: result += 1
	return result

func level(role: String) -> int:
	return level_for(int(xp.get(role, 0)))

static func clean_xp(data: Dictionary) -> Dictionary:
	var result := {}
	for role: String in ROLES:
		var value: Variant = data.get(role, 0)
		result[role] = clampi(int(value), 0, 100000000) if value is int or (value is float and is_finite(value)) else 0
	return result

static func allowed_style(style: String, actor_xp: int) -> bool:
	return RUN_STYLES.has(style) and (style in BASIC_STYLES or level_for(actor_xp) >= 2)

static func report(totals: Dictionary, contributions: Dictionary) -> Dictionary:
	var result := {}
	for role: String in ROLES:
		var items: Array = []
		var supplied: Variant = contributions.get(role, [])
		if supplied is Array:
			for action: String in ACTIONS[role]:
				if action in supplied: items.append(action)
		var old: int = int(totals.get(role, 0))
		var gained: int = items.size() * 20 + (10 if not items.is_empty() else 0)
		result[role] = {"before_xp":old, "after_xp":old + gained, "before_level":level_for(old), "after_level":level_for(old + gained), "gained":gained, "actions":items}
	return result

func award(receipt: String, contributions: Dictionary) -> Dictionary:
	if receipt.is_empty() or receipt in receipts:
		return {}
	var result := report(xp, contributions)
	for role: String in ROLES:
		xp[role] = result[role].after_xp
	receipts.append(receipt)
	if receipts.size() > 128: receipts.pop_front()
	last_save_error = save()
	return result

func open(filename: String) -> Error:
	path = filename
	if path.is_empty() or not FileAccess.file_exists(path): return OK
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK: return error
	var data: Variant = config.get_value("crew", "xp", {})
	xp = clean_xp(data if data is Dictionary else {})
	var saved: Variant = config.get_value("crew", "receipts", [])
	receipts = saved.filter(func(v: Variant) -> bool: return v is String).slice(-128) if saved is Array else []
	var style: String = str(config.get_value("crew", "run_style", "sculpted"))
	run_style = style if allowed_style(style, xp.actor) else "sculpted"
	return OK

func save() -> Error:
	if path.is_empty(): return OK
	var config := ConfigFile.new()
	config.set_value("crew", "version", 1)
	config.set_value("crew", "xp", xp)
	config.set_value("crew", "run_style", run_style)
	config.set_value("crew", "receipts", receipts)
	var error := config.save(path + ".tmp")
	if error != OK: return error
	return DirAccess.rename_absolute(path + ".tmp", path)
