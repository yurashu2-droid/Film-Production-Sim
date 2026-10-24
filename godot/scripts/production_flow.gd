extends Node
const Office := preload("res://scripts/production_office.gd")
const Assets := preload("res://scripts/production_assets.gd")
const Location := preload("res://scripts/production_location.gd")
const ProductionProp := preload("res://scripts/production_prop.gd")
const MovieProp := preload("res://scripts/production_movie_prop.gd")
const Notes := preload("res://scripts/production_notes.gd")
const Yard := preload("res://scripts/production_yard.gd")
const Look := preload("res://scripts/production_look.gd")
const ScriptProp := preload("res://scripts/production_script_prop.gd")
const MonitorProp := preload("res://scripts/production_monitor_prop.gd")
const Rental := preload("res://scripts/production_rental.gd")
const Display := preload("res://scripts/production_display.gd")
const Cast := preload("res://scripts/production_cast.gd")
const Briefs := preload("res://scripts/production_briefs.gd")
const Talents := preload("res://scripts/cast_talents.gd")
const Slides := preload("res://scripts/production_slides.gd")
# 会社のアップグレード。種類ごとに段階があり、報酬で1段ずつ上げる（levels の0番が最初から持っている物）
const TRACKS := {
	"car": {"title": "車", "levels": [
		{"name": "軽トラ", "cost": 0, "desc": "荷台に安全に積めるのは 12 まで。積みすぎると道中で落ちる"},
		{"name": "ロケバン", "cost": 800, "desc": "荷室が広く 24 まで積める。屋根つきなので、道中で物が落ちない"}]},
	"studio": {"title": "スタジオ", "levels": [
		{"name": "野外の空き地", "cost": 0, "desc": "工事現場のとなりの空き地。ときどき突風が吹く。使えるのは 10分"},
		{"name": "コンテナ倉庫", "cost": 600, "desc": "屋内なので風が入らない。使えるのは 11分"},
		{"name": "撮影スタジオ", "cost": 1200, "desc": "壁と床のそろったスタジオ。使えるのは 12分"}]},
	"monitor": {"title": "モニター", "levels": [
		{"name": "確認用モニターだけ", "cost": 0, "desc": "映像は、置いたモニターのそばでだけ見られる"},
		{"name": "小型モニター", "cost": 500, "desc": "全員の画面の右上に、いつでもカメラの映像が出る"}]},
	"camera": {"title": "カメラ", "levels": [
		{"name": "三脚なし", "cost": 0, "desc": "カメラ本体だけ。段ボールなどを積んで高さを作り、その上に載せて撮る"},
		{"name": "三脚", "cost": 400, "desc": "三脚に載せて、高さと向きを決められる"}]},
	"plan": {"title": "段取り", "levels": [
		{"name": "行き当たりばったり", "cost": 0, "desc": "出発までの準備は 3分"},
		{"name": "段取り表", "cost": 300, "desc": "出発までの準備が 4分 に延びる"}]},
}
# スタジオの段階 → 現場の種類（0=倉庫 1=室内スタジオ 2=野外）
const STUDIO_SITES := [2, 0, 1]
# site: 現場（0=倉庫 1=室内スタジオ 2=野外） / script: 脚本 / bonus: 追加注文の種類 / scenes: 場面の短い名前（ふつうは3つ）
# budget: 依頼主が出す制作費。借り物はこの中からしか払えず、使い残しは会社の儲けになる
const JOBS := [
	{"title":"月下の城と大爆発", "rank":4, "budget":500, "location":"倉庫", "site":0, "script":"castle", "bonus":"first_take", "bonus_title":"一発OKで撮り切る",
		"scenes":["告白（高低差・城・明るさ）", "背後で大爆発", "爆発のあと再会"],
		"description":"廃材で城を作り、告白 → 背後の爆発 → 再会を撮る。見えない裏側は節約していい。"},
	{"title":"わが城と大爆発", "rank":2, "budget":450, "location":"室内スタジオ", "site":1, "script":"castle", "bonus":"no_crew", "bonus_title":"スタッフ映り込み0.5秒以内",
		"scenes":["告白（高低差・城・明るさ）", "背後で大爆発", "爆発のあと再会"],
		"description":"手放した城を、あったことにする。光と構図を工夫しよう。"},
	{"title":"月が主役の夜の城", "rank":3, "budget":480, "location":"野外", "site":2, "script":"castle", "bonus":"moon", "bonus_title":"月を合計2秒映す",
		"scenes":["告白（高低差・城・明るさ）", "背後で大爆発", "爆発のあと再会"],
		"description":"月を主役に、夜の城を撮る。画角の外がどうであれ、映れば映画だ。"},
	{"title":"怪獣、段ボールの街に現る", "rank":2, "budget":600, "location":"野外", "site":2, "script":"kaiju", "bonus":"no_crew", "bonus_title":"スタッフ映り込み0.5秒以内",
		"scenes":["怪獣が街より大きく映る", "逃げる二人の背後で大爆発", "倒れた怪獣の前で勝利"],
		"description":"小さな怪獣をカメラの手前に置けば巨大に見える。段ボールの街を襲わせ、爆発のあとは誰かがこっそり倒そう。"},
	{"title":"お嬢様の大怪獣", "rank":1, "budget":380, "location":"倉庫", "site":0, "script":"kaiju", "bonus":"first_take", "bonus_title":"一発OKで撮り切る",
		"scenes":["怪獣が街より大きく映る", "逃げる二人の背後で大爆発", "倒れた怪獣の前で勝利"],
		"description":"遠近法と段ボールだけで、街ひとつ壊してみせよう。"},
	# 場面の列（production_script.gd の beats）を持つ依頼：5場面を、フィルム1本のテイクで撮り切る。2日目から出る。
	#   board：絵コンテの組（無ければ script と同じ）/ fee_all：全部の場面がそろったときの上乗せ（無ければ 300）
	#   cast_at：見立てを数える場面 [怪獣と街が映った場面, 爆発が映った場面]（無ければ [0, 1]）
	{"title":"怪獣、段ボールの街に現る・完全版", "rank":4, "budget":700, "location":"野外", "site":2, "script":"kaiju", "board":"kaiju5",
		"bonus":"first_take", "bonus_title":"一発OKで撮り切る", "fee_all":400, "cast_at":[1, 2],
		"scenes":["街を歩いてくる", "怪獣あらわる", "怪獣の技で街がこわれる", "怪獣がひとりでに倒れる", "倒れた怪獣の前で勝利"],
		"description":"5場面を、フィルム1本で止めずに撮る。怪獣は出番まで映さず、技で街だけを倒し、最後は寄りで万歳。場面は、台本を読める人が進める。"},
	# カット割りの依頼（production_script.gd の cuts）：同じ5場面を、場面ごとにフィルムを止めて撮る。止めている間に、次の場面の用意（場転）
	{"title":"怪獣ドラマ 第1話", "rank":4, "budget":650, "location":"室内スタジオ", "site":1, "script":"kaiju", "board":"kaiju5",
		"bonus":"no_crew", "bonus_title":"スタッフ映り込み0.5秒以内", "fee_all":400, "cast_at":[1, 2],
		"scenes":["街を歩いてくる", "怪獣あらわる", "怪獣の技で街がこわれる", "怪獣がひとりでに倒れる", "倒れた怪獣の前で勝利"],
		"description":"同じ5場面を、場面ごとにカットを割って撮る。場面が撮れるとフィルムが止まる。止まっている間に、怪獣を出す・火薬を詰める・カメラを寄せる。用意ができたら、台本を読める人が 1 で回す。"},
	# 最初の一本（debut）：会社の紹介動画。1日目は、これだけが来る。ネットに上げたあと、2日目から依頼の電話が来る
	{"title":"わが社の紹介動画（ネット用・30秒）", "rank":1, "budget":300, "location":"会社の前", "site":1, "script":"castle", "board":"pr", "debut":true, "home":true,
		"bonus":"no_crew", "bonus_title":"スタッフ映り込み0.5秒以内", "fee_all":300,
		"scenes":["社員紹介（一人ずつ寄り）", "お城も建てます", "爆発も、します", "ぜんぶ、格安で！（全員集合）"],
		"description":"会社の紹介動画を、会社の前（事務所の正面）で撮る。情報商材の「バズる黄金の4カット」：一人ずつ寄りで社員紹介 → お城も建てます → 爆発も、します → 看板の前に全員集合。場面が撮れるとフィルムが止まるので、止まっている間に次の場面を用意して、1 で回す。"},
	# 場所が変わるカット割り：城の門 → 月夜の丘（城を片づけて月を出す）→ 爆発 → 寄りで決め
	{"title":"旅する二人", "rank":3, "budget":520, "location":"倉庫", "site":0, "script":"castle", "board":"travel",
		"bonus":"first_take", "bonus_title":"一発OKで撮り切る", "fee_all":350, "cast_at":[1, 2],
		"scenes":["城の門", "月夜の丘（城は映さない）", "月の下で大爆発", "寄りで決めポーズ"],
		"description":"場所が変わる4カット。城の前で出発 → 城を片づけて、月夜の丘 → 爆発 → 寄りで決め。場転のたびに、片づける・出す・寄せる・照らし直す。"},
	# 名場面のパロディ（冒険映画の有名な冒頭）。仕掛けの見せ場（features/contraptions.gd）：動くカメラ・上から落ちる罠・転がる大岩・寄り。
	# 役者を自分たちで演じると、カメラを押す人も罠を落とす人も大岩を押す人もいない。仕掛けに任せるか、人を雇うか
	{"title":"転がる大岩・予告編", "rank":3, "budget":560, "location":"倉庫", "site":0, "script":"trap", "board":"trap", "props":["scrap_treasure_pedestal"],
		"bonus":"no_crew", "bonus_title":"スタッフ映り込み0.5秒以内", "fee_all":450, "cast_at":[2, 2],
		"scenes":["遺跡に踏み込む（カメラが動く）", "罠が作動（上から落ちてくる）", "大岩に追われて逃げる", "穴に飛び込んで、大岩をよける"],
		"description":"冒険映画の有名な冒頭のパロディを、予告編の4カットで。忍び足で奥へ（カメラも動く）→ 秘宝をすり替えると、上から物が落ちる → 転がる大岩に追われて逃げる → 間一髪、穴に飛び込むと、大岩が上を転がっていく。穴は、バスタブや箱に見立てるか、板に描く。押す人・落とす人は、映ってはいけない。"},
	# ---- 名場面のパロディ（10〜16）。実在の題名・名前は出さず、誰でも分かる状況で寄せる ----
	# props：依頼主が用意する物（features/job_props.gd が、その日の廃材置き場に出しておく）
	{"title":"空き巣にご用心", "rank":1, "budget":520, "location":"室内スタジオ", "site":1, "script":"home_alone", "board":"home_alone", "props":["scrap_hinged_door_wall", "scrap_layered_pine"],
		"bonus":"no_crew", "bonus_title":"スタッフ映り込み0.5秒以内", "fee_all":450, "cast_at":[1, 2],
		"scenes":["玄関の前の泥棒", "振り子が当たる", "炎がお尻に", "寄りでぐったり"],
		"description":"クリスマスの留守番コメディのパロディで、防犯ビデオ。泥棒の二人が、罠に次々かかる：振り子が当たる → 足元のボタンでトーチの炎がお尻に → ぐったり。最初は玄関の前（玄関の役の物を映す）。玄関のドアとモミの木は、廃材置き場に出してある。罠を仕掛ける人は、映ってはいけない。"},
	{"title":"月夜の自転車", "rank":2, "budget":480, "location":"野外", "site":2, "script":"moon_bike", "board":"moon_bike", "props":["scrap_cardboard_bicycle"],
		"bonus":"moon", "bonus_title":"月を合計2秒映す", "fee_all":400, "cast_at":[0, 1],
		"scenes":["満月を見上げる", "満月の前を横切る", "寄りで決めポーズ"],
		"description":"宇宙から来た友だちの映画のパロディ。満月を見上げる二人 → 自転車で満月の前を横切るシルエット → 着地して決め。画面の上で、月に重ねて横切らせる。"},
	{"title":"沈まない船の舳先で", "rank":3, "budget":520, "location":"野外", "site":2, "script":"ship", "board":"ship", "props":["scrap_fan", "scrap_rowboat_shell"],
		"bonus":"first_take", "bonus_title":"一発OKで撮り切る", "fee_all":400, "cast_at":[0, 1],
		"scenes":["高い舳先に立つ", "風を受けて両手を広げる", "寄りで見つめ合う"],
		"description":"豪華客船の恋愛映画のパロディ。高い所（舳先）に立つ二人 → 送風機の風を正面から受けて、両手を広げる → 寄りで見つめ合う。送風機と張りぼてのボートは、廃材置き場に出してある。"},
	{"title":"弾をよける男", "rank":3, "budget":540, "location":"倉庫", "site":0, "script":"dodge", "board":"dodge", "props":["scrap_brick_parapet"],
		"bonus":"no_crew", "bonus_title":"スタッフ映り込み0.5秒以内", "fee_all":450, "cast_at":[0, 1],
		"scenes":["向き合う二人", "のけぞる二人とカメラの回り込み", "寄りで決め"],
		"description":"仮想世界のアクション映画のパロディ。向き合う二人 → 弾をよけてのけぞったまま、カメラだけが二人のまわりを回り込む（60度くらい）→ 寄りで決め。カメラを押す人は、映ってはいけない。"},
	{"title":"階段を駆け上がれ", "rank":2, "budget":500, "location":"室内スタジオ", "site":1, "script":"stairs", "board":"stairs", "props":["scrap_straight_stair", "scrap_paper_mountain"],
		"bonus":"first_take", "bonus_title":"一発OKで撮り切る", "fee_all":400, "cast_at":[0, 1],
		"scenes":["並んで走る（カメラも動く）", "駆け上がる", "頂上で万歳"],
		"description":"ボクサーの朝の映画のパロディ。走る二人と並んでカメラも動く → 高い所へ一気に駆け上がる → 頂上で万歳。上の印は、高い所に置く。階段と張りぼての山は、廃材置き場に出してある。"},
	{"title":"カップ麺の3分（CM）", "rank":1, "budget":320, "location":"会社の前", "site":1, "script":"noodle", "board":"noodle", "home":true, "props":["scrap_teapot"],
		"bonus":"no_crew", "bonus_title":"スタッフ映り込み0.5秒以内", "fee_all":300, "cast_at":[0, 1],
		"scenes":["お湯を注ぐ", "タイマーがチン", "寄りでうまい！"],
		"description":"カップ麺のCMのパロディを、会社の前で。お湯を注ぐ二人 → 映っている所でタイマー（目覚まし時計・押しボタン）がチン → 寄りで、うまい！"},
	{"title":"髪がなびく車のCM", "rank":1, "budget":380, "location":"会社の前", "site":1, "script":"car_cm", "board":"car_cm", "home":true, "props":["scrap_fan", "scrap_car_front_shell"],
		"bonus":"no_crew", "bonus_title":"スタッフ映り込み0.5秒以内", "fee_all":350, "cast_at":[0, 1],
		"scenes":["風を受ける二人", "車が走り抜ける", "寄りで決め"],
		"description":"車のCMのパロディを、会社の前で。送風機の風で髪がなびく二人 → 大きな物（車の正面の書割）がカメラの前を走り抜ける → 寄りで決め。送風機と車の正面は、廃材置き場に出してある。"},
	# 最後の一本（finale）：ハリウッドの監督からの依頼。格4の「大仕事」の枠にだけ出る。全部の場面がそろえば、エンディング
	{"title":"ハリウッド監督の新作・大怪獣", "rank":5, "finale":true, "budget":900, "location":"野外", "site":2, "script":"kaiju", "board":"kaiju5",
		"bonus":"first_take", "bonus_title":"一発OKで撮り切る", "fee_all":1500, "cast_at":[1, 2],
		"scenes":["街を歩いてくる", "怪獣あらわる", "怪獣の技で街がこわれる", "怪獣がひとりでに倒れる", "倒れた怪獣の前で勝利"],
		"description":"ハリウッドの監督から FAX。『あなたたちの怪獣映画を見た。私の新作の怪獣の場面を、あなたたちのやり方で撮ってほしい』。5場面を、フィルム1本で止めずに撮る。これが撮れれば、ハリウッドだ。"},
]
const HOME_TRUCK := Vector3(80, 0, 18)
const SITE_TRUCK := Vector3(16.3, 0, 6.5)
# 会社の前の撮影場所（事務所の正面。店構えを背に撮れる）。home の依頼（会社のCM）は、出発せずに、ここで撮る
const HOME_SET := Vector3(70.0, 0.0, 12.5)
const OFFSET := HOME_TRUCK - SITE_TRUCK
# 会社の機材（カメラ3台・ライト2台・カチンコ・カンペ・確認用モニター）。荷台には積まない。
# 会社では機材置き場（軽トラの北東。囲いは production_office.gd の GEAR_YARD）に並べておき、
# 出発すると、いっしょに現場へ運ばれる（荷台を、廃材と借り物のために空けておく）
const GEAR_KINDS := ["camera", "spot", "clapper", "cue_card", "monitor"]
const GEAR_NAMES := {"camera": "カメラ", "spot": "ライト", "clapper": "カチンコ", "cue_card": "カンペ", "monitor": "モニター"}     # 積み込み確認の札に出す短い名前
# 機材置き場での並べ方：種類 → [[囲いの北西の角からの位置（x, z）, 向き], ...]
const GEAR_HOME := {
	"camera": [[Vector2(0.6, 0.65), 0.0], [Vector2(0.6, 1.85), 0.0], [Vector2(0.6, 3.05), 0.0]],
	"spot": [[Vector2(1.85, 0.65), PI], [Vector2(1.85, 1.85), PI]],
	"clapper": [[Vector2(1.6, 3.05), -PI * 0.5]],
	"cue_card": [[Vector2(2.1, 3.0), -PI * 0.5]],
	"monitor": [[Vector2(3.25, 1.65), -PI * 0.5]],
}
# 現場での並べ方：種類 → [[搬入口（game.SPAWN）からの位置（x, z）, 向き], ...]。
# 軽トラの通り道の北側に、手前からカメラ・ライト・モニターの順（軽トラの横は、人が通れるように空ける）。
# ふさがっていたら、近くの空いた場所を探す
const GEAR_SITE := {
	"camera": [[Vector2(0.8, -3.1), PI * 0.5], [Vector2(2.0, -3.1), PI * 0.5], [Vector2(3.2, -3.1), PI * 0.5]],
	"spot": [[Vector2(0.8, -4.4), -PI * 0.5], [Vector2(2.0, -4.4), -PI * 0.5]],
	"clapper": [[Vector2(2.95, -4.4), 0.0]],
	"cue_card": [[Vector2(4.05, -4.4), 0.0]],
	"monitor": [[Vector2(2.0, -5.95), 0.0]],
}
var game: Node
var phase := 0
var wallet := 600
var lease_left := 600.0
var expired := false
var chosen_job := 0
var trip_time := 0.0
var last_payment := 0
var expenses := 0
# お金は2種類ある。
#   制作費：依頼ごとに依頼主が出す。借り物はこの中からしか払えない。使い残しは会社の儲けになる
#   貯金（wallet）：次の依頼へ繰り越す。使い道は、会社を大きくする物（車・スタジオなど）と家賃
# こう分けておくと、会社が金持ちになっても「全部は借りられないから廃材でごまかす」が毎回残る
const START_WALLET := 600
const RENT_EVERY := 3            # 何本ごとに家賃を払うか
const RENT_FIRST := 1200         # 最初の家賃
const RENT_STEP := 600           # 払うたびに上がる額
var saved := 0                   # 今回、使わずに浮かせた制作費
var rent_no := 0                 # これまでに家賃を払った回数
var rent_paid := 0               # 今回の精算で払った家賃（0＝支払いの回ではない）
var bankrupt := false            # 家賃が払えず倒産した（事務所へ戻ると、新しい会社でやり直す）
# 評判と格：納品の出来で評判が上下し、評判で格（1〜4）が決まる。格で、掲示板に来る依頼主が変わる。倒産すると 0 から
const RANK_AT := [0, 4, 9, 15]   # 格1〜4になる評判
const RANK_NAMES := ["町内の制作会社", "地方で評判の制作会社", "映画会社の下請け", "大作も任される制作会社"]
# 格が上がったときに、新しい依頼主から来る電話
const RANK_CALLS := ["", "地方テレビ局『評判、聞いてますよ。うちの番組の仕事、お願いできますか』", "映画会社『下請けを探していまして。予算は出します』",
	"大手の制作部『うちの大作、撮ってみませんか』　──その夜、海外から FAX が一枚。『ハリウッドの監督です。あなたたちの映画を見ました』"]
