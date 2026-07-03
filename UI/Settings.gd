extends Control

# =============================================================================
# 设置界面控制器（多语言版）
# 用法：调用方 instantiate() 后 add_child()，设置 on_close_callback 回调
# =============================================================================

# 调用方设置的关闭回调（替代 signal，更可靠）
var on_close_callback: Callable = Callable()

@onready var tab_container: TabContainer = $TabContainer
@onready var back_btn: Button = $BackBtn

# 视频标签引用
@onready var res_label: Label = $TabContainer/Video/ResolutionLabel
@onready var resolution_opt: OptionButton = $TabContainer/Video/ResolutionOpt
@onready var fullscreen_chk: CheckBox = $TabContainer/Video/FullscreenChk
@onready var vsync_chk: CheckBox = $TabContainer/Video/VsyncChk
@onready var fps_label: Label = $TabContainer/Video/FPSLabel
@onready var fps_limit_opt: OptionButton = $TabContainer/Video/FPSLimitOpt

# 音频
@onready var master_slider: HSlider = $TabContainer/Audio/MasterSlider
@onready var bgm_slider: HSlider = $TabContainer/Audio/BGMSlider
@onready var sfx_slider: HSlider = $TabContainer/Audio/SFXSlider
@onready var master_label: Label = $TabContainer/Audio/MasterLabel
@onready var bgm_label: Label = $TabContainer/Audio/BGMLabel
@onready var sfx_label: Label = $TabContainer/Audio/SFXLabel

# 控制 + 按键绑定
@onready var sensitivity_slider: HSlider = $TabContainer/Controls/SensitivitySlider
@onready var invert_y_chk: CheckBox = $TabContainer/Controls/InvertYChk
@onready var sens_label: Label = $TabContainer/Controls/SensLabel
@onready var key_bindings_label: Label = $TabContainer/Controls/KeyBindingsLabel
@onready var key_bindings_container: VBoxContainer = $TabContainer/Controls/KeyBindings

# 按键绑定数据结构
var action_list: Array = ["move_up", "move_down", "move_left", "move_right", "shoot", "reload", "weapon_1", "weapon_2", "grenade"]
var binding_buttons: Dictionary = {}
var waiting_for_input: String = ""

# 游戏
@onready var crosshair_label: Label = $TabContainer/Game/CrosshairLabel
@onready var crosshair_opt: OptionButton = $TabContainer/Game/CrosshairOpt
@onready var crosshair_color_btn: ColorPickerButton = $TabContainer/Game/CrosshairColorBtn
@onready var crosshair_preview: Control = $TabContainer/Game/CrosshairPreview
@onready var show_fps_chk: CheckBox = $TabContainer/Game/ShowFPSChk
@onready var language_label: Label = $TabContainer/Game/LanguageLabel
@onready var language_opt: OptionButton = $TabContainer/Game/LanguageOpt

func _ready() -> void:
	back_btn.pressed.connect(_on_back_pressed)

	# 信号连接
	resolution_opt.item_selected.connect(_on_resolution_changed)
	fullscreen_chk.toggled.connect(_on_fullscreen_toggled)
	vsync_chk.toggled.connect(_on_vsync_toggled)
	fps_limit_opt.item_selected.connect(_on_fps_limit_changed)
	master_slider.value_changed.connect(_on_master_vol_changed)
	bgm_slider.value_changed.connect(_on_bgm_vol_changed)
	sfx_slider.value_changed.connect(_on_sfx_vol_changed)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	invert_y_chk.toggled.connect(_on_invert_y_toggled)
	crosshair_opt.item_selected.connect(_on_crosshair_changed)
	crosshair_color_btn.color_changed.connect(_on_crosshair_color_changed)
	show_fps_chk.toggled.connect(_on_show_fps_toggled)
	language_opt.item_selected.connect(_on_language_changed)

	if crosshair_preview:
		crosshair_preview.draw.connect(_on_crosshair_preview_draw)

	_apply_language()
	_build_key_binding_ui()
	GameSettings.apply_all_settings()
	load_current_settings()

	# 给所有按钮添加点击音效
	_connect_click_sounds(self)

