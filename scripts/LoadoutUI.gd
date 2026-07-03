extends Control

# =============================================================================
# 装备配置界面
# 左侧5套配置列表，右侧编辑面板（主武器+3行Perk选择）
# =============================================================================

var _selected_index: int = 0

# Perk 选项数量
# 类别0: 2个（轻装上阵、清道夫）
# 类别1: 3个（防弹衣、快速治疗、爆炸抗性）
# 类别2: 3个（精准射击、弹药充沛、快速换弹）
const PERK_COUNTS: Array = [2, 3, 3]

# 主武器选项：1=步枪, 2=狙击枪, 4=机枪
const PRIMARY_WEAPON_OPTIONS: Array = [1, 2, 4]

# BGM（由 BGMManager Autoload 管理，跨场景连续）

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_selected_index = LoadoutManager.current_loadout_index
	_build_ui()
	BGMManager.play_bgm()
	_connect_click_sounds(self)


func _connect_click_sounds(node: Node) -> void:
	for child in node.get_children():
		_connect_click_sounds(child)
		if child is Button:
			child.pressed.connect(UIAudio.play_click)


func _build_ui() -> void:
	# 全屏背景
	var bg: ColorRect = ColorRect.new()
	bg.name = "BG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.06, 1)
	add_child(bg)

	# 主容器：左右分栏
	var main_hbox: HBoxContainer = HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 20)
	# 左边距
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)
	margin.add_child(main_hbox)

	# === 左侧：配置列表 ===
	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.custom_minimum_size = Vector2(200, 0)
	var left_style: StyleBoxFlat = StyleBoxFlat.new()
	left_style.bg_color = Color(0.06, 0.06, 0.08, 1)
	left_style.border_color = Color(0.4, 0.5, 0.7, 0.8)
	left_style.border_width_left = 2
	left_style.border_width_right = 2
	left_style.border_width_top = 2
	left_style.border_width_bottom = 2
	left_style.corner_radius_top_left = 8
	left_style.corner_radius_top_right = 8
	left_style.corner_radius_bottom_left = 8
	left_style.corner_radius_bottom_right = 8
	left_style.content_margin_top = 12
	left_style.content_margin_bottom = 12
	left_style.content_margin_left = 10
	left_style.content_margin_right = 10
	left_panel.add_theme_stylebox_override("panel", left_style)
	main_hbox.add_child(left_panel)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.name = "LeftVBox"
	left_vbox.add_theme_constant_override("separation", 8)
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_vbox)

	# 标题
	var list_title: Label = Label.new()
	list_title.name = "ListTitle"
	list_title.text = GameSettings.t("loadout")
	list_title.add_theme_font_size_override("font_size", 22)
	list_title.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
	left_vbox.add_child(list_title)

	# 配置按钮列表
	for i in range(LoadoutManager.MAX_LOADOUTS):
		var btn: Button = Button.new()
		btn.name = "LoadoutBtn%d" % i
		if i < LoadoutManager.loadouts.size():
			var ld: Dictionary = LoadoutManager.loadouts[i]
			btn.text = ld.get("name", "配置%d" % (i + 1))
		else:
			btn.text = "配置%d" % (i + 1)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 16)
		if i == _selected_index:
			btn.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
		btn.pressed.connect(func(): _on_loadout_selected(i))
		left_vbox.add_child(btn)

	# 返回按钮
	var back_btn: Button = Button.new()
	back_btn.name = "BackBtn"
	back_btn.text = GameSettings.t("back")
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(_on_back)
	left_vbox.add_child(back_btn)

	# === 右侧：编辑面板 ===
	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.name = "RightPanel"
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_style: StyleBoxFlat = StyleBoxFlat.new()
	right_style.bg_color = Color(0.08, 0.08, 0.10, 1)
	right_style.border_color = Color(0.4, 0.5, 0.7, 0.8)
	right_style.border_width_left = 2
	right_style.border_width_right = 2
	right_style.border_width_top = 2
	right_style.border_width_bottom = 2
	right_style.corner_radius_top_left = 8
	right_style.corner_radius_top_right = 8
	right_style.corner_radius_bottom_left = 8
	right_style.corner_radius_bottom_right = 8
	right_style.content_margin_top = 16
	right_style.content_margin_bottom = 16
	right_style.content_margin_left = 20
	right_style.content_margin_right = 20
	right_panel.add_theme_stylebox_override("panel", right_style)
	main_hbox.add_child(right_panel)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.name = "RightVBox"
	right_vbox.add_theme_constant_override("separation", 16)
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_vbox)

	# 配置名称（可编辑）
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = GameSettings.t("loadout") + " 名称:"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1))
	right_vbox.add_child(name_label)

	var name_edit: LineEdit = LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.add_theme_font_size_override("font_size", 18)
	if _selected_index < LoadoutManager.loadouts.size():
		name_edit.text = LoadoutManager.loadouts[_selected_index].get("name", "")
	name_edit.text_changed.connect(_on_name_changed)
	right_vbox.add_child(name_edit)

	# 主武器选择标题
	var weapon_title: Label = Label.new()
	weapon_title.name = "WeaponTitle"
	weapon_title.text = GameSettings.t("primary_weapon")
	weapon_title.add_theme_font_size_override("font_size", 18)
	weapon_title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
	right_vbox.add_child(weapon_title)

	# 主武器选择按钮行
	var weapon_row: HBoxContainer = HBoxContainer.new()
	weapon_row.name = "WeaponRow"
	weapon_row.add_theme_constant_override("separation", 12)
	right_vbox.add_child(weapon_row)

	for w_idx in PRIMARY_WEAPON_OPTIONS:
		var w_btn: Button = Button.new()
		w_btn.name = "WeaponBtn%d" % w_idx
		w_btn.text = LoadoutManager.get_weapon_name(w_idx)
		w_btn.custom_minimum_size = Vector2(120, 50)
		w_btn.add_theme_font_size_override("font_size", 16)
		var current_pw: int = _get_current_primary_weapon()
		if w_idx == current_pw:
			w_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
		w_btn.pressed.connect(func(): _on_weapon_selected(w_idx))
		weapon_row.add_child(w_btn)

	# Perk 选择（3行）
	for cat in range(3):
		var perk_title: Label = Label.new()
		perk_title.name = "PerkTitle%d" % cat
		var cat_names: Array = [GameSettings.t("perk_category_0"), GameSettings.t("perk_category_1"), GameSettings.t("perk_category_2")]
		perk_title.text = cat_names[cat]
		perk_title.add_theme_font_size_override("font_size", 16)
		perk_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))
		right_vbox.add_child(perk_title)

		var perk_row: HBoxContainer = HBoxContainer.new()
		perk_row.name = "PerkRow%d" % cat
		perk_row.add_theme_constant_override("separation", 10)
		right_vbox.add_child(perk_row)

		# "无"选项
		var none_btn: Button = Button.new()
		none_btn.name = "PerkNone%d" % cat
		none_btn.text = GameSettings.t("perk_none")
		none_btn.custom_minimum_size = Vector2(80, 40)
		none_btn.add_theme_font_size_override("font_size", 14)
		var current_perk: int = _get_current_perk(cat)
		if current_perk == -1:
			none_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
		none_btn.pressed.connect(func(): _on_perk_selected(cat, -1))
		perk_row.add_child(none_btn)

		# Perk选项
		for p_idx in range(PERK_COUNTS[cat]):
			var p_btn: Button = Button.new()
			p_btn.name = "PerkBtn%d_%d" % [cat, p_idx]
			p_btn.text = LoadoutManager.get_perk_name(cat, p_idx)
			p_btn.custom_minimum_size = Vector2(140, 40)
			p_btn.add_theme_font_size_override("font_size", 14)
			if p_idx == current_perk:
				p_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
			p_btn.pressed.connect(func(): _on_perk_selected(cat, p_idx))
			perk_row.add_child(p_btn)

		# Perk描述（选中后显示）
		var perk_desc: Label = Label.new()
		perk_desc.name = "PerkDesc%d" % cat
		perk_desc.add_theme_font_size_override("font_size", 12)
		perk_desc.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1))
		if current_perk >= 0:
			perk_desc.text = LoadoutManager.get_perk_desc(cat, current_perk)
		else:
			perk_desc.text = ""
		right_vbox.add_child(perk_desc)

	# 保存并使用按钮
	var save_btn: Button = Button.new()
	save_btn.name = "SaveBtn"
	save_btn.text = GameSettings.t("loadout") + " ✓"
	save_btn.custom_minimum_size = Vector2(200, 50)
	save_btn.add_theme_font_size_override("font_size", 18)
	save_btn.pressed.connect(_on_save)
	right_vbox.add_child(save_btn)


