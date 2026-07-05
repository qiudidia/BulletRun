extends Control
# =============================================================================
# 炫酷科技风主菜单
# 动态背景 + 发光按钮 + 立体卡片 + 动画效果
# =============================================================================

var start_btn: Button = null
var settings_btn: Button = null
var about_btn: Button = null
var loadout_btn: Button = null
var quit_btn: Button = null

var settings_instance: Control = null
var about_screen: Control = null
var mode_screen: Control = null

var title_time: float = 0.0
var bg_node: Control = null

var player_info_panel: PanelContainer = null
var player_avatar: Control = null
var player_name_label: Label = null
var player_level_label: Label = null
var player_xp_bar: ProgressBar = null
var player_xp_label: Label = null
var avatar_picker: Control = null

var menu_buttons: Array = []
var mode_cards: Array = []


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_create_dynamic_background()
	_create_main_menu()
	_create_mode_select_screen()
	_create_player_info_panel()
	_create_version_label()
	BGMManager.play_bgm()


func _create_dynamic_background() -> void:
	bg_node = Control.new()
	bg_node.name = "DynamicBG"
	bg_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg_script: GDScript = load("res://scripts/DynamicBackground.gd")
	bg_node.set_script(bg_script)
	add_child(bg_node)


func _create_main_menu() -> void:
	var main_container: VBoxContainer = VBoxContainer.new()
	main_container.name = "MainMenuContainer"
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_theme_constant_override("separation", 30)
	add_child(main_container)
	
	var title_vbox: VBoxContainer = VBoxContainer.new()
	title_vbox.name = "TitleArea"
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_vbox.add_theme_constant_override("separation", 8)
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_container.add_child(title_vbox)
	
	var title_glow: Label = Label.new()
	title_glow.name = "TitleGlow"
	title_glow.text = "BULLET RUN"
	title_glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_glow.add_theme_font_size_override("font_size", 72)
	title_glow.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0, 0.3))
	title_glow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_child(title_glow)
	
	var title_label: Label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "BULLET RUN"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_child(title_label)
	
	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "// TACTICAL COMBAT SIMULATOR //"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 0.8))
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_child(subtitle)
	
	var sep_hbox: HBoxContainer = HBoxContainer.new()
	sep_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sep_hbox.add_theme_constant_override("separation", 15)
	sep_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_child(sep_hbox)
	
	var left_line: ColorRect = ColorRect.new()
	left_line.custom_minimum_size = Vector2(120, 2)
	left_line.color = Color(0.3, 0.6, 1.0, 0.5)
	sep_hbox.add_child(left_line)
	
	var diamond: Label = Label.new()
	diamond.text = ">>"
	diamond.add_theme_font_size_override("font_size", 14)
	diamond.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	sep_hbox.add_child(diamond)
	
	var right_line: ColorRect = ColorRect.new()
	right_line.custom_minimum_size = Vector2(120, 2)
	right_line.color = Color(0.3, 0.6, 1.0, 0.5)
	sep_hbox.add_child(right_line)
	
	var btn_container: VBoxContainer = VBoxContainer.new()
	btn_container.name = "ButtonContainer"
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 12)
	btn_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_container.add_child(btn_container)
	
	start_btn = _create_glow_button("StartBtn", "start_game", "[>]", Color(0.2, 0.8, 0.5, 1.0))
	start_btn.pressed.connect(_on_start_pressed)
	btn_container.add_child(start_btn)
	
	loadout_btn = _create_glow_button("LoadoutBtn", "loadout", "[X]", Color(0.9, 0.6, 0.2, 1.0))
	loadout_btn.pressed.connect(_on_loadout_pressed)
	btn_container.add_child(loadout_btn)
	
	settings_btn = _create_glow_button("SettingsBtn", "settings", "[O]", Color(0.3, 0.6, 1.0, 1.0))
	settings_btn.pressed.connect(_on_settings_pressed)
	btn_container.add_child(settings_btn)
	
	about_btn = _create_glow_button("AboutBtn", "about_game", "[i]", Color(0.6, 0.4, 0.9, 1.0))
	about_btn.pressed.connect(_on_about_pressed)
	btn_container.add_child(about_btn)
	
	quit_btn = _create_glow_button("QuitBtn", "quit_game", "[X]", Color(0.9, 0.3, 0.3, 1.0))
	quit_btn.pressed.connect(_on_quit_pressed)
	btn_container.add_child(quit_btn)


