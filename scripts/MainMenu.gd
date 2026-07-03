extends Control

# =============================================================================
# 主菜单控制器
# 全屏模式选择，多语言支持
# 主界面 BGM：进入主菜单后播放，开场动画时不播放
# =============================================================================

@onready var main_container: CenterContainer = $MainContainer
@onready var start_btn: Button = $MainContainer/VBox/ButtonContainer/StartBtn
@onready var settings_btn: Button = $MainContainer/VBox/ButtonContainer/SettingsBtn
@onready var about_btn: Button = $MainContainer/VBox/ButtonContainer/AboutBtn
@onready var loadout_btn: Button = $MainContainer/VBox/ButtonContainer/LoadoutBtn
@onready var quit_btn: Button = $MainContainer/VBox/ButtonContainer/QuitBtn

# 设置界面实例（叠加显示，不切换场景）
var settings_instance: Control = null

# 游戏介绍全屏面板
var about_screen: Control = null

# 模式选择全屏
@onready var mode_screen: Control = $ModeSelectScreen
@onready var mode_title: Label = $ModeSelectScreen/Center/VBox/TitleLabel
@onready var zombie_card_title: Label = $ModeSelectScreen/Center/VBox/ModeRow/ZombieCard/VBox/Title
@onready var zombie_card_desc: Label = $ModeSelectScreen/Center/VBox/ModeRow/ZombieCard/VBox/Desc
@onready var zombie_btn: Button = $ModeSelectScreen/Center/VBox/ModeRow/ZombieCard/VBox/ZombieBtn
@onready var bot_card_title: Label = $ModeSelectScreen/Center/VBox/ModeRow/BotCard/VBox/Title
@onready var bot_card_desc: Label = $ModeSelectScreen/Center/VBox/ModeRow/BotCard/VBox/Desc
@onready var bot_btn: Button = $ModeSelectScreen/Center/VBox/ModeRow/BotCard/VBox/BotBtn
@onready var mode_back_btn: Button = $ModeSelectScreen/Center/VBox/BackBtn

# 联机模式卡片
@onready var mp_card_title: Label = $ModeSelectScreen/Center/VBox/ModeRow/MultiplayerCard/VBox/Title
@onready var mp_card_desc: Label = $ModeSelectScreen/Center/VBox/ModeRow/MultiplayerCard/VBox/Desc
@onready var mp_btn: Button = $ModeSelectScreen/Center/VBox/ModeRow/MultiplayerCard/VBox/MultiplayerBtn

var title_time: float = 0.0

