extends Control

# =============================================================================
# 装备配置界面（风格化版）
# 左侧5套配置列表，右侧编辑面板（主武器+3行Perk选择）
# =============================================================================

var _selected_index: int = 0
var _loadout_buttons: Array = []
var _weapon_buttons: Array = []
var _perk_buttons: Array = []

# Perk 选项数量
const PERK_COUNTS: Array = [2, 3, 3]
# 主武器选项：1=步枪, 2=狙击枪, 4=机枪
const PRIMARY_WEAPON_OPTIONS: Array = [1, 2, 4]
const WEAPON_ICONS: Dictionary = {1: "R", 2: "S", 4: "M"}

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
			if not child.pressed.is_connected(UIAudio.play_click):
				child.pressed.connect(UIAudio.play_click)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "BG"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.03, 0.04, 0.08, 1)
	add_child(bg)
	
	var bg_script: GDScript = load("res://scripts/DynamicBackground.gd")
	var bg_node := Control.new()
	bg_node.name = "DynamicBG"
	bg_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_node.set_script(bg_script)
	add_child(bg_node)

	var main_hbox := HBoxContainer.new()
	main_hbox.name = "MainHBox"
	main_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 20)
	
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	main_hbox.add_child(margin)
	add_child(main_hbox)

	_create_left_panel(margin)
	_create_right_panel(margin)


func _create_left_panel(parent: Container) -> void:
	var main_hbox: HBoxContainer = parent.get_parent()
	
	var left_panel := PanelContainer.new()
	left_panel.name = "LeftPanel"
	left_panel.custom_minimum_size = Vector2(220, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.04, 0.06, 0.1, 0.9)
	left_style.border_color = Color(0.3, 0.5, 0.8, 0.5)
	left_style.border_width_left = 2
	left_style.border_width_right = 2
	left_style.border_width_top = 2
	left_style.border_width_bottom = 2
	left_style.corner_radius_top_left = 10
	left_style.corner_radius_top_right = 10
	left_style.corner_radius_bottom_left = 10
	left_style.corner_radius_bottom_right = 10
	left_style.content_margin_top = 14
	left_style.content_margin_bottom = 14
	left_style.content_margin_left = 12
	left_style.content_margin_right = 12
	left_panel.add_theme_stylebox_override("panel", left_style)
	
	var main_hbox_ref: HBoxContainer = parent.get_parent()
	main_hbox_ref.add_child(left_panel)
	
	var left_vbox := VBoxContainer.new()
	left_vbox.name = "LeftVBox"
	left_vbox.add_theme_constant_override("separation", 8)
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_vbox)
	
	var list_title := Label.new()
	list_title.name = "ListTitle"
	list_title.text = GameSettings.t("loadout")
	list_title.add_theme_font_size_override("font_size", 24)
	list_title.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(list_title)
	
	var sep := HSeparator.new()
	sep.add_theme_color_override("font_color", Color(0.3, 0.5, 0.8, 0.3))
	left_vbox.add_child(sep)
	
	_loadout_buttons.clear()
	for i in range(LoadoutManager.MAX_LOADOUTS):
		var btn := Button.new()
		btn.name = "LoadoutBtn%d" % i
		if i < LoadoutManager.loadouts.size():
			var ld: Dictionary = LoadoutManager.loadouts[i]
			btn.text = ld.get("name", "配置%d" % (i + 1))
		else:
			btn.text = "配置%d" % (i + 1)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 15)
		btn.custom_minimum_size = Vector2(0, 40)
		
		if i == _selected_index:
			btn.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
			_loadout_buttons.append(_create_selected_style())
		else:
			_loadout_buttons.append(_create_unselected_style())
		
		_apply_loadout_style(i)
		btn.pressed.connect(func(): _on_loadout_selected(i))
		left_vbox.add_child(btn)
	
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	left_vbox.add_child(spacer)
	
	var back_btn := Button.new()
	back_btn.name = "BackBtn"
	back_btn.text = "<- " + GameSettings.t("back")
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.custom_minimum_size = Vector2(0, 42)
	back_btn.pressed.connect(_on_back)
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9, 1))
	
	var back_normal := StyleBoxFlat.new()
	back_normal.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	back_normal.border_color = Color(0.3, 0.5, 0.8, 0.5)
	back_normal.border_width_left = 2
	back_normal.border_width_right = 2
	back_normal.border_width_top = 1
	back_normal.border_width_bottom = 1
	back_normal.corner_radius_top_left = 6
	back_normal.corner_radius_top_right = 6
	back_normal.corner_radius_bottom_left = 6
	back_normal.corner_radius_bottom_right = 6
	back_normal.content_margin_left = 16
	back_normal.content_margin_right = 16
	back_normal.content_margin_top = 10
	back_normal.content_margin_bottom = 10
	back_btn.add_theme_stylebox_override("normal", back_normal)
	
	var back_hover := StyleBoxFlat.new()
	back_hover.bg_color = Color(0.1, 0.14, 0.22, 0.9)
	back_hover.border_color = Color(0.4, 0.6, 1.0, 0.8)
	back_hover.border_width_left = 2
	back_hover.border_width_right = 2
	back_hover.border_width_top = 2
	back_hover.border_width_bottom = 2
	back_hover.corner_radius_top_left = 6
	back_hover.corner_radius_top_right = 6
	back_hover.corner_radius_bottom_left = 6
	back_hover.corner_radius_bottom_right = 6
	back_hover.content_margin_left = 16
	back_hover.content_margin_right = 16
	back_hover.content_margin_top = 10
	back_hover.content_margin_bottom = 10
	back_btn.add_theme_stylebox_override("hover", back_hover)
	
	left_vbox.add_child(back_btn)