func _create_glow_button(btn_name: String, text_key: String, icon: String, color: Color) -> Button:
	var btn: Button = Button.new()
	btn.name = btn_name
	btn.custom_minimum_size = Vector2(320, 56)
	btn.text = "  " + icon + "  " + GameSettings.t(text_key)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.8))
	
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	normal_style.border_color = color * 0.6
	normal_style.border_width_left = 3
	normal_style.border_width_right = 3
	normal_style.border_width_top = 1
	normal_style.border_width_bottom = 1
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	normal_style.content_margin_left = 20
	normal_style.content_margin_right = 20
	normal_style.content_margin_top = 12
	normal_style.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", normal_style)
	
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = color * 0.15 + Color(0.06, 0.08, 0.12, 0.9)
	hover_style.border_color = color
	hover_style.border_width_left = 3
	hover_style.border_width_right = 3
	hover_style.border_width_top = 2
	hover_style.border_width_bottom = 2
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	hover_style.content_margin_left = 20
	hover_style.content_margin_right = 20
	hover_style.content_margin_top = 12
	hover_style.content_margin_bottom = 12
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style: StyleBoxFlat = StyleBoxFlat.new()
	pressed_style.bg_color = color * 0.25 + Color(0.04, 0.06, 0.1, 0.9)
	pressed_style.border_color = color * 0.8
	pressed_style.border_width_left = 3
	pressed_style.border_width_right = 3
	pressed_style.border_width_top = 2
	pressed_style.border_width_bottom = 2
	pressed_style.corner_radius_top_left = 6
	pressed_style.corner_radius_top_right = 6
	pressed_style.corner_radius_bottom_left = 6
	pressed_style.corner_radius_bottom_right = 6
	pressed_style.content_margin_left = 20
	pressed_style.content_margin_right = 20
	pressed_style.content_margin_top = 13
	pressed_style.content_margin_bottom = 11
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	btn.pressed.connect(UIAudio.play_click)
	
	return btn


func _process(delta: float) -> void:
	title_time += delta
	
	var title_label: Label = get_node_or_null("MainMenuContainer/TitleArea/TitleLabel")
	var title_glow: Label = get_node_or_null("MainMenuContainer/TitleArea/TitleGlow")
	
	if title_label and title_glow:
		var s: float = 1.0 + sin(title_time * 2.0) * 0.02
		title_label.scale = Vector2(s, s)
		title_glow.scale = Vector2(s * 1.02, s * 1.02)
		
		var glow_op: float = 0.2 + sin(title_time * 1.5) * 0.1
		title_glow.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0, glow_op))