# 玩家信息面板节点引用
var player_info_panel: PanelContainer = null
var player_avatar: Control = null  # AvatarIcon
var player_name_label: Label = null
var player_level_label: Label = null
var player_xp_bar: ProgressBar = null
var player_xp_label: Label = null
var avatar_picker: Control = null  # 头像选择面板

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# 连接按钮信号
	start_btn.pressed.connect(_on_start_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	about_btn.pressed.connect(_on_about_pressed)
	loadout_btn.pressed.connect(_on_loadout_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	zombie_btn.pressed.connect(_on_zombie_mode_pressed)
	bot_btn.pressed.connect(_on_bot_mode_pressed)
	mp_btn.pressed.connect(_on_multiplayer_pressed)
	mode_back_btn.pressed.connect(_on_back_pressed)

	# 隐藏模式选择全屏
	if Engine.has_meta("show_mode_select") and Engine.get_meta("show_mode_select"):
		mode_screen.visible = true
		Engine.remove_meta("show_mode_select")
	else:
		mode_screen.visible = false

	# 应用已保存的设置（全屏、分辨率、音量等）
	apply_saved_settings()
	# 应用多语言
	_apply_language()

	# 播放主界面 BGM（跨场景连续）
	BGMManager.play_bgm()

	# 创建玩家信息面板（左上角）
	_create_player_info_panel()
	
	# 创建版本标签（右下角）
	_create_version_label()
	
	# 给所有按钮添加点击音效
	_connect_click_sounds(self)


func _connect_click_sounds(node: Node) -> void:
	for child in node.get_children():
		_connect_click_sounds(child)
		if child is Button:
			child.pressed.connect(UIAudio.play_click)


func _process(delta: float) -> void:
	# 标题呼吸缩放效果
	title_time += delta
	var s: float = 1.0 + sin(title_time * 2.0) * 0.03
	var title_lbl: Label = $MainContainer/VBox/TitleLabel
	if title_lbl:
		title_lbl.scale = Vector2(s, s)


func _apply_language() -> void:
	start_btn.text = GameSettings.t("start_game")
	settings_btn.text = GameSettings.t("settings")
	about_btn.text = GameSettings.t("about_game")
	loadout_btn.text = GameSettings.t("loadout")
	quit_btn.text = GameSettings.t("quit_game")
	mode_title.text = GameSettings.t("select_mode")
	zombie_card_title.text = GameSettings.t("zombie_mode")
	zombie_card_desc.text = GameSettings.t("zombie_mode_desc")
	zombie_btn.text = GameSettings.t("start_game")
	bot_card_title.text = GameSettings.t("bot_mode")
	bot_card_desc.text = GameSettings.t("bot_mode_desc")
	bot_btn.text = GameSettings.t("start_game")
	mp_card_title.text = GameSettings.t("multiplayer_mode")
	mp_card_desc.text = GameSettings.t("multiplayer_desc")
	mp_btn.text = GameSettings.t("start_game")
	mode_back_btn.text = GameSettings.t("back")
	# 刷新介绍面板
	if about_screen and about_screen.visible:
		_refresh_about_panel()
	# 刷新玩家信息面板（语言可能改变，名字/等级文本格式更新）
	if player_info_panel:
		_refresh_player_info()


func _on_start_pressed() -> void:
	mode_screen.visible = true


func _on_settings_pressed() -> void:
	# 叠加显示设置界面，不切换场景
	if settings_instance:
		return
	var settings_scene: PackedScene = load("res://UI/settings.tscn")
	if not settings_scene:
		return
	settings_instance = settings_scene.instantiate()
	# 使用回调替代信号，更可靠
	settings_instance.on_close_callback = func(): _on_settings_closed()
	add_child(settings_instance)


func _on_settings_closed() -> void:
	if settings_instance:
		settings_instance.queue_free()
		settings_instance = null
	# 设置关闭后刷新多语言文本（语言可能已被更改）
	_apply_language()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_loadout_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/loadout/LoadoutMenu.tscn")


func _on_bot_mode_pressed() -> void:
	BGMManager.stop_bgm()
	get_tree().change_scene_to_file("res://scenes/game/bot_mode/bot_game.tscn")


func _on_zombie_mode_pressed() -> void:
	BGMManager.stop_bgm()
	get_tree().change_scene_to_file("res://scenes/game/zombie_mode/zombie_game.tscn")


func _on_multiplayer_pressed() -> void:
	# 点击联机模式卡片 → 打开联机大厅
	get_tree().change_scene_to_file("res://scenes/multiplayer/Lobby.tscn")


func _on_back_pressed() -> void:
	mode_screen.visible = false


func _on_about_pressed() -> void:
	if not about_screen:
		_create_about_screen()
	main_container.visible = false
	about_screen.visible = true


func _create_about_screen() -> void:
	about_screen = Control.new()
	about_screen.name = "AboutScreen"
	about_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 背景（完全不透明，遮挡主菜单）
	var bg: ColorRect = ColorRect.new()
	bg.name = "BG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.06, 1)
	about_screen.add_child(bg)

	# 滚动容器（内容可能很长）
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	about_screen.add_child(scroll)

	# 边距容器（左右留40px，上下留30px）
	# ★ 关键：不设 PRESET_FULL_RECT！否则填满视口导致无法滚动
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	scroll.add_child(margin)

	# 内容 VBox
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 24)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	# ── 游戏名 ──
	var game_title: Label = Label.new()
	game_title.name = "GameTitle"
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_title.add_theme_font_size_override("font_size", 48)
	game_title.add_theme_color_override("font_color", Color(1, 0.8, 0, 1))
	game_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(game_title)

	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(subtitle)

	# ── 工作室 ──
	var studio_vbox: VBoxContainer = VBoxContainer.new()
	studio_vbox.name = "StudioVBox"
	studio_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	studio_vbox.add_theme_constant_override("separation", 4)
	studio_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(studio_vbox)

	var studio_label: Label = Label.new()
	studio_label.name = "StudioLabel"
	studio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	studio_label.add_theme_font_size_override("font_size", 14)
	studio_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	studio_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	studio_vbox.add_child(studio_label)

	var studio_name: Label = Label.new()
	studio_name.name = "StudioName"
	studio_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	studio_name.add_theme_font_size_override("font_size", 36)
	studio_name.add_theme_color_override("font_color", Color(0, 0.85, 1, 1))
	studio_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	studio_vbox.add_child(studio_name)

	# ── 创始人区域 ──
	var founder_hbox: HBoxContainer = HBoxContainer.new()
	founder_hbox.name = "FounderRow"
	founder_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	founder_hbox.add_theme_constant_override("separation", 20)
	content.add_child(founder_hbox)

	# 头像
	var avatar_rect: TextureRect = TextureRect.new()
	avatar_rect.name = "Avatar"
	avatar_rect.custom_minimum_size = Vector2(120, 120)
	avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if ResourceLoader.exists("res://assets/qiudidia.jpg"):
		avatar_rect.texture = load("res://assets/qiudidia.jpg")
	founder_hbox.add_child(avatar_rect)

	# 创始人名字和标签
	var founder_info: VBoxContainer = VBoxContainer.new()
	founder_info.name = "FounderInfo"
	founder_info.alignment = BoxContainer.ALIGNMENT_CENTER
	founder_info.add_theme_constant_override("separation", 4)
	founder_hbox.add_child(founder_info)

	var founder_label: Label = Label.new()
	founder_label.name = "FounderLabel"
	founder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	founder_label.add_theme_font_size_override("font_size", 14)
	founder_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	founder_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	founder_info.add_child(founder_label)

	var founder_name: Label = Label.new()
	founder_name.name = "FounderName"
	founder_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	founder_name.add_theme_font_size_override("font_size", 24)
	founder_name.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
	founder_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	founder_info.add_child(founder_name)

	# ── 分隔线 ──
	var sep1: HSeparator = HSeparator.new()
	content.add_child(sep1)

	# ── 游戏模式介绍标题 ──
	var modes_lbl: Label = Label.new()
	modes_lbl.name = "ModeSectionTitle"
	modes_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	modes_lbl.add_theme_font_size_override("font_size", 28)
	modes_lbl.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
	modes_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(modes_lbl)

	# ── 僵尸模式卡片（用 PanelContainer，会自动适应子节点大小） ──
	var zombie_card: PanelContainer = PanelContainer.new()
	zombie_card.name = "ZombieCard"
	var zombie_style: StyleBoxFlat = StyleBoxFlat.new()
	zombie_style.bg_color = Color(0.08, 0.12, 0.08, 1)
	zombie_style.border_color = Color(0.2, 0.8, 0.2, 0.6)
	zombie_style.border_width_bottom = 2
	zombie_style.border_width_top = 2
	zombie_style.border_width_left = 2
	zombie_style.border_width_right = 2
	zombie_style.content_margin_top = 16
	zombie_style.content_margin_bottom = 16
	zombie_style.content_margin_left = 20
	zombie_style.content_margin_right = 20
	zombie_card.add_theme_stylebox_override("panel", zombie_style)
	zombie_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(zombie_card)

	var zombie_vbox: VBoxContainer = VBoxContainer.new()
	zombie_vbox.name = "ZombieVBox"
	# ★ PanelContainer 是 Container，会自动管理子节点布局，不需要 PRESET_FULL_RECT
	zombie_vbox.add_theme_constant_override("separation", 8)
	zombie_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zombie_card.add_child(zombie_vbox)

	var z_title: Label = Label.new()
	z_title.name = "ZombieTitle"
	z_title.add_theme_font_size_override("font_size", 22)
	z_title.add_theme_color_override("font_color", Color(0.2, 0.85, 0.2, 1))
	z_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zombie_vbox.add_child(z_title)

	var z_desc: Label = Label.new()
	z_desc.name = "ZombieDesc"
	z_desc.add_theme_font_size_override("font_size", 14)
	z_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	z_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	z_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zombie_vbox.add_child(z_desc)

	# ── Bot 模式卡片 ──
	var bot_card: PanelContainer = PanelContainer.new()
	bot_card.name = "BotCard"
	var bot_style: StyleBoxFlat = StyleBoxFlat.new()
	bot_style.bg_color = Color(0.12, 0.08, 0.08, 1)
	bot_style.border_color = Color(0.9, 0.2, 0.2, 0.6)
	bot_style.border_width_bottom = 2
	bot_style.border_width_top = 2
	bot_style.border_width_left = 2
	bot_style.border_width_right = 2
	bot_style.content_margin_top = 16
	bot_style.content_margin_bottom = 16
	bot_style.content_margin_left = 20
	bot_style.content_margin_right = 20
	bot_card.add_theme_stylebox_override("panel", bot_style)
	bot_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(bot_card)

	var bot_vbox: VBoxContainer = VBoxContainer.new()
	bot_vbox.name = "BotVBox"
	bot_vbox.add_theme_constant_override("separation", 8)
	bot_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_card.add_child(bot_vbox)

	var b_title: Label = Label.new()
	b_title.name = "BotTitle"
	b_title.add_theme_font_size_override("font_size", 22)
	b_title.add_theme_color_override("font_color", Color(0.9, 0.25, 0.25, 1))
	b_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_vbox.add_child(b_title)

	var b_desc: Label = Label.new()
	b_desc.name = "BotDesc"
	b_desc.add_theme_font_size_override("font_size", 14)
	b_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	b_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_vbox.add_child(b_desc)

	# ── 联机模式卡片 ──
	var mp_card: PanelContainer = PanelContainer.new()
	mp_card.name = "MultiplayerCard"
	var mp_style: StyleBoxFlat = StyleBoxFlat.new()
	mp_style.bg_color = Color(0.08, 0.08, 0.15, 1)
	mp_style.border_color = Color(0.3, 0.5, 0.9, 0.6)
	mp_style.border_width_bottom = 2
	mp_style.border_width_top = 2
	mp_style.border_width_left = 2
	mp_style.border_width_right = 2
	mp_style.content_margin_top = 16
	mp_style.content_margin_bottom = 16
	mp_style.content_margin_left = 20
	mp_style.content_margin_right = 20
	mp_card.add_theme_stylebox_override("panel", mp_style)
	mp_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(mp_card)

	var mp_vbox: VBoxContainer = VBoxContainer.new()
	mp_vbox.name = "MultiplayerVBox"
	mp_vbox.add_theme_constant_override("separation", 8)
	mp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_card.add_child(mp_vbox)

	var mp_title: Label = Label.new()
	mp_title.name = "MultiplayerTitle"
	mp_title.add_theme_font_size_override("font_size", 22)
	mp_title.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0, 1))
	mp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_vbox.add_child(mp_title)

	var mp_desc: Label = Label.new()
	mp_desc.name = "MultiplayerDesc"
	mp_desc.add_theme_font_size_override("font_size", 14)
	mp_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	mp_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mp_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_vbox.add_child(mp_desc)

	# ── 分隔线 ──
	var sep2: HSeparator = HSeparator.new()
	content.add_child(sep2)

	# ── 武器介绍标题 ──
	var weapon_title: Label = Label.new()
	weapon_title.name = "WeaponSectionTitle"
	weapon_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_title.add_theme_font_size_override("font_size", 28)
	weapon_title.add_theme_color_override("font_color", Color(0.85, 0.65, 0.1, 1))
	weapon_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(weapon_title)

	# ── 武器详情 ──
	var weapon_info: Label = Label.new()
	weapon_info.name = "WeaponInfo"
	weapon_info.add_theme_font_size_override("font_size", 14)
	weapon_info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	weapon_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	weapon_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(weapon_info)

	# ── 特长系统卡片 ──
	var perks_card: PanelContainer = PanelContainer.new()
	perks_card.name = "PerksCard"
	var perks_style: StyleBoxFlat = StyleBoxFlat.new()
	perks_style.bg_color = Color(0.10, 0.06, 0.14, 1)
	perks_style.border_color = Color(0.8, 0.4, 0.9, 0.6)
	perks_style.border_width_bottom = 2
	perks_style.border_width_top = 2
	perks_style.border_width_left = 2
	perks_style.border_width_right = 2
	perks_style.content_margin_top = 16
	perks_style.content_margin_bottom = 16
	perks_style.content_margin_left = 20
	perks_style.content_margin_right = 20
	perks_card.add_theme_stylebox_override("panel", perks_style)
	perks_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(perks_card)

	var perks_vbox: VBoxContainer = VBoxContainer.new()
	perks_vbox.name = "PerksVBox"
	perks_vbox.add_theme_constant_override("separation", 8)
	perks_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perks_card.add_child(perks_vbox)

	var perks_title: Label = Label.new()
	perks_title.name = "PerksTitle"
	perks_title.add_theme_font_size_override("font_size", 22)
	perks_title.add_theme_color_override("font_color", Color(0.8, 0.4, 0.9, 1))
	perks_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perks_vbox.add_child(perks_title)

	var perks_desc: Label = Label.new()
	perks_desc.name = "PerksDesc"
	perks_desc.add_theme_font_size_override("font_size", 14)
	perks_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	perks_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	perks_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	perks_vbox.add_child(perks_desc)

	# ── 分隔线 ──
	var sep3: HSeparator = HSeparator.new()
	content.add_child(sep3)

	# ── 操作说明标题 ──
	var control_title: Label = Label.new()
	control_title.name = "ControlSectionTitle"
	control_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	control_title.add_theme_font_size_override("font_size", 28)
	control_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.9, 1))
	control_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(control_title)

	# ── 操作说明 ──
	var control_info: Label = Label.new()
	control_info.name = "ControlInfo"
	control_info.add_theme_font_size_override("font_size", 14)
	control_info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	control_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(control_info)

	# ── 返回按钮 ──
	var back_btn: Button = Button.new()
	back_btn.name = "BackBtn"
	back_btn.custom_minimum_size = Vector2(200, 45)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_btn.pressed.connect(_on_about_back_pressed)
	back_btn.pressed.connect(UIAudio.play_click)
	content.add_child(back_btn)

	add_child(about_screen)
	_refresh_about_panel()