# 毎日3枚：地元の仕事（1つ下の格。易しい・少ない）／いつもの仕事（今の格）／大仕事（1つ上の格。大きい報酬、失敗すると評判が大きく下がる）
const SLOTS := ["local", "regular", "big"]
const SLOT_NAMES := {"local": "地元の仕事", "regular": "いつもの仕事", "big": "大仕事"}
var reputation := 0
var rep_change := 0              # 今回の精算での評判の増減
var chosen_slot := ""            # 受けた依頼の枠（SLOTS のどれか。初日の一本は ""）
var finale_done := false         # ハリウッドの一本を撮り切った（事務所へ戻ると、エンディング）
var all_jobs := false            # 遊んで確かめる用：2日目から全部の依頼を出す（features/start_day.gd の --day2）
var owned := {}                  # 買って会社の持ち物になった物（発注の id → true）。次の依頼からも最初から在る。倒産すると無くなる
var bought_now: Array = []       # この依頼の間に買った物（発注の id）
var bought := 0                  # この依頼の間に、買い物で貯金から払った額（精算の内訳に出す）
var sack_stock: Array = []       # 前の依頼から持ち越した火薬の袋（1袋ごとの残りの量）
# 会社の名前：文字では決めない。事務所の入口の上に掛けた段ボールの看板の絵が、会社の名前（features/company_sign.gd）。
# 会社が呼ばれる文（お知らせ・電話・コメント欄・作品の札・依頼主のひとこと）には COMPANY（「{会社}」）を書き、
# 表示する側が ui/company_logo.gd の show_in で看板の絵に替える。文字しか出せない所（題など）は company_name() の文字
const CompanyLogo := preload("res://scripts/ui/company_logo.gd")
const COMPANY := CompanyLogo.TOKEN
const DEFAULT_COMPANY := CompanyLogo.DEFAULT
var company := ""
var _new_names: Array = []       # いま買ったばかりの物の名前（お知らせに出す）
var last_flubs: Array[String] = []
var notes: RefCounted
var bonus_progress := ""
const BONUS_TITLES := ["一発OKで撮り切る", "スタッフ映り込み0.5秒以内", "月を合計2秒映す"]
var _sync := 0.0
var _notice := 0
var _loaded: Array[int] = []
var _ahead: Array = []           # 荷台に積まず、先に現場へ送った物 [[物のID, 置きたい場所, 向き], ...]
var _parked := {}                # 搬入口に並べたまま、まだ誰も動かしていない物（物のID → 置いた場所）。突風では動かない
var _home_layout := {}
var _configured_job := -1
var _site_root: Node3D
var _office_root: Node3D
var _trip_camera: Camera3D
var _original_walls: Array[StaticBody3D] = []
var _warnings := [120.0, 60.0, 30.0]
var _world_environment: Environment
# 日替わりの廃材：廃材置き場に出るのは毎日この数だけ。残りは奥にしまってある
const DAILY_COUNT := 35
var day := 1
var stash: Array = []            # 今日は出ていない物（物のID）
var daily := true                # false なら全部出す（自動確認用）
var _yard_root: Node3D
var script_prop: Node            # 1冊だけの台本
var monitor_prop: Node           # 確認用モニター（置き型）
var levels := {"car": 0, "studio": 0, "monitor": 0, "plan": 0}   # アップグレードの段階
var display: Node3D              # 事務所の奥のアップグレード画面
var _configured_site := -1
# 準備の持ち時間と、荷台の積みすぎ
const PREP_TIME := 180.0         # 依頼を受けてから出発までの目安。過ぎた分は撮影時間から引く
const MIN_LEASE := 240.0         # どれだけ遅れても、撮影時間はこれだけ残る
const BED_CAPACITY := 12         # 荷台に安全に載る「かさ」。超えた分は道中で落ちるかもしれない
const BUMPS := [2.6, 5.4]        # 移動中に段差を踏む時刻（秒）
const FALL_CHANCE := 0.45        # 段差1回で、はみ出した物が落ちる確率
var prep_left := PREP_TIME       # 負の値は遅れ
var hazards := true              # false なら遅れも荷崩れも起きない（自動確認用）
var lost: Array = []             # 今回の移動で落とした物の名前
var _bumped := 0
# 野外の空き地（最初のスタジオ）は、ときどき突風が吹く。固定していない軽い物は動く・倒れる
const GUST_EVERY := Vector2(28.0, 50.0)   # 次の突風までの秒数（この間でばらつく）
const GUST_WARN := 2.5                    # 風の音がしてから、物が動くまで
var _gust_in := 40.0
var _gust_warned := false
const GUST_BLOW := 0.9                    # 風が吹き続ける秒数
var _gust_left := 0.0
var _gust_dir := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _gate := 0.0
# 見立て：どの物を何の役に使うか（物のID → 役。""＝役を外した）。依頼ごとに付け直す
var casting: Dictionary = {}
var cast_face: Dictionary = {}       # 見立ての飾りの顔を付ける側（物のID → 0..3。cast_dress.gd の face）。役を付けた人が見ていた側
const SITE_RADIUS := 38.0         # 現場に持ってきた物かどうかを、場所で見分ける
# 監督の机（production_director.gd）。事務所の机の「のぞき箱」で、参考スライドをのぞく
var slides: Dictionary = {}       # スライドの中身（依頼を受けたときにホストが決める。production_slides.gd）
var peeper := 0                   # いま、のぞき箱をのぞいている人（参加者のID。0＝誰もいない）
# 発注：画面が開くのは、開いた人だけ。ゲームは止まらず、ほかの人は準備を続ける
var orderer := 0                  # いま、発注の画面を開いている人（参加者のID。0＝誰もいない）
var ordered: Dictionary = {}      # この依頼で、決めてある注文（発注の id → 数）。届いている物は、これで決まる。
                                  # 画面で選んでいる途中の注文（game.order）は、決めるまで世界に出ない
