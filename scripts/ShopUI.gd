extends Control

# =============================================================================
# Bot 模式商店 UI（风格化版）
# 人头商店：击杀敌人获得人头，按人头购买物品
# =============================================================================

signal item_purchased(item_id: int)
signal shop_closed()

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var kills_label: Label = $Panel/VBox/KillsLabel
@onready var item_list: VBoxContainer = $Panel/VBox/ItemList
@onready var close_btn: Button = $Panel/VBox/CloseBtn

var current_kills: int = 0
var purchased_items: Array = []

var item_buttons: Array = []

# 商品定义 [id, 名称, 花费人头数, 描述, 图标]
var items: Array = [
	{"id": 0, "name": "补满弹药", "cost": 2, "desc": "补满当前武器的弹匣+备用弹", "icon": "A"},
	{"id": 1, "name": "医疗包", "cost": 1, "desc": "恢复 50 点生命值", "icon": "+"},
	{"id": 2, "name": "升级伤害", "cost": 10, "desc": "所有武器伤害 +10", "icon": "S"},
	{"id": 3, "name": "无限子弹", "cost": 30, "desc": "当前武器弹匣无限（仍可换弹显示）", "icon": "\u221e"},
	{"id": 4, "name": "核爆", "cost": 40, "desc": "立即结束游戏，玩家已核爆", "icon": "N"},
	{"id": 5, "name": "手榴弹", "cost": 8, "desc": "获得 1 颗手榴弹（按 G 长按瞄准松开投掷）", "icon": "G"},
	{"id": 6, "name": "机枪", "cost": 12, "desc": "解锁机枪武器（按 5 切换）", "icon": "M"},
]


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

	if close_btn:
		close_btn.pressed.connect(_on_close)

	_refresh_ui()


func open(kills: int) -> void:
	current_kills = kills
	visible = true
	_refresh_ui()


func close() -> void:
	visible = false
	shop_closed.emit()


func _on_close() -> void:
	close()


func set_kills(kills: int) -> void:
	current_kills = kills
	_refresh_ui()


func _refresh_ui() -> void:
	if kills_label:
		kills_label.text = "当前人头: %d" % current_kills

	if not item_list:
		return

	for child in item_list.get_children():
		child.queue_free()
	item_buttons.clear()

	for item in items:
		var btn := _create_shop_item(item)
		item_buttons.append(btn)
		item_list.add_child(btn)


