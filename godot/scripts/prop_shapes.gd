extends RefCounted
## 持てる物の当たり判定の表。見た目（モデル）に合わせた形の組み合わせを、物ごとに並べる。
## ここに無い種類は、作る側のスクリプトの従来どおり（多くは、外形を囲む箱ひとつ。小物や、四角い物はそれで足りる）。
## 見た目と重ねた写真は tools/collider_shots.gd で撮れる。数値の確認は tests/collider_fit_test.gd。
##
## 形の書き方（座標は物の原点から、メートル。+Y が上、+Z が正面）：
##   ["box",  中心, 大きさ]            箱
##   ["cyl",  中心, 半径, 高さ]        円柱（軸は上下）
##   ["ball", 中心, 半径]              球
##   ["cap",  中心, 半径, 全体の高さ]  カプセル（軸は上下）
##   どの形も、後ろに回転（度。Vector3(x, y, z)）を足せる。円柱を横倒しにするなら Vector3(90, 0, 0) など
##   後ろに "thin" を足すと、人だけが当たる薄い物（手すり）。物は通り抜け、撮影の判定では透けて見える
##
## 物ごとの項目：
##   "shapes": 形の一覧（物ひとつにつき12個まで）
##   "size"  : 大きさを決めて取り込む物（廃材置き場の物・手持ち特撮の物）だけ。この表を書いたときの size。
##             あとで size を変えても、当たり判定は同じ比率で大きさが変わる（表は書き直さなくていい）
##   "com"   : 重心の位置（メートル）。背の高い物・後ろに支えのある板を倒れにくくする。省くと形から自動で決まる
##             （廃材置き場の物は、省くと production_scrap.gd の com＝高さに対する割合）
##
## 決めごと：
##   ・くぐれる所、脚と脚の間、細い柱は、見た目どおりに空ける
##   ・人が乗る面（足場・ふち）は、平らな箱で残す
##   ・細すぎる物は少し太らせる（照準を合わせやすく、物理が暴れにくい）。太さの目安は6cm以上
##   ・小さな飾り（ねじ・ひも・導火線・蛇口）には形を付けない
##   ・本体から細く張り出した物（怪獣の腕・モニターの取っ手・モップの柄・台車の押し手）にも付けない。
##     荷台に積むときの「かさ」は、当たり判定を全部囲む箱で決まる（main.gd の body_bounds）。
##     張り出しに形を付けると、積める数が減ったり、荷台の壁の上に渡して置かれたりする
const Prop := preload("res://scripts/prop.gd")