const PEEP_REACH := 6.0           # のぞき箱から、これより遠い人の頼みは受けない

func setup(owner_game: Node, incremental: bool = false) -> void:
	game = owner_game
	notes = Notes.new()
	notes.game = game
	for item in [["lift_cart",Vector3(68,0,18)],["cleaning_cart",Vector3(66,0,18)]]:
		var cart: Node = ProductionProp.new()
		cart.build_model(item[0])
		game.stage._register(cart,item[1]-OFFSET,0.0)
		if incremental:
			await get_tree().process_frame
	for item in [["dragon_skull",Vector3(51,0.05,17)],["witch_cauldron",Vector3(54,0.05,19)],["tomato_monster",Vector3(56,0.05,21)]]:
		var prop: Node = MovieProp.new()
		prop.build_model(item[0])
		game.stage._register(prop,item[1]-OFFSET,0.0)
		if incremental:
			await get_tree().process_frame
	# 廃材置き場の無料の小道具・大道具（表は production_scrap.gd。追加は表の末尾へ）
	for item: Dictionary in MovieProp.Scrap.ITEMS:
		var scrap: Node = MovieProp.new()
		scrap.build_model(item["kind"])
		var spot: Vector2 = item["pos"]
		game.stage._register(scrap,Vector3(spot.x,0.05,spot.y)-OFFSET,float(item.get("yaw",0.0)))
		if incremental:
			await get_tree().process_frame
	# 台本は1冊だけ。事務所の机の上に置いてある（物のIDがずれないよう、小道具の最後に作る）
	script_prop = ScriptProp.new()
	script_prop.build_model()
	game.stage._register(script_prop, Vector3(72.9, 0.98, 0.25) - OFFSET, 0.35)
	monitor_prop = MonitorProp.new()
	monitor_prop.build_model()
	game.stage._register(monitor_prop, Vector3(77.0, 0.05, 21.6) - OFFSET, PI * 0.5)
	monitor_prop.attach(game.film.view)
	_office_root = Office.build(game, game.font)
	Rental.build(_office_root, game.font)
	display = Display.new()
	display.name = "UpgradeDisplay"
	display.position = Vector3(69.4, 0, -7.6)
	_office_root.add_child(display)
	display.build(game)
	# ユーザー作成の廃材置き場とコンテナ、まわりの倉庫街
	_yard_root = Yard.build(_office_root)
	if incremental:
		await get_tree().process_frame
	var decor := Assets.decorate(_office_root, "office")
	decor.position = Vector3(74, 0, -4)
	if incremental:
		await get_tree().process_frame
	for child in game.stage.get_children():
		if child is WorldEnvironment:
			_world_environment = child.environment
			var sky_material := ProceduralSkyMaterial.new()
			sky_material.sky_top_color = Color("638ca9")
			sky_material.sky_horizon_color = Color("c0d0c8")
			sky_material.ground_horizon_color = Color("a6a99d")
			sky_material.ground_bottom_color = Color("626b61")
			# 遠くを空の色へ溶かして、地平線の線を消す
			_world_environment.fog_enabled = true
			_world_environment.fog_light_color = Color("b4c2c0")
			_world_environment.fog_density = 0.0035
			_world_environment.fog_sky_affect = 0.35
			var sky := Sky.new()
			sky.sky_material = sky_material
			_world_environment.sky = sky
			_world_environment.background_mode = Environment.BG_SKY
		if child is StaticBody3D and child.position.y > 0.1:
			_original_walls.append(child)
	# 拠点の絵作り（空・もや・色味）。空ともやを上書きするので、上の設定のあとに呼ぶ
	Look.apply(_world_environment, game.stage, _office_root)
	_trip_camera = Camera3D.new()
	_trip_camera.fov = 70
	game.add_child(_trip_camera)
	# 自動確認では毎回同じ結果になるよう、全部の廃材を出し、遅れ・荷崩れ・スタジオの段階を使わない
	# （現場の種類は全員の画面で同じ決め方をする必要があるので、ホスト以外でも決めておく）
	daily = get_tree().get_script() == null or "--dev-play" in OS.get_cmdline_user_args()      # --dev-play：dev_session で、ふつうに遊ぶ
	for flag: String in OS.get_cmdline_user_args():
		# 二人通信の確認には「--〇〇-host」「--〇〇-client」で起動するものがある（"--host" だけの起動は、本番の遊び）
		var mark := flag.trim_prefix("--")
		if flag.contains("test") or flag.contains("shot") or mark.ends_with("-host") or mark.ends_with("-client"):
			daily = false
	hazards = daily
	if Net.is_host():
		# 無料の物は、廃材置き場の中の決まった置き場所へ並べる
		var slots: Dictionary = Yard.home_slots()
		var taken := {}
		for pid: int in game.props:
			var prop: Node = game.props[pid]
			if prop.kind != "mark":
				_move(prop, prop.global_position + OFFSET)
			if prop.kind == "truck":
				_move(prop, prop.global_position, 0.0)
			if slots.has(prop.kind) and prop.rider_of == 0 and not prop.absent:
				var n: int = taken.get(prop.kind, 0)
				if n < (slots[prop.kind] as Array).size():
					taken[prop.kind] = n + 1
					# 正面を通路（ヤードの中心線）のほうへ向ける
					var at: Vector3 = slots[prop.kind][n]
					var st: Array = prop.get_state()
					st[0] = at
					st[1] = Quaternion(Vector3.UP, PI * 0.5 if at.z > Yard.CENTER.z else -PI * 0.5)
					prop.restore(st)
			if prop.kind == "carton" or in_bag(prop.kind):
				# 段ボール箱は廃材置き場には並べない。段ボール置き場（cargo_kit.gd）が出すまで、待機場所に置いておく。
				# ゴミ袋・包みの中の物も、振って出すまで待機場所に置いておく（features/junk_bags.gd）
				var parked: Array = prop.get_state()
				parked[0] = Vector3(float(pid) * 3.0, -60.0, 0.0)
				parked[2] = true
				prop.restore(parked)
			_home_layout[pid] = prop.get_state()
		_rng.randomize()
		restock()
		park_truck_for_day()
		game._set_state(game.S.PREP)
		game.production_sync.rpc(snapshot())
		game.move_crew(Office.SPAWN_POINT, 0.0)
		game._grab_mouse(false)

# 会社の名前（まだ決めていなければ、ゲームの題名）
func company_name() -> String:
	return company if company != "" else DEFAULT_COMPANY


func job() -> Dictionary:
	return JOBS[chosen_job]


# ---- 見立て（配役） ----

# いまの台本。依頼を受ける前は役が無い
func story() -> String:
	return str(job()["script"]) if phase >= 1 else ""


# 今回の依頼主の好み（属性タグ）。依頼を受ける前は無い
func likes() -> Array:
	return (Briefs.brief(chosen_job).get("likes", []) as Array) if phase >= 1 else []


# その物が、いまの台本で何の役か（""＝役なし）。自分たちで決めた役が、もとから付いている役より優先
func role_of(prop: Node) -> String:
	if prop == null or not Cast.castable(prop.kind):
		return ""
	var role: String = str(casting[prop.pid]) if casting.has(prop.pid) else Cast.default_role(prop.kind)
	return role if role in Cast.roles_for(story()) else ""


# 採点に渡す印。等身大パネルは、白紙のままなら "blank" が付く（ジョーカーにならない）
func cast_tags(prop: Node) -> Array:
	var out: Array = (prop.tags as Array).duplicate()
	if prop.has_method("blank") and prop.blank():
		out.append("blank")
	# 爆弾は、入れた火薬の量で爆発の大きさが変わる（量を3段階に当てはめる。fx_box.gd の stage_of）
	if prop.kind == "fx":
		out.append("powder%d" % int(prop.stage()))
	# ドレスの人がショールをかけた物（cast_talent.gd）：むりやりの役でも、それっぽく見える
	var talent: Variant = game.get("talent")
	if talent != null and talent.shawled(prop.pid):
		out.append("shawl")
	return out


# その物を、その役に使ったときのらしさ（0＝むりやり / 1＝それっぽい / 2＝ぴったり）
func cast_fit(prop: Node, role: String) -> int:
	return Cast.fit(prop.kind, role, cast_tags(prop))


# 配役表や採点に載せる1件。名前は短く（かっこ書きの説明は外す）
func _cast_item(prop: Node) -> Dictionary:
	return {"kind": prop.kind, "label": str(prop.label).get_slice("（", 0), "tags": cast_tags(prop)}


# 役を決める（ホスト）。role が "" なら役を外す
func cast_set(pid: int, role: String, face := -1) -> bool:
	var prop: Node = game.props.get(pid)
	if prop == null or prop.absent or not Cast.castable(prop.kind) or Cast.locked(prop.kind):
		return false
	if role != "" and role not in Cast.roles_for(story()):
		return false
	if role == Cast.default_role(prop.kind):
		casting.erase(pid)
		cast_face.erase(pid)
	else:
		casting[pid] = role
		# 飾りの顔を付ける側（役を付けた人が見ていた側。決まっていなければ前のまま）
		if face >= 0:
			cast_face[pid] = face
	game.production_sync.rpc(snapshot())
	return true


# その物が実際にある場所。しまってある物（箱の中・人の体の中）は、入れ物（箱・人）のいる所
func whereabouts(prop: Node3D) -> Vector3:
	var at: Node3D = prop
	for step in 4:
		var keeper: int = int(at.get("stored_in")) if at.get("stored_in") != null else 0
		if keeper == 0:
			break
		var next: Node3D = game.props.get(keeper) if keeper > 0 else game.players.get(-keeper)
		if next == null:
			break
		at = next
	return at.global_position


# 現場に持ってきた物か（場所で見分ける。会社に置いてきた物は遠い）
func at_site(prop: Node3D) -> bool:
	var at: Vector3 = whereabouts(prop)
	var center: Vector3 = site_center()
	return Vector2(at.x - center.x, at.z - center.z).length() < SITE_RADIUS


# 準備で会社にいる間か（発注・会社のスマホが使える）：出発前の積み込み、または会社の前で撮る日の撮影の準備
func office_prep() -> bool:
	return phase == 2 or (phase == 4 and shoots_home())


# 今回の依頼を、会社の前で撮るか（会社のCM。出発しない）
func shoots_home() -> bool:
	return phase >= 1 and bool(job().get("home", false))


# 撮影現場の真ん中（会社の前で撮る依頼は、事務所の正面。ほかは、軽トラで行く現場）
func site_center() -> Vector3:
	return HOME_SET if shoots_home() else Vector3.ZERO


# いま撮影に使える場所にあるか。会社にいる間は全部。現場に着いてからは、持ってきた物だけ
func on_set(prop: Node3D) -> bool:
	return phase < 3 or at_site(prop)


# いま役の付いている物を、役ごとに集める。
# 準備中は「荷台に積んだ物」と「自分たちで役を決めた物」、現場では「持ってきた物」だけを見る
func cast_pool() -> Dictionary:
	var used := {}
	var prep: bool = phase < 3          # 会社にいる間（借りる画面を開いている間も）
	var packed: Array = cargo() if prep else []
	for pid: int in game.props:
		var prop: Node = game.props[pid]
		# しまってある物（箱の中・人の体の中）は、見えなくても配役に数える
		if prop.absent and prop.stored_in == 0:
			continue
		var role := role_of(prop)
		if role == "":
			continue
		var here: bool = (pid in packed or casting.has(pid)) if prep else at_site(prop)
		if not here:
			continue
		if not used.has(role):
			used[role] = []
		(used[role] as Array).append(_cast_item(prop))
	return used


# 役ごとの、見立てた物の短い名前（台本のせりふに入れる）。{役: 名前}。決まっていない役は入らない
func cast_names() -> Dictionary:
	var out := {}
	var used := cast_pool()
	for role: String in used:
		var label: String = str(used[role][0]["label"])
		out[role] = label.get_slice("（", 0).get_slice("・", 0)
	return out


# 配役表：役ごとに、何を使うつもりか。コンボの見込みも付ける
#   {"rows": [{role, name, items, grade（-1＝まだ決めていない）, grade_name, optional}], "combos": [...], "coins": 見込み}
func cast_sheet() -> Dictionary:
	var used := cast_pool()
	var report := Cast.score(story(), used, likes())
	var rows: Array = []
	for role: String in Cast.roles_for(story()):
		var row := {"role": role, "name": Cast.role_name(role, story()), "items": "", "grade": -1, "grade_name": "", "optional": role in Cast.OPTIONAL}
		for r: Dictionary in report["roles"]:
			if r["role"] == role:
				row["items"] = r["items"]
				row["grade"] = r["grade"]
				row["grade_name"] = r["grade_name"]
		rows.append(row)
	return {"rows": rows, "combos": report["combos"], "liked": report["liked"], "coins": report["coins"]}


