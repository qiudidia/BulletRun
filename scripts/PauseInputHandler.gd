extends Node

@export var toggle_callable: Callable


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if toggle_callable.is_valid():
			toggle_callable.call()