const TABLE := {
	# ==== 倉庫のセットと小道具（stage.gd の DEFS。寸法は拡大前で、DEFS の scale が掛かる） ====
	# バルコニー：床板、左右の脚、手すり（前と左右。人だけが当たる）
	"balcony": {"shapes": [
		["box", Vector3(0, 0.76, 0), Vector3(2.6, 0.18, 1.4)],
		["box", Vector3(-1.0, 0.34, 0), Vector3(0.15, 0.67, 1.3)],
		["box", Vector3(1.0, 0.34, 0), Vector3(0.15, 0.67, 1.3)],
		["box", Vector3(0, 1.38, 0.62), Vector3(2.6, 1.0, 0.08), "thin"],
		["box", Vector3(-1.22, 1.38, 0), Vector3(0.08, 1.0, 1.4), "thin"],
		["box", Vector3(1.22, 1.38, 0), Vector3(0.08, 1.0, 1.4), "thin"],
	]},
	# アーチ窓の壁：薄い壁の後ろを、足と筋交いが支える。壁の後ろの空間は空ける
	"window": {"com": Vector3(0, 0.9, -0.1), "shapes": [
		["box", Vector3(0, 1.35, 0.17), Vector3(2.2, 2.7, 0.18)],                                   # 壁（窓のガラスも固い）
		["box", Vector3(0, 1.55, 0.295), Vector3(1.54, 1.7, 0.14)],                                 # 窓枠
		["box", Vector3(0, 2.585, 0.295), Vector3(1.0, 0.37, 0.14)],                                # 窓枠のアーチの上
		["box", Vector3(0, 0.70, 0.35), Vector3(1.68, 0.13, 0.34)],                                 # 窓台
		["box", Vector3(-0.88, 0.055, -0.17), Vector3(0.12, 0.11, 0.70)],                           # 後ろの足
		["box", Vector3(0.88, 0.055, -0.17), Vector3(0.12, 0.11, 0.70)],
		["box", Vector3(-0.88, 0.685, -0.202), Vector3(0.075, 1.207, 0.075), Vector3(20.6, 0, 0)],  # 筋交い
		["box", Vector3(0.88, 0.685, -0.202), Vector3(0.075, 1.207, 0.075), Vector3(20.6, 0, 0)],
	]},
	# 遺跡の壁：石積みを段ごとにまとめる。上の欠けと背面の空間は塞がない（tests/ruin_collision_test.gd が確かめている）
	"ruin": {"shapes": [
		["box", Vector3(-0.0325, 0.22, 0.0829232), Vector3(2.68, 0.37, 0.55)],                      # 石積み（下から）
		["box", Vector3(0.0325, 0.62, 0.0829232), Vector3(2.68, 0.37, 0.55)],
		["box", Vector3(-0.4825, 1.02, 0.0829232), Vector3(1.78, 0.37, 0.55)],
		["box", Vector3(1.0925, 1.02, 0.0829232), Vector3(0.43, 0.37, 0.55)],
		["box", Vector3(-0.4175, 1.42, 0.0829232), Vector3(0.88, 0.37, 0.55)],
		["box", Vector3(0.4725, 0.18, 0.5929232), Vector3(0.4829895, 0.36, 0.4083072)],             # 前に落ちた石
		["box", Vector3(-0.8775, 0.075, -0.4070768), Vector3(0.12, 0.11, 0.78)],                    # 後ろの足
		["box", Vector3(0.8725, 0.075, -0.4070768), Vector3(0.12, 0.11, 0.78)],
		["box", Vector3(-0.8775, 0.575, -0.4770768), Vector3(0.08, 1.1027693, 0.08), Vector3(30.518213, 0, 0)],   # 筋交い
		["box", Vector3(0.8725, 0.575, -0.4770768), Vector3(0.08, 1.1027693, 0.08), Vector3(30.518213, 0, 0)],
	]},
	# 書割（城の胸壁）：2枚つなぎの板と、後ろの足・筋交い
	"flat": {"com": Vector3(0, 0.38, -0.16), "shapes": [
		["box", Vector3(0, 0.5435, -0.004), Vector3(1.83, 1.087, 0.17)],                            # 板と桟
		["box", Vector3(-0.45, 0.0225, -0.33), Vector3(0.12, 0.045, 0.49)],                         # 後ろの足
		["box", Vector3(0.45, 0.0225, -0.33), Vector3(0.12, 0.045, 0.49)],
		["box", Vector3(-0.45, 0.391, -0.284), Vector3(0.075, 0.821, 0.052), Vector3(30.1, 0, 0)],  # 筋交い
		["box", Vector3(0.45, 0.391, -0.284), Vector3(0.075, 0.821, 0.052), Vector3(30.1, 0, 0)],
	]},
	# 発泡スチロールの岩：3段。いちばん上は平らにして、乗れる
	"rock": {"shapes": [
		["box", Vector3(-0.046, 0.17, 0.05), Vector3(1.08, 0.34, 0.58)],
		["box", Vector3(-0.04, 0.44, 0.045), Vector3(0.88, 0.20, 0.48)],
		["box", Vector3(-0.03, 0.61, 0.04), Vector3(0.52, 0.14, 0.34)],
	]},
	# 小道具かご：かごと、上の取っ手
	"basket": {"shapes": [
		["box", Vector3(0, 0.11, 0), Vector3(0.372, 0.22, 0.262)],
		["box", Vector3(0, 0.275, 0), Vector3(0.30, 0.115, 0.03)],
	]},
	# 折りたたみパーテーション：ジグザグに立つ3枚（物の原点は左端にある）
	"partition": {"shapes": [
		["box", Vector3(0.3445, 0.906, -0.105), Vector3(0.72, 1.81, 0.06), Vector3(0, 17, 0)],
		["box", Vector3(1.089, 0.906, -0.105), Vector3(0.72, 1.81, 0.06), Vector3(0, -17, 0)],
		["box", Vector3(1.8325, 0.906, -0.105), Vector3(0.72, 1.81, 0.06), Vector3(0, 17, 0)],
	]},
	# グリーンバック：布と、左右のスタンドの足元
	"greenscreen": {"shapes": [
		["box", Vector3(0, 1.05, 0), Vector3(2.8, 2.0, 0.06)],
		["box", Vector3(-1.32, 0.05, 0.12), Vector3(0.9, 0.1, 0.78)],
		["box", Vector3(1.32, 0.05, 0.12), Vector3(0.9, 0.1, 0.78)],
	]},
	# 台車：台だけ（車輪の間も埋めて、床を滑らせる）。後ろへ張り出す押し手には付けない
	"dolly": {"shapes": [
		["box", Vector3(0, 0.16, 0), Vector3(0.92, 0.32, 1.2)],
	]},
	# ガンマイク：竿と、先のマイク。立てて置けるように、足元に小さな石突きを付けて重心を下げてある
	"boom": {"com": Vector3(0, 0.3, 0), "shapes": [
		["box", Vector3(0, 0.015, 0), Vector3(0.16, 0.03, 0.16)],                 # 石突き（見た目より少し広い）
		["box", Vector3(0, 1.04, 0), Vector3(0.10, 2.0, 0.10)],                   # 竿（太らせてある）
		["cap", Vector3(0, 2.121, -0.04), 0.07, 0.49, Vector3(90, 0, 0)],         # マイクと風よけ
	]},

	# ==== 機材と、スクリプトで組み立てる物 ====
	# がらくたの月（stage.gd）：土台・柱・丸い板
	"moon": {"com": Vector3(0, 0.4, 0), "shapes": [
		["cyl", Vector3(0, 0.05, 0), 0.45, 0.10],
		["box", Vector3(0, 1.3, 0), Vector3(0.10, 2.4, 0.10)],
		["cyl", Vector3(0, 3.0, 0), 0.53, 0.22, Vector3(90, 0, 0)],
	]},
	# 撮影カメラ（film_camera.gd）：三脚は、脚の広がりに合わせた4段の円柱（脚の間は埋めて、照準を合わせやすく・置きやすくする）。
	# 足元の幅は前の箱と同じ 0.8m（足先のゴムは少しはみ出す）
	"camera": {"com": Vector3(0, 0.55, 0), "shapes": [
		["cyl", Vector3(0, 0.14, 0), 0.40, 0.28],                  # 足元
		["cyl", Vector3(0, 0.42, 0), 0.31, 0.28],
		["cyl", Vector3(0, 0.70, 0), 0.21, 0.28],
		["cyl", Vector3(0, 1.00, 0), 0.12, 0.32],                  # 脚の付け根
		["box", Vector3(0, 1.33, 0), Vector3(0.22, 0.34, 0.36)],   # 雲台とカメラ
	]},
	# スポットライト（spot_rig.gd）：脚と重りの袋、柱、灯体（向きを変えても同じ形になるよう球）。
	# 脚は +X へ長いが、どちら向きに置いても同じ幅になるよう、柱を中心にした円で囲む
	"spot": {"com": Vector3(0, 0.35, 0), "shapes": [
		["cyl", Vector3(0, 0.16, 0), 0.45, 0.32],
		["box", Vector3(0, 1.07, 0), Vector3(0.10, 1.52, 0.10)],
		["ball", Vector3(0, 2.0, 0), 0.19],
	]},
	# 爆弾（fx_box.gd）：木の台・鉄の玉・口金。つないだロープ（fuse_cord.gd）には付けない
	"fx": {"shapes": [
		["box", Vector3(0, 0.065, 0), Vector3(0.54, 0.13, 0.4)],
		["ball", Vector3(0, 0.37, 0), 0.25],
		["cyl", Vector3(0, 0.63, 0), 0.075, 0.11],
	]},
	# 爆弾の道具（bomb_kit.gd）。火薬の袋（powder_sack.gd）：転がらないよう、箱で囲む（しぼんでも形は変えない）
	"powdersack": {"shapes": [
		["box", Vector3(0, 0.23, 0), Vector3(0.3, 0.46, 0.28)],
	]},
	# はさみ：刃と持ち手をまとめて、薄い箱ひとつ（厚みは少し太らせる）。寸法は拡大前
	"scissors": {"shapes": [
		["box", Vector3(0, 0.124, 0.007), Vector3(0.13, 0.248, 0.06)],
	]},
	# 爆炎の書割（boom_flat.gd）：土台だけ。寝ている板（2.2m四方）には付けない
	# （付けると、荷台に積めなくなり、廃材置き場でも隣の物と重なる。板は合図で跳ね上がる飾り）
	"boomflat": {"shapes": [
		["box", Vector3(0, 0.05, 0), Vector3(1.8, 0.10, 0.5)],
	]},
	# 等身大パネル（standin_panel.gd）：立っている板、床の足、後ろの横木、斜めの支え
	"standin": {"com": Vector3(0, 0.32, -0.3), "shapes": [
		["box", Vector3(0, 0.97, -0.025), Vector3(0.82, 1.88, 0.07)],
		["box", Vector3(-0.255, 0.028, -0.356), Vector3(0.073, 0.056, 0.82)],
		["box", Vector3(0.255, 0.028, -0.356), Vector3(0.073, 0.056, 0.82)],
		["box", Vector3(0, 0.083, -0.69), Vector3(0.62, 0.054, 0.072)],
		["box", Vector3(-0.255, 0.65, -0.388), Vector3(0.062, 1.275, 0.045), Vector3(28.6, 0, 0)],
		["box", Vector3(0.255, 0.65, -0.388), Vector3(0.062, 1.275, 0.045), Vector3(28.6, 0, 0)],
	]},
	# 大型確認モニター（production_monitor_prop.gd）：画面、背面の箱、ひさし、2本の支柱、梁、キャスター付きの脚
	# （支柱の間・脚の間は空ける。横の取っ手には付けない。重心は、前の大ざっぱな箱のときと同じ高さにしてある）
	"monitor": {"com": Vector3(0, 1.15, -0.05), "shapes": [
		["box", Vector3(0, 1.84, 0), Vector3(2.66, 1.60, 0.26)],
		["box", Vector3(0, 1.84, -0.24), Vector3(2.30, 1.24, 0.22)],
		["box", Vector3(0, 2.645, 0.12), Vector3(2.68, 0.05, 0.34)],
		["box", Vector3(-0.58, 0.63, -0.19), Vector3(0.08, 0.87, 0.08)],
		["box", Vector3(0.58, 0.63, -0.19), Vector3(0.08, 0.87, 0.08)],
		["box", Vector3(0, 0.21, -0.10), Vector3(1.74, 0.08, 0.08)],
		["box", Vector3(-0.80, 0.125, -0.10), Vector3(0.14, 0.25, 1.04)],
		["box", Vector3(0.80, 0.125, -0.10), Vector3(0.14, 0.25, 1.04)],
	]},
	# 昇降カメラ台（production_prop.gd）：台車の本体と、押し手の枠。上下する荷台の板は production_prop.gd が別に作る
	"lift_cart": {"shapes": [
		["box", Vector3(-0.065, 0.145, 0), Vector3(1.12, 0.29, 0.52)],
		["box", Vector3(-0.59, 0.62, 0), Vector3(0.08, 0.66, 0.49)],
	]},
	# 清掃カート（production_prop.gd）：台、ごみ袋、2段の棚、バケツと絞り機、押し手。横に立てかけたモップの柄には付けない
	"cleaning_cart": {"shapes": [
		["box", Vector3(0, 0.135, 0), Vector3(1.16, 0.27, 0.52)],
		["box", Vector3(-0.455, 0.58, 0), Vector3(0.31, 0.62, 0.43)],
		["box", Vector3(-0.06, 0.60, 0), Vector3(0.43, 0.67, 0.45)],
		["box", Vector3(0.365, 0.49, 0), Vector3(0.38, 0.46, 0.39)],
		["box", Vector3(-0.39, 0.95, 0), Vector3(0.06, 0.12, 0.44)],
	]},

	# ==== 手持ち特撮の物（production_movie_prop.gd） ====
	# 魔女の鍋：胴の上（口まで）と、すぼまった底。3本の脚は足先の位置に立てた円柱で（脚の間は空く）
	"witch_cauldron": {"size": 1.0, "com": Vector3(0, 0.35, 0), "shapes": [
		["cyl", Vector3(0, 0.60, 0), 0.45, 0.36],
		["cyl", Vector3(0, 0.30, 0), 0.36, 0.26],
		["cyl", Vector3(0.366, 0.10, -0.148), 0.07, 0.20],
		["cyl", Vector3(-0.31, 0.10, -0.243), 0.07, 0.20],
		["cyl", Vector3(-0.055, 0.10, 0.39), 0.07, 0.20],
	]},
	# トマト怪獣：丸い体、両足（まとめて1本。立てて置けるように）、へた。左右に張り出した細い腕には付けない
	"tomato_monster": {"size": 1.4, "com": Vector3(0, 0.5, 0), "shapes": [
		["ball", Vector3(0, 0.74, 0.03), 0.48],
		["cyl", Vector3(0, 0.14, -0.03), 0.24, 0.28],
		["cyl", Vector3(0, 1.24, 0.04), 0.10, 0.16],
	]},

	# ==== 廃材置き場（production_scrap.gd）。寸法は "size" のときのもの ====
	# ミニ撮影クレーン塔：土台、格子の塔、運転室、上の腕（腕の下は空ける。つり下げた輪には付けない）
	"scrap_crane": {"size": 1.5, "com": Vector3(-0.2, 0.4, 0), "shapes": [
		["box", Vector3(-0.2565, 0.047, 0), Vector3(0.695, 0.094, 0.68)],
		["box", Vector3(-0.256, 0.64, 0), Vector3(0.45, 1.19, 0.45)],
		["box", Vector3(-0.256, 1.20, -0.047), Vector3(0.53, 0.27, 0.45)],
		["box", Vector3(0, 1.42, -0.03), Vector3(1.13, 0.16, 0.07)],
	]},
	# 新聞の売店：本体（窓口の中も埋める）と、張り出した屋根
	"scrap_kiosk": {"size": 1.0, "shapes": [
		["box", Vector3(0, 0.462, 0.02), Vector3(0.90, 0.924, 0.64)],
		["box", Vector3(0, 0.959, -0.0175), Vector3(1.0, 0.07, 0.68)],
	]},
	# 曲がった煙突：土台、れんがの筒、曲がった先、笠
	"scrap_chimney": {"size": 1.1, "shapes": [
		["box", Vector3(-0.027, 0.07, 0), Vector3(0.447, 0.14, 0.42)],
		["box", Vector3(-0.027, 0.47, 0), Vector3(0.31, 0.70, 0.31)],
		["box", Vector3(0.035, 0.86, 0), Vector3(0.36, 0.32, 0.30)],
		["box", Vector3(0.01, 1.058, 0), Vector3(0.48, 0.085, 0.45)],
	]},
	# 街灯：土台、柱（太らせてある）、灯り
	"scrap_lamp": {"size": 1.3, "shapes": [
		["box", Vector3(0, 0.04, 0), Vector3(0.25, 0.08, 0.25)],
		["box", Vector3(0, 0.54, 0), Vector3(0.09, 0.92, 0.09)],
		["box", Vector3(0, 1.125, 0), Vector3(0.21, 0.28, 0.21)],
	]},
	# 太鼓橋：まん中の平らな板と、両側の下りの板（橋の下は空く。上を歩いて渡れる）。
	# 欄干には付けない（欄干の間は人の幅より狭く、付けると橋に乗れなくなる）
	"scrap_bridge": {"size": 1.2, "shapes": [
		["box", Vector3(0, 0.181, 0), Vector3(0.61, 0.065, 0.47)],
		["box", Vector3(0, 0.105, 0.404), Vector3(0.61, 0.065, 0.40), Vector3(20.2, 0, 0)],
		["box", Vector3(0, 0.105, -0.404), Vector3(0.61, 0.065, 0.40), Vector3(-20.2, 0, 0)],
	]},
	# バスの正面（書割）：正面の板と、後ろの足・筋交い
	"scrap_bus": {"size": 1.1, "shapes": [
		["box", Vector3(0, 0.28, 0.178), Vector3(1.04, 0.56, 0.205)],                               # 車体の下半分とバンパー
		["box", Vector3(0, 0.77, 0.148), Vector3(0.99, 0.43, 0.10)],                                # 窓と柱
		["box", Vector3(0, 1.0425, 0.112), Vector3(0.99, 0.115, 0.22)],                             # 屋根の帯
		["box", Vector3(-0.317, 0.026, -0.002), Vector3(0.064, 0.052, 0.555)],                      # 後ろの足
		["box", Vector3(0.317, 0.026, -0.002), Vector3(0.064, 0.052, 0.555)],
		["box", Vector3(-0.317, 0.428, -0.102), Vector3(0.05, 0.839, 0.05), Vector3(22.2, 0, 0)],   # 筋交い
		["box", Vector3(0.317, 0.428, -0.102), Vector3(0.05, 0.839, 0.05), Vector3(22.2, 0, 0)],
	]},
	# 巨大キノコ：足、柄、傘（ふちと、てっぺん）。傘の下は空く
	"scrap_mushroom": {"size": 1.0, "shapes": [
		["cyl", Vector3(0, 0.025, 0), 0.215, 0.05],
		["cyl", Vector3(0, 0.365, 0), 0.13, 0.67],
		["cyl", Vector3(0, 0.77, 0), 0.42, 0.16],
		["cyl", Vector3(0, 0.905, 0), 0.32, 0.11],
	]},
	# ゴムアヒル：体（底は平ら）、尾、頭、くちばし
	"scrap_duck": {"size": 0.8, "shapes": [
		["box", Vector3(0, 0.17, -0.05), Vector3(0.44, 0.34, 0.50)],
		["box", Vector3(0, 0.235, -0.33), Vector3(0.14, 0.20, 0.14)],
		["ball", Vector3(0, 0.345, 0.15), 0.155],
		["box", Vector3(0, 0.33, 0.33), Vector3(0.24, 0.085, 0.15)],
	]},
	# 宇宙カプセル：台、胴、肩、先、扉
	"scrap_capsule": {"size": 1.3, "shapes": [
		["cyl", Vector3(0, 0.08, -0.022), 0.47, 0.16],
		["cyl", Vector3(0, 0.50, -0.022), 0.44, 0.70],
		["cyl", Vector3(0, 1.00, -0.022), 0.36, 0.32],
		["cyl", Vector3(0, 1.22, -0.022), 0.26, 0.16],
		["box", Vector3(0, 0.56, 0.43), Vector3(0.46, 0.76, 0.10)],
	]},
	# 撮影用トイレ：台座、便器とふた（上は平ら。座れる）、タンク
	"scrap_toilet": {"size": 0.9, "shapes": [
		["box", Vector3(-0.008, 0.16, 0), Vector3(0.44, 0.32, 0.44)],
		["box", Vector3(-0.008, 0.44, 0.065), Vector3(0.60, 0.28, 0.70)],
		["box", Vector3(-0.008, 0.66, -0.28), Vector3(0.60, 0.49, 0.27)],
	]},
	# 大型送風機：台、羽根のかご（横倒しの円柱）、かごを支える柱
	"scrap_fan": {"size": 1.2, "shapes": [
		["box", Vector3(0, 0.08, 0), Vector3(0.69, 0.16, 0.56)],
		["cyl", Vector3(0, 0.751, 0.026), 0.45, 0.27, Vector3(90, 0, 0)],
		["box", Vector3(-0.313, 0.24, 0.026), Vector3(0.06, 0.20, 0.08)],
		["box", Vector3(0.313, 0.24, 0.026), Vector3(0.06, 0.20, 0.08)],
	]},
	# 神殿柱：台座、丸い柱、柱頭
	"scrap_column": {"size": 1.8, "shapes": [
		["box", Vector3(0, 0.13, 0), Vector3(0.564, 0.26, 0.564)],
		["cyl", Vector3(0, 0.95, 0), 0.19, 1.40],
		["box", Vector3(0, 1.72, 0), Vector3(0.54, 0.16, 0.54)],
	]},
	# アーチ：両側の柱（土台・柱頭ごと）と、5つの石で丸く組んだアーチ。くぐれる（まん中の高さ 1.97m）
	"scrap_arch": {"size": 2.2, "shapes": [
		["box", Vector3(-0.734, 0.71, 0), Vector3(0.34, 1.42, 0.40)],
		["box", Vector3(0.734, 0.71, 0), Vector3(0.34, 1.42, 0.40)],
		["box", Vector3(-0.694, 1.586, 0), Vector3(0.53, 0.23, 0.30), Vector3(0, 0, 72)],
		["box", Vector3(-0.429, 1.951, 0), Vector3(0.53, 0.23, 0.30), Vector3(0, 0, 36)],
		["box", Vector3(0, 2.09, 0), Vector3(0.53, 0.23, 0.30)],
		["box", Vector3(0.429, 1.951, 0), Vector3(0.53, 0.23, 0.30), Vector3(0, 0, -36)],
		["box", Vector3(0.694, 1.586, 0), Vector3(0.53, 0.23, 0.30), Vector3(0, 0, -72)],
	]},
	# 張りぼての木：土台、幹、葉のかたまり3つ（葉の下は空く）
	"scrap_tree": {"size": 1.8, "com": Vector3(0, 0.45, -0.04), "shapes": [
		["cyl", Vector3(0.003, 0.036, -0.039), 0.265, 0.072],
		["cyl", Vector3(0.003, 0.60, -0.039), 0.085, 1.06],
		["ball", Vector3(-0.306, 1.204, -0.039), 0.35],
		["ball", Vector3(0.306, 1.242, -0.122), 0.35],
		["ball", Vector3(0.025, 1.419, 0.122), 0.35],
	]},
	# スッポン：ゴムのカップと、柄（太らせてある）
	"scrap_plunger": {"size": 0.7, "shapes": [
		["cyl", Vector3(0, 0.05, 0), 0.091, 0.10],
		["box", Vector3(0, 0.40, 0), Vector3(0.07, 0.60, 0.07)],
	]},
	# ゴムのうんこ：3段の円柱
	"scrap_poop": {"size": 0.5, "shapes": [
		["cyl", Vector3(0, 0.095, 0), 0.24, 0.19],
		["cyl", Vector3(0, 0.235, 0), 0.16, 0.09],
		["cyl", Vector3(0, 0.32, 0), 0.08, 0.08],
	]},
	# クリームパイ：皿と、クリーム
	"scrap_pie": {"size": 0.45, "shapes": [
		["cyl", Vector3(0, 0.045, 0), 0.225, 0.09],
		["cyl", Vector3(0, 0.14, 0), 0.18, 0.11],
	]},
	# 猫足のバスタブ：ふち（上は平ら。乗れる）、湯船の中ほど、湯船の底、猫足4本（足の間は空く）。蛇口には付けない
	"scrap_tub": {"size": 1.3, "shapes": [
		["box", Vector3(0, 0.4925, 0), Vector3(1.30, 0.105, 0.65)],
		["box", Vector3(0, 0.37, 0), Vector3(1.02, 0.14, 0.50)],
		["box", Vector3(0, 0.225, 0), Vector3(0.70, 0.15, 0.34)],
		["box", Vector3(-0.45, 0.08, 0.19), Vector3(0.17, 0.16, 0.13)],
		["box", Vector3(-0.45, 0.08, -0.19), Vector3(0.17, 0.16, 0.13)],
		["box", Vector3(0.45, 0.08, 0.19), Vector3(0.17, 0.16, 0.13)],
		["box", Vector3(0.45, 0.08, -0.19), Vector3(0.17, 0.16, 0.13)],
	]},
	# サボテン：土台、幹、左右の腕（横へ出て、上へ曲がる）
	"scrap_cactus": {"size": 1.5, "shapes": [
		["cyl", Vector3(0, 0.04, 0), 0.24, 0.08],
		["cap", Vector3(0, 0.78, 0), 0.115, 1.44],
		["box", Vector3(-0.24, 0.474, 0), Vector3(0.26, 0.132, 0.132)],
		["cap", Vector3(-0.342, 0.71, 0), 0.066, 0.45],
		["box", Vector3(0.24, 0.756, 0), Vector3(0.26, 0.132, 0.132)],
		["cap", Vector3(0.342, 0.99, 0), 0.066, 0.45],
	]},
	# たき火：石の輪とまき（低い円柱）、まん中の炎
	"scrap_campfire": {"size": 1.0, "shapes": [
		["cyl", Vector3(0, 0.075, 0), 0.49, 0.15],
		["cyl", Vector3(0, 0.30, 0.02), 0.16, 0.31],
	]},
	# 機関車の正面：台枠と車輪、ボイラー（横倒しの円柱）、前の排障器、煙突
	"scrap_train": {"size": 1.4, "shapes": [
		["box", Vector3(0, 0.19, -0.11), Vector3(1.13, 0.38, 0.92)],
		["cyl", Vector3(0, 0.654, -0.06), 0.38, 0.93, Vector3(90, 0, 0)],
		["box", Vector3(0, 0.165, 0.46), Vector3(1.16, 0.27, 0.22)],
		["cyl", Vector3(0, 1.20, 0.02), 0.15, 0.40],
	]},
	# 風車小屋：塔（下・上）、三角屋根（2段）、後ろの足と筋交い、羽根4枚
	"scrap_windmill": {"size": 1.8, "shapes": [
		["box", Vector3(0, 0.32, 0.086), Vector3(0.76, 0.64, 0.39)],
		["box", Vector3(0, 0.95, 0.086), Vector3(0.56, 0.63, 0.39)],
		["box", Vector3(0, 1.335, 0.086), Vector3(0.60, 0.16, 0.50)],
		["box", Vector3(0, 1.50, 0.086), Vector3(0.28, 0.17, 0.50)],
		["box", Vector3(-0.308, 0.031, -0.17), Vector3(0.067, 0.062, 0.672)],
		["box", Vector3(0.308, 0.031, -0.17), Vector3(0.067, 0.062, 0.672)],
		["box", Vector3(-0.308, 0.509, -0.292), Vector3(0.05, 1.012, 0.05), Vector3(21.7, 0, 0)],
		["box", Vector3(0.308, 0.509, -0.292), Vector3(0.05, 1.012, 0.05), Vector3(21.7, 0, 0)],
		["box", Vector3(0.363, 1.228, 0.488), Vector3(0.75, 0.20, 0.05), Vector3(0, 0, 14.3)],
		["box", Vector3(-0.175, 1.416, 0.488), Vector3(0.20, 0.75, 0.05), Vector3(0, 0, 14.3)],
		["box", Vector3(-0.363, 0.877, 0.488), Vector3(0.75, 0.20, 0.05), Vector3(0, 0, 14.3)],
		["box", Vector3(0.175, 0.69, 0.488), Vector3(0.20, 0.75, 0.05), Vector3(0, 0, 14.3)],
	]},
	# 噴水：土台、下の皿（すぼまった所と、ふち）、柱、上の皿、噴き出し口
	"scrap_fountain": {"size": 1.2, "shapes": [
		["cyl", Vector3(0, 0.042, 0), 0.60, 0.084],
		["cyl", Vector3(0, 0.14, 0), 0.38, 0.12],
		["cyl", Vector3(0, 0.245, 0), 0.56, 0.10],
		["cyl", Vector3(0, 0.45, 0), 0.085, 0.31],
		["cyl", Vector3(0, 0.675, 0), 0.29, 0.13],
		["cyl", Vector3(0, 0.86, 0), 0.045, 0.25],
	]},
	# ---- ゴミ袋・包みから出てくる物（production_scrap.gd の "bag"）。ほとんどは外形の箱で足りる。人が上る物だけ、面を書く ----
	# まっすぐな階段：手前（+Z）が低く、奥が高い。段の上をなでる斜めの板（歩いて上れる）、奥の踊り場、手前の足。手すりには付けない
	"scrap_straight_stair": {"size": 1.6, "com": Vector3(0.025, 0.4, -0.25), "shapes": [
		["box", Vector3(0.025, 0.511, 0.107), Vector3(0.85, 0.06, 1.442), Vector3(37.1, 0, 0)],
		["box", Vector3(0.025, 0.5, -0.595), Vector3(0.85, 1.0, 0.29)],
		["box", Vector3(0.025, 0.04, 0.68), Vector3(0.85, 0.08, 0.12)],
	]},
	# 踊り場つきの階段：左の段（手前から奥へ上る）→ 奥の踊り場 → 右の段（奥から手前へ上る）→ 右手前の上の踊り場
	"scrap_turning_stair": {"size": 1.75, "shapes": [
		["box", Vector3(-0.40, 0.325, 0.174), Vector3(0.76, 0.06, 0.927), Vector3(32.7, 0, 0)],
		["box", Vector3(-0.40, 0.04, 0.55), Vector3(0.76, 0.08, 0.12)],
		["box", Vector3(0, 0.31, -0.39), Vector3(1.6, 0.62, 0.38)],
		["box", Vector3(0.415, 0.878, 0.095), Vector3(0.73, 0.06, 0.743), Vector3(-42.3, 0, 0)],
		["box", Vector3(0.415, 0.6, 0.49), Vector3(0.73, 1.2, 0.28)],
	]},
	# 手すりつきのスロープ：手前（+Z）が低い斜めの板、奥の支え、手前の足。手すりには付けない
	"scrap_access_ramp": {"size": 2.0, "com": Vector3(-0.045, 0.25, -0.3), "shapes": [
		["box", Vector3(-0.045, 0.321, -0.008), Vector3(0.99, 0.06, 1.965), Vector3(14.7, 0, 0)],
		["box", Vector3(-0.045, 0.29, -0.925), Vector3(0.99, 0.58, 0.15)],
		["box", Vector3(-0.045, 0.035, 0.93), Vector3(0.99, 0.07, 0.12)],
	]},
	# 張りぼての山：4段の円柱（1段 30cm ほど。跳べば上れる。雇った役者も段に跳び乗る）。てっぺんは人が立てる平ら
	"scrap_paper_mountain": {"size": 2.0, "shapes": [
		["cyl", Vector3(0, 0.15, 0), 0.88, 0.3],
		["cyl", Vector3(0, 0.45, 0), 0.68, 0.3],
		["cyl", Vector3(0, 0.775, 0), 0.5, 0.35],
		["cyl", Vector3(0, 1.13, 0), 0.3, 0.36],
	]},
	# 部屋の角：前と右の2枚の壁（L字の内側は空ける）
	"scrap_folding_room_corner": {"size": 1.6, "shapes": [
		["box", Vector3(0, 0.79, 0.75), Vector3(1.6, 1.57, 0.1)],
		["box", Vector3(0.70, 0.79, 0), Vector3(0.2, 1.57, 1.6)],
	]},
}


