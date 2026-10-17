extends RefCounted
## 台本の中身。production_flow.gd の JOBS と同じ並び（依頼ごとに1冊）。
## 台本は現場に1冊しかない。持っている人だけが読めるので、その人が監督になって
## せりふを読み上げ、合図を出す。役者は口を動かさないので、せりふは参加者が声を当てる。
##
## scenes : 場面（ふつうは3つ）。dir＝ト書き / lines＝[[誰, せりふ], ...] / memo＝撮り方
## beats  : 場面の列（あれば）。この列を持つ台本は、合図 1・2・3 ではなく、監督がページをめくって進める（production_beats.gd）。
##          場面ごとに、役者が印から印へ動く。scenes と同じ数だけ並べる
##   rule＝採点の見方（stroll 街を歩く / appear 怪獣あらわる / attack 怪獣の技 / topple 怪獣が倒れる / cheer 勝利）
##   from・to＝その場面の最初と最後の印（0＝① 1＝② 2＝③）。「もう一度」では from まで戻ってから演じ直す
##   gait＝印までの動き（walk / run）/ pose＝着いてからの姿（idle / freeze 見上げて固まる / cheer 万歳）
##   look＝着いてから見る先（monster / camera / partner）/ face＝[動いている間の顔, 着いてからの顔]
##   meet＝二人が、印のあいだへ寄って向かい合う / music＝その場面で流す曲（""＝止める）/ roar＝怪獣の声が鳴る
##   boom＝この場面に入ると、爆発役の物（爆炎の書割・見立てた物）に合図が出る。爆弾は合図では鳴らない
## せりふの {城} {怪獣} {街} {技} は、その役に見立てた物の名前に置き換わる（決まるまでは WORDS の言葉）
const WORDS := {"城": ["castle", "ベニヤ板"], "怪獣": ["monster", "ただの置物"], "街": ["city", "段ボール"], "技": ["boom", "何か"], "月": ["moon", "丸い何か"],
	# 名場面のパロディの役（production_cast.gd の SCRIPT_ROLES）
	"大岩": ["bigrock", "丸い何か"], "秘宝": ["relic", "何か光る物"], "玄関": ["door", "ベニヤ板"], "ツリー": ["xmas", "何か"],
	"自転車": ["bike", "何か"], "船": ["ship", "木箱"], "屋上": ["roof", "倉庫"], "階段": ["steps", "箱"], "頂上": ["summit", "箱の上"],
	"カップ麺": ["noodle", "丸い何か"], "車": ["car", "何か"]}
