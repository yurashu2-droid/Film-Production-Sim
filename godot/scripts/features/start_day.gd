extends Node
## 遊んで確かめる用の起動：「-- --day2」を付けて起動すると、1日目（会社のCM）を飛ばして、2日目から始まる。
## 掲示板に、会社のCM以外の依頼（名場面のパロディなど）が全部出る（ふだんは、評判の格に合わせて毎日3枚）。リポジトリ直下の play_new_jobs.bat から起動する。
## 決めるのはホスト（日にちは、参加者へは会社の状態と一緒に届く）。付けなければ、何もしない
var game: Node


func setup() -> void:
	apply(OS.get_cmdline_user_args())


func apply(args: Array) -> void:
	if "--day2" in args and Net.mode != "client" and game.production != null and int(game.production.day) <= 1:
		game.production.day = 2
		game.production.all_jobs = true