func _create_shop_item(item: Dictionary) -> PanelContainer:
	var is_purchased: bool = item.id in purchased_items
	var affordable: bool = current_kills >= item.cost
	
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 70)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style := StyleBoxFlat.new()
	if is_purchased:
		style.bg_color = Color(0.08, 0.06, 0.06, 0.9)
		style.border_color = Color(0.5, 0.2, 0.2, 0.5)
	elif not affordable:
		style.bg_color = Color(0.06, 0.07, 0.09, 0.9)
		style.border_color = Color(0.25, 0.3, 0.4, 0.4)
	else:
		style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
		style.border_color = Color(0.3, 0.5, 0.8, 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 1
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)
	
	# 图标区域
	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(44, 44)
	icon_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var icon_style := StyleBoxFlat.new()
	if is_purchased:
		icon_style.bg_color = Color(0.3, 0.15, 0.15, 0.8)
		icon_style.border_color = Color(0.6, 0.2, 0.2, 0.6)
	elif affordable:
		icon_style.bg_color = Color(0.15, 0.25, 0.4, 0.8)
		icon_style.border_color = Color(0.3, 0.6, 1.0, 0.6)
	else:
		icon_style.bg_color = Color(0.1, 0.1, 0.12, 0.8)
		icon_style.border_color = Color(0.25, 0.25, 0.3, 0.5)
	icon_style.border_width_left = 2
	icon_style.border_width_right = 2
	icon_style.border_width_top = 2
	icon_style.border_width_bottom = 2
	icon_style.corner_radius_top_left = 8
	icon_style.corner_radius_top_right = 8
	icon_style.corner_radius_bottom_left = 8
	icon_style.corner_radius_bottom_right = 8
	icon_panel.add_theme_stylebox_override("panel", icon_style)
	
	var icon_label := Label.new()
	icon_label.text = item.icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 20)
	if affordable and not is_purchased:
		icon_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0, 1))
	elif is_purchased:
		icon_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3, 1))
	else:
		icon_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45, 1))
	icon_panel.add_child(icon_label)
	hbox.add_child(icon_panel)
	
	# 信息区域
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)
	
	var name_hbox := HBoxContainer.new()
	name_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_child(name_hbox)
	
	var name_label := Label.new()
	name_label.text = item.name
	name_label.add_theme_font_size_override("font_size", 15)
	if is_purchased:
		name_label.add_theme_color_override("font_color", Color(0.7, 0.4, 0.4, 1))
	elif affordable:
		name_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	else:
		name_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 1))
	name_hbox.add_child(name_label)
	
	# 价格标签
	var cost_label := Label.new()
	cost_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cost_label.add_theme_font_size_override("font_size", 14)
	if is_purchased:
		cost_label.text = "[已购买]"
		cost_label.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3, 1))
	else:
		cost_label.text = "[%d 人头]" % item.cost
		if affordable:
			cost_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
		else:
			cost_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4, 1))
	name_hbox.add_child(cost_label)
	
	var desc_label := Label.new()
	desc_label.text = item.desc
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_label)
	
	# 购买按钮
	var buy_btn := Button.new()
	buy_btn.text = "购买" if not is_purchased else "已购"
	buy_btn.custom_minimum_size = Vector2(80, 36)
	buy_btn.add_theme_font_size_override("font_size", 14)
	buy_btn.disabled = is_purchased or not affordable
	
	var btn_normal := StyleBoxFlat.new()
	if is_purchased:
		btn_normal.bg_color = Color(0.2, 0.1, 0.1, 0.9)
		btn_normal.border_color = Color(0.5, 0.2, 0.2, 0.5)
	elif affordable:
		btn_normal.bg_color = Color(0.15, 0.4, 0.25, 0.9)
		btn_normal.border_color = Color(0.2, 0.8, 0.4, 0.8)
	else:
		btn_normal.bg_color = Color(0.15, 0.15, 0.15, 0.9)
		btn_normal.border_color = Color(0.3, 0.3, 0.3, 0.5)
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 1
	btn_normal.border_width_bottom = 1
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	buy_btn.add_theme_stylebox_override("normal", btn_normal)
	
	var btn_hover := StyleBoxFlat.new()
	if affordable:
		btn_hover.bg_color = Color(0.2, 0.55, 0.35, 0.9)
		btn_hover.border_color = Color(0.3, 1.0, 0.5, 1.0)
	else:
		btn_hover.bg_color = Color(0.2, 0.2, 0.2, 0.9)
		btn_hover.border_color = Color(0.4, 0.4, 0.4, 0.5)
	btn_hover.border_width_left = 2
	btn_hover.border_width_right = 2
	btn_hover.border_width_top = 1
	btn_hover.border_width_bottom = 1
	btn_hover.corner_radius_top_left = 6
	btn_hover.corner_radius_top_right = 6
	btn_hover.corner_radius_bottom_left = 6
	btn_hover.corner_radius_bottom_right = 6
	buy_btn.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed := StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.1, 0.3, 0.18, 0.9)
	btn_pressed.border_color = Color(0.3, 1.0, 0.5, 1.0)
	btn_pressed.border_width_left = 2
	btn_pressed.border_width_right = 2
	btn_pressed.border_width_top = 2
	btn_pressed.border_width_bottom = 2
	btn_pressed.corner_radius_top_left = 6
	btn_pressed.corner_radius_top_right = 6
	btn_pressed.corner_radius_bottom_left = 6
	btn_pressed.corner_radius_bottom_right = 6
	buy_btn.add_theme_stylebox_override("pressed", btn_pressed)
	
	if is_purchased or not affordable:
		buy_btn.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
	else:
		buy_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	
	buy_btn.pressed.connect(func(): _on_item_pressed(item.id))
	buy_btn.pressed.connect(UIAudio.play_click)
	hbox.add_child(buy_btn)
	
	return panel


func _on_item_pressed(item_id: int) -> void:
	var one_time_items: Array = [3, 4, 6]
	if item_id in one_time_items:
		purchased_items.append(item_id)
	item_purchased.emit(item_id)
	_refresh_ui()