func _refresh_about_panel() -> void:
	if not about_screen:
		return
	var content: VBoxContainer = about_screen.get_node("Scroll/Margin/Content")

	# 游戏名
	content.get_node("GameTitle").text = "BULLET RUN"
	content.get_node("Subtitle").text = GameSettings.t("about_subtitle")

	# 工作室
	content.get_node("StudioVBox/StudioLabel").text = GameSettings.t("about_studio_label")
	content.get_node("StudioVBox/StudioName").text = "Vee Studio"

	# 创始人
	content.get_node("FounderRow/FounderInfo/FounderLabel").text = GameSettings.t("about_founder_label")
	content.get_node("FounderRow/FounderInfo/FounderName").text = "qiudidia"

	# 游戏模式
	content.get_node("ModeSectionTitle").text = GameSettings.t("about_modes_title")
	content.get_node("ZombieCard/ZombieVBox/ZombieTitle").text = GameSettings.t("about_zombie_title")
	content.get_node("ZombieCard/ZombieVBox/ZombieDesc").text = GameSettings.t("about_zombie_desc")
	content.get_node("BotCard/BotVBox/BotTitle").text = GameSettings.t("about_bot_title")
	content.get_node("BotCard/BotVBox/BotDesc").text = GameSettings.t("about_bot_desc")
	content.get_node("MultiplayerCard/MultiplayerVBox/MultiplayerTitle").text = GameSettings.t("about_multiplayer_title")
	content.get_node("MultiplayerCard/MultiplayerVBox/MultiplayerDesc").text = GameSettings.t("about_multiplayer_desc")

	# 武器
	content.get_node("WeaponSectionTitle").text = GameSettings.t("about_weapons_title")
	content.get_node("WeaponInfo").text = GameSettings.t("about_weapons_info")

	# 特长系统
	content.get_node("PerksCard/PerksVBox/PerksTitle").text = GameSettings.t("about_perks_title")
	content.get_node("PerksCard/PerksVBox/PerksDesc").text = GameSettings.t("about_perks_desc")

	# 操作说明
	content.get_node("ControlSectionTitle").text = GameSettings.t("about_controls_title")
	content.get_node("ControlInfo").text = GameSettings.t("about_controls_info")

	# 返回
	content.get_node("BackBtn").text = GameSettings.t("back")