func _create_mode_select_screen() -> void:
	mode_screen = Control.new()
	mode_screen.name = "ModeSelectScreen"
	mode_screen.visible = false
	mode_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mode_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mode_screen)
	
	var bg_overlay: ColorRect = ColorRect.new()
	bg_overlay.name = "BGOverlay"
	bg_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_overlay.color = Color(0.02, 0.03, 0.06, 0.85)
	mode_screen.add_child(bg_overlay)
	
	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 40)
	mode_screen.add_child(main_vbox)
	
	var title_label: Label = Label.new()
	title_label.name = "ModeTitle"
	title_label.text = GameSettings.t("select_mode")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(title_label)
	
	var underline: ColorRect = ColorRect.new()
	underline.name = "Underline"
	underline.custom_minimum_size = Vector2(200, 3)
	underline.color = Color(0.3, 0.6, 1.0, 0.8)
	underline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.add_child(underline)
	
	var cards_hbox: HBoxContainer = HBoxContainer.new()
	cards_hbox.name = "CardsRow"
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 40)
	cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(cards_hbox)
	
	var zombie_card: PanelContainer = _create_mode_card(
		"ZombieCard",
		"[Z]",
		"zombie_mode",
		"zombie_mode_desc",
		Color(0.2, 0.8, 0.4, 1.0)
	)
	zombie_card.get_node("CardVBox/PlayBtn").pressed.connect(_on_zombie_mode_pressed)
	cards_hbox.add_child(zombie_card)
	
	var bot_card: PanelContainer = _create_mode_card(
		"BotCard",
		"[B]",
		"bot_mode",
		"bot_mode_desc",
		Color(0.9, 0.3, 0.3, 1.0)
	)
	bot_card.get_node("CardVBox/PlayBtn").pressed.connect(_on_bot_mode_pressed)
	cards_hbox.add_child(bot_card)
	
	var mp_card: PanelContainer = _create_mode_card(
		"MultiplayerCard",
		"[M]",
		"multiplayer_mode",
		"multiplayer_desc",
		Color(0.2, 0.6, 1.0, 1.0)
	)
	mp_card.get_node("CardVBox/PlayBtn").pressed.connect(_on_multiplayer_pressed)
	cards_hbox.add_child(mp_card)
	
	var back_btn: Button = Button.new()
	back_btn.name = "BackBtn"
	back_btn.custom_minimum_size = Vector2(200, 45)
	back_btn.text = "<-  " + GameSettings.t("back")
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var back_style: StyleBoxFlat = StyleBoxFlat.new()
	back_style.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	back_style.border_color = Color(0.4, 0.5, 0.7, 0.6)
	back_style.border_width_left = 2
	back_style.border_width_right = 2
	back_style.border_width_top = 1
	back_style.border_width_bottom = 1
	back_style.corner_radius_top_left = 6
	back_style.corner_radius_top_right = 6
	back_style.corner_radius_bottom_left = 6
	back_style.corner_radius_bottom_right = 6
	back_style.content_margin_left = 20
	back_style.content_margin_right = 20
	back_style.content_margin_top = 10
	back_style.content_margin_bottom = 10
	back_btn.add_theme_stylebox_override("normal", back_style)
	
	var back_hover: StyleBoxFlat = StyleBoxFlat.new()
	back_hover.bg_color = Color(0.12, 0.16, 0.22, 0.9)
	back_hover.border_color = Color(0.5, 0.7, 1.0, 0.8)
	back_hover.border_width_left = 2
	back_hover.border_width_right = 2
	back_hover.border_width_top = 2
	back_hover.border_width_bottom = 2
	back_hover.corner_radius_top_left = 6
	back_hover.corner_radius_top_right = 6
	back_hover.corner_radius_bottom_left = 6
	back_hover.corner_radius_bottom_right = 6
	back_hover.content_margin_left = 20
	back_hover.content_margin_right = 20
	back_hover.content_margin_top = 10
	back_hover.content_margin_bottom = 10
	back_btn.add_theme_stylebox_override("hover", back_hover)
	
	back_btn.pressed.connect(_on_back_pressed)
	back_btn.pressed.connect(UIAudio.play_click)
	main_vbox.add_child(back_btn)


func _create_mode_card(card_name: String, icon: String, title_key: String, desc_key: String, color: Color) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = card_name
	card.custom_minimum_size = Vector2(280, 380)
	
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.05, 0.07, 0.1, 0.95)
	normal_style.border_color = color * 0.4
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 4
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	normal_style.content_margin_left = 20
	normal_style.content_margin_right = 20
	normal_style.content_margin_top = 25
	normal_style.content_margin_bottom = 25
	card.add_theme_stylebox_override("panel", normal_style)
	
	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.name = "CardVBox"
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 16)
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(card_vbox)
	
	var icon_label: Label = Label.new()
	icon_label.name = "Icon"
	icon_label.text = icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 64)
	icon_label.add_theme_color_override("font_color", color)
	icon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(icon_label)
	
	var title_label: Label = Label.new()
	title_label.name = "Title"
	title_label.text = GameSettings.t(title_key)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", color)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(title_label)
	
	var sep: HSeparator = HSeparator.new()
	sep.modulate.a = 0.3
	card_vbox.add_child(sep)
	
	var desc_label: Label = Label.new()
	desc_label.name = "Desc"
	desc_label.text = GameSettings.t(desc_key)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8, 1.0))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(desc_label)
	
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	card_vbox.add_child(spacer)
	
	var play_btn: Button = Button.new()
	play_btn.name = "PlayBtn"
	play_btn.custom_minimum_size = Vector2(0, 50)
	play_btn.text = "[>]  " + GameSettings.t("start_game")
	play_btn.add_theme_font_size_override("font_size", 18)
	play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var btn_normal: StyleBoxFlat = StyleBoxFlat.new()
	btn_normal.bg_color = color * 0.2
	btn_normal.border_color = color * 0.7
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 1
	btn_normal.border_width_bottom = 2
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_left = 15
	btn_normal.content_margin_right = 15
	btn_normal.content_margin_top = 10
	btn_normal.content_margin_bottom = 10
	play_btn.add_theme_stylebox_override("normal", btn_normal)
	
	var btn_hover: StyleBoxFlat = StyleBoxFlat.new()
	btn_hover.bg_color = color * 0.35
	btn_hover.border_color = color
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_top = 2
	btn_hover.border_width_bottom = 2
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6
	btn_hover.content_margin_left = 15
	btn_hover.content_margin_right = 15
	btn_hover.content_margin_top = 10
	btn_hover.content_margin_bottom = 10
	play_btn.add_theme_stylebox_override("hover", btn_hover)
	
	play_btn.pressed.connect(UIAudio.play_click)
	card_vbox.add_child(play_btn)
	
	return card