static func has(kind: String) -> bool:
	return TABLE.has(kind)


# 表を書いたときの大きさ（size）。書いていなければ 0
static func base_size(kind: String) -> float:
	if not TABLE.has(kind):
		return 0.0
	return float((TABLE[kind] as Dictionary).get("size", 0.0))


# 表に重心が書いてあるか
static func has_com(kind: String) -> bool:
	return TABLE.has(kind) and (TABLE[kind] as Dictionary).has("com")


# 表の形を body に付ける。scale＝表の寸法に掛ける倍率。付けた形を、表の順番で返す（表に無ければ空）
static func build(body: RigidBody3D, kind: String, scale: float = 1.0) -> Array[CollisionShape3D]:
	var made: Array[CollisionShape3D] = []
	if not TABLE.has(kind):
		return made
	var entry: Dictionary = TABLE[kind]
	for row: Array in entry["shapes"]:
		var collider := add(body, row, scale)
		if collider != null:
			made.append(collider)
	if entry.has("com"):
		body.center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
		body.center_of_mass = (entry["com"] as Vector3) * scale
	return made


# 大きさを決めて取り込む物（廃材置き場の物・手持ち特撮の物）用。size＝いまの大きさ。
# 表の寸法は表の "size" のときのものなので、その比で拡大・縮小して付ける
static func build_sized(body: RigidBody3D, kind: String, size: float) -> Array[CollisionShape3D]:
	var base := base_size(kind)
	return build(body, kind, size / base if base > 0.0 else 1.0)