# 撮ったテイクの見立ての点（ホスト）。映画の中で役が成立した物だけを数える。
#   seen：物のID → 撮影カメラに映った秒数 / boom_pid：数えた爆発を出した物 / passed：場面ごとの成否
func cast_report(seen: Dictionary, boom_pid: int, passed: Array) -> Dictionary:
	var used := {}
	# 怪獣と街が映った場面・爆発が映った場面（依頼の cast_at。今までの3場面は、1つ目と2つ目）
	var gates: Array = job().get("cast_at", [0, 1])
	var shown: bool = int(gates[0]) < passed.size() and bool(passed[int(gates[0])])
	var boomed: bool = int(gates[1]) < passed.size() and bool(passed[int(gates[1])])
	var lead := 0
	var lead_t := 0.0
	for pid: int in seen:
		var prop: Node = game.props.get(pid)
		if prop == null or float(seen[pid]) < Cast.MIN_SEEN:
			continue
		var role := role_of(prop)
		if role == "" or role == "boom" or not shown:
			continue
		if role == "monster":
			# 怪獣は、いちばん長く映っていた1体が主役
			if float(seen[pid]) > lead_t:
				lead_t = float(seen[pid])
				lead = pid
			continue
		if not used.has(role):
			used[role] = []
		(used[role] as Array).append(_cast_item(prop))
	if lead != 0:
		used["monster"] = [_cast_item(game.props[lead])]
	if boomed and game.props.has(boom_pid):
		var boom := _cast_item(game.props[boom_pid])
		if boom["kind"] == "fx":
			# 爆発したときに入っていた量で数える（爆発のあとは空になっている）
			boom["tags"] = ["powder%d" % game.judge.boom_power]
		used["boom"] = [boom]
	return Cast.score(story(), used, likes())


# この依頼の制作費（依頼主が出す。借り物の上限）
func budget() -> int:
	return int(job().get("budget", 600))


# 次に払う家賃の額（払うたびに上がる）
func rent_amount() -> int:
	return RENT_FIRST + RENT_STEP * rent_no


# 家賃の支払いまで、あと何本か（今回の依頼を含む。1＝今回の精算で払う）
func rent_in() -> int:
	return RENT_EVERY - ((day - 1) % RENT_EVERY)

func snapshot() -> Dictionary:
	return {"phase":phase,"wallet":wallet,"lease_left":lease_left,"expired":expired,"chosen_job":chosen_job,"trip_time":trip_time,"last_payment":last_payment,"expenses":expenses,"last_flubs":last_flubs,"bonus_progress":bonus_progress,"day":day,"levels":levels,"prep_left":prep_left,"lost":lost,"saved":saved,"rent_no":rent_no,"rent_paid":rent_paid,"bankrupt":bankrupt,"casting":casting,"cast_face":cast_face,"crew_epoch":game._crew_epoch,"owned":owned,"bought_now":bought_now,"bought":bought,"sack_stock":sack_stock,"slides":slides,"peeper":peeper,"orderer":orderer,"ordered":ordered,"company":company,"reputation":reputation,"rep_change":rep_change,"chosen_slot":chosen_slot,"finale_done":finale_done,"all_jobs":all_jobs}

func apply(data: Dictionary) -> void:
	game._crew_epoch = maxi(game._crew_epoch,int(data.get("crew_epoch",0)))
	var old := phase
	phase = int(data["phase"])
	wallet = int(data["wallet"])
	company = str(data.get("company", company))
	lease_left = float(data["lease_left"])
	expired = bool(data["expired"])
	chosen_job = int(data["chosen_job"])
	game.judge.story = str(job()["script"])
	trip_time = float(data["trip_time"])
	last_payment = int(data["last_payment"])
	expenses = int(data["expenses"])
	last_flubs.assign(data["last_flubs"])
	bonus_progress = str(data.get("bonus_progress",""))
	day = int(data.get("day",day))
	levels = data.get("levels",levels)
	# 車の段階に合わせて、軽トラかロケバンかを切り替える
	if game.truck.has_method("set_vehicle"):
		game.truck.set_vehicle("van" if int(levels.get("car", 0)) >= 1 else "kei")
	prep_left = float(data.get("prep_left",prep_left))
	lost = data.get("lost",lost)
	saved = int(data.get("saved",saved))
	rent_no = int(data.get("rent_no",rent_no))
	rent_paid = int(data.get("rent_paid",rent_paid))
	bankrupt = bool(data.get("bankrupt",bankrupt))
	reputation = int(data.get("reputation",reputation))
	rep_change = int(data.get("rep_change",rep_change))
	chosen_slot = str(data.get("chosen_slot",chosen_slot))
	finale_done = bool(data.get("finale_done",finale_done))
	all_jobs = bool(data.get("all_jobs",all_jobs))
	casting = data.get("casting",casting)
	cast_face = data.get("cast_face",cast_face)
	owned = data.get("owned",owned)
	bought_now = data.get("bought_now",bought_now)
	bought = int(data.get("bought",bought))
	sack_stock = data.get("sack_stock",sack_stock)
	slides = data.get("slides",slides)
	peeper = int(data.get("peeper",peeper))
	orderer = int(data.get("orderer",orderer))
	ordered = data.get("ordered",ordered)
	# 各仕組みの hook_production_applied：買った爆弾に付く袋・持ち越した袋の数が変わったら、出ている袋を合わせ直す。
	# 場面の列を持つ依頼のときだけ、印②③・リール・ランプを出す
	game.hooks.run("hook_production_applied")
	# 事務所・買い物・積み込み・移動中は撮影映像を表示しない。
	game.film.view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if phase in [4,5] else SubViewport.UPDATE_DISABLED
	if phase in [4,5] and (_site_root == null or _configured_job != chosen_job or _configured_site != site_index()):
		_configure_site()
	game.hud.root.visible = true
	game.input_locked = phase == 3
	_sync_vehicle_riders()
	if phase != 3 and _trip_camera.current and game.local_player():
		game.local_player().cam.make_current()
	if old != phase:
		game._grab_mouse(phase in [2,4])

# きょう掲示板に出る依頼。初日は会社のCMだけ。2日目からは3枚（地元の仕事・いつもの仕事・大仕事の順）
func offered() -> Array:
	return offers().map(func(o: Array) -> int: return int(o[1]))


# きょうの依頼 [[枠, 依頼の番号], ...]。日と評判だけで決まる（ホストと参加者で同じになる）
func offers() -> Array:
	var debut := debut_job()
	if day <= 1:
		return [["", debut if debut >= 0 else 0]]
	if all_jobs:
		return range(JOBS.size()).filter(func(i: int) -> bool: return i != debut).map(func(i: int) -> Array: return ["", i])
	var out: Array = []
	var taken: Array = []
	for slot: String in SLOTS:
		var pick := _pick(slot, taken)
		if pick >= 0:
			out.append([slot, pick])
			taken.append(pick)
	return out


# その依頼の、きょうの枠（"local"・"regular"・"big"。出ていなければ ""）
func slot_of(index: int) -> String:
	for o: Array in offers():
		if int(o[1]) == index:
			return str(o[0])
	return ""


func _pick(slot: String, taken: Array) -> int:
	var r := rank()
	var want: int = {"local": maxi(1, r - 1), "regular": r, "big": r + 1}[slot]
	var pool: Array = range(JOBS.size()).filter(func(i: int) -> bool:
		return job_rank(i) == want and i != debut_job() and i not in taken)
	if pool.is_empty():
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s|%d" % [day, slot, reputation])
	return int(pool[rng.randi_range(0, pool.size() - 1)])


func job_rank(index: int) -> int:
	return int(JOBS[index].get("rank", 1))


# いまの格（1〜4）
func rank() -> int:
	var r := 1
	for i in RANK_AT.size():
		if reputation >= int(RANK_AT[i]):
			r = i + 1
	return r


func rank_name() -> String:
	return str(RANK_NAMES[rank() - 1])


# 次の格まで、あと何点か（いちばん上なら -1）
func rep_to_next() -> int:
	var r := rank()
	return int(RANK_AT[r]) - reputation if r < RANK_AT.size() else -1


# 評判の増減：場面が全部そろえば +2（追加の注文も達成で +1）、半分以上で +1、半分に届かなければ −1、ひとつも撮れなければ −2。
# 大仕事は増えるのも減るのも2倍。地元の仕事は、増えても +1 まで
static func rep_delta(count: int, total: int, bonus_ok: bool, slot: String) -> int:
	var d := 0
	if total > 0 and count == total:
		d = 2 + (1 if bonus_ok else 0)
	elif count * 2 >= total and count > 0:
		d = 1
	elif count > 0:
		d = -1
	else:
		d = -2
	if slot == "big":
		d *= 2
	elif slot == "local":
		d = mini(d, 1)
	return d


# 最初の一本（会社のCM）の番号（無ければ -1）
func debut_job() -> int:
	for i in JOBS.size():
		if bool(JOBS[i].get("debut", false)):
			return i
	return -1


# 依頼を受ける：買い物は後回し。まず廃材置き場の門が開く
func accept(index: int) -> void:
	if phase != 0 or index < 0 or index >= JOBS.size():
		return
	chosen_slot = slot_of(index)
	chosen_job = index
	game.judge.story = str(job()["script"])
	expired = false
	lease_left = lease_time()
	prep_left = PREP_TIME + (60.0 if int(levels.get("plan", 0)) >= 1 else 0.0)
	lost = []
	expenses = 0
	bought_now = []
	bought = 0
	saved = 0
	rent_paid = 0
	last_payment = 0
	last_flubs.clear()
	casting = {}
	cast_face = {}
	peeper = 0
	orderer = 0
	ordered = {}
	# 参考スライド：この依頼のおすすめの形を決める。今日手に入る物を、役ごとに1つは混ぜる
	slides = Slides.build(chosen_job, str(job()["script"]), Briefs.brief(chosen_job).get("likes", []), obtainable_kinds(), _rng.randi())
	notes.reset()
	bonus_progress = ""
	game.order = {}
	game.buying = {}
	game.takes = []
	game._take_data = []
	game.selected = 0
	game.host_ev("order", [game.order, game.buying])
	game.host_ev("takes", [[],0])
	game._apply_order()
	# 会社の持ち物（前に買った物）は、借りた物が届く場所に最初から在る
	_bring_home()
	# 台本は机の上へ、会社の機材は機材置き場へ戻す（誰かが持ち歩いていても）。カンペに書いた内容は消さない
	_ahead = []
	_parked = {}
	var back: Array = gear()
	if script_prop:
		back.append(script_prop)
	for own: Node in back:
		if _home_layout.has(own.pid):
			_let_go(own)
			var state: Array = own.get_state()
			for i in 3:
				state[i] = _home_layout[own.pid][i]
			own.restore(state)
	game._set_state(game.S.PREP)
	phase = 2
	park_truck_for_day()
	game.production_sync.rpc(snapshot())
	# 各仕組みの hook_new_job：場面の列を持つ依頼なら、役者の印（①②③）を現場に並べる
	game.hooks.run("hook_new_job")
	if bool(job().get("home", false)):
		# 会社の前で撮る依頼（1日目の紹介動画・CM）：軽トラにも乗らず、出発の時間も無い。そのまま撮影の準備に入る
		_shoot_home(bool(job().get("debut", false)))
	else:
		game.host_ev("toast", ["机に台本（1冊だけ）が届いた。依頼主の参考写真が挟まっている（台本を開いて、もう一度 F）。となりの粗大ごみ置き場の金網の穴も、めくっておいた（廃材は、そこから持ち出す）。出発まで3分",0])


# アップグレードを1段買う（買い切り。次の依頼からもずっと使える）
func buy(id: String) -> void:
	if not TRACKS.has(id):
		return
	var steps: Array = TRACKS[id]["levels"]
	var have: int = int(levels.get(id, 0))
	if have >= steps.size() - 1:
		return
	var next: Dictionary = steps[have + 1]
	if wallet < int(next["cost"]):
		game.host_ev("sfx", ["ui_fail", null])
		game.host_ev("toast", ["会社の貯金が足りない（%s は %d コイン）" % [next["name"], int(next["cost"])], 1])
		return
	wallet -= int(next["cost"])
	levels[id] = have + 1
	game.production_sync.rpc(snapshot())
	game.host_ev("sfx", ["ui_ok", null])
	if hazards and wallet < rent_amount():
		# 買い物のあとで家賃が払えなくなりそうなら、先に知らせる
		game.host_ev("toast", ["%s を手に入れた。次の家賃は %d コイン（あと%d本）。貯金に気をつけて" % [next["name"], rent_amount(), rent_in()], 1])
	else:
		game.host_ev("toast", ["%s を手に入れた。これからずっと使える" % next["name"], 0])


