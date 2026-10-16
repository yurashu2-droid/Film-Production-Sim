extends RefCounted
## 見立て：どの物を何の役に使うか。物ごとの属性タグで「らしさ」とコンボを採点する。
##
## ・役は台本ごとに決まっている（SCRIPT_ROLES）。どの物でも、どの役にも付けられる。
## ・役が好む属性（ROLES の likes）と物の属性（PROPS の attrs）が重なるほど「らしい」。
##   0個＝むりやり / 1個＝それっぽい / 2個以上＝ぴったり。
##   むりやりでも失格にはしない。ギャラが少し減るだけ。
## ・別々の役に、同じ属性（THEMES にあるもの）の物を使うとコンボで、ギャラが増える。
##   NAMED は名前つきの特別なコンボ。
## ・場面が成立したかどうか（映っているか・順序）は judge.gd が見る。ここは「何を使ったか」だけ。
##
## 物を増やすときは PROPS に1行足す。
##   attrs：属性タグ（2〜3個が目安）
##   role ：何も決めなくても付いている役（その役専用に作られた小道具だけ）
##   fit  ：属性の数え方と違う「らしさ」にしたいときだけ {役: 0〜2}
##   lock ：役を付け替えられない物（爆弾は爆発するための物なので、爆発役のまま）
##   joker：ジョーカー（等身大パネル）。何か描いてあれば、どの役でも「それっぽい」。
##          さらにコンボを1つだけ完成させる（ほかの役の物と同じ属性を持っていることにできる）。
##          白紙のまま（印 "blank"）なら、ただの白い板：むりやりで、コンボにも加われない

const GRADES := [
	{"name": "むりやり", "coins": -60},
	{"name": "それっぽい", "coins": 0},
	{"name": "ぴったり", "coins": 60},
]
const COMBO_COINS := {2: 120, 3: 300}     # 同じ属性でそろえた役の数 → コイン
const NAMED_COINS := 220
const MAX_COMBOS := 3
const LIKE_COINS := 60                    # 依頼主の好みの属性の物を使った役ひとつにつき
# 爆弾に火薬をたくさん入れた大きな爆発（量の段階 → 呼び名とコイン。段階は fx_box.gd の stage_of）
const BIG_BOOM := {2: ["大爆発（火薬たっぷり）", 120], 3: ["超・大爆発（火薬を袋ごと）", 250]}
const MIN_SEEN := 0.5                     # 本番でこの秒数映った物だけを数える

const ROLES := {
	"castle": {"name": "城", "likes": ["石", "建物", "背が高い", "おとぎ話"]},
	"moon": {"name": "月", "likes": ["丸い", "光る"]},
	"monster": {"name": "怪獣", "likes": ["生き物", "こわい"]},
	"city": {"name": "街", "likes": ["建物", "街角", "乗り物", "四角い"]},
	"boom": {"name": "爆発", "likes": ["火", "はで"]},
	# 名場面のパロディの役（2026-10-16）
	"ruins": {"name": "遺跡", "likes": ["石", "建物", "自然"]},
	"relic": {"name": "秘宝", "likes": ["お宝", "光る"]},
	"bigrock": {"name": "大岩", "likes": ["丸い", "石"]},
	"door": {"name": "玄関", "likes": ["建物", "四角い", "街角"]},
	"xmas": {"name": "ツリー", "likes": ["自然", "光る", "背が高い"]},
	"bike": {"name": "自転車", "likes": ["乗り物", "丸い"]},
	"woods": {"name": "森", "likes": ["自然", "背が高い"]},
	"ship": {"name": "船", "likes": ["乗り物", "水まわり", "背が高い"]},
	"sea": {"name": "海", "likes": ["水まわり", "自然", "風"]},
	"roof": {"name": "屋上", "likes": ["建物", "街角", "背が高い"]},
	"agent": {"name": "追っ手", "likes": ["こわい", "機械"]},
	"steps": {"name": "階段", "likes": ["建物", "背が高い", "石"]},
	"summit": {"name": "頂上", "likes": ["自然", "背が高い", "石"]},
	"noodle": {"name": "カップ麺", "likes": ["食べ物", "丸い"]},
	"kettle": {"name": "やかん", "likes": ["水まわり", "火", "機械"]},
	"car": {"name": "車", "likes": ["乗り物", "機械"]},
	"street": {"name": "街並み", "likes": ["街角", "光る", "建物"]},
}
# 台本ごとの役。怪獣映画の爆発は「怪獣の技」として撃ち出される
const SCRIPT_ROLES := {
	"castle": ["castle", "moon", "boom"],
	"kaiju": ["monster", "city", "boom"],
	# 名場面のパロディ（production_flow.gd の JOBS の "script"）。最初の役が、その場面の主役の物
	"trap": ["bigrock", "relic", "ruins"],
	"home_alone": ["door", "xmas"],
	"moon_bike": ["moon", "bike", "woods"],
	"ship": ["ship", "sea"],
	"dodge": ["roof", "agent"],
	"stairs": ["steps", "summit"],
	"noodle": ["noodle", "kettle"],
	"car_cm": ["car", "street"],
}
const SCRIPT_NAMES := {"kaiju": {"boom": "怪獣の技"}}
# 無くても撮れる役（配役表で「まだ」と急かさない）
const OPTIONAL := ["moon", "ruins", "woods", "sea", "agent", "summit", "kettle", "street"]