func _get_current_primary_weapon() -> int:
	if _selected_index < LoadoutManager.loadouts.size():
		return LoadoutManager.loadouts[_selected_index].get("primary_weapon", 1)
	return 1

func _get_current_perk(category: int) -> int:
	if _selected_index < LoadoutManager.loadouts.size():
		var perks: Array = LoadoutManager.loadouts[_selected_index].get("perks", [-1, -1, -1])
		if category < perks.size():
			return perks[category]
	return -1

func _on_loadout_selected(index: int) -> void:
	_selected_index = index
	# 重建UI以反映新选中配置
	for child in get_children():
		if child.name != "BG":
			child.queue_free()
	_build_ui()
	_connect_click_sounds(self)

func _on_name_changed(new_text: String) -> void:
	if _selected_index < LoadoutManager.loadouts.size():
		LoadoutManager.loadouts[_selected_index]["name"] = new_text

func _on_weapon_selected(weapon_index: int) -> void:
	if _selected_index < LoadoutManager.loadouts.size():
		LoadoutManager.loadouts[_selected_index]["primary_weapon"] = weapon_index
		_refresh_highlight()

func _on_perk_selected(category: int, perk_index: int) -> void:
	if _selected_index < LoadoutManager.loadouts.size():
		var perks: Array = LoadoutManager.loadouts[_selected_index].get("perks", [-1, -1, -1])
		perks[category] = perk_index
		LoadoutManager.loadouts[_selected_index]["perks"] = perks
		_refresh_highlight()

func _refresh_highlight() -> void:
	# 重建整个UI（简单粗暴但有效）
	for child in get_children():
		if child.name != "BG":
			child.queue_free()
	_build_ui()
	_connect_click_sounds(self)

func _on_save() -> void:
	LoadoutManager.select_loadout(_selected_index)
	LoadoutManager._save_loadouts()
	_on_back()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