# 撮影に使える時間（スタジオが良くなると延びる）
func lease_time() -> float:
	return 600.0 + 60.0 * float(int(levels.get("studio", 0)))


# 今回の現場の種類。ふだんは会社のスタジオの段階で決まる（自動確認では依頼ごとの決まった現場）
func site_index() -> int:
	return int(STUDIO_SITES[clampi(int(levels.get("studio", 0)), 0, 2)]) if hazards else int(job()["site"])


# 撮影場所の名前
func location_name() -> String:
	if shoots_home():
		return "会社の前"
	return str(TRACKS["studio"]["levels"][clampi(int(levels.get("studio", 0)), 0, 2)]["name"]) if hazards else str(job()["location"])


# 映像を見られるか：小型モニターを持っているか、確認用モニターのそばにいる
func near_monitor(player: Node3D) -> bool:
	if int(levels.get("monitor", 0)) >= 1:
		return true
	# 首を伸ばしたベレー帽の人（cast_talent.gd）は、離れた所からでも、のぞける
	var talent: Variant = game.get("talent")
	var reach: float = Talents.NECK_MONITOR if talent != null and "peer_id" in player and talent.neck_out(player.peer_id) else 3.4
	return monitor_prop != null and not monitor_prop.absent and player.global_position.distance_to(monitor_prop.global_position) < reach


# ---- 監督の机 ----

# 今日、手に入る物の種類：会社や廃材置き場に出ている物と、借りられる物（参考スライドに混ぜる）
func obtainable_kinds() -> Array:
	var rent := {}
	for opt: Dictionary in game.OPTIONS:
		for kind: String in opt["kinds"]:
			rent[kind] = true
	var out: Array = []
	for pid: int in game.props:
		var prop: Node = game.props[pid]
		if not Cast.castable(prop.kind) or prop.kind in out:
			continue
		# 段ボール箱は、置き場からいくらでも出せる。借りられる物は、発注すれば届く
		if prop.kind == "carton" or rent.has(prop.kind) or (not prop.absent and pid not in stash):
			out.append(prop.kind)
	return out


# 台本に挟まっている参考写真を見る・やめる（ホスト。中の名前は、前の「のぞき箱」のまま peep）。
# 見られるのは台本を手に持っている人だけ（台本は1冊なので、一度に1人）。依頼を受けてから、本番の前まで。会社でも現場でも
func peep(who: int, on: bool) -> bool:
	if not on:
		if peeper != who:
			return false
		peeper = 0
		game.production_sync.rpc(snapshot())
		return true
	var pl: Node3D = game.players.get(who)
	if phase not in [2, 4] or game.state != game.S.PREP or slides.is_empty() or pl == null or orderer == who:
		return false
	if peeper == who:
		return true
	# 台本を手に持っている人だけ
	if script_prop == null or pl.held != script_prop.pid or pl.operating != 0:
		return false
	peeper = who
	game.production_sync.rpc(snapshot())
	return true


# 制作班の誰かが抜けた（ホスト）：その人が使っていた机の物を空ける。選びかけの注文は、決めた注文へ戻す
func crew_left(who: int) -> void:
	if peeper != who and orderer != who:
		return
	if peeper == who:
		peeper = 0
	if orderer == who:
		_drop_order()
	game.production_sync.rpc(snapshot())


# 発注：足りない物だけ、机の電話（か、レンタルのカウンター）で借りる・買う。出発までは何度でもやり直せる。
# 画面が開くのは、開いた人（orderer）だけ。全体の段階は変えないので、ほかの人は準備を続け、出発までの時計も進む。
# 同時に開けるのは1人
func open_order(who: int) -> void:
	if not office_prep() or game.state != game.S.PREP or not game.players.has(who) or orderer == who:
		return
	if orderer != 0 and game.players.has(orderer):
		game.ev.rpc_id(who, "toast", ["発注は、いま別の人が使用中", 0])
		return
	if peeper == who:
		return
	orderer = who
	game.production_sync.rpc(snapshot())


# 発注の画面を、決めずに閉じる（ホスト）。選びかけの注文は、前に決めた注文へ戻す
func close_order(who: int) -> void:
	if orderer == 0 or orderer != who:
		return
	_drop_order()
	game.production_sync.rpc(snapshot())


# 選びかけの注文を捨てて、発注の席を空ける（知らせるのは呼ぶ側）
func _drop_order() -> void:
	orderer = 0
	if game.order != ordered or not game.buying.is_empty():
		game.order = ordered.duplicate()
		game.buying = {}
		game.host_ev("order", [game.order, game.buying])


# 買った物を会社の持ち物にする（ホスト。発注を決めたとき、物を並べ直す前に呼ぶ）。貯金から払う
func purchase() -> void:
	var due: int = game.savings_cost()
	_new_names = []
	for opt: Dictionary in game.OPTIONS:
		if int(game.buying.get(opt["id"], 0)) > 0 and not opt.get("used_up", false):
			owned[opt["id"]] = true
			if opt["id"] not in bought_now:
				bought_now.append(opt["id"])
			_new_names.append(str(opt["name"]).trim_prefix("借りる"))
	wallet -= due
	bought += due
	game.buying = {}
	# ここからは、この注文が「決めた注文」。届く物・片づく物は、これで決まる
	ordered = game.order.duplicate()
	game.host_ev("order", [game.order, game.buying])
	# 先に知らせる（参加者の画面で、買った爆弾に付く袋の数が合うように）
	game.production_sync.rpc(snapshot())


# 買って会社の持ち物になった物か（物の種類で見分ける）
func is_owned(prop: Node) -> bool:
	for opt: Dictionary in game.OPTIONS:
		if owned.has(opt["id"]) and prop.kind in opt["kinds"]:
			return true
	return false


# 発注の並べ直しは、大きな物を元の現場の座標に置く。会社の庭（軽トラの横）へ寄せる
func _bring_home() -> void:
	for prop: Node in game.props.values():
		if prop.absent or prop.kind == "mark" or prop.kind == "truck":
			continue
		if prop.rider_of == game.truck.pid:
			continue
		if prop.global_position.x < 30.0:
			_move(prop, prop.global_position + OFFSET)


func pack() -> void:
	# 借り物と火薬は依頼主の制作費から払う。買った物は、会社の貯金から払ってある（purchase）
	expenses = game.order_cost()
	_bring_home()
	orderer = 0
	game.production_sync.rpc(snapshot())
	if not _new_names.is_empty():
		var note := "%s を買った（貯金 −%d）。会社の持ち物になり、次の依頼からも最初から在る" % ["・".join(_new_names), bought]
		if hazards and wallet < rent_amount():
			note += "。次の家賃は %d コイン（あと%d本）" % [rent_amount(), rent_in()]
		_new_names = []
		game.host_ev("toast", [note, 0])
	elif expenses > 0:
		game.host_ev("toast", ["借りた機材は軽トラの横に届いた。浮いた制作費 %d コインは会社の儲け" % (budget() - expenses),0])
	else:
		game.host_ev("toast", ["何も借りなかった。制作費 %d コインが、まるごと会社の儲けになる" % budget(),0])


# ---- 今日の廃材 ----

func _is_free(prop: Node) -> bool:
	return Yard.Slots.SLOTS.has(prop.kind) and _home_layout.has(prop.pid)


# 廃材置き場に出す物を選び直す（ホスト）。どの依頼でも最低限は撮れる組み合わせにする
func restock() -> void:
	var free: Array = []
	for pid: int in game.props:
		if _is_free(game.props[pid]):
			free.append(pid)
	var keep: Array = free.duplicate()
	if daily:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var pool: Array = free.duplicate()
		for n in range(pool.size() - 1, 0, -1):
			var k := rng.randi_range(0, n)
			var swap: int = pool[n]
			pool[n] = pool[k]
			pool[k] = swap
		keep = []
		# 高い足場になる物は、毎日ひとつは出す（城の告白は高低差が要る）
		var needs := [[func(q: Node) -> bool: return q.kind in ["riser", "carton", "applebox"], 1]]
		var first_day: bool = day <= 1
		if first_day:
			# 初日は遊び方を覚える日。専用の小道具をひととおり出す
			needs.append([func(q: Node) -> bool: return Cast.default_role(q.kind) == "castle", 1])
			needs.append([func(q: Node) -> bool: return Cast.default_role(q.kind) == "monster", 1])
			needs.append([func(q: Node) -> bool: return Cast.default_role(q.kind) == "city", 2])
		# 2日目からは約束しない。役は何に見立ててもいいので、専用の物が無い日は、あり合わせで工夫する。
		# 爆炎の書割は2日に1回くらい。無い日は、爆弾を借りるか、何かを爆発役にする
		if first_day or rng.randf() < 0.5:
			needs.append([func(q: Node) -> bool: return q.kind == "boomflat", 1])
		else:
			pool = pool.filter(func(pid: int) -> bool: return game.props[pid].kind != "boomflat")
		for need: Array in needs:
			var left: int = need[1]
			for pid: int in pool:
				if left > 0 and pid not in keep and (need[0] as Callable).call(game.props[pid]):
					keep.append(pid)
					left -= 1
		for pid: int in pool:
			if keep.size() < DAILY_COUNT and pid not in keep:
				keep.append(pid)
	var hidden: Array = free.filter(func(pid: int) -> bool: return pid not in keep)
	# 段ボール置き場の奥にしまってある箱は、しまったまま（出すのは cargo_kit.gd）
	for pid: int in stash:
		if pid not in hidden and game.props.has(pid) and game.props[pid].kind == "carton":
			hidden.append(pid)
	# ゴミ袋・包みの中の物（production_scrap.gd の "bag"）は、毎日しまった状態から始まる。振ると出てくる（features/junk_bags.gd）
	var bagged: Array = []
	for pid: int in game.props:
		if in_bag(game.props[pid].kind):
			bagged.append(pid)
			if pid not in hidden:
				hidden.append(pid)
	game.host_ev("stash", [hidden])
	for pid: int in free:
		var prop: Node = game.props[pid]
		if pid in hidden:
			prop.global_position = Vector3(float(pid) * 3.0, -60.0, 0.0)
		else:
			prop.restore(_home_layout[pid])
	for pid: int in bagged:
		var parked: Array = game.props[pid].get_state()
		parked[0] = Vector3(float(pid) * 3.0, -60.0, 0.0)
		parked[2] = true
		game.props[pid].restore(parked)


# ゴミ袋・包みの中にしまってある種類か（production_scrap.gd の "bag"。"small"＝ゴミ袋 / "large"＝ブルーシートの包み）
static func in_bag(kind: String) -> bool:
	return bag_of(kind) != ""


static func bag_of(kind: String) -> String:
	return str(MovieProp.Scrap.find(kind).get("bag", "")) if kind.begins_with("scrap_") else ""


# いま廃材置き場に出ている物。[[種類, 名前, 個数], ...]
func yard_stock() -> Array:
	var count := {}
	var label := {}
	var order: Array = []
	for pid: int in game.props:
		var prop: Node = game.props[pid]
		if not Yard.Slots.SLOTS.has(prop.kind) or prop.absent:
			continue
		if not count.has(prop.kind):
			order.append(prop.kind)
			label[prop.kind] = prop.label
		count[prop.kind] = int(count.get(prop.kind, 0)) + 1
	var out: Array = []
	for kind: String in order:
		out.append([kind, label[kind], count[kind]])
	return out


# 全員の画面で、しまってある物を消す（"stash" と "absent" の合図のあとに呼ぶ）
func apply_stash(hidden: Array) -> void:
	for pid: int in stash:
		if pid not in hidden and game.props.has(pid):
			# しまってある物（箱の中・人の体の中）は、消えたままにする
			game.props[pid].set_absent(game.props[pid].stored_in != 0)
	stash = hidden.duplicate()
	for pid: int in stash:
		if game.props.has(pid):
			game.props[pid].set_absent(true)


func _process(delta: float) -> void:
	# 依頼を受けている間だけ、廃材置き場の金網の穴（ペンチで切った所）がめくれて通れる。1日目（会社の紹介動画）は開けない（使う物は事務所の前に出してある。features/tutorial_day.gd）
	var want := 1.0 if phase >= 1 and not bool(job().get("debut", false)) else 0.0
	if _yard_root and not is_equal_approx(_gate, want):
		if _gate == 0.0 or _gate == 1.0:
			Sfx.play("gate", Yard.gate_point(), -2.0)
		_gate = move_toward(_gate, want, delta / 1.6)
		Yard.set_gate(_yard_root, smoothstep(0.0, 1.0, _gate))