# コンボになる属性。形や大きさ（丸い・四角い・背が高い）は入れない
const THEMES := ["水まわり", "ばっちい", "食べ物", "火", "機械", "自然", "宇宙", "おとぎ話", "お宝", "石", "街角", "乗り物", "光る", "風"]

const NAMED := [
	{"name": "トイレ怪獣の必殺技", "need": {"monster": ["scrap_toilet"], "boom": ["scrap_poop"]},
		"line": "依頼主『…出たね。出ちゃったね。子どもは大喜びだと思う』"},
	{"name": "スッポン・ミサイル", "need": {"monster": ["scrap_toilet"], "boom": ["scrap_plunger"]},
		"line": "依頼主『トイレが自分で詰まりを直しに来る映画、初めて見たよ』"},
	{"name": "竜の火炎", "need": {"monster": ["dragon_skull"], "boom": ["attr:火"]},
		"line": "依頼主『竜が火を吐いた！ 骨だけなのに！』"},
	{"name": "パイ投げ光線", "need": {"monster": ["attr:食べ物"], "boom": ["scrap_pie"]},
		"line": "依頼主『食べ物で遊ぶなと言いたいが、笑ってしまった』"},
	{"name": "魔女の鍋が噴いた", "need": {"castle": ["attr:おとぎ話"], "boom": ["witch_cauldron"]},
		"line": "依頼主『城の裏で魔女が煮込みに失敗したんだね。わかるよ』"},
]