const SCRIPTS := [
	# 0 月下の城と大爆発（結婚式の再現ビデオ）
	{"scenes": [
		{"dir": "月夜の城。Aは高い所に立ち、Bは下から見上げる。",
			"lines": [["B", "あなたに、伝えたいことがあります"], ["A", "……あれ、{城}じゃない？"], ["B", "今日だけは城です"]],
			"memo": "二人に高低差をつけ、城役の物と一緒に明るく映す"},
		{"dir": "見つめ合う二人。その背後で、なぜか大爆発。",
			"lines": [["B", "結婚してください！"], ["（爆発）", ""], ["A", "えっ、なんて！？"]],
			"memo": "爆発が二人の背後に映るように。合図2で爆発"},
		{"dir": "煙の中から、二人が歩み寄る。",
			"lines": [["A", "聞こえなかったけど、はい"], ["B", "聞こえてなかったのに！？"]],
			"memo": "爆発のあと、近づいた二人を映す"}]},
	# 1 スタジオで月下の城（城主の末裔）
	{"scenes": [
		{"dir": "どう見ても城ではない場所。だが、城である。Aは高い所からあたりを見下ろす。",
			"lines": [["A", "ここが、わが城……{城}に見えるのは気のせいか"], ["B", "気のせいです、殿"], ["A", "広く撮れ"]],
			"memo": "二人に高低差をつけ、城役の物と一緒に明るく映す"},
		{"dir": "Bが何かに気づく。Aは気づかない。背後で大爆発。",
			"lines": [["B", "殿、後ろ！"], ["A", "余は振り向かぬ。それが王だ"], ["（爆発）", ""]],
			"memo": "爆発が二人の背後に映るように。スタッフは画面の外へ"},
		{"dir": "静かになった城。二人が歩み寄る。",
			"lines": [["A", "……いまのは、税務署か？"], ["B", "たぶん花火です"]],
			"memo": "爆発のあと、近づいた二人を映す"}]},
	# 2 青空の下でも夜の城（天文同好会）
	{"scenes": [
		{"dir": "どこで撮ろうと、夜の城である。空には月。",
			"lines": [["A", "今夜は月がきれいですね"], ["B", "昼ですけどね"], ["A", "心の目で見て"]],
			"memo": "二人に高低差をつけ、城役と月役の物を一緒に映す。月は合わせて2秒"},
		{"dir": "空を見上げる二人。背後で大爆発。",
			"lines": [["B", "あ、流れ星！"], ["（爆発）", ""], ["A", "近い近い近い！"]],
			"memo": "爆発が二人の背後に映るように。月も画面に残す"},
		{"dir": "煙が晴れる。二人が歩み寄り、空を確かめる。",
			"lines": [["A", "月は無事？"], ["B", "月だけは無事です"]],
			"memo": "爆発のあと、近づいた二人を映す"}]},
	# 3 怪獣、段ボールの街に現る（防災の啓発ビデオ）
	{"scenes": [
		{"dir": "街の向こうに、巨大な怪獣。二人は気づいて固まる。",
			"lines": [["A", "あれ、{怪獣}じゃない？"], ["B", "怪獣です。市民は落ち着いて"], ["（怪獣の声）", "ガオー"]],
			"memo": "怪獣役の物をカメラの手前に置き、街役の物より大きく映す"},
		{"dir": "逃げる二人。その背後で大爆発。",
			"lines": [["B", "押さない、駆けない、しゃべらない！"], ["A", "全部やってる！ {技}が飛んできた！"], ["（爆発）", ""]],
			"memo": "爆発（怪獣の技）が二人の背後に映るように。スタッフは画面の外へ"},
		{"dir": "誰かがこっそり怪獣を倒す。二人が戻ってくる。",
			"lines": [["B", "怪獣は、段差につまずきました"], ["A", "勝ったの？"], ["二人", "ばんざーい！"]],
			"memo": "F で怪獣を倒し、その前で喜ぶ二人を映す"}]},
	# 4 倉庫の大怪獣（怪獣映画マニアのお嬢様）
	{"scenes": [
		{"dir": "段ボールの街に、巨大な怪獣が現れる。見上げる二人。",
			"lines": [["A", "でかい……本物みたい"], ["B", "近くで見たら{怪獣}だぞ"], ["A", "言うな"]],
			"memo": "怪獣役の物をカメラの手前に置き、街役の物より大きく映す"},
		{"dir": "逃げる二人。その背後で大爆発。",
			"lines": [["A", "逃げろー！"], ["B", "どっちに！？"], ["A", "カメラに映るほうに！"]],
			"memo": "爆発が二人の背後に映るように。合図2で爆発"},
		{"dir": "倒れた怪獣。二人がおそるおそる近づく。",
			"lines": [["B", "倒したのは誰だ"], ["A", "たぶんスタッフ"], ["二人", "ばんざーい！"]],
			"memo": "F で怪獣を倒し、その前で喜ぶ二人を映す"}]},
	# 5 怪獣、段ボールの街に現る・完全版（自称・巨匠。5場面を、フィルム1本で止めずに撮る）
	{"scenes": [
		{"dir": "のどかな街。二人が歩いてくる。怪獣は、まだ影も形もない。",
			"lines": [["A", "いい街だねえ。よく見ると全部{街}だけど"], ["B", "住めば都です"], ["A", "怪獣とか、出ないよね"]],
			"memo": "歩いている二人と、街役の物を2つ以上映す。怪獣役の物は、まだ映さない"},
		{"dir": "街の向こうに、巨大な怪獣。二人は見上げて固まる。",
			"lines": [["B", "出ました"], ["A", "出たね……あれ、{怪獣}じゃない？"], ["（怪獣の声）", "ガオー"]],
			"memo": "怪獣役の物を、街役の物より大きく映す。固まった二人も一緒に"},
		{"dir": "怪獣の技が街を襲う。二人は走って逃げる。怪獣は、びくともしない。",
			"lines": [["A", "{技}が飛んできた！"], ["B", "押さない、駆けない、しゃべらない！"], ["（爆発）", ""]],
			"memo": "逃げる二人の背後で爆発。すぐに、街役の物が2つ以上倒れること。怪獣は立ったまま"},
		{"dir": "ところが怪獣は、なぜか、ひとりでに倒れる。",
			"lines": [["B", "怪獣は、段差につまずきました"], ["A", "いま、誰か押さなかった？"], ["B", "誰も押していません"]],
			"memo": "立っている怪獣が倒れるところを映す。倒す人は映さない"},
		{"dir": "倒れた怪獣の前。二人が近づいて、万歳。",
			"lines": [["A", "勝ったの？"], ["B", "勝ったことにしましょう"], ["二人", "ばんざーい！"]],
			"memo": "倒れた怪獣の前の二人を、寄りで大きく映す"}],
		"beats": [
			{"rule": "stroll", "from": 0, "to": 1, "gait": "walk", "pose": "idle", "look": "", "face": ["happy", "neutral"]},
			{"rule": "appear", "from": 1, "to": 1, "gait": "walk", "pose": "freeze", "look": "monster", "face": ["surprised", "surprised"], "music": "music_tension", "roar": true},
			{"rule": "attack", "from": 1, "to": 2, "gait": "run", "pose": "idle", "look": "monster", "face": ["shock", "shock"], "boom": true},
			{"rule": "topple", "from": 2, "to": 2, "gait": "walk", "pose": "idle", "look": "monster", "face": ["surprised", "surprised"], "music": ""},
			{"rule": "cheer", "from": 2, "to": 2, "gait": "walk", "pose": "cheer", "look": "camera", "face": ["happy", "happy"], "meet": true, "music": "music_reunion"}]},
	# 6 怪獣ドラマ 第1話（地方テレビ局。同じ5場面を、場面ごとにカットを割って撮る）
	#   cuts：場面が撮れたら、フィルムが止まる（カット）。止まっている間に次の場面の用意（場転）をして、1 で回し直す
	{"cuts": true, "scenes": [
		{"dir": "のどかな街。二人が歩いてくる。",
			"lines": [["A", "この街も、平和になったね"], ["B", "前回までのあらすじ、ありましたっけ"], ["A", "第1話だよ"]],
			"memo": "歩いている二人と、街役の物を2つ以上映す。怪獣役の物は、まだ映さない（カットのあとで出す）"},
		{"dir": "【場転】街の向こうに、巨大な怪獣。二人は見上げて固まる。",
			"lines": [["B", "あれは……"], ["A", "{怪獣}だ！"], ["（怪獣の声）", "ガオー"]],
			"memo": "カットの間に、怪獣役の物をカメラの手前へ。街より大きく映す"},
		{"dir": "【場転】怪獣の技が街を襲う。二人は走って逃げる。",
			"lines": [["A", "{技}が来る！"], ["B", "CMまで持ちこたえて！"], ["（爆発）", ""]],
			"memo": "カットの間に、爆弾に火薬を詰めて、街の奥へ。爆発のあと、街役の物が2つ以上倒れること。怪獣は立ったまま"},
		{"dir": "【場転】怪獣が、なぜか、ひとりでに倒れる。",
			"lines": [["B", "怪獣は、段差につまずきました"], ["A", "毎週つまずくの？"]],
			"memo": "カットの間に、倒れた街を片づけてもいい。立っている怪獣が倒れるところを映す。倒す人は映さない"},
		{"dir": "【場転】倒れた怪獣の前。二人が近づいて、万歳。次回へ続く。",
			"lines": [["A", "勝ったの？"], ["B", "来週もまた見てね"], ["二人", "ばんざーい！"]],
			"memo": "カットの間に、カメラを二人へ寄せる。倒れた怪獣の前の二人を、寄りで大きく映す"}],
		"beats": [
			{"rule": "stroll", "from": 0, "to": 1, "gait": "walk", "pose": "idle", "look": "", "face": ["happy", "neutral"]},
			{"rule": "appear", "from": 1, "to": 1, "gait": "walk", "pose": "freeze", "look": "monster", "face": ["surprised", "surprised"], "music": "music_tension", "roar": true},
			{"rule": "attack", "from": 1, "to": 2, "gait": "run", "pose": "idle", "look": "monster", "face": ["shock", "shock"], "boom": true},
			{"rule": "topple", "from": 2, "to": 2, "gait": "walk", "pose": "idle", "look": "monster", "face": ["surprised", "surprised"], "music": ""},
			{"rule": "cheer", "from": 2, "to": 2, "gait": "walk", "pose": "cheer", "look": "camera", "face": ["happy", "happy"], "meet": true, "music": "music_reunion"}]},
	# 7 わが社の紹介動画（最初の一本。怪しい情報商材の「バズる黄金の4カット」。docs/production/tutorial-cm.md）
	#   役者：社長（必ず要る）と社員3人（いなくても撮れる。足りない分は、等身大パネルや物で代用）
	{"cuts": true, "cast": ["社長", "社員", "社員", "社員"], "cast_need": 1, "scenes": [
		{"dir": "【わが社の前】社長と社員が並んで、カメラにあいさつ。社員が足りない所は、等身大パネル。",
			"lines": [["社長", "はい、せーの"], ["全員", "格安アクション映画制作班です！"], ["社員", "（小声）一人、パネルです"]],
			"memo": "出ている役者を全員、印①に立たせて、明るく映す（カメラは段ボールに載せて置く）"},
		{"dir": "【場転】わが社の腕前。城を背に、社長がドヤ顔。",
			"lines": [["社長", "お城も、建てます"], ["社員", "（画面の外から）{城}です"]],
			"memo": "社長だけを印②へ。城役の物を後ろに置いて、一緒に明るく映す（城役は、物を見て Y で決める）"},
		{"dir": "【場転】社長の背後で、爆発。社長は動じない。社員は、びくっとする。",
			"lines": [["社長", "爆発も、します"], ["（爆発）", ""], ["社長", "……ご近所の許可は、取っています"]],
			"memo": "爆炎の書割を、役者の奥に立てる。1 で回すと、書割が爆ぜる"},
		{"dir": "【場転】手描きの看板（会社の名前と電話番号）の前で、全員でお辞儀。",
			"lines": [["全員", "ぜんぶ、格安で！"], ["社長", "お電話、お待ちしております"], ["社員", "番号は、看板のとおりです"]],
			"memo": "板やパネルに会社の名前を描いて（F）、表をカメラへ向けて置く。その前に役者を集める"}],
		"beats": [
			{"rule": "show", "from": 0, "to": 0, "gait": "walk", "pose": "greet", "look": "camera", "face": ["happy", "happy"], "music": "music_tension"},
			{"rule": "show", "role": "castle", "who": [0], "from": 0, "to": 1, "gait": "walk", "pose": "hips", "look": "camera", "face": ["happy", "happy"]},
			{"rule": "blast", "from": 1, "to": 1, "gait": "walk", "pose": "hips", "pose_by": {"1": "freeze", "2": "freeze", "3": "freeze"}, "look": "camera", "face": ["neutral", "neutral"], "music": "", "boom": true},
			{"rule": "sign", "from": 1, "to": 2, "gait": "walk", "pose": "bow", "look": "camera", "face": ["happy", "happy"], "meet": true, "music": "music_reunion"}]},
	# 8 旅する二人（天文同好会の会報の付録・第2弾。場所が変わる4カット。場転で、片づける・出す・寄せる・照らし直す）
	{"cuts": true, "scenes": [
		{"dir": "【城の門】旅の二人が、城の前で出発を誓う。",
			"lines": [["A", "さあ、月を見に行こう"], ["B", "城から出たこと、ありましたっけ"], ["A", "{城}の外は、初めてだ"]],
			"memo": "城役の物と二人を、一緒に明るく映す"},
		{"dir": "【場転：月夜の丘】城を離れ、丘の上。二人は月を見上げる。",
			"lines": [["B", "見て、{月}"], ["A", "旅に出てよかった"]],
			"memo": "カットの間に、城を片づけるか隠して、月役の物を出す。城が映ると、同じ場所に見えてしまう"},
		{"dir": "【場転】月の下で、なぜか大爆発。",
			"lines": [["A", "流れ星？"], ["（爆発）", ""], ["B", "近い近い近い！"]],
			"memo": "カットの間に、爆炎の書割（または爆弾）を二人の奥へ。1 で回すと、書割が爆ぜる"},
		{"dir": "【場転】旅の終わり。二人が寄ってきて、決めポーズ。",
			"lines": [["二人", "次の旅で、また会おう！"]],
			"memo": "カットの間に、カメラを二人へ寄せて、ライトも向け直す。二人を、寄りで大きく映す"}],
		"beats": [
			{"rule": "show", "role": "castle", "from": 0, "to": 0, "gait": "walk", "pose": "idle", "look": "camera", "face": ["happy", "happy"], "music": "music_tension"},
			{"rule": "show", "role": "moon", "hide": "castle", "from": 0, "to": 1, "gait": "walk", "pose": "idle", "look": "", "face": ["happy", "happy"], "music": ""},
			{"rule": "blast", "from": 1, "to": 1, "gait": "walk", "pose": "freeze", "look": "camera", "face": ["shock", "shock"], "boom": true},
			{"rule": "show", "close": true, "from": 1, "to": 2, "gait": "walk", "pose": "cheer", "look": "camera", "face": ["happy", "happy"], "meet": true, "music": "music_reunion"}]},
	# 9 転がる大岩・予告編（ベレー帽先生の新作。冒険映画の有名な冒頭のパロディ。4カット：
	#   忍び足で奥へ（カメラも動く）→ 秘宝をすり替えると罠が作動（上から落ちる）→ 大岩に追われて逃げる → 間一髪で決め）
	{"cuts": true, "scenes": [
		{"dir": "【遺跡の奥】探検家の二人が、忍び足で奥へ。カメラは二人と一緒に進む。",
			"lines": [["A", "この奥に、黄金の像がある"], ["B", "どこかで見た話ですね"], ["A", "気のせいだ"]],
			"memo": "歩く二人を映したまま、カメラを動かす（台車に載せる・手で押す・引かせる）。押す人は映さない"},
		{"dir": "【場転】黄金の像を、重さの同じ袋とすり替える。……頭の上から、何かが落ちてくる。",
			"lines": [["B", "{秘宝}と重さは、同じはず"], ["（罠）", "ゴゴゴゴ……"], ["A", "同じじゃなかった！"]],
			"memo": "立ち止まった二人のそばに、上から物を落とす（1m以上）。落とす人は映さない"},
		{"dir": "【場転】奥から、大岩が転がってくる。二人は走って逃げる。",
			"lines": [["A", "走れ！ {大岩}だ！"], ["（大岩）", "ゴロゴロゴロ"], ["B", "予算のわりに、大きい！"]],
			"memo": "逃げる二人の後ろから、転がる物を迫らせる（押す・坂を下らせる・ロープで引く）。押す人は映さない。張りぼての大岩は、電話で借りられる"},
		{"dir": "【場転】間一髪、外へ飛び出して、決めポーズ。",
			"lines": [["二人", "今冬、公開未定！"]],
			"memo": "カットの間に、カメラを二人へ寄せる。二人を、寄りで大きく映す"}],
		"beats": [
			{"rule": "track", "from": 0, "to": 1, "gait": "walk", "pose": "idle", "look": "", "face": ["neutral", "happy"], "music": "music_tension"},
			{"rule": "drop", "from": 1, "to": 1, "gait": "walk", "pose": "freeze", "look": "camera", "face": ["surprised", "shock"], "music": ""},
			{"rule": "chase", "from": 1, "to": 2, "gait": "run", "pose": "idle", "look": "", "face": ["shock", "shock"], "music": "music_tension"},
			{"rule": "show", "close": true, "from": 2, "to": 2, "gait": "walk", "pose": "cheer", "look": "camera", "face": ["happy", "happy"], "meet": true, "music": "music_reunion"}]},
	# 10 空き巣にご用心（クリスマスの留守番コメディのパロディ。防犯ビデオ）：振り子が当たる・炎がお尻に
	{"cuts": true, "scenes": [
		{"dir": "【玄関】泥棒の二人が、留守の家の前で手もみする。",
			"lines": [["A", "この家、子どもが一人で留守番だってよ"], ["B", "玄関が{玄関}ですね。楽勝です"], ["A", "フラグを立てるな"]],
			"memo": "玄関役の物の前の二人を、明るく映す（物を見て Y で玄関の役にする）。ツリーも映ると、クリスマスらしい"},
		{"dir": "【場転】ドアを開けると、吊るしてあった物が、振り子になって顔に当たる。",
			"lines": [["B", "開いてますよ"], ["（罠）", "ブォン"], ["A", "……知ってた"]],
			"memo": "吊るした物（ロープで吊る・焼き切る・押す）を、歩く二人に当てる。当てる人は映さない"},
		{"dir": "【場転】足元のボタンを踏むと、トーチの炎がお尻に。",
			"lines": [["A", "いま、何か踏んだ"], ["（罠）", "ボッ"], ["B", "あっちっち！"]],
			"memo": "止まった二人のすぐそばで、トーチの炎を出す（ボタン・時計・ケーブル）。点ける人は映さない"},
		{"dir": "【場転】二人そろって、ぐったり。……防犯の大切さを訴える。",
			"lines": [["二人", "戸締まりは、しっかりと"]],
			"memo": "カットの間に、カメラを二人へ寄せる。二人を、寄りで大きく映す"}],
		"beats": [
			{"rule": "show", "role": "door", "from": 0, "to": 0, "gait": "walk", "pose": "idle", "look": "camera", "face": ["happy", "happy"], "music": "music_tension"},
			{"rule": "hit", "from": 0, "to": 1, "gait": "walk", "pose": "idle", "look": "", "face": ["neutral", "shock"], "music": ""},
			{"rule": "scorch", "from": 1, "to": 1, "gait": "walk", "pose": "freeze", "look": "", "face": ["shock", "shock"]},
			{"rule": "show", "close": true, "from": 1, "to": 2, "gait": "walk", "pose": "idle", "look": "camera", "face": ["sad", "sad"], "meet": true, "music": "music_reunion"}]},
	# 11 月夜の自転車（宇宙から来た友だちの映画のパロディ）：満月の前を、シルエットが横切る
	{"cuts": true, "scenes": [
		{"dir": "【月夜の丘】大きな満月。二人は空を見上げる。",
			"lines": [["A", "今夜は、満月だ"], ["B", "飛べる気がする"]],
			"memo": "月役の物と二人を、一緒に映す（物を見て Y で月の役にする）"},
		{"dir": "【場転】自転車がふわりと浮いて、満月の前を横切る。",
			"lines": [["A", "飛んだ！"], ["B", "{自転車}に乗ってますけどね"]],
			"memo": "満月の前を、役者が横切る（画面の上で、月に重ねる）。月を高く吊る・カメラを低く構える・パネルを引く。自転車役の物を抱えると、それらしい。シルエットなので暗くてもいい"},
		{"dir": "【場転】そっと着地して、決めポーズ。",
			"lines": [["二人", "おうち、帰れました"]],
			"memo": "カットの間に、カメラを二人へ寄せる。二人を、寄りで大きく映す"}],
		"beats": [
			{"rule": "show", "role": "moon", "from": 0, "to": 0, "gait": "walk", "pose": "idle", "look": "", "face": ["surprised", "happy"], "music": "music_tension"},
			{"rule": "cross", "from": 0, "to": 1, "gait": "run", "pose": "idle", "look": "", "face": ["happy", "surprised"], "music": ""},
			{"rule": "show", "close": true, "from": 1, "to": 2, "gait": "walk", "pose": "cheer", "look": "camera", "face": ["happy", "happy"], "meet": true, "music": "music_reunion"}]},
	# 12 沈まない船の舳先で（豪華客船の恋愛映画のパロディ）：高い所で、風を受けて両手を広げる
	{"cuts": true, "scenes": [
		{"dir": "【夕日の舳先】船のいちばん前に、二人が立つ。",
			"lines": [["A", "ここが、船のいちばん前"], ["B", "どう見ても、{船}ですけどね"]],
			"memo": "二人を、床より高い所（ボートの舳先・台・箱の上）に立たせる。印を高い所に置く。船役・海役の物も映すと、それらしい"},
		{"dir": "【場転】両手を広げると、海風が吹きつける。",
			"lines": [["A", "飛んでる……！"], ["B", "送風機の音、入ってます"]],
			"memo": "送風機の風を、二人の正面から当てる（手ぶらで F・ボタン・時計で回す）。送風機と張りぼてのボートは、廃材置き場に出してある"},
		{"dir": "【場転】寄りで、見つめ合う二人。",
			"lines": [["二人", "沈まない予算で、お送りしました"]],
			"memo": "カットの間に、カメラを二人へ寄せる。二人を、寄りで大きく映す"}],
		"beats": [
			{"rule": "high", "from": 0, "to": 1, "gait": "walk", "pose": "idle", "look": "", "face": ["happy", "happy"], "music": "music_tension"},
			{"rule": "wind", "from": 1, "to": 1, "gait": "walk", "pose": "cheer", "look": "", "face": ["happy", "happy"], "music": ""},
			{"rule": "show", "close": true, "from": 1, "to": 2, "gait": "walk", "pose": "idle", "look": "camera", "face": ["happy", "happy"], "meet": true, "music": "music_reunion"}]},
	# 13 弾をよける男（仮想世界のアクション映画のパロディ）：のけぞる二人のまわりを、カメラが回り込む
	{"cuts": true, "scenes": [
		{"dir": "【屋上】黒いコートの二人が、向き合う。",
			"lines": [["A", "この世界は、作り物だ"], ["B", "この{屋上}も、作り物です"]],
			"memo": "屋上役の物の前で向き合う二人を、明るく映す（物を見て Y で屋上の役にする）"},
		{"dir": "【場転】弾が飛んでくる。二人はのけぞる。時間が止まり、カメラだけが回り込む。",
			"lines": [["（弾）", "ヒュン"], ["A", "……よけた"], ["B", "まだ動いちゃだめです"]],
			"memo": "止まった二人を映したまま、カメラを二人のまわりで回す（60度くらい）。台車を、滑車とロープで弧に引く・手で押す。押す人は映さない"},
		{"dir": "【場転】寄りで、決めのひとこと。",
			"lines": [["二人", "選んだのは、格安のほうだ"]],
			"memo": "カットの間に、カメラを二人へ寄せる。二人を、寄りで大きく映す"}],
		"beats": [
			{"rule": "show", "role": "roof", "from": 0, "to": 0, "gait": "walk", "pose": "idle", "look": "camera", "face": ["neutral", "neutral"], "music": "music_tension"},
			{"rule": "orbit", "from": 0, "to": 1, "gait": "walk", "pose": "freeze", "look": "", "face": ["shock", "neutral"], "music": ""},
			{"rule": "show", "close": true, "from": 1, "to": 2, "gait": "walk", "pose": "idle", "look": "camera", "face": ["neutral", "happy"], "meet": true, "music": "music_reunion"}]},
	# 14 階段を駆け上がれ（ボクサーの朝の映画のパロディ）：並んで走る → 駆け上がる → 頂上で万歳
	{"cuts": true, "scenes": [
		{"dir": "【夜明けの街】二人が走る。カメラも並んで走る。",
			"lines": [["A", "まだ、終わっちゃいない"], ["B", "朝ごはん、まだです"]],
			"memo": "走る二人を映したまま、カメラを動かす。押す人は映さない"},
		{"dir": "【場転】長い階段を、一気に駆け上がる。",
			"lines": [["A", "うおおお、{階段}だ"], ["B", "息が……"]],
			"memo": "上の印を、高い所（階段の上・張りぼての山・台・箱）に置き、二人に上らせる（坂や低い段を並べる）"},
		{"dir": "【場転】頂上で、両手を突き上げる。",
			"lines": [["二人", "{頂上}だ！ エイドリ……いや、なんでもない！"]],
			"memo": "高い所で万歳する二人を、明るく映す。頂上役の物（山など）も映すと、それらしい"}],
		"beats": [
			{"rule": "track", "from": 0, "to": 1, "gait": "run", "pose": "idle", "look": "", "face": ["neutral", "neutral"], "music": "music_tension"},
			{"rule": "climb", "from": 1, "to": 2, "gait": "run", "pose": "idle", "look": "", "face": ["neutral", "shock"], "music": ""},
			{"rule": "high", "from": 2, "to": 2, "gait": "walk", "pose": "cheer", "look": "camera", "face": ["happy", "happy"], "music": "music_reunion"}]},
	# 15 カップ麺の3分（CM）：お湯を注ぐ → タイマーがチン → うまい！
	{"cuts": true, "scenes": [
		{"dir": "【台所】二人が、カップ麺にお湯を注いで、ふたをする。",
			"lines": [["A", "{カップ麺}に、お湯を注いだ。あと3分"], ["B", "長い……"]],
			"memo": "カップ麺役の物と二人を、明るく映す（物を見て Y でカップ麺の役にする）"},
		{"dir": "【場転】3分後。タイマーが、チン！",
			"lines": [["（タイマー）", "チン"], ["二人", "きた！"]],
			"memo": "目覚まし時計か押しボタンを、映っている所で鳴らす（ねじを巻いておく・ケーブル）"},
		{"dir": "【場転】寄りで、うまい！",
			"lines": [["二人", "うまい！ 3分、待ったかいがあった！"]],
			"memo": "カットの間に、カメラを二人へ寄せる。二人を、寄りで大きく映す"}],
		"beats": [
			{"rule": "show", "role": "noodle", "from": 0, "to": 0, "gait": "walk", "pose": "idle", "look": "camera", "face": ["neutral", "neutral"], "music": "music_tension"},
			{"rule": "ring", "from": 0, "to": 1, "gait": "walk", "pose": "freeze", "look": "", "face": ["surprised", "surprised"], "music": ""},
			{"rule": "show", "close": true, "from": 1, "to": 2, "gait": "walk", "pose": "cheer", "look": "camera", "face": ["happy", "happy"], "meet": true, "music": "music_reunion"}]},
	# 16 髪がなびく車のCM：風を受ける二人 → 車が走り抜ける → 決め
	{"cuts": true, "scenes": [
		{"dir": "【海沿いの道】オープンカーの二人。髪が、風になびく。",
			"lines": [["A", "風が、気持ちいい"], ["B", "送風機ですけどね"]],
			"memo": "止まった二人に、送風機の風を正面から当てる。送風機と車の正面の書割は、廃材置き場に出してある"},
		{"dir": "【場転】車が、カメラの前を走り抜ける。",
			"lines": [["（{車}）", "ブォーン"]],
			"memo": "大きな物（車の正面の書割など）を、画面の中で2m以上走らせる（台車に載せて押す・引く）。押す人は映さない"},
		{"dir": "【場転】寄りで、決めのひとこと。",
			"lines": [["二人", "新しい走りを、あなたに"]],
			"memo": "カットの間に、カメラを二人へ寄せる。二人を、寄りで大きく映す"}],
		"beats": [
			{"rule": "wind", "from": 0, "to": 0, "gait": "walk", "pose": "idle", "look": "", "face": ["happy", "happy"], "music": "music_tension"},
			{"rule": "pass", "from": 0, "to": 1, "gait": "walk", "pose": "idle", "look": "camera", "face": ["happy", "happy"], "music": ""},
			{"rule": "show", "close": true, "from": 1, "to": 2, "gait": "walk", "pose": "cheer", "look": "camera", "face": ["happy", "happy"], "meet": true, "music": "music_reunion"}]},
]