func _connect_click_sounds(node: Node) -> void:
	for child in node.get_children():
		_connect_click_sounds(child)
		if child is Button:
			child.pressed.connect(UIAudio.play_click)

func _apply_language() -> void:
	# 标签页名称
	tab_container.set_tab_title(0, GameSettings.t("video_tab"))
	tab_container.set_tab_title(1, GameSettings.t("audio_tab"))
	tab_container.set_tab_title(2, GameSettings.t("controls_tab"))
	tab_container.set_tab_title(3, GameSettings.t("gameplay_tab"))

	# 视频标签
	res_label.text = GameSettings.t("resolution")
	fullscreen_chk.text = GameSettings.t("fullscreen")
	vsync_chk.text = GameSettings.t("vsync")
	fps_label.text = GameSettings.t("fps_limit")

	# 音频标签
	_update_audio_labels()

	# 控制标签
	sens_label.text = GameSettings.t("sensitivity") + ": %.1f" % sensitivity_slider.value
	invert_y_chk.text = GameSettings.t("invert_y")
	key_bindings_label.text = GameSettings.t("key_bindings")

	# 游戏标签
	crosshair_label.text = GameSettings.t("crosshair_style")
	show_fps_chk.text = GameSettings.t("show_fps")
	language_label.text = GameSettings.t("language")
	back_btn.text = GameSettings.t("back")

	# 下拉选项（需要清除重建）
	var prev_res: int = resolution_opt.selected
	resolution_opt.clear()
	resolution_opt.add_item("1280 x 720", 0)
	resolution_opt.add_item("1366 x 768", 1)
	resolution_opt.add_item("1920 x 1080", 2)
	resolution_opt.add_item("2560 x 1440", 3)
	resolution_opt.selected = prev_res

	var prev_fps: int = fps_limit_opt.selected
	fps_limit_opt.clear()
	fps_limit_opt.add_item(GameSettings.t("no_limit"), 0)
	fps_limit_opt.add_item("60 FPS", 60)
	fps_limit_opt.add_item("120 FPS", 120)
	fps_limit_opt.add_item("144 FPS", 144)
	fps_limit_opt.add_item("240 FPS", 240)
	fps_limit_opt.selected = prev_fps

	var prev_ch: int = crosshair_opt.selected
	crosshair_opt.clear()
	crosshair_opt.add_item(GameSettings.t("crosshair_cross"), 0)
	crosshair_opt.add_item(GameSettings.t("crosshair_dot"), 1)
	crosshair_opt.add_item(GameSettings.t("crosshair_ring"), 2)
	crosshair_opt.selected = prev_ch

	language_opt.clear()
	language_opt.add_item("中文", 0)
	language_opt.add_item("English", 1)
	language_opt.selected = GameSettings.get_language()

	# 刷新按键绑定UI
	_update_key_binding_labels()
	_load_key_binding_ui()

func _build_key_binding_ui() -> void:
	if not key_bindings_container:
		return
	for child in key_bindings_container.get_children():
		child.queue_free()
	await get_tree().process_frame

	for action in action_list:
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label: Label = Label.new()
		label.text = GameSettings.t(action)
		label.custom_minimum_size.x = 120
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)

		var btn: Button = Button.new()
		btn.custom_minimum_size.x = 160
		btn.text = _get_action_key_text(action)
		btn.pressed.connect(_on_binding_btn_pressed.bind(action))
		btn.pressed.connect(UIAudio.play_click)
		hbox.add_child(btn)
		binding_buttons[action] = btn

		key_bindings_container.add_child(hbox)

func _on_binding_btn_pressed(action: String) -> void:
	waiting_for_input = action
	var btn: Button = binding_buttons.get(action, null)
	if btn:
		btn.text = GameSettings.t("press_key")