const PROPS := {
	# --- 会社にある専用の小道具・借り物 ---
	"flat": {"attrs": ["石", "建物", "おとぎ話"], "role": "castle"},
	"plywood": {"attrs": ["石", "建物"], "role": "castle"},
	"ruin": {"attrs": ["石", "建物"], "role": "castle"},
	"balcony": {"attrs": ["建物", "背が高い", "おとぎ話"], "role": "castle"},
	"window": {"attrs": ["建物", "おとぎ話"], "role": "castle"},
	"moon": {"attrs": ["丸い", "光る"], "role": "moon"},
	"tomato_monster": {"attrs": ["生き物", "食べ物", "丸い"], "role": "monster", "fit": {"monster": 2}},
	"dragon_skull": {"attrs": ["生き物", "こわい", "火"], "role": "monster"},
	"fx": {"attrs": ["火", "はで"], "role": "boom", "lock": true},
	"boomflat": {"attrs": ["火"], "role": "boom"},
	"carton": {"attrs": ["紙", "四角い"], "role": "city"},
	"applebox": {"attrs": ["四角い"], "role": "city"},
	# --- ジョーカー ---
	"standin": {"attrs": ["ジョーカー"], "joker": true},
	# --- 役の決まっていない物 ---
	"witch_cauldron": {"attrs": ["火", "おとぎ話", "丸い"]},
	"riser": {"attrs": ["四角い"]},
	"rock": {"attrs": ["石", "丸い", "自然"]},
	"boulder": {"attrs": ["石", "丸い", "自然"]},
	"partition": {"attrs": ["四角い", "背が高い"]},
	"greenscreen": {"attrs": ["四角い"]},
	"sandbag": {"attrs": []},
	"basket": {"attrs": ["四角い"]},
	"rose": {"attrs": ["自然", "おとぎ話"]},
	"letter": {"attrs": ["紙"]},
	"crown": {"attrs": ["おとぎ話", "お宝"]},
	"fish": {"attrs": ["生き物", "食べ物", "水まわり"]},
	"filmcan": {"attrs": ["丸い"]},
	"tape": {"attrs": ["丸い"]},
	"spot": {"attrs": ["光る", "機械", "背が高い"]},
	"boom": {"attrs": ["機械", "背が高い"]},
	"recorder": {"attrs": ["機械", "四角い"]},
	"dolly": {"attrs": ["乗り物", "機械"]},
	"lift_cart": {"attrs": ["乗り物", "機械"]},
	"cleaning_cart": {"attrs": ["水まわり", "ばっちい", "乗り物"]},
	# --- 廃材置き場の物（production_scrap.gd） ---
	"scrap_crane": {"attrs": ["機械", "背が高い", "街角"]},
	"scrap_clock": {"attrs": ["建物", "背が高い", "機械"]},
	"scrap_kiosk": {"attrs": ["建物", "街角"]},
	"scrap_chimney": {"attrs": ["建物", "背が高い", "火"]},
	"scrap_lamp": {"attrs": ["街角", "光る", "背が高い"]},
	"scrap_bridge": {"attrs": ["街角", "自然"]},
	"scrap_bus": {"attrs": ["乗り物", "街角"]},
	"scrap_mushroom": {"attrs": ["自然", "食べ物", "丸い"]},
	"scrap_duck": {"attrs": ["生き物", "水まわり"]},
	"scrap_capsule": {"attrs": ["宇宙", "機械", "丸い"]},
	"scrap_chest": {"attrs": ["お宝", "四角い", "おとぎ話"]},
	"scrap_toilet": {"attrs": ["水まわり", "ばっちい"]},
	"scrap_fan": {"attrs": ["機械", "風", "丸い"]},
	"scrap_column": {"attrs": ["石", "背が高い"]},
	"scrap_arch": {"attrs": ["石", "建物"]},
	"scrap_tree": {"attrs": ["自然", "背が高い"]},
	"scrap_plunger": {"attrs": ["水まわり", "ばっちい"]},
	"scrap_poop": {"attrs": ["ばっちい", "丸い"]},
	"scrap_pie": {"attrs": ["食べ物", "はで"]},
	"scrap_chicken": {"attrs": ["生き物", "食べ物"]},
	"scrap_torch": {"attrs": ["火", "光る"]},
	"scrap_idol": {"attrs": ["お宝", "生き物"]},
	"scrap_tub": {"attrs": ["水まわり", "四角い"]},
	"scrap_fridge": {"attrs": ["食べ物", "機械", "四角い"]},
	"scrap_vending": {"attrs": ["街角", "機械", "四角い"]},
	"scrap_phone": {"attrs": ["街角", "建物", "背が高い"]},
	"scrap_cactus": {"attrs": ["自然", "こわい", "背が高い"]},
	"scrap_campfire": {"attrs": ["火", "自然"]},
	"scrap_train": {"attrs": ["乗り物", "機械"]},
	"scrap_windmill": {"attrs": ["建物", "背が高い", "風"]},
	"scrap_fountain": {"attrs": ["水まわり", "石", "街角"]},
	# --- ゴミ袋・ブルーシートの包みから出てくる物（production_scrap.gd の "bag"） ---
	"scrap_ring_box": {"attrs": ["お宝", "四角い"]},
	"scrap_heart_chocolates": {"attrs": ["食べ物", "紙"]},
	"scrap_perfume": {"attrs": ["水まわり", "光る"]},
	"scrap_hand_mirror": {"attrs": ["光る", "おとぎ話"]},
	"scrap_folding_fan": {"attrs": ["風", "紙"]},
	"scrap_parasol": {"attrs": ["丸い", "背が高い"]},
	"scrap_tulip_bouquet": {"attrs": ["自然", "はで"]},
	"scrap_ribbon_gift": {"attrs": ["四角い", "はで"]},
	"scrap_masquerade_mask": {"attrs": ["おとぎ話", "こわい"]},
	"scrap_magnifying_glass": {"attrs": ["丸い", "光る"]},
	"scrap_detective_notebook": {"attrs": ["紙", "四角い"]},
	"scrap_pocket_watch": {"attrs": ["機械", "丸い", "お宝"]},
	"scrap_skeleton_key": {"attrs": ["お宝", "おとぎ話"]},
	"scrap_evidence_bag": {"attrs": ["紙", "ばっちい"]},
	"scrap_flashlight": {"attrs": ["光る", "機械"]},
	"scrap_detective_badge": {"attrs": ["お宝", "光る"]},
	"scrap_newspaper": {"attrs": ["紙", "街角"]},
	"scrap_treasure_map": {"attrs": ["紙", "お宝"]},
	"scrap_compass": {"attrs": ["機械", "丸い"]},
	"scrap_potion_bottle": {"attrs": ["おとぎ話", "水まわり", "光る"]},
	"scrap_foam_sword": {"attrs": ["おとぎ話", "はで"]},
	"scrap_round_shield": {"attrs": ["丸い", "おとぎ話"]},
	"scrap_star_wand": {"attrs": ["おとぎ話", "光る"]},
	"scrap_royal_scroll": {"attrs": ["紙", "おとぎ話"]},
	"scrap_spell_book": {"attrs": ["おとぎ話", "紙", "こわい"]},
	"scrap_spyglass": {"attrs": ["機械", "水まわり"]},
	"scrap_adventure_satchel": {"attrs": ["お宝", "四角い"]},
	"scrap_teapot": {"attrs": ["水まわり", "丸い", "食べ物"]},
	"scrap_mug": {"attrs": ["食べ物", "丸い"]},
	"scrap_rolling_pin": {"attrs": ["食べ物"]},
	"scrap_frying_pan": {"attrs": ["食べ物", "火", "丸い"]},
	"scrap_banana_peel": {"attrs": ["食べ物", "ばっちい"]},
	"scrap_giant_sandwich": {"attrs": ["食べ物", "四角い"]},
	"scrap_broom": {"attrs": ["ばっちい", "おとぎ話", "背が高い"]},
	"scrap_watering_can": {"attrs": ["水まわり", "自然"]},
	"scrap_travel_suitcase": {"attrs": ["四角い", "乗り物"]},
	"scrap_trophy_cup": {"attrs": ["お宝", "光る"]},
	"scrap_walkie_talkie": {"attrs": ["機械"]},
	"scrap_headset": {"attrs": ["機械"]},
	"scrap_headphones": {"attrs": ["機械", "丸い"]},
	"scrap_lens_case": {"attrs": ["機械", "丸い"]},
	"scrap_tabletop_tripod": {"attrs": ["機械"]},
	"scrap_audio_recorder": {"attrs": ["機械", "四角い"]},
	"scrap_field_mixer": {"attrs": ["機械", "四角い"]},
	"scrap_portable_monitor": {"attrs": ["機械", "光る", "四角い"]},
	"scrap_battery_pack": {"attrs": ["機械", "四角い"]},
	"scrap_battery_charger": {"attrs": ["機械", "四角い"]},
	"scrap_extension_reel": {"attrs": ["機械", "丸い"]},
	"scrap_script_binder": {"attrs": ["紙", "四角い"]},
	"scrap_clipboard": {"attrs": ["紙", "四角い"]},
	"scrap_storyboard_pad": {"attrs": ["紙", "四角い"]},
	"scrap_cue_cards": {"attrs": ["紙", "四角い"]},
	"scrap_color_checker": {"attrs": ["はで", "四角い"]},
	"scrap_focus_chart": {"attrs": ["四角い", "紙"]},
	"scrap_bounce_reflector": {"attrs": ["光る", "丸い"]},
	"scrap_light_flag": {"attrs": ["四角い"]},
	"scrap_spring_clamp": {"attrs": ["機械"]},
	"scrap_articulating_arm": {"attrs": ["機械"]},
	"scrap_interview_mic": {"attrs": ["機械", "街角"]},
	"scrap_small_speaker": {"attrs": ["機械", "四角い"]},
	"scrap_timecode_display": {"attrs": ["機械", "光る"]},
	"scrap_makeup_case": {"attrs": ["四角い", "はで"]},
	"scrap_powder_brush": {"attrs": ["はで"]},
	"scrap_comb": {"attrs": ["ばっちい"]},
	"scrap_costume_hanger": {"attrs": ["四角い"]},
	"scrap_sewing_kit": {"attrs": ["四角い", "おとぎ話"]},
	"scrap_pin_cushion": {"attrs": ["丸い", "こわい"]},
	"scrap_measuring_tape": {"attrs": ["機械", "丸い"]},
	"scrap_prop_wrench": {"attrs": ["機械"]},
	"scrap_folding_step": {"attrs": ["四角い"]},
	"scrap_first_aid_case": {"attrs": ["四角い", "はで"]},
	"scrap_dustpan": {"attrs": ["ばっちい"]},
	"scrap_popcorn_bucket": {"attrs": ["食べ物", "丸い", "はで"]},
	"scrap_hinged_door_wall": {"attrs": ["建物", "四角い", "街角"]},
	"scrap_saloon_swing_doors": {"attrs": ["建物", "街角"]},
	"scrap_barred_cell_gate": {"attrs": ["建物", "こわい", "四角い"]},
	"scrap_barn_double_door": {"attrs": ["建物", "自然", "四角い"]},
	"scrap_sliding_shoji": {"attrs": ["建物", "紙", "四角い"]},
	"scrap_sash_window_wall": {"attrs": ["建物", "四角い"]},
	"scrap_porthole_bulkhead": {"attrs": ["乗り物", "水まわり", "建物"]},
	"scrap_serving_hatch": {"attrs": ["建物", "食べ物", "街角"]},
	"scrap_timber_portal": {"attrs": ["建物", "自然"]},
	"scrap_straight_stair": {"attrs": ["建物", "背が高い"]},
	"scrap_turning_stair": {"attrs": ["建物", "背が高い"]},
	"scrap_access_ramp": {"attrs": ["建物", "街角"]},
	"scrap_trapdoor_platform": {"attrs": ["四角い", "こわい"]},
	"scrap_plank_bridge": {"attrs": ["自然", "こわい"]},
	"scrap_gable_roof": {"attrs": ["建物", "おとぎ話"]},
	"scrap_scenic_fireplace": {"attrs": ["火", "建物"]},
	"scrap_broken_arch": {"attrs": ["石", "建物", "おとぎ話"]},
	"scrap_elevator_facade": {"attrs": ["建物", "機械", "街角"]},
	"scrap_folding_room_corner": {"attrs": ["建物", "四角い"]},
	"scrap_sewer_entry": {"attrs": ["水まわり", "ばっちい", "こわい"]},
	"scrap_director_chair": {"attrs": ["四角い"]},
	"scrap_two_seat_sofa": {"attrs": ["四角い"]},
	"scrap_wing_armchair": {"attrs": ["四角い", "おとぎ話"]},
	"scrap_swivel_bar_stool": {"attrs": ["丸い", "街角"]},
	"scrap_dining_table": {"attrs": ["食べ物", "四角い"]},
	"scrap_writing_desk": {"attrs": ["四角い", "紙"]},
	"scrap_bar_counter": {"attrs": ["街角", "食べ物", "四角い"]},
	"scrap_single_bed": {"attrs": ["四角い"]},
	"scrap_folding_privacy_screen": {"attrs": ["四角い", "背が高い"]},
	"scrap_wardrobe_cabinet": {"attrs": ["四角い", "背が高い", "おとぎ話"]},
	"scrap_open_bookshelf": {"attrs": ["紙", "四角い", "背が高い"]},
	"scrap_filing_cabinet": {"attrs": ["四角い", "紙"]},
	"scrap_reception_desk": {"attrs": ["建物", "四角い"]},
	"scrap_bulb_vanity": {"attrs": ["光る", "はで"]},
	"scrap_pedestal_sink": {"attrs": ["水まわり", "石"]},
	"scrap_kitchen_stove": {"attrs": ["火", "食べ物", "機械"]},
	"scrap_diner_booth": {"attrs": ["食べ物", "街角"]},
	"scrap_upright_piano": {"attrs": ["はで", "四角い"]},
	"scrap_hospital_bed": {"attrs": ["機械", "四角い"]},
	"scrap_lectern": {"attrs": ["四角い", "街角"]},
	"scrap_church_pew": {"attrs": ["建物", "おとぎ話"]},
	"scrap_standing_coatrack": {"attrs": ["背が高い"]},
	"scrap_park_bench": {"attrs": ["街角", "自然"]},
	"scrap_roofed_well": {"attrs": ["水まわり", "石", "おとぎ話"]},
	"scrap_market_stall": {"attrs": ["街角", "食べ物", "建物"]},
	"scrap_bus_shelter": {"attrs": ["街角", "乗り物", "建物"]},
	"scrap_street_mailbox": {"attrs": ["街角", "丸い"]},
	"scrap_direction_signpost": {"attrs": ["街角", "背が高い"]},
	"scrap_traffic_signal": {"attrs": ["街角", "光る", "背が高い"]},
	"scrap_picket_gate": {"attrs": ["街角", "自然"]},
	"scrap_brick_parapet": {"attrs": ["建物", "街角", "石"]},
	"scrap_iron_fence": {"attrs": ["街角", "四角い"]},
	"scrap_layered_pine": {"attrs": ["自然", "背が高い"]},
	"scrap_hedge_arch": {"attrs": ["自然", "おとぎ話"]},
	"scrap_scenic_pond": {"attrs": ["水まわり", "自然"]},
	"scrap_wooden_dock": {"attrs": ["水まわり", "自然"]},
	"scrap_theater_curtain": {"attrs": ["はで", "背が高い"]},
	"scrap_backdrop_roller": {"attrs": ["紙", "背が高い"]},
	"scrap_scenery_wagon": {"attrs": ["乗り物", "四角い"]},
	"scrap_rain_bar_rig": {"attrs": ["水まわり", "機械"]},
	"scrap_smoke_stack_rig": {"attrs": ["火", "建物", "背が高い"]},
	"scrap_starship_console": {"attrs": ["宇宙", "機械", "光る"]},
	"scrap_fake_reactor": {"attrs": ["機械", "光る", "こわい"]},
	"scrap_cartoon_boiler": {"attrs": ["機械", "火"]},
	"scrap_pipe_valve_wall": {"attrs": ["機械", "水まわり"]},
	"scrap_conveyor_belt": {"attrs": ["機械", "四角い"]},
	"scrap_vault_door": {"attrs": ["お宝", "機械", "丸い"]},
	"scrap_oversized_gear_wall": {"attrs": ["機械", "丸い"]},
	"scrap_car_front_shell": {"attrs": ["乗り物", "機械", "街角"]},
	"scrap_rowboat_shell": {"attrs": ["乗り物", "水まわり"]},
	"scrap_rickshaw_cart": {"attrs": ["乗り物", "丸い", "街角"]},
	"scrap_treasure_pedestal": {"attrs": ["お宝", "石", "おとぎ話"]},
	"scrap_waterwheel": {"attrs": ["水まわり", "自然", "丸い"]},
	"scrap_ticket_turnstile": {"attrs": ["街角", "機械", "乗り物"]},
	"scrap_paper_mountain": {"attrs": ["自然", "石", "背が高い"]},
	"scrap_cardboard_bicycle": {"attrs": ["乗り物", "丸い", "紙"]},
}