func _on_about_back_pressed() -> void:
	if about_screen:
		about_screen.visible = false
	main_container.visible = true


func apply_saved_settings() -> void:
	GameSettings.apply_all_settings()


func _create_player_info_panel() -> void:
	# 左上角玩家信息面板：头像 + 名字 + 等级 + XP进度条
	# ★ 用 PanelContainer 作为根节点，content 直接放在里面享受 content margins
	player_info_panel = PanelContainer.new()
	player_info_panel.name = "PlayerInfoPanel"
	# 左上角定位（锚点左上，固定偏移）
	player_info_panel.anchor_left = 0.0
	player_info_panel.anchor_top = 0.0
	player_info_panel.anchor_right = 0.0
	player_info_panel.anchor_bottom = 0.0
	player_info_panel.offset_left = 20
	player_info_panel.offset_top = 20
	player_info_panel.offset_right = 260
	player_info_panel.offset_bottom = 120

	# 半透明背景+边框
	var bg_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.06, 0.08, 0.85)
	bg_style.border_color = Color(0.4, 0.6, 0.9, 0.5)
	bg_style.border_width_bottom = 1
	bg_style.border_width_top = 1
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.corner_radius_top_left = 8
	bg_style.corner_radius_top_right = 8
	bg_style.corner_radius_bottom_left = 8
	bg_style.corner_radius_bottom_right = 8
	bg_style.content_margin_top = 12
	bg_style.content_margin_bottom = 12
	bg_style.content_margin_left = 14
	bg_style.content_margin_right = 14
	player_info_panel.add_theme_stylebox_override("panel", bg_style)

	# 内容区域：头像在左，信息在右
	# ★ PanelContainer 内子节点不需要 PRESET_FULL_RECT，自动受 content margins 控制
	var content: HBoxContainer = HBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 12)
	player_info_panel.add_child(content)

	# 头像（AvatarIcon）——直接可点击，hover时显示高亮环
	var avatar_script: GDScript = load("res://scripts/AvatarIcon.gd")
	player_avatar = Control.new()
	player_avatar.name = "AvatarIcon"
	player_avatar.set_script(avatar_script)
	player_avatar.avatar_id = GameSettings.get_avatar()
	player_avatar.avatar_size = Vector2(48, 48)
	player_avatar.avatar_clicked.connect(_on_avatar_clicked)
	content.add_child(player_avatar)

	# 右侧信息 VBox
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.name = "InfoVBox"
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 4)
	content.add_child(info_vbox)

	# 玩家名 + 等级
	var name_level_hbox: HBoxContainer = HBoxContainer.new()
	name_level_hbox.name = "NameLevelRow"
	name_level_hbox.add_theme_constant_override("separation", 8)
	info_vbox.add_child(name_level_hbox)

	player_name_label = Label.new()
	player_name_label.name = "PlayerName"
	player_name_label.add_theme_font_size_override("font_size", 18)
	player_name_label.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
	name_level_hbox.add_child(player_name_label)

	player_level_label = Label.new()
	player_level_label.name = "PlayerLevel"
	player_level_label.add_theme_font_size_override("font_size", 16)
	player_level_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0, 1))
	name_level_hbox.add_child(player_level_label)

	# XP 进度条
	player_xp_bar = ProgressBar.new()
	player_xp_bar.name = "XPBar"
	player_xp_bar.custom_minimum_size = Vector2(140, 12)
	player_xp_bar.show_percentage = false
	player_xp_bar.value = GameSettings.get_level_progress() * 100.0
	# 进度条样式
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.3, 0.7, 1.0, 0.9)
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	player_xp_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_bar_style: StyleBoxFlat = StyleBoxFlat.new()
	bg_bar_style.bg_color = Color(0.15, 0.15, 0.18, 1)
	bg_bar_style.corner_radius_top_left = 4
	bg_bar_style.corner_radius_top_right = 4
	bg_bar_style.corner_radius_bottom_left = 4
	bg_bar_style.corner_radius_bottom_right = 4
	player_xp_bar.add_theme_stylebox_override("background", bg_bar_style)
	info_vbox.add_child(player_xp_bar)

	# XP 数值标签
	player_xp_label = Label.new()
	player_xp_label.name = "XPLabel"
	player_xp_label.add_theme_font_size_override("font_size", 12)
	player_xp_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	info_vbox.add_child(player_xp_label)

	add_child(player_info_panel)
	_refresh_player_info()