func _input(event: InputEvent) -> void:
	if waiting_for_input.is_empty():
		return
	if event is InputEventKey and event.pressed:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_ESCAPE:
			waiting_for_input = ""
			_load_key_binding_ui()
			return
		InputMap.action_erase_events(waiting_for_input)
		InputMap.action_add_event(waiting_for_input, key_event)
		GameSettings.set_value("controls", "key_" + waiting_for_input, key_event.keycode)
		waiting_for_input = ""
		_load_key_binding_ui()

func _load_key_binding_ui() -> void:
	for action in action_list:
		var btn: Button = binding_buttons.get(action, null)
		if btn:
			btn.text = _get_action_key_text(action)

func _update_key_binding_labels() -> void:
	if not key_bindings_container:
		return
	for i in range(action_list.size()):
		if i < key_bindings_container.get_child_count():
			var hbox = key_bindings_container.get_child(i)
			if hbox is HBoxContainer and hbox.get_child_count() > 0:
				var label = hbox.get_child(0)
				if label is Label:
					label.text = GameSettings.t(action_list[i])

func _get_action_key_text(action: String) -> String:
	var evs: Array = InputMap.action_get_events(action)
	if evs.is_empty():
		return GameSettings.t("not_set")
	var ev = evs[0]
	if ev is InputEventKey:
		return OS.get_keycode_string(ev.keycode)
	elif ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return GameSettings.t("mouse_left")
			MOUSE_BUTTON_RIGHT: return GameSettings.t("mouse_right")
			MOUSE_BUTTON_MIDDLE: return GameSettings.t("mouse_middle")
			_: return "Mouse %d" % ev.button_index
	return "?"

func _on_crosshair_preview_draw() -> void:
	if not crosshair_preview:
		return
	var style: int = crosshair_opt.selected
	var col: Color = crosshair_color_btn.color
	var center: Vector2 = crosshair_preview.size * 0.5
	var draw_size: float = 30.0

	match style:
		0:
			crosshair_preview.draw_line(Vector2(center.x - draw_size, center.y), Vector2(center.x - 6, center.y), col, 2.0)
			crosshair_preview.draw_line(Vector2(center.x + 6, center.y), Vector2(center.x + draw_size, center.y), col, 2.0)
			crosshair_preview.draw_line(Vector2(center.x, center.y - draw_size), Vector2(center.x, center.y - 6), col, 2.0)
			crosshair_preview.draw_line(Vector2(center.x, center.y + 6), Vector2(center.x, center.y + draw_size), col, 2.0)
		1:
			crosshair_preview.draw_circle(center, 5.0, col)
		2:
			crosshair_preview.draw_arc(center, draw_size * 0.5, 0, TAU, 32, col, 2.0, true)

func load_current_settings() -> void:
	var res: String = GameSettings.get_value("video", "resolution", "1280x720")
	match res:
		"1280x720": resolution_opt.selected = 0
		"1366x768": resolution_opt.selected = 1
		"1920x1080": resolution_opt.selected = 2
		"2560x1440": resolution_opt.selected = 3
	fullscreen_chk.button_pressed = GameSettings.get_value("video", "fullscreen", false)
	vsync_chk.button_pressed = GameSettings.get_value("video", "vsync", true)
	var max_fps: int = GameSettings.get_value("video", "max_fps", 0)
	match max_fps:
		0: fps_limit_opt.selected = 0
		60: fps_limit_opt.selected = 1
		120: fps_limit_opt.selected = 2
		144: fps_limit_opt.selected = 3
		240: fps_limit_opt.selected = 4

	master_slider.value = GameSettings.get_value("audio", "master_volume", 0.8) * 100.0
	bgm_slider.value = GameSettings.get_value("audio", "bgm_volume", 0.6) * 100.0
	sfx_slider.value = GameSettings.get_value("audio", "sfx_volume", 0.8) * 100.0
	_update_audio_labels()

	sensitivity_slider.value = GameSettings.get_value("controls", "mouse_sensitivity", 1.0) * 50.0
	invert_y_chk.button_pressed = GameSettings.get_value("controls", "invert_y", false)
	sens_label.text = GameSettings.t("sensitivity") + ": %.1f" % sensitivity_slider.value

	crosshair_opt.selected = GameSettings.get_value("game", "crosshair_style", 0)
	crosshair_color_btn.color = GameSettings.get_value("game", "crosshair_color", Color(0, 1, 0, 1))
	show_fps_chk.button_pressed = GameSettings.get_value("game", "show_fps", true)
	language_opt.selected = GameSettings.get_language()

	_load_key_binding_ui()
	if crosshair_preview:
		crosshair_preview.queue_redraw()