static func castable(kind: String) -> bool:
	return PROPS.has(kind)


static func is_joker(kind: String) -> bool:
	return bool((PROPS.get(kind, {}) as Dictionary).get("joker", false))


static func locked(kind: String) -> bool:
	return bool((PROPS.get(kind, {}) as Dictionary).get("lock", false))


static func roles_for(story: String) -> Array:
	return SCRIPT_ROLES.get(story, [])


static func role_name(role: String, story: String = "") -> String:
	if role == "":
		return "役なし"
	return str((SCRIPT_NAMES.get(story, {}) as Dictionary).get(role, ROLES[role]["name"]))


# 配役表や札に出す呼び名：「怪獣役」「街役」。爆発は「爆発」「怪獣の技」のまま
static func role_title(role: String, story: String = "") -> String:
	if role == "":
		return "役なし"
	return role_name(role, story) + ("" if role == "boom" else "役")


# ["宇宙", "光る"] → "〔宇宙〕〔光る〕"
static func chips(list: Array) -> String:
	return "".join(list.map(func(a: String) -> String: return "〔%s〕" % a))


static func stars(grade: int) -> String:
	return "★".repeat(grade + 1) + "☆".repeat(2 - grade)


static func default_role(kind: String) -> String:
	return str((PROPS.get(kind, {}) as Dictionary).get("role", ""))


