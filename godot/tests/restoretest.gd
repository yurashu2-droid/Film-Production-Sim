extends SceneTree
# 描画完了後に荷台から置き直しても、古い物理位置へ戻らない。
# godot --path godot --script res://tests/restoretest.gd
var game: Node
func _initialize() -> void:
    _run.call_deferred()
func _run() -> void:
    game = load("res://main.tscn").instantiate()
    game.input_locked = true
    root.add_child(game)
    await create_timer(0.6).timeout
    game.h_order_set("balcony", 1)
    game.h_order_confirm()
    await create_timer(0.6).timeout
    if DisplayServer.get_name() == "headless":
        await process_frame
    else:
        await RenderingServer.frame_post_draw
    game.h_sample()
    await create_timer(1.0).timeout
    var ok := true
    for i in 2:
        var rig: Node3D = game.spots[i]
        var want := Vector3(-3.6 if i == 0 else 3.6, 0, 2.6)
        var gap: float = rig.global_position.distance_to(want)
        print("RESTORE light", i, " gap=", gap)
        ok = ok and gap < 0.2
    for p in game.props.values():
        if p.kind == "window":
            var gap: float = p.global_position.distance_to(Vector3(0, 0, -4.1))
            print("RESTORE wall gap=", gap)
            ok = ok and gap < 0.3
    print("RESTORETEST_OK" if ok else "RESTORETEST_FAIL")
    quit(0 if ok else 1)