func _refresh_player_info() -> void:
	# 刷新玩家信息面板（名字/等级/XP从GameSettings读取）
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

	# 更新头像
	if player_avatar and player_avatar.has_method("set_avatar"):
		player_avatar.set_avatar(p_avatar_id)


func _on_avatar_clicked() -> void:
	# 打开/关闭头像选择面板
	if avatar_picker and is_instance_valid(avatar_picker):
		avatar_picker.queue_free()
		avatar_picker = null
		return
	_create_avatar_picker()


func _create_avatar_picker() -> void:
	# 头像选择面板：4×4网格展示16个头像
	var total_avatars: int = 16
	var cols: int = 4
	var rows: int = 4
	var cell_size: float = 64.0
	var padding: float = 8.0

	avatar_picker = PanelContainer.new()
	avatar_picker.name = "AvatarPicker"
	# 定位在玩家信息面板下方
	avatar_picker.anchor_left = 0.0
	avatar_picker.anchor_top = 0.0
	avatar_picker.anchor_right = 0.0
	avatar_picker.anchor_bottom = 0.0
	avatar_picker.offset_left = 20
	avatar_picker.offset_top = 125
	avatar_picker.offset_right = 20 + cols * (cell_size + padding) + 28
	avatar_picker.offset_bottom = 125 + rows * (cell_size + padding) + 40

	# 背景
	var picker_style: StyleBoxFlat = StyleBoxFlat.new()
	picker_style.bg_color = Color(0.08, 0.08, 0.12, 0.92)
	picker_style.border_color = Color(0.4, 0.6, 0.9, 0.7)
	picker_style.border_width_bottom = 2
	picker_style.border_width_top = 2
	picker_style.border_width_left = 2
	picker_style.border_width_right = 2
	picker_style.corner_radius_top_left = 8
	picker_style.corner_radius_top_right = 8
	picker_style.corner_radius_bottom_left = 8
	picker_style.corner_radius_bottom_right = 8
	picker_style.content_margin_top = 8
	picker_style.content_margin_bottom = 8
	picker_style.content_margin_left = 10
	picker_style.content_margin_right = 10
	avatar_picker.add_theme_stylebox_override("panel", picker_style)

	# GridContainer
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
		cell.name = "AvatarCell_%d" % i
		cell.custom_minimum_size = Vector2(cell_size, cell_size)
		# 选中态 vs 默认态
		var cell_style: StyleBoxFlat = StyleBoxFlat.new()
		if i == current_avatar:
			cell_style.bg_color = Color(0.2, 0.35, 0.6, 0.7)
			cell_style.border_color = Color(0.4, 0.7, 1.0, 1.0)
			cell_style.border_width_bottom = 2
			cell_style.border_width_top = 2
			cell_style.border_width_left = 2
			cell_style.border_width_right = 2
		else:
			cell_style.bg_color = Color(0.12, 0.12, 0.16, 0.5)
			cell_style.border_color = Color(0.3, 0.3, 0.35, 0.5)
			cell_style.border_width_bottom = 1
			cell_style.border_width_top = 1
			cell_style.border_width_left = 1
			cell_style.border_width_right = 1
		cell_style.corner_radius_top_left = 4
		cell_style.corner_radius_top_right = 4
		cell_style.corner_radius_bottom_left = 4
		cell_style.corner_radius_bottom_right = 4
		cell.add_theme_stylebox_override("panel", cell_style)

		var avatar_node: Control = Control.new()
		avatar_node.name = "Avatar_%d" % i
		avatar_node.set_script(avatar_script)
		avatar_node.avatar_id = i
		avatar_node.avatar_size = Vector2(cell_size - 10, cell_size - 10)
		cell.add_child(avatar_node)

		# 点击选择
		var select_btn: Button = Button.new()
		select_btn.name = "SelectBtn_%d" % i
		select_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		select_btn.add_theme_font_size_override("font_size", 0)
		# 透明按钮覆盖整个cell
		var sel_style: StyleBoxFlat = StyleBoxFlat.new()
		sel_style.bg_color = Color(0, 0, 0, 0)
		sel_style.border_width_bottom = 0
		sel_style.border_width_top = 0
		sel_style.border_width_left = 0
		sel_style.border_width_right = 0
		select_btn.add_theme_stylebox_override("normal", sel_style)
		var sel_hover: StyleBoxFlat = StyleBoxFlat.new()
		sel_hover.bg_color = Color(0.2, 0.3, 0.5, 0.3)
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
	# 保存选中的头像
	GameSettings.set_value("game", "avatar", id)
	GameSettings.save_settings()
	# 关闭选择面板
	if avatar_picker and is_instance_valid(avatar_picker):
		avatar_picker.queue_free()
		avatar_picker = null
	# 更新主界面头像
	_refresh_player_info()

# =============================================================================
# 版本显示
# =============================================================================
func _create_version_label() -> void:
	"""在右下角显示版本号"""
	var version_label: Label = Label.new()
	version_label.name = "VersionLabel"
	version_label.text = "v" + _get_version()
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	version_label.add_theme_font_size_override("font_size", 14)
	version_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
	
	# 锚点设为右下角
	version_label.anchor_left = 1.0
	version_label.anchor_top = 1.0
	version_label.anchor_right = 1.0
	version_label.anchor_bottom = 1.0
	version_label.offset_left = -80
	version_label.offset_top = -30
	version_label.offset_right = -20
	version_label.offset_bottom = -10
	
	add_child(version_label)


func _get_version() -> String:
	"""读取version.txt获取版本号"""
	var file: FileAccess = FileAccess.open("res://version.txt", FileAccess.READ)
	if file:
		return file.get_line().strip_edges()
	return "unknown"
