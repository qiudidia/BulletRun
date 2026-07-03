extends Control

# =============================================================================
# Bot 模式商店 UI
# 人头商店：击杀敌人获得人头，按人头购买物品
# =============================================================================

signal item_purchased(item_id: int)
signal shop_closed()

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var kills_label: Label = $Panel/VBox/KillsLabel
@onready var item_list: VBoxContainer = $Panel/VBox/ItemList
@onready var close_btn: Button = $Panel/VBox/CloseBtn

var current_kills: int = 0

# 已购买的一次性商品 id 集合（灰显不可再买）
var purchased_items: Array = []

# 商品定义 [id, 名称, 花费人头数, 描述]
var items: Array = [
	{"id": 0, "name": "补满弹药", "cost": 2, "desc": "补满当前武器的弹匣+备用弹"},
	{"id": 1, "name": "医疗包", "cost": 1, "desc": "恢复 50 点生命值"},
	{"id": 2, "name": "升级伤害", "cost": 10, "desc": "所有武器伤害 +10"},
	{"id": 3, "name": "无限子弹", "cost": 30, "desc": "当前武器弹匣无限（仍可换弹显示）"},
	{"id": 4, "name": "核爆", "cost": 40, "desc": "立即结束游戏，玩家已核爆"},
	{"id": 5, "name": "手榴弹", "cost": 8, "desc": "获得 1 颗手榴弹（按 G 长按瞄准松开投掷）"},
	{"id": 6, "name": "机枪", "cost": 12, "desc": "解锁机枪武器（按 5 切换）"},
]


func _ready() -> void:
	# 默认隐藏
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

	# 清空旧按钮
	for child in item_list.get_children():
		child.queue_free()

	for item in items:
		var btn: Button = Button.new()
		var is_purchased: bool = item.id in purchased_items
		var affordable: bool = current_kills >= item.cost
		var cost_text: String = "%d 人头" % item.cost
		if is_purchased:
			btn.text = "%s  [已购买]\n%s" % [item.name, item.desc]
			btn.disabled = true
		else:
			btn.text = "%s  [%s]\n%s" % [item.name, cost_text, item.desc]
			btn.disabled = not affordable
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _on_item_pressed(item.id))
		item_list.add_child(btn)


func _on_item_pressed(item_id: int) -> void:
	# 一次性商品：不可重复购买（机枪6、无限子弹3、核爆4）
	var one_time_items: Array = [3, 4, 6]
	if item_id in one_time_items:
		purchased_items.append(item_id)
	item_purchased.emit(item_id)
	_refresh_ui()