func _on_back_pressed() -> void:
	if on_close_callback.is_valid():
		on_close_callback.call()
	else:
		# 保底：如果没有设置回调，直接退出到主菜单
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")

# ---- 视频 ----
func _on_resolution_changed(index: int) -> void:
	var res_str: String = ["1280x720", "1366x768", "1920x1080", "2560x1440"][index]
	GameSettings.set_value("video", "resolution", res_str)
	var parts: PackedStringArray = res_str.split("x")
	if parts.size() == 2:
		get_window().size = Vector2i(int(parts[0]), int(parts[1]))

func _on_fullscreen_toggled(on: bool) -> void:
	GameSettings.set_value("video", "fullscreen", on)
	get_window().mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED

func _on_vsync_toggled(on: bool) -> void:
	GameSettings.set_value("video", "vsync", on)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

func _on_fps_limit_changed(index: int) -> void:
	var fps: int = [0, 60, 120, 144, 240][index]
	GameSettings.set_value("video", "max_fps", fps)
	Engine.max_fps = fps

# ---- 音频 ----
func _on_master_vol_changed(val: float) -> void:
	var v: float = val / 100.0
	GameSettings.set_value("audio", "master_volume", v)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(v))
	_update_audio_labels()

func _on_bgm_vol_changed(val: float) -> void:
	var v: float = val / 100.0
	GameSettings.set_value("audio", "bgm_volume", v)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), linear_to_db(v))
	_update_audio_labels()

func _on_sfx_vol_changed(val: float) -> void:
	var v: float = val / 100.0
	GameSettings.set_value("audio", "sfx_volume", v)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(v))
	_update_audio_labels()

func _update_audio_labels() -> void:
	master_label.text = GameSettings.t("master_vol") + ": %.0f%%" % master_slider.value
	bgm_label.text = GameSettings.t("bgm_vol") + ": %.0f%%" % bgm_slider.value
	sfx_label.text = GameSettings.t("sfx_vol") + ": %.0f%%" % sfx_slider.value

# ---- 控制 ----
func _on_sensitivity_changed(val: float) -> void:
	GameSettings.set_value("controls", "mouse_sensitivity", val / 50.0)
	sens_label.text = GameSettings.t("sensitivity") + ": %.1f" % val

func _on_invert_y_toggled(on: bool) -> void:
	GameSettings.set_value("controls", "invert_y", on)

# ---- 游戏 ----
func _on_crosshair_changed(_index: int) -> void:
	GameSettings.set_value("game", "crosshair_style", crosshair_opt.selected)
	if crosshair_preview:
		crosshair_preview.queue_redraw()

func _on_crosshair_color_changed(color: Color) -> void:
	GameSettings.set_value("game", "crosshair_color", color)
	if crosshair_preview:
		crosshair_preview.queue_redraw()

func _on_show_fps_toggled(on: bool) -> void:
	GameSettings.set_value("game", "show_fps", on)

func _on_language_changed(index: int) -> void:
	GameSettings.set_language(index)
	_apply_language()