# 現場へ持っていく物（物のID）。荷台に載っている物・それに接着した物・手に持っている物。
# with_hands が false なら、手に持っているだけの物は数えない（軽トラが運ぶ物だけ）。
# 会社の機材は、ここに入っていなくても現場へ運ばれる（gear()）
func cargo(with_hands: bool = true) -> Array[int]:
	var result: Array[int] = []
	var held_ids: Array[int] = []
	for player: Node in game.players.values():
		if player.held != 0 and with_hands:
			held_ids.append(player.held)
	for pid: int in game.props:
		var prop: Node = game.props[pid]
		if prop.absent or prop.kind in ["truck","mark"]:
			continue
		var carrier: int = prop.rider_of
		var seen := 0
		while carrier != 0 and seen < game.props.size():
			if carrier == game.truck.pid:
				result.append(pid)
				break
			var parent_prop: Node = game.props.get(carrier)
			carrier = parent_prop.rider_of if parent_prop else 0
			seen += 1
		if ((prop.holder != 0 and with_hands) or pid in held_ids) and not pid in result:
			result.append(pid)
	for pid: int in game.props:
		if pid not in result and (game.adhesive.connected_to(pid,game.truck.pid) or result.any(func(carrier): return game.adhesive.connected_to(pid,carrier))): result.append(pid)
	# しまってある物は、入れ物といっしょに運ばれる。箱が運ばれるなら、中身も数える。
	# 人が体にしまっている物は、手に持っている物と同じ扱い（軽トラが運ぶ物には数えない）
	for pid: int in game.props:
		var keeper: int = game.props[pid].stored_in
		if keeper == 0 or pid in result:
			continue
		if (keeper > 0 and keeper in result) or (keeper < 0 and with_hands and game.players.has(-keeper)):
			result.append(pid)
	return result

# ---- 荷台の積みすぎ ----

# 物のかさ（小1・中2・大3）
func bulk(prop: Node) -> int:
	var longest: float = maxf(prop.half.x, maxf(prop.half.y, prop.half.z)) * 2.0
	return 1 if longest < 0.6 else (2 if longest < 1.3 else 3)


# 荷台の大きさだけで容量を決める。重りは荷台を広げない
func bed_capacity() -> int:
	return BED_CAPACITY + (12 if int(levels.get("car", 0)) >= 1 else 0)


# 荷台の様子。used＝積んだかさ / cap＝安全に載るかさ / risky＝はみ出して落ちるかもしれない物（物のID）
# 会社の機材と台本は、わざわざ荷台に積んでも数えない。下に積んだ物から順に数え、上の物からはみ出す
func bed_load() -> Dictionary:
	var riders: Array = []
	for pid: int in game.props:
		var prop: Node = game.props[pid]
		if prop.absent or prop.rider_of != game.truck.pid or prop.kind in GEAR_KINDS or prop.kind == "script":
			continue
		riders.append(prop)
	riders.sort_custom(func(a: Node, b: Node) -> bool:
		return a.ride_local.origin.y < b.ride_local.origin.y if not is_equal_approx(a.ride_local.origin.y, b.ride_local.origin.y) else a.pid < b.pid)
	var used := 0
	var risky: Array = []
	var cap := bed_capacity()
	# ロープの掛け方は、ここでは数えない（押さえが効いているかは、ゲームの中の見た目で判断する）
	for prop: Node in riders:
		used += bulk(prop)
		if used > cap:
			risky.append(prop.pid)
	return {"used": used, "cap": cap, "risky": risky}


# 突風（野外の空き地だけ）。音と案内のあと、固定していない物を風下へ押す。
# 面が広くて軽い物ほどよく動く。G で固定した物・手に持っている物・台に載せた物は動かない
func _wind(delta: float) -> void:
	if not hazards or shoots_home() or site_index() != 2 or game.replaying:
		return
	_gust_in -= delta
	if not _gust_warned and _gust_in <= GUST_WARN:
		_gust_warned = true
		game.host_ev("sfx", ["wind", null])
		game.host_ev("toast", ["風が来る！ 軽い物は重りや接着剤で支えよう", 1])
	if _gust_in > 0.0:
		return
	_gust_in = _rng.randf_range(GUST_EVERY.x, GUST_EVERY.y)
	_gust_warned = false
	gust(Vector3(1, 0, 0.35).rotated(Vector3.UP, _rng.randf_range(-0.5, 0.5)).normalized(), 1.0)


# 突風を吹かせる。押される物の数を返す。風は GUST_BLOW 秒のあいだ吹き続ける
func gust(dir: Vector3, strength: float) -> int:
	_gust_dir = dir.normalized() * strength
	_gust_left = GUST_BLOW
	return _blow(0.0)


# 風が吹いている間、毎フレーム呼ぶ。面が広くて軽い物ほど強く押され、重い物・小さい物は動かない
func _blow(delta: float) -> int:
	var moved := 0
	for prop: Node in game.props.values():
		if prop.absent or prop.immovable or prop.fixed or prop.holder != 0 or prop.kind == "mark":
			continue
		if "operator" in prop and prop.operator != 0:
			continue
		# カエルの警官が「止まれ！」で止めている物（cast_talent.gd）は、風にも押されない
		if game.get("talent") != null and game.talent.halted(prop.pid):
			continue
		if _parked.has(prop.pid):
			# 搬入口に並べたままの機材は、荷下ろしの間に風で倒さない。誰かが動かしたあとは、ふつうの物と同じ
			if prop.global_position.distance_to(_parked[prop.pid]) < 0.6:
				continue
			_parked.erase(prop.pid)
		# 風を受ける面の広さ ÷ 重さ で、押される強さ（加速度）を決める。床との摩擦より弱ければ動かない
		var area: float = maxf(prop.half.x, prop.half.z) * prop.half.y * 4.0
		var accel: float = clampf(area * 34.0 / maxf(prop.mass, 0.3), 0.0, 11.5) * _gust_dir.length()
		if accel < 4.0:
			continue
		moved += 1
		if delta > 0.0:
			prop.sleeping = false
			if prop.rolls:
				# キャスターの付いた台（台車・モニター台など）は、低く広い台で踏ん張るので、風では倒れない。
				# 足元の高さを押す（倒す回りの力が生まれない）。押す力が床との摩擦より強ければ、ずれる
				var low: Vector3 = prop.center_global() - prop.global_position
				low.y = 0.1
				prop.apply_force(_gust_dir.normalized() * accel * prop.mass, low)
				continue
			prop.apply_central_force(_gust_dir.normalized() * accel * prop.mass)
			# 背の高い物は上のほうを押されて倒れる
			prop.apply_torque(Vector3(_gust_dir.z, 0, -_gust_dir.x).normalized() * accel * prop.mass * prop.half.y * 0.35)
	return moved


# 段差を踏んだ：はみ出した物が、確率で荷台から転げ落ちる
func _bump(_chance: float) -> void:
	# 車体の上下動・摩擦・重力で落下する。接着済みの荷物も同じ物理で扱う。
	game.host_ev("sfx", ["bump", game.truck.global_position])


func crew_ready() -> String:
	var count := 0
	for player: Node3D in game.players.values():
		if player.global_position.distance_to(HOME_TRUCK) < 9.0:
			count += 1
	return "軽トラのそば　%d / %d 人" % [count,game.players.size()]

# 出発できるか：全員が軽トラのそばにいればいい（会社の機材は、積まなくても、いっしょに運ばれる）
func can_depart() -> bool:
	if phase != 2:
		return false
	for player: Node3D in game.players.values():
		if player.global_position.distance_to(HOME_TRUCK) >= 9.0:
			return false
	return true

func loadout_status() -> String:
	var data := loadout()
	var lines: Array[String] = []
	for row: Array in data["gear"]:
		lines.append("✔ %s%s（いっしょに運ぶ）" % [row[1], " ×%d" % int(row[2]) if int(row[2]) > 1 else ""])
	var book: Array = data["script"]
	if not book.is_empty():
		lines.append(("✔ " if book[2] else "□ ") + "%s（持つか、荷台に積む）" % book[1])
	lines.append("")
	for item: Array in data["items"]:
		lines.append("・%s ×%d" % [item[1], int(item[2])])
	return "\n".join(lines)

# 積み込み確認の中身。
#   gear  ：会社の機材 [[種類, 名前, 台数], ...]。積まなくても、出発するといっしょに運ばれる
#   script：台本 [種類, 名前, 持つか積むかしたか]。1冊だけなので、忘れると現場で読めない
#   items ：荷台に積んだ物・手に持っている物・箱の中身 [[種類, 名前, 個数, 落ちそうな数], ...]
# 配役表は、積み込み確認には出さない（台本を持っている人だけが、台本のページで見る。cast_sheet()）
func loadout() -> Dictionary:
	var ids := cargo()
	var gear_rows: Array = []
	var row_of := {}
	for prop: Node in gear():
		if row_of.has(prop.kind):
			gear_rows[row_of[prop.kind]][2] += 1
		else:
			row_of[prop.kind] = gear_rows.size()
			gear_rows.append([prop.kind, GEAR_NAMES.get(prop.kind, prop.label), 1])
	var book: Array = [script_prop.kind, script_prop.label, script_prop.pid in ids] if script_prop else []
	var count := {}
	var label := {}
	var order: Array = []
	for pid: int in ids:
		var prop: Node = game.props[pid]
		if prop.kind in GEAR_KINDS or prop.kind == "script":
			continue
		if not count.has(prop.kind):
			order.append(prop.kind)
			label[prop.kind] = prop.label
		count[prop.kind] = int(count.get(prop.kind, 0)) + 1
	var bed := bed_load()
	var risky := {}
	for pid: int in bed["risky"]:
		risky[game.props[pid].kind] = int(risky.get(game.props[pid].kind, 0)) + 1
	var items: Array = []
	for kind: String in order:
		items.append([kind, label[kind], count[kind], int(risky.get(kind, 0))])
	return {"gear": gear_rows, "script": book, "items": items, "used": bed["used"], "cap": bed["cap"]}


# ---- 会社の機材と、手に持って行く物 ----

# 会社の機材（物のIDの小さい順）
func gear() -> Array:
	var out: Array = []
	for pid: int in game.props:
		var prop: Node = game.props[pid]
		if prop.kind in GEAR_KINDS and not prop.absent:
			out.append(prop)
	return out


# その機材が、同じ種類の中で何番目か（並べる場所が決まる）
func _gear_index(prop: Node) -> int:
	var n := 0
	for other: Node in gear():
		if other == prop:
			break
		if other.kind == prop.kind:
			n += 1
	return n


func _gear_slot(table: Dictionary, kind: String, index: int) -> Array:
	var slots: Array = table.get(kind, [])
	return slots[mini(index, slots.size() - 1)] if not slots.is_empty() else [Vector2.ZERO, 0.0]


# 会社の機材置き場での置き場所 [場所, 向き]
func gear_home(kind: String, index: int) -> Array:
	var slot: Array = _gear_slot(GEAR_HOME, kind, index)
	var corner: Vector2 = Office.GEAR_YARD.position
	return [Vector3(corner.x + slot[0].x, 0.03, corner.y + slot[0].y), float(slot[1])]


# 現場の搬入口での置き場所 [場所, 向き]
func gear_site(kind: String, index: int) -> Array:
	var slot: Array = _gear_slot(GEAR_SITE, kind, index)
	return [Vector3(game.SPAWN.x + slot[0].x, 0.03, game.SPAWN.z + slot[0].y), float(slot[1])]


# 会社の機材を、機材置き場に並べる（ホスト）。事務所へ戻ったときも、ここへ戻る
func stage_gear() -> void:
	var count := {}
	for prop: Node in gear():
		var n: int = count.get(prop.kind, 0)
		count[prop.kind] = n + 1
		var home: Array = gear_home(prop.kind, n)
		_let_go(prop)
		var state: Array = prop.get_state()
		state[0] = home[0]
		state[1] = Quaternion(Vector3.UP, home[1])
		state[2] = false
		prop.restore(state)
		_home_layout[prop.pid] = prop.get_state()


# 置き直す前に、手・操作・荷台から外す
func _let_go(prop: Node) -> void:
	if prop.holder != 0:
		game.host_release(prop)
	if "operator" in prop and prop.operator != 0:
		game._stop_operating(prop)
	if prop.rider_of != 0:
		game.host_unload(prop)


# その物と、接着でつながった物（いっしょに動かす）
func _group(prop: Node) -> Array:
	var out: Array = [prop]
	if game.adhesive == null or not game.adhesive.has_method("connected_ids"):
		return out
	for pid: int in game.adhesive.connected_ids(prop.pid):
		var member: Node = game.props.get(pid)
		if member != null and member != prop and not member.immovable:
			out.append(member)
	return out


# prop を to へ置いたときの、まとまり全体を囲む箱（ワールド座標）
func _group_box(prop: Node, group: Array, to: Transform3D) -> AABB:
	var move: Transform3D = to * prop.global_transform.affine_inverse()
	var box := AABB()
	for i in group.size():
		var one: AABB = (move * (group[i] as Node3D).global_transform) * (game.body_bounds(group[i]) as AABB)
		box = one if i == 0 else box.merge(one)
	return box


# その場所に立てて置くときの置き方。いちばん低い所が、spot の高さに来る
func _stand_at(prop: Node, group: Array, spot: Vector3, yaw: float) -> Transform3D:
	var to := Transform3D(Basis(Vector3.UP, yaw), Vector3(spot.x, 0.0, spot.z))
	to.origin.y = spot.y - _group_box(prop, group, to).position.y
	return to