# 物の属性。段ボールに窓の絵を貼る工作（crew_workshop.gd）は「建物」が増える
static func attrs(kind: String, tags: Array = []) -> Array:
	var out: Array = ((PROPS.get(kind, {}) as Dictionary).get("attrs", []) as Array).duplicate()
	if kind == "carton" and "city" in tags and "建物" not in out:
		out.append("建物")
	return out


# らしさ：0＝むりやり / 1＝それっぽい / 2＝ぴったり
# ショールをかけた物（印 "shawl"。ドレスの人の特技）は、むりやりでも、それっぽく見える。
# もとから合っている物（1・2）は変わらない。属性は増えない（コンボや、依頼主の好みには効かない）
static func fit(kind: String, role: String, tags: Array = []) -> int:
	var grade := _plain_fit(kind, role, tags)
	return 1 if grade == 0 and "shawl" in tags and ROLES.has(role) else grade


static func _plain_fit(kind: String, role: String, tags: Array = []) -> int:
	if not ROLES.has(role):
		return 0
	if is_joker(kind):
		return 0 if "blank" in tags else 1
	var fixed: Dictionary = (PROPS.get(kind, {}) as Dictionary).get("fit", {})
	if fixed.has(role):
		return int(fixed[role])
	var n := 0
	for a: String in attrs(kind, tags):
		if a in ROLES[role]["likes"]:
			n += 1
	return mini(n, 2)


