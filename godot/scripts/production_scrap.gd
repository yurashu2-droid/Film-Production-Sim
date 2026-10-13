extends RefCounted
## 廃材置き場の「無料の小道具・大道具」の一覧。1行足せば新しい物が増える。
## 追加は必ず末尾へ（全参加者で生成順＝物のIDが一致する必要がある。並べ替え禁止）。
##
## kind     : 物の種類名（一意）
## file     : res://assets/production/scrap/ の GLB（拡張子なし）
## label    : 画面に出す名前
## size     : 最長辺をこの長さ(m)に正規化（GLBの向きは Y上・正面+Z・底の中心が原点でなくてもよい）
## mass     : 質量(kg)。1人で運べる範囲（目安 12 以下）
## tags     : 撮影だけモードの judge が読む印。"city"=街の模型 / "monster"=怪獣・生き物 / "castle"=城に見える
##            制作モードでは使わない。何の役にするかは制作班が決め（見立て）、
##            らしさとコンボは production_cast.gd の属性タグで決まる。物を足したら、そちらにも1行足す
## shape    : 当たり判定の種類。"box"=外形の箱 / "cyl"=円柱 / "arch"=両脚と上の梁（くぐれる）。
##            prop_shapes.gd の表に同じ kind があれば、そちら（見た目に合わせた形の組み合わせ）を使い、これは使わない。
##            物を足したら、まずここで決め、見た目とずれるようなら表に形を足す（重ねた写真は tools/collider_shots.gd で撮れる）
## com      : 重心の高さ（高さに対する割合 0〜1）。背の高い物を倒れにくくする（表に "com" があれば、そちらを使う）
## pos      : 会社の敷地での位置 Vector2(x, z)
## yaw      : 向き（ラジアン）。PI で正面(+Z)が北＝事務所側を向く
## one_sided: 正面（+Z）だけが城に見える薄い書割のときだけ true
const ITEMS := [
	# --- 街のミニチュア ---
	{"kind": "scrap_crane", "file": "S098_crane_tower", "label": "ミニ撮影クレーン塔", "size": 1.5, "mass": 6.0,
		"tags": ["city"], "shape": "box", "com": 0.3, "pos": Vector2(44.5, 25.0), "yaw": PI},
	{"kind": "scrap_clock", "file": "S096_giant_clock", "label": "振り子時計", "size": 1.4, "mass": 4.0,
		"tags": ["city"], "shape": "box", "com": 0.3, "pos": Vector2(47.7, 25.0), "yaw": PI},
	{"kind": "scrap_kiosk", "file": "S060_news_kiosk", "label": "新聞の売店（ミニチュア）", "size": 1.0, "mass": 5.0,
		"tags": ["city"], "shape": "box", "com": 0.4, "pos": Vector2(50.9, 25.0), "yaw": PI},
	{"kind": "scrap_chimney", "file": "S020_crooked_chimney", "label": "曲がった煙突", "size": 1.1, "mass": 3.0,
		"tags": ["city"], "shape": "box", "com": 0.3, "pos": Vector2(54.1, 25.0), "yaw": PI},
	{"kind": "scrap_lamp", "file": "S051_street_lamp", "label": "街灯（ミニチュア）", "size": 1.3, "mass": 2.0,
		"tags": ["city"], "shape": "box", "com": 0.12, "pos": Vector2(57.3, 25.0), "yaw": PI},
	{"kind": "scrap_bridge", "file": "S074_arched_garden_bridge", "label": "太鼓橋（ミニチュア）", "size": 1.2, "mass": 2.5,
		"tags": ["city"], "shape": "box", "com": 0.3, "pos": Vector2(60.5, 25.0), "yaw": PI},
	{"kind": "scrap_bus", "file": "S090_bus_front_shell", "label": "バスの正面（書割）", "size": 1.1, "mass": 4.0,
		"tags": ["city"], "shape": "box", "com": 0.3, "pos": Vector2(63.9, 25.0), "yaw": PI},
	# --- 生き物・宇宙 ---
	{"kind": "scrap_mushroom", "file": "S070_giant_mushroom", "label": "巨大キノコ", "size": 1.0, "mass": 4.0,
		"tags": ["monster"], "shape": "box", "com": 0.3, "pos": Vector2(44.5, 28.5), "yaw": PI},
	{"kind": "scrap_duck", "file": "P049_rubber_duck", "label": "ゴムアヒル", "size": 0.8, "mass": 3.0,
		"tags": ["monster"], "shape": "box", "com": 0.4, "pos": Vector2(48.0, 28.5), "yaw": PI},
	{"kind": "scrap_capsule", "file": "S093_space_capsule", "label": "宇宙カプセル", "size": 1.3, "mass": 6.0,
		"tags": ["spaceship"], "shape": "box", "com": 0.35, "pos": Vector2(51.5, 28.5), "yaw": PI},
	# --- 笑える・使い回せる大道具 ---
	{"kind": "scrap_chest", "file": "P029_treasure_chest", "label": "お宝の箱", "size": 0.7, "mass": 5.0,
		"tags": ["treasure"], "shape": "box", "com": 0.4, "pos": Vector2(55.0, 28.5), "yaw": PI},
	{"kind": "scrap_toilet", "file": "S042_cartoon_toilet", "label": "撮影用トイレ", "size": 0.9, "mass": 4.0,
		"tags": ["gag"], "shape": "box", "com": 0.35, "pos": Vector2(58.0, 28.5), "yaw": PI},
	{"kind": "scrap_fan", "file": "S079_large_wind_fan", "label": "大型送風機", "size": 1.2, "mass": 7.0,
		"tags": ["wind"], "shape": "box", "com": 0.3, "pos": Vector2(61.5, 28.5), "yaw": PI},
	{"kind": "scrap_column", "file": "S011_foam_column", "label": "発泡スチロールの神殿柱", "size": 1.8, "mass": 8.0,
		"tags": ["castle"], "shape": "box", "com": 0.25, "pos": Vector2(44.5, 32.0), "yaw": PI},
	{"kind": "scrap_arch", "file": "S010_freestanding_arch", "label": "発泡スチロールのアーチ", "size": 2.2, "mass": 10.0,
		"tags": ["castle"], "shape": "arch", "com": 0.25, "pos": Vector2(48.5, 32.0), "yaw": PI},
	{"kind": "scrap_tree", "file": "S066_broadleaf_tree", "label": "張りぼての木", "size": 1.8, "mass": 6.0,
		"tags": ["tree"], "shape": "box", "com": 0.3, "pos": Vector2(53.0, 32.0), "yaw": PI},
	# --- 2026-10-12 追加：見立てとコンボの材料（水まわり・食べ物・火・街角・機械） ---
	{"kind": "scrap_plunger", "file": "P045_plunger", "label": "スッポン（ラバーカップ）", "size": 0.7, "mass": 0.8,
		"tags": ["gag"], "shape": "box", "com": 0.2, "pos": Vector2(44.5, 35.5), "yaw": PI},
	{"kind": "scrap_poop", "file": "J001_rubber_poop", "label": "ゴムのうんこ（ジョークグッズ）", "size": 0.5, "mass": 1.2,
		"tags": ["gag"], "shape": "box", "com": 0.3, "pos": Vector2(47.0, 35.5), "yaw": PI},
	{"kind": "scrap_pie", "file": "P042_cream_pie", "label": "クリームパイ（投げる用）", "size": 0.45, "mass": 0.6,
		"tags": ["gag"], "shape": "box", "com": 0.4, "pos": Vector2(49.5, 35.5), "yaw": PI},
	{"kind": "scrap_chicken", "file": "P043_rubber_chicken", "label": "ゴムのニワトリ", "size": 0.8, "mass": 0.8,
		"tags": ["monster"], "shape": "box", "com": 0.25, "pos": Vector2(52.0, 35.5), "yaw": PI},
	{"kind": "scrap_torch", "file": "P030_fake_torch", "label": "作り物のたいまつ", "size": 0.8, "mass": 0.8,
		"tags": ["fire"], "shape": "box", "com": 0.25, "pos": Vector2(54.5, 35.5), "yaw": PI},
	{"kind": "scrap_idol", "file": "P031_ancient_idol", "label": "金ピカのフクロウ像", "size": 0.7, "mass": 3.0,
		"tags": ["monster"], "shape": "box", "com": 0.3, "pos": Vector2(57.0, 35.5), "yaw": PI},
	{"kind": "scrap_tub", "file": "S040_clawfoot_tub", "label": "猫足のバスタブ", "size": 1.3, "mass": 9.0,
		"tags": ["gag"], "shape": "box", "com": 0.3, "pos": Vector2(60.5, 35.5), "yaw": PI},
	{"kind": "scrap_fridge", "file": "S044_retro_refrigerator", "label": "レトロ冷蔵庫（中は空）", "size": 1.4, "mass": 9.0,
		"tags": ["city"], "shape": "box", "com": 0.3, "pos": Vector2(44.5, 39.0), "yaw": PI},
	{"kind": "scrap_vending", "file": "S059_vending_machine", "label": "自動販売機（張りぼて）", "size": 1.5, "mass": 9.0,
		"tags": ["city"], "shape": "box", "com": 0.3, "pos": Vector2(47.5, 39.0), "yaw": PI},
	{"kind": "scrap_phone", "file": "S058_phone_booth", "label": "電話ボックス", "size": 1.6, "mass": 8.0,
		"tags": ["city"], "shape": "box", "com": 0.25, "pos": Vector2(50.5, 39.0), "yaw": PI},
	{"kind": "scrap_cactus", "file": "S068_branch_cactus", "label": "サボテン（張りぼて）", "size": 1.5, "mass": 5.0,
		"tags": ["tree"], "shape": "box", "com": 0.25, "pos": Vector2(53.5, 39.0), "yaw": PI},
	{"kind": "scrap_campfire", "file": "S072_campfire_circle", "label": "たき火（作り物）", "size": 1.0, "mass": 5.0,
		"tags": ["fire"], "shape": "box", "com": 0.4, "pos": Vector2(56.5, 39.0), "yaw": PI},
	{"kind": "scrap_train", "file": "S091_train_engine_front", "label": "機関車の正面（書割）", "size": 1.4, "mass": 10.0,
		"tags": ["city"], "shape": "box", "com": 0.3, "pos": Vector2(59.5, 39.0), "yaw": PI},
	{"kind": "scrap_windmill", "file": "S100_scenic_windmill", "label": "風車小屋（ミニチュア）", "size": 1.8, "mass": 9.0,
		"tags": ["castle"], "shape": "box", "com": 0.25, "pos": Vector2(63.0, 39.0), "yaw": PI},
	{"kind": "scrap_fountain", "file": "S053_tiered_fountain", "label": "噴水（ミニチュア）", "size": 1.2, "mass": 8.0,
		"tags": ["city"], "shape": "box", "com": 0.3, "pos": Vector2(64.0, 32.0), "yaw": PI},
]


static func find(kind: String) -> Dictionary:
	for item: Dictionary in ITEMS:
		if item["kind"] == kind:
			return item
	return {}


static func has_kind(kind: String) -> bool:
	return not find(kind).is_empty()


static func kinds() -> Array:
	var result: Array = []
	for item: Dictionary in ITEMS:
		result.append(item["kind"])
	return result