# 物（と、いっしょに動く物）を、その置き方へ移す
func _place_group(prop: Node, group: Array, to: Transform3D, fixed: bool) -> void:
	var move: Transform3D = to * prop.global_transform.affine_inverse()
	var targets: Array[Transform3D] = []
	for member: Node3D in group:
		targets.append(move * member.global_transform)
	for i in group.size():
		var state: Array = group[i].get_state()
		state[0] = targets[i].origin
		state[1] = Quaternion(targets[i].basis.orthonormalized())
		state[2] = fixed
		group[i].restore(state)


# 荷台に積まない物を、先に現場へ送る（接着でつながった物もいっしょ）。
# いったん置きたい場所に固めて置き、着いてから _settle_ahead() が空いている場所を確かめて置き直す
func _send_ahead(prop: Node, spot: Vector3, yaw: float, sent: Dictionary) -> void:
	if sent.has(prop.pid):
		return
	var group: Array = _group(prop)
	for member: Node in group:
		_let_go(member)
		sent[member.pid] = true
	_place_group(prop, group, _stand_at(prop, group, spot, yaw), true)
	_ahead.append([prop.pid, spot, yaw])


# 先に送った物（会社の機材・手に持ってきた物）を、搬入口のそばの空いている場所に立てて並べる
func _settle_ahead() -> void:
	# 現場の壁や床、軽トラが置かれてから、空いている場所を調べる
	await get_tree().physics_frame
	await get_tree().physics_frame
	if phase != 4:
		return
	var taken: Array[Rect2] = []
	var glued := false
	for item: Array in _ahead:
		var prop: Node = game.props.get(item[0])
		if prop == null or prop.absent:
			continue
		# 固めて置いてあるので、ここで必ず置き直して固定を解く（固定のままだと、持てない）
		var group: Array = _group(prop)
		glued = glued or group.size() > 1
		var to: Transform3D = _stand_at(prop, group, _free_spot(prop, group, item[1], item[2], taken), item[2])
		var box: AABB = _group_box(prop, group, to)
		taken.append(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))
		_place_group(prop, group, to, false)
		for member: Node3D in group:
			_parked[member.pid] = member.global_position
	_ahead = []
	if glued:
		game.adhesive.rebuild()


# 置きたい場所が空いていれば、そこ。ふさがっていたら、搬入口のまわりを近い順に探す（見つからなければ、置きたい場所のまま）
func _free_spot(prop: Node, group: Array, want: Vector3, yaw: float, taken: Array[Rect2]) -> Vector3:
	var skip: Array[RID] = []
	for member: Node in group:
		skip.append(member.get_rid())
	if _spot_free(prop, group, want, yaw, skip, taken):
		return want
	var gate: Vector3 = game.SPAWN
	var spots: Array[Vector3] = []
	for ix in 14:
		for iz in 20:
			var z: float = gate.z - 6.4 + iz * 0.6
			# 軽トラの後ろの通り道（着いた人が立つ所）は空けておく
			if absf(z - gate.z) >= 1.9:
				spots.append(Vector3(gate.x - 3.0 + ix * 0.6, want.y, z))
	spots.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(want) < b.distance_squared_to(want))
	for spot: Vector3 in spots:
		if _spot_free(prop, group, spot, yaw, skip, taken):
			return spot
	return want


# その場所に立てて置けるか：壁の中・物の上・人や役者の立ち位置・先に並べた物の場所ではない
func _spot_free(prop: Node, group: Array, spot: Vector3, yaw: float, skip: Array[RID], taken: Array[Rect2]) -> bool:
	var box: AABB = _group_box(prop, group, _stand_at(prop, group, spot, yaw))
	var foot := Rect2(box.position.x, box.position.z, box.size.x, box.size.z).grow(0.12)
	for other: Rect2 in taken:
		if foot.intersects(other):
			return false
	# 役者（待機中は当たり判定が無い）と、足元の立ち位置の印
	var keep_out := foot.grow(1.2)
	for actor: Node3D in game.actors:
		var mark: Vector3 = actor.mark.global_position
		if keep_out.has_point(Vector2(actor.global_position.x, actor.global_position.z)) or keep_out.has_point(Vector2(mark.x, mark.z)):
			return false
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	# 壁・物・人に重ならない（床の少し上から、てっぺんまでの箱で調べる）
	var shape := BoxShape3D.new()
	shape.size = Vector3(foot.size.x, maxf(box.size.y - 0.12, 0.1), foot.size.y)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, Vector3(foot.get_center().x, box.end.y - shape.size.y * 0.5, foot.get_center().y))
	query.collision_mask = 1 | 2 | 4 | 8 | 16
	query.exclude = skip
	if not space.intersect_shape(query, 1).is_empty():
		return false
	# 足元：床があって、ほかの物の上ではない（中心と四隅）
	for corner: Vector2 in [foot.get_center(), foot.position, foot.end, Vector2(foot.position.x, foot.end.y), Vector2(foot.end.x, foot.position.y)]:
		var ray := PhysicsRayQueryParameters3D.create(Vector3(corner.x, box.position.y + 0.4, corner.y), Vector3(corner.x, box.position.y - 0.5, corner.y), 1 | 2 | 4 | 16)
		ray.exclude = skip
		var hit: Dictionary = space.intersect_ray(ray)
		if hit.is_empty() or "pid" in hit["collider"]:
			return false
	return true


func depart() -> void:
	if not can_depart():
		game.host_ev("toast", ["全員が軽トラのそばへ集まろう（会社の機材は、積まなくてもいっしょに運ばれる）",1])
		return
	if shoots_home():
		_shoot_home()
		return
	# 荷台に載っている物（と、それに接着した物）は、軽トラが運ぶ。
	# 会社の機材は、荷台に積んでいなければ、先に現場の搬入口へ送る。わざわざ積んだ機材は、荷台に載ったまま行く
	var riding := cargo(false)
	var sent := {}
	_ahead = []
	_parked = {}
	var count := {}
	for prop: Node in gear():
		var n: int = count.get(prop.kind, 0)
		count[prop.kind] = n + 1
		if prop.pid not in riding:
			var slot: Array = gear_site(prop.kind, n)
			_send_ahead(prop, slot[0], slot[1], sent)
	# 手に持っている物は、持ったまま乗る（現場では、搬入口の自分の立つ所のそばに出る）。
	# 荷台の上で持っていた物は、手を離した所に載る
	var ids: Array = game.players.keys()
	ids.sort()
	for prop: Node in game.props.values():
		if prop.holder == 0 or prop.absent:
			continue
		var place: int = maxi(ids.find(prop.holder), 0)
		game.host_release(prop)
		# 手を離した所が荷台（や、荷台に載った台車）の上なら、そのまま軽トラが運ぶ。それ以外は、持ったまま乗ったことにする
		if prop.pid not in riding and prop.pid not in cargo(false):
			_send_ahead(prop, game.SPAWN + Vector3(float(place) * 0.8, -0.07, 1.8), 0.0, sent)
	_loaded = cargo()
	# 車体の正面（ローカル +Z）を走行方向へ向ける。荷物は荷台の相対位置で追従する。
	_move(game.truck, HOME_TRUCK, 0.0)
	peeper = 0
	_drop_order()
	phase = 3
	trip_time = 0.0
	game.host_ev("sfx", ["engine", game.truck.global_position])
	_bumped = 0
	lost = []
	game.production_sync.rpc(snapshot())
	game.move_crew(game.truck.global_transform * Vector3(game.truck.deck_c.x,game.truck.deck_top + 0.35,game.truck.deck_c.y), PI)
	_sync_vehicle_riders()

func _sync_vehicle_riders() -> void:
	var ids: Array = game.players.keys()
	ids.sort()
	game.truck.set_traveling(phase == 3)
	for i in ids.size():
		var player: Node = game.players[ids[i]]
		if not player.has_method("board_vehicle"): continue
		if phase == 3:
			player.board_vehicle(game.truck,i)
		else:
			player.leave_vehicle()

func _physics_process(delta: float) -> void:
	_sync_vehicle_riders()
	if phase == 3:
		var driver: Dictionary = game.truck.seat(0)
		_trip_camera.global_position = game.truck.global_transform * Vector3(signf(driver.hip.x) * 5.2,3.1,5.3)
		_trip_camera.look_at(game.truck.global_position + Vector3(0,1.5,0))
		_trip_camera.make_current()
	if not Net.is_host():
		return
	if phase == 3:
		trip_time += delta
		# 段差では車体が跳ねる
		var hop := 0.0
		for at: float in BUMPS:
			var since: float = trip_time - at
			if since > 0.0 and since < 0.35:
				hop = maxf(hop, sin(since / 0.35 * PI) * 0.16)
		var distance := 2.5*trip_time*trip_time if trip_time<1.0 else 5.0*trip_time-2.5
		game.truck.drive_to(HOME_TRUCK + Vector3(0,hop,distance))
		_sync_vehicle_riders()
		if _bumped < BUMPS.size() and trip_time >= BUMPS[_bumped]:
			_bumped += 1
			_bump(FALL_CHANCE)
		if trip_time >= 8.0:
			arrive()
	elif phase in [1,2]:
		prep_left -= delta
	elif phase == 4 and not expired and game.state != game.S.DELIVERED:
		if game.state == game.S.TAKE and not game.take_held():     # 場転でフィルムを止めている間は、映り込みを数えない
			notes.tick(delta)
			bonus_progress = "映り込み %.1f秒" % notes.crew_seconds if job()["bonus"] == "no_crew" else ("月 %.1f / 2秒" % notes.moon_seconds if job()["bonus"] == "moon" else "最初のテイク" if game.takes.is_empty() else "撮り直し中")
		_wind(delta)
		if _gust_left > 0.0:
			_gust_left -= delta
			_blow(delta)
		lease_left = maxf(0.0,lease_left - delta)
		if _notice < _warnings.size() and lease_left <= _warnings[_notice]:
			game.host_ev("toast", ["スタジオ返却まで %d秒！" % int(_warnings[_notice]),0])
			_notice += 1
		if lease_left <= 0.0:
			expire()
	_sync -= delta
	if _sync <= 0.0:
		_sync = 0.5
		game.production_sync.rpc(snapshot())

func arrive() -> void:
	# 場面の切り替えだけを瞬間移動する。移動中に落ちた物は道路へ残す。
	var carried := cargo()
	var old: Transform3D = game.truck.global_transform
	var dest := Transform3D(Basis(Vector3.UP,PI*0.5),SITE_TRUCK)
	var transfer := dest * old.affine_inverse()
	var states := {}
	for pid in carried:
		var prop: Node = game.props[pid]
		if prop.stored_in != 0:
			continue      # しまってある物は待機場所のまま。入れ物といっしょに着く
		var world: Transform3D = transfer * prop.global_transform
		states[pid] = [world,prop.rider_of]
	_move(game.truck,SITE_TRUCK,PI*0.5)
	for pid in states:
		var prop: Node = game.props[pid]
		var world: Transform3D = states[pid][0]
		var s: Array = prop.get_state()
		s[0] = world.origin
		s[1] = Quaternion(world.basis.orthonormalized())
		prop.restore(s)
		prop.rider_of = states[pid][1]
	for pid in states:
		var prop: Node = game.props[pid]
		if prop.rider_of != 0:
			prop.ride_local = game.props[prop.rider_of].global_transform.affine_inverse()*prop.global_transform
	for pid in _loaded:
		if pid in carried:
			continue
		var fallen: Node = game.props[pid]
		if fallen.kind in GEAR_KINDS:
			# 会社の機材は置いていかない。道中で荷台から落ちても、現場の搬入口に出す
			var slot: Array = gear_site(fallen.kind, _gear_index(fallen))
			_send_ahead(fallen, slot[0], slot[1], {})
		else:
			lost.append(fallen.label)
	game.adhesive.rebuild()
	phase = 4
	var late := maxf(0.0,-prep_left) if hazards else 0.0
	lease_left = maxf(MIN_LEASE,lease_time()-late)
	_gust_in = _rng.randf_range(GUST_EVERY.x,GUST_EVERY.y)
	_gust_warned = false
	_notice = 0
	while _notice < _warnings.size() and lease_left <= _warnings[_notice]: _notice += 1
	game._set_state(game.S.PREP)
	game.production_sync.rpc(snapshot())
	game.move_crew(game.SPAWN,-PI/2)
	game.host_ev("toast",["到着！ 会社の機材は搬入口に並べてある。荷台の物を降ろそう。撮影に使えるのは%d分%02d秒" % [int(lease_left)/60,int(lease_left)%60],0])
	_settle_ahead()


