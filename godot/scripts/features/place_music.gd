extends Node
## 場所の曲（ゲームが始まってからの BGM）：
##   ・事務所（依頼を選ぶ・帰社した次の日）では music_office、準備（廃材を集める・軽トラで運ぶ・現場で組む・テイクを選ぶ）では music_prep
##   ・カウントダウン・本番・見返し・試写会は、今までどおり（劇中曲は main.gd と場面の列が鳴らす）。その間は場所の曲を止めて、邪魔しない
##   ・曲は UVI で作った物（tools/bgm/songs/office_combo.py・prep_caper.py）。公開リポジトリには無いので、無ければ鳴らさない
## 合図は送らない：場所（会社の phase と game.state）は全員に配られているので、それぞれの画面で自分で決める（見返しの記録にも載らない）
const OFFICE := "music_office"
const PREP := "music_prep"
const FADE := 1.5

var game: Node


# 鳴っている曲と、今いる場所の曲を毎コマ比べる（覚えておかない：劇中曲に替わって止まったあとも、ちゃんと戻す）
func _process(_delta: float) -> void:
	var want := wanted()
	var now: String = Sfx.current_music()
	if want == "":
		if now in [OFFICE, PREP]:
			Sfx.stop_music(FADE)
		return
	if now == want:
		return
	if now != "" and now not in [OFFICE, PREP]:
		return              # 劇中曲が鳴っている間（本番の直後など）は、それが止まってから
	if Sfx.has_sound(want):
		Sfx.play_music(want, FADE)


# 今いる場所の曲（"" ＝場所の曲は鳴らさない）
func wanted() -> String:
	if game == null or game.replaying or game.state not in [game.S.PREP, game.S.RESULT, game.S.ORDER]:
		return ""
	var flow: Node = game.production
	if flow == null:
		return PREP
	var phase := int(flow.phase)
	if phase <= 1:
		return OFFICE
	if phase <= 4:
		return PREP
	return ""