func _on_start_pressed() -> void:
	if mode_screen:
		mode_screen.visible = true


func _on_settings_pressed() -> void:
	if settings_instance:
		return
	var settings_scene: PackedScene = load("res://UI/settings.tscn")
	if not settings_scene:
		return
	settings_instance = settings_scene.instantiate()
	settings_instance.on_close_callback = func(): _on_settings_closed()
	add_child(settings_instance)


func _on_settings_closed() -> void:
	if settings_instance:
		settings_instance.queue_free()
		settings_instance = null
	_apply_language()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_loadout_pressed() -> void:
	BGMManager.stop_bgm()
	get_tree().change_scene_to_file("res://scenes/loadout/LoadoutMenu.tscn")


func _on_bot_mode_pressed() -> void:
	BGMManager.stop_bgm()
	get_tree().change_scene_to_file("res://scenes/game/bot_mode/bot_game.tscn")


func _on_zombie_mode_pressed() -> void:
	BGMManager.stop_bgm()
	get_tree().change_scene_to_file("res://scenes/game/zombie_mode/zombie_game.tscn")


func _on_multiplayer_pressed() -> void:
	BGMManager.stop_bgm()
	get_tree().change_scene_to_file("res://scenes/multiplayer/Lobby.tscn")


func _on_back_pressed() -> void:
	if mode_screen:
		mode_screen.visible = false


func _on_about_pressed() -> void:
	if not about_screen:
		_create_about_screen()
	get_node("MainMenuContainer").visible = false
	about_screen.visible = true