# 会社の前で撮る（出発しない）：物はその場のまま、撮影の時計を回し始める
func _shoot_home(debut := false) -> void:
	peeper = 0
	_drop_order()
	_ahead = []
	_parked = {}
	_loaded = []
	lost = []
	phase = 4
	var late := maxf(0.0,-prep_left) if hazards else 0.0
	lease_left = maxf(MIN_LEASE,lease_time()-late)
	_notice = 0
	while _notice < _warnings.size() and lease_left <= _warnings[_notice]: _notice += 1
	game._set_state(game.S.PREP)
	game.production_sync.rpc(snapshot())
	if debut:
		# 1日目：廃材置き場は閉まったまま。使えそうな物は、事務所の前に出してある（features/tutorial_day.gd）
		game.host_ev("toast",["撮影は、事務所の前で。使えそうな物は、事務所の前に出しておいた。撮影に使えるのは%d分%02d秒" % [int(lease_left)/60,int(lease_left)%60],0])
	else:
		game.host_ev("toast",["ここで撮る！ 撮影現場は、事務所の前。廃材置き場も機材置き場も、すぐそば。撮影に使えるのは%d分%02d秒" % [int(lease_left)/60,int(lease_left)%60],0])


func expire() -> void:
	expired = true
	if game.replaying:
		game._end_replay()
	if game.state == game.S.TAKE:
		game._cut()
	elif game.takes.is_empty():
		game._begin_take()
		game._cut()
	else:
		game._set_state(game.S.RESULT)
	game.production_sync.rpc(snapshot())
	game.host_ev("toast", ["管理人『次の予約が入ってるよ！』 いまあるテイクを選んで納品しよう",1])

func settle(index: int) -> void:
	var passed: Array = game.takes[index]["passed"]
	var count := passed.count(true)
	last_payment = take_fee(index)
	var extras: Dictionary = game.takes[index].get("extras",{})
	# 使わなかった制作費は、ギャラと一緒に会社の貯金へ入る
	saved = maxi(0, budget() - expenses)
	wallet += last_payment + saved
	# 家賃：RENT_EVERY 本ごとに払う。払えなければ倒産
	rent_paid = 0
	bankrupt = false
	if hazards and day % RENT_EVERY == 0:
		var due := rent_amount()
		if wallet >= due:
			wallet -= due
			rent_paid = due
			rent_no += 1
		else:
			bankrupt = true
	# 評判：出来で上下する。格が変わったら、新しい依頼主から電話が来る
	var rank_before := rank()
	rep_change = rep_delta(count, passed.size(), bool(extras.get("bonus_ok",false)), chosen_slot)
	reputation = maxi(0, reputation + rep_change)
	if bool(job().get("finale", false)) and count == passed.size() and not bankrupt:
		finale_done = true
	last_flubs.clear()
	if finale_done:
		last_flubs.append("ハリウッド監督『ブラボー！ この予算で、この画。次はハリウッドで会おう』")
	elif rank() > rank_before:
		last_flubs.append(str(RANK_CALLS[rank() - 1]))
	elif rank() < rank_before:
		last_flubs.append("評判が落ちた。大きな依頼主からの電話が、しばらく来なくなりそうだ")
	last_flubs.append("追加注文『%s』：%s" % [job()["bonus_title"],"達成！ +150コイン" if extras.get("bonus_ok",false) else "今回は未達"])
	last_flubs.append_array(notes.observations(extras))
	# 見立て：むりやりな役と、コンボへのひとこと
	var cast: Dictionary = extras.get("cast",{})
	var said := false          # 依頼主が見立てについて、もうひとこと言ったか
	for combo: Dictionary in cast.get("combos",[]):
		var big: bool = str(combo["name"]).begins_with("大爆発") or str(combo["name"]).begins_with("超")
		last_flubs.append(("%s +%d コイン" if big else "コンボ %s +%d コイン") % [combo["name"],int(combo["coins"])])
		if str(combo.get("line","")) != "" and not said:
			last_flubs.append(str(combo["line"]))
			said = true
	# 仕組みが足した上乗せ（見ごたえ など）
	for line: Array in fee_lines(index):
		last_flubs.append("%s +%d コイン" % [str(line[0]), int(line[1])])
	var liked: Dictionary = cast.get("liked",{})
	if int(liked.get("roles",0)) > 0:
		last_flubs.append("依頼主の好み %s を %d役で使った +%d コイン" % [Cast.chips(liked["attrs"]),int(liked["roles"]),int(liked["coins"])])
		if not said:
			last_flubs.append("依頼主『そう、こういうのが見たかった！』")
			said = true
	var forced: Array = []
	for row: Dictionary in cast.get("roles",[]):
		if int(row["grade"]) == 0:
			forced.append("%sが%s" % [row["name"],row["items"]])
	if not forced.is_empty() and not said:
		last_flubs.append("依頼主『%s？ まあ、勢いはあった』" % "、".join(forced))
		said = true
	for result: Dictionary in game.takes[index]["results"]:
		if not result["ok"]:
			last_flubs.append(str(result["title"]) + "：" + str(result["detail"]))
	# 最初の一本（会社の紹介動画）：ネットに上げると、テレビ局の人がコメントを書いていく（帰社すると、その人から電話が鳴る。2日目から、ほかの依頼が来る）
	if bool(job().get("debut", false)):
		last_flubs.append("コメント欄『地方テレビ局のランプと申します。%sさんの動画、拝見しました。のちほど、お電話します』" % COMPANY)
		said = true
	if count == passed.size() and count > 0 and not said:
		last_flubs.append("依頼主『あの怪獣、本物を呼んだのかと思ったよ！』" if job()["script"] == "kaiju" else "依頼主『これをこの予算で？ 次も頼むよ！』")
	elif count == 0:
		last_flubs.append("依頼主『予告編の素材としては…味がある』")
	phase = 5
	game.production_sync.rpc(snapshot())
	if bankrupt:
		game.host_ev("toast",["納品はした。だが家賃 %d コインが払えない…会社は倒産した" % rent_amount(),1])
	elif rent_paid > 0:
		game.host_ev("toast",["納品完了！ ギャラ %d ＋ 浮かせた制作費 %d。家賃 %d を払った" % [last_payment, saved, rent_paid],0])
	else:
		game.host_ev("toast",["納品完了！ ギャラ %d ＋ 浮かせた制作費 %d コイン" % [last_payment, saved],0])
	game._grab_mouse(false)

func take_fee(index: int) -> int:
	var take: Dictionary = game.takes[index]
	var passed: Array = take["passed"]
	var count: int = passed.count(true)
	# 場面1つにつき 250。全部そろえば上乗せ（3場面は 300。5場面の依頼は 400 で、満額が今までの 1.5 倍になる）
	var all_in: int = int(job().get("fee_all", 300)) if count == passed.size() else 0
	var extra := 0
	for line: Array in fee_lines(index):
		extra += int(line[1])
	return maxi(0, 150 + count * 250 + all_in + (150 if take.get("extras",{}).get("bonus_ok",false) else 0) + cast_coins(index) + extra)


# 仕組みが足すギャラの上乗せ [[文, コイン], ...]（見ごたえ など。各仕組みの hook_fee_lines）
func fee_lines(index: int) -> Array:
	var out: Array = []
	var hooks: Variant = game.get("hooks")
	if hooks == null:
		return out
	for target: Object in hooks.in_order("hook_fee_lines"):
		out.append_array(target.hook_fee_lines(index))
	return out


# 見立てとコンボで増減するコイン
func cast_coins(index: int) -> int:
	var extras: Dictionary = game.takes[index].get("extras",{})
	return int((extras.get("cast",{}) as Dictionary).get("coins",0))

func bonus_status() -> String:
	var text: String = "追加注文 +150コイン：" + str(job()["bonus_title"])
	if game.state in [game.S.RESULT,game.S.REPLAY] and not game.takes.is_empty():
		var extra: Dictionary = game.takes[game.selected].get("extras",{})
		return text + ("　✔ 達成" if extra.get("bonus_ok",false) else "　未達") + "\n納品料見込み：%dコイン" % take_fee(game.selected)
	if game.state == game.S.TAKE:
		return text + "　" + bonus_progress
	return text + "（本編%d場面の成立も必要）" % (job()["scenes"] as Array).size()

func return_office() -> void:
	if phase != 5:
		return
	# 人が体にしまっている物（キャラの特技）は、置き場所を戻す前に外へ出す（あとだと、見えない物が事務所に残る）
	if game.talent != null:
		game.talent.host_clear_all()
	_ahead = []
	_parked = {}
	# 使い残した火薬の袋は、残りの量ごと次の依頼へ持ち越す。倒産したら、会社の持ち物は全部無くなる
	if bankrupt:
		owned = {}
		sack_stock = []
	elif game.bomb_kit != null:
		sack_stock = game.bomb_kit.leftover()
	# 今回買った爆弾に付いてきた袋も、ここからは「持ち越した袋」として数える
	bought_now = []
	game.production_sync.rpc(snapshot())
	# 各仕組みの hook_return_office。段ボール箱：中身を全部出し、ロープをほどき、箱を置き場の奥へ戻す（中身は、下で元の場所へ戻る）
	game.hooks.run("hook_return_office")
	for prop: Node in game.props.values():
		if prop.holder != 0:
			game.host_release(prop)
		if prop.rider_of != 0:
			game.host_unload(prop)
		if "operator" in prop and prop.operator != 0:
			game._stop_operating(prop)
		if _home_layout.has(prop.pid):
			prop.restore(_home_layout[prop.pid])
	orderer = 0
	ordered = {}
	game.order = {}
	game.buying = {}
	game.host_ev("order", [game.order, game.buying])
	game._apply_order()
	_move(game.truck,HOME_TRUCK)
	# All company and free props return to their initial yard positions; rental selection is next job's choice.
	# 買った物は別（借りた物が届く場所に置く。現場へ持って行った物も、ここへ戻る）
	for pid in _home_layout:
		var prop: Node = game.props[pid]
		if prop.kind != "mark" and not prop.absent and prop.rider_of == 0 and not is_owned(prop):
			_move(prop, _home_layout[pid][0])
	_bring_home()
	if finale_done:
		# エンディング：ハリウッドへ。会社は次の世代へ（最初から、もう一度）
		game.host_ev("toast", ["エンディング：%s は、ハリウッドへ旅立った。事務所には、新しい制作班がやって来る" % COMPANY, 0])
	if bankrupt or finale_done:
		# 倒産：新しい会社を立ち上げて、最初からやり直す
		reputation = 0
		finale_done = false
		chosen_slot = ""
		wallet = START_WALLET
		company = ""          # 新しい会社（名前は打ち込まない。看板には手で書く）
		for id: String in levels:
			levels[id] = 0
		day = 0
		rent_no = 0
		bankrupt = false
		game.host_ev("toast", ["新しい会社を立ち上げた。貯金 %d コインからやり直し" % START_WALLET, 0])
	saved = 0
	rent_paid = 0
	rep_change = 0
	casting = {}
	cast_face = {}
	slides = {}
	peeper = 0
	phase = 0
	day += 1
	park_truck_for_day()
	restock()
	# 各仕組みの hook_office_ready。段ボール置き場に、箱を出し直す
	game.hooks.run("hook_office_ready")
	game._set_state(game.S.PREP)
	game.production_sync.rpc(snapshot())
	game.move_crew(Office.SPAWN_POINT, 0.0)

# 1日目（会社の紹介動画の日）は、軽トラを事務所の前に置かない。移動が無いので、あると「乗るの？」と迷う。
# 2日目の朝（事務所へ戻ったとき）、いつもの所に来ている
const TRUCK_AWAY := Vector3(80, 0, 150)


func park_truck_for_day() -> void:
	if game.truck == null or not Net.is_host() or debut_job() < 0:
		return
	var parked_away: bool = game.truck.global_position.distance_to(TRUCK_AWAY) < 1.0
	# 1日目の朝と、紹介動画を撮っている間だけ。1日目にほかの依頼を受けたとき（自動確認など）は、いつもの所へ
	var away: bool = day <= 1 and (phase == 0 or bool(job().get("debut", false)))
	if away and not parked_away:
		_move(game.truck, TRUCK_AWAY, 0.0)
	elif not away and parked_away:
		_move(game.truck, HOME_TRUCK, 0.0)


func _move(prop: Node3D, pos: Vector3, yaw: float = NAN) -> void:
	var carrier: int = prop.rider_of
	var local: Transform3D = prop.ride_local
	var state: Array = prop.get_state()
	state[0] = pos
	if not is_nan(yaw):
		state[1] = Quaternion(Vector3.UP, yaw)
	prop.restore(state)
	if carrier != 0 and game.props.has(carrier):
		game._set_rider(prop,game.props[carrier],local)

func _configure_site() -> void:
	_configured_job = chosen_job
	var site: int = site_index()
	_configured_site = site
	if _site_root:
		_site_root.queue_free()
	_site_root = Node3D.new()
	_site_root.name = "JobLocation"
	game.add_child(_site_root)
	for wall in _original_walls:
		wall.visible = site == 0
		for collider in wall.get_children():
			if collider is CollisionShape3D:
				collider.set_deferred("disabled",site != 0)
	if site == 1:
		var studio := Assets.decorate(_site_root,"studio")
		studio.position = Vector3(0,0,-2)
	elif site == 2:
		var yard := Assets.decorate(_site_root,"yard")
		yard.position = Vector3(8,0,-6)
	Location.build(_site_root,game.font,site)