# せりふの {役} を、見立てた物の名前に置き換える。names：{役の名前: 物の名前}（決まっていない役は入れない）
static func fill(text: String, names: Dictionary) -> String:
	for word: String in WORDS:
		text = text.replace("{%s}" % word, str(names.get(WORDS[word][0], WORDS[word][1])))
	return text


# 役者の役の名前（台本の "cast"。無ければ A・B の二人）。役者は台本ごとに最大4人（A・B・C・D の順）
static func cast(index: int) -> Array:
	return of(index).get("cast", ["A", "B"])


static func cast_size(index: int) -> int:
	return clampi(cast(index).size(), 1, 4)


# 必ず誰かが演じる役の数（前から数える。"cast_need"。無ければ全員）。残りは、誰も演じなくても撮れる
static func cast_need(index: int) -> int:
	return clampi(int(of(index).get("cast_need", cast_size(index))), 1, cast_size(index))


static func of(index: int) -> Dictionary:
	return SCRIPTS[clampi(index, 0, SCRIPTS.size() - 1)]


# その台本の、場面の列（無ければ空。今までの3場面の台本は、合図 1・2・3 で進める）
static func beats(index: int) -> Array:
	if index < 0 or index >= SCRIPTS.size():
		return []
	return SCRIPTS[index].get("beats", [])


# その台本は、場面ごとにカットを割って撮るか（場面が撮れるとフィルムが止まり、場転のあと 1 で回し直す）。
# false なら長回し（フィルムは、切れるまで止まらない）
static func cuts(index: int) -> bool:
	if index < 0 or index >= SCRIPTS.size():
		return false
	return bool(SCRIPTS[index].get("cuts", false))
