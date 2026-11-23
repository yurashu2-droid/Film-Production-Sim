extends SceneTree
# 大項目と小項目のindexが、元のITEMSのindexと混線しないことを検証する。
const Lab := preload("res://vfx/vfx_lab.gd")
var failed := false
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("VFX_PICKER_CHECK ",label," ","OK" if ok else "FAIL")
	failed=failed or not ok
func run() -> void:
	var lab := Lab.new()
	root.add_child(lab)
	lab.loop_enabled=false
	var ids: Array[String]=[]
	var seen: Dictionary={}
	for item: Array in Lab.ITEMS:
		ids.append(item[1])
		seen[item[1]]=true
		check(Lab.category_for(item[1]) in Lab.CATEGORIES,"category exists: "+item[1])
	check(ids.size()==seen.size(),"effect IDs are unique")
	for size_class:String in ["L","M","S"]:
		var title={"L":"大／多","M":"中／標準","S":"小／簡潔"}[size_class]
		lab._choose_category(Lab.CATEGORIES.find("Pixel×Real・"+title))
		check(lab._picker.item_count==Lab.Px50.Catalog.TIER_COUNTS[size_class]+(1 if size_class=="L" else 0),"pack content category: "+size_class)
		var last_item=lab._picker.item_count-1
		lab._picker.item_selected.emit(last_item)
		check(lab.current==lab._picker.get_item_id(last_item),"pack50 leaf maps to global selection: "+size_class)
	lab._choose_category(Lab.CATEGORIES.find("生成素材"))
	check(lab._picker.item_count==8,"generated assets has original prototype and seven methods")
	var method_index:=ids.find("gen_material")
	lab.play(method_index)
	check(lab._picker.get_item_id(lab._picker.selected)==method_index,"image method is selectable through category picker")
	lab._choose_category(Lab.CATEGORIES.find("Pixel×Real"))
	check(lab._picker.item_count==14,"Pixel×Real has 4 existing and 10 new animations")
	var local_index := lab._picker.item_count-1
	var global_index := lab._picker.get_item_id(local_index)
	lab._picker.item_selected.emit(local_index)
	check(lab.current==global_index,"leaf selection maps to global effect index")
	lab._cycle_item(1)
	check(lab.current==lab._picker.get_item_id(0),"next wraps within the category")
	lab._cycle_item(-1)
	check(lab.current==lab._picker.get_item_id(local_index),"previous wraps within the category")
	var ink_index := ids.find("ink_barrage")
	lab.play(ink_index)
	check(lab._category_picker.selected==Lab.CATEGORIES.find("墨") and lab._picker.get_item_id(lab._picker.selected)==ink_index,"direct effect selection synchronizes both pickers")
	for row in lab._picker.item_count:
		check(Lab.category_for(Lab.ITEMS[lab._picker.get_item_id(row)][1])=="墨","ink category excludes other styles")
	lab.queue_free()
	await process_frame
	# 別に配る VFX パック（addons/）が無い環境：その項目を出さず、選んでも止まらない
	var bare := Lab.new()
	bare._punk_fx = null
	bare._origami_fx = null
	root.add_child(bare)
	bare.loop_enabled = false
	var origami_category := Lab.CATEGORIES.find("折り紙・紙工作")
	bare._choose_category(origami_category)
	check(bare._picker.item_count == 0 and bare._category_picker.is_item_disabled(origami_category), "origami category is empty and disabled without the pack")
	bare._choose_category(Lab.CATEGORIES.find("赤黒パンク"))
	var pack_rows := 0
	for row in bare._picker.item_count:
		if (Lab.ITEMS[bare._picker.get_item_id(row)][1] as String).begins_with("pk_"):
			pack_rows += 1
	check(bare._picker.item_count > 0 and pack_rows == 0, "punk category keeps only the built-in effects without the pack")
	bare.play(ids.find("og_hit"))
	bare.play(ids.find("pk_hit"))
	check(get_nodes_in_group("origami_vfx").is_empty() and get_nodes_in_group("punk_ink_vfx").is_empty(), "selecting a pack effect without the pack spawns nothing")
	check(Lab._pack("res://addons/no_such_pack/none.gd") == null, "a missing pack loads as null")
	bare.queue_free()
	await process_frame
	print("VFX_PICKER_TEST_FAIL" if failed else "VFX_PICKER_TEST_OK")
	quit(1 if failed else 0)