# Y を押すたびに替わる順番：らしい役から先に。最後は「役なし」。
# by_fit を false にすると、台本の役の順のまま（らしさを知らない人＝台本を読めない人の順番。順番から答えが分からないように）
static func cycle(kind: String, story: String, current: String, tags: Array = [], by_fit: bool = true) -> String:
	var order: Array = roles_for(story).duplicate()
	if by_fit:
		order.sort_custom(func(a: String, b: String) -> bool:
			var fa := fit(kind, a, tags)
			var fb := fit(kind, b, tags)
			return fa > fb if fa != fb else roles_for(story).find(a) < roles_for(story).find(b))
	order.append("")
	return order[(order.find(current) + 1) % order.size()]


# 採点。used：{役: [{"kind": 種類, "label": 名前, "tags": 印}, ...]}（その役として映った物）
#       likes：依頼主の好みの属性。その属性の物を使った役の数だけ、ギャラが増える
# 返り値：{"roles": [{role, name, items, grade, grade_name, coins}], "combos": [{name, coins, line}],
#          "liked": {attrs, roles, coins}, "coins": 合計}
static func score(story: String, used: Dictionary, likes: Array = []) -> Dictionary:
	var roles: Array = []
	var coins := 0
	for role: String in roles_for(story):
		var list: Array = used.get(role, [])
		if list.is_empty():
			continue
		var sum := 0.0
		var names: Array = []
		for item: Dictionary in list:
			sum += fit(str(item["kind"]), role, item.get("tags", []))
			names.append(str(item["label"]))
		var avg := sum / list.size()
		var grade := 2 if avg >= 1.5 else (1 if avg >= 0.5 else 0)
		coins += int(GRADES[grade]["coins"])
		roles.append({"role": role, "name": role_name(role, story), "items": _tally(names), "grade": grade,
			"grade_name": GRADES[grade]["name"], "coins": GRADES[grade]["coins"]})
	var combos := _combos(story, used)
	# 爆弾の大きな爆発（印 "powder2" / "powder3"）は、コンボと同じ欄に載せる
	for item: Dictionary in used.get("boom", []):
		for bags: int in BIG_BOOM:
			if item["kind"] == "fx" and "powder%d" % bags in item.get("tags", []):
				combos.push_front({"name": str(BIG_BOOM[bags][0]), "coins": int(BIG_BOOM[bags][1]),
					"line": "依頼主『いまの爆発、本物だよね？ 近所から苦情が来てるよ』" if bags >= 3 else ""})
	for combo: Dictionary in combos:
		coins += int(combo["coins"])
	# 依頼主の好み：好みの属性の物を使っている役を数える
	var pleased: Array = []
	for role: String in roles_for(story):
		for item: Dictionary in used.get(role, []):
			var has := false
			for a: String in attrs(str(item["kind"]), item.get("tags", [])):
				has = has or a in likes
			if has:
				pleased.append(role)
				break
	var liked := {"attrs": likes, "roles": pleased.size(), "coins": pleased.size() * LIKE_COINS}
	coins += int(liked["coins"])
	return {"roles": roles, "combos": combos, "liked": liked, "coins": coins, "story": story}


