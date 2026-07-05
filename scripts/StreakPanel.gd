extends Control
## 击杀连杀提示面板
## 显示连续击杀获得的连杀称号

signal streak_cleared()

@onready var streak_label: Label = $StreakLabel
@onready var combo_count: Label = $ComboCount

var _current_streak: int = 0
var _visible_time: float = 0.0
var _display_duration: float = 2.5

var streak_titles: Dictionary = {
	5: "连杀 x5!",
	10: "杀戮机器!",
	15: "无人能挡!",
	20: "传奇杀手!",
	25: "神一般存在!",
}


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not visible:
		return
	_visible_time += delta
	if _visible_time >= _display_duration:
		hide_streak()


func show_streak(count: int) -> void:
	_current_streak = count
	_visible_time = 0.0
	
	if count >= 5:
		apply_streak_style(count)
		visible = true
	else:
		visible = false


func apply_streak_style(count: int) -> void:
	var title: String = streak_titles.get(count, "连杀 x%d!" % count)
	
	if streak_label:
		streak_label.text = title
	if combo_count:
		combo_count.text = "x%d" % count
	
	var accent_color: Color
	match count:
		5:
			accent_color = Color(0.3, 0.7, 1.0, 1)
		10:
			accent_color = Color(1, 0.5, 0.2, 1)
		15:
			accent_color = Color(1, 0.3, 0.3, 1)
		20:
			accent_color = Color(0.8, 0.3, 1, 1)
		_:
			accent_color = Color(1, 0.85, 0.3, 1)
	
	if streak_label:
		streak_label.add_theme_color_override("font_color", accent_color)


func hide_streak() -> void:
	visible = false
	streak_cleared.emit()


func reset() -> void:
	_current_streak = 0
	visible = false
