extends Node

const Gust := preload("res://vfx/vfx_site_gust.gd")
const EVENT := "site_gust"

var game: Node
var _effect: Node3D


func hook_events() -> Array:
	return [EVENT]


func hook_rec_events() -> Array:
	return [EVENT]


func hook_event(_name: String, args: Array) -> void:
	var location: Node3D = game.production._site_root
	if not is_instance_valid(location):
		return
	_clear()
	_effect = Gust.new()
	location.add_child(_effect)
	_effect.start(args[0], location)


func hook_production_applied() -> void:
	if game.production.phase not in [4, 5]:
		_clear()


func _clear() -> void:
	if is_instance_valid(_effect):
		_effect.queue_free()
	_effect = null