func _create_about_screen() -> void:
	about_screen = Control.new()
	about_screen.name = "AboutScreen"
	about_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var bg: ColorRect = ColorRect.new()
	bg.name = "BG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.08, 0.95)
	about_screen.add_child(bg)
	
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	about_screen.add_child(scroll)
	
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 60)
	margin.add_theme_constant_override("margin_right", 60)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	scroll.add_child(margin)
	
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 24)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	
	var game_title: Label = Label.new()
	game_title.name = "GameTitle"
	game_title.text = "BULLET RUN"
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_title.add_theme_font_size_override("font_size", 48)
	game_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
	game_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(game_title)
	
	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = GameSettings.t("about_subtitle")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.9))
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(subtitle)
	
	var sep1: HSeparator = HSeparator.new()
	sep1.modulate.a = 0.3
	content.add_child(sep1)
	
	var studio_vbox: VBoxContainer = VBoxContainer.new()
	studio_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	studio_vbox.add_theme_constant_override("separation", 4)
	studio_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(studio_vbox)
	
	var studio_label: Label = Label.new()
	studio_label.text = GameSettings.t("about_studio_label")
	studio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	studio_label.add_theme_font_size_override("font_size", 14)
	studio_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	studio_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	studio_vbox.add_child(studio_label)
	
	var studio_name: Label = Label.new()
	studio_name.text = "Vee Studio"
	studio_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	studio_name.add_theme_font_size_override("font_size", 32)
	studio_name.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0, 1.0))
	studio_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	studio_vbox.add_child(studio_name)
	
	var founder_hbox: HBoxContainer = HBoxContainer.new()
	founder_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	founder_hbox.add_theme_constant_override("separation", 20)
	content.add_child(founder_hbox)
	
	var avatar_rect: TextureRect = TextureRect.new()
	avatar_rect.custom_minimum_size = Vector2(100, 100)
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists("res://assets/qiudidia.jpg"):
		avatar_rect.texture = load("res://assets/qiudidia.jpg")
	founder_hbox.add_child(avatar_rect)
	
	var founder_info: VBoxContainer = VBoxContainer.new()
	founder_info.alignment = BoxContainer.ALIGNMENT_CENTER
	founder_info.add_theme_constant_override("separation", 4)
	founder_hbox.add_child(founder_info)
	
	var founder_label: Label = Label.new()
	founder_label.text = GameSettings.t("about_founder_label")
	founder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	founder_label.add_theme_font_size_override("font_size", 14)
	founder_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	founder_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	founder_info.add_child(founder_label)
	
	var founder_name: Label = Label.new()
	founder_name.text = "qiudidia"
	founder_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	founder_name.add_theme_font_size_override("font_size", 24)
	founder_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 1.0))
	founder_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	founder_info.add_child(founder_name)
	
	var sep2: HSeparator = HSeparator.new()
	sep2.modulate.a = 0.3
	content.add_child(sep2)
	
	var modes_title: Label = Label.new()
	modes_title.text = GameSettings.t("about_modes_title")
	modes_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modes_title.add_theme_font_size_override("font_size", 28)
	modes_title.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4, 1))
	modes_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(modes_title)
	
	var z_card: PanelContainer = _create_about_card(
		GameSettings.t("about_zombie_title"),
		GameSettings.t("about_zombie_desc"),
		Color(0.2, 0.8, 0.4, 1.0)
	)
	content.add_child(z_card)
	
	var b_card: PanelContainer = _create_about_card(
		GameSettings.t("about_bot_title"),
		GameSettings.t("about_bot_desc"),
		Color(0.9, 0.3, 0.3, 1.0)
	)
	content.add_child(b_card)
	
	var m_card: PanelContainer = _create_about_card(
		GameSettings.t("about_multiplayer_title"),
		GameSettings.t("about_multiplayer_desc"),
		Color(0.3, 0.6, 1.0, 1.0)
	)
	content.add_child(m_card)
	
	var sep3: HSeparator = HSeparator.new()
	sep3.modulate.a = 0.3
	content.add_child(sep3)
	
	var back_btn: Button = Button.new()
	back_btn.custom_minimum_size = Vector2(200, 45)
	back_btn.text = "<-  " + GameSettings.t("back")
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var back_style: StyleBoxFlat = StyleBoxFlat.new()
	back_style.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	back_style.border_color = Color(0.4, 0.5, 0.7, 0.6)
	back_style.border_width_left = 2
	back_style.border_width_right = 2
	back_style.border_width_top = 1
	back_style.border_width_bottom = 1
	back_style.corner_radius_top_left = 6
	back_style.corner_radius_top_right = 6
	back_style.corner_radius_bottom_left = 6
	back_style.corner_radius_bottom_right = 6
	back_style.content_margin_left = 20
	back_style.content_margin_right = 20
	back_style.content_margin_top = 10
	back_style.content_margin_bottom = 10
	back_btn.add_theme_stylebox_override("normal", back_style)
	
	var back_hover: StyleBoxFlat = StyleBoxFlat.new()
	back_hover.bg_color = Color(0.12, 0.16, 0.22, 0.9)
	back_hover.border_color = Color(0.5, 0.7, 1.0, 0.8)
	back_hover.border_width_left = 2
	back_hover.border_width_right = 2
	back_hover.border_width_top = 2
	back_hover.border_width_bottom = 2
	back_hover.corner_radius_top_left = 6
	back_hover.corner_radius_top_right = 6
	back_hover.corner_radius_bottom_left = 6
	back_hover.corner_radius_bottom_right = 6
	back_hover.content_margin_left = 20
	back_hover.content_margin_right = 20
	back_hover.content_margin_top = 10
	back_hover.content_margin_bottom = 10
	back_btn.add_theme_stylebox_override("hover", back_hover)
	
	back_btn.pressed.connect(_on_about_back_pressed)
	back_btn.pressed.connect(UIAudio.play_click)
	content.add_child(back_btn)
	
	add_child(about_screen)


func _create_about_card(title: String, desc: String, color: Color) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	card_style.border_color = color * 0.5
	card_style.border_width_left = 3
	card_style.border_width_right = 1
	card_style.border_width_top = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.content_margin_top = 14
	card_style.content_margin_bottom = 14
	card_style.content_margin_left = 18
	card_style.content_margin_right = 18
	card.add_theme_stylebox_override("panel", card_style)
	
	var card_vbox: VBoxContainer = VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(card_vbox)
	
	var t_label: Label = Label.new()
	t_label.text = title
	t_label.add_theme_font_size_override("font_size", 20)
	t_label.add_theme_color_override("font_color", color)
	t_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(t_label)
	
	var d_label: Label = Label.new()
	d_label.text = desc
	d_label.add_theme_font_size_override("font_size", 14)
	d_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	d_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(d_label)
	
	return card