static func _combos(story: String, used: Dictionary) -> Array:
	var out: Array = []
	var named_sets: Array = []
	for recipe: Dictionary in NAMED:
		var need: Dictionary = recipe["need"]
		var ok := true
		for role: String in need:
			if role not in roles_for(story) or not _has_any(used.get(role, []), need[role]):
				ok = false
				break
		if ok:
			out.append({"name": "『%s』" % recipe["name"], "coins": NAMED_COINS, "line": recipe.get("line", "")})
			named_sets.append(need.keys())
	# 属性ごとに、その属性の物を使っている役
	var theme_roles := {}
	for theme: String in THEMES:
		var shared: Array = []
		for role: String in roles_for(story):
			for item: Dictionary in used.get(role, []):
				if theme in attrs(str(item["kind"]), item.get("tags", [])):
					shared.append(role)
					break
		theme_roles[theme] = shared
	# 名前つきのコンボと同じ役の組み合わせなら、二重には数えない
	var covered := func(shared: Array) -> bool:
		for named_roles: Array in named_sets:
			if shared.all(func(r: String) -> bool: return r in named_roles):
				return true
		return false
	# ジョーカー（何か描いてある等身大パネル）は、いちばん得なコンボを1つだけ完成させる
	var joker_role := ""
	for role: String in roles_for(story):
		for item: Dictionary in used.get(role, []):
			if is_joker(str(item["kind"])) and "blank" not in item.get("tags", []):
				joker_role = role
	var joker_theme := ""
	if joker_role != "":
		var best := 0
		for theme: String in THEMES:
			var shared: Array = theme_roles[theme]
			if shared.is_empty() or joker_role in shared or shared.size() >= 3:
				continue
			var joined: Array = roles_for(story).filter(func(r: String) -> bool: return r in shared or r == joker_role)
			if covered.call(joined):
				continue
			var before := 0 if shared.size() < 2 or covered.call(shared) else int(COMBO_COINS[shared.size()])
			var gain := int(COMBO_COINS[mini(joined.size(), 3)]) - before
			if gain > best:
				best = gain
				joker_theme = theme
		if joker_theme != "":
			theme_roles[joker_theme] = roles_for(story).filter(func(r: String) -> bool: return r in theme_roles[joker_theme] or r == joker_role)
	for theme: String in THEMES:
		var shared: Array = theme_roles[theme]
		if shared.size() < 2 or covered.call(shared):
			continue
		out.append({"name": "『%s』でそろえた（%s）%s" % [theme, "・".join(shared.map(func(r: String) -> String: return role_name(r, story))), "※ジョーカー" if theme == joker_theme else ""],
			"coins": int(COMBO_COINS[mini(shared.size(), 3)]), "line": "依頼主『あの絵、誰が描いたの？ 妙に味があった』" if theme == joker_theme else ""})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["coins"]) > int(b["coins"]))
	return out.slice(0, MAX_COMBOS)