func _create_selected_style() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.18, 0.3, 0.9)
	normal.border_color = Color(0.4, 0.7, 1.0, 0.7)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.15, 0.22, 0.35, 0.9)
	hover.border_color = Color(0.5, 0.8, 1.0, 0.8)
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 1
	hover.border_width_bottom = 1
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8
	
	return {"normal": normal, "hover": hover}


func _create_unselected_style() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.08, 0.12, 0.7)
	normal.border_color = Color(0.25, 0.3, 0.45, 0.4)
	normal.border_width_left = 1
	normal.border_width_right = 1
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.08, 0.1, 0.16, 0.8)
	hover.border_color = Color(0.35, 0.45, 0.65, 0.6)
	hover.border_width_left = 1
	hover.border_width_right = 1
	hover.border_width_top = 1
	hover.border_width_bottom = 1
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	hover.content_margin_left = 12
	hover.content_margin_right = 12
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8
	
	return {"normal": normal, "hover": hover}


func _apply_loadout_style(index: int) -> void:
	if index >= _loadout_buttons.size():
		return
	var btn: Button = left_vbox_of_selected_index(index).get_child(2 + index) as Button
	if not btn:
		return
	var styles = _loadout_buttons[index]
	if index == _selected_index:
		btn.add_theme_stylebox_override("normal", styles["normal"])
		btn.add_theme_stylebox_override("hover", styles["hover"])
	else:
		btn.add_theme_stylebox_override("normal", styles["normal"])
		btn.add_theme_stylebox_override("hover", styles["hover"])


func left_vbox_of_selected_index(_idx: int) -> VBoxContainer:
	return get_node("MainHBox/Margin/LeftPanel/LeftVBox")


func _create_right_panel(parent: Container) -> void:
	var main_hbox_ref: HBoxContainer = parent.get_parent()
	
	var right_panel := PanelContainer.new()
	right_panel.name = "RightPanel"
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.05, 0.07, 0.1, 0.85)
	right_style.border_color = Color(0.3, 0.5, 0.8, 0.4)
	right_style.border_width_left = 2
	right_style.border_width_right = 2
	right_style.border_width_top = 2
	right_style.border_width_bottom = 2
	right_style.corner_radius_top_left = 10
	right_style.corner_radius_top_right = 10
	right_style.corner_radius_bottom_left = 10
	right_style.corner_radius_bottom_right = 10
	right_style.content_margin_top = 18
	right_style.content_margin_bottom = 18
	right_style.content_margin_left = 24
	right_style.content_margin_right = 24
	right_panel.add_theme_stylebox_override("panel", right_style)
	
	main_hbox_ref.add_child(right_panel)
	
	var right_vbox := VBoxContainer.new()
	right_vbox.name = "RightVBox"
	right_vbox.add_theme_constant_override("separation", 14)
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(right_vbox)
	
	_create_name_section(right_vbox)
	_create_weapon_section(right_vbox)
	_create_perk_sections(right_vbox)
	_create_save_button(right_vbox)