func _on_about_back_pressed() -> void:
	if about_screen:
		about_screen.visible = false
	get_node("MainMenuContainer").visible = true


func _apply_language() -> void:
	if start_btn:
		start_btn.text = "  [>]  " + GameSettings.t("start_game")
	if settings_btn:
		settings_btn.text = "  [O]  " + GameSettings.t("settings")
	if about_btn:
		about_btn.text = "  [i]  " + GameSettings.t("about_game")
	if loadout_btn:
		loadout_btn.text = "  [X]  " + GameSettings.t("loadout")
	if quit_btn:
		quit_btn.text = "  [X]  " + GameSettings.t("quit_game")
	
	if mode_screen:
		var title_lbl: Label = mode_screen.get_node_or_null("MainVBox/ModeTitle")
		if title_lbl:
			title_lbl.text = GameSettings.t("select_mode")
		
		var zombie_vbox = mode_screen.get_node_or_null("MainVBox/CardsRow/ZombieCard/CardVBox")
		if zombie_vbox:
			var zt: Label = zombie_vbox.get_node_or_null("Title")
			var zd: Label = zombie_vbox.get_node_or_null("Desc")
			var zb: Button = zombie_vbox.get_node_or_null("PlayBtn")
			if zt:
				zt.text = GameSettings.t("zombie_mode")
			if zd:
				zd.text = GameSettings.t("zombie_mode_desc")
			if zb:
				zb.text = "[>]  " + GameSettings.t("start_game")
		
		var bot_vbox = mode_screen.get_node_or_null("MainVBox/CardsRow/BotCard/CardVBox")
		if bot_vbox:
			var bt: Label = bot_vbox.get_node_or_null("Title")
			var bd: Label = bot_vbox.get_node_or_null("Desc")
			var bb: Button = bot_vbox.get_node_or_null("PlayBtn")
			if bt:
				bt.text = GameSettings.t("bot_mode")
			if bd:
				bd.text = GameSettings.t("bot_mode_desc")
			if bb:
				bb.text = "[>]  " + GameSettings.t("start_game")
		
		var mp_vbox = mode_screen.get_node_or_null("MainVBox/CardsRow/MultiplayerCard/CardVBox")
		if mp_vbox:
			var mt: Label = mp_vbox.get_node_or_null("Title")
			var md: Label = mp_vbox.get_node_or_null("Desc")
			var mb: Button = mp_vbox.get_node_or_null("PlayBtn")
			if mt:
				mt.text = GameSettings.t("multiplayer_mode")
			if md:
				md.text = GameSettings.t("multiplayer_desc")
			if mb:
				mb.text = "[>]  " + GameSettings.t("start_game")
		
		var back_btn: Button = mode_screen.get_node_or_null("MainVBox/BackBtn")
		if back_btn:
			back_btn.text = "<-  " + GameSettings.t("back")