static func _has_any(list: Array, wanted: Array) -> bool:
	for item: Dictionary in list:
		for w: String in wanted:
			if w.begins_with("attr:"):
				if w.trim_prefix("attr:") in attrs(str(item["kind"]), item.get("tags", [])):
					return true
			elif item["kind"] == w:
				return true
	return false


# ["段ボール箱", "段ボール箱", "街灯"] → "段ボール箱×2・街灯"
static func _tally(names: Array) -> String:
	var count := {}
	var order: Array = []
	for n: String in names:
		if not count.has(n):
			order.append(n)
		count[n] = int(count.get(n, 0)) + 1
	var parts: Array = []
	for n: String in order:
		parts.append(n if count[n] == 1 else "%s×%d" % [n, count[n]])
	return "・".join(parts)


# 画面に出す文。[[文, コイン], ...]
static func lines(report: Dictionary) -> Array:
	var out: Array = []
	for r: Dictionary in report.get("roles", []):
		out.append(["%s　%s　%s" % [role_title(str(r["role"]), str(report.get("story", ""))), r["items"], r["grade_name"]], int(r["coins"])])
	var liked: Dictionary = report.get("liked", {})
	if int(liked.get("roles", 0)) > 0:
		out.append(["依頼主の好み %s　%d役" % [chips(liked["attrs"]), int(liked["roles"])], int(liked["coins"])])
	for c: Dictionary in report.get("combos", []):
		out.append([str(c["name"]) if str(c["name"]).begins_with("大爆発") or str(c["name"]).begins_with("超") else "コンボ %s" % c["name"], int(c["coins"])])
	return out