func _create_name_section(parent: Container) -> void:
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.text = GameSettings.t("loadout_name") + ":"
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1))
	parent.add_child(name_label)
	
	var name_edit := LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.add_theme_font_size_override("font_size", 17)
	if _selected_index < LoadoutManager.loadouts.size():
		name_edit.text = LoadoutManager.loadouts[_selected_index].get("name", "")
	name_edit.text_changed.connect(_on_name_changed)
	
	var line_style := StyleBoxFlat.new()
	line_style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	line_style.border_color = Color(0.3, 0.5, 0.8, 0.5)
	line_style.border_width_left = 2
	line_style.border_width_right = 2
	line_style.border_width_top = 1
	line_style.border_width_bottom = 2
	line_style.corner_radius_top_left = 6
	line_style.corner_radius_top_right = 6
	line_style.corner_radius_bottom_left = 6
	line_style.corner_radius_bottom_right = 6
	line_style.content_margin_left = 10
	line_style.content_margin_right = 10
	line_style.content_margin_top = 6
	line_style.content_margin_bottom = 6
	name_edit.add_theme_stylebox_override("normal", line_style)
	
	var line_focus := StyleBoxFlat.new()
	line_focus.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	line_focus.border_color = Color(0.4, 0.6, 1.0, 0.8)
	line_focus.border_width_left = 2
	line_focus.border_width_right = 2
	line_focus.border_width_top = 1
	line_focus.border_width_bottom = 2
	line_focus.corner_radius_top_left = 6
	line_focus.corner_radius_top_right = 6
	line_focus.corner_radius_bottom_left = 6
	line_focus.corner_radius_bottom_right = 6
	line_focus.content_margin_left = 10
	line_focus.content_margin_right = 10
	line_focus.content_margin_top = 6
	line_focus.content_margin_bottom = 6
	name_edit.add_theme_stylebox_override("focus", line_focus)
	
	parent.add_child(name_edit)


func _create_weapon_section(parent: Container) -> void:
	var weapon_title := Label.new()
	weapon_title.name = "WeaponTitle"
	weapon_title.text = GameSettings.t("primary_weapon")
	weapon_title.add_theme_font_size_override("font_size", 18)
	weapon_title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
	parent.add_child(weapon_title)
	
	var weapon_row := HBoxContainer.new()
	weapon_row.name = "WeaponRow"
	weapon_row.add_theme_constant_override("separation", 12)
	parent.add_child(weapon_row)
	
	_weapon_buttons.clear()
	var current_pw: int = _get_current_primary_weapon()
	
	for w_idx in PRIMARY_WEAPON_OPTIONS:
		var w_btn := Button.new()
		w_btn.name = "WeaponBtn%d" % w_idx
		var icon: String = WEAPON_ICONS.get(w_idx, "?")
		w_btn.text = icon + " " + LoadoutManager.get_weapon_name(w_idx)
		w_btn.custom_minimum_size = Vector2(130, 48)
		w_btn.add_theme_font_size_override("font_size", 15)
		w_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		_weapon_buttons.append(_create_weapon_styles(w_idx == current_pw))
		_apply_weapon_style(w_idx, w_btn)
		
		w_btn.pressed.connect(func(): _on_weapon_selected(w_idx))
		weapon_row.add_child(w_btn)