func _create_player_info_panel() -> void:
	player_info_panel = PanelContainer.new()
	player_info_panel.name = "PlayerInfoPanel"
	player_info_panel.anchor_left = 0.0
	player_info_panel.anchor_top = 0.0
	player_info_panel.anchor_right = 0.0
	player_info_panel.anchor_bottom = 0.0
	player_info_panel.offset_left = 20
	player_info_panel.offset_top = 20
	player_info_panel.offset_right = 260
	player_info_panel.offset_bottom = 120
	
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.04, 0.06, 0.1, 0.85)
	bg_style.border_color = Color(0.3, 0.6, 1.0, 0.5)
	bg_style.border_width_left = 2
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 2
	bg_style.corner_radius_top_left = 10
	bg_style.corner_radius_top_right = 10
	bg_style.corner_radius_bottom_left = 10
	bg_style.corner_radius_bottom_right = 10
	bg_style.content_margin_top = 12
	bg_style.content_margin_bottom = 12
	bg_style.content_margin_left = 14
	bg_style.content_margin_right = 14
	player_info_panel.add_theme_stylebox_override("panel", bg_style)
	
	var content: HBoxContainer = HBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	player_info_panel.add_child(content)
	
	var avatar_script: GDScript = load("res://scripts/AvatarIcon.gd")
	player_avatar = Control.new()
	player_avatar.name = "AvatarIcon"
	player_avatar.set_script(avatar_script)
	player_avatar.avatar_id = GameSettings.get_avatar()
	player_avatar.avatar_size = Vector2(48, 48)
	player_avatar.avatar_clicked.connect(_on_avatar_clicked)
	content.add_child(player_avatar)
	
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.name = "InfoVBox"
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 4)
	content.add_child(info_vbox)
	
	var name_level_hbox: HBoxContainer = HBoxContainer.new()
	name_level_hbox.name = "NameLevelRow"
	name_level_hbox.add_theme_constant_override("separation", 8)
	info_vbox.add_child(name_level_hbox)
	
	player_name_label = Label.new()
	player_name_label.name = "PlayerName"
	player_name_label.add_theme_font_size_override("font_size", 17)
	player_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 1.0))
	name_level_hbox.add_child(player_name_label)
	
	player_level_label = Label.new()
	player_level_label.name = "PlayerLevel"
	player_level_label.add_theme_font_size_override("font_size", 15)
	player_level_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 1.0))
	name_level_hbox.add_child(player_level_label)
	
	player_xp_bar = ProgressBar.new()
	player_xp_bar.name = "XPBar"
	player_xp_bar.custom_minimum_size = Vector2(140, 12)
	player_xp_bar.show_percentage = false
	player_xp_bar.value = GameSettings.get_level_progress() * 100.0
	
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.7, 1.0, 0.9)
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	player_xp_bar.add_theme_stylebox_override("fill", fill_style)
	
	var bg_bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_bar_style.bg_color = Color(0.12, 0.14, 0.18, 1)
	bg_bar_style.corner_radius_top_left = 4
	bg_bar_style.corner_radius_top_right = 4
	bg_bar_style.corner_radius_bottom_left = 4
	bg_bar_style.corner_radius_bottom_right = 4
	player_xp_bar.add_theme_stylebox_override("background", bg_bar_style)
	info_vbox.add_child(player_xp_bar)
	
	player_xp_label = Label.new()
	player_xp_label.name = "XPLabel"
	player_xp_label.add_theme_font_size_override("font_size", 11)
	player_xp_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	info_vbox.add_child(player_xp_label)
	
	add_child(player_info_panel)
	_refresh_player_info()


func _refresh_player_info() -> void:
	if not player_info_panel:
		return
	var p_name: String = GameSettings.get_player_name()
	var p_level: int = GameSettings.get_level()
	var p_xp: int = GameSettings.get_xp()
	var p_needed: int = GameSettings.xp_for_level(p_level)
	var p_avatar_id: int = GameSettings.get_avatar()
	
	player_name_label.text = p_name
	player_level_label.text = GameSettings.t("level_display") % [p_level, GameSettings.get_rank_name(p_level)]
	if p_level >= GameSettings.MAX_LEVEL:
		player_xp_label.text = GameSettings.t("max_level")
	else:
		player_xp_label.text = GameSettings.t("xp_display") % [p_xp, p_needed]
	player_xp_bar.value = GameSettings.get_level_progress() * 100.0
	
	if player_avatar and player_avatar.has_method("set_avatar"):
		player_avatar.set_avatar(p_avatar_id)


func _on_avatar_clicked() -> void:
	if avatar_picker and is_instance_valid(avatar_picker):
		avatar_picker.queue_free()
		avatar_picker = null
		return
	_create_avatar_picker()


