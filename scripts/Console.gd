extends CanvasLayer

# =============================================================================
# 游戏内开发控制台
# 按 ~ 键打开/关闭，直接输入指令（无需 / 前缀）
# 仅游戏内可用
# =============================================================================

var console_panel: Panel
var input_line: LineEdit
var output_label: RichTextLabel
var console_visible: bool = false

var player: CharacterBody2D = null

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_ui()


func _create_ui() -> void:
	console_panel = Panel.new()
	console_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	console_panel.custom_minimum_size = Vector2(0, 80)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.6, 1.0, 0.8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	console_panel.add_theme_stylebox_override("panel", style)
	console_panel.visible = false
	add_child(console_panel)

	# 输出区域
	output_label = RichTextLabel.new()
	output_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	output_label.offset_top = 2
	output_label.offset_bottom = -26
	output_label.offset_left = 4
	output_label.offset_right = -4
	output_label.bbcode_enabled = true
	output_label.scroll_following = true
	output_label.add_theme_font_size_override("normal_font_size", 13)
	output_label.add_theme_color_override("default_color", Color(0.7, 0.9, 0.7, 1))
	console_panel.add_child(output_label)

	# 输入框
	input_line = LineEdit.new()
	input_line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	input_line.offset_top = -22
	input_line.offset_bottom = -2
	input_line.offset_left = 4
	input_line.offset_right = -4
	input_line.placeholder_text = ""
	input_line.add_theme_font_size_override("font_size", 14)

	var input_style: StyleBoxFlat = StyleBoxFlat.new()
	input_style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	input_style.border_width_left = 2
	input_style.border_width_right = 2
	input_style.border_width_top = 2
	input_style.border_width_bottom = 2
	input_style.border_color = Color(0.3, 0.6, 1.0, 0.6)
	input_style.content_margin_left = 6
	input_style.content_margin_right = 6
	input_line.add_theme_stylebox_override("normal", input_style)
	input_line.add_theme_stylebox_override("focus", input_style)

	input_line.text_submitted.connect(_on_text_submitted)
	console_panel.add_child(input_line)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# ~ 键切换控制台
		if event.keycode == KEY_QUOTELEFT:
			toggle_console()
			get_viewport().set_input_as_handled()
			return
		# 控制台打开时，ESC 关闭控制台
		if console_visible and event.keycode == KEY_ESCAPE:
			toggle_console()
			get_viewport().set_input_as_handled()
			return

	# 控制台打开时，拦截鼠标事件防止点击穿透到游戏
	# 不拦截键盘事件——LineEdit 需要接收字符输入
	if console_visible and event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func toggle_console() -> void:
	console_visible = not console_visible
	console_panel.visible = console_visible
	_notify_player(console_visible)
	if console_visible:
		input_line.grab_focus()
		input_line.clear()
	else:
		input_line.release_focus()


func _notify_player(open: bool) -> void:
	_find_player()
	if is_instance_valid(player) and "console_open" in player:
		player.console_open = open


func _on_text_submitted(text: String) -> void:
	var cmd: String = text.strip_edges()
	input_line.clear()
	if cmd.is_empty():
		return

	# 直接解析指令，不需要 / 前缀
	_execute_command(cmd)


func _execute_command(cmd: String) -> void:
	var parts: PackedStringArray = cmd.split(" ", false)
	var command: String = parts[0].to_lower() if parts.size() > 0 else ""

	match command:
		"god":
			_cmd_god()
		"jx", "setkills", "set_kills":
			_cmd_set_kills(parts)
		_:
			_print_text("[color=#ff6666]未知指令: %s[/color]" % command)


func _cmd_set_kills(parts: PackedStringArray) -> void:
	if parts.size() < 2:
		_print_text("[color=#ff6666]用法: jx <数字>[/color]")
		return
	var value: int = parts[1].to_int()
	if value < 0:
		_print_text("[color=#ff6666]击杀数不能为负[/color]")
		return
	var parent = get_parent()
	if parent and parent.has_method("set_kills"):
		parent.set_kills(value)
		_print_text("[color=#66ff66]OK - 击杀数已设为 %d[/color]" % value)
	else:
		_print_text("[color=#ff6666]当前场景不支持修改击杀数[/color]")


func _cmd_god() -> void:
	_find_player()
	if not is_instance_valid(player):
		_print_text("[color=#ff6666]未找到玩家[/color]")
		return

	player.god_mode = not player.god_mode
	_print_text("[color=#66ff66]OK[/color]")


func _print_text(text: String) -> void:
	output_label.append_text(text + "\n")


func _find_player() -> void:
	if is_instance_valid(player):
		return
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
