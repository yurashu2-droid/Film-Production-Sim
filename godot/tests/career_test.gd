extends SceneTree
## 評判と格・毎日3枚の依頼（production_flow.gd）の確認。ゲームは起動しない（計算だけ）

var failed := false


func check(ok: bool, what: String) -> void:
	print("CAREER_CHECK %s %s" % [what, "OK" if ok else "FAIL"])
	if not ok:
		failed = true


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var flow: Node = load("res://scripts/production_flow.gd").new()
	# 格
	flow.reputation = 0
	check(flow.rank() == 1, "reputation 0 is rank 1")
	flow.reputation = 4
	check(flow.rank() == 2, "reputation 4 is rank 2")
	flow.reputation = 15
	check(flow.rank() == 4 and flow.rep_to_next() == -1, "reputation 15 is the top rank")
	# 毎日3枚：地元（1つ下）・いつもの（今の格）・大仕事（1つ上）
	flow.day = 1
	check(flow.offered() == [flow.debut_job()], "day one offers only the commercial")
	for rep: int in [0, 4, 9]:
		flow.reputation = rep
		var r: int = flow.rank()
		for d in range(2, 12):
			flow.day = d
			var offers: Array = flow.offers()
			var ranks: Array = offers.map(func(o: Array) -> int: return flow.job_rank(int(o[1])))
			var slots: Array = offers.map(func(o: Array) -> String: return str(o[0]))
			var ok: bool = slots == ["local", "regular", "big"] and ranks == [maxi(1, r - 1), r, r + 1] and flow.debut_job() not in flow.offered()
			if not ok:
				check(false, "day %d rank %d offers %s %s" % [d, r, slots, ranks])
				break
	check(true, "three slots match the rank on ten days at ranks 1-3")
	# 同じ日と評判なら、同じ依頼（ホストと参加者で同じ）
	flow.reputation = 4
	flow.day = 5
	check(flow.offered() == flow.offered(), "the same day gives the same jobs")
	# 格4の大仕事は、ハリウッドの一本
	flow.reputation = 15
	flow.day = 7
	var big: int = int(flow.offers()[2][1])
	check(bool(flow.JOBS[big].get("finale", false)), "at the top rank, the big job is the Hollywood one")
	# 評判の増減
	check(flow.rep_delta(3, 3, false, "regular") == 2, "all scenes: +2")
	check(flow.rep_delta(3, 3, true, "regular") == 3, "all scenes and the extra order: +3")
	check(flow.rep_delta(2, 3, false, "regular") == 1, "most scenes: +1")
	check(flow.rep_delta(1, 3, false, "regular") == -1, "few scenes: -1")
	check(flow.rep_delta(0, 3, false, "regular") == -2, "nothing: -2")
	check(flow.rep_delta(3, 3, true, "big") == 6 and flow.rep_delta(0, 3, false, "big") == -4, "the big job doubles both ways")
	check(flow.rep_delta(3, 3, true, "local") == 1 and flow.rep_delta(0, 3, false, "local") == -2, "the local job gains at most 1")
	# 全部の依頼に格がある
	var no_rank: Array = []
	for i in flow.JOBS.size():
		if not flow.JOBS[i].has("rank"):
			no_rank.append(i)
	check(no_rank.is_empty(), "every job has a rank %s" % [no_rank])
	flow.free()
	print("CAREER_TEST_FAIL" if failed else "CAREER_TEST_OK")
	quit(1 if failed else 0)