func _create_avatar_picker() -> void:
	var total_avatars: int = 16
	var cols: int = 4
	var rows: int = 4
	var cell_size: float = 64.0
	var padding: float = 8.0
	
	avatar_picker = PanelContainer.new()
	avatar_picker.name = "AvatarPicker"
	avatar_picker.anchor_left = 0.0
	avatar_picker.anchor_top = 0.0
	avatar_picker.anchor_right = 0.0
	avatar_picker.anchor_bottom = 0.0
	avatar_picker.offset_left = 20
	avatar_picker.offset_top = 125
	avatar_picker.offset_right = 20 + cols * (cell_size + padding) + 28
	avatar_picker.offset_bottom = 125 + rows * (cell_size + padding) + 40
	
	var picker_style: StyleBoxFlat = StyleBoxFlat.new()
	picker_style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	picker_style.border_color = Color(0.4, 0.6, 1.0, 0.7)
	picker_style.border_width_left = 2
	picker_style.border_width_right = 2
	picker_style.border_width_top = 2
	picker_style.border_width_bottom = 2
	picker_style.corner_radius_top_left = 10
	picker_style.corner_radius_top_right = 10
	picker_style.corner_radius_bottom_left = 10
	picker_style.corner_radius_bottom_right = 10
	picker_style.content_margin_top = 10
	picker_style.content_margin_bottom = 10
	picker_style.content_margin_left = 12
	picker_style.content_margin_right = 12
	avatar_picker.add_theme_stylebox_override("panel", picker_style)
	
	var grid: GridContainer = GridContainer.new()
	grid.name = "AvatarGrid"
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", int(padding))
	grid.add_theme_constant_override("v_separation", int(padding))
	avatar_picker.add_child(grid)
	
	var avatar_script: GDScript = load("res://scripts/AvatarIcon.gd")
	var current_avatar: int = GameSettings.get_avatar()
	
	for i in range(total_avatars):
		var cell: PanelContainer = PanelContainer.new()
		cell.name = "AvatarCell_" + str(i)
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
		
		var cell_style: StyleBoxFlat = StyleBoxFlat.new()
		if i == current_avatar:
			cell_style.bg_color = Color(0.15, 0.25, 0.5, 0.7)
			cell_style.border_color = Color(0.4, 0.7, 1.0, 1.0)
			cell_style.border_width_bottom = 2
			cell_style.border_width_top = 2
			cell_style.border_width_left = 2
			cell_style.border_width_right = 2
		else:
			cell_style.bg_color = Color(0.08, 0.1, 0.14, 0.6)
			cell_style.border_color = Color(0.25, 0.3, 0.4, 0.5)
			cell_style.border_width_bottom = 1
			cell_style.border_width_top = 1
			cell_style.border_width_left = 1
			cell_style.border_width_right = 1
		cell_style.corner_radius_top_left = 6
		cell_style.corner_radius_top_right = 6
		cell_style.corner_radius_bottom_left = 6
		cell_style.corner_radius_bottom_right = 6
		cell.add_theme_stylebox_override("panel", cell_style)
		
		var avatar_node: Control = Control.new()
		avatar_node.name = "Avatar_" + str(i)
		avatar_node.set_script(avatar_script)
		avatar_node.avatar_id = i
		avatar_node.avatar_size = Vector2(cell_size - 10, cell_size - 10)
		cell.add_child(avatar_node)
		
		var select_btn: Button = Button.new()
		select_btn.name = "SelectBtn_" + str(i)
		select_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		select_btn.add_theme_font_size_override("font_size", 0)
		
		var sel_style: StyleBoxFlat = StyleBoxFlat.new()
		sel_style.bg_color = Color(0, 0, 0, 0)
		sel_style.border_width_bottom = 0
		sel_style.border_width_top = 0
		sel_style.border_width_left = 0
		sel_style.border_width_right = 0
		select_btn.add_theme_stylebox_override("normal", sel_style)
		
		var sel_hover: StyleBoxFlat = StyleBoxFlat.new()
		sel_hover.bg_color = Color(0.2, 0.35, 0.6, 0.3)
		sel_hover.border_width_bottom = 0
		sel_hover.border_width_top = 0
		sel_hover.border_width_left = 0
		sel_hover.border_width_right = 0
		select_btn.add_theme_stylebox_override("hover", sel_hover)
		
		var captured_id: int = i
		select_btn.pressed.connect(func(): _on_avatar_selected(captured_id))
		select_btn.pressed.connect(UIAudio.play_click)
		cell.add_child(select_btn)
		
		grid.add_child(cell)
	
	add_child(avatar_picker)


func _on_avatar_selected(id: int) -> void:
	GameSettings.set_value("game", "avatar", id)
	GameSettings.save_settings()
	if avatar_picker and is_instance_valid(avatar_picker):
		avatar_picker.queue_free()
		avatar_picker = null
	_refresh_player_info()


func _create_version_label() -> void:
	var version_label: Label = Label.new()
	version_label.name = "VersionLabel"
	version_label.text = "v" + UpdateManager.get_current_version()
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0, 0.7))
	version_label.anchor_left = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -120
	version_label.offset_top = -35
	version_label.offset_right = -25
	version_label.offset_bottom = -15
	add_child(version_label)