func _create_weapon_styles(is_selected: bool) -> Dictionary:
	var normal := StyleBoxFlat.new()
	var hover := StyleBoxFlat.new()
	if is_selected:
		normal.bg_color = Color(0.15, 0.1, 0.08, 0.9)
		normal.border_color = Color(1, 0.85, 0.3, 0.7)
		hover.bg_color = Color(0.2, 0.14, 0.1, 0.9)
		hover.border_color = Color(1, 0.9, 0.5, 1)
	else:
		normal.bg_color = Color(0.06, 0.08, 0.12, 0.9)
		normal.border_color = Color(0.3, 0.4, 0.6, 0.5)
		hover.bg_color = Color(0.1, 0.12, 0.18, 0.9)
		hover.border_color = Color(0.4, 0.55, 0.8, 0.7)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.corner_radius_top_left = 8
	hover.corner_radius_top_right = 8
	hover.corner_radius_bottom_left = 8
	hover.corner_radius_bottom_right = 8
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	hover.content_margin_top = 8
	hover.content_margin_bottom = 8
	return {"normal": normal, "hover": hover}


func _apply_weapon_style(index: int, btn: Button) -> void:
	if index >= _weapon_buttons.size():
		return
	var styles = _weapon_buttons[index]
	btn.add_theme_stylebox_override("normal", styles["normal"])
	btn.add_theme_stylebox_override("hover", styles["hover"])
	if index < PRIMARY_WEAPON_OPTIONS.size():
		var w_idx = PRIMARY_WEAPON_OPTIONS[index]
		if w_idx == _get_current_primary_weapon():
			btn.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
		else:
			btn.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95, 1))


func _create_perk_sections(parent: Container) -> void:
	_perk_buttons.clear()
	var cat_names: Array = [GameSettings.t("perk_category_0"), GameSettings.t("perk_category_1"), GameSettings.t("perk_category_2")]
	
	for cat in range(3):
		var perk_title := Label.new()
		perk_title.name = "PerkTitle%d" % cat
		perk_title.text = cat_names[cat]
		perk_title.add_theme_font_size_override("font_size", 16)
		perk_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 1))
		parent.add_child(perk_title)
		
		var perk_row := HBoxContainer.new()
		perk_row.name = "PerkRow%d" % cat
		perk_row.add_theme_constant_override("separation", 10)
		parent.add_child(perk_row)
		
		var current_perk: int = _get_current_perk(cat)
		
		var none_btn := Button.new()
		none_btn.name = "PerkNone%d" % cat
		none_btn.text = "\u00d7 " + GameSettings.t("perk_none")
		none_btn.custom_minimum_size = Vector2(90, 38)
		none_btn.add_theme_font_size_override("font_size", 14)
		none_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		if current_perk == -1:
			none_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
			_perk_buttons.append(_create_perk_selected_style())
		else:
			_perk_buttons.append(_create_perk_unselected_style())
		_apply_perk_style(perk_buttons_count(cat), none_btn)
		none_btn.pressed.connect(func(): _on_perk_selected(cat, -1))
		perk_row.add_child(none_btn)
		
		for p_idx in range(PERK_COUNTS[cat]):
			var p_btn := Button.new()
			p_btn.name = "PerkBtn%d_%d" % [cat, p_idx]
			p_btn.text = LoadoutManager.get_perk_name(cat, p_idx)
			p_btn.custom_minimum_size = Vector2(130, 38)
			p_btn.add_theme_font_size_override("font_size", 14)
			p_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
			if p_idx == current_perk:
				p_btn.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
				_perk_buttons.append(_create_perk_selected_style())
			else:
				_perk_buttons.append(_create_perk_unselected_style())
			_apply_perk_style(perk_buttons_count(cat) - 1, p_btn)
			p_btn.pressed.connect(func(): _on_perk_selected(cat, p_idx))
			perk_row.add_child(p_btn)
		
		var perk_desc := Label.new()
		perk_desc.name = "PerkDesc%d" % cat
		perk_desc.add_theme_font_size_override("font_size", 12)
		perk_desc.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1))
		perk_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		perk_desc.custom_minimum_size = Vector2(400, 20)
		if current_perk >= 0:
			perk_desc.text = "\u25ce " + LoadoutManager.get_perk_desc(cat, current_perk)
		perk_row.add_child(perk_desc)


