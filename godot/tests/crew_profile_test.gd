extends SceneTree

var failed := false

func check(ok: bool, label: String) -> void:
	print("CREW_PROFILE_CHECK ", label, " ", "OK" if ok else "FAIL")
	failed = failed or not ok

func _initialize() -> void:
	if not FileAccess.file_exists("res://scripts/crew_profile.gd"):
		check(false, "crew progression model exists")
		quit(1)
		return
	var model: GDScript = load("res://scripts/crew_profile.gd")
	var profile: RefCounted = model.new()
	check(profile.level("actor") == 1 and profile.level("camera") == 1, "new player starts at Lv1")
	var first: Dictionary = profile.award("film-1", {"actor":["acting","acting"], "backstage":["setup"], "camera":[]})
	check(first.actor.gained == 30 and first.backstage.gained == 30 and first.camera.gained == 0, "one action per kind plus completion, idle roles get zero")
	check(profile.award("film-1", {"actor":["acting","action","ensemble"]}).is_empty() and profile.xp.actor == 30, "repeated receipt never grants XP")
	var second: Dictionary = profile.award("film-2", {"actor":["acting"], "camera":["framing","operation","lighting","invalid"], "unknown":["anything"]})
	check(profile.xp.actor == 60 and profile.level("actor") == 2 and second.actor.before_level == 1 and second.actor.after_level == 2, "Lv2 unlock at exactly 60 XP")
	check(second.camera.gained == 70 and profile.xp.camera == 70, "maximum 70 per role and unknown actions ignored")
	for pair: Array in [[59,1],[60,2],[179,2],[180,3],[359,3],[360,4],[599,4],[600,5],[850,5]]:
		profile.xp.actor = pair[0]
		check(profile.level("actor") == pair[1], "level boundary %d" % pair[0])
	profile.xp.actor = 60
	var path := "user://crew-profile-test-%d.cfg" % OS.get_process_id()
	profile.path = path
	profile.run_style = "volt"
	check(profile.save() == OK, "profile writes to isolated test file")
	var restored: RefCounted = model.new()
	check(restored.open(path) == OK and restored.xp.actor == 60 and restored.run_style == "volt", "restart restores XP and chosen VFX")
	check(restored.award("film-2", {"actor":["acting"]}).is_empty(), "receipt dedup survives restart")
	check(restored.level("backstage") == 1 and restored.xp.backstage == 30, "roles keep independent progress")
	DirAccess.remove_absolute(path)
	if not failed: print("CREW_PROFILE_TEST_OK")
	quit(1 if failed else 0)
