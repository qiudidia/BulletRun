extends Node
## 场景过渡动画工具
## 提供淡入淡出效果

const TRANSITION_DURATION := 0.35

var _overlay: ColorRect = null
var _is_transitioning: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func fade_out(target_scene: String, duration: float = TRANSITION_DURATION) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	
	var root := get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_overlay)
	
	var tween := create_tween()
	tween.tween_property(_overlay, "color", Color(0, 0, 0, 0.85), duration)
	tween.finished.connect(func():
		_overlay.queue_free()
		_overlay = null
		_is_transitioning = false
		get_tree().change_scene_to_file(target_scene)
	)


func fade_in(duration: float = TRANSITION_DURATION) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	
	var root := get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.85)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_overlay)
	
	var tween := create_tween()
	tween.tween_property(_overlay, "color", Color(0, 0, 0, 0), duration)
	tween.finished.connect(func():
		_overlay.queue_free()
		_overlay = null
		_is_transitioning = false
	)


func fade_overlay(color: Color = Color(0, 0, 0, 0.7), duration: float = TRANSITION_DURATION) -> Tween:
	var root := get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_overlay)
	
	var tween := create_tween()
	tween.tween_property(_overlay, "color", color, duration)
	return tween


func fade_remove(duration: float = TRANSITION_DURATION) -> void:
	if not _overlay:
		return
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, duration)
	tween.finished.connect(func():
		_overlay.queue_free()
		_overlay = null
	)