func perk_buttons_count(_cat: int) -> int:
	var count: int = 0
	for cat in range(3):
		if cat < _cat:
			count += 1 + PERK_COUNTS[cat]
		else:
			break
	return count


func _create_perk_selected_style() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.08, 0.05, 0.9)
	normal.border_color = Color(1, 0.85, 0.3, 0.6)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.16, 0.11, 0.07, 0.9)
	hover.border_color = Color(1, 0.9, 0.5, 0.8)
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	
	return {"normal": normal, "hover": hover}


func _create_perk_unselected_style() -> Dictionary:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	normal.border_color = Color(0.3, 0.4, 0.6, 0.5)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 1
	normal.border_width_bottom = 1
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left = 10
	normal.content_margin_right = 10
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.1, 0.12, 0.18, 0.9)
	hover.border_color = Color(0.4, 0.55, 0.8, 0.7)
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.corner_radius_top_left = 6
	hover.corner_radius_top_right = 6
	hover.corner_radius_bottom_left = 6
	hover.corner_radius_bottom_right = 6
	hover.content_margin_left = 10
	hover.content_margin_right = 10
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	
	return {"normal": normal, "hover": hover}


func _apply_perk_style(index: int, btn: Button) -> void:
	var styles = _perk_buttons[index]
	if styles:
		btn.add_theme_stylebox_override("normal", styles["normal"])
		btn.add_theme_stylebox_override("hover", styles["hover"])


func _create_save_button(parent: Container) -> void:
	var save_btn := Button.new()
	save_btn.name = "SaveBtn"
	save_btn.text = GameSettings.t("loadout") + " \u2713"
	save_btn.custom_minimum_size = Vector2(220, 48)
	save_btn.add_theme_font_size_override("font_size", 18)
	save_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var save_normal := StyleBoxFlat.new()
	save_normal.bg_color = Color(0.1, 0.35, 0.2, 0.9)
	save_normal.border_color = Color(0.2, 0.8, 0.4, 0.8)
	save_normal.border_width_left = 2
	save_normal.border_width_right = 2
	save_normal.border_width_top = 1
	save_normal.border_width_bottom = 1
	save_normal.corner_radius_top_left = 8
	save_normal.corner_radius_top_right = 8
	save_normal.corner_radius_bottom_left = 8
	save_normal.corner_radius_bottom_right = 8
	save_normal.content_margin_left = 16
	save_normal.content_margin_right = 16
	save_normal.content_margin_top = 10
	save_normal.content_margin_bottom = 10
	save_btn.add_theme_stylebox_override("normal", save_normal)
	
	var save_hover := StyleBoxFlat.new()
	save_hover.bg_color = Color(0.15, 0.45, 0.28, 0.9)
	save_hover.border_color = Color(0.3, 1.0, 0.5, 1)
	save_hover.border_width_left = 2
	save_hover.border_width_right = 2
	save_hover.border_width_top = 2
	save_hover.border_width_bottom = 2
	save_hover.corner_radius_top_left = 8
	save_hover.corner_radius_top_right = 8
	save_hover.corner_radius_bottom_left = 8
	save_hover.corner_radius_bottom_right = 8
	save_hover.content_margin_left = 16
	save_hover.content_margin_right = 16
	save_hover.content_margin_top = 10
	save_hover.content_margin_bottom = 10
	save_btn.add_theme_stylebox_override("hover", save_hover)
	
	save_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	save_btn.pressed.connect(_on_save)
	parent.add_child(save_btn)


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
	for child in get_children():
		if child.name != "BG" and child.name != "DynamicBG":
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
	for child in get_children():
		if child.name != "BG" and child.name != "DynamicBG":
			child.queue_free()
	_build_ui()
	_connect_click_sounds(self)

func _on_save() -> void:
	LoadoutManager.select_loadout(_selected_index)
	LoadoutManager._save_loadouts()
	_on_back()

func _on_back() -> void:
	SceneTransition.fade_out("res://scenes/menu/main_menu.tscn")