# 形をひとつ付ける。row は上の「形の書き方」の1行
static func add(body: Node3D, row: Array, scale: float = 1.0) -> CollisionShape3D:
	var shape: Shape3D
	var next := 3
	match String(row[0]):
		"box":
			var box := BoxShape3D.new()
			box.size = (row[2] as Vector3) * scale
			shape = box
		"cyl":
			var cyl := CylinderShape3D.new()
			cyl.radius = float(row[2]) * scale
			cyl.height = float(row[3]) * scale
			shape = cyl
			next = 4
		"ball":
			var ball := SphereShape3D.new()
			ball.radius = float(row[2]) * scale
			shape = ball
		"cap":
			var cap := CapsuleShape3D.new()
			cap.radius = float(row[2]) * scale
			cap.height = maxf(float(row[3]), float(row[2]) * 2.0) * scale
			shape = cap
			next = 4
		_:
			push_error("prop_shapes: 知らない形 %s" % String(row[0]))
			return null
	var turn := Vector3.ZERO
	var thin := false
	for i in range(next, row.size()):
		if row[i] is Vector3:
			turn = row[i]
		elif row[i] is String and String(row[i]) == "thin":
			thin = true
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = (row[1] as Vector3) * scale
	collider.rotation_degrees = turn
	if thin:
		# 手すり：体は通さないが、物は通り、カメラや光は遮らない
		var rail := StaticBody3D.new()
		rail.collision_layer = Prop.L_THIN
		rail.collision_mask = 0
		rail.add_child(collider)
		body.add_child(rail)
	else:
		body.add_child(collider)
	return collider